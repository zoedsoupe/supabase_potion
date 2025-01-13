defmodule Supabase.Client do
  @moduledoc """
  A client for interacting with Supabase. This module is responsible for
  managing the connection options for your Supabase project.

  ## Usage

  Generally, you can start a client by calling `Supabase.init_client/3`:

      iex> base_url = "https://<app-name>.supabase.io"
      iex> api_key = "<supabase-api-key>"
      iex> Supabase.init_client(base_url, api_key, %{})
      {:ok, %Supabase.Client{}}

  > That way of initialisation is useful when you want to manage the client state by yourself or create one off clients.

  However, starting a client directly means you have to manage the client state by yourself. To make it easier, you can use the `Supabase.Client` module to manage the connection options for you, which we call a "self managed client".

  To achieve this you can use the `Supabase.Client` module in your module:

      defmodule MyApp.Supabase.Client do
        use Supabase.Client, otp_app: :my_app
      end

  This will automatically start an [Agent](https://hexdocs.pm/elixir/Agent.html) process to manage the state for you. But for that to work, you need to configure your Supabase client options in your application configuration, either in compile-time (`config.exs`) or runtime (`runtime.exs`):

      # config/runtime.exs or config/config.exs

      config :my_app, MyApp.Supabase.Client,
        base_url: "https://<app-name>.supabase.co",
        api_key: "<supabase-api-key>",
        # any additional options
        access_token: "<supabase-access-token>",
        db: [schema: "another"],
        auth: [debug: true] # optional

  Another alternative would be to configure your Supabase Client in code, while starting your application:

      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            {MyApp.Supabase.Client, [
              base_url: "https://<app-name>.supabase.co",
              api_key: "<supabase-api-key>"
            ]}
          ]

          opts = [strategy: :one_for_one, name: MyApp.Supabase.Client.Supervisor]
          Supervisor.start_link(children, opts)
        end
      end

  For more information on how to configure your Supabase Client with additional options, please refer to the `Supabase.Client.t()` typespec.

  ## Examples

      %Supabase.Client{
        base_url: "https://<app-name>.supabase.io",
        api_key: "<supabase-api-key>",
        access_token: "<supabase-access-token>",
        db: %Supabase.Client.Db{
          schema: "public"
        },
        global: %Supabase.Client.Global{
          headers: %{}
        },
        auth: %Supabase.Client.Auth{
          auto_refresh_token: true,
          debug: false,
          detect_session_in_url: true,
          flow_type: :implicit,
          persist_session: true,
          storage_key: "sb-<host>-auth-token"
        }
      }
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Supabase.Client.Auth
  alias Supabase.Client.Db
  alias Supabase.Client.Global

  @typedoc """
  The type of the `Supabase.Client` that will be returned from `Supabase.init_client/3`.

  ## Source
  https://supabase.com/docs/reference/javascript/initializing
  """
  @type t :: %__MODULE__{
          base_url: String.t(),
          access_token: String.t(),
          api_key: String.t(),

          # helper fields
          realtime_url: String.t(),
          auth_url: String.t(),
          functions_url: String.t(),
          database_url: String.t(),
          storage_url: String.t(),

          # "public" options
          db: Db.t(),
          global: Global.t(),
          auth: Auth.t()
        }

  @typedoc """
  The type for the available additional options that can be passed
  to `Supabase.init_client/3` to configure the Supabase client.

  Note that these options can be passed to `Supabase.init_client/3` as `Enumerable`, which means it can be either a `Keyword.t()` or a `Map.t()`, but internally it will be passed as a map.
  """
  @type options :: %{
          optional(:db) => Db.params(),
          optional(:global) => Global.params(),
          optional(:auth) => Auth.params()
        }

  defmacro __using__(otp_app: otp_app) do
    module = __CALLER__.module

    quote do
      use Agent

      import Supabase.Client, only: [update_access_token: 2]

      alias Supabase.MissingSupabaseConfig

      @behaviour Supabase.Client.Behaviour

      @otp_app unquote(otp_app)

      @doc """
      Start an Agent process to manage the Supabase client instance.

      ## Usage

      First, define your client module and use the `Supabase.Client` module:

          defmodule MyApp.Supabase.Client do
            use Supabase.Client, otp_app: :my_app
          end

      Note that you need to configure it with your Supabase project details. You can do this by setting the `base_url` and `api_key` in your `config.exs` file:

          config :#{@otp_app}, #{inspect(unquote(module))},
            base_url: "https://<app-name>.supabase.co",
            api_key: "<supabase-api-key>",
            # additional options
            access_token: "<supabase-access-token>",
            db: [schema: "another"],
            auth: [debug: true]

      Then, on your `application.ex` file, you can start the agent process by adding your defined client into the Supervision tree of your project:

          def start(_type, _args) do
            children = [
              #{inspect(unquote(module))}
            ]

            Supervisor.init(children, strategy: :one_for_one)
          end

      For alternatives on how to start and define your Supabase client instance, please refer to the [Supabase.Client module documentation](https://hexdocs.pm/supabase_potion/Supabase.Client.html).

      For more information on how to start an Agent process, please refer to the [Agent module documentation](https://hexdocs.pm/elixir/Agent.html).
      """
      def start_link(opts \\ [])

      def start_link(opts) when is_list(opts) and opts == [] do
        config = Application.get_env(@otp_app, __MODULE__)

        if is_nil(config) do
          raise MissingSupabaseConfig, key: :config, client: __MODULE__, otp_app: @otp_app
        end

        base_url = Keyword.get(config, :base_url)
        api_key = Keyword.get(config, :api_key)
        name = Keyword.get(config, :name, __MODULE__)
        params = Map.new(config)

        if is_nil(base_url) do
          raise MissingSupabaseConfig, key: :url, client: __MODULE__, otp_app: @otp_app
        end

        if is_nil(api_key) do
          raise MissingSupabaseConfig, key: :key, client: __MODULE__, otp_app: @otp_app
        end

        Agent.start_link(fn -> Supabase.init_client!(base_url, api_key, params) end, name: name)
      end

      def start_link(opts) when is_list(opts) do
        base_url = Keyword.get(opts, :base_url)
        api_key = Keyword.get(opts, :api_key)

        if is_nil(base_url) do
          raise MissingSupabaseConfig, key: :url, client: __MODULE__, otp_app: @otp_app
        end

        if is_nil(api_key) do
          raise MissingSupabaseConfig, key: :key, client: __MODULE__, otp_app: @otp_app
        end

        name = Keyword.get(opts, :name, __MODULE__)
        params = Map.new(opts)

        Agent.start_link(
          fn ->
            Supabase.init_client!(base_url, api_key, params)
          end,
          name: name
        )
      end

      @doc """
      This function is an alias for `start_link/1` with no arguments.
      """
      @impl Supabase.Client.Behaviour
      def init, do: start_link([])

      @doc """
      Retrieve the client instance from the Agent process, so you can use it to interact with the Supabase API.
      """
      @impl Supabase.Client.Behaviour
      def get_client(pid \\ __MODULE__) do
        case Agent.get(pid, & &1) do
          nil -> {:error, :not_found}
          client -> {:ok, client}
        end
      end

      @doc """
      This function updates the `access_token` field of client
      that will then be used by the integrations as the `Authorization`
      header in requests, by default the `access_token` have the same
      value as the `api_key`.
      """
      @impl Supabase.Client.Behaviour
      def set_auth(pid \\ __MODULE__, token) when is_binary(token) do
        Agent.update(pid, &update_access_token(&1, token))
      end
    end
  end

  @primary_key false
  embedded_schema do
    field(:api_key, :string)
    field(:access_token, :string)
    field(:base_url, :string)

    field(:realtime_url, :string)
    field(:auth_url, :string)
    field(:storage_url, :string)
    field(:functions_url, :string)
    field(:database_url, :string)

    embeds_one(:db, Db, defaults_to_struct: true, on_replace: :update)
    embeds_one(:global, Global, defaults_to_struct: true, on_replace: :update)
    embeds_one(:auth, Auth, defaults_to_struct: true, on_replace: :update)
  end

  @spec changeset(attrs :: map) :: Ecto.Changeset.t()
  def changeset(%{base_url: base_url, api_key: api_key} = attrs) do
    %__MODULE__{}
    |> cast(attrs, [:api_key, :base_url, :access_token])
    |> put_change(:access_token, attrs[:access_token] || api_key)
    |> cast_embed(:db, required: false)
    |> cast_embed(:global, required: false)
    |> cast_embed(:auth, required: false)
    |> validate_required([:access_token, :base_url, :api_key])
    |> put_change(:auth_url, Path.join(base_url, "auth/v1"))
    |> put_change(:functions_url, Path.join(base_url, "functions/v1"))
    |> put_change(:database_url, Path.join(base_url, "rest/v1"))
    |> put_change(:storage_url, Path.join(base_url, "storage/v1"))
    |> put_change(:realtime_url, Path.join(base_url, "realtime/v1"))
  end

  @doc """
  Helper function to swap the current acccess token being used in
  the Supabase client instance.

  Note that this functions shoudln't be used directly if you are using a
  self managed client (aka started it into your supervision tree as the `Supabase.Client` moduledoc says), since it will return the updated client but it **won't**
  update the inner client in the `Agent` process.

  To update the access token for a self managed client, you can use the `set_auth/2` function that is generated when you configure your client module.

  If you're managing your own Supabase client state (aka one off clients) you can
  use this helper function.
  """
  @spec update_access_token(t, String.t()) :: t
  def update_access_token(%__MODULE__{} = client, access_token) do
    %{client | access_token: access_token}
  end

  defimpl Inspect, for: Supabase.Client do
    import Inspect.Algebra

    def inspect(%Supabase.Client{} = client, opts) do
      concat([
        "#Supabase.Client<",
        nest(
          concat([
            line(),
            "base_url: ",
            to_doc(client.base_url, opts),
            ",",
            line(),
            "schema: ",
            to_doc(client.db.schema, opts),
            ",",
            line(),
            "auth: (",
            "flow_type: ",
            to_doc(client.auth.flow_type, opts),
            ", ",
            "persist_session: ",
            to_doc(client.auth.persist_session, opts),
            ")"
          ]),
          2
        ),
        line(),
        ">"
      ])
    end
  end
end
