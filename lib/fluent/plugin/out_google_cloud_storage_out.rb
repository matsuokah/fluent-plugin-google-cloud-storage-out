# -*- coding: utf-8 -*-

module Fluent
  require "fluent/log"
  require "fluent/mixin/config_placeholders"
  require 'googleauth'
  require 'google/apis/storage_v1'
  class GoogleCloudStorageOut < TimeSlicedOutput
    Plugin.register_output('google_cloud_storage_out', self)

    Storage = Google::Apis::StorageV1
    ServiceAccountCredentials = Google::Auth::ServiceAccountCredentials

    SUPPORTED_COMPRESS = {
      'gz' => :gz,
      'gzip' => :gz,
    }

    UNIQUE_STRATEGY= {
      'chunk_id' => :chunk_id,
      'increment' => :increment,
      'timestamp' => :timestamp,
    }

    UNIQUE_PLACE_HOLDER = '${unique}'

    #
    # Config Parameters
    #
    config_set_default :buffer_type, 'file'
    config_set_default :time_slice_format, '%Y%m%d'
    config_set_default :flush_interval, nil

    include Mixin::ConfigPlaceholders

    #desc "The path of Service Account Json key."
    config_param :service_account_json_key_path, :string

    #desc "The bucket ID for destination for store."
    config_param :bucket_id, :string

    #desc "The directory path for store."
    config_param :path, :string

    #desc "The format of the file content. The default is out_file"
    config_param :format, :string, :default => 'out_file'

    #desc "The tag for out"
    config_param :default_tag, :string, :default => 'tag_missing'

    #desc "The unique strategy for avoid override for same path"
    config_param :unique_strategy, :default => nil do |val|
      c = UNIQUE_STRATEGY[val]
      unless c
        raise ConfigError, "Unsupported make uniuqe strategy '#{val}'"
      end
      c
    end

    #desc "The format for unique replacement, if you set timestamp to unique_strategy, you should set time format"
    config_param :unique_format, :string, :default => "%Y%m%d%H%M%S%L"

    #desc "Compress flushed file."
    config_param :compress, :default => nil do |val|
      c = SUPPORTED_COMPRESS[val]
      unless c
        raise ConfigError, "Unsupported compression algorithm '#{val}'"
      end
      c
    end

    def initialize
      super
      require 'zlib'
      require 'net/http'
      require 'time'
      require 'mime-types'
    end

    # Define `log` method for v0.10.42 or earlier
    unless method_defined?(:log)
      define_method("log") { $log }
    end

    def configure(conf)
      if conf['path']
        if conf['path'].index('%S')
          conf['time_slice_format'] = '%Y%m%d%H%M%S'
        elsif conf['path'].index('%M')
          conf['time_slice_format'] = '%Y%m%d%H%M'
        elsif conf['path'].index('%H')
          conf['time_slice_format'] = '%Y%m%d%H'
        end
      end

      super

      if @path.index(UNIQUE_PLACE_HOLDER).nil? && @unique_strategy
        raise Fluent::ConfigError, "Path must contain ${unique}, or you set the unique_strategy to nil."
      end

      @formatter = Plugin.new_formatter(@format)
      @formatter.configure(conf)
      @path_suffix = ".log"
      prepare_client()

      if @unique_strategy == :increment
         @samepath_counter = 0
      end
    end

    def prepare_client
      @storage = Storage::StorageService.new
      scopes = [Storage::AUTH_CLOUD_PLATFORM, Storage::AUTH_DEVSTORAGE_FULL_CONTROL]
      @storage.authorization = ServiceAccountCredentials.make_creds(
        {
          :json_key_io => File.open(@service_account_json_key_path),
          :scope => scopes
        }
      )
    end

    def start
      super
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      @formatter.format(tag, time, record)
    end

    def chunk_unique_id_to_str(unique_id)
      unique_id.unpack('C*').map{|x| x.to_s(16).rjust(2,'0')}.join('')
    end

    def path_format_with_unique_strategy(path, strategy, chunk_key, chunk_unique)
       case strategy
       when nil
         path
       when :chunk_id
         path.gsub(UNIQUE_PLACE_HOLDER, chunk_unique_id_to_str(chunk_unique))
       when :increment
         if @before_chunk_key
           if @before_chunk_key == chunk_key
             @samepath_counter += 1
           else
             @samepath_counter = 0
           end
         end
         @before_chunk_key = chunk_key
         path.gsub(UNIQUE_PLACE_HOLDER, "#{@samepath_counter}")
       when :timestamp
         path.gsub(UNIQUE_PLACE_HOLDER, Time.now.strftime(@unique_format))
       end
    end

    def path_format(chunk)
      # format from chunk key
      path = Time.strptime(chunk.key, @time_slice_format).strftime(@path)

      # format for make unique
      path = path_format_with_unique_strategy(path, @unique_strategy, chunk.key, chunk.unique_id)

      # append .log
      unless path.include?(".log")
        path.concat(@path_suffix)
      end

      # append .gz
      case @compress
      when nil
        path
      when :gz
        "#{path}.gz"
      end
    end

    def send(path, data)
      mimetype = MIME::Types.type_for(path).first
      io = nil
      if @compress
        io = StringIO.new("")
        writer = Zlib::GzipWriter.new(io)
        writer.write(data)
        writer.finish
        io.rewind
      else
        io = StringIO.new(data)
      end

      @storage.insert_object(@bucket_id, upload_source: io, name: path, content_type:mimetype.content_type)
    end

    def write(chunk)
      gcs_path = path_format(chunk)
      send(gcs_path, chunk.read)
      gcs_path
    end
  end
end
