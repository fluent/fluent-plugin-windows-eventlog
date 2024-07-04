# fluent-plugin-windows-eventlog

## Component

### fluentd Input plugin for the Windows Event Log

[Fluentd](https://www.fluentd.org/) plugin to read the Windows Event Log.

This repository contains 2 Fluentd plugins:

* in_windows_eventlog
* in_windows_eventlog2

The former one is obsolete, please don't use in newly deployment.

This document describes about the later one.
If you want to know about the obsolete one, please see [in_windows_eventlog(old).md](in_windows_eventlog(old).md)

## Installation
    ridk exec gem install fluent-plugin-windows-eventlog

## in_windows_eventlog2

Fluentd Input plugin for the Windows Event Log using newer Windows Event Logging API. This is successor to [in_windows_eventlog](in_windows_eventlog(old).md). See also [this slide](https://www.slideshare.net/cosmo0920/fluentd-meetup-2019) for the details of `in_windows_eventlog2` plugin.

## Configuration

    <source>
      @type windows_eventlog2
      @id windows_eventlog2
      channels application,system # Also be able to use `<subscribe>` directive.
      read_existing_events false
      read_interval 2
      tag winevt.raw
      render_as_xml false       # default is false.
      rate_limit 200            # default is -1(Winevt::EventLog::Subscribe::RATE_INFINITE).
      # preserve_qualifiers_on_hash true # default is false.
      # read_all_channels false # default is false.
      # description_locale en_US # default is nil. It means that system locale is used for obtaining description.
      # refresh_subscription_interval 10m # default is nil. It specifies refresh interval for channel subscriptions.
      # event_query "Event/System[EventID!=1001]" # default is "*".
      <storage>
        @type local             # @type local is the default.
        persistent true         # default is true. Set to false to use in-memory storage.
        path ./tmp/storage.json # This is required when persistent is true. If migrating from eventlog v1 please ensure that you remove the old .pos folder
                                # Or, please consider using <system> section's `root_dir` parameter.
      </storage>
      # <parse> # Note: parsing is only available when render_as_xml true
      #  @type winevt_xml # @type winevt_xml is the default. winevt_xml and none parsers are supported for now.
        # When set up it as true, this plugin preserves "Qualifiers" and "EventID" keys.
        # When set up it as false, this plugin calculates actual "EventID" from "Qualifiers" and removing "Qualifiers".
        # With the following equation:
        # (EventID & 0xffff) | (Qualifiers & 0xffff) << 16
        # preserve_qualifiers true # preserve_qualifiers_on_hash can be used as a setting outside <parse> if render_as_xml is false
      # </parse>
      # <subscribe>
      #   channles application, system
      #   read_existing_events false # read_existing_events should be applied each of subscribe directive(s)
      #   remote_server 127.0.0.1 # Remote server ip/fqdn
      #   remote_domain WORKGROUP # Domain name
      #   remote_username fluentd # Remoting access account name
      #   remote_password changeme! # Remoting access account password
      # </subscribe>
    </source>

**NOTE:** in_windows_eventlog2 always handles EventLog records as UTF-8 characters. Users don't have to specify encoding related parameters and they are not provided.

**NOTE:** When `Description` contains error message such as `The message resource is present but the message was not found in the message table.`, eventlog's resource file (.mui) related to error generating event is something wrong. This issue is also occurred in built-in Windows Event Viewer which is the part of Windows management tool.

**NOTE:** When `render_as_xml` as `true`, `fluent-plugin-parser-winevt_xml` plugin should be needed to parse XML rendered Windows EventLog string.

**NOTE:** If you encountered CPU spike due to massively huge EventLog channel, `rate_limit` parameter may help you. Currently, this paramter can handle the multiples of 10 or -1(`Winevt::EventLog::Subscribe::RATE_INFINITE`).

### parameters

|name      | description |
|:-----    |:-----       |
|`channels`         | (option) No default value just empty array, but 'application' is used as default due to backward compatibility. One or more of {'application', 'system', 'setup', 'security'} and other evtx, which is the brand new Windows XML Event Log (EVTX) format since Windows Vista, formatted channels. Theoritically, `in_windows_ventlog2` may read all of channels except for debug and analytical typed channels. If you want to read 'setup' or 'security' logs or some privileged channels, you must launch fluentd with administrator privileges.|
|`keys`             | (option) A subset of [keys](#read-keys) to read. Defaults to all keys.|
|`read_interval`    | (option) Read interval in seconds. 2 seconds as default.|
|`from_encoding`    | (option) Input character encoding. `nil` as default.|
|`<storage>`        | Setting for `storage` plugin for recording read position like `in_tail`'s `pos_file`.|
|`<parse>`          | Setting for `parser` plugin for parsing raw XML EventLog records. |
|`parse_description`| (option) parse `description` field and set parsed result into the record. `Description` and `EventData` fields are removed|
|`read_from_head`   | **Deprecated** (option) Start to read the entries from the oldest, not from when fluentd is started. Defaults to `false`.|
|`read_existing_events` | (option) Read the entries which already exist before fluentd is started. Defaults to `false`.|
|`render_as_xml` | (option) Render Windows EventLog as XML or Ruby Hash object directly. Defaults to `false`.|
|`rate_limit`      | (option) Specify rate limit to consume EventLog. Default is `Winevt::EventLog::Subscribe::RATE_INFINITE`.|
|`preserve_qualifiers_on_hash`      | (option) When set up it as true, this plugin preserves "Qualifiers" and "EventID" keys. When set up it as false, this plugin calculates actual "EventID" from "Qualifiers" and removing "Qualifiers". Default is `false`.|
|`read_all_channels`| (option) Read from all channels. Default is `false`|
|`description_locale`| (option) Specify description locale. Default is `nil`. See also: [Supported locales](https://github.com/fluent-plugins-nursery/winevt_c#multilingual-description) |
|`refresh_subscription_interval`|(option) It specifies refresh interval for channel subscriptions. Default is `nil`.|
|`event_query`|(option) It specifies query for deny/allow/filter events with XPath 1.0 or structured XML query. Default is `"*"` (retrieving all events).|
|`<subscribe>`          | Setting for subscribe channels. |

#### subscribe section

|name      | description |
|:-----    |:-----       |
|`channels`             | One or more of {'application', 'system', 'setup', 'security'}. If you want to read 'setup' or 'security' logs, you must launch fluentd with administrator privileges. |
|`read_existing_events` | (option) Read the entries which already exist before fluentd is started. Defaults to `false`. |
|`remote_server` | (option) Remoting access server ip address/fqdn. Defaults to `nil`. |
|`remote_domain` | (option) Remoting access server joining domain name. Defaults to `nil`. |
|`remote_username` | (option) Remoting access access account's username. Defaults to `nil`. |
|`remote_password` | (option) Remoting access access account's password. Defaults to `nil`. |


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
  channels ["Application", "Security"]
  # read_existing_events false
</subscribe>
<subscribe>
  channels ["HardwareEvent"]
  read_existing_events true
</subscribe>
```

This configuration can be handled as:

* "Application" and "Security" channels just tailing
* "HardwareEvent" channel read existing events before launching Fluentd

##### Remoting access

`<subscribe>` section supports remoting access parameters:

* `remote_server`
* `remote_domain`
* `remote_username`
* `remote_password`

These parameters are only in `<subscribe>` directive.

Note that before using this feature, remoting access users should belong to "Event Log Readers" group:

```console
> net localgroup "Event Log Readers" <domain\username> /add
```

And then, users also should set up their remote box's Firewall configuration:

```console
> netsh advfirewall firewall set rule group="Remote Event Log Management" new enable=yes
```

As a security best practices, remoting access account _should not be administrator account_.

For graphical instructions, please refer to [Preconfigure a Machine to Collect Remote Windows Events | Sumo Logic](https://help.sumologic.com/03Send-Data/Sources/01Sources-for-Installed-Collectors/Remote-Windows-Event-Log-Source/Preconfigure-a-Machine-to-Collect-Remote-Windows-Events) document for example.

#### Available keys

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

#### `parse_description` details

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
