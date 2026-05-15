# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :request) do
    allow_any_instance_of(ActionView::Base).to receive(:javascript_pack_tag).and_return('')
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_pack_tag).and_return('')
  end
end
