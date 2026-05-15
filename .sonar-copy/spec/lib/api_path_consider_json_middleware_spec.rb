# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiPathConsiderJsonMiddleware do
  describe '#call' do
    it 'sets content type to json for regular api endpoints' do
      app = ->(env) { [200, {}, [env['CONTENT_TYPE']]] }
      middleware = described_class.new(app)
      env = { 'PATH_INFO' => '/api/submissions', 'REQUEST_METHOD' => 'GET' }

      _status, _headers, body = middleware.call(env)

      expect(body).to eq(['application/json'])
    end

    it 'does not force json content type for attachments endpoint' do
      app = ->(env) { [200, {}, [env['CONTENT_TYPE']]] }
      middleware = described_class.new(app)
      env = { 'PATH_INFO' => '/api/attachments', 'REQUEST_METHOD' => 'POST' }

      _status, _headers, body = middleware.call(env)

      expect(body).to eq([nil])
    end

    it 'does not force json content type for documents post endpoint' do
      app = ->(env) { [200, {}, [env['CONTENT_TYPE']]] }
      middleware = described_class.new(app)
      env = { 'PATH_INFO' => '/api/submissions/1/documents', 'REQUEST_METHOD' => 'POST' }

      _status, _headers, body = middleware.call(env)

      expect(body).to eq([nil])
    end
  end
end
