require 'simplecov-lcov'
require 'simplecov_json_formatter'

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end

SimpleCov.start 'rails' do
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
