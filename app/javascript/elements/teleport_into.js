export default class extends HTMLElement {
  connectedCallback () {
    if (!this.dataset.target) return

    if (!this.attemptTeleport()) {
      this.observer = new MutationObserver(() => {
        if (this.attemptTeleport()) this.observer.disconnect()
      })
      this.observer.observe(document.body, { childList: true, subtree: true })
    }
  }

  disconnectedCallback () {
    this.observer?.disconnect()
  }

  attemptTeleport () {
    const target = document.querySelector(this.dataset.target)
    if (!target) return false

    const position = this.dataset.position || 'append'
    const children = Array.from(this.children)

    if (position === 'prepend') {
      children.reverse().forEach((child) => target.insertBefore(child, target.firstChild))
    } else {
      children.forEach((child) => target.appendChild(child))
    }

    this.remove()
    return true
  }
}
