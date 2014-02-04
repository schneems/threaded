module Threaded
  class Promise
    class NoJobError < StandardError
      def initialize
        super "No job present for #{self.inspect}"
      end
    end

    attr_reader :has_run; alias :has_run? :has_run
    attr_reader :running; alias :running? :running
    attr_reader :error

    def initialize(&job)
      raise "Must supply a job" unless job
      @mutex   = Mutex.new
      @has_run = false
      @running = false
      @result  = nil
      @error   = nil
      @job     = job
    end

    def later
      Threaded.enqueue(self)
      self
    end

    def call
      @mutex.synchronize do
        return true if running? || has_run?
        begin
          if @job
            @running = true
            @result  = @job.call
          else
            raise NoJobError
          end
        rescue Exception => error
          @error   = error
        ensure
          @has_run = true
        end
      end
    end

    def now
      wait_for_it!
      raise error, error.message, error.backtrace if error
      @result
    end
    alias :join  :now
    alias :value :now

    private
    def wait_for_it!
      return true if has_run?

      if running?
        @mutex.synchronize {} # waits for lock to be released
      else
        call
      end
    end
  end
end

# job = Threaded.later do


# end

# job.now

# job = Threaded::Promise.new
# job.enqueue do


# end

# job.now