module GCal4Ruby

  class Recurrence
    attr_reader :start, :end, :event, :day_of_week, :repeat_until, :frequency, :all_day
    def initialize
      @start = nil
      @end = nil
      @event = nil
      @day_of_week = nil
      @repeat_until = nil
      @frequency = nil
      @all_day = nil
    end
    
    def to_s
      output = ""
      #output += "<gd:recurrence>"
      if @all_day
        output += "DTSTART;VALUE=DATE:#{@start.strftime("%Y%m%d")}\n"
      else
        output += "DTSTART;VALUE=#{@start.xmlschema}\n"
      end
      if @all_day
        output += "DTEND;VALUE=DATE:#{@start.strftime("%Y%m%d")}\n"
      else
        output += "DTEND;VALUE=#{@start.xmlschema}\n"
      end
      output += "RRULE:"
      if @frequency
        output += "FREQ=#{@frequency.upcase}"
      end
      if @day_of_week
        output += ";BYDAY=#{@day_of_week}"
      end
      if @repeat_until
        output += ";UNTIL=#{@repeat_until.strftime("%Y%m%d")}"
      end
      
      output += "\n"
    end
    
    def start=(s)
      if not s.is_a?(Time)
        raise RecurrenceValueError, "Start must be a date or a time"
      else
        @start = s
      end
    end
    
    def end=(s)
      if not s.is_a?(Time)
        raise RecurrenceValueError, "End must be a date or a time"
      else
        @end = s
      end
    end
    
    def event=(e)
      if not e.is_a?(Event)
        raise RecurrenceValueError, "Event must be an event"
      else
        @event = e
      end
    end
    
    def repeat_until=(r)
      if not  r.is_a?(Date)
        raise RecurrenceValueError, "Repeat_until must be a date"
      else
        @repeat_until = r
      end
    end
    
    def frequency=(f)
      error = true
      x = ["SECONDLY", "MINUTELY", "HOURLY", "DAILY", "WEEKLY", "MONTHLY", "YEARLY"]
      x.each do |v|
        if v.downcase == f.downcase
          error = false
          break
        end
      end
      if error
        raise RecurrenceValueError, "Frequency must be one of "+x.join(" ")
      else
        @frequency = f
      end
    end
    
    def day_of_week=(d)
      error = false
      if not d.is_a?(Array)
        error = true
      else
        d.each do |x|
          if x.length != 2
            error = true
          end
        end
      end
      if error
        raise RecurrenceValueError, "Day of week must be an array of two letter day names"
      else
        @day_of_week = d
      end
    end
  end
  
  class Event
    attr_accessor :title, :content, :where, :transparency, :status, :id
    attr_reader :start, :end, :edit_feed
    @exists = false
    @calendar = nil
    @xml = nil
    @etag = nil
    @recurrence = nil
    
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

