import { animate } from "motion"

let AnimatedCardHooks = {}

AnimatedCardHooks.GridCardData = {
  mounted() {
    const cardElement = this.el
    const id = cardElement.dataset.dropShortId
    const rect = cardElement.getBoundingClientRect()

    const cardData = {
      id: id,
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
    }

    sessionStorage.setItem(`cardAnimationData-${id}`, JSON.stringify(cardData))
  },
}

AnimatedCardHooks.AnimateDropExpansion = {
  mounted() {
    const dropDetails = this.el
    const shortId = dropDetails.dataset.shortId
    const element = dropDetails.querySelector(`#drop-details-${shortId}`)
    const animationDataString = sessionStorage.getItem(`cardAnimationData-${shortId}`)
    
    if (!animationDataString || !element) {
      animate(element, { opacity: [0, 1] }, { duration: 0.3, ease: "easeOut" })
      return
    }
    
    const animationData = JSON.parse(animationDataString)
    console.log(animationData)
    sessionStorage.removeItem(`cardAnimationData-${shortId}`)
    
    this.animateExpansion(element, animationData)
  },

  animateExpansion(element, startData) {
    const endRect = element.getBoundingClientRect()
    
    const startScale = {
      x: startData.width / endRect.width,
      y: startData.height / endRect.height
    }
    
    const transformOriginX = startData.x + (startData.width / 2)
    const transformOriginY = 0
    
    element.style.transformOrigin = `${transformOriginX}px ${transformOriginY}px`
    
    animate(
      element,
      {
        scale: [startScale.x, 1],
        scaleY: [startScale.y, 1],
        opacity: [0.8, 1]
      },
      {
        duration: 1.0,
        ease: [0.25, 0.46, 0.45, 0.94]
      }
    ).then(() => {
      element.style.transformOrigin = ''
    })
  }
}

export default AnimatedCardHooks
