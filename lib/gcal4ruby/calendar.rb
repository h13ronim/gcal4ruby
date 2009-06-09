require 'gcal4ruby/event'

module GCal4Ruby
#The Calendar Class is the representation of a Google Calendar.  Each user account 
#can have multiple calendars.  You must have an authenticated Service object before 
#using the Calendar object.
#=Usage
#All usages assume a successfully authenticated Service.
#1. Create a new Calendar
#    cal = Calendar.new(service)
#
#2. Find an existing Calendar
#    cal = Calendar.find(service, "New Calendar", :first)
#
#3. Find all calendars containing the search term
#    cal = Calendar.find(service, "Soccer Team")
#
#4. Find a calendar by ID
#    cal = Calendar.find(service, id, :first)
#
#After a calendar object has been created or loaded, you can change any of the 
#attributes like you would any other object.  Be sure to save the calendar to write changes
#to the Google Calendar service.

class Calendar
  CALENDAR_FEED = "http://www.google.com/calendar/feeds/default/owncalendars/full"
  
  #The calendar title
  attr_accessor :title
  
  #A short description of the calendar
  attr_accessor :summary
  
  #The parent Service object passed on initialization
  attr_reader :service
  
  #The unique calendar id
  attr_reader :id
  
  #Boolean value indicating the calendar visibility
  attr_accessor :hidden
  
  #The calendar timezone[http://code.google.com/apis/calendar/docs/2.0/reference.html#gCaltimezone]
  attr_accessor :timezone
  
  #The calendar color.  Must be one of these[http://code.google.com/apis/calendar/docs/2.0/reference.html#gCalcolor] values.
  attr_accessor :color
  
  #The calendar geo location, if any
  attr_accessor :where
  
  #A boolean value indicating whether the calendar appears by default when viewed online
  attr_accessor :selected
  
  #The event feed for the calendar
  attr_reader :event_feed
  
  #Returns true if the calendar exists on the Google Calendar system (i.e. was 
  #loaded or has been saved).  Otherwise returns false.
  def exists?
    return @exists
  end
  
  #Returns true if the calendar is publically accessable, otherwise returns false.
  def public?
    return @public
  end
  
  #Returns an array of Event objects corresponding to each event in the calendar.
  def events
    events = []
    ret = @service.send_get(@event_feed)
    REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
      entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
      entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
      entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
      e = Event.new(self)
      if e.load(entry.to_s)
        events << e
      end
    end
    return events
  end
  
  #Set the calendar to public (p = true) or private (p = false).  Publically viewable
  #calendars can be accessed by anyone without having to log in to google calendar.  See
  #Calendar#to_iframe for options to display a public calendar in a webpage.
  def public=(p)
    if p
      permissions = 'http://schemas.google.com/gCal/2005#read' 
    else
      permissions = 'none'
    end
    
    #if p != @public
      path = "http://www.google.com/calendar/feeds/#{@id}/acl/full/default"
      request = REXML::Document.new(ACL_XML)
      request.root.elements.each() do |ele|
        if ele.name == 'role'
          ele.attributes['value'] = permissions
        end
        
      end
      if @service.send_put(path, request.to_s, {"Content-Type" => "application/atom+xml", "Content-Length" => request.length.to_s})
        @public = p
        return true
      else
        return false
      end
    #end
  end

  #Accepts a Service object.  Returns the new Calendar if successful, otherwise raises the InvalidService
  #error.
  def initialize(service)
    super()
    if !service.is_a?(Service)
      raise InvalidService
    end
    @xml = CALENDAR_XML
    @service = service
    @exists = false
    @title = ""
    @summary = ""
    @public = false
    @id = nil
    @hidden = false
    @timezone = "America/Los_Angeles"
    @color = "#2952A3"
    @where = ""
    return true
  end
  
  #Deletes a calendar.  If successful, returns true, otherwise false.  If successful, the
  #calendar object is cleared.
  def delete
    if @exists    
      if @service.send_delete(CALENDAR_FEED+"/"+@id)
        @exists = false
        @title = nil
        @summary = nil
        @public = false
        @id = nil
        @hidden = false
        @timezone = nil
        @color = nil
        @where = nil
        return true
      else
        return false
      end
    else
      return false
    end
  end
  
  #If the calendar does not exist, creates it, otherwise updates the calendar info.  Returns
  #true if the save is successful, otherwise false.
  def save
    if @exists
      ret = service.send_put(@edit_feed, to_xml(), {'Content-Type' => 'application/atom+xml'})
    else
      ret = service.send_post(CALENDAR_FEED, to_xml(), {'Content-Type' => 'application/atom+xml'})
    end
    if !@exists
      if load(ret.read_body)
        return true
      else
        raise CalendarSaveFailed
      end
    end
    return true
  end
  
  #Class method for querying the google service for specific calendars.  The service parameter
  #should be an appropriately authenticated Service. The term parameter can be any string.  The
  #scope parameter may be either :all to return an array of matches, or :first to return 
  #the first match as a Calendar object.
  def self.find(service, query_term, scope = :all)
    t = query_term.downcase
    cals = service.calendars
    ret = []
    cals.each do |cal|
      title = cal.title || ""
      summary = cal.summary || ""
      id = cal.id || ""
      if title.downcase.match(t) or summary.downcase.match(t) or id.downcase.match(t)
        if scope == :first
          return cal
        elsif scope == :all
          ret << cal
        end
      end
    end
    ret
  end
  
  #Reloads the calendar objects information from the stored server version.  Returns true
  #if successful, otherwise returns false.  Any information not saved will be overwritten.
  def reload
    if not @exists
      return false
    end  
    t = Calendar.find(service, @id, :first)
    if t
      load(t.xml)
    else
      return false
    end
  end
  
  #Returns the xml representation of the Calenar.
  def to_xml
    xml = REXML::Document.new(@xml)
    xml.root.elements.each(){}.map do |ele|
      case ele.name
      when "title"
        ele.text = @title
      when "summary"
        ele.text = @summary
      when "timezone"
        ele.attributes["value"] = @timezone
      when "hidden"
        ele.attributes["value"] = @hidden
      when "color"
        ele.attributes["value"] = @color
      when "selected"
        ele.attributes["value"] = @selected
      end
    end
    xml.to_s
  end

  #Loads the Calendar with returned data from Google Calendar feed.  Returns true if successful.
  def load(string)
    @exists = true
    @xml = string
    xml = REXML::Document.new(string)
    xml.root.elements.each(){}.map do |ele|
      case ele.name
        when "id"
          @id = ele.text.gsub("http://www.google.com/calendar/feeds/default/calendars/", "")
        when 'title'
          @title = ele.text
        when 'summary'
          @summary = ele.text
        when "color"
          @color = ele.attributes['value']
        when 'hidden'
          @hidden = ele.attributes["value"] == "true" ? true : false
        when 'timezone'
          @timezone = ele.attributes["value"]
        when "selected"
          @selected = ele.attributes["value"] == "true" ? true : false
        when "link"
          if ele.attributes['rel'] == 'edit'
            @edit_feed = ele.attributes['href']
          end
      end
    end
    
    @event_feed = "http://www.google.com/calendar/feeds/#{@id}/private/full"
    
    puts "Getting ACL Feed" if @service.debug
    ret = @service.send_get("http://www.google.com/calendar/feeds/#{@id}/acl/full/")
    r = REXML::Document.new(ret.read_body)
    r.root.elements.each("entry") do |ele|
      ele.elements.each do |e|
        #puts "e = "+e.to_s if @service.debug
        #puts "previous element = "+e.previous_element.to_s if @service.debug
        if e.name == 'role' and e.previous_element.name == 'scope' and e.previous_element.attributes['type'] == 'default'
          if e.attributes['value'].match('#read')
            @public = true
          else
            @public = false
          end
        end
      end
    end
    return true
  end
  
  #Returns a HTML <iframe> tag displaying the calendar.
  def to_iframe(height=300, width=400)
    
  end
  
  private
  @xml 
  @exists = false
  @public = false
  @event_feed = ''
  @edit_feed = ''
  
end 

end