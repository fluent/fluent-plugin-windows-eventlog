require 'winevt'
require 'fluent/plugin/input'
require 'fluent/plugin'
require_relative 'bookmark_sax_parser'

module Fluent::Plugin
  class WindowsEventLog2Input < Input
    Fluent::Plugin.register_input('windows_eventlog2', self)

    class ReconnectError < Fluent::UnrecoverableError; end

    helpers :timer, :storage, :parser

    DEFAULT_STORAGE_TYPE = 'local'
    KEY_MAP = {"ProviderName"      => ["ProviderName",          :string],
               "ProviderGUID"      => ["ProviderGUID",          :string],
               "EventID"           => ["EventID",               :string],
               "Qualifiers"        => ["Qualifiers",            :string],
               "Level"             => ["Level",                 :string],
               "Task"              => ["Task",                  :string],
               "Opcode"            => ["Opcode",                :string],
               "Keywords"          => ["Keywords",              :string],
               "TimeCreated"       => ["TimeCreated",           :string],
               "EventRecordID"     => ["EventRecordID",         :string],
               "ActivityID"        => ["ActivityID",            :string],
               "RelatedActivityID" => ["RelatedActivityID",     :string],
               "ProcessID"         => ["ProcessID",             :string],
               "ThreadID"          => ["ThreadID",              :string],
               "Channel"           => ["Channel",               :string],
               "Computer"          => ["Computer",              :string],
               "UserID"            => ["UserID",                :string],
               "User"              => ["User",                  :string],
               "Version"           => ["Version",               :string],
               "Description"       => ["Description",           :string],
               "EventData"         => ["EventData",             :array]}

    config_param :tag, :string
    config_param :read_interval, :time, default: 2
    config_param :channels, :array, default: []
    config_param :keys, :array, default: []
    config_param :read_from_head, :bool, default: false, deprecated: "Use `read_existing_events' instead."
    config_param :read_existing_events, :bool, default: false
    config_param :parse_description, :bool, default: false
    config_param :render_as_xml, :bool, default: false
    config_param :rate_limit, :integer, default: Winevt::EventLog::Subscribe::RATE_INFINITE
    config_param :preserve_qualifiers_on_hash, :bool, default: false
    config_param :preserve_sid_on_hash, :bool, default: true
    config_param :read_all_channels, :bool, default: false
    config_param :description_locale, :string, default: nil
    config_param :refresh_subscription_interval, :time, default: nil
    config_param :event_query, :string, default: "*"

    config_section :subscribe, param_name: :subscribe_configs, required: false, multi: true do
      config_param :channels, :array
      config_param :read_existing_events, :bool, default: false
      config_param :remote_server, :string, default: nil
      config_param :remote_domain, :string, default: nil
      config_param :remote_username, :string, default: nil
      config_param :remote_password, :string, default: nil, secret: true
    end

    config_section :storage do
      config_set_default :usage, "bookmarks"
      config_set_default :@type, DEFAULT_STORAGE_TYPE
      config_set_default :persistent, true
    end

    config_section :parse do
      config_set_default :@type, 'windows_eventlog2_dummy'
      config_set_default :estimate_current_event, false
    end

    def initalize
      super
      @chs = []
      @keynames = []
    end

    def configure(conf)
      super
      @session = nil
      @chs = []
      @subscriptions = {}
      @all_chs = Winevt::EventLog::Channel.new
      @all_chs.force_enumerate = false
      @timers = {}

      if @read_all_channels
        @all_chs.each do |ch|
          uch = ch.strip.downcase
          @chs.push([uch, @read_existing_events])
        end
      end

      @read_existing_events = @read_from_head || @read_existing_events
      if @channels.empty? && @subscribe_configs.empty? && !@read_all_channels
        @chs.push(['application', @read_existing_events, nil])
      else
        @channels.map {|ch| ch.strip.downcase }.uniq.each do |uch|
          @chs.push([uch, @read_existing_events, nil])
        end
        @subscribe_configs.each do |subscribe|
          if subscribe.remote_server
            @session = Winevt::EventLog::Session.new(subscribe.remote_server,
                                                     subscribe.remote_domain,
                                                     subscribe.remote_username,
                                                     subscribe.remote_password)

            log.debug("connect to remote box (server: #{subscribe.remote_server}) domain: #{subscribe.remote_domain} username: #{subscribe.remote_username})")
          end
          subscribe.channels.map {|ch| ch.strip.downcase }.uniq.each do |uch|
            @chs.push([uch, subscribe.read_existing_events, @session])
          end
        end
      end
      @chs.uniq!
      @keynames = @keys.map {|k| k.strip }.uniq
      if @keynames.empty?
        @keynames = KEY_MAP.keys
      end

      @tag = tag
      @bookmarks_storage = storage_create(usage: "bookmarks")
      @winevt_xml = false
      @parser = nil
      if @render_as_xml
        parser_config = @parser_configs.first
        if parser_config["@type"] == "windows_eventlog2_dummy"
          @parser = parser_create(usage: "parse_xml", type: "winevt_xml", conf: conf.elements("parse").first)
        else
          @parser = parser_create
        end
        @winevt_xml = @parser.respond_to?(:winevt_xml?) && @parser.winevt_xml?
        class << self
          alias_method :on_notify, :on_notify_xml
        end
      else
        class << self
          alias_method :on_notify, :on_notify_hash
        end
      end

      if @render_as_xml && @preserve_qualifiers_on_hash
        raise Fluent::ConfigError, "preserve_qualifiers_on_hash must be used with Hash object rendering(render_as_xml as false)."
      end
      if !@render_as_xml && !@preserve_qualifiers_on_hash
        @keynames.delete('Qualifiers')
      elsif @parser.respond_to?(:preserve_qualifiers?) && !@parser.preserve_qualifiers?
        @keynames.delete('Qualifiers')
      end
      @keynames.delete('EventData') if @parse_description
      if @render_as_xml && !@preserve_sid_on_hash
        raise Fluent::ConfigError, "preserve_sid_on_hash is effective with Hash object rendering(render_as_xml as false)."
      end
      if @render_as_xml
        @keynames.delete('User')
      end
      if !@render_as_xml && !@preserve_sid_on_hash
        @keynames.delete('UserID')
      end

      locale = Winevt::EventLog::Locale.new
      if @description_locale && unsupported_locale?(locale, @description_locale)
        raise Fluent::ConfigError, "'#{@description_locale}' is not supported. Supported locales are: #{locale.each.map{|code, _desc| code}.join(" ")}"
      end
    end

    def unsupported_locale?(locale, description_locale)
      locale.each.select {|c, _d| c.downcase == description_locale.downcase}.empty?
    end

    def start
      super

      refresh_subscriptions
      if @refresh_subscription_interval
        timer_execute(:in_windows_eventlog_refresh_subscription_timer, @refresh_subscription_interval, &method(:refresh_subscriptions))
      end
    end

    def shutdown
      super

      @subscriptions.keys.each do |ch|
        subscription = @subscriptions.delete(ch)
        if subscription
          subscription.cancel
          log.debug "channel (#{ch}) subscription is canceled."
        end
      end
    end

    def retry_on_error(channel, times: 15)
      try = 0
      begin
        log.debug "Retry to subscribe for #{channel}...." if try > 1
        try += 1
        yield
        log.info "Retry to subscribe for #{channel} succeeded." if try > 1
        try = 0
      rescue Winevt::EventLog::Subscribe::RemoteHandlerError => e
        raise ReconnectError, "Retrying limit is exceeded." if try > times
        log.warn "#{e.message}. Remaining retry count(s): #{times - try}"
        sleep 2**try
        retry
      end
    end

    def refresh_subscriptions
      clear_subscritpions

      @chs.each do |ch, read_existing_events, session|
        retry_on_error(ch) do
          begin
            ch, subscribe = subscription(ch, read_existing_events, session)
            @subscriptions[ch] = subscribe
          rescue Winevt::EventLog::ChannelNotFoundError => e
            log.warn "#{e.message}"
          end
        end
      end
      subscribe_channels(@subscriptions)
    end

    def clear_subscritpions
      @subscriptions.keys.each do |ch|
        subscription = @subscriptions.delete(ch)
        if subscription
          if subscription.cancel
            log.debug "channel (#{ch}) subscription is cancelled."
            subscription.close
            log.debug "channel (#{ch}) subscription handles are closed forcibly."
          end
        end
      end
      @timers.keys.each do |ch|
        timer = @timers.delete(ch)
        if timer
          event_loop_detach(timer)
          log.debug "channel (#{ch}) subscription watcher is detached."
        end
      end
    end

    def subscription(ch, read_existing_events, remote_session)
      bookmarkXml = @bookmarks_storage.get(ch) || ""
      bookmark = nil
      if bookmark_validator(bookmarkXml, ch)
        bookmark = Winevt::EventLog::Bookmark.new(bookmarkXml)
      end
      subscribe = Winevt::EventLog::Subscribe.new
      subscribe.read_existing_events = read_existing_events
      begin
        subscribe.subscribe(ch, event_query, bookmark, remote_session)
        if !@render_as_xml && @preserve_qualifiers_on_hash
          subscribe.preserve_qualifiers = @preserve_qualifiers_on_hash
        end
        if !@render_as_xml && !@preserve_sid_on_hash
          subscribe.preserve_sid = @preserve_sid_on_hash
        end
      rescue Winevt::EventLog::Query::Error => e
        raise Fluent::ConfigError, "Invalid Bookmark XML is loaded. #{e}"
      end
      subscribe.render_as_xml = @render_as_xml
      subscribe.rate_limit = @rate_limit
      subscribe.locale = @description_locale if @description_locale
      [ch, subscribe]
    end

    def subscribe_channels(subscriptions)
      subscriptions.each do |ch, subscribe|
        log.trace "Subscribing Windows EventLog at #{ch} channel"
        @timers[ch] = timer_execute("in_windows_eventlog_#{escape_channel(ch)}".to_sym, @read_interval) do
          on_notify(ch, subscribe)
        end
        log.debug "channel (#{ch}) subscription is subscribed."
      end
    end

    def bookmark_validator(bookmarkXml, channel)
      return false if bookmarkXml.empty?

      evtxml = WinevtBookmarkDocument.new
      parser = Nokogiri::XML::SAX::Parser.new(evtxml)
      parser.parse(bookmarkXml)
      result = evtxml.result
      if !result.empty? && (result[:channel].downcase == channel.downcase) && result[:is_current]
        true
      else
        log.warn "This stored bookmark is incomplete for using. Referring `read_existing_events` parameter to subscribe: #{bookmarkXml}, channel: #{channel}"
        false
      end
    end

    def escape_channel(ch)
      ch.gsub(/[^a-zA-Z0-9\s]/, '_')
    end

    def on_notify(ch, subscribe)
      # for safety.
    end

    def on_notify_xml(ch, subscribe)
      es = Fluent::MultiEventStream.new
      begin
        subscribe.each do |xml, message, string_inserts|
          @parser.parse(xml) do |time, record|
            # record.has_key?("EventData") for none parser checking.
            if @winevt_xml
              record["Description"] = message
              record["EventData"] = string_inserts

              h = {}
              @keynames.each do |k|
                type = KEY_MAP[k][1]
                value = record[KEY_MAP[k][0]]
                h[k]=case type
                     when :string
                       value.to_s
                     when :array
                       value.map {|v| v.to_s}
                     else
                       raise "Unknown value type: #{type}"
                     end
              end
              parse_desc(h) if @parse_description
              es.add(Fluent::Engine.now, h)
            else
              record["Description"] = message
              record["EventData"] = string_inserts
              # for none parser
              es.add(Fluent::Engine.now, record)
            end
          end
        end
        router.emit_stream(@tag, es)
        @bookmarks_storage.put(ch, subscribe.bookmark)
        log.trace "Collecting Windows EventLog from #{ch} channel. Collected size: #{es.size}"
      rescue Winevt::EventLog::Query::Error => e
        log.warn "Invalid XML data on #{ch}.", error: e
        log.warn_backtrace
      end
    end

    def on_notify_hash(ch, subscribe)
      es = Fluent::MultiEventStream.new
      begin
        subscribe.each do |record, message, string_inserts|
          record["Description"] = message
          record["EventData"] = string_inserts
          h = {}
          @keynames.each do |k|
            type = KEY_MAP[k][1]
            value = record[KEY_MAP[k][0]]
            h[k]=case type
                 when :string
                   value.to_s
                 when :array
                   value.map {|v| v.to_s}
                 else
                   raise "Unknown value type: #{type}"
                 end
          end
          parse_desc(h) if @parse_description
          es.add(Fluent::Engine.now, h)
        end
        router.emit_stream(@tag, es)
        @bookmarks_storage.put(ch, subscribe.bookmark)
        log.trace "Collecting Windows EventLog from #{ch} channel. Collected size: #{es.size}"
      rescue Winevt::EventLog::Query::Error => e
        log.warn "Invalid Hash data on #{ch}.", error: e
        log.warn_backtrace
      end
    end

    #### These lines copied from in_windows_eventlog plugin:
    #### https://github.com/fluent/fluent-plugin-windows-eventlog/blob/528290d896a885c7721f850943daa3a43a015f3d/lib/fluent/plugin/in_windows_eventlog.rb#L192-L232
    GROUP_DELIMITER = "\r\n\r\n".freeze
    RECORD_DELIMITER = "\r\n\t".freeze
    FIELD_DELIMITER = "\t\t".freeze
    NONE_FIELD_DELIMITER = "\t".freeze

    def parse_desc(record)
      desc = record.delete("Description".freeze)
      return if desc.nil?

      elems = desc.split(GROUP_DELIMITER)
      record['DescriptionTitle'] = elems.shift
      previous_key = nil
      elems.each { |elem|
        parent_key = nil
        elem.split(RECORD_DELIMITER).each { |r|
          key, value = if r.index(FIELD_DELIMITER)
                         r.split(FIELD_DELIMITER)
                       else
                         r.split(NONE_FIELD_DELIMITER)
                       end
          key = "" if key.nil?
          key.chop!  # remove ':' from key
          if value.nil?
            parent_key = to_key(key)
          else
            # parsed value sometimes contain unexpected "\t". So remove it.
            value.strip!
            # merge empty key values into the previous non-empty key record.
            if key.empty?
              record[previous_key] = [record[previous_key], value].flatten.reject {|e| e.nil?}
            elsif parent_key.nil?
              record[to_key(key)] = value
            else
              k = "#{parent_key}.#{to_key(key)}"
              record[k] = value
            end
          end
          # XXX: This is for empty privileges record key.
          # We should investigate whether an another case exists or not.
          previous_key = to_key(key) unless key.empty?
        }
      }
    end

    def to_key(key)
      key.downcase!
      key.gsub!(' '.freeze, '_'.freeze)
      key
    end
    ####
  end

  class WindowsEventLog2DummyParser < Parser
    Fluent::Plugin.register_parser('windows_eventlog2_dummy', self)

    def configure(conf)
      super
    end

    def parse(text)
      raise NotImplementedError, "This is a dummy parser for the default setting and can not be used actually."
    end
  end
end
