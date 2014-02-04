require 'thread'
require 'timeout'
require 'logger'

require 'threaded/version'
require 'threaded/timeout'

module Threaded
  STOP_TIMEOUT = 10 # seconds
  extend self

  @mutex = Mutex.new

  attr_reader :logger, :size, :inline, :timeout
  alias :inline? :inline

  def inline=(inline)
    @mutex.synchronize { @inline = inline }
  end

  def logger=(logger)
    @mutex.synchronize { @logger = logger }
  end

  def size=(size)
    @mutex.synchronize { @size = size }
  end

  def timeout=(timeout)
    @mutex.synchronize { @timeout = timeout }
  end

  def start(options = {})
    self.logger  = options[:logger]  if options[:logger]
    self.size    = options[:size]    if options[:size]
    self.timeout = options[:timeout] if options[:timeout]
    self.master.start
    return self
  end

  def master
    @mutex.synchronize do
      return @master if @master
      @master = Master.new(logger:  self.logger,
                           size:    self.size,
                           timeout: self.timeout)
    end
    @master
  end
  alias :master= :master


  def configure(&block)
    raise "Queue is already started, must configure queue before starting" if started?
    yield self
  end
  alias :config  :configure

  def started?
    return false unless master
    master.alive?
  end

  def stopped?
    !started?
  end

  def later(&block)
    Threaded::Promise.new(&block).later
  end

  def enqueue(job, *args)
    if inline?
      job.call(*args)
    else
      master.enqueue(job, *args)
    end
    return true
  end

  def stop(timeout = STOP_TIMEOUT)
    return true unless master
    master.stop(timeout)
    return true
  end
end

Threaded.logger       = Logger.new(STDOUT)
Threaded.logger.level = Logger::INFO


require 'threaded/errors'
require 'threaded/worker'
require 'threaded/master'
require 'threaded/promise'
