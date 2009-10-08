module WAZ
  module Queues
    class WAZStorageException < StandardError
    end
    
    class InvalidOption < WAZStorageException
      def initialize(missing_option)
        super("You did not provide one of the required parameters. Please provide the #{missing_option}.")
      end
    end
    
    class QueueAlreadyExists < WAZStorageException
      def initialize(name)
        super("The queue #{name} already exists on your account.")
      end
    end
    
    class OptionOutOfRange < WAZStorageException
      def initialize(args = {})
        super("The #{args[:name]} parameter is out of range allowed values go from #{args[:min]} to  #{args[:max]}.")
      end
    end
    
    class InvalidOperation < WAZStorageException
      def initialize()
        super("A peeked message cannot be delete, you need to lock it first (pop_receipt required).")
      end
    end
  end
end