# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::BulkImport do
  describe '.call' do
    it 'iterates rows with line numbers starting at 2' do
      row1 = Users::BulkImport::Row.new(email: 'a@example.test', first_name: 'A', last_name: 'One', role: 'member')
      row2 = Users::BulkImport::Row.new(email: 'b@example.test', first_name: 'B', last_name: 'Two', role: 'member')
      account = double('account')

      allow(described_class).to receive(:parse_rows).and_return([row1, row2])
      allow(described_class).to receive(:process_row)

      result = described_class.call(file: double('file'), account: account)

      expect(result).to be_a(Users::BulkImport::Result)
      expect(described_class).to have_received(:process_row).with(row1, 2, account, result)
      expect(described_class).to have_received(:process_row).with(row2, 3, account, result)
    end
  end

  describe '.normalize_role' do
    it 'maps localized aliases to canonical role' do
      expect(described_class.normalize_role('administrateur')).to eq('admin')
      expect(described_class.normalize_role('éditeur')).to eq('editor')
    end

    it 'falls back to member for unknown roles' do
      expect(described_class.normalize_role('unknown-role')).to eq('member')
    end
  end

  describe '.detect_separator' do
    it 'detects semicolon separated csv' do
      expect(described_class.detect_separator("email;first_name;last_name;role\n")).to eq(';')
    end

    it 'defaults to comma separator' do
      expect(described_class.detect_separator("email,first_name,last_name,role\n")).to eq(',')
    end
  end

  describe '.validate_headers!' do
    it 'raises InvalidFile when required headers are missing' do
      expect do
        described_class.validate_headers!(%w[email first_name])
      end.to raise_error(Users::BulkImport::InvalidFile, /Colonnes manquantes/)
    end
  end

  describe '.parse_rows' do
    it 'raises InvalidFile for unsupported extension' do
      file = double('file', original_filename: 'users.txt')

      expect do
        described_class.parse_rows(file)
      end.to raise_error(Users::BulkImport::InvalidFile, /Format non supporté/)
    end

    it 'delegates to parse_xlsx for xlsx files' do
      file = double('file', original_filename: 'users.xlsx')
      allow(described_class).to receive(:parse_xlsx).with(file).and_return([])

      described_class.parse_rows(file)

      expect(described_class).to have_received(:parse_xlsx).with(file)
    end
  end

  describe '.parse_csv' do
    it 'parses rows with BOM and mixed-case headers' do
      file = double('file')
      allow(file).to receive(:read).and_return("\uFEFFEmail,first_name,last_name,role\nUSER@EXAMPLE.TEST,John,Doe,admin\n")

      rows = described_class.parse_csv(file)

      expect(rows.size).to eq(1)
      expect(rows.first.email).to eq('USER@EXAMPLE.TEST')
      expect(rows.first.first_name).to eq('John')
      expect(rows.first.last_name).to eq('Doe')
      expect(rows.first.role).to eq('admin')
    end

    it 'raises InvalidFile on malformed csv' do
      file = double('file')
      allow(file).to receive(:read).and_return('broken')
      allow(CSV).to receive(:parse).and_raise(CSV::MalformedCSVError.new('bad csv', 1))

      expect do
        described_class.parse_csv(file)
      end.to raise_error(Users::BulkImport::InvalidFile, /CSV invalide/)
    end
  end

  describe '.process_row' do
    let(:result) { Users::BulkImport::Result.new }
    let(:account) { double('account') }

    it 'adds skipped result when user already exists' do
      row = Users::BulkImport::Row.new(email: 'exists@example.test', first_name: 'A', last_name: 'B', role: 'member')

      allow(User).to receive(:exists?).with(email: 'exists@example.test').and_return(true)

      described_class.process_row(row, 2, account, result)

      expect(result.skipped.first[:reason]).to include('utilisateur existe déjà')
    end

    it 'adds error when email is blank' do
      row = Users::BulkImport::Row.new(email: ' ', first_name: 'A', last_name: 'B', role: 'member')

      described_class.process_row(row, 2, account, result)

      expect(result.errors.first).to include(line: 2, email: '', reason: 'email manquant')
    end

    it 'adds error when email is invalid' do
      row = Users::BulkImport::Row.new(email: 'not-an-email', first_name: 'A', last_name: 'B', role: 'member')

      described_class.process_row(row, 2, account, result)

      expect(result.errors.first).to include(line: 2, email: 'not-an-email', reason: 'email invalide')
    end

    it 'creates user and enqueues invitation email on success' do
      row = Users::BulkImport::Row.new(email: 'new@example.test', first_name: 'A', last_name: 'B', role: 'administrateur')
      user = double('user', save: true)
      mail = double('mail')

      allow(User).to receive(:exists?).with(email: 'new@example.test').and_return(false)
      allow(User).to receive(:new).and_return(user)
      allow(UserMailer).to receive(:invitation_email).with(user).and_return(mail)
      allow(mail).to receive(:deliver_later!)

      described_class.process_row(row, 2, account, result)

      expect(User).to have_received(:new).with(hash_including(email: 'new@example.test', role: 'admin'))
      expect(UserMailer).to have_received(:invitation_email).with(user)
      expect(mail).to have_received(:deliver_later!)
      expect(result.created.first).to include(line: 2, email: 'new@example.test', role: 'admin')
    end

    it 'still marks row as created when invitation enqueue fails' do
      row = Users::BulkImport::Row.new(email: 'new2@example.test', first_name: 'A', last_name: 'B', role: 'member')
      user = double('user', save: true)
      mail = double('mail')
      logger = double('logger', warn: nil)

      allow(User).to receive(:exists?).with(email: 'new2@example.test').and_return(false)
      allow(User).to receive(:new).and_return(user)
      allow(UserMailer).to receive(:invitation_email).with(user).and_return(mail)
      allow(mail).to receive(:deliver_later!).and_raise(StandardError.new('queue down'))
      allow(Rails).to receive(:logger).and_return(logger)

      described_class.process_row(row, 3, account, result)

      expect(logger).to have_received(:warn).with(/invitation email queue failed/)
      expect(result.created.first).to include(line: 3, email: 'new2@example.test')
    end

    it 'adds error when user save fails' do
      row = Users::BulkImport::Row.new(email: 'fail@example.test', first_name: 'A', last_name: 'B', role: 'member')
      errors = double('errors', full_messages: ['Role is invalid'])
      user = double('user', save: false, errors: errors)

      allow(User).to receive(:exists?).with(email: 'fail@example.test').and_return(false)
      allow(User).to receive(:new).and_return(user)

      described_class.process_row(row, 4, account, result)

      expect(result.errors.first).to include(line: 4, email: 'fail@example.test')
      expect(result.errors.first[:reason]).to include('Role is invalid')
    end

    it 'captures unexpected exceptions and records error' do
      row = Users::BulkImport::Row.new(email: 'boom@example.test', first_name: 'A', last_name: 'B', role: 'member')
      logger = double('logger', error: nil)

      allow(User).to receive(:exists?).with(email: 'boom@example.test').and_return(false)
      allow(User).to receive(:new).and_raise(StandardError.new('boom'))
      allow(Rails).to receive(:logger).and_return(logger)

      described_class.process_row(row, 5, account, result)

      expect(logger).to have_received(:error).with(/line 5/)
      expect(result.errors.first[:reason]).to include('StandardError: boom')
    end
  end
end
