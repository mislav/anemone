begin
  require 'fakeweb'
rescue LoadError
  warn "You need the 'fakeweb' gem installed to test Anemone"
  exit
end

FakeWeb.allow_net_connect = false

module Anemone
  class FakePage
    attr_reader :name, :links, :hrefs, :redirect, :content_type
    
    def initialize(name = '', options = {})
      @name = name
      @links = Array(options[:links])
      @hrefs = Array(options[:hrefs])
      @redirect = options[:redirect]
      @content_type = options[:content_type] || "text/html"
      @body = options[:body]
      
      add_to_fakeweb
    end
    
    def url
      SPEC_DOMAIN + @name
    end
    
    def body
      @body ||= begin
        "<html><body>" +
        links.map { |link| %(<a href="#{SPEC_DOMAIN}#{link}">link</a>) }.join("\n") +
        hrefs.map { |href| %(<a href="#{href}">href</a>) }.join("\n") +
        "</body></html>"
      end
    end
    
    private
    
    def add_to_fakeweb
      headers = {'Content-type' => content_type}
      headers['Location'] = SPEC_DOMAIN + redirect if redirect
      
      response_body = 'HTTP/1.1 '
      response_body << (redirect ? '301 Permanently Moved' : '200 OK') << "\r\n"
      response_body << headers.map { |k,v| "#{k}: #{v}" }.join("\r\n")
      response_body << "\r\n\r\n" << body
      
      options = {:response => response_body}
      
      FakeWeb.register_uri(:get, SPEC_DOMAIN + name, options)
    end
  end
end
