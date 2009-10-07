# enabling the load of files from root (on RSpec)
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../')

require 'rubygems'
require 'spec'
require 'mocha'
require 'restclient'
require 'time'
require 'hmac-sha2'
require 'base64'
require 'tests/configuration'
require 'lib/waz-queues'

describe "Windows Azure Queues API service" do 
  it "should list queues" do
    # setup mocks
    expected_url = "http://my_account.queue.core.windows.net/?comp=list"
    expected_response = <<-eos
                        <?xml version="1.0" encoding="utf-8"?>
                        <EnumerationResults AccountName="http://myaccount.queue.core.windows.net">
                          <Queues>
                            <Queue>
                              <QueueName>mock-queue</QueueName>
                              <Url>http://myaccount.queue.core.windows.net/mock-queue</Url>
                            </Queue>
                          </Queues>
                        </EnumerationResults>
                        eos
    
    mock_request = RestClient::Request.new(:method => :get, :url => expected_url)
    mock_request.expects(:execute).returns(expected_response)
    
    service = WAZ::Queues::Service.new("my_account", "my_key", false, "queue.core.windows.net")
    # setup mocha expectations
    service.expects(:generate_request_uri).with("list", nil).returns(expected_url)
    service.expects(:generate_request).with("GET", expected_url).returns(mock_request)
    
    queues = service.list_queues()
    queues.first()[:name].should == "mock-queue"
    queues.first()[:url].should == "http://myaccount.queue.core.windows.net/mock-queue"
  end
  
  it "should create queue" do
    expected_url = "http://myaccount.queue.core.windows.net/mock-queue"
    mock_request = RestClient::Request.new(:method => :get, :url => expected_url)
    mock_request.stubs(:execute)
    
    service = WAZ::Queues::Service.new("my_account", "my_key", false, "queue.core.windows.net")
    # setup mocha expectations
    service.expects(:generate_request_uri).with(nil, "mock-queue").returns(expected_url)
    service.expects(:generate_request).with("PUT", expected_url, {:x_ms_meta_priority => "high-importance"}).returns(mock_request)

    service.create_queue("mock-queue", {:x_ms_meta_priority => "high-importance"})
  end
  
  it "should raise queue already exists when there's a conflict" do
    expected_url = "http://myaccount.queue.core.windows.net/mock-queue"
    # generate a mock 409 Conflic Exception
    mock_response = mock()
    mock_response.stubs(:code).returns("409")
    mock_request = RestClient::Request.new(:method => :get, :url => expected_url)
    mock_request.stubs(:execute).raises(RestClient::RequestFailed, mock_response)

    
    service = WAZ::Queues::Service.new("my_account", "my_key", false, "queue.core.windows.net")
    # setup mocha expectations
    service.expects(:generate_request_uri).with(nil, "mock-queue").returns(expected_url)
    service.expects(:generate_request).with("PUT", expected_url, {}).returns(mock_request)

    lambda{ service.create_queue("mock-queue") }.should raise_error(WAZ::Queues::QueueAlreadyExists)
  end
end