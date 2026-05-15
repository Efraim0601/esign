# frozen_string_literal: true

class SubmissionsChainLinkController < ApplicationController
  load_and_authorize_resource :submission

  def create
    @submission.preferences = @submission.preferences.merge('chain_link_enabled' => true)
    @submission.save!

    redirect_to submission_path(@submission), notice: I18n.t('chain_link_enabled_notice')
  end

  def destroy
    @submission.preferences = @submission.preferences.merge('chain_link_enabled' => false)
    @submission.save!

    redirect_to submission_path(@submission), notice: I18n.t('chain_link_disabled_notice')
  end
end
