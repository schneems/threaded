module Threaded
  class Master
    include Threaded::Timeout
    attr_reader :workers, :logger

    DEFAULT_TIMEOUT = 60 # seconds, 1 minute
    DEFAULT_SIZE    = 16

    def initialize(options = {})
      @queue    = Queue.new
      @mutex    = Mutex.new
      @stopping = false
      @max      = options[:size]     || DEFAULT_SIZE
      @timeout  = options[:timeout]  || DEFAULT_TIMEOUT
      @logger   = options[:logger]   || Threaded.logger
      @workers  = []
    end

    def enqueue(job, *json)
      @queue.enq([job, json])

      new_worker if needs_workers? && @queue.size > 0
      raise NoWorkersError unless alive?
      return true
    end

    def alive?
      !stopping?
    end

    def start
      new_workers(@max, true)
      return self
    end

    def stop(timeout = 10)
      @mutex.synchronize do
        @stopping = true
        workers.each {|w| w.poison }
        timeout(timeout, "waiting for workers to stop") do
          while self.alive?
            workers.reject! {|w| w.join if w.dead? }
          end
        end
      end
      return self
    end

    def size
      @workers.size
    end

    private

    def needs_workers?
      size < @max
    end

    def max_workers?
      !needs_workers?
    end

    def stopping?
      @stopping
    end

    def new_worker(num = 1, force_start = false)
      @mutex.synchronize do
        @stopping = false if force_start
        return false      if stopping?
        num.times do
          next if max_workers?
          @workers << Worker.new(@queue, timeout: @timeout)
        end
      end
    end
    alias :new_workers :new_worker
  end
end
