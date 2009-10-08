# enabling the load of files from root (on RSpec)
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../')

require 'rubygems'
require 'spec'
require 'mocha'
require 'restclient'
require 'lib/waz-queues'

describe "Queue object behavior" do
  it "should list queues by name" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"})
    WAZ::Queues::Service.any_instance.expects(:list_queues).returns([{:name => 'queue1', :url => 'queue1_url'}, {:name => 'queue2', :url => 'queue2_url'}])
    containers = WAZ::Queues::Queue.list
    containers.size.should == 2
    containers.first().name.should == "queue1"
    containers.first().url.should == "queue1_url"
    containers.last().name.should == "queue2"
  end
  
  it "should throw when not name provided for the queue" do
    lambda { WAZ::Queues::Queue.new({:foo => "bar"}) }.should raise_error(WAZ::Queues::InvalidOption)
  end
  
  it "should throw when not url provided for the queue" do
    lambda { WAZ::Queues::Queue.new({:name => "mock-queue"}) }.should raise_error(WAZ::Queues::InvalidOption)
  end
  
  it "should create queue" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).twice
    WAZ::Queues::Service.any_instance.expects(:create_queue)
    queue = WAZ::Queues::Queue.create('queue1') 
    queue.name.should == "queue1"
    queue.url.should == "http://my-account.queue.core.windows.net/queue1"
  end
  
  it "should find queue" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).twice
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).returns {  }
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.name.should == "queue1"
    queue.url.should == "http://my-account.queue.core.windows.net/queue1"
  end
  
  it "should return null when the queue isn't found" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).once
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").raises(RestClient::ResourceNotFound)
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.nil?.should == true
  end
  
  it "should delete queue" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({})
    WAZ::Queues::Service.any_instance.expects(:delete_queue).with("queue1").returns()
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.destroy!
  end
  
  it "should get queue metadata" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({:x_ms_meta_property => "value"}).twice
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.metadata[:x_ms_meta_property].should == "value"
  end
  
  it "should get queue length" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({:x_ms_approximate_messages_count => "2"}).twice
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.size.should == 2
  end
  
  it "should merge queue metadata new metadata" do
    existing_metadata = {:x_ms_approximate_message_count => 2, :x_ms_request_id => 2, :x_ms_meta_property1 => "value1"}
    valid_metadata = {:x_ms_meta_property1 => "value1"}
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(4)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns(existing_metadata).twice
    WAZ::Queues::Service.any_instance.expects(:set_queue_metadata).with(valid_metadata.merge(:x_ms_meta_property2 => "value2"))
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.put_properties!({:x_ms_meta_property2 => "value2"})
  end
  
  it "should override queue metadata new metadata" do
    existing_metadata = {:x_ms_approximate_message_count => 2, :x_ms_request_id => 2, :x_ms_meta_property1 => "value1"}
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(4)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns(existing_metadata)
    WAZ::Queues::Service.any_instance.expects(:set_queue_metadata).with({:x_ms_meta_property2 => "value2"})
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.put_properties!({:x_ms_meta_property2 => "value2"}, true)
  end
  
  it "should enqueue message on the queue" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:enqueue).with("queue1", "this is my message enqueued", 604800)
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.enqueue!("this is my message enqueued")
  end
  
  it "should enqueue message on the queue with specific time to live" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:enqueue).with("queue1", "this is my message enqueued", 600)
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.enqueue!("this is my message enqueued", 600)
  end
  
  it "should peek lock a single message from the queue" do
    expected_message = {:message_id => "message id", :message_text => "text", :expiration_time => Time.new, :insertion_time => Time.new, :pop_receipt => "receipt"}
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:get_messages).with('queue1', {:num_of_messages => 1}).returns([expected_message])
    queue = WAZ::Queues::Queue.find('queue1') 
    message = queue.lock()
    message.queue_name == "queue1"
    message.message_id.should == "message id"
    message.message_text.should == "text"
    message.pop_receipt.should == "receipt"    
  end
  
  it "should peek lock messages from the queue" do
    expected_messages = [ {:message_id => "message id", :message_text => "text", :expiration_time => Time.new, :insertion_time => Time.new, :pop_receipt => "receipt"},
                         {:message_id => "message id2", :message_text => "text-second", :expiration_time => Time.new, :insertion_time => Time.new, :pop_receipt => "receipt"}]
                         
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:get_messages).with('queue1', {:num_of_messages => 2}).returns(expected_messages)
    queue = WAZ::Queues::Queue.find('queue1') 
    messages = queue.lock(2)
    messages.last().queue_name == "queue1"
    messages.last().message_id.should == "message id2"
    messages.last().message_text.should == "text-second"
    messages.last().pop_receipt.should == "receipt"    
  end
  
  it "should peek a single message from the queue" do
    expected_message = {:message_id => "message id", :message_text => "text", :expiration_time => Time.new, :insertion_time => Time.new, :pop_receipt => "receipt"}
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:peek).with('queue1', {:num_of_messages => 1}).returns([expected_message])
    queue = WAZ::Queues::Queue.find('queue1') 
    message = queue.peek()
    message.queue_name == "queue1"
    message.message_id.should == "message id"
    message.message_text.should == "text"
    message.pop_receipt.should == "receipt"    
  end
  
  it "should peek messages from the queue" do
    expected_messages = [{:message_id => "message id", :message_text => "text", :expiration_time => Time.new, :insertion_time => Time.new, :pop_receipt => "receipt"},
                         {:message_id => "message id2", :message_text => "text-second", :expiration_time => Time.new, :insertion_time => Time.new, :pop_receipt => "receipt"}]
                         
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:peek).with('queue1', {:num_of_messages => 2}).returns(expected_messages)
    queue = WAZ::Queues::Queue.find('queue1') 
    messages = queue.peek(2)
    messages.last().queue_name == "queue1"
    messages.last().message_id.should == "message id2"
    messages.last().message_text.should == "text-second"
    messages.last().pop_receipt.should == "receipt"
  end
  
  it "should clear queue" do
    WAZ::Queues::Base.expects(:default_connection).returns({:account_name => "my-account", :access_key => "key"}).at_most(3)
    WAZ::Queues::Service.any_instance.expects(:get_queue_metadata).with("queue1").returns({}).once
    WAZ::Queues::Service.any_instance.expects(:clear_queue).with('queue1').returns()
    queue = WAZ::Queues::Queue.find('queue1') 
    queue.clear()
  end
end