require 'win32/eventlog'

class EventLog
  def initialize
    @logger = Win32::EventLog.new
    @app_source = "fluent-plugins"
  end

  def info(event_id, message)
    @logger.report_event(
      source: @app_source,
      event_type: Win32::EventLog::INFO_TYPE,
      event_id: event_id,
      data: message
    )
  end

  def warn(event_id, message)
    @logger.report_event(
      source: @app_source,
      event_type: Win32::EventLog::WARN_TYPE,
      event_id: event_id,
      data: message
    )
  end

  def crit(event_id, message)
    @logger.report_event(
      source: @app_source,
      event_type: Win32::EventLog::ERROR_TYPE,
      event_id: event_id,
      data: message
    )
  end

end

module Fluent
  module Plugin
    class EventService
      def run
        eventlog = EventLog.new()
        eventlog.info(65500, "Hi, from fluentd-plugins!! at " + Time.now.strftime("%Y/%m/%d %H:%M:%S "))
      end
    end
  end
end
