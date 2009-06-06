require 'gcal4ruby/recurrence'

module GCal4Ruby
  class Event
    attr_accessor :title, :content, :where, :transparency, :status, :id
    attr_reader :start, :end, :edit_feed
    @exists = false
    @calendar = nil
    @xml = nil
    @etag = nil
    @recurrence = nil
    @deleted = false
    
    def recurrence
      @recurrence
    end
    
    def recurrence=(r)
      r.event = self
      @recurrence = r
    end
    
    def copy()
      e = Event.new()
      e.load(to_xml)
      e.calendar = @calendar
      return e
    end
    
    def start=(str)
      if str.class == String
        @start = Time.parse(str)      
      elsif str.class == Time
        @start = str
      else
        raise "Start Time must be either Time or String"
      end
    end
    
    def end=(str)
      if str.class == String
        @end = Time.parse(str)      
      elsif str.class == Time
        @end = str
      else
        raise "End Time must be either Time or String"
      end
    end
    
    def delete
        if @exists    
          if @calendar.service.send_delete(@edit_feed, {"If-Match" => @etag})
            @exists = false
            @deleted = true
            @title = nil
            @content = nil
            @id = nil
            @start = nil
            @end = nil
            @transparency = nil
            @status = nil
            @where = nil
            return true
          else
            return false
          end
        else
          return false
        end
    end
    
    def initialize(calendar)
      super()
      @xml = EVENT_XML
      @calendar = calendar
      @title = nil
      @content = nil
      @start = nil
      @end = nil
      @where = nil
      @transparency = "http://schemas.google.com/g/2005#event.opaque"
      @status = "http://schemas.google.com/g/2005#event.confirmed"
    end
    
    def save
      if @deleted
        return false
      end
      if @exists 
        ret = @calendar.service.send_put(@edit_feed, to_xml, {'Content-Type' => 'application/atom+xml', "If-Match" => @etag})
      else
        ret = @calendar.service.send_post(@calendar.event_feed, to_xml, {'Content-Type' => 'application/atom+xml'})
      end
      if !@exists
        if load(ret.read_body)
          return true
        else
          raise EventSaveFailed
        end
      end
      return true
    end
    
    def to_xml()
      xml = REXML::Document.new(@xml)
      xml.root.elements.each(){}.map do |ele|
        case ele.name
        when 'id'
          ele.text = @id
        when "title"
          ele.text = @title
        when "content"
          ele.text = @content
        when "when"
          if not @recurrence
            ele.attributes["startTime"] = @start.xmlschema
            ele.attributes["endTime"] = @end.xmlschema
          else
            xml.root.delete_element("/entry/gd:when")
            xml.root.add_element("gd:recurrence").text = @recurrence.to_s
          end
        when "eventStatus"
          ele.attributes["value"] = @status
        when "transparency"
          ele.attributes["value"] = @transparency
        when "where"
          ele.attributes["valueString"] = @where
        end
      end
      xml.to_s
    end
    
    def load(text)
      @xml = text
      @exists = true
      xml = REXML::Document.new(text)
      @etag = xml.root.attributes['etag']
      xml.root.elements.each(){}.map do |ele|
          case ele.name
             when 'id'
                @id, @edit_feed = ele.text
             when 'title'
                @title = ele.text
              when 'content'
                @content = ele.text
              when "transparency"
                @transparency = ele.attributes['value']
              when "eventStatus"
                @status = ele.attributes['value']
              when "when"
                @start = Time.parse(ele.attributes['startTime'])
                @end = Time.parse(ele.attributes['endTime'])
              when "where"
                @where = ele.attributes['valueString']
              when "link"
                if ele.attributes['rel'] == 'edit'
                  @edit_feed = ele.attributes['href']
                end
            end      
        end
    end
    
    def reload
      t = Event.find(service, :first, @id)
      if t
        load(t.xml)
      else
        return false
      end
    end
    
    
    def self.find(calendar, term, scope = :all)
        events = calendar.service.send_get("http://www.google.com/calendar/feeds/#{calendar.id}/private/full?q="+CGI.escape(term))
        ret = []
        REXML::Document.new(events.read_body).root.elements.each("entry"){}.map do |entry|
          entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
          entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
          entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
          event = Event.new(calendar)
          event.load("<?xml version='1.0' encoding='UTF-8'?>#{entry.to_s}")
          ret << event
      end
      if scope == :all
        return ret
      elsif scope == :first
        return ret[0]
      end
      return false
    end
  
  
end

end

