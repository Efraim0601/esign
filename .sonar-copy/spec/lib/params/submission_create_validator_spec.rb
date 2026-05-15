# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Params::SubmissionCreateValidator do
  describe '.call' do
    it 'accepts creation from emails payload' do
      params = {
        template_id: 1,
        emails: 'user@example.com',
        send_email: true,
        message: { body: 'Hello' }
      }

      expect(described_class.call(params)).to be(true)
    end

    it 'validates submitters payload and rejects duplicate roles' do
      params = {
        template_id: 1,
        submitters: [
          { role: 'Signer', email: 'a@example.com' },
          { role: 'Signer', email: 'b@example.com' }
        ]
      }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /role must be unique/)
    end

    it 'rejects invalid phone format in submitter' do
      params = {
        template_id: 1,
        submitters: [
          {
            role: 'Signer',
            phone: '12345',
            name: 'John',
            fields: [{ name: 'first_name', uuid: 'f1' }]
          }
        ]
      }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /phone should start with \+</)
    end

    it 'rejects invalid order value in submission payload' do
      params = {
        template_id: 1,
        submission: { submitters: [{ email: 'a@example.com' }] },
        order: 'invalid'
      }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /order must be one of preserved, random/)
    end

    it 'requires submitters when no supported input shape is provided' do
      params = { template_id: 1 }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /submitters is required/)
    end
  end
end
