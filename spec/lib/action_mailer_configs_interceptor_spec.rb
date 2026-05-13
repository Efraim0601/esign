# frozen_string_literal: true

RSpec.describe ActionMailerConfigsInterceptor do
  describe '.build_smtp_configs_hash' do
    it 'builds TLS smtp settings from default secure port' do
      email_configs = double('email_configs', value: {
                               'username' => 'u',
                               'password' => 'p',
                               'host' => 'smtp.test',
                               'port' => '465',
                               'domain' => 'example.test',
                               'security' => nil
                             })

      hash = described_class.build_smtp_configs_hash(email_configs)

      expect(hash).to include(
        user_name: 'u',
        password: 'p',
        address: 'smtp.test',
        port: '465',
        domain: 'example.test',
        tls: true,
        open_timeout: ActionMailerConfigsInterceptor::OPEN_TIMEOUT,
        read_timeout: ActionMailerConfigsInterceptor::READ_TIMEOUT
      )
      expect(hash[:enable_starttls]).to be_nil
    end

    it 'uses no-verify mode and no authentication when password is blank' do
      email_configs = double('email_configs', value: {
                               'username' => 'u',
                               'password' => '',
                               'host' => 'smtp.test',
                               'port' => '25',
                               'domain' => 'example.test',
                               'security' => 'noverify'
                             })

      hash = described_class.build_smtp_configs_hash(email_configs)

      expect(hash[:openssl_verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
      expect(hash[:authentication]).to be_nil
      expect(hash[:enable_starttls_auto]).to be(true)
    end
  end

  describe '.delivering_email' do
    it 'returns message untouched outside production' do
      message = double('message')
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))

      expect(described_class.delivering_email(message)).to eq(message)
    end

    it 'switches to test delivery method in demo mode' do
      message = double('message')
      allow(message).to receive(:delivery_method)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(Docuseal).to receive(:demo?).and_return(true)

      result = described_class.delivering_email(message)

      expect(result).to eq(message)
      expect(message).to have_received(:delivery_method).with(:test)
    end

    it 'uses account smtp config in single-tenant production when present' do
      message = double('message')
      allow(message).to receive(:delivery_method)
      allow(message).to receive(:from=)

      account = double('account', name: 'Acme "Corp"')
      email_configs = double('email_configs',
                             account: account,
                             value: {
                               'from_email' => 'from@example.test',
                               'username' => 'u',
                               'password' => 'p',
                               'host' => 'smtp.test',
                               'port' => '587',
                               'domain' => 'example.test'
                             })

      relation = double('relation')
      allow(EncryptedConfig).to receive(:order).with(:account_id).and_return(relation)
      allow(relation).to receive(:find_by).with(key: EncryptedConfig::EMAIL_SMTP_KEY).and_return(email_configs)

      action_mailer_config = double('action_mailer_config', delivery_method: nil)
      app_config = double('app_config', action_mailer: action_mailer_config)
      application = double('application', config: app_config)
      allow(Rails).to receive(:application).and_return(application)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(Docuseal).to receive(:demo?).and_return(false)
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(described_class).to receive(:build_smtp_configs_hash).and_return({ address: 'smtp.test' })

      described_class.delivering_email(message)

      expect(message).to have_received(:delivery_method).with(:smtp, { address: 'smtp.test' })
      expect(message).to have_received(:from=).with('"Acme Corp" <from@example.test>')
    end

    it 'overrides from address when global SMTP delivery method is configured' do
      message = Mail.new
      message.from = ['"Legacy Sender" <legacy@example.test>']
      action_mailer_config = double('action_mailer_config', delivery_method: :smtp)
      app_config = double('app_config', action_mailer: action_mailer_config)
      application = double('application', config: app_config)

      allow(Rails).to receive(:application).and_return(application)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(Docuseal).to receive(:demo?).and_return(false)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('SMTP_FROM').and_return('new@example.test')

      described_class.delivering_email(message)

      expect(message[:from].to_s).to include('new@example.test')
    end

    it 'returns message unchanged in multitenant mode when not demo and no global mailer config' do
      message = double('message')
      allow(message).to receive(:delivery_method)
      action_mailer_config = double('action_mailer_config', delivery_method: nil)
      app_config = double('app_config', action_mailer: action_mailer_config)
      application = double('application', config: app_config)

      allow(Rails).to receive(:application).and_return(application)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(Docuseal).to receive(:demo?).and_return(false)
      allow(Docuseal).to receive(:multitenant?).and_return(true)

      expect(described_class.delivering_email(message)).to eq(message)
      expect(message).not_to have_received(:delivery_method)
    end
  end
end
