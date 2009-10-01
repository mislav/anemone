require 'spec_helper'

describe Anemone do
  
  before(:all) do
    Anemone::FakePage.new
  end
  
  after(:each) do
    # reset global options object to defaults
    Anemone::DEFAULTS.each { |key, value| Anemone.options.send("#{key}=", value) }
  end

  it "should have a version" do
    Anemone.const_defined?('VERSION').should == true
  end

  it "should have options" do
    Anemone.should respond_to(:options)
  end
  
  it "should accept options for the crawl" do
    Anemone.crawl(SPEC_DOMAIN, :verbose => false, 
                               :threads => 2, 
                               :discard_page_bodies => true,
                               :user_agent => 'test',
                               :obey_robots_txt => true,
                               :depth_limit => 3)

    Anemone.options.verbose.should == false
    Anemone.options.threads.should == 2
    Anemone.options.discard_page_bodies.should == true
    Anemone.options.delay.should == false
    Anemone.options.user_agent.should == 'test'
    Anemone.options.obey_robots_txt.should == true
    Anemone.options.depth_limit.should == 3
  end
  
  it "should use 1 thread if a delay is requested" do
    Anemone.crawl(SPEC_DOMAIN, :delay => 0.01, :threads => 2)
    Anemone.options.threads.should == 1
  end
  
  it "should return a Anemone::Core from the crawl, which has a PageHash" do
    result = Anemone.crawl(SPEC_DOMAIN)
    result.should be_an_instance_of(Anemone::Core)
    result.pages.should be_an_instance_of(Anemone::PageHash)
  end
  
end
