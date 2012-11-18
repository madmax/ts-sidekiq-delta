module SphinxHelpers
  include Sidekiq::Util

  def sphinx
    @sphinx ||= SphinxController.new
  end

  def index(*indices)
    yield if block_given?

    ThinkingSphinx::Deltas::SidekiqDelta.clear_thinking_sphinx_queues
    sphinx.index *indices
    sleep 0.25
  end

  def work
    client    = Redis.connect(:url => "resque://localhost:6379/")
    namespace = Redis::Namespace.new('test', :redis => client)

    Sidekiq::Client.registered_queues.each do |queue_name|
      while message = namespace.lpop("queue:#{queue_name}")
        message = JSON.parse(message)
        constantize(message['class']).new.perform(*message['args'])
      end
    end
  end
end

RSpec.configure do |config|
  config.include SphinxHelpers

  config.before :all do |group|
    sphinx.setup && sphinx.start if group.class.metadata[:live]
  end

  config.after :all do |group|
    sphinx.stop if group.class.metadata[:live]
  end
end
