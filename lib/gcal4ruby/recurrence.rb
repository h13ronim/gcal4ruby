class Time
  def complete
    self.utc.strftime("%Y%m%dT%H%M%S")
  end
end

module GCal4Ruby
  class Recurrence
    attr_reader :start, :end, :event, :day_of_week, :repeat_until, :frequency
    attr_accessor :all_day
    def initialize
      @start = nil
      @end = nil
      @event = nil
      @day_of_week = nil
      @repeat_until = nil
      @frequency = nil
      @all_day = false
    end
    
    def to_s
      output = ''
      if @all_day
        output += "DTSTART;VALUE=DATE:#{@start.utc.strftime("%Y%m%d")}\n"
      else
        output += "DTSTART;VALUE=DATE-TIME:#{@start.complete}\n"
      end
      if @all_day
        output += "DTEND;VALUE=DATE:#{@end.utc.strftime("%Y%m%d")}\n"
      else
        output += "DTEND;VALUE=DATE-TIME:#{@end.complete}\n"
      end
      output += "RRULE:"
      if @frequency
        output += "FREQ=#{@frequency.upcase}"
      end
      if @day_of_week and @frequency.downcase = 'weekly'
        output += ";BYDAY=#{@day_of_week.join(",")}"
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
end