require 'winevt'
require 'fluent/plugin/input'
require 'fluent/plugin'

module Fluent::Plugin
  class WindowsEventLog2Input < Input
    Fluent::Plugin.register_input('windows_eventlog2', self)

    helpers :timer, :storage, :parser

    DEFAULT_STORAGE_TYPE = 'local'

    config_param :tag, :string
    config_param :read_interval, :time, default: 2
    config_param :channels, :array, default: ['application']
    config_param :read_from_head, :bool, default: false
    config_param :from_encoding, :string, default: nil
    config_param :encoding, :string, default: nil
    config_param :parse_description, :bool, default: false

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
    end

    def configure(conf)
      super
      @chs = @channels.map {|ch| ch.strip.downcase }.uniq

      @tag = tag
      @tailing = @read_from_head ? false : true
      @bookmarks_storage = storage_create(usage: "bookmarks")
      @parser = parser_create
      configure_encoding
      @message_handler = if @encoding
                           method(:encode_record)
                         else
                           method(:no_encode_record)
                          end

    end

    #### These lines copied from in_windows_eventlog plugin:
    #### https://github.com/fluent/fluent-plugin-windows-eventlog/blob/528290d896a885c7721f850943daa3a43a015f3d/lib/fluent/plugin/in_windows_eventlog.rb#L74-L105
    def configure_encoding
      unless @encoding
        if @from_encoding
          raise Fluent::ConfigError, "windows_eventlog: 'from_encoding' parameter must be specied with 'encoding' parameter."
        end
      end

      @encoding = parse_encoding_param(@encoding) if @encoding
      @from_encoding = parse_encoding_param(@from_encoding) if @from_encoding
    end

    def parse_encoding_param(encoding_name)
      begin
        Encoding.find(encoding_name) if encoding_name
      rescue ArgumentError => e
        raise Fluent::ConfigError, e.message
      end
    end

    def encode_record(record)
      if @encoding
        if @from_encoding
          record.encode!(@encoding, @from_encoding)
        else
          record.force_encoding(@encoding)
        end
      end
    end

    def no_encode_record(record)
      record
    end
    ####

    def start
      super

      @chs.each do |ch|
        bookmarkXml = @bookmarks_storage.get(ch) || ""
        subscribe = Winevt::EventLog::Subscribe.new
        bookmark = Winevt::EventLog::Bookmark.new(bookmarkXml)
        subscribe.tail = @tailing
        subscribe.subscribe(ch, "*", bookmark)
        timer_execute("in_windows_eventlog_#{escape_channel(ch)}".to_sym, @read_interval) do
          on_notify(ch, subscribe)
        end
      end
    end

    def escape_channel(ch)
      ch.gsub(/[^a-zA-Z0-9]/, '_')
    end

    def on_notify(ch, subscribe)
      es = Fluent::MultiEventStream.new
      subscribe.each do |xml, message|
        @parser.parse(xml) do |time, record|
          if message && !message.empty?
            message = message.gsub(/(%\d+)/, '\1$s')
            record["Description"] = @message_handler.call(sprintf(message, *record["EventData"]))
            parse_desc(record) if @parse_description
          end
          es.add(Fluent::Engine.now, record)
        end
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
      desc = record.delete('Description'.freeze)
      return if desc.nil?
      record.delete("EventData")

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
