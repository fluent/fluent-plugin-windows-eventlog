# fluent-plugin-windows-eventlog

## Component

### fluentd Input plugin for the Windows Event Log

[Fluentd](https://www.fluentd.org/) plugin to read the Windows Event Log.

## Installation
    ridk exec gem install fluent-plugin-windows-eventlog

## Configuration

### in_windows_eventlog

Check [in_windows_eventlog2](https://github.com/fluent/fluent-plugin-windows-eventlog#in_windows_eventlog2) first. `in_windows_eventlog` will be replaced with `in_windows_eventlog2`.

fluentd Input plugin for the Windows Event Log using old Windows Event Logging API

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
|`channels`         | (option) 'application' as default. One or more of {'application', 'system', 'setup', 'security'}. If you want to read 'setup' or 'security' logs, you must launch fluentd with administrator privileges.|
|`keys`             | (option) A subset of [keys](#read-keys) to read. Defaults to all keys.|
|`read_interval`    | (option) Read interval in seconds. 2 seconds as default.|
|`from_encoding`    | (option) Input character encoding. `nil` as default.|
|`encoding`         | (option) Output character encoding. `nil` as default.|
|`read_from_head`   | (option) Start to read the entries from the oldest, not from when fluentd is started. Defaults to `false`.|
|`<storage>`        | Setting for `storage` plugin for recording read position like `in_tail`'s `pos_file`.|
|`parse_description`| (option) parse `description` field and set parsed result into the record. `parse` and `string_inserts` fields are removed|

##### Available keys

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

##### `parse_description` details

Here is an example with `parse_description true`.

```
{
  "channel": "security",
  "record_number": "91698",
  "time_generated": "2017-08-29 20:12:29 +0000",
  "time_written": "2017-08-29 20:12:29 +0000",
  "event_id": "4798",
  "event_type": "audit_success",
  "event_category": "13824",
  "source_name": "Microsoft-Windows-Security-Auditing",
  "computer_name": "TEST",
  "user": "",
  "description": "A user's local group membership was enumerated.\r\n\r\nSubject:\r\n\tSecurity ID:\t\tS-XXX\r\n\tAccount Name:\t\tTEST$\r\n\tAccount Domain:\t\tWORKGROUP\r\n\tLogon ID:\t\t0x3e7\r\n\r\nUser:\r\n\tSecurity ID:\t\tS-XXX-YYY-ZZZ\r\n\tAccount Name:\t\tAdministrator\r\n\tAccount Domain:\t\tTEST\r\n\r\nProcess Information:\r\n\tProcess ID:\t\t0x7dc\r\n\tProcess Name:\t\tC:\\Windows\\System32\\LogonUI.exe\r\n",
  "string_inserts": [
    "Administrator",
    "TEST",
    "S-XXX-YYY-ZZZ",
    "S-XXX",
    "TEST$",
    "WORKGROUP",
    "0x3e7",
    "0x7dc",
    "C:\\Windows\\System32\\LogonUI.exe"
  ]
}
```

This record is transformed to

```
{
  "channel": "security",
  "record_number": "91698",
  "time_generated": "2017-08-29 20:12:29 +0000",
  "time_written": "2017-08-29 20:12:29 +0000",
  "event_id": "4798",
  "event_type": "audit_success",
  "event_category": "13824",
  "source_name": "Microsoft-Windows-Security-Auditing",
  "computer_name": "TEST",
  "user": "",
  "description_title": "A user's local group membership was enumerated.",
  "subject.security_id": "S-XXX",
  "subject.account_name": "TEST$",
  "subject.account_domain": "WORKGROUP",
  "subject.logon_id": "0x3e7",
  "user.security_id": "S-XXX-YYY-ZZZ",
  "user.account_name": "Administrator",
  "user.account_domain": "TEST",
  "process_information.process_id": "0x7dc",
  "process_information.process_name": "C:\\Windows\\System32\\LogonUI.exe\r\n"
}
```

NOTE: This feature assumes `description` field has following formats:

- group delimiter: `\r\n\r\n`
- record delimiter: `\r\n\t`
- field delimiter: `\t\t`

If your `description` doesn't follow this format, the parsed result is only `description_title` field with same `description` content.

### in_windows_eventlog2

fluentd Input plugin for the Windows Event Log using newer Windows Event Logging API. This is successor to `in_windows_eventlog`. See also [this slide](https://www.slideshare.net/cosmo0920/fluentd-meetup-2019) for the details of `in_windows_eventlog2` plugin.

    <source>
      @type windows_eventlog2
      @id windows_eventlog2
      channels application,system # Also be able to use `<subscribe>` directive.
      read_existing_events false
      read_interval 2
      tag winevt.raw
      render_as_xml false       # default is true.
      rate_limit 200            # default is -1(Winevt::EventLog::Subscribe::RATE_INFINITE).
      <storage>
        @type local             # @type local is the default.
        persistent true         # default is true. Set to false to use in-memory storage.
        path ./tmp/storage.json # This is required when persistent is true.
                                # Or, please consider using <system> section's `root_dir` parameter.
      </storage>
      <parse>
        @type winevt_xml # @type winevt_xml is the default. winevt_xml and none parsers are supported for now.
      </parse>
      # <subscribe>
      #   channles application, system
      #   read_existing_events false # read_existing_events should be applied each of subscribe directive(s)
      # </subscribe>
    </source>

**NOTE:** in_windows_eventlog2 always handles EventLog records as UTF-8 characters. Users don't have to specify encoding related parameters and they are not provided.

**NOTE:** When `Description` contains error message such as `The message resource is present but the message was not found in the message table.`, eventlog's resource file (.mui) related to error generating event is something wrong. This issue is also occurred in built-in Windows Event Viewer which is the part of Windows management tool.

**NOTE:** When `render_as_xml` as `false`, the dependent winevt_c gem renders Windows EventLog as Ruby Hash object directly. This reduces bottleneck to consume EventLog. Specifying `render_as_xml` as `false` should be faster consuming than `render_as_xml` as `true` case.

**NOTE:** If you encountered CPU spike due to massively huge EventLog channel, `rate_limit` parameter may help you. Currently, this paramter can handle the multiples of 10 or -1(`Winevt::EventLog::Subscribe::RATE_INFINITE`).

#### parameters

|name      | description |
|:-----    |:-----       |
|`channels`         | (option) No default value just empty array, but 'application' is used as default due to backward compatibility. One or more of {'application', 'system', 'setup', 'security'}. If you want to read 'setup' or 'security' logs, you must launch fluentd with administrator privileges.|
|`keys`             | (option) A subset of [keys](#read-keys) to read. Defaults to all keys.|
|`read_interval`    | (option) Read interval in seconds. 2 seconds as default.|
|`from_encoding`    | (option) Input character encoding. `nil` as default.|
|`<storage>`        | Setting for `storage` plugin for recording read position like `in_tail`'s `pos_file`.|
|`<parse>`          | Setting for `parser` plugin for parsing raw XML EventLog records. |
|`parse_description`| (option) parse `description` field and set parsed result into the record. `Description` and `EventData` fields are removed|
|`read_from_head`   | **Deprecated** (option) Start to read the entries from the oldest, not from when fluentd is started. Defaults to `false`.|
|`read_existing_events` | (option) Read the entries which already exist before fluentd is started. Defaults to `false`.|
|`rate_limit`      | (option) Specify rate limit to consume EventLog. Default is `Winevt::EventLog::Subscribe::RATE_INFINITE`.|
|`read_all_channels`| (option) Read from all channels. Default is `false`|
|`<subscribe>`          | Setting for subscribe channels. |

##### subscribe section

|name      | description |
|:-----    |:-----       |
|`channels`             | One or more of {'application', 'system', 'setup', 'security'}. If you want to read 'setup' or 'security' logs, you must launch fluentd with administrator privileges. |
|`read_existing_events` | (option) Read the entries which already exist before fluentd is started. Defaults to `false`. |


**Motivation:** subscribe directive is designed for applying `read_existing_events` each of channels which is specified in subscribe section(s).

e.g) The previous configuration can handle `read_existing_events` but this parameter only specifies `read_existing_events` or not for channels which are specified in `channels`.

```aconf
channels ["Application", "Security", "HardwareEvents"]
read_existing_events true
```

is interpreted as "Application", "Security", and "HardwareEvents" should be read existing events.

But some users want to configure to:

* "Application" and "Security" channels just tailing
* "HardwareEvent" channel read existing events before launching Fluentd

With `<subscribe>` directive, this requirements can be represendted as:

```aconf
<subscribe>
  channles ["Application", "Security"]
  # read_existing_events false
</subscribe>
<subscribe>
  channles ["HardwareEvent"]
  read_existing_events true
</subscribe>
```

This configuration can be handled as:

* "Application" and "Security" channels just tailing
* "HardwareEvent" channel read existing events before launching Fluentd

##### Available keys

This plugin reads the following fields from Windows Event Log entries. Use the `keys` configuration option to select a subset. No other customization is allowed for now.

|key|
|:-----             |
|`ProviderName`     |
|`ProviderGuid`     |
|`EventID`          |
|`Qualifiers`       |
|`Level`            |
|`Task`             |
|`Opcode`           |
|`Keywords`         |
|`TimeCreated`      |
|`EventRecordId`    |
|`ActivityID`       |
|`RelatedActivityID`|
|`ProcessID`        |
|`ThreadID`         |
|`Channel`          |
|`Computer`         |
|`UserID`           |
|`Version`          |
|`Description`      |
|`EventData`        |

##### `parse_description` details

Here is an example with `parse_description true`.

```
{
  "ProviderName": "Microsoft-Windows-Security-Auditing",
  "ProviderGUID": "{D441060A-9695-472B-90BC-24DCA9D503A4}",
  "EventID": "4798",
  "Qualifiers": "",
  "Level": "0",
  "Task": "13824",
  "Opcode": "0",
  "Keywords": "0x8020000000000000",
  "TimeCreated": "2019-06-19T03:10:01.982940200Z",
  "EventRecordID": "87028",
  "ActivityID": "",
  "RelatedActivityID": "{2599DE71-2F70-44AD-9DC8-C5FF2AE8D1EF}",
  "ThreadID": "16888",
  "Channel": "Security",
  "Computer": "DESKTOP-TEST",
  "UserID": "",
  "Version": "0",
  "Description": "A user's local group membership was enumerated.\r\n\r\nSubject:\r\n\tSecurity ID:\t\tS-X-Y-Z\r\n\tAccount Name:\t\tDESKTOP-TEST$\r\n\tAccount Domain:\t\tWORKGROUP\r\n\tLogon ID:\t\t0x3e7\r\n\r\nUser:\r\n\tSecurity ID:\t\tS-XXX-YYY-ZZZ0\r\n\tAccount Name:\t\tAdministrator\r\n\tAccount Domain:\t\tDESKTOP-TEST\r\n\r\nProcess Information:\r\n\tProcess ID:\t\t0xbac\r\n\tProcess Name:\t\tC:\\Windows\\System32\\svchost.exe\r\n",
  "EventData": [
    "Administrator",
    "DESKTOP-TEST",
    "S-XXX-YYY-ZZZ",
    "S-X-Y-Z",
    "DESKTOP-TEST$",
    "WORKGROUP",
    "0x3e7",
    "0xbac",
    "C:\\Windows\\System32\\svchost.exe"
  ]
}
```

This record is transformed to

```
{
  "ProviderName": "Microsoft-Windows-Security-Auditing",
  "ProviderGUID": "{D441060A-9695-472B-90BC-24DCA9D503A4}",
  "EventID": "4798",
  "Qualifiers": "",
  "Level": "0",
  "Task": "13824",
  "Opcode": "0",
  "Keywords": "0x8020000000000000",
  "TimeCreated": "2019-06-19T03:10:01.982940200Z",
  "EventRecordID": "87028",
  "ActivityID": "",
  "RelatedActivityID": "{2599DE71-2F70-44AD-9DC8-C5FF2AE8D1EF}",
  "ThreadID": "16888",
  "Channel": "Security",
  "Computer": "DESKTOP-TEST",
  "UserID": "",
  "Version": "0",
  "DescriptionTitle": "A user's local group membership was enumerated.",
  "subject.security_id": "S-X-Y-Z",
  "subject.account_name": "DESKTOP-TEST$",
  "subject.account_domain": "WORKGROUP",
  "subject.logon_id": "0x3e7",
  "user.security_id": "S-XXX-YYY-ZZZ",
  "user.account_name": "Administrator",
  "user.account_domain": "DESKTOP-TEST",
  "process_information.process_id": "0xbac",
  "process_information.process_name": "C:\\Windows\\System32\\svchost.exe"
}
```

NOTE: This feature assumes `description` field has following formats:

- group delimiter: `\r\n\r\n`
- record delimiter: `\r\n\t`
- field delimiter: `\t\t`

If your `description` doesn't follow this format, the parsed result is only `description_title` field with same `description` content.

## Copyright
### Copyright
Copyright(C) 2014- @okahashi117
### License
Apache License, Version 2.0
