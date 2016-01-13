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
      'gzip' => :gzip,
    }

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

      @formatter = Plugin.new_formatter(@format)
      @formatter.configure(conf)
      prepare_client()
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

    def path_format(chunk_key)
      path = Time.strptime(chunk_key, @time_slice_format).strftime(@path)
      log.debug "GCS Path: #{path}"
      path
    end

    def send(path, data)
      mimetype = MIME::Types.type_for(path).first

      io = nil
      if SUPPORTED_COMPRESS.include?(@compress)
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
      gcs_path = path_format(chunk.key)
      send(gcs_path, chunk.read)
      gcs_path
    end
  end
end

