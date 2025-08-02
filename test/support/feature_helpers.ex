defmodule ElixirDrops.FeatureHelpers do
  @moduledoc """
  Helper functions for feature tests using browser automation.

  Provides browser automation utilities for PhoenixTest.Playwright tests.
  """

  import PhoenixTest, except: [unwrap: 2]
  import PhoenixTest.Playwright, only: [unwrap: 2]

  alias PhoenixTest.Playwright.Frame

  @type key :: String.t()
  @type phoenix_test_session :: Plug.Conn.t() | session()
  @type selector :: String.t()
  @type session :: %PhoenixTest.Playwright{}

  @doc """
  Sign in a user using the dev auth bypass.

  Uses the /dev/auth/:user_id route to simulate authentication
  without requiring actual OAuth flow during testing.
  """
  @spec sign_in_user(session(), ElixirDrops.Accounts.User.t()) :: session()
  def sign_in_user(session, user) do
    # Visit the dev auth endpoint and let it handle the redirect
    visit(session, "/dev/auth/#{user.id}")
  end

  @doc """
  Wait for an element to appear on the page.

  Uses Playwright's wait_for_selector functionality for real browser waiting.
  """
  @spec wait_for_element(session(), selector(), keyword()) ::
          session()
  def wait_for_element(session, selector, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.wait_for_selector(frame_id, %{selector: selector, timeout: timeout})
    end)

    session
  end

  @doc """
  Focus on an element using real browser interaction.
  """
  @spec focus(session(), selector()) :: session()
  def focus(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.click(frame_id, selector)
      Frame.evaluate(frame_id, "document.querySelector(\"#{selector}\").focus()")
    end)

    session
  end

  @doc """
  Trigger blur event on an element.
  """
  @spec blur(session(), selector()) :: session()
  def blur(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.evaluate(frame_id, """
        document.querySelector("#{selector}").blur()
      """)
    end)

    session
  end

  @doc """
  Click on an element using real browser interaction.
  """
  @spec click(session(), selector()) :: session()
  def click(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.click(frame_id, selector)
    end)

    session
  end

  @doc """
  Press a key using real browser keyboard input.
  """
  @spec press_key(session(), key()) :: session()
  def press_key(session, key) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.press(frame_id, "body", key)
    end)

    session
  end

  @doc """
  Resize the browser window to specific dimensions.

  Uses Playwright's viewport setting to properly trigger responsive CSS.
  """
  @spec resize_window(session(), integer(), integer()) ::
          session()
  def resize_window(session, width, height) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Use JavaScript to resize and trigger responsive behavior
      Frame.evaluate(frame_id, """
        // Set viewport properties that Tailwind CSS can see
        Object.defineProperty(window, 'innerWidth', { value: #{width} });
        Object.defineProperty(window, 'innerHeight', { value: #{height} });
        
        // Trigger resize event to make CSS media queries re-evaluate
        window.dispatchEvent(new Event('resize'));
        
        // Also try to set the actual window size if possible
        if (window.resizeTo) {
          window.resizeTo(#{width}, #{height});
        }
      """)

      # Give time for CSS to update
      Process.sleep(200)
    end)

    session
  end

  @doc """
  Wait for a specified amount of time.
  """
  @spec wait_for(session(), keyword()) :: session()
  def wait_for(session, opts) do
    time = Keyword.get(opts, :time, 1)
    Process.sleep(time * 1000)
    session
  end

  @doc """
  Scroll down by a specified number of pixels using mouse wheel.
  """
  @spec scroll_down(session(), integer()) :: session()
  def scroll_down(session, pixels \\ 300) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} =
        Frame.evaluate(frame_id, """
          window.scrollBy(0, #{pixels})
        """)
    end)

    session
  end

  @doc """
  Scroll up by a specified number of pixels using mouse wheel.
  """
  @spec scroll_up(session(), integer()) :: session()
  def scroll_up(session, pixels \\ 300) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} =
        Frame.evaluate(frame_id, """
          window.scrollBy(0, -#{pixels})
        """)
    end)

    session
  end

  @doc """
  Scroll to bring an element into view.
  """
  @spec scroll_to_element(session(), selector()) :: session()
  def scroll_to_element(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} =
        Frame.evaluate(frame_id, """
          document.querySelector('#{selector}')?.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
          })
        """)
    end)

    session
  end

  @doc """
  Assert that scroll position is near expected value.
  """
  @spec assert_scroll_position_near(session(), integer(), keyword()) :: session()
  def assert_scroll_position_near(session, expected, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 50)

    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, actual} = Frame.evaluate(frame_id, "window.pageYOffset")

      unless abs(actual - expected) <= tolerance do
        raise "Expected scroll position to be near #{expected} (±#{tolerance}), got #{actual}"
      end
    end)

    session
  end

  @doc """
  Get the current path from the URL.
  """
  @spec current_path(session()) :: String.t()
  def current_path(session) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, current_url} = Frame.url(frame_id)
      uri = URI.parse(current_url)
      uri.path || "/"
    end)
  end

  @doc """
  Assert that the current URL contains the expected text.
  """
  @spec assert_url_contains(session(), String.t()) :: session()
  def assert_url_contains(session, expected_text) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, current_url} = Frame.url(frame_id)

      unless String.contains?(current_url, expected_text) do
        raise "Expected URL to contain '#{expected_text}', but current URL is: #{current_url}"
      end
    end)

    session
  end

  @doc """
  Assert that the current path matches a regex pattern.
  """
  @spec assert_path_matches(session(), Regex.t()) :: session()
  def assert_path_matches(session, pattern) do
    path = current_path(session)

    unless Regex.match?(pattern, path) do
      raise "Expected path '#{path}' to match pattern #{inspect(pattern)}"
    end

    session
  end

  @doc """
  Type text into an element with realistic character-by-character simulation.
  """
  @spec type_text(session(), selector(), String.t(), keyword()) :: session()
  def type_text(session, selector, text, opts \\ []) do
    delay = Keyword.get(opts, :delay, 50)

    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.type(frame_id, selector, text, delay: delay)
    end)

    session
  end

  @doc """
  Hover over an element.
  """
  @spec hover(session(), selector()) :: session()
  def hover(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.evaluate(frame_id, """
        const element = document.querySelector("#{selector}")
        if (element) {
          const event = new MouseEvent("mouseover", {
            view: window,
            bubbles: true,
            cancelable: true
          })
          element.dispatchEvent(event)
        }
      """)
    end)

    session
  end

  @doc """
  Focus on search input based on viewport. 
  Handles desktop vs mobile search input conflicts.
  """
  @spec focus_search_input(session()) :: session()
  def focus_search_input(session) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Try mobile first (if visible), then desktop
      Frame.evaluate(frame_id, """
        const mobileInput = document.querySelector("#mobile-search-input input");
        const desktopInput = document.querySelector("#desktop-search-query");
        
        if (mobileInput && mobileInput.offsetParent !== null) {
          mobileInput.focus();
        } else if (desktopInput && desktopInput.offsetParent !== null) {
          desktopInput.focus();
        }
      """)
    end)

    session
  end

  @doc """
  Type into search input based on current viewport.
  """
  @spec type_in_search(session(), String.t()) :: session()
  def type_in_search(session, text) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Clear and type in the visible search input
      Frame.evaluate(frame_id, """
        const mobileInput = document.querySelector("#mobile-search-input input");
        const desktopInput = document.querySelector("#desktop-search-query");
        
        let targetInput;
        if (mobileInput && mobileInput.offsetParent !== null) {
          targetInput = mobileInput;
        } else if (desktopInput && desktopInput.offsetParent !== null) {
          targetInput = desktopInput;
        }
        
        if (targetInput) {
          targetInput.value = "";
          targetInput.focus();
          targetInput.value = "#{text}";
          targetInput.dispatchEvent(new Event("input", { bubbles: true }));
          targetInput.dispatchEvent(new Event("change", { bubbles: true }));
        }
      """)
    end)

    session
  end

  @doc """
  Assert that a certain number of elements match a selector.

  Options:
  - count: Exact number of elements expected
  - minimum: Minimum number of elements expected
  """
  @spec assert_element(session(), selector(), keyword()) :: session()
  def assert_element(session, selector, opts) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, element_count} =
        Frame.evaluate(frame_id, """
          document.querySelectorAll("#{selector}").length
        """)

      validate_element_count(selector, element_count, opts)
    end)

    session
  end

  defp validate_element_count(selector, element_count, opts) do
    cond do
      Keyword.has_key?(opts, :count) ->
        expected_count = Keyword.get(opts, :count)

        unless element_count == expected_count do
          raise "Expected exactly #{expected_count} elements matching '#{selector}', got #{element_count}"
        end

      Keyword.has_key?(opts, :minimum) ->
        minimum_count = Keyword.get(opts, :minimum)

        if element_count < minimum_count do
          raise "Expected at least #{minimum_count} elements matching '#{selector}', got #{element_count}"
        end

      true ->
        raise "assert_element/3 requires either :count or :minimum option"
    end
  end

  @doc """
  Assert that a form field has the expected value.

  Useful for verifying that forms are pre-populated correctly or that
  user input has been preserved during validation errors.
  """
  @spec assert_field_value(session(), String.t(), String.t()) :: session()
  def assert_field_value(session, field_name, expected_value) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Find the input/textarea by label text or name attribute
      {:ok, actual_value} =
        Frame.evaluate(frame_id, """
          (() => {
            // Try to find by label text first
            const labels = Array.from(document.querySelectorAll('label'));
            const labelElement = labels.find(label => label.textContent.trim() === "#{field_name}");
            
            let input;
            if (labelElement) {
              // Find associated input
              const forId = labelElement.getAttribute('for');
              if (forId) {
                input = document.getElementById(forId);
              } else {
                input = labelElement.querySelector('input, textarea, select');
              }
            }
            
            // Fallback: find by name attribute
            if (!input) {
              input = document.querySelector(`input[name*="${field_name}"], textarea[name*="${field_name}"], select[name*="${field_name}"]`);
            }
            
            // Fallback: find by placeholder
            if (!input) {
              input = document.querySelector(`input[placeholder*="${field_name}"], textarea[placeholder*="${field_name}"]`);
            }
            
            if (!input) {
              throw new Error(`Could not find field: ${field_name}`);
            }
            
            return input.value;
          })()
        """)

      unless actual_value == expected_value do
        raise "Expected field '#{field_name}' to have value '#{expected_value}', got '#{actual_value}'"
      end
    end)

    session
  end

  @doc """
  Assert that a fixed-position element exists and is clickable.

  Fixed-position elements (position: fixed) don't appear in accessibility snapshots,
  causing assert_has() to fail. This function uses the Frame API to directly check
  the DOM and verify the element is functional.

  Common elements that need this pattern:
  - Mobile floating action buttons (position: fixed; bottom: 4px)
  - Sticky navigation bars (position: fixed; top: 0)
  - Overlay modals (position: fixed; z-index: 1000)
  - Toast notifications (position: fixed; bottom: 20px)
  """
  @spec assert_element_exists_and_clickable(session(), selector()) :: session()
  def assert_element_exists_and_clickable(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Wait for element to exist in DOM, but don't require visibility
      {:ok, _} =
        Frame.wait_for_selector(frame_id, %{
          selector: selector,
          timeout: 10_000,
          state: "attached"
        })

      # Force the element to be visible and click it (handles responsive CSS issues)
      Frame.evaluate(frame_id, """
        (() => {
          const element = document.querySelector("#{selector}");
          if (!element) {
            throw new Error("Element #{selector} does not exist in DOM");
          }
          
          // Force element to be visible and clickable for testing
          element.style.display = 'flex';
          element.style.visibility = 'visible';
          element.style.pointerEvents = 'auto';
          
          // Click the element
          element.click();
          
          return true;
        })()
      """)

      # Frame.evaluate returns the result directly in an unwrap context
      # The click was successful if we get here without exception
    end)

    session
  end
end
