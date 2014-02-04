require 'thread'
require 'timeout'
require 'logger'

require 'threaded/version'
require 'threaded/timeout'

module Threaded
  STOP_TIMEOUT = 10 # seconds
  extend self
  attr_accessor :inline, :logger, :size, :timeout
  alias :inline? :inline

  @mutex = Mutex.new

  def start(options = {})
    self.master = options
    self.master.start
    return self
  end

  def configure(&block)
    raise "Queue is already started, must configure queue before starting" if started?
    @mutex.synchronize do
      yield self
    end
  end
  alias :config  :configure

  def started?
    return false unless master
    master.alive?
  end

  def stopped?
    !started?
  end

  def master(options = {})
    @mutex.synchronize do
      return @master if @master
      self.logger  = options[:logger]  if options[:logger]
      self.size    = options[:size]    if options[:size]
      self.timeout = options[:timeout] if options[:timeout]
      @master = Master.new(logger:  self.logger,
                           size:    self.size,
                           timeout: self.timeout)
    end
  end
  alias :master= :master

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
