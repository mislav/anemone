require 'anemone/page'

module Anemone
  class Tentacle
    #
    # Create a new Tentacle
    #
    def initialize(body)
      @body = body
    end
    
    def delay
      @delay ||= @body.options[:delay] || 0
    end
    
    #
    # Gets links from @link_queue, and returns the fetched
    # Page objects into @page_queue
    #
    def run
      while true do
        link, parent_page = get_payload
        break if link == :END
        
        fetch link, parent_page
        sleep delay
      end
    end
    
    protected
    
    def get_payload
      @body.link_queue.deq
    end
    
    def fetch(link, parent_page)
      page = (parent_page || Page).fetch(link, @body.options)
      enqueue page
    end
    
    def enqueue(page)
      @body.page_queue.enq(page)
    end
  end
end