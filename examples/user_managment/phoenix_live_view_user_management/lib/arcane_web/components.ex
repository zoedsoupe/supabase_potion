defmodule ArcaneWeb.Components do
  @moduledoc """
  This module define function components.
  """

  use ArcaneWeb, :verified_routes
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :field, Phoenix.HTML.FormField
  attr :src, :string
  attr :size, :integer
  attr :uploading?, :boolean, default: false

  def avatar(%{size: size} = assigns) do
    assigns =
      assigns
      |> Map.put(:height, "#{size}em")
      |> Map.put(:width, "#{size}em")

    ~H"""
    <div>
      <img
        :if={@src}
        id="avatar-preview"
        phx-hook="LivePreview"
        src={@src}
        alt="Avatar"
        class="avatar-image"
        style={[height: @height, width: @width]}
      />
      <div :if={is_nil(@src)} class="avatar no-image" style={[height: @height, width: @width]} />

      <div style="width: 10em; position: relative;">
        <label class="button primary block" for="single">
          <%= if @uploading?, do: "Uploading...", else: "Upload" %>
        </label>
        <input
          style="position: absolute; visibility: hidden;"
          type="file"
          id="single"
          accept="image/*"
          name={@field.name}
          id={@field.id}
          value={@field.value}
          disabled={@uploading?}
        />
      </div>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true

  def auth(assigns) do
    ~H"""
    <.form for={@form} action={~p"/session"} class="row flex flex-center">
      <div class="col-6 form-widget">
        <h1 class="header">Supabase + Phoenix LiveView</h1>
        <p class="description">Sign in via magic link with your email below</p>
        <div>
          <input
            class="inputField"
            type="email"
            placeholder="Your email"
            name={@form[:email].name}
            id={@form[:email].id}
            value={@form[:email].value}
          />
        </div>
        <div>
          <button type="submit" class="button block" phx-disable-with="Loading...">
            Send magic link
          </button>
        </div>
      </div>
    </.form>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :avatar, :string
  attr :"trigger-signout", :boolean, default: false

  def account(assigns) do
    ~H"""
    <.form
      for={@form}
      class="form-widget"
      phx-submit="update-profile"
      phx-change="upload-profile"
      action={~p"/session"}
      phx-trigger-action={Map.get(assigns, :"trigger-signout", false)}
      method="delete"
    >
      <!-- <.avatar src={@avatar} field={@form[:avatar]} size={10} /> -->
      <input type="text"
      hidden
      name={@form[:id].name}
      id={@form[:id].id}
      value={@form[:id].value}
      />
      <div>
        <label for="email">Email</label>
        <input
          type="text"
          name={@form[:email].name}
          id={@form[:email].id}
          value={@form[:email].value}
          disabled
        />
      </div>
      <div>
        <label for="username">Name</label>
        <input
          type="text"
          name={@form[:username].name}
          id={@form[:username].id}
          value={@form[:username].value}
        />
      </div>
      <div>
        <label for="website">Website</label>
        <input
          type="url"
          name={@form[:website].name}
          id={@form[:website].id}
          value={@form[:website].value}
        />
      </div>

      <div>
        <button type="submit" class="button block primary" phx-disable-with="Loading...">
          Update
        </button>
      </div>

      <div>
        <button type="button" class="button block" phx-click="sign-out">
          Sign Out
        </button>
      </div>
    </.form>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "flash-container",
        @kind == :info && "flash-info",
        @kind == :error && "flash-error"
      ]}
      {@rest}
    >
      <p :if={@title} class="flash-title">
        <%= @title %>
      </p>
      <p class="flash-message"><%= msg %></p>
      <button type="button" class="flash-close-button">
        X
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="flash-group-container">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet!"
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        class="hidden"
      >
        Attempting to reconnect...
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        class="hidden"
      >
        Hang in there while we get back on track
      </.flash>
    </div>
    """
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
