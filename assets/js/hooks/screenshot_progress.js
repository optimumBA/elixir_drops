let ScreenshotProgressHooks = {}

ScreenshotProgressHooks.ScreenshotProgress = {
  mounted() {
    console.log('Screenshot Progress Hook Mounted')

    // Find elements within this hook element
    const progressCircle = this.el.querySelector('#progress-circle')
    const percentageText = this.el.querySelector('#percentage')

    if (!progressCircle || !percentageText) {
      console.error('Could not find required elements for progress circle')
      return
    }

    // Calculate the circumference of the circle
    const radius = progressCircle.getAttribute('r')
    const circumference = 2 * Math.PI * radius

    // Set the initial state of the circle
    progressCircle.style.strokeDasharray = circumference
    progressCircle.style.strokeDashoffset = circumference

    // Function to update progress
    const setProgress = (percent) => {
      const offset = circumference - (percent / 100) * circumference
      progressCircle.style.strokeDashoffset = offset
      percentageText.textContent = `${Math.round(percent)}%`
    }

    // Initialize with 0%
    setProgress(0)

    // Listen for the screenshot_generation_started event
    this.handleEvent('screenshot_generation_started', () => {
      // Reset progress
      setProgress(0)

      const totalTime = 5000 // 5 seconds
      const startTime = Date.now()

      // Function to check for random completion
      const randomCheck = () => {
        // 1% chance each check to complete to 50%
        return Math.random() < 0.01
      }

      // Update progress based on time
      const updateInterval = setInterval(() => {
        const elapsedTime = Date.now() - startTime

        // Calculate progress percentage (only up to 50%)
        let progressPercent = Math.min(99, (elapsedTime / totalTime) * 99)

        // Check for random completion
        if (randomCheck() && progressPercent < 99) {
          progressPercent = 99
          clearInterval(updateInterval)
        }

        // Update the progress circle
        setProgress(progressPercent)

        // Check if time is up
        if (elapsedTime >= totalTime) {
          clearInterval(updateInterval)
        }
      }, 50) // Update every 50ms for smooth animation
    })

    // Listen for screenshot progress updates
    this.handleEvent(
      'screenshot_progress_update',
      ({ progress, status, url }) => {
        // When we receive the completed status
        // Note: status can be "completed" (string) or :completed (atom serialized as "completed")
        if (status === 'completed') {
          // First, show 100% before transitioning to the screenshot
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
          // Force progress to 100% regardless of the progress value sent
          setProgress(100)

          // Add a delay before the parent component shows the screenshot
          // This ensures the progress animation has time to complete
          //TODO: Trying to send the event to the LiveView to trigger UI changes but it's not working
          // setTimeout(() => {
          //   // Dispatch an event that the LiveView can listen for to trigger UI changes
          //   this.pushEvent('progress_animation_complete', {})
          // }, 1000) // Wait 1 second for the animation to complete
        } else if (progress) {
          // Update progress based on server value
          setProgress(progress)
        }
      }
    )
  },
}

export default ScreenshotProgressHooks
