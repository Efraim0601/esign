# frozen_string_literal: true

require 'rails_helper'
require 'puma/plugin'

RSpec.describe 'Puma sidekiq_embed plugin' do
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

    load Rails.root.join('lib/puma/plugin/sidekiq_embed.rb')
    plugin_class.new
  end

  it 'configures lifecycle hooks for workers' do
    plugin = load_plugin
    cfg = double('cfg')
    hooks = {}
    allow(cfg).to receive(:instance_variable_get).with(:@options).and_return({ workers: 2 })
    allow(cfg).to receive(:on_worker_boot) { |&b| hooks[:boot] = b }
    allow(cfg).to receive(:on_worker_shutdown) { |&b| hooks[:shutdown] = b }
    allow(cfg).to receive(:on_refork) { |&b| hooks[:refork] = b }
    sidekiq = double('sidekiq', stop: true)
    plugin.instance_variable_set(:@sidekiq, sidekiq)
    allow(plugin).to receive(:start_sidekiq!)

    plugin.config(cfg)
    hooks[:boot].call
    hooks[:shutdown].call
    hooks[:refork].call

    expect(plugin).to have_received(:start_sidekiq!)
    expect(sidekiq).to have_received(:stop).twice
  end

  it 'starts sidekiq in single-process mode and stops on shutdown events' do
    plugin = load_plugin
    events = double('events')
    launcher = double('launcher', events: events)
    after_booted = nil
    after_stopped = nil
    before_restart = nil
    sidekiq = double('sidekiq', stop: true)
    plugin.instance_variable_set(:@sidekiq, sidekiq)
    Puma.singleton_class.send(:define_method, :stats_hash) { { workers: 0 } }
    allow(events).to receive(:after_booted) { |&b| after_booted = b }
    allow(events).to receive(:after_stopped) { |&b| after_stopped = b }
    allow(events).to receive(:before_restart) { |&b| before_restart = b }
    allow(plugin).to receive(:start_sidekiq!)
    allow(Thread).to receive(:new).and_yield.and_return(double('thread', join: true))

    plugin.start(launcher)
    after_booted.call
    after_stopped.call
    before_restart.call

    expect(plugin).to have_received(:start_sidekiq!)
    expect(sidekiq).to have_received(:stop).twice
  end

  it 'fires and clears lifecycle events' do
    plugin = load_plugin
    called = []
    config = { lifecycle_events: { startup: [-> { called << 1 }, -> { called << 2 }] } }

    plugin.fire_event(config, :startup)

    expect(called).to eq([1, 2])
    expect(config[:lifecycle_events][:startup]).to eq([])
  end

  it 'waits for redis with retries and raises after max attempts' do
    plugin = load_plugin
    allow(ENV).to receive(:fetch).with('REDIS_WAIT_ATTEMPTS', 90).and_return('2')
    allow(ENV).to receive(:fetch).with('REDIS_URL', nil).and_return('redis://redis:6379/0')
    client = double('client')
    allow(RedisClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_raise(RedisClient::CannotConnectError.new('fail'))
    allow(plugin).to receive(:sleep)

    expect { plugin.wait_for_redis! }.to raise_error(RuntimeError, /Unable to connect to Redis after 2 attempts/)
  end
end
