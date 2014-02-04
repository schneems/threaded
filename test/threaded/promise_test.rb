require 'test_helper'

class PromiseTest < Test::Unit::TestCase

  def test_promise_interface
    Dummy.expects(:process).with(1).once
    Dummy.expects(:process).with(2).once

    promise1 = Threaded.later do
      Dummy.process(1)
    end

    promise2 = Threaded.later do
      Dummy.process(2)
    end

    promise1.value
    promise2.value
  end
end
