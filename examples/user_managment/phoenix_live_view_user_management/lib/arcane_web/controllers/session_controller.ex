defmodule ArcaneWeb.SessionController do
  use ArcaneWeb, :controller

  import ArcaneWeb.Auth
  import Phoenix.LiveView.Controller

  alias Arcane.Profiles
  alias ArcaneWeb.UserManagementLive
  alias Supabase.GoTrue

  require Logger

  @doc """
  THis function is responsible to process the log in request and send tbe
  magic link via Supabase/GoTrue

  Note that we do `live_render` since there's no state to mantain between
  controller and the live view itself (that will do authentication checks).
  """
  def create(conn, %{"email" => email}) do
    params = %{
      email: email,
      options: %{
        should_create_user: true,
        email_redirect_to: ~p"/session/confirm"
      }
    }

    {:ok, client} = Arcane.Supabase.Client.get_client()

    case GoTrue.sign_in_with_otp(client, params) do
      :ok ->
        live_render(conn, UserManagementLive)

      {:error, error} ->
        Logger.error("""
        [#{__MODULE__}] => Failed to login user:
        ERROR: #{inspect(error, pretty: true)}
        """)

        live_render(conn, UserManagementLive)
    end
  end

  @doc """
  Once the user clicks the email link that they'll receive, the link will redirect
  to the `/session/confirm` route defined on `ArcaneWeb.Router` and will trigger
  this function.

  So we create an empty Profile for this user, so the `UserManagementLive` can
  correctly show informations about the profile.

  Note also that we put the token into the session, as configured in the `ArcaneWeb.Endpoint`
  it will set up session cookies to store authentication information locally.

  Finally, we redirect back the user to the root page, that will redenr `UserManagementLive`
  live view. We could use `live_render`, but it would need to pass all the state and session
  mannually to the live view, which is unecessary here since it will happen automatically on
  `mount` of the live view.
  """
  def confirm(conn, %{"token_hash" => token_hash, "type" => "magiclink"}) do
    {:ok, client} = Arcane.Supabase.Client.get_client()

    params = %{
      token_hash: token_hash,
      type: :magiclink
    }

    with {:ok, session} <- GoTrue.verify_otp(client, params),
         {:ok, user} <- GoTrue.get_user(client, session) do
      Profiles.create_profile(user_id: user.id)

      conn
      |> put_token_in_session(session.access_token)
      |> redirect(to: ~p"/")
    else
      {:error, error} ->
        Logger.error("""
        [#{__MODULE__}] => Failed to verify OTP:
        ERROR: #{inspect(error, pretty: true)}
        """)

        redirect(conn, to: ~p"/")
    end
  end

  @doc """
  This function clears the local session, which includes the session cookie, so the user
  will need to authenticate again on the application.
  """
  def signout(conn, _params) do
    conn
    |> log_out_user(:local)
    |> live_render(UserManagementLive)
  end
end
