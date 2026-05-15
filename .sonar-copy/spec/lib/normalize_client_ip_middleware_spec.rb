# frozen_string_literal: true

RSpec.describe NormalizeClientIpMiddleware do
  let(:app) { ->(env) { [200, {}, [env]] } }
  let(:middleware) { described_class.new(app) }

  it 'forwards env unchanged when HTTP_CLIENT_IP is blank' do
    env = { 'HTTP_X_FORWARDED_FOR' => '203.0.113.1' }

    middleware.call(env)

    expect(env).to eq({ 'HTTP_X_FORWARDED_FOR' => '203.0.113.1' })
  end

  it 'strips port from HTTP_CLIENT_IP when HTTP_X_CLIENT_IP matches the IP portion' do
    env = {
      'HTTP_CLIENT_IP' => '203.0.113.1:54321',
      'HTTP_X_CLIENT_IP' => '203.0.113.1'
    }

    middleware.call(env)

    expect(env['HTTP_CLIENT_IP']).to eq('203.0.113.1')
  end

  it 'leaves HTTP_CLIENT_IP unchanged when HTTP_X_CLIENT_IP does not match' do
    env = {
      'HTTP_CLIENT_IP' => '203.0.113.1:54321',
      'HTTP_X_CLIENT_IP' => '198.51.100.1'
    }

    middleware.call(env)

    expect(env['HTTP_CLIENT_IP']).to eq('203.0.113.1:54321')
  end

  it 'normalizes HTTP_X_FORWARDED_FOR when its IP-without-port equals HTTP_CLIENT_IP' do
    env = {
      'HTTP_CLIENT_IP' => '203.0.113.1',
      'HTTP_X_FORWARDED_FOR' => '203.0.113.1:8080'
    }

    middleware.call(env)

    expect(env['HTTP_X_FORWARDED_FOR']).to eq('203.0.113.1')
  end

  it 'leaves HTTP_X_FORWARDED_FOR alone when its IP differs from HTTP_CLIENT_IP' do
    env = {
      'HTTP_CLIENT_IP' => '203.0.113.1',
      'HTTP_X_FORWARDED_FOR' => '198.51.100.1:8080'
    }

    middleware.call(env)

    expect(env['HTTP_X_FORWARDED_FOR']).to eq('198.51.100.1:8080')
  end

  it 'always calls the underlying app' do
    underlying = instance_double(Proc, call: [200, {}, []])
    middleware = described_class.new(underlying)
    env = { 'HTTP_CLIENT_IP' => '203.0.113.1' }

    middleware.call(env)

    expect(underlying).to have_received(:call).with(env)
  end
end
