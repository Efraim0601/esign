# frozen_string_literal: true

class TemplatesCodeModalController < ApplicationController
  load_and_authorize_resource :template

  def show
    # no-op (Rails implicit rendering / stub)
  end
end
