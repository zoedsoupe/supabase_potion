defmodule ArcaneWeb.UserManagementLive do
  use ArcaneWeb, :live_view

  import ArcaneWeb.Components

  alias Arcane.Profiles
  alias Phoenix.LiveView.AsyncResult
  alias Supabase.Storage
  alias Supabase.Storage.Bucket

  require Logger

  on_mount {ArcaneWeb.Auth, :mount_current_user}

  @bucket_name "avatars"

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = current_user && Profiles.get_profile(id: current_user.id)
    account_form = make_account_form(profile, current_user)

    # `assigns` on render expect that the
    # `@<assign>` is defined on `socket.assigns`
    # so we need to define it here if there isn't
    # any current user
    {:ok,
     socket
     |> assign(:page_title, "User Management")
     |> assign(:auth_form, to_form(%{"email" => nil}))
     |> assign(:account_form, account_form)
     |> assign(:profile, profile)
     |> allow_upload(:avatar,
       auto_upload: true,
       accept: ["image/*"],
       progress: &handle_progress/3
     )
     |> assign(:avatar_blob, AsyncResult.loading())
     |> start_async(:download_avatar_blob, fn -> maybe_download_avatar(profile) end)}
  end

  def render(assigns) do
    ~H"""
    <div class="container" style="padding: 50px 0 100px 0">
      <.avatar :if={@current_user} upload={@uploads.avatar} size={10} />
      <.account :if={@current_user} form={@account_form} />
      <.auth :if={is_nil(@current_user)} form={@auth_form} />
    </div>
    """
  end

  def handle_event("update-profile", params, socket) do
    current_user = socket.assigns.current_user
    params = Map.merge(params, %{"id" => current_user.id})

    case Profiles.update_profile(params) do
      {:ok, profile} ->
        Logger.info("""
        [#{__MODULE__}] => Profile updated: #{inspect(profile)}
        """)

        account_form = make_account_form(profile, current_user)
        {:noreply, assign(socket, :account_form, account_form)}

      {:error, error} ->
        Logger.error("""
        [#{__MODULE__}] => Error updating profile: #{inspect(error)}
        """)

        {:noreply, put_flash(socket, :error, "Error updating profile")}
    end
  end

  def handle_event("avatar-blob-url", %{"url" => url}, socket) do
    {:noreply, assign(socket, avatar: url)}
  end

  def handle_event("sign-out", _params, socket) do
    ArcaneWeb.Auth.log_out_user(socket, :local)
    {:noreply, socket}
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
    {:ok, client} = Arcane.Supabase.Client.get_client()
    bucket = %Bucket{name: @bucket_name}

    Storage.download_object(client, bucket, profile.avatar_url)
  end

  defp make_account_form(profile, current_user) do
    to_form(%{
      "id" => profile && profile.id,
      "username" => profile && profile.username,
      "website" => profile && profile.website,
      "email" => current_user && current_user.email,
      "avatar" => nil
    })
  end

  defp handle_progress(:avatar, entry, socket) when entry.done? do
    current_user = socket.assigns.current_user
    profile = socket.assigns.profile
    params = %{profile: profile, user: current_user}
    consume_uploaded_entry(socket, entry, &handle_avatar_upload(&1, params))

    {:noreply, socket}
  end

  defp handle_progress(:avatar, entry, socket) do
    Logger.info("[#{__MODULE__}] => Avatar with #{entry.progress} progress")
    {:noreply, socket}
  end

  defp handle_avatar_upload(%{path: path}, %{user: current_user, profile: profile}) do
    bucket = %Bucket{name: @bucket_name}
    basename = Path.basename(path)
    remote_path = Path.join([bucket.name, current_user.id, basename])
    expires = :timer.hours(24) * 365

    with {:ok, client} = Arcane.Supabase.Client.get_client(),
         {:ok, obj} <- Supabase.Storage.upload_object(client, bucket, remote_path, path),
         {:ok, url} <- Supabase.Storage.create_signed_url(client, bucket, remote_path, expires),
         {:ok, _} <- Profiles.update_profile(%{id: profile.id, avatar_url: url}) do
      {:ok, obj.path}
    else
      err ->
        Logger.error("[#{__MODULE__}] => Failed to upload avatar with #{inspect(err)}")
        err
    end
  end
end
