# frozen_string_literal: true

require 'ostruct'

RSpec.describe Submissions::AssignDefinedSubmitters do
  SubmittersCollection = Struct.new(:items) do
    def any?(&blk)
      items.any?(&blk)
    end

    def new(attrs)
      obj = OpenStruct.new(attrs)
      items << obj
      obj
    end

    def find(&blk)
      items.find(&blk)
    end
  end

  describe '.call' do
    it 'adds defined and linked submitters and sets preserved order' do
      template_submitters = [
        { 'uuid' => 'u1', 'email' => 'a@example.com' },
        { 'uuid' => 'u2', 'linked_to_uuid' => 'u1' }
      ]
      template = double('template', submitters: template_submitters, author: double('author', email: 'author@example.com'))
      submitters = SubmittersCollection.new([])
      submission = OpenStruct.new(template: template, submitters: submitters, account_id: 55, submitters_order: nil)

      described_class.call(submission)

      expect(submission.submitters_order).to eq('preserved')
      expect(submitters.items.map(&:uuid)).to include('u1', 'u2')
      expect(submitters.items.find { |s| s.uuid == 'u2' }.email).to eq('a@example.com')
    end
  end
end
