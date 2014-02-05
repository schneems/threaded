# Redirects STDOUT to `Thread.current[:stdout]` if present
class Threaded::StdThreadOut
  def self.puts(value)
    if Thread.current[:stdout]
      Thread.current[:stdout].puts value
    else
      $stdout.puts value
    end
  end
end
