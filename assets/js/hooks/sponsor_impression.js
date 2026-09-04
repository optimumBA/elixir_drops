let SponsorImpressionHooks = {}

// Count a placement when it first renders, including a sidebar revealed by
// resizing. Observe actual element sizes so CSS remains the eligibility rule.
SponsorImpressionHooks.SponsorImpression = {
  mounted() {
    this.sentPlacements = new Set()
    this.connected = true
    this.observer = new ResizeObserver(() => this.reportPlacements())
    for (const placement of ['banner', 'sidebar']) {
      const el = this.el.querySelector(`#appsignal-drop-${placement}`)
      if (el) this.observer.observe(el)
    }
    this.reportPlacements()
  },

  disconnected() {
    this.connected = false
  },

  reconnected() {
    this.connected = true
    this.reportPlacements()
  },

  destroyed() {
    this.observer.disconnect()
  },

  reportPlacements() {
    if (!this.connected) return

    const placements = ['banner', 'sidebar']
      .map((placement) => this.renderedPlacement(placement))
      .filter((placement) => placement && !this.sentPlacements.has(placement))

    if (placements.length === 0) return
    placements.forEach((placement) => this.sentPlacements.add(placement))
    this.pushEvent('sponsor_impression', {
      drop_id: this.el.dataset.dropId,
      placements,
    }).catch(() => {
      // Permit a later resize/reconnect to retry a failed delivery.
      placements.forEach((placement) => this.sentPlacements.delete(placement))
    })
  },

  renderedPlacement(placement) {
    const el = this.el.querySelector(`#appsignal-drop-${placement}`)
    if (!el) return null

    const rect = el.getBoundingClientRect()
    return rect.width > 0 && rect.height > 0 ? `drop-${placement}` : null
  },
}

export default SponsorImpressionHooks
