# frozen_string_literal: true

FactoryBot.define do
  factory :encrypted_config do
    account
    sequence(:key) { |n| "test_encrypted_key_#{n}" }
    value { 'test_secret' }
  end
end
