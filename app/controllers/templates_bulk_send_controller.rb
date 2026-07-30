# frozen_string_literal: true

class TemplatesBulkSendController < ApplicationController
  load_and_authorize_resource :template

  before_action :authorize_bulk_send

  def new; end

  def create
    file = params[:file]

    if file.blank?
      flash.now[:alert] = 'Veuillez sélectionner un fichier.'
      return render :new, status: :unprocessable_content
    end

    @result = Submissions::BulkSend.call(file:, template: @template, user: current_user)

    render :create
  rescue Submissions::BulkSend::InvalidFile => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  rescue StandardError => e
    Rails.logger.error("[TemplatesBulkSend] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    flash.now[:alert] = "Erreur inattendue: #{e.class} — #{e.message}"
    render :new, status: :unprocessable_content
  end

  private

  def authorize_bulk_send
    authorize!(:manage, :bulk_send)
  end
end
