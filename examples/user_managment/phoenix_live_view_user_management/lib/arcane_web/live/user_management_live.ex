defmodule ArcaneWeb.UserManagementLive do
  use ArcaneWeb, :live_view

  import ArcaneWeb.Components

  alias Arcane.Profiles
  alias Phoenix.LiveView.AsyncResult
  alias Supabase.Storage
  alias Supabase.Storage.Bucket

  require Logger

  on_mount {ArcaneWeb.Auth, :mount_current_user}

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = current_user && Profiles.get_profile(id: current_user.id)

    # `assigns` on render expect that the
    # `@<assign>` is defined on `socket.assigns`
    # so we need to define it here if there isn't
    # any current user
    {:ok,
     socket
     |> assign(:page_title, "User Management")
     |> assign(:auth_form, to_form(%{"email" => nil}))
     |> assign(
       :account_form,
       to_form(%{
         "id" => profile && profile.id,
         "username" => profile && profile.username,
         "website" => profile && profile.website,
         "email" => current_user && current_user.email,
         "avatar" => nil
       })
     )
     |> assign(:profile, profile)
     |> assign_new(:avatar, fn -> nil end)
     |> assign(:avatar_blob, AsyncResult.loading())
     |> start_async(:download_avatar_blob, fn -> maybe_download_avatar(profile) end)}
  end

  def render(assigns) do
    ~H"""
    <div class="container" style="padding: 50px 0 100px 0">
      <.account :if={@current_user} form={@account_form} />
      <.auth :if={is_nil(@current_user)} form={@auth_form} />
    </div>
    """
  end

  def handle_event("update-profile", params, socket) do
    IO.inspect(params)

    case Profiles.upsert_profile(params) do
      {:ok, profile} ->
        Logger.info("""
        [#{__MODULE__}] => Profile updated: #{inspect(profile)}
        """)
        changeset = Profiles.Profile.changeset(profile, %{})

        {:noreply, assign(socket, :account_form, to_form(changeset))}

      {:error, changeset} ->
        Logger.error("""
        [#{__MODULE__}] => Error updating profile: #{inspect(changeset.errors)}
        """)

        {:noreply, put_flash(socket, :error, "Error updating profile")}
    end
  end

  def handle_event("upload-profile", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("avatar-blob-url", %{"url" => url}, socket) do
    {:noreply, assign(socket, avatar: url)}
  end

  def handle_event("signout", _params, socket) do
    {:noreply, assign(socket, :"trigger-signout", true)}
  end

  # fallback to avoid crashing the LiveView process
  # although this isn't a problem for Phoenix
  # as Elixir is fault tolerant, but it helps with observability
  def handle_event(event, params, socket) do
    Logger.info("""
    [#{__MODULE__}] => Unhandled event: #{event}
    PARAMS: #{inspect(params, pretty: true)}
    """)

    {:noreply, socket}
  end

  def handle_async(:download_avatar_blob, {:ok, nil}, socket) do
    avatar_blob = socket.assigns.avatar_blob
    ok = AsyncResult.ok(avatar_blob, nil)
    {:noreply, assign(socket, avatar_blob: ok)}
  end

  def handle_async(:download_avatar_blob, {:ok, blob}, socket) do
    avatar_blob = socket.assigns.avatar_blob

    {:noreply,
     socket
     |> assign(avatar_blob: AsyncResult.ok(avatar_blob, blob))
     |> push_event("consume-blob", %{blob: blob})}
  end

  def handle_async(:download_avatar_blob, {:error, error}, socket) do
    Logger.error("""
    [#{__MODULE__}] => Error downloading avatar blob: #{inspect(error)}
    """)

    avatar_blob = socket.assigns.avatar_blob
    failed = AsyncResult.failed(avatar_blob, {:error, error})
    {:noreply, assign(socket, avatar_blob: failed)}
  end

  defp maybe_download_avatar(nil), do: nil
  defp maybe_download_avatar(%Profiles.Profile{avatar_url: nil}), do: nil

  defp maybe_download_avatar(%Profiles.Profile{} = profile) do
    client = Arcane.Supabase.Client.get_client()
    bucket = %Bucket{name: "avatars"}

    Storage.download_object(client, bucket, profile.avatar_url)
  end
end
