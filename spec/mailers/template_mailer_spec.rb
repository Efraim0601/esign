# frozen_string_literal: true

RSpec.describe TemplateMailer do
  let(:account) { create(:account, locale: 'en') }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }

  describe '#otp_verification_email' do
    it 'sends otp email and stores generated otp code' do
      message = Mail.new(to: 'user@example.test', subject: I18n.t('email_verification'))
      allow(EmailVerificationCodes).to receive(:generate).and_return('654321')
      allow_any_instance_of(TemplateMailer).to receive(:mail).and_return(message)

      mailer = described_class.new
      result = mailer.otp_verification_email(template, email: 'user@example.test')

      expect(EmailVerificationCodes).to have_received(:generate).with("user@example.test:#{template.slug}")
      expect(result).to eq(message)
      expect(message.to).to eq(['user@example.test'])
      expect(message.subject).to eq(I18n.t('email_verification'))
      expect(mailer.instance_variable_get(:@otp_code)).to eq('654321')
    end
  end
end
