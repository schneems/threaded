## Threaded

[![Build Status](https://travis-ci.org/schneems/threaded.png?branch=master)](https://travis-ci.org/schneems/threaded)

Simpler than actors, easier than threads. Get threaded!

## What

Why wait? If you're doing IO in MRI, or really anything in JRuby you can speed up your programs dramatically by using threads. Threads however are a low level primitive in Ruby that can be difficult to use. For a primer on threads check out [Working with Ruby Threads](http://www.jstorimer.com/products/working-with-ruby-threads). Threaded implements a few common thread patterns into an easy to use interface letting you focus on writing your code and letting Threaded worry about running that code as fast as possible. Threaded currently includes a threaded background queue, a thread pool, and promises.

Threaded does not use any fancy "metaprogramming" and prefers explicit fast execution over semantic beauty. The internals should be "simple", easy to read, and easy to debug.

## Install

In your `Gemfile`:

```ruby
gem 'threaded'
```

Then run `$ bundle install`


# Simple Promises

Throw tasks you want to get worked on in the background into a `Threaded.later` block:

```ruby
promise = Threaded.later do
  require "YAML"
  YAML.load `curl https://s3-external-1.amazonaws.com/heroku-buildpack-ruby/ruby_versions.yml 2>/dev/null`
end
```

Then when you need the value use the `value` method:

```ruby
promise.value # => ["ruby-2.0.0", "ruby-1.9.3", # ...
```

It's secretly doing all of that work in the background letting your main Ruby thread focus on the work you care about most.

## Keep your Promises

Promises will block when executed inside of one another, this means you can put promises in your promises and they'll always be executed in the correct order.

```ruby
curl = Threaded.later do
  `curl https://s3-external-1.amazonaws.com/heroku-buildpack-ruby/ruby_versions.yml 2>/dev/null`
end

yaml = Threaded.later do
  require "YAML"
  YAML.load curl.value
end
```

This code guarantees that the block in `curl` gets executed before the `YAML.load`. Of course, the outcome is the same:

```ruby
yaml.value #=> ["ruby-2.0.0", "ruby-1.9.3", # ...
```

While a contrived example, you can use this type of promise chaining to parallelize complex tasks.

By the way, if you call `Threaded.later` and never call `value` on the returned object it may run but is not guaranteed to. So if you `value` your "promises" then you'll always keep them.

## Background Queue

The engine that power's `threaded` promises is also a publicly available background queue! You may be familiar with `resque` or `sidekiq` that allow you to enqueue jobs to be run later threaded has something like that. The main difference is that threaded does not persist values to a permanent store (like resque or PostgreSQL). Here's how you use it.

Define your task to be processed:

```ruby
class Archive
  def self.call(repo_id, branch = 'master')
    repo = Repository.find(repo_id)
    repo.create_archive(branch)
  end
end
```

It can be any object that responds to `call` but we recommend a class or module which makes switching to a durable queue system (like resque) later easier.

Then to enqueue a task to be run in the background use `Threaded.enqueue`:

```ruby
repo = Repo.last
Threaded.enqueue(Archive, repo.id, 'staging')
```

The first argument is a class that defines the task to be processed and the rest of the arguments are passed to the task when it is run.


# Configure

The default number of worker threads is 16, you can configure that when you start your queue:

```ruby
Threaded.config do |config|
  config.size = 5
end
```

By default jobs have a timeout value of 60 seconds. Since this is an in-memory queue (goes away when your process terminates) it is in your best interests to keep jobs small and quick, and not overload the queue. You can configure a different timeout on start:

```ruby
Threaded.config do |config|
  config.timeout = 90 # timeout is in seconds
end
```

Want a different logger? Specify a different Logger:

```ruby
Threaded.config do |config|
  config.logger = Logger.new(STDOUT)
end
```

As soon as you call `enqueue` a new thread will be added to your thread pool if it is needed, if you wish to explicitly start all threads you can call `Threaded.start`. You can also inline your config if you want when you start the queue:

```ruby
Threaded.start(size: 5, timeout: 90, logger: Logger.new(STDOUT))
```

For testing or guaranteed code execution use the `inline` option:

```ruby
Threaded.inline = true
```

This option bypasses the queue and executes code as it comes.

## Thread Considerations

This worker operates in the same process as your app, that means if your app is CPU bound, it will not be very useful. This worker uses threads which means that to be useful your app needs to either use IO (database calls, file writes/reads, shelling out, etc.) or run on JRuby or Rubinius.

All other threading concerns remain true so be careful for using things like `Dir.chdir` inside of threaded as it changes the directory for all threads. Also don't modify shared data (unless you've got a mutex around it and know what you're doing).

It is possible for you to enqueue more things in your queue than can be processed before your program exits (you hit CTRL+C, or get an exception). When your program exits all jobs promises and enqueued jobs go away as they are not persisted to disk. If you care about your data getting run always call `value` on promises. When `value` is called on promises if it has not already started running it will be run immediately. This functionality allows for the chaining of promises.

To truly preserve data you've `enqueued` into Threaded's background queue you need to switch to a durable queue backend like resque. Alternatively use a promise and call `value` on the `Threaded.later` promise object.

## License

MIT

