# frozen_string_literal: true

RSpec.describe UserSessionIntegrity do
  let(:dummy_class) do
    Class.new do
      include UserSessionIntegrity

      attr_accessor :session, :true_user, :performed_flag, :redirect_target, :redirect_alert,
                    :signed_out

      def initialize
        @session = {}
        @performed_flag = false
      end

      def performed?
        @performed_flag
      end

      def stop_impersonating_user
        # no-op for test
      end

      def sign_out(_user)
        @signed_out = true
      end

      def root_path
        '/'
      end

      def new_user_session_path
        '/users/sign_in'
      end

      def redirect_to(path, alert: nil)
        @redirect_target = path
        @redirect_alert = alert
        @performed_flag = true
      end
    end
  end
  let(:controller) { dummy_class.new }

  describe 'sync_impersonated_permission_version!' do
    it 'stops impersonation when impersonated user no longer exists' do
      controller.session[:impersonated_user_id] = 'gone-uuid'
      controller.session[:impersonated_permission_version] = 1
      allow(User).to receive(:find_by).with(uuid: 'gone-uuid').and_return(nil)

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.session).not_to have_key(:impersonated_permission_version)
    end

    it 'stores expected permission version when none is stored yet' do
      user = double('user', permission_version: 5)
      controller.session[:impersonated_user_id] = 'u1'
      allow(User).to receive(:find_by).with(uuid: 'u1').and_return(user)

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.session[:impersonated_permission_version]).to eq(5)
    end

    it 'stops impersonation and redirects when stored permission version is stale' do
      user = double('user', permission_version: 7)
      controller.session[:impersonated_user_id] = 'u1'
      controller.session[:impersonated_permission_version] = 5
      allow(User).to receive(:find_by).with(uuid: 'u1').and_return(user)
      allow(I18n).to receive(:t).with('your_session_was_refreshed_please_continue').and_return('refreshed')

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.redirect_target).to eq('/')
      expect(controller.redirect_alert).to eq('refreshed')
      expect(controller.session).not_to have_key(:impersonated_permission_version)
    end

    it 'does nothing when impersonated permission version matches' do
      user = double('user', permission_version: 3)
      controller.session[:impersonated_user_id] = 'u1'
      controller.session[:impersonated_permission_version] = 3
      allow(User).to receive(:find_by).with(uuid: 'u1').and_return(user)
      controller.true_user = nil

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.redirect_target).to be_nil
    end
  end

  describe 'sync_true_user_permission_version!' do
    it 'is a no-op when there is no true_user' do
      controller.true_user = nil

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.session).not_to have_key(:user_permission_version)
    end

    it 'stores expected version when session has none' do
      controller.true_user = double('user', permission_version: 9)

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.session[:user_permission_version]).to eq(9)
    end

    it 'signs out and redirects when stored version is stale' do
      controller.true_user = double('user', permission_version: 10)
      controller.session[:user_permission_version] = 9
      controller.session[:impersonated_permission_version] = 1
      allow(I18n).to receive(:t).with('your_session_was_refreshed_sign_in_again').and_return('signin')

      controller.send(:enforce_user_session_permission_version!)

      expect(controller.signed_out).to be(true)
      expect(controller.redirect_target).to eq('/users/sign_in')
      expect(controller.redirect_alert).to eq('signin')
      expect(controller.session).not_to have_key(:user_permission_version)
    end
  end
end
