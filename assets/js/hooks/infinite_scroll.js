// assets/js/infinite_scroll.js
export default InfiniteScroll = {
  page() {
    return this.el.dataset.page
  },
  loadMore(entries) {
    // line 8 grabs the target element
    const target = entries[0]
    if (target.isIntersecting && this.pending == this.page()) {
      this.pending = this.page() + 1
      this.pushEvent('load-more', {})
    }
  },
  mounted() {
    this.pending = this.page()
    // initializing the intersection observer
    // First argument to the IntersectionObserver is the callback function to be executed
    // then the second argument is the options passed to the intersection observer
    this.observer = new IntersectionObserver(
      (entries) => this.loadMore(entries),
      {
        root: null, // window by default
        rootMargin: '400px',
        // As long as 10% of the root element is visible on the screen....Fire!!
        threshold: 0.1,
      }
    )
    this.observer.observe(this.el)
  },
  destroyed() {
    this.observer.unobserve(this.el)
  },
  updated() {
    this.pending = this.page()
  },
}
