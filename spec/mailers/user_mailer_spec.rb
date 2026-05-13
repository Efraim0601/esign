# frozen_string_literal: true

RSpec.describe UserMailer do
  let(:account) { create(:account, locale: 'en') }
  let(:user) { create(:user, account:, email: 'invitee@example.test') }

  describe '#invitation_email' do
    it 'builds invitation email and generates reset token' do
      message = Mail.new(to: user.email, subject: "Invited to #{Docuseal.product_name}")
      allow(user).to receive(:set_reset_password_token).and_return('reset-token')
      allow_any_instance_of(UserMailer).to receive(:mail).and_return(message)

      mailer = described_class.new
      message = mailer.invitation_email(user)

      expect(message.to).to include(user.email)
      expect(message.subject).to include(Docuseal.product_name)
      expect(mailer.instance_variable_get(:@token)).to eq('reset-token')
    end
  end

  describe '#role_changed' do
    it 'builds role change email with static subject' do
      changed_by = create(:user, account:, email: 'admin@example.test')
      message = Mail.new(to: user.email, subject: "Vos droits d'accès DocuSeal ont été modifiés")
      allow_any_instance_of(UserMailer).to receive(:mail).and_return(message)
      result = described_class.new.role_changed(user, 'member', 'editor', changed_by.id)

      expect(result).to eq(message)
      expect(message.to).to eq([user.email])
    end
  end
end
