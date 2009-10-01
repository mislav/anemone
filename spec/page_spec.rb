require 'spec_helper'

module Anemone
  describe Page do
    
    before(:all) do
      @url = FakePage.new('home').url
    end
    
    before(:each) do
      @page = Page.fetch(@url)
    end
    
    it "should be able to fetch a page" do
      @page.url.path.should == '/home'
    end
    
    it "should store the response headers when fetching a page" do
      @page.headers.should have_key('content-type')
    end
    
    it "should have content type" do
      @page.content_type.should == 'text/html'
      @page.should be_html
    end
    
    it "should have an OpenStruct attribute for the developer to store data in" do
      @page.data.test = 'test'
      @page.data.test.should == 'test'
    end
    
    it "should have a Nokogori::HTML::Document attribute for the page body" do
      @page.doc.should be_an_instance_of(Nokogiri::HTML::Document)
    end
    
    describe "redirect" do
      before(:all) do
        @redirect_url = FakePage.new('redir', :redirect => 'home').url
        @redirect_page = Page.fetch(@redirect_url)
      end
    
      it "should not indicate redirect for normal responses" do
        @page.should_not be_redirect
      end
    
      it "should indicate redirect for HTTP 30x responses" do
        @redirect_page.should be_redirect
        @redirect_page.code.should == 301
      end
      
      it "should indicate destination URL" do
        @redirect_page.aliases.should == [@page.url]
      end
      
      it "should clone from an alias URL" do
        cloned_page = @redirect_page.alias_clone(@page.url)
        cloned_page.should_not == @redirect_page
        cloned_page.url.should == @page.url
        cloned_page.aliases.should == [@redirect_page.url]
        cloned_page.code.should == 200
      end
    end
    
    it "should have a method to tell if a URI is in the same domain as the page" do
      @page.should be_in_domain(URI(FakePage.new('test').url))
      @page.should_not be_in_domain(URI('http://www.other.com/'))
    end
    
  end
end
