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
