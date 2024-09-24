defmodule ArcaneWeb.SessionController do
  use ArcaneWeb, :controller

  import ArcaneWeb.Auth
  import Phoenix.LiveView.Controller

  alias ArcaneWeb.UserManagementLive
  alias Supabase.GoTrue

  require Logger

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
        message = "Check your email for the login link!"

        conn
        |> put_flash(:success, message)
        |> live_render(UserManagementLive)

      {:error, error} ->
        Logger.error("""
        [#{__MODULE__}] => Failed to login user:
        ERROR: #{inspect(error, pretty: true)}
        """)

        message = "Failed to send login link!"

        conn
        |> put_flash(:error, message)
        |> live_render(UserManagementLive)
    end
  end

  def confirm(conn, %{"token" => token, "type" => "magiclink"}) do
    {:ok, client} = Arcane.Supabase.Client.get_client()

    params = %{
      token_hash: token,
      type: :magiclink
    }

    case GoTrue.verify_otp(client, params) do
      {:ok, session} ->
        conn
        |> put_token_in_session(session.access_token)
        |> live_render(UserManagementLive,
          session: %{
            "user_token" => session.access_token,
            "live_socket_id" => get_session(conn, :live_socket_id)
          }
        )

      {:error, error} ->
        Logger.error("""
        [#{__MODULE__}] => Failed to verify OTP:
        ERROR: #{inspect(error, pretty: true)}
        """)

        message = "Failed to verify login link!"

        conn
        |> put_flash(:error, message)
        |> live_render(UserManagementLive)
    end
  end

  def signout(conn, _params) do
    message = "You have been signed out!"

    conn
    |> log_out_user(:local)
    |> put_flash(:info, message)
    |> live_render(UserManagementLive)
  end
end
