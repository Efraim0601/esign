# frozen_string_literal: true

class EmbedScriptsController < ActionController::Metal
  DUMMY_SCRIPT = <<~JAVASCRIPT.freeze
    const DummyBuilder = class extends HTMLElement {
      connectedCallback() {
        this.innerHTML = '';
      }
    };

    const DummyForm = class extends DummyBuilder {};

    if (!window.customElements.get('docuseal-builder')) {
      window.customElements.define('docuseal-builder', DummyBuilder);
    }

    if (!window.customElements.get('docuseal-form')) {
      window.customElements.define('docuseal-form', DummyForm);
    }
  JAVASCRIPT

  def show
    headers['Content-Type'] = 'application/javascript'

    self.response_body = DUMMY_SCRIPT

    self.status = 200
  end
end
