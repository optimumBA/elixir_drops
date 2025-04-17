let ScreenshotProgressHooks = {}

ScreenshotProgressHooks.ScreenshotProgress = {
  mounted() {
    const progressCircle = this.el.querySelector('#progress-circle')
    const percentageText = this.el.querySelector('#percentage')

    if (!progressCircle || !percentageText) {
      console.error('Could not find required elements for progress circle')
      return
    }

    const radius = progressCircle.getAttribute('r')
    const circumference = 2 * Math.PI * radius

    progressCircle.style.strokeDasharray = circumference
    progressCircle.style.strokeDashoffset = circumference

    const setProgress = (percent) => {
      const offset = circumference - (percent / 100) * circumference
      progressCircle.style.strokeDashoffset = offset
      percentageText.textContent = `${Math.round(percent)}%`
    }

    setProgress(0)

    this.handleEvent('screenshot_generation_started', () => {
      setProgress(0)

      const totalTime = 5000
      const startTime = Date.now()

      const randomCheck = () => {
        return Math.random() < 0.01
      }

      const updateInterval = setInterval(() => {
        const elapsedTime = Date.now() - startTime

        let progressPercent = Math.min(99, (elapsedTime / totalTime) * 99)

        if (randomCheck() && progressPercent < 99) {
          progressPercent = 99
          clearInterval(updateInterval)
        }

        setProgress(progressPercent)

        if (elapsedTime >= totalTime) {
          clearInterval(updateInterval)
        }
      }, 50)
    })

    this.handleEvent(
      'screenshot_progress_update',
      ({ progress, status, url }) => {
        if (status === 'completed') {
          progressCircle.classList.add(
            'transition-all',
            'duration-500',
            'ease-out'
          )
          percentageText.classList.add(
            'transition-all',
            'duration-500',
            'ease-out'
          )
          setProgress(100)

          //TODO: Trying to send the event to the LiveView to trigger UI changes but it's not working
          // setTimeout(() => {
          //   // Dispatch an event that the LiveView can listen for to trigger UI changes
          //   this.pushEvent('progress_animation_complete', {})
          // }, 1000) // Wait 1 second for the animation to complete
        } else if (progress) {
          setProgress(progress)
        }
      }
    )
  },
}

export default ScreenshotProgressHooks
