
require 'win32/eventlog'
include Win32

module Fluent
  class WinEvtLog < Fluent::Input
    Fluent::Plugin.register_input('winevtlog', self)

    @@KEY_MAP = {"record_number" => :record_number, 
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
    config_param :read_interval, :time, :default => 2
    config_param :pos_file, :string, :default => nil
    config_param :category, :string, :default => 'Application' 
    config_param :keys, :string, :default => ''
    config_param :read_from_head, :bool, :default => false

    attr_reader :cats

    def initialize
      super
      @cats = []
      @keynames = []
      @tails = {}
    end

    def configure(conf)
      super
      @cats = @category.split(',').map {|cat| cat.strip }.uniq
      if @cats.empty?
        raise ConfigError, "winevtlog: 'category' parameter is required on winevtlog input"
      end
      @keynames = @keys.split(',').map {|k| k.strip }.uniq
      if @keynames.empty?
        @keynames = @@KEY_MAP.keys
      end
      @tag = tag
      @stop = false
    end

    def start
      if @pos_file
        @pf_file = File.open(@pos_file, File::RDWR|File::CREAT|File::BINARY, DEFAULT_FILE_PERMISSION)
        @pf_file.sync = true
        @pf = PositionFile.parse(@pf_file)
      end
      @loop = Coolio::Loop.new
      start_watchers(@cats)
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      stop_watchers(@tails.keys, true)
      @loop.stop rescue nil
      @thread.join
      @pf_file.close if @pf_file
    end

    def setup_wacther(cat, pe)
      wlw = WindowsLogWatcher.new(cat, pe, &method(:receive_lines))
      wlw.attach(@loop)
      wlw
    end

    def start_watchers(cats)
      cats.each { |cat|
        pe = nil
        if @pf
          pe = @pf[cat]
          if @read_from_head && pe.read_num.zero?
            el = EventLog.open(cat)
            pe.update(el.oldest_record_number-1,1)
            el.close
          end
        end
        @tails[cat] = setup_wacther(cat, pe)
      }
    end

    def stop_watchers(cats, unwatched = false)
      cats.each { |cat|
        wlw = @tails.delete(cat)
        if wlw
          wlw.unwatched = unwatched
          close_watcher(wlw)
        end
      }
    end

    def close_watcher(wlw)
      wlw.close
      # flush_buffer(wlw)
    end

    def run
      @loop.run
    rescue
      $log.error "unexpected error", :error=>$!.to_s
      $log.error_backtrace
    end

    def receive_lines(lines, pe)
      return if lines.empty?
      begin
        for r in lines
          h = Hash[@keynames.map {|k| [k, r.send(@@KEY_MAP[k])]}]
          Engine.emit(@tag, Engine.now, h)
          pe[1] +=1
        end
      rescue
        $log.error "unexpected error", :error=>$!.to_s
        $log.error_backtrace
      end
    end


    class WindowsLogWatcher
      def initialize(cat, pe, &receive_lines)
        @cat = cat
        @pe = pe || MemoryPositionEntry.new
        @receive_lines = receive_lines
        @timer_trigger = TimerWatcher.new(1, true, &method(:on_notify))
      end

      attr_reader   :cat
      attr_accessor :unwatched
      attr_accessor :pe

      def attach(loop)
        @timer_trigger.attach(loop)
        on_notify
      end

      def detach
        @timer_trigger.detach if @timer_trigger.attached?
      end

      def close
        detach
      end

      def on_notify
        el = EventLog.open(@cat)
        rl_sn = [el.oldest_record_number, el.total_records]
        pe_sn = [@pe.read_start, @pe.read_num]
        # if total_records is zero, oldest_record_number has no meaning.
        if rl_sn[1] == 0
          return
        end
        
        if pe_sn[0] == 0 && pe_sn[1] == 0
          @pe.update(rl_sn[0], rl_sn[1])
          return
        end

        cur_end = rl_sn[0] + rl_sn[1] -1
        old_end = pe_sn[0] + pe_sn[1] -1

        if (rl_sn[0] < pe_sn[0])
          # may be a record number rotated.
          cur_end += 0xFFFFFFFF
        end

        if (cur_end <= old_end)
          # something occured.
          @pe.update(rl_sn[0], rl_sn[1])
          return
        end

        read_more = false
        begin
          numlines = cur_end - old_end
          winlogs = el.read(Windows::Constants::EVENTLOG_SEEK_READ | Windows::Constants::EVENTLOG_FORWARDS_READ, old_end + 1)
          @receive_lines.call(winlogs, pe_sn)
          @pe.update(pe_sn[0], pe_sn[1])
          old_end = pe_sn[0] + pe_sn[1] -1
        end while read_more
        el.close
        
      end

      class TimerWatcher < Coolio::TimerWatcher
        def initialize(interval, repeat, &callback)
          @callback = callback
          super(interval, repeat)
        end

        def on_timer
          @callback.call
        rescue
          # TODO log?
          $log.error $!.to_s
          $log.error_backtrace
        end
      end
    end

    class PositionFile
      def initialize(file, map, last_pos)
        @file = file
        @map = map
        @last_pos = last_pos
      end

      def [](cat)
        if m = @map[cat]
          return m
        end
        @file.pos = @last_pos
        @file.write cat
        @file.write "\t"
        seek = @file.pos
        @file.write "00000000\t00000000\n"
        @last_pos = @file.pos
        @map[cat] = FilePositionEntry.new(@file, seek)
      end

      # parsing file and rebuild mysself
      def self.parse(file)
        map = {}
        file.pos = 0
        file.each_line {|line|
          # check and get a matched line as m
          m = /^([^\t]+)\t([0-9a-fA-F]+)\t([0-9a-fA-F]+)/.match(line)
          next unless m
          cat = m[1] 
          pos = m[2].to_i(16)
          seek = file.pos - line.bytesize + cat.bytesize + 1
          map[cat] = FilePositionEntry.new(file, seek)
        }
        new(file, map, file.pos)
      end
    end

    class FilePositionEntry
      START_SIZE = 8
      NUM_OFFSET = 9
      NUM_SIZE   = 8
      LN_OFFSET = 17
      SIZE = 18

      def initialize(file, seek)
        @file = file
        @seek = seek
      end

      def update(start, num)
        @file.pos = @seek
        @file.write "%08x\t%08x" % [start, num]
      end
      
      def read_start
        @file.pos = @seek
        raw = @file.read(START_SIZE)
        raw ? raw.to_i(16) : 0
      end

      def read_num
        @file.pos = @seek + NUM_OFFSET
        raw = @file.read(NUM_SIZE)
        raw ? raw.to_i(16) : 0
      end
    end

    class MemoryPositionEntry
      def initialize
        @start = 0
        @num = 0
      end

      def update(start, num)
        @start = start
        @num = num
      end
      
      def read_start
        @start
      end

      def read_num
        @num
      end
    end

  end
end
