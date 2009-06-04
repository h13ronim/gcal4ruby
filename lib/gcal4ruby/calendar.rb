require 'gcal4ruby/event'

module GCal4Ruby

class Calendar
  CALENDAR_FEED = "http://www.google.com/calendar/feeds/default/owncalendars/full"
  attr_accessor :title, :summary, :service, :id, :hidden, :timezone, :color, :where, :selected, :xml
  attr_reader :event_feed, :edit_feed
  @exists = false
  @public = false
  @event_feed = ''
  @edit_feed = ''
  
  def exists?
    return @exists
  end
  
  def public?
    return @public
  end
  
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
  end
  
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
  
  def self.find(service, term, scope = :all)
    t = term.downcase
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
  
  def reload
    t = Calendar.find(service, @id, :first)
    if t
      load(t.xml)
    else
      return false
    end
  end
  
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

  def load(text)
    @exists = true
    @xml = text
    xml = REXML::Document.new(text)
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
  
  def to_iframe()
    
  end
  
end 

end