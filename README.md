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
|`channels`      | (option) 'application' as default. One or more of {'application', 'system', 'setup', 'security'}. If you want to read 'setup' or 'security' logs, you must launch fluentd with administrator privileges.|
|`keys`          | (option) A subset of [keys](#read-keys) to read. Defaults to all keys.|
|`read_interval` | (option) Read interval in seconds. 2 seconds as default.|
|`from_encoding` | (option) Input character encoding. `nil` as default.|
|`encoding`      | (option) Output character encoding. `nil` as default.|
|`read_from_head`| (option) Start to read the entries from the oldest, not from when fluentd is started. Defaults to `false`.|
|`<storage>`     | Setting for `storage` plugin for recording read position like `in_tail`'s `pos_file`.|

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

## Copyright
#### Copyright
Copyright(C) 2014- @okahashi117
#### License
Apache License, Version 2.0

