defmodule ArcaneWeb.Components do
  @moduledoc """
  This module define function components.
  """

  use ArcaneWeb, :verified_routes
  use Phoenix.Component

  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :size, :integer

  def avatar(%{size: size} = assigns) do
    size_str = "height: #{size}em; width: #{size}em;"
    assigns = assign(assigns, size: size_str)

    ~H"""
    <div>
      <.live_img_preview
        :for={entry <- @upload.entries}
        entry={entry}
        alt="Avatar"
        class="avatar-image"
        style={@size}
      />
      <div :if={@upload.entries == []} class="avatar no-image" style={@size} />

      <div style="width: 10em; position: relative; decoration: none;">
        <label class="button primary block" for={@upload.ref}>
          Upload
        </label>
        <.live_file_input
          upload={@upload}
          id="single"
          style="position: absolute; visibility: hidden;"
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

  @doc """
  We actually need 2 different forms as the first one will keep track of
  the profile update data and emit LiveView events and the second one will submit an HTTP request
  `DELETE /session` to log out the current user (aka delete session cookies)
  """
  def account(assigns) do
    ~H"""
    <.form for={@form} class="form-widget" phx-submit="update-profile" phx-change="upload-profile">
      <input type="text" hidden name={@form[:id].name} id={@form[:id].id} value={@form[:id].value} />
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
    </.form>
    <.form for={%{}} action={~p"/session"} method="delete">
      <div>
        <button type="submit" class="button block">
          Sign Out
        </button>
      </div>
    </.form>
    """
  end
end
