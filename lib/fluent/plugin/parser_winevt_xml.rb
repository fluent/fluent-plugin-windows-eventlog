require 'fluent/plugin/parser'
require 'nokogiri'

module Fluent::Plugin
  class WinevtXMLparser < Parser
    Fluent::Plugin.register_parser('winevt_xml', self)

    def parse(text)
      record = {}
      doc = Nokogiri::XML(text)
      system_elem                     = doc/'Event'/'System'
      record["ProviderName"]          = (system_elem/"Provider").attribute("Name").text rescue nil
      record["ProviderGUID"]          = (system_elem/"Provider").attribute("Guid").text rescue nil
      record["EventID"]               = (system_elem/'EventID').text rescue nil
      record["Qualifiers"]            = (system_elem/'EventID').attribute("Qualifiers").text rescue nil
      record["Level"]                 = (system_elem/'Level').text rescue nil
      record["Task"]                  = (system_elem/'Task').text rescue nil
      record["Opcode"]                = (system_elem/'Opcode').text rescue nil
      record["Keywords"]              = (system_elem/'Keywords').text rescue nil
      record["TimeCreated"]           = (system_elem/'TimeCreated').attribute("SystemTime").text rescue nil
      record["EventRecordID"]         = (system_elem/'EventRecordID').text rescue nil
      record["ActivityID"]            = (system_elem/'ActivityID').text rescue nil
      record["RelatedActivityID"]     = (system_elem/'Correlation').attribute("ActivityID").text rescue nil
      record["ThreadID"]              = (system_elem/'Execution').attribute("ThreadID").text rescue nil
      record["Channel"]               = (system_elem/'Channel').text rescue nil
      record["Computer"]              = (system_elem/"Computer").text rescue nil
      record["UserID"]                = (system_elem/'Security').attribute("UserID").text rescue nil
      record["Version"]               = (system_elem/'Version').text rescue nil
      record["EventData"]             = [] # These parameters are processed in winevt_c.
      time = @estimate_current_event ? Fluent::EventTime.now : nil
      yield time, record
    end
  end
end
