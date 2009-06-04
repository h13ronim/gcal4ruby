require 'gcal4ruby/base' 
require 'gcal4ruby/calendar'

module GCal4Ruby

class Service < Base
  attr_reader :account
  
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
