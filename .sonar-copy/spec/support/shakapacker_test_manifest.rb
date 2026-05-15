# frozen_string_literal: true

require 'json'
require 'fileutils'

RSpec.configure do |config|
  config.before(:suite) do
    packs_dir = Rails.root.join('public', 'packs-test')
    FileUtils.mkdir_p(packs_dir)

    assets = {
      'application.js' => '/packs-test/application.js',
      'form.js' => '/packs-test/form.js',
      'rollbar.js' => '/packs-test/rollbar.js',
      'application.css' => '/packs-test/application.css',
      'form.css' => '/packs-test/form.css'
    }

    assets.each_value do |asset_path|
      absolute_asset_path = Rails.root.join('public', asset_path.delete_prefix('/'))
      FileUtils.mkdir_p(absolute_asset_path.dirname)
      File.write(absolute_asset_path, '') unless File.exist?(absolute_asset_path)
    end

    manifest_path = packs_dir.join('manifest.json')
    File.write(manifest_path, JSON.dump(assets))
    Shakapacker.manifest.refresh if defined?(Shakapacker)
  end
end
