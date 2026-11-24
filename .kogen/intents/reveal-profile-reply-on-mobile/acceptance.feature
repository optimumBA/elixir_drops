Feature: Reveal the selected public profile reply in the discussion
  This feature exercises the guest journey from a homepage contributor link through a keyboard switch from Drops to Comments, using the older-conversation fixture from the landed profile work. It checks rendered body visibility, not just presence in the DOM or a matching URL. The native 120-second acceptance limit stays unchanged; run configured setup before Cucumber.

  Scenario: Guest discussion navigation reveals the exact selected entry and Back returns to Comments
    Then reveal-profile-reply-on-mobile: at 390 by 844 and 1280 by 800 the connected discussion links reveal "RPL-0001 old reply" and "CMT-0002 old top-level comment", and full-document navigation to the selected reply href reveals "RPL-0001 old reply", with Back to Comments each time
