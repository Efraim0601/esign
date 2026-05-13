# frozen_string_literal: true

require 'rails_helper'
require 'puma/plugin'

RSpec.describe 'Puma redis_server plugin' do
  def load_plugin
    plugin_class = nil

    allow(Puma::Plugin).to receive(:create) do |&blk|
      plugin_class = Class.new do
        def in_background(&block)
          block.call
        end
      end
      plugin_class.class_eval(&blk)
    end

    load Rails.root.join('lib/puma/plugin/redis_server.rb')
    plugin_class.new
  end

  it 'returns early when LOCAL_REDIS_URL is missing' do
    plugin = load_plugin
    launcher = double('launcher')
    allow(ENV).to receive(:[]).with('LOCAL_REDIS_URL').and_return('')

    expect(plugin.start(launcher)).to be_nil
  end

  it 'registers hooks and stops redis on lifecycle events' do
    plugin = load_plugin
    events = double('events')
    launcher = double('launcher', events: events)
    after_booted = nil
    after_stopped = nil
    before_restart = nil
    stop_calls = 0

    allow(ENV).to receive(:[]).with('LOCAL_REDIS_URL').and_return('redis://local')
    allow(plugin).to receive(:fork_redis).and_return(555)
    allow(plugin).to receive(:in_background).and_yield
    allow(plugin).to receive(:monitor_redis)
    allow(plugin).to receive(:stop_redis_server) { stop_calls += 1 }
    allow(events).to receive(:after_booted) { |&b| after_booted = b }
    allow(events).to receive(:after_stopped) { |&b| after_stopped = b }
    allow(events).to receive(:before_restart) { |&b| before_restart = b }

    plugin.start(launcher)
    after_booted.call
    after_stopped.call
    before_restart.call

    expect(plugin).to have_received(:monitor_redis)
    expect(stop_calls).to eq(2)
  end

  it 'detects dead redis process when waitpid raises' do
    plugin = load_plugin
    plugin.instance_variable_set(:@redis_server_pid, 777)
    allow(Process).to receive(:waitpid).and_raise(Errno::ECHILD)

    expect(plugin.send(:redis_dead?)).to be(true)
  end

  it 'stops redis server and swallows missing-process errors' do
    plugin = load_plugin
    plugin.instance_variable_set(:@redis_server_pid, 888)
    allow(Process).to receive(:kill).with(:INT, 888)
    allow(Process).to receive(:wait).with(888).and_raise(Errno::ESRCH)

    expect { plugin.send(:stop_redis_server) }.not_to raise_error
  end
end
