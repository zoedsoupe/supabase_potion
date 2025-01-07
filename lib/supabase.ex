defmodule Supabase do
  @moduledoc """
  The main entrypoint for the Supabase SDK library.

  ## Starting a Client

  You then can start a Client calling `Supabase.init_client/3`:

      iex> Supabase.init_client("base_url", "api_key", %{db: %{schema: "public"}})
      {:ok, %Supabase.Client{}}

  ## Acknowledgements

  This package represents the base SDK for Supabase. That means
  that it not includes all of the functionality of the Supabase client integrations, so you need to install each feature separetely, as:

  - [Supabase.GoTrue](https://hexdocs.pm/supabase_gotrue)
  - [Supabase.Storage](https://hexdocs.pm/supabase_storage)
  - [Supabase.PostgREST](https://hexdocs.pm/supabase_postgrest)
  - `Realtime` - TODO
  - `UI` - TODO

  ### Supabase Storage

  Supabase Storage is a service for developers to store large objects like images, videos, and other files. It is a hosted object storage service, like AWS S3, but with a simple API and strong consistency.

  ### Supabase PostgREST

  PostgREST is a web server that turns your PostgreSQL database directly into a RESTful API. The structural constraints and permissions in the database determine the API endpoints and operations.

  ### Supabase Realtime

  Supabase Realtime provides a realtime websocket API powered by PostgreSQL notifications. It allows you to listen to changes in your database, and instantly receive updates as soon as they happen.

  ### Supabase Auth/GoTrue

  Supabase Auth is a feature-complete user authentication system. It provides email & password sign in, email verification, password recovery, session management, and more, out of the box.

  ### Supabase UI

  Supabase UI is a set of UI components that help you quickly build Supabase-powered applications. It is built on top of Tailwind CSS and Headless UI, and is fully customizable. The package provides `Phoenix.LiveView` components!
  """

  alias Supabase.Client

  alias Supabase.MissingSupabaseConfig

  @typedoc "Helper typespec to define general success and error returns"
  @type result(a) :: {:ok, a} | {:error, Supabase.Error.t()}

  @typedoc "The available Supabase services to interact with"
  @type service :: :database | :storage | :auth | :functions | :realtime
  @typep changeset :: Ecto.Changeset.t()

  @doc """
  Creates a new one off Supabase client, you you wanna a self managed client, that
  levarages an [Agent][https://hexdocs.pm/elixir/Agent.html] instance that can
  started in your application supervision tree, check the `Supabase.Client` module docs.

  ## Parameters
  - `base_url`: The unique Supabase URL which is supplied when you create a new project in your project dashboard.
  - `api_key`: The unique Supabase Key which is supplied when you create a new project in your project dashboard.
  - `options`: Additional options to configure the client behaviour, check `Supabase.Client.options()` typespec to check all available options.

  ## Examples
      iex> Supabase.init_client("https://<supabase-url>", "<supabase-api-key>")
      iex> {:ok, %Supabase.Client{}}

      iex> Supabase.init_client("https://<supabase-url>", "<supabase-api-key>",
        db: [schema: "another"],
        auth: [flow_type: :pkce],
        global: [headers: %{"custom-header" => "custom-value"}]
      )
      iex> {:ok, %Supabase.Client{}}
  """
  @spec init_client(supabase_url, supabase_key, options) ::
          {:ok, Client.t()} | {:error, changeset}
        when supabase_url: String.t(),
             supabase_key: String.t(),
             options: Enumerable.t()
  def init_client(url, api_key, opts \\ %{})
      when is_binary(url) and is_binary(api_key) do
    opts
    |> Map.new()
    |> Map.put(:base_url, url)
    |> Map.put(:api_key, api_key)
    |> then(&Client.changeset(%Client{}, &1))
    |> Ecto.Changeset.apply_action(:parse)
    |> then(&maybe_put_storage_key/1)
    |> then(&put_default_headers/1)
  end

  defp maybe_put_storage_key({:ok, %Client{base_url: base_url} = client}) do
    maybe_default = &(Function.identity(&1) || default_storage_key(base_url))
    {:ok, update_in(client.auth.storage_key, maybe_default)}
  end

  defp maybe_put_storage_key(other), do: other

  defp default_storage_key(base_url) when is_binary(base_url) do
    base_url
    |> URI.parse()
    |> then(&String.split(&1.host, ".", trim: true))
    |> List.first()
    |> then(&"sb-#{&1}-auth-token")
  end

  defp put_default_headers({:ok, %Client{global: g} = client}) do
    headers = Supabase.Fetcher.merge_headers(g.headers, default_headers())
    {:ok, put_in(client.global.headers, Map.new(headers))}
  end

  defp put_default_headers(other), do: other

  defp default_headers do
    %{
      "x-client-info" => "supabase-fetch-elixir/#{version()}",
      "user-agent" => "SupabasePotion/#{version()}"
    }
  end

  @spec version :: String.t()
  defp version do
    {:ok, vsn} = :application.get_key(:supabase_potion, :vsn)
    List.to_string(vsn)
  end

  @doc """
  Same as `Supabase.init_client/3` but raises if any errors occurs while
  parsing the client options.
  """
  @spec init_client!(supabase_url, supabase_key, options) :: Client.t()
        when supabase_url: String.t(),
             supabase_key: String.t(),
             options: Enumerable.t()
  def init_client!(url, api_key, opts \\ %{})
      when is_binary(url) and is_binary(api_key) do
    case init_client(url, api_key, opts) do
      {:ok, client} ->
        client

      {:error, changeset} ->
        errors = errors_on_changeset(changeset)

        if "can't be blank" in (errors[:api_key] || []) do
          raise MissingSupabaseConfig, key: :key, client: nil
        end

        if "can't be blank" in (errors[:base_url] || []) do
          raise MissingSupabaseConfig, key: :url, client: nil
        end

        raise Ecto.InvalidChangesetError, changeset: changeset, action: :init
    end
  end

  defp errors_on_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
