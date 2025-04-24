let ScreenshotProgressHooks = {}

ScreenshotProgressHooks.ScreenshotProgress = {
  mounted() {
    const progressCircle = this.el.querySelector('#progress-circle')
    const percentageText = this.el.querySelector('#percentage')
    let animationInterval = null
    let animationStarted = false
    let currentProgress = 0

    if (!progressCircle || !percentageText) {
      console.error('Could not find required elements for progress circle')
      return
    }

    const radius = progressCircle.getAttribute('r')
    const circumference = 2 * Math.PI * radius

    progressCircle.style.strokeDasharray = circumference
    progressCircle.style.strokeDashoffset = circumference

    const setProgress = (percent) => {
      currentProgress = percent
      const offset = circumference - (percent / 100) * circumference
      progressCircle.style.strokeDashoffset = offset
      percentageText.textContent = `${Math.round(percent)}%`
    }

    setProgress(0)

    this.handleEvent('screenshot_generation_started', () => {
      setProgress(0)
      animationStarted = true

      const totalTime = 5000
      const startTime = Date.now()

      animationInterval = setInterval(() => {
        const elapsedTime = Date.now() - startTime

        let progressPercent = Math.min(60, (elapsedTime / totalTime) * 60)

        setProgress(progressPercent)

        if (elapsedTime >= totalTime) {
          clearInterval(animationInterval)
          animationInterval = null
        }
      }, 50)
    })

    this.handleEvent(
      'screenshot_progress_update',
      ({ drop_short_id, progress, status, url }) => {
        if (status === 'pending' && progress === 60) {
          if (animationInterval) {
            clearInterval(animationInterval)
            animationInterval = null
          }
          if (currentProgress < 60) {
            setProgress(60)
          }
        } else if (status === 'completed') {
          if (animationInterval) {
            clearInterval(animationInterval)
            animationInterval = null
          }

          setProgress(100)

          setTimeout(() => {
            this.pushEvent('progress_animation_complete', {
              progress,
              drop_short_id,
              status,
              url,
            })
          }, 1000)
        } else {
          setProgress(progress)
        }
      }
    )
  },
}

export default ScreenshotProgressHooks
