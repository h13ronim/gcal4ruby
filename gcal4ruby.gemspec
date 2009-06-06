Gem::Specification.new do |s|
   s.name = %q{gcal4ruby}
   s.version = "0.1.0"
   s.date = %q{2009-06-02}
   s.authors = ["Mike Reich"]
   s.email = %q{mike@seabourneconsulting.com}
   s.summary = %q{A full featured wrapper for interacting with the Google Calendar API}
   s.homepage = %q{http://gcal4ruby.rubyforge.org/}
   s.description = %q{A full featured wrapper for interacting with the Google Calendar API}
   #s.files = [ "README", "Changelog", "LICENSE", "demo.rb", "demo.conf", "lib/parseconfig.rb"]
   s.files = ["README", "lib/gcal4ruby.rb", "lib/gcal4ruby/base.rb", "lib/gcal4ruby/service.rb", "lib/gcal4ruby/calendar.rb", "lib/gcal4ruby/event.rb", "lib/gcal4ruby/recurrence.rb"]
   s.rubyforge_project = 'gcal4ruby'
   s.has_rdoc = true
   s.test_files = ['test/unit.rb'] 
end 
