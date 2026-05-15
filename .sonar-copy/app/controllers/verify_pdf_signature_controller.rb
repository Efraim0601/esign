# frozen_string_literal: true

class VerifyPdfSignatureController < ApplicationController
  skip_authorization_check

  def create
    if params[:files].blank?
      return render turbo_stream: turbo_stream.replace('result',
                                                       html: helpers.tag.div(I18n.t('file_is_missing'), id: 'result'))
    end

    pdfs =
      params[:files].map do |file|
        HexaPDF::Document.new(io: file.open)
      end

    trusted_certs = Accounts.load_trusted_certs(current_account)

    render turbo_stream: turbo_stream.replace('result', partial: 'result',
                                                        locals: { pdfs:, files: params[:files], trusted_certs: })
  rescue HexaPDF::MalformedPDFError
    render turbo_stream: turbo_stream.replace('result', html: helpers.tag.div(I18n.t('invalid_pdf'), id: 'result'))
  rescue StandardError => e
    Rails.logger.error("[VerifyPdfSignature] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    Rollbar.error(e) if defined?(Rollbar)
    render turbo_stream: turbo_stream.replace('result',
                                              html: helpers.tag.div("#{I18n.t('invalid_pdf')} (#{e.class})", id: 'result'))
  end
end
