require 'win32/eventlog'
require 'fluent/plugin/input'
require 'fluent/plugin'

module Fluent::Plugin
  class WindowsEventLogInput < Input
    Fluent::Plugin.register_input('windows_eventlog', self)

    helpers :timer, :storage

    DEFAULT_STORAGE_TYPE = 'local'
    KEY_MAP = {"record_number" => :record_number,
                 "time_generated" => :time_generated,
                 "time_written" => :time_written,
                 "event_id" => :event_id,
                 "event_type" => :event_type,
                 "event_category" => :category,
                 "source_name" => :source,
                 "computer_name" => :computer,
                 "user" => :user,
                 "description" => :description}

    config_param :tag, :string
    config_param :read_interval, :time, default: 2
    config_param :pos_file, :string, default: nil,
                 obsoleted: "This section is not used anymore. Use 'store_pos' instead."
    config_param :channels, :array, default: ['Application']
    config_param :keys, :string, default: []
    config_param :read_from_head, :bool, default: false
    config_param :from_encoding, :string, default: nil
    config_param :encoding, :string, default: nil

    config_section :storage do
      config_set_default :usage, "positions"
      config_set_default :@type, DEFAULT_STORAGE_TYPE
      config_set_default :persistent, true
    end

    attr_reader :chs

    def initialize
      super
      @chs = []
      @keynames = []
      @tails = {}
    end

    def configure(conf)
      super
      @chs = @channels.map {|ch| ch.strip.downcase }.uniq
      if @chs.empty?
        raise Fluent::ConfigError, "windows_eventlog: 'channels' parameter is required on windows_eventlog input"
      end
      @keynames = @keys.map {|k| k.strip }.uniq
      if @keynames.empty?
        @keynames = KEY_MAP.keys
      end
      @tag = tag
      @stop = false
      configure_encoding
      @receive_handlers = if @encoding
                            method(:encode_record)
                          else
                            method(:no_encode_record)
                          end
      @pos_storage = storage_create(usage: "positions")
    end

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

    def start
      super
      @chs.each do |ch|
        start, num = @pos_storage.get(ch)
        if @read_from_head || (!num || num.zero?)
          el = Win32::EventLog.open(ch)
          @pos_storage.put(ch, [el.oldest_record_number - 1, 1])
          el.close
        end
        timer_execute("in_windows_eventlog_#{escape_channel(ch)}".to_sym, @read_interval) do
          on_notify(ch)
        end
      end
    end

    def escape_channel(ch)
      ch.gsub(/[^a-zA-Z0-9]/, '_')
    end

    def receive_lines(ch, lines)
      return if lines.empty?
      begin
        for r in lines
          h = {"channel" => ch}
          @keynames.each {|k| h[k]=@receive_handlers.call(r.send(KEY_MAP[k]).to_s)}
          #h = Hash[@keynames.map {|k| [k, r.send(KEY_MAP[k]).to_s]}]
          router.emit(@tag, Fluent::Engine.now, h)
        end
      rescue => e
        log.error "unexpected error", error: e
        log.error_backtrace
      end
    end

    def on_notify(ch)
      el = Win32::EventLog.open(ch)

      current_oldest_record_number = el.oldest_record_number
      current_total_records = el.total_records

      read_start, read_num = @pos_storage.get(ch)

      # if total_records is zero, oldest_record_number has no meaning.
      if current_total_records == 0
        return
      end

      if read_start == 0 && read_num == 0
        @pos_storage.put(ch, [current_oldest_record_number, current_total_records])
        return
      end

      current_end = current_oldest_record_number + current_total_records - 1
      old_end = read_start + read_num - 1

      if current_oldest_record_number < read_start
        # may be a record number rotated.
        current_end += 0xFFFFFFFF
      end

      if current_end < old_end
        # something occured.
        @pos_storage.put(ch, [current_oldest_record_number, current_total_records])
        return
      end

      winlogs = el.read(Win32::EventLog::SEEK_READ | Win32::EventLog::FORWARDS_READ, old_end + 1)
      receive_lines(ch, winlogs)
      @pos_storage.put(ch, [read_start, read_num + winlogs.size])
    ensure
      el.close
    end
  end
end
