require 'net/http'

module Anemone
  class HTTP
    def initialize(options)
      @options = options
      @user_agent = options[:user_agent]
      @redirect_limit = options[:redirect_limit]
      @connections = {}
      
      if options[:obey_robots_txt]
        @robots = Robots.new(@user_agent)
      else
        @robots = nil
      end
    end
    
    #
    # Retrieve an HTTP response for *url*, following redirects.
    # Returns the response object, initial response code, and final URI location.
    # 
    def get(url, referer = nil)
      headers = {}
      headers['User-Agent'] = @user_agent
      headers['Referer'] = referer.to_s if referer
      
      response = get_response(url, headers)
      code = response.code.to_i
      limit = @redirect_limit
      
      while response.is_a?(Net::HTTPRedirection) and limit > 0
        target = URI(response['location'])
        target = url.merge(target) if target.relative?
        response = get_response(target, headers)
        
        url = target
        limit -= 1
      end
      
      [response, code, url]
    end
    
    def allowed?(link)
      not @robots or @robots.allowed?(link)
    end
    
    #
    # Get an HTTPResponse for *url*
    #
    def get_response(url, headers = {})
      get_connection(url) do |conn|
        conn.get(url.path_with_query, headers)
      end
    end
    
    def close_connections!
      @connections.values.each { |conn| conn.finish if conn.active? }
      @connections.clear
    end
    
    protected
    
    def get_connection(url)
      connection = Net::HTTP.new(url.host, url.port)
      yield connection
    end
  end
end
