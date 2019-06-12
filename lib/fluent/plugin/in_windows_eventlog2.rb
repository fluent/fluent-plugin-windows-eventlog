require 'winevt'
require 'fluent/plugin/input'
require 'fluent/plugin'

module Fluent::Plugin
  class WindowsEventLog2Input < Input
    Fluent::Plugin.register_input('windows_eventlog2', self)

    helpers :timer

    config_param :tag, :string
    config_param :read_interval, :time, default: 2
    config_param :channels, :array, default: ['application']
    config_param :read_from_head, :bool, default: false

    def initalize
      super
      @chs = []
    end

    def configure(conf)
      super
      @chs = @channels.map {|ch| ch.strip.downcase }.uniq

      @tag = tag
      @tailing = @read_from_head ? false : true
    end

    def start
      super

      @chs.each do |ch|
        subscribe = Winevt::EventLog::Subscribe.new
        subscribe.tail = @tailing
        subscribe.subscribe(ch, "*")
        timer_execute("in_windows_eventlog_#{escape_channel(ch)}".to_sym, @read_interval) do
          on_notify(subscribe)
        end
      end
    end

    def escape_channel(ch)
      ch.gsub(/[^a-zA-Z0-9]/, '_')
    end

    def on_notify(subscribe)
      es = Fluent::MultiEventStream.new
      subscribe.each do |xml|
        es.add(Fluent::Engine.now, xml)
      end
      router.emit_stream(@tag, es)
    end
  end
end
