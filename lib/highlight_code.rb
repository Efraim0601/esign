# frozen_string_literal: true

module HighlightCode
  module_function

  def call(code, lexer, theme: 'base16.light')
    require 'rouge/themes/base16' unless Rouge::Theme.registry[theme]

    # Only JSON/Shell lexers are autoloaded in config/initializers/rouge.rb;
    # any other lexer must be required explicitly before const_get can find it.
    lexer_name = lexer.to_s
    require "rouge/lexers/#{lexer_name.downcase}"

    formatter = Rouge::Formatters::HTMLInline.new(theme)
    lexer_class = Rouge::Lexers.const_get(lexer_name.to_sym)
    formatted_code = formatter.format(lexer_class.new.lex(code))
    formatted_code = formatted_code.gsub('background-color: #181818', '') if theme == 'base16.dark'
    formatted_code
  end
end
