module WAZ
  module Queues
    class WAZStorageException < StandardError
    end
    
    class InvalidOption < WAZStorageException
      def initialize(missing_option)
        super("You did not provide both required access keys. Please provide the #{missing_option}.")
      end
    end
    
    class QueueAlreadyExists < WAZStorageException
      def initialize(name)
        super("The queue #{name} already exists on your account.")
      end
    end
  end
end