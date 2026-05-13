require 'simplecov-lcov'
require 'simplecov_json_formatter'

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end

SimpleCov.start 'rails' do
  # SonarQube considère souvent les fichiers absents du report comme "0%".
  # En trackant explicitement app/ et lib/, on a une baseline stable, même si
  # certains fichiers ne sont pas chargés par les specs.
  track_files '{app,lib}/**/*.rb'

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/db/migrate/'
  add_filter '/vendor/'
end
