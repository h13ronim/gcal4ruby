require 'gcal4ruby/recurrence'

module GCal4Ruby
  #The Event Class represents a remote event in calendar.
  class Event
    attr_accessor :title
    attr_accessor :content
    attr_accessor :where
    attr_accessor :transparency
    attr_accessor :status
    attr_accessor :id
    
    attr_reader :start
    attr_reader :end
    
    #Returns the current event's Recurrence information
    def recurrence
      @recurrence
    end
    
    #Sets the event's recurrence information to a Recurrence object.  Returns true if successful,
    #false otherwise
    def recurrence=(r)
      if r.is_a?(Recurrence)
        r.event = self
        @recurrence = r
        return true
      else
        return false
      end
    end
    
    #Returns a duplicate of the current event as a new Event object
    def copy()
      e = Event.new()
      e.load(to_xml)
      e.calendar = @calendar
      return e
    end
    
    #Sets the start time of the Event.  Must be a Time object or a parsable string representation
    #of a time.
    def start=(str)
      if str.class == String
        @start = Time.parse(str)      
      elsif str.class == Time
        @start = str
      else
        raise "Start Time must be either Time or String"
      end
    end
    
    #Sets the end time of the Event.  Must be a Time object or a parsable string representation
    #of a time.
    def end=(str)
      if str.class == String
        @end = Time.parse(str)      
      elsif str.class == Time
        @end = str
      else
        raise "End Time must be either Time or String"
      end
    end
    
    #Deletes the event from the Google Calendar Service.  All values are cleared.
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
    
    #Creates a new Event.  Accepts a valid Calendar object.
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
    
    #If the event does not exist on the Google Calendar service, save creates it.  Otherwise
    #updates the existing event data.  Returns true on success, false otherwise.
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
    
    #Returns an XML representation of the event.
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
    
    #Loads the event info from an XML string.
    def load(string)
      @xml = string
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
    
    #Reloads the event data from the Google Calendar Service.  Returns true if successful,
    #false otherwise.
    def reload
      t = Event.find(service, :first, @id)
      if t
        if load(t.xml)
         return true
        else
         return false
        end
      else
        return false
      end
    end
    
    #Finds the event that matches search_term in title or description full text search.  The scope parameter can
    #be either :all to return an array of all matches, or :first to return the first match as an Event. 
    def self.find(calendar, search_term, scope = :all)
        events = calendar.service.send_get("http://www.google.com/calendar/feeds/#{calendar.id}/private/full?q="+CGI.escape(search_term))
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
    
    #Returns true if the event exists on the Google Calendar Service.
    def exists?
      return @exists
    end
  
    private 
    @exists = false
    @calendar = nil
    @xml = nil
    @etag = nil
    @recurrence = nil
    @deleted = false
    @edit_feed = ''
end

end

