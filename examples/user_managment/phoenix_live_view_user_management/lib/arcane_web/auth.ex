defmodule ArcaneWeb.Auth do
  use Supabase.GoTrue.LiveView,
    endpoint: ArcaneWeb.Endpoint,
    client: Arcane.Supabase.Client,
    signed_in_path: "/",
    not_authenticated_path: "/"

  # LiveView cannot write cookies
  # or set session, so we need to use Plug
  # to handle the session and cookies
  # check ArcaneWeb.SessionController
  use Supabase.GoTrue.Plug,
    endpoint: ArcaneWeb.Endpoint,
    client: Arcane.Supabase.Client,
    signed_in_path: "/",
    not_authenticated_path: "/"
end
