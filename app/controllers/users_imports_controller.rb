# frozen_string_literal: true

class UsersImportsController < ApplicationController
  before_action :authorize_import

  def new; end

  def create
    file = params[:file]

    if file.blank?
      flash.now[:alert] = 'Veuillez sélectionner un fichier.'
      return render :new, status: :unprocessable_content
    end

    @result = Users::BulkImport.call(file: file, account: current_account)

    render :create
  rescue Users::BulkImport::InvalidFile => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  rescue StandardError => e
    Rails.logger.error("[UsersImports] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    flash.now[:alert] = "Erreur inattendue: #{e.class} — #{e.message}"
    render :new, status: :unprocessable_content
  end

  private

  def authorize_import
    authorize!(:create, User.new(account: current_account))
  end
end
