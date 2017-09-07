# fluent-plugin-windows-eventlog

## Component

### fluentd Input plugin for the Windows Event Log

[Fluentd](http://fluentd.org) plugin to read the Windows Event Log.

## Installation
    gem install fluent-plugin-windows-eventlog

## Configuration

### fluentd Input plugin for the Windows Event Log

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

### parameters

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

#### Available keys

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

#### `parse_description` details

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

## Copyright
### Copyright
Copyright(C) 2014- @okahashi117
### License
Apache License, Version 2.0

