require 'spec_helper'

describe Anemone do
  
  before(:all) do
    Anemone::FakePage.new
  end
  
  it "should have a version" do
    Anemone::VERSION.should be_instance_of(String)
  end

  it "should not have global options" do
    Anemone.should_not respond_to(:options)
  end
  
  it "should return a Anemone::Core from the crawl, which has a PageHash" do
    result = Anemone.crawl(SPEC_DOMAIN)
    result.should be_an_instance_of(Anemone::Core)
    result.pages.should be_an_instance_of(Anemone::PageHash)
  end
  
end
