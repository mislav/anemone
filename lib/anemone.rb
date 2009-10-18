require 'anemone/core'

module Anemone
  # Version number
  VERSION = '0.2.0'
  
  # default options
  DEFAULTS = {
    # run 4 Tentacle threads to fetch pages
    :threads => 4,
    # disable verbose output
    :verbose => false,
    # don't throw away the page response body after scanning it for links
    :discard_page_bodies => false,
    # identify self as Anemone/VERSION
    :user_agent => "Anemone/#{VERSION}",
    # no delay between requests
    :delay => false,
    # don't obey the robots exclusion protocol
    :obey_robots_txt => false,
    # by default, don't limit the depth of the crawl
    :depth_limit => false,
    # number of times HTTP redirects will be followed
    :redirect_limit => 5,
    # whether crawling is allowed to paths above ones given
    :traverse_up => true
  }

  #
  # Convenience method to start a crawl using Core
  #
  def self.crawl(urls, options = {}, &block)
    options = DEFAULTS.merge options
    
    if options[:obey_robots_txt]
      begin
        require 'robots'
      rescue LoadError
        warn "To support the robot exclusion protocol, install the robots gem:\n" \
          "sudo gem install fizx-robots"
        exit(1)
      end
    end
    
    # use a single thread if a delay was requested
    options[:threads] = 1 if options[:delay]
    
    Core.crawl(urls, options, &block)
  end
end
