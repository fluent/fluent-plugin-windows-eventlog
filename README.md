# fluent-plugin-windows-eventlog

## Component

#### fluentd Input plugin for Windows Event Log

[Fluentd](http://fluentd.org) plugin to read Windows Event Log.

## Installation
    gem install fluent-plugin-windows-eventlog

## Configuration
#### fluentd Input plugin for Windows Event Log 

    <source>
      @type windows_eventlog
      channels application,system
      read_interval 2
      tag winevt.raw
      @id windows_eventlog
      <storage>
        @type local             # @type local is default.
        persistent true         # default is true. If you want to use on-memory storage, set false.
        path ./tmp/storage.json # This is required when persistent is true.
                                # Or, please consider to use <system> section's root_dir parameter.
      </storage>
    </source>

#### parameters

|name      | description |
|:-----    |:-----       |
|channels   | (option) 'applicaion' as default. one or combination of {application, system, setup, security}. If you want to read setup or security, administrator priv is required to launch fluentd.  |
|read_interval   | (option) a read interval in second. 2 seconds as default.|
|from_encoding  | (option) an input characters encoding. nil as default.|
|encoding   | (option) an output characters encoding. nil as default.|
|<storage>|Setting for storage plugin for recording read position like in_tail's pos_file|

#### read keys
This plugin reads follows from Windws Event Log. No customization is allowed for now.

|key|
|:-----    |
|record_number   |
|time_generated|
|time_written   |
|event_id   |
|event_type   |
|event_category   |
|source_name   |
|computer_name  |
|user   |
|description   |

## Etc.
'read_from_head' is not supporeted currently.You can read newer records after you start first.
No customize to read information keys.

## Copyright
####Copyright
Copyright(C) 2014- @okahashi117
####License
Apache License, Version 2.0

