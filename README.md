# Fluent::GoogleCloudStorageOut
## Installation

Add this line to your application's Gemfile:

```ruby
$ td-agent-gem install fluent-plugin-google-cloud-storage-out
```

## Usage

#### Sample Conf
```
<match *.json.log>
    type google_cloud_storage_out
    service_account_json_key_path /etc/td-agent/client_secrets.json
    bucket_id access-log
    path nginx/%Y_%m_%d/${hostname}_%H%M_${unique}
    unique_strategy increment
    format json
    compress gzip

    buffer_type memory
    buffer_chunk_limit 10m
</match>
```

| parameter | description |
| ---- | ---- |
| service_account_json_key_path | Absolute Path to json key |
| bucket_id | GCS Bucket ID to Store |
| path | Path to save, if you use `/`, that will resolve to directory. And if path is including time format , then rotate by minum unit. Moreover, you can include ${unique}, that is to replace token with unique key|
| unique_strategy | you can choice chunk_id, timestamp and inctement |
| unique_format | Now, if you choiced `timestamp` to unique_strategy, then you can ccustom timestampformat. Default format is `%Y%m%d%H%M%S%L` |
| format |  |
| compress | gzip or nil |

#### Bucket

You shuould beforehand make a Bucket in GCS. This plugin will not support to create a Bucket automatically. Because I assume this plugin was used any servers.

#### ServiceAccountKey(json)

TODO

#### Conf

TODO

#### Make Unique Strategy for avoid override object

TODO

###### Use The Chunk ID

TODO

###### Use The Timestamp

TODO

###### Use The Increment

TODO
