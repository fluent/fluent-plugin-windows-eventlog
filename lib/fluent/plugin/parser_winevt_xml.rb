require 'fluent/plugin/parser'
require 'nokogiri'

module Fluent::Plugin
  class WinevtXMLparser < Parser
    Fluent::Plugin.register_parser('winevt_xml', self)

    def parse(text)
      record = {}
      doc = Nokogiri::XML(text)
      record["ProviderName"]          = (doc/'Event'/'System'/"Provider").attribute("Name").text rescue nil
      record["ProviderGUID"]          = (doc/'Event'/'System'/"Provider").attribute("Guid").text rescue nil
      record["EventID"]               = (doc/'Event'/'System'/'EventID').text rescue nil
      record["Qualifiers"]            = (doc/'Event'/'System'/'EventID').attribute("Qualifiers").text rescue nil
      record["Level"]                 = (doc/'Event'/'System'/'Level').text rescue nil
      record["Task"]                  = (doc/'Event'/'System'/'Task').text rescue nil
      record["Opcode"]                = (doc/'Event'/'System'/'Opcode').text rescue nil
      record["Keywords"]              = (doc/'Event'/'System'/'Keywords').text rescue nil
      record["TimeCreated"]           = (doc/'Event'/'System'/'TimeCreated').attribute("SystemTime").text rescue nil
      record["EventRecordID"]         = (doc/'Event'/'System'/'EventRecordID').text rescue nil
      record["ActivityID"]            = (doc/'Event'/'System'/'ActivityID').text rescue nil
      record["RelatedActivityID"]     = (doc/'Event'/'System'/'Correlation').attribute("ActivityID").text rescue nil
      record["ThreadID"]              = (doc/'Event'/'System'/'Execution').attribute("ThreadID").text rescue nil
      record["Channel"]               = (doc/'Event'/'System'/'Channel').text rescue nil
      record["Computer"]              = (doc/'Event'/'System'/"Computer").text rescue nil
      record["UserID"]                = (doc/'Event'/'System'/"UserID").text rescue nil
      record["Version"]               = (doc/'Event'/'System'/'Version').text rescue nil
      record["EventData"]             = []
      (doc/'Event'/'EventData'/'Data').each do |elem|
        record["EventData"] << elem.text
      end
      time = @estimate_current_event ? Fluent::EventTime.now : nil
      yield time, record
    end
  end
end
