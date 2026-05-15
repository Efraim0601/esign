# frozen_string_literal: true

FactoryBot.define do
  factory :account_config do
    account
    sequence(:key) { |n| "test_config_key_#{n}" }
    value { 'test_value' }
  end
end
