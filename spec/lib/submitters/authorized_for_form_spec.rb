# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::AuthorizedForForm do
  describe '.totp_user_for' do
    let(:account) { create(:account) }
    let(:submission) { create(:submission, account:) }

    context 'when no user matches the submitter email' do
      let(:submitter) { create(:submitter, submission:, email: 'stranger@example.com') }

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end

    context 'when a user matches but has not enabled TOTP' do
      let(:submitter) { create(:submitter, submission:, email: 'alice@example.com') }

      before do
        create(:user, account:, email: 'alice@example.com', otp_required_for_login: false)
      end

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end

    context 'when a user matches in another account' do
      let(:other_account) { create(:account) }
      let(:submitter) { create(:submitter, submission:, email: 'alice@example.com') }

      before do
        create(:user, account: other_account, email: 'alice@example.com',
                      otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end

    context 'when a matching user has TOTP enabled in the same account' do
      let(:submitter) { create(:submitter, submission:, email: 'Alice@Example.com ') }
      let!(:user) do
        create(:user, account:, email: 'alice@example.com',
                      otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      it 'returns the user (case- and whitespace-insensitive)' do
        expect(described_class.totp_user_for(submitter)).to eq(user)
      end
    end

    context 'when submitter has no email' do
      let(:submitter) { create(:submitter, submission:, email: nil) }

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end
  end
end
