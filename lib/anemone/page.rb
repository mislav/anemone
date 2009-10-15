require 'anemone/http'
require 'nokogiri'
require 'ostruct'

module Anemone
  class Page

    # The URL of the page
    attr_accessor :url
    # Headers of the HTTP response
    attr_reader :headers
    
    # OpenStruct for user-stored data
    attr_reader :data
    # Integer response code of the page
    attr_accessor :code
    # Array of redirect-aliases for the page
    attr_reader :aliases
    # Boolean indicating whether or not this page has been visited in PageHash#shortest_paths!
    attr_accessor :visited
    # Depth of this page from the root of the crawl. This is not necessarily the
    # shortest path; use PageHash#shortest_paths! to find that value.
    attr_accessor :depth
    # URL of the page that brought us to this page
    attr_accessor :referer
    
    # URLs ending in these file extensions will be skipped
    SKIP_EXTENSIONS = %w(pdf mov flv mp3 mp4 ogg tgz tar gz zip rar dmg pdf jpg jpeg gif png psd doc docx xls)
    
    #
    # Create a new Page from the response of an HTTP request to *url*
    #
    def self.fetch(url, options, parent_page = nil)
      url = URI(url) unless URI === url

      if parent_page
        referer = parent_page.url
        depth = parent_page.depth + 1
      end

      response, code, final_url = options[:http].get(url, referer)
      aka = final_url == url ? nil : final_url

      new(url, response.body.dup, code, response.to_hash, aka, referer, depth)
    end
    
    def fetch(url, options)
      self.class.fetch(url, options, self)
    end
    
    #
    # Create a new page
    #
    def initialize(url, body = nil, code = nil, headers = nil, aka = nil, referer = nil, depth = 0)
      @url = url
      @code = code
      @headers = headers
      @headers['content-type'] ||= ['']
      @aliases = Array(aka)
      @data = OpenStruct.new
      @referer = referer
      @depth = depth || 0
      @body = body
    end
    
    # Nokogiri document for the HTML body
    def doc
      @doc ||= @body && html? && Nokogiri::HTML(@body)
    end
    
    # Array of distinct A tag HREFs from the page
    def links
      @links ||= begin
        if doc
          # get a list of distinct links on the page, in absolute url form
          links = doc.css('a[href]').inject([]) do |list, link|
            href = link.attributes['href'].content
            href.strip! if href
            
            unless skip_link?(href)
              begin
                url = to_absolute(href)
              rescue URI::InvalidURIError
                $stderr.puts "ERROR: bad URI #{href.inspect} on page #{self.url.to_s.inspect}"
              else
                list << url if url.scheme =~ /^https?$/
              end
            end
            list
          end
          
          links.uniq!
          links
        else
          []
        end
      end
    end
    
    def discard_document!
      links # force parsing of page links before we trash the document
      @body = @doc = nil
    end
    
    #
    # Return a new page with the same *response* and *url*, but
    # with a 200 response code
    #
    def alias_clone(aka)
      page = clone
      page.aliases.delete(aka)
      page.add_alias(page.url)
      page.url = aka
      page.code = 200
      page
    end

    #
    # Add a redirect-alias String *aka* to the list of the page's aliases
    #
    # Returns *self*
    #
    def add_alias(aka)
      aliases << aka unless aliases.include?(aka)
    end
    
    #
    # Returns an Array of all links from this page, and all the 
    # redirect-aliases of those pages, as String objects.
    #
    # *page_hash* is a PageHash object with the results of the current crawl.
    #
    def links_and_their_aliases(page_hash)
      links.inject([]) do |results, link|
        results.concat([link].concat(page_hash[link].aliases))
      end
    end
    
    #
    # The content-type returned by the HTTP request for this page
    #
    def content_type
      headers['content-type'].first
    end
    
    #
    # Returns +true+ if the page is a HTML document, returns +false+
    # otherwise.
    #
    def html?
      !!(content_type =~ %r{^(text/html|application/xhtml+xml)\b})
    end
    
    #
    # Returns +true+ if the page is a HTTP redirect, returns +false+
    # otherwise.
    #    
    def redirect?
      (300..399).include?(@code)
    end
    
    #
    # Returns +true+ if the page was not found (returned 404 code),
    # returns +false+ otherwise.
    #
    def not_found?
      404 == @code
    end
    
    #
    # Converts relative URL *link* into an absolute URL based on the
    # location of the page
    #
    def to_absolute(link)
      # remove fragment
      link = link.split('#').first if link.index('#')
      url = URI(URI.encode(link))
      raise URI::InvalidURIError unless url.path
      url = @url.merge(url) if url.relative?
      url.path = '/' if url.path.empty?
      url
    end
    
    #
    # Returns +true+ if *uri* is in the same domain as the page, returns
    # +false+ otherwise
    #
    def same_host?(uri)
      uri.host == @url.host
    end
    
    #
    # Skip empty links, those which begin with a fragment or any other
    # that begin with a word+colon that's not part of the URI scheme
    # (mailto, javascript, tel, sms, ...)
    #
    def skip_link?(link)
      link.nil? or link.empty? or link =~ %r{^(#|[\w-]+:(?!//))} or
        (link =~ /\.(\w{2,4})([?#]|\Z)/ && SKIP_EXTENSIONS.include?($1.downcase))
    end
  end
end
