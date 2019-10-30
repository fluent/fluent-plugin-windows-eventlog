require 'winevt'
require 'fluent/plugin/input'
require 'fluent/plugin'

module Fluent::Plugin
  class WindowsEventLog2Input < Input
    Fluent::Plugin.register_input('windows_eventlog2', self)

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
               "Version"           => ["Version",               :string],
               "Description"       => ["Description",           :string],
               "EventData"         => ["EventData",             :array]}

    config_param :tag, :string
    config_param :read_interval, :time, default: 2
    config_param :channels, :array, default: ['application']
    config_param :keys, :array, default: []
    config_param :read_from_head, :bool, default: false
    config_param :parse_description, :bool, default: false
    config_param :render_as_xml, :bool, default: true
    config_param :rate_limit, :integer, default: Winevt::EventLog::Subscribe::RATE_INFINITE

    config_section :storage do
      config_set_default :usage, "bookmarks"
      config_set_default :@type, DEFAULT_STORAGE_TYPE
      config_set_default :persistent, true
    end

    config_section :parse do
      config_set_default :@type, 'winevt_xml'
      config_set_default :estimate_current_event, false
    end

    def initalize
      super
      @chs = []
      @keynames = []
    end

    def configure(conf)
      super
      @chs = @channels.map {|ch| ch.strip.downcase }.uniq
      @keynames = @keys.map {|k| k.strip }.uniq
      if @keynames.empty?
        @keynames = KEY_MAP.keys
      end
      @keynames.delete('Qualifiers') unless @render_as_xml
      @keynames.delete('EventData') if @parse_description

      @tag = tag
      @tailing = @read_from_head ? false : true
      @bookmarks_storage = storage_create(usage: "bookmarks")
      @winevt_xml = false
      if @render_as_xml
        @parser = parser_create
        @winevt_xml = @parser.respond_to?(:winevt_xml?) && @parser.winevt_xml?
        class << self
          alias_method :on_notify, :on_notify_xml
        end
      else
        class << self
          alias_method :on_notify, :on_notify_hash
        end
      end
    end

    def start
      super

      @chs.each do |ch|
        bookmarkXml = @bookmarks_storage.get(ch) || ""
        subscribe = Winevt::EventLog::Subscribe.new
        bookmark = unless bookmarkXml.empty?
                     Winevt::EventLog::Bookmark.new(bookmarkXml)
                   else
                     nil
                   end
        subscribe.tail = @tailing
        subscribe.subscribe(ch, "*", bookmark)
        subscribe.render_as_xml = @render_as_xml
        subscribe.rate_limit = @rate_limit
        timer_execute("in_windows_eventlog_#{escape_channel(ch)}".to_sym, @read_interval) do
          on_notify(ch, subscribe)
        end
      end
    end

    def escape_channel(ch)
      ch.gsub(/[^a-zA-Z0-9]/, '_')
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
      rescue Winevt::EventLog::Query::Error => e
        log.warn "Invalid XML data", error: e
        log.warn_backtrace
      end
      router.emit_stream(@tag, es)
      @bookmarks_storage.put(ch, subscribe.bookmark)
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
      rescue Winevt::EventLog::Query::Error => e
        log.warn "Invalid Hash data", error: e
        log.warn_backtrace
      end
      router.emit_stream(@tag, es)
      @bookmarks_storage.put(ch, subscribe.bookmark)
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
      elems.each { |elem|
        parent_key = nil
        elem.split(RECORD_DELIMITER).each { |r|
          key, value = if r.index(FIELD_DELIMITER)
                         r.split(FIELD_DELIMITER)
                       else
                         r.split(NONE_FIELD_DELIMITER)
                       end
          key.chop!  # remove ':' from key
          if value.nil?
            parent_key = to_key(key)
          else
            # parsed value sometimes contain unexpected "\t". So remove it.
            value.strip!
            if parent_key.nil?
              record[to_key(key)] = value
            else
              k = "#{parent_key}.#{to_key(key)}"
              record[k] = value
            end
          end
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
end
