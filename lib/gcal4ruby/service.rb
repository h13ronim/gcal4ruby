require 'gcal4ruby/base' 
require 'gcal4ruby/calendar'

module GCal4Ruby

#The service class is the main handler for all direct interactions with the 
#Google Calendar API.  A service represents a single user account.  Each user
#account can have multiple calendars, so you'll need to find the calendar you
#want from the service, using the Calendar#find class method.
#=Usage
#
#1. Authenticate
#    service = Service.new
#    service.authenticate("user@gmail.com", "password")
#
#2. Get Calendar List
#    calendars = service.calendars
#

class Service < Base
  #Convenience attribute contains the currently authenticated account name
  attr_reader :account
      
  # The token returned by the Google servers, used to authorize all subsequent messages
  attr_reader :auth_token

  # The authenticate method passes the username and password to google servers.  
  # If authentication succeeds, returns true, otherwise raises the AuthenticationFailed error.
  def authenticate(username, password)
    ret = nil
    ret = send_post(AUTH_URL, "Email=#{username}&Passwd=#{password}&source=GCal4Ruby&service=cl")
    if ret.class == Net::HTTPOK
      @auth_token = ret.read_body.to_a[2].gsub("Auth=", "").strip
      @account = username
      return true
    else
      raise AuthenticationFailed
    end
  end

  #Returns an array of Calendar objects for each calendar associated with 
  #the authenticated account.
  def calendars
    if not @auth_token
       raise NotAuthenticated
    end
    ret = send_get(CALENDAR_LIST_FEED)
    cals = []
    REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
      entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
      entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
      entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
      cal = Calendar.new(self)
      cal.load("<?xml version='1.0' encoding='UTF-8'?>#{entry.to_s}")
      cals << cal
    end
    return cals
  end
end

end
