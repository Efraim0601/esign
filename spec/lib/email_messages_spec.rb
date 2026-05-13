# frozen_string_literal: true

RSpec.describe EmailMessages do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  describe '.find_or_create_for_account_user' do
    it 'creates a new email message when none exists for the (subject, body) pair' do
      expect do
        described_class.find_or_create_for_account_user(account, user, 'Hello', 'Body content')
      end.to change(account.email_messages, :count).by(1)
    end

    it 'reuses the existing email message when subject and body match' do
      first = described_class.find_or_create_for_account_user(account, user, 'Hello', 'Body content')

      expect do
        again = described_class.find_or_create_for_account_user(account, user, 'Hello', 'Body content')
        expect(again).to eq(first)
      end.not_to change(account.email_messages, :count)
    end

    it 'creates a new message when body differs' do
      described_class.find_or_create_for_account_user(account, user, 'Hello', 'Body A')

      expect do
        described_class.find_or_create_for_account_user(account, user, 'Hello', 'Body B')
      end.to change(account.email_messages, :count).by(1)
    end

    it 'falls back to the default invitation subject when blank' do
      message = described_class.find_or_create_for_account_user(account, user, nil, 'Body content')
      expect(message.subject).to eq(I18n.t(:you_are_invited_to_sign_a_document))
    end

    it 'assigns the given user as author' do
      message = described_class.find_or_create_for_account_user(account, user, 'Hello', 'Body content')
      expect(message.author).to eq(user)
    end
  end
end
