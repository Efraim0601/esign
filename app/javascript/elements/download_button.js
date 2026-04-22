import { target, targetable } from '@github/catalyst/lib/targetable'

export default targetable(class extends HTMLElement {
  static [target.static] = ['defaultButton', 'loadingButton']

  connectedCallback () {
    this.addEventListener('click', () => this.downloadFiles())
  }

  toggleState () {
    this.defaultButton?.classList?.toggle('hidden')
    this.loadingButton?.classList?.toggle('hidden')
  }

  downloadFiles () {
    if (!this.dataset.src) return

    this.toggleState()

    fetch(this.dataset.src, { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then(async (response) => {
        if (!response.ok) {
          console.error('Download request failed', response.status, response.statusText, this.dataset.src)
          alert(`Failed to download files (HTTP ${response.status})`)
          this.toggleState()
          return
        }

        const urls = await response.json()

        if (!Array.isArray(urls) || urls.length === 0) {
          console.error('Download response had no URLs', urls)
          alert('No files available to download yet.')
          this.toggleState()
          return
        }

        const isMobileSafariIos = 'ontouchstart' in window && navigator.maxTouchPoints > 0 && /AppleWebKit/i.test(navigator.userAgent)
        const isSafariIos = isMobileSafariIos || /iPhone|iPad|iPod/i.test(navigator.userAgent)

        if (isSafariIos && urls.length > 1) {
          this.downloadSafariIos(urls)
        } else {
          this.downloadUrls(urls)
        }
      })
      .catch((error) => {
        console.error('Download error', error)
        alert(`Failed to download files: ${error.message}`)
        this.toggleState()
      })
  }

  downloadUrls (urls) {
    const fileRequests = urls.map((url) => {
      return () => {
        return fetch(url, { credentials: 'same-origin' }).then(async (resp) => {
          if (!resp.ok) throw new Error(`HTTP ${resp.status} on ${url}`)

          const blobUrl = URL.createObjectURL(await resp.blob())
          const link = document.createElement('a')

          link.href = blobUrl
          link.setAttribute('download', decodeURI(url.split('/').pop()))

          link.click()

          URL.revokeObjectURL(blobUrl)
        })
      }
    })

    fileRequests.reduce(
      (prevPromise, request) => prevPromise.then(() => request()),
      Promise.resolve()
    ).catch((error) => {
      console.error('Download error', error)
      alert(`Failed to download files: ${error.message}`)
    }).finally(() => {
      this.toggleState()
    })
  }

  downloadSafariIos (urls) {
    const fileRequests = urls.map((url) => {
      return fetch(url, { credentials: 'same-origin' }).then(async (resp) => {
        const blob = await resp.blob()
        const blobUrl = URL.createObjectURL(blob.slice(0, blob.size, 'application/octet-stream'))
        const link = document.createElement('a')

        link.href = blobUrl
        link.setAttribute('download', decodeURI(url.split('/').pop()))

        return link
      })
    })

    Promise.all(fileRequests).then((links) => {
      links.forEach((link, index) => {
        setTimeout(() => {
          link.click()

          URL.revokeObjectURL(link.href)
        }, index * 50)
      })
    }).finally(() => {
      this.toggleState()
    })
  }
})
