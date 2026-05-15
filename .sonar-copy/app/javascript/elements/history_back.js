export default class extends HTMLElement {
  connectedCallback () {
    const link = this.querySelector('a')
    if (!link) return

    link.addEventListener('click', (event) => {
      const sameOriginReferrer =
        document.referrer && new URL(document.referrer).origin === window.location.origin

      if (sameOriginReferrer && window.history.length > 1) {
        event.preventDefault()
        window.history.back()
      }
    })
  }
}
