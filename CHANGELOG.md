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
