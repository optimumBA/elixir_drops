let SponsorImpressionHooks = {}

// Served-impression estimate reporting with server acknowledgment. A placement
// is reported until the server acknowledges it (persisted or intentionally
// skipped). Retries are bounded: at most MAX_ATTEMPTS sends per placement, on
// a timer schedule (not only on a later resize), and each send is abandoned
// after REPLY_TIMEOUT_MS. The server derives a stable event id per visit and
// placement, so a retry after a lost reply cannot be counted twice.
export const MAX_ATTEMPTS = 3
export const RETRY_DELAYS_MS = [1000, 3000]
export const REPLY_TIMEOUT_MS = 5000

export class PlacementReporter {
  // rendered(): placements currently rendered; send(placements): Promise of
  // a reply shaped {acknowledged: [placement, ...]}.
  constructor({ rendered, send }) {
    this.rendered = rendered
    this.send = send
    this.connected = true
    this.stopped = false
    this.states = new Map()
    this.replyTimers = new Set()
  }

  state(placement) {
    if (!this.states.has(placement)) {
      this.states.set(placement, {
        acked: false,
        attempts: 0,
        inflight: false,
        timer: null,
      })
    }
    return this.states.get(placement)
  }

  setConnected(connected) {
    this.connected = connected
    if (connected) this.flush()
  }

  stop() {
    this.stopped = true
    for (const state of this.states.values()) clearTimeout(state.timer)
    for (const timer of this.replyTimers) clearTimeout(timer)
  }

  flush() {
    if (!this.connected || this.stopped) return

    const eligible = this.rendered().filter((placement) => {
      const state = this.state(placement)
      return (
        !state.acked &&
        !state.inflight &&
        state.timer === null &&
        state.attempts < MAX_ATTEMPTS
      )
    })
    if (eligible.length === 0) return

    const batch = eligible.map((placement) => {
      const state = this.state(placement)
      state.attempts += 1
      state.inflight = true
      return placement
    })

    let settled = false
    const fail = () => {
      if (settled) return
      settled = true
      clearTimeout(replyTimer)
      this.replyTimers.delete(replyTimer)
      batch.forEach((placement) => this.failed(placement))
    }
    const replyTimer = setTimeout(fail, REPLY_TIMEOUT_MS)
    this.replyTimers.add(replyTimer)

    let promise
    try {
      promise = Promise.resolve(this.send(batch))
    } catch (_error) {
      return fail()
    }

    promise
      .then((reply) => {
        if (this.stopped) return
        this.replyTimers.delete(replyTimer)
        const acknowledged = (reply && reply.acknowledged) || []
        // A late reply still acknowledges, even after the timeout.
        batch.forEach((placement) => {
          if (acknowledged.includes(placement)) this.acknowledged(placement)
        })
        if (!settled) {
          settled = true
          clearTimeout(replyTimer)
          batch
            .filter((placement) => !acknowledged.includes(placement))
            .forEach((placement) => this.failed(placement))
        }
      })
      .catch(fail)
  }

  acknowledged(placement) {
    const state = this.state(placement)
    state.acked = true
    state.inflight = false
    clearTimeout(state.timer)
    state.timer = null
  }

  failed(placement) {
    const state = this.state(placement)
    if (state.acked) return
    state.inflight = false
    if (this.stopped || state.attempts >= MAX_ATTEMPTS) return

    clearTimeout(state.timer)
    state.timer = setTimeout(
      () => {
        state.timer = null
        this.flush()
      },
      RETRY_DELAYS_MS[Math.min(state.attempts, RETRY_DELAYS_MS.length) - 1]
    )
  }
}

// Separate visible-impression estimate: >=50% in the viewport for a
// continuous 1000ms in a foreground document. This is our implementation rule,
// not a claim of audited viewability. A qualified event remains eligible for
// bounded delivery retries even if the reader subsequently scrolls away.
export const VISIBLE_DWELL_MS = 1000
export class VisibilityReporter {
  constructor({ targets, send }) {
    this.targets = targets
    this.entries = new Map()
    this.timers = new Map()
    this.qualified = new Set()
    this.connected = true
    this.stopped = false
    this.reporter = new PlacementReporter({
      rendered: () => [...this.qualified],
      send,
    })
    this.onVisibility = () => this.check()
    document.addEventListener('visibilitychange', this.onVisibility)
    this.observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          for (const [placement, el] of this.targets) {
            if (el === entry.target)
              this.entries.set(placement, entry.intersectionRatio)
          }
        }
        this.check()
      },
      { threshold: [0, 0.5, 1] }
    )
    for (const el of targets.values()) this.observer.observe(el)
  }

  eligible(placement, el) {
    if (
      !this.connected ||
      this.stopped ||
      document.visibilityState !== 'visible'
    )
      return false
    if ((this.entries.get(placement) || 0) < 0.5) return false
    const rect = el.getBoundingClientRect()
    if (rect.width <= 0 || rect.height <= 0) return false
    const width = Math.max(
      0,
      Math.min(rect.right, window.innerWidth) - Math.max(rect.left, 0)
    )
    const height = Math.max(
      0,
      Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0)
    )
    return (width * height) / (rect.width * rect.height) >= 0.5
  }

  check() {
    for (const [placement, el] of this.targets) {
      if (this.qualified.has(placement)) continue
      if (!this.eligible(placement, el)) {
        clearTimeout(this.timers.get(placement))
        this.timers.delete(placement)
      } else if (!this.timers.has(placement)) {
        this.timers.set(
          placement,
          setTimeout(() => {
            this.timers.delete(placement)
            if (!this.eligible(placement, el)) return
            this.qualified.add(placement)
            this.reporter.flush()
          }, VISIBLE_DWELL_MS)
        )
      }
    }
  }

  setConnected(connected) {
    this.connected = connected
    this.reporter.setConnected(connected)
    this.check()
  }

  stop() {
    this.stopped = true
    this.observer.disconnect()
    document.removeEventListener('visibilitychange', this.onVisibility)
    for (const timer of this.timers.values()) clearTimeout(timer)
    this.timers.clear()
    this.reporter.stop()
  }
}

// Drop page: AppSignal banner and sidebar. Observe actual element sizes so CSS
// remains the eligibility rule (the sidebar is desktop-only).
SponsorImpressionHooks.SponsorImpression = {
  mounted() {
    this.reporter = new PlacementReporter({
      rendered: () =>
        ['banner', 'sidebar']
          .map((placement) => this.renderedPlacement(placement))
          .filter(Boolean),
      send: (placements) =>
        this.pushEvent('sponsor_impression', {
          drop_id: this.el.dataset.dropId,
          placements,
        }),
    })
    const targets = new Map()
    for (const placement of ['banner', 'sidebar']) {
      const el = this.el.querySelector(`#appsignal-drop-${placement}`)
      if (el) targets.set(`drop-${placement}`, el)
    }
    this.visibility = new VisibilityReporter({
      targets,
      send: (placements) =>
        this.pushEvent('sponsor_visible_impression', {
          drop_id: this.el.dataset.dropId,
          placements,
        }),
    })
    this.observer = new ResizeObserver(() => {
      this.reporter.flush()
      this.visibility.check()
    })
    for (const placement of ['banner', 'sidebar']) {
      const el = this.el.querySelector(`#appsignal-drop-${placement}`)
      if (el) this.observer.observe(el)
    }
    this.reporter.flush()
  },

  disconnected() {
    this.reporter.setConnected(false)
    this.visibility.setConnected(false)
  },

  reconnected() {
    this.reporter.setConnected(true)
    this.visibility.setConnected(true)
  },

  destroyed() {
    this.observer.disconnect()
    this.reporter.stop()
    this.visibility.stop()
  },

  renderedPlacement(placement) {
    const el = this.el.querySelector(`#appsignal-drop-${placement}`)
    if (!el) return null

    const rect = el.getBoundingClientRect()
    return rect.width > 0 && rect.height > 0 ? `drop-${placement}` : null
  },
}

export default SponsorImpressionHooks
