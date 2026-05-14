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

    it 'rejects invalid email format in emails-creation payload' do
      params = { template_id: 1, emails: 'not-an-email' }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /emails/)
    end


    it 'accepts message hash with subject + body on submission creation' do
      params = {
        template_id: 1,
        submission: { submitters: [{ email: 'a@example.com' }] },
        message: { subject: 'Hi', body: 'Welcome' }
      }

      expect(described_class.call(params)).to be(true)
    end

    it 'accepts submissions array shape' do
      params = {
        template_id: 1,
        submissions: [{ submitters: [{ email: 'a@example.com' }] }]
      }

      expect(described_class.call(params)).to be(true)
    end

    it 'rejects invalid reply_to email in submitter' do
      params = {
        template_id: 1,
        submitters: [
          { email: 'a@example.com', name: 'A', reply_to: 'not-an-email' }
        ]
      }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /reply_to/)
    end

    it 'rejects invalid bcc_completed email at submission level' do
      params = {
        template_id: 1,
        submitters: [{ email: 'a@example.com' }],
        bcc_completed: 'not-an-email'
      }

      expect do
        described_class.call(params)
      end.to raise_error(Params::BaseValidator::InvalidParameterError, /bcc_completed/)
    end

    it 'validates per-submitter field params and accepts complete ones' do
      params = {
        template_id: 1,
        submitters: [
          { email: 'a@example.com', fields: [{ name: 'Email', uuid: 'f1' }] }
        ]
      }

      expect(described_class.call(params)).to be(true)
    end
  end
end
