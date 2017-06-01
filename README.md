# fluent-plugin-windows-eventlog

## Component

#### fluentd Input plugin for the Windows Event Log

[Fluentd](http://fluentd.org) plugin to read the Windows Event Log.

## Installation
    gem install fluent-plugin-windows-eventlog

## Configuration
#### fluentd Input plugin for the Windows Event Log

    <source>
      @type windows_eventlog
      @id windows_eventlog
      channels application,system
      read_interval 2
      tag winevt.raw
      <storage>
        @type local             # @type local is the default.
        persistent true         # default is true. Set to false to use in-memory storage.
        path ./tmp/storage.json # This is required when persistent is true.
                                # Or, please consider using <system> section's `root_dir` parameter.
      </storage>
    </source>

#### parameters

|name      | description |
|:-----    |:-----       |
|`channels`   | (option) 'application' as default. One or more of {'application', 'system', 'setup', 'security'}. If you want to read 'setup' or 'security' logs, you must launch fluentd with administrator privileges.|
|`keys`   | (option) A subset of [keys](#read-keys) to read. Defaults to all keys.|
|`read_interval`   | (option) read interval in seconds. 2 seconds as default.|
|`from_encoding`  | (option) input character encoding. `nil` as default.|
|`encoding`   | (option) output character encoding. `nil` as default.|
|`<storage>`| Setting for `storage` plugin for recording read position like `in_tail`'s `pos_file`.|

#### read keys
This plugin reads the following fields from Windows Event Log entries. Use the `keys` configuration option to select a subset. No other customization is allowed for now.

|key|
|:-----    |
|`record_number` |
|`time_generated`|
|`time_written`  |
|`event_id`      |
|`event_type`    |
|`event_category`|
|`source_name`   |
|`computer_name` |
|`user`          |
|`description`   |
|`string_inserts`|

## Etc.
'`read_from_head`' is not supported currently. You can read newer records after you start first.
No customize to read information keys.

## Copyright
#### Copyright
Copyright(C) 2014- @okahashi117
#### License
Apache License, Version 2.0

