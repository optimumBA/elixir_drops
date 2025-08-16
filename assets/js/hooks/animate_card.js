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
    
    if (!animationDataString || !element) return
    
    const animationData = JSON.parse(animationDataString)
    sessionStorage.removeItem(`cardAnimationData-${shortId}`)
    
    const animateExpansion = (element, startData) => {
      const endRect = element.getBoundingClientRect()
      
      const startScale = {
        x: startData.width / endRect.width,
        y: startData.height / endRect.height
      }
      
      const transformOriginX = startData.x + (startData.width / 2)
      const transformOriginY = 0
      
      const transformOrigin = `${transformOriginX}px ${transformOriginY}px`
      
      const ease = (progress, power = 1.8) => {
        return 1 - Math.pow(1 - progress, power)
      }
      
      const frameCount = 100
      const expandAnimation = `expand-${shortId}`
      
      let animation = `@keyframes ${expandAnimation} {\n`
      
      for (let i = 0; i <= frameCount; i++) {
        const step = (i / frameCount) * 100
        const easedStep = ease(i / frameCount)
        
        const xScale = startScale.x + (1 - startScale.x) * easedStep
        const yScale = startScale.y + (1 - startScale.y) * easedStep
        
        animation += `  ${step}% {\n    transform: scale(${xScale}, ${yScale});\n  }\n`
      }
      
      animation += '}\n'
      
      let styleSheet = document.querySelector('.expand-animations')
      
      styleSheet.textContent += animation
 
      element.style.transformOrigin = transformOrigin
      element.classList.add('expand-card')
      element.style.animationName = expandAnimation
      
      element.addEventListener('animationend', () => {
        element.classList.remove('expand-card')
        element.style.animationName = ''
        element.style.transform = ''
        element.style.transformOrigin = ''
      }, { once: true })
    }

    animateExpansion(element, animationData)
  }
}

export default AnimatedCardHooks
