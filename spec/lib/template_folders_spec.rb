# frozen_string_literal: true

RSpec.describe TemplateFolders do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  describe '.search' do
    it 'returns the relation unchanged when keyword is blank' do
      relation = account.template_folders
      expect(described_class.search(relation, '')).to eq(relation)
      expect(described_class.search(relation, nil)).to eq(relation)
    end

    it 'matches case-insensitively on the folder name' do
      matching = create(:template_folder, account:, name: 'Contracts')
      create(:template_folder, account:, name: 'Invoices')

      result = described_class.search(account.template_folders, 'CONT')

      expect(result).to include(matching)
      expect(result.size).to eq(1)
    end

    it 'escapes SQL LIKE wildcards in the keyword' do
      create(:template_folder, account:, name: 'My Folder')

      result = described_class.search(account.template_folders, '%')

      expect(result).to be_empty
    end
  end

  describe '.filter_by_full_name' do
    it 'returns none when name is blank' do
      expect(described_class.filter_by_full_name(account.template_folders, nil)).to be_empty
      expect(described_class.filter_by_full_name(account.template_folders, '')).to be_empty
    end

    it 'matches a top-level folder by name when no parent segment is given' do
      folder = create(:template_folder, account:, name: 'Contracts')

      result = described_class.filter_by_full_name(account.template_folders, 'Contracts')

      expect(result.to_a).to eq([folder])
    end

    it 'matches a sub-folder using "Parent / Child" notation' do
      parent = create(:template_folder, account:, name: 'Legal')
      child = create(:template_folder, account:, name: 'Contracts', parent_folder: parent, author: user)

      result = described_class.filter_by_full_name(account.template_folders, 'Legal / Contracts')

      expect(result.to_a).to eq([child])
    end
  end

  describe '.sort' do
    let!(:folder_a) { create(:template_folder, account:, author: user, name: 'Alpha') }
    let!(:folder_b) { create(:template_folder, account:, author: user, name: 'Bravo') }

    it 'orders by name ascending when order is "name"' do
      result = described_class.sort(account.template_folders, user, 'name')
      expect(result.pluck(:name)).to start_with(%w[Alpha Bravo])
    end

    it 'orders by id descending for unknown order values' do
      result = described_class.sort(account.template_folders, user, 'whatever')
      expect(result.pluck(:id).first(2)).to eq([folder_b.id, folder_a.id])
    end

    it 'returns a relation joined with templates for "used_at"' do
      result = described_class.sort(account.template_folders, user, 'used_at')
      expect(result).to respond_to(:to_a)
    end
  end

  describe '.find_or_create_by_name' do
    it 'returns the default folder when name is blank' do
      result = described_class.find_or_create_by_name(user, nil)
      expect(result.name).to eq(TemplateFolder::DEFAULT_NAME)
    end

    it 'returns the default folder when name equals the default name' do
      result = described_class.find_or_create_by_name(user, TemplateFolder::DEFAULT_NAME)
      expect(result.name).to eq(TemplateFolder::DEFAULT_NAME)
    end

    it 'creates a top-level folder when name has no parent segment' do
      expect do
        described_class.find_or_create_by_name(user, 'New Folder')
      end.to change(account.template_folders, :count).by(1)
    end

    it 'reuses an existing folder when one with that name already exists' do
      create(:template_folder, account:, author: user, name: 'Existing')

      expect do
        described_class.find_or_create_by_name(user, 'Existing')
      end.not_to change(account.template_folders, :count)
    end

    it 'creates parent and child folders for "Parent / Child"' do
      expect do
        described_class.find_or_create_by_name(user, 'Parent / Child')
      end.to change(account.template_folders, :count).by(2)

      child = account.template_folders.find_by(name: 'Child')
      expect(child.parent_folder.name).to eq('Parent')
    end
  end
end
