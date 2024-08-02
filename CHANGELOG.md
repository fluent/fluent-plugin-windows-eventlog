# Release v0.9.0 - 2024/08/02
* in_windows_eventlog2: Enable expanding user names from SID and add `preserve_sid_on_hash` option
* in_windows_eventlog2: Add Delimiter and Casing options for parsing
* in_windows_eventlog2: Not to load WinevtXMLparser by default
* in_windows_eventlog2: Make it possible to work without Nokogiri

# Release v0.8.3 - 2023/01/19
* Permit using nokogiri 1.14.0

# Release v0.8.2 - 2022/09/26
* in_windows_eventlog2: Skip to subscribe non existent channels, not to stop Fluentd

# Release v0.8.1 - 2021/09/16
* in_windows_eventlog2: Add trace logs for debugging
* in_windows_eventlog2: Support event query parameter on Windows EventLog channel subscriptions

# Release v0.8.0 - 2020/09/16
* in_windows_eventlog2: Support remoting access

# Release v.0.7.1.rc1 - 2020/06/23
* in_windows_eventlog2: Depends on nokogiri 1.11 series

# Release v0.7.0 - 2020/05/22
* in_windows_eventlog2: Support multilingual description

# Release v0.6.0 - 2020/04/15
* Make fluent-plugin-parser-winevt_xml plugin as optional dependency
* in_windows_eventlog2: Render Ruby hash object directly by default

# Release v0.5.4 - 2020/04/10
* Permit using nokogiri 1.11.0

# Release v0.5.3 - 2020/03/17
* in_windows_eventlog2: Add Qualifiers key handling options

# Release v0.5.2 - 2020/02/28
* in_windows_eventlog2: Add parameter to read from all channels shortcut

# Release v0.5.1 - 2020/02/26
* in_windows_eventlog2: Add empty bookmark checking mechanism

# Release v0.5.0 - 2020/02/17
* in_windows_eventlog2: Support subscribe directive to handle read_existing_events paratemer each of channels.
* in_windows_eventlog2: Depends on winevt_c v0.7.0 or later.

# Release v0.4.6 - 2020/02/15
* Fix winevt_c dependency to prevent fetching winevt_c v0.7.0 or later.

# Release v0.4.5 - 2020/01/28
* in_windows_eventlog2: Handle empty key case in parsing description method.

# Release v0.4.4 - 2019/11/07
* in_windows_eventlog: Improve error handling and logging when failed to open Windows Event Log.

# Release v0.4.3 - 2019/10/31
* in_windows_eventlog2: Handle privileges record on #parse_desc
* in_windows_eventlog2: Raise error when handling invalid bookmark xml

# Release v0.4.2 - 2019/10/16
* in_windows_eventlog2: Handle invalid data error from `Winevt::EventLog::Query::Error`

# Release v0.4.1 - 2019/10/11
* in_windows_eventlog2: Add a missing ProcessID record

# Release v0.4.0 - 2019/10/10

* in_windows_eventlog2: Add new `render_as_xml` parameter to switch rendering as XML or Ruby Hash object
* in_windows_eventlog2: Support rate limit with `rate_limit` option
* parser_winevt_xml: Separate `parser_winevt_xml` plugin to other repository and published as Fluentd parser plugin

# Release v0.3.0 - 2019/07/08

* Add new `in_windows_eventlog2` plugin. This plugin uses newer windows event logging API.
* Add `winevt_c` and `nokogiri` gem dependency for `in_windows_eventlog2`

# Release v0.2.2 - 2017/09/08

* in_windows_eventlog: Add `parse_description` parameter

# Release v0.2.1 - 2017/06/06

* in_windows_eventlog: Add `string_inserts` to the resulting record

# Release v0.2.0 - 2017/03/08

* in_windows_eventlog: Use v1 API
