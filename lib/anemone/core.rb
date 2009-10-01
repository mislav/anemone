require 'uri'
require 'thread'
require 'anemone/tentacle'
require 'anemone/page_hash'

module Anemone
  class Core
    # PageHash storing all Page objects encountered during the crawl
    attr_reader :pages

    #
    # Initialize the crawl with starting *urls* (single URL or Array of URLs)
    # and optional *block*
    #
    def initialize(urls, &block)
      @urls = Array(urls).map do |url|
        url = URI(url) if String === url
        url.path = '/' if url.path.empty?
        url
      end

      @tentacles = []
      @pages = PageHash.new
      @on_every_page_blocks = []
      @on_pages_like_blocks = Hash.new { |hash,key| hash[key] = [] }
      @skip_link_patterns = []
      @after_crawl_blocks = []
      @focus_crawl_block = nil

      if Anemone.options.obey_robots_txt
        @robots = Robots.new(Anemone.options.user_agent)
      else
        @robots = nil
      end

      block.call(self) if block
    end

    #
    # Convenience method to start a new crawl
    #
    def self.crawl(root, &block)
      self.new(root) do |core|
        block.call(core) if block
        core.run
        return core
      end
    end

    #
    # Add a block to be executed on the PageHash after the crawl
    # is finished
    #
    def after_crawl(&block)
      @after_crawl_blocks << block
      self
    end

    #
    # Add one ore more Regex patterns for URLs which should not be
    # followed
    #
    def skip_links_like(*patterns)
      @skip_link_patterns.concat patterns
      self
    end

    #
    # Add a block to be executed on every Page as they are encountered
    # during the crawl
    #
    def on_every_page(&block)
      @on_every_page_blocks << block
      self
    end

    #
    # Add a block to be executed on Page objects with a URL matching
    # one or more patterns
    #
    def on_pages_like(*patterns, &block)
      patterns.each do |pattern|
        @on_pages_like_blocks[pattern] << block
      end
      self
    end

    #
    # Specify a block which will select which links to follow on each page.
    # The block should return an Array of URI objects.
    #
    def focus_crawl(&block)
      @focus_crawl_block = block
      self
    end

    #
    # Perform the crawl
    #
    def run
      @urls.delete_if { |url| !visit_link?(url) }
      return if @urls.empty?

      link_queue = Queue.new
      page_queue = Queue.new

      Anemone.options.threads.times do |id|
        @tentacles << Thread.new { Tentacle.new(link_queue, page_queue).run }
      end

      @urls.each{ |url| link_queue.enq(url) }

      loop do
        page = page_queue.deq

        @pages[page.url] = page

        puts "#{page.url} Queue: #{link_queue.size}" if Anemone.options.verbose

        # perform the on_every_page blocks for this page
        do_page_blocks(page)

        page.discard_document! if Anemone.options.discard_page_bodies

        links_to_follow(page).each do |link|
          link_queue.enq([link, page])
          @pages[link] = nil
        end

        # create an entry in the page hash for each alias of this page,
        # i.e. all the pages that redirected to this page
        page.aliases.each do |aka|
          @pages[aka] ||= page.alias_clone(aka)
        end

        # if we are done with the crawl, tell the threads to end
        if link_queue.empty? and page_queue.empty?
          until link_queue.num_waiting == @tentacles.size
            Thread.pass
          end

          if page_queue.empty?
            @tentacles.size.times { |i| link_queue.enq(:END)}
            break
          end
        end

      end

      @tentacles.each { |t| t.join }

      do_after_crawl_blocks

      self
    end

    private

    #
    # Execute the after_crawl blocks
    #
    def do_after_crawl_blocks
      @after_crawl_blocks.each { |block| block.call(@pages) }
    end

    #
    # Execute the on_every_page blocks for *page*
    #
    def do_page_blocks(page)
      blocks = @on_every_page_blocks
      
      @on_pages_like_blocks.each do |pattern, blks|
        blocks += blks if page.url.to_s =~ pattern
      end
      
      blocks.each { |block| block.call(page) }
    end

    #
    # Return an Array of links to follow from the given page.
    # Based on whether or not the link has already been crawled,
    # and the block given to #focus_crawl
    #
    def links_to_follow(page)
      unless Anemone.options.depth_limit and page.depth >= Anemone.options.depth_limit
        links = @focus_crawl_block ? @focus_crawl_block.call(page) : page.links
        links.select { |link| visit_link?(link) }.uniq
      else
        [] # depth limit reached; don't follow any links
      end
    end

    #
    # Returns +true+ if *link* has not been visited already,
    # and is not excluded by a skip_link pattern...
    # and is not excluded by robots.txt...
    # Returns +false+ otherwise.
    #
    def visit_link?(link)
      not @pages.has_key?(link) and not skip_link?(link) and
        (not @robots or @robots.allowed?(link))
    end

    #
    # Returns +true+ if *link* should not be visited because
    # its URL matches a skip_link pattern.
    #
    def skip_link?(link)
      @skip_link_patterns.any? { |p| link.path_with_query =~ p }
    end

  end
end

URI::Generic.class_eval do
  def path_with_query
    query && !query.empty? ? "#{path}?#{query}" : path
  end
end
