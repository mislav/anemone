require 'net/http'

module Anemone
  class HTTP < Net::HTTP
    #
    # Retrieve an HTTP response for *url*, following redirects.
    # Returns the response object, initial response code, and final URI location.
    # 
    def self.get(url, referer = nil)
      headers = {}
      headers['User-Agent'] = Anemone.options.user_agent
      headers['Referer'] = referer.to_s if referer
      
      response = get_response(url, headers)
      code = response.code.to_i
      limit = Anemone.options.redirect_limit
      
      while response.is_a?(Net::HTTPRedirection) and limit > 0
        target = URI(response['location'])
        target = url.merge(target) if target.relative?
        response = get_response(target, headers)
        
        url = target
        limit -= 1
      end
      
      [response, code, url]
    end
    
    #
    # Get an HTTPResponse for *url*
    #
    def self.get_response(url, headers = {})
      Net::HTTP.start(url.host, url.port) do |http|
        path = url.path
        path << '?' << url.query if url.query
        http.get(path, headers)
      end
    end
  end
end
