defmodule ElixirDropsWeb.CustomInputComponents do
  @moduledoc """
  Provides custom core UI components.

  These are customised components from core_components module.
  """
  use Phoenix.Component

  alias ElixirDropsWeb.CoreComponents
  alias Phoenix.LiveView.JS

  @type assigns :: map()
  @type rendered :: Phoenix.LiveView.Rendered.t()

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.custom_input field={@form[:email]} type="email" />
      <.custom_input name="my-input" errors={["oh no!"]} />
  """
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :class, :any, default: nil, doc: "classes for input container"
  attr :errors, :list, default: []

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :id, :any, default: nil
  attr :input_field_class, :any, default: nil, doc: "classes for input field"
  attr :label, :string, default: nil
  attr :label_class, :string, default: nil, doc: "classes for input label"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :name, :any
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
                             range search select tel text textarea time url week)

  attr :value, :any

  slot :extra_content, required: false

  @spec custom_input(assigns()) :: rendered()
  def custom_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &CoreComponents.translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> custom_input()
  end

  def custom_input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={@class} phx-feedback-for={@id} phx-click={JS.focus(to: "##{@id}")}>
      <.custom_label for={@id} class={@label_class}>{@label}</.custom_label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "focus:ring-0 sm:text-sm sm:leading-6 resize-none overflow-hidden",
          @input_field_class
        ]}
        phx-hook="TextArea"
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      {render_slot(@extra_content)}
      <.custom_error :for={msg <- @errors}>{msg}</.custom_error>
    </div>
    """
  end

  def custom_input(assigns) do
    ~H"""
    <div class={@class} phx-feedback-for={@id} phx-click={JS.focus(to: "##{@id}")}>
      <.custom_label for={@id}>{@label}</.custom_label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "focus:ring-0 sm:text-sm sm:leading-6",
          @input_field_class
        ]}
        {@rest}
      />
      {render_slot(@extra_content)}
      <.custom_error :for={msg <- @errors}>{msg}</.custom_error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :class, :string, default: nil
  attr :for, :string, default: nil

  slot :inner_block, required: true

  @spec custom_label(assigns()) :: rendered()
  def custom_label(assigns) do
    ~H"""
    <label
      for={@for}
      class={[
        "block text-sm font-semibold leading-6 text-zinc-800",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  @spec custom_error(assigns()) :: rendered()
  def custom_error(assigns) do
    ~H"""
    <p class="mt-1 flex gap-3 text-sm leading-6 text-rose-600">
      {render_slot(@inner_block)}
    </p>
    """
  end
end
