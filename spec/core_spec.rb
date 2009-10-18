require 'spec_helper'

module Anemone
  describe Core do
    
    before(:each) do
      FakeWeb.clean_registry
    end
    
    it "should crawl all the html pages in a domain by following <a> href's" do
      pages = []
      pages << FakePage.new('0', :links => ['1', '2'])
      pages << FakePage.new('1', :links => ['3'])
      pages << FakePage.new('2')
      pages << FakePage.new('3')
      
      core = Anemone.crawl(pages[0].url)
      core.should have(4).pages
    end
    
    it "should not leave the original domain" do
      pages = []
      pages << FakePage.new('0', :links => ['1'], :hrefs => 'http://www.other.com/')
      pages << FakePage.new('1')
      
      core = Anemone.crawl(pages[0].url)
      
      core.should have(2).pages
      core.pages.keys.should_not include('http://www.other.com/')
    end
    
    it "should follow http redirects" do
      pages = []
      pages << FakePage.new('0', :links => ['1'])
      pages << FakePage.new('1', :redirect => '2')
      pages << FakePage.new('2')
      
      Anemone.crawl(pages[0].url).should have(3).pages     
    end
    
    it "should accept multiple starting URLs" do
      pages = []
      pages << FakePage.new('0', :links => ['1'])
      pages << FakePage.new('1')
      pages << FakePage.new('2', :links => ['3'])
      pages << FakePage.new('3')
      
      Anemone.crawl([pages[0].url, pages[2].url]).should have(4).pages
    end
    
    it "should leave original domain if allowed by pattern" do
      pages = []
      pages << FakePage.new('0', :hrefs => ['http://www.other.com/', 'http://www.other.com/fun/games/wwp'])
      pages << FakePage.new('http://www.other.com/fun/games/wwp', :hrefs => 'http://www.other.com/fun')
      
      core = Anemone.crawl(pages[0].url, :allowed_urls => ['http://www.other.com/fun/games'], :traverse_up => false)
      
      core.should have(2).pages
      core.pages.keys.should include('http://www.other.com/fun/games/wwp')
    end
    
    it "should stay under given paths with :traverse_up set to false" do
      pages = []
      pages << FakePage.new('0', :links => ['01'])
      pages << FakePage.new('01')
      pages << FakePage.new('2', :links => ['3'])
      pages << FakePage.new('3')
      
      Anemone.crawl([pages[0].url, pages[2].url], :traverse_up => false).should have(3).pages
    end
    
    it "should include the query string when following links" do
      pages = []
      pages << FakePage.new('0', :links => ['1?foo=1'])
      pages << FakePage.new('1?foo=1')
      pages << FakePage.new('1')
      
      core = Anemone.crawl(pages[0].url)
      
      core.should have(2).pages
      core.pages.keys.should_not include(pages[2].url)
    end
    
    it "should be able to skip links based on a regex" do
      pages = []
      pages << FakePage.new('0', :links => ['1', '2'])
      pages << FakePage.new('1')
      pages << FakePage.new('2')
      
      core = Anemone.crawl(pages[0].url, :skip_urls => %r{/1})
      
      core.should have(2).pages
      core.pages.keys.should_not include(pages[1].url)
    end
    
    it "should be able to call a block on every page" do
      pages = []
      pages << FakePage.new('0', :links => ['1', '2'])
      pages << FakePage.new('1')
      pages << FakePage.new('2')
      
      count = 0
      Anemone.crawl(pages[0].url) do |a|
        a.on_every_page { count += 1 }
      end     
      
      count.should == 3
    end
    
    it "should not discard page bodies by default" do
      core = Anemone.crawl(FakePage.new('0').url)
      page = core.pages.values.first
      page.doc.should_not be_nil
    end
    
    it "should optionally discard page bodies to conserve memory" do
      core = Anemone.crawl(FakePage.new('0').url, :discard_page_bodies => true)
      core.pages.values.first.doc.should be_nil
    end
    
    it "should provide a focus_crawl method to select the links on each page to follow" do
      pages = []
      pages << FakePage.new('0', :links => ['1', '2'])
      pages << FakePage.new('1')
      pages << FakePage.new('2')

      core = Anemone.crawl(pages[0].url) do |a|
        a.focus_crawl {|p| p.links.reject{|l| l.to_s =~ /1/}}
      end     
      
      core.should have(2).pages
      core.pages.keys.should_not include(pages[1].url)
    end
    
    it "should optionally delay between page requests" do
      delay = 0.25
      
      pages = []
      pages << FakePage.new('0', :links => '1')
      pages << FakePage.new('1')
      
      start = Time.now
      Anemone.crawl(pages[0].url, :delay => delay)
      finish = Time.now
      
      (finish - start).should satisfy {|t| t > delay * 2}
    end
     
    it "should optionally obey the robots exclusion protocol" do
      pages = []
      pages << FakePage.new('0', :links => '1')
      pages << FakePage.new('1')
      pages << FakePage.new('robots.txt', 
                            :body => "User-agent: *\nDisallow: /1",
                            :content_type => 'text/plain')

      core = Anemone.crawl(pages[0].url, :obey_robots_txt => true)
      urls = core.pages.keys
      
      urls.should include(pages[0].url)
      urls.should_not include(pages[1].url)
    end
  end
  
  describe Core, "many pages" do
    before(:all) do
      FakeWeb.clean_registry
      
      @pages, size = [], 5
      
      size.times do |n|
        # register this page with a link to the next page
        link = (n + 1).to_s if n + 1 < size
        @pages << FakePage.new(n.to_s, :links => Array(link))
      end    
    end
  
    it "should track the page depth and referer" do
      core = Anemone.crawl(@pages[0].url) 
      previous_page = nil
      
      @pages.each_with_index do |page, i|
        page = core.pages[page.url]
        page.should be
        page.depth.should == i
        
        if previous_page
          page.referer.should == previous_page.url
        else
          page.referer.should be_nil
        end
        previous_page = page
      end
    end
  
    it "should optionally limit the depth of the crawl" do
      core = Anemone.crawl(@pages[0].url, :depth_limit => 3) 
      core.should have(4).pages
    end
  end
  
  describe Core, "link selection" do
    before(:each) do
      @core = described_class.new(SPEC_DOMAIN, Anemone::DEFAULTS)
    end
    
    def links_to_follow(page)
      @core.send(:links_to_follow, page)
    end
    
    it "should skip links and remove duplicates" do
      @core.skip_links_like %r{/will/skip}
      @core.pages[SPEC_DOMAIN + 'bar'] = nil # mark as "visited"
      
      links = %[
        #{SPEC_DOMAIN}foo
        #{SPEC_DOMAIN}bar
        #{SPEC_DOMAIN}will/skip/this/link
        #{SPEC_DOMAIN}foo
        http://other.com/foo
      ].split.map{ |link| URI(link) }
        
      page = stub(:depth => 1, :links => links)
      page.stub!(:same_host?).and_return(true)
        
      links_to_follow(page).should == [links[0], links[4]]
    end
    
    it "should not try to analyze links deeper than depth limit" do
      @core.options[:depth_limit] = 1
      page = stub(:depth => 1)
      page.should_not_receive(:links)
      links_to_follow(page).should == []
    end
  end
end
