defmodule Supabase.Client.Behaviour do
  @moduledoc """
  The behaviour for the Supabase Client. This behaviour is used to define the API for a Supabase Client.

  If you're implementing a [Self Managed Client](https://github.com/zoedsoupe/supabase-ex?tab=readme-ov-file#self-managed-clients) as the [Supabase.Client](https://hexdocs.pm/supabase_potion/Supabase.Client.html), this behaviour is already implemented for you.

  If you're implementing a [One Off Client](https://github.com/zoedsoupe/supabase-ex?tab=readme-ov-file#one-off-clients) as the [Supabase.Client](https://hexdocs.pm/supabase_potion/Supabase.Client.html), you need to implement this behaviour in case you want to use the integration with [Supabase.GoTrue](https://hexdocs.pm/supabase_gotrue/readme.html) for [Plug](https://hexdocs.pm/plug) based application or [Phoenix.LiveView](https://hexdocs.pm/phoenix_live_view) applications.
  """

  alias Supabase.Client

  @callback init :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  @callback get_client :: {:ok, Client.t()} | {:error, :not_found}
  @callback get_client(pid | atom) :: {:ok, Client.t()} | {:error, :not_found}

  @optional_callbacks get_client: 0, get_client: 1
end
