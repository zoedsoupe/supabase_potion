# Supabase Potion

Where the magic starts!

> [!WARNING]
> This project is still in high development, expect breaking changes and unexpected behaviour.

## Getting Started

### Examples

This repository contains a few examples with sample apps to help you get started and showcase each usage of the client implementations:

#### Gotrue/Auth examples

TODO

<!--
- [Plug based auth](https://github.com/zoedsoupe/supabase-ex/tree/main/examples/auth/plug)
- [Phoenix LiveView based auth](https://github.com/zoedsoupe/supabase-ex/tree/main/examples/auth/phoenix_live_view)
- [User management](https://github.com/zoedsoupe/supabase-ex/tree/main/examples/auth/user_management)
-->

#### Storage examples

TODO

<!--
- [Plug based upload](https://github.com/zoedsoupe/supabase-ex/tree/main/examples/storage/plug)
- [Phoenix LiveView upload](https://github.com/zoedsoupe/supabase-ex/tree/main/examples/storage/phoenix_live_view)
-->

### Installation

To install the base SDK:

```elixir
def deps do
  [
    {:supabase_potion, "~> 0.5"}
  ]
end
```

### General usage

This library per si is the base foundation to user Supabase services from Elixir, so to integrate with specific services you need to add each client library you want to use.

Available client services are:
- [PostgREST](https://github.com/zoedsoupe/postgres-ex)
- [Storage](https://github.com/zoedsoupe/storage-ex)
- [Auth/GoTrue](https://github.com/zoedsoupe/gotrue-ex)

So if you wanna use the Storage and Auth/GoTrue services, your `mix.exs` should look like that:

```elixir
def deps do
  [
    {:supabase_potion, "~> 0.5"}, # base SDK
    {:supabase_storage, "~> 0.3"}, # storage integration
    {:supabase_gotrue, "~> 0.3"}, # auth integration
    {:supabase_postgrest, "~> 0.2"}, # postgrest integration
  ]
end
```

### Clients

A `Supabase.Client` holds general information about Supabase, that can be used to intereact with any of the children integrations, for example: `Supabase.Storage` or `Supabase.UI`.

`Supabase.Client` is defined as:

- `:conn` - connection information, the only required option as it is vital to the `Supabase.Client`.
    - `:base_url` - The base url of the Supabase API, it is usually in the form `https://<app-name>.supabase.io`.
    - `:api_key` - The API key used to authenticate requests to the Supabase API.
    - `:access_token` - Token with specific permissions to access the Supabase API, it is usually the same as the API key.
- `:db` - default database options
    - `:schema` - default schema to use, defaults to `"public"`
- `:global` - global options config
    - `:headers` - additional headers to use on each request
- `:auth` - authentication options
    - `:auto_refresh_token` - automatically refresh the token when it expires, defaults to `true`
    - `:debug` - enable debug mode, defaults to `false`
    - `:detect_session_in_url` - detect session in URL, defaults to `true`
    - `:flow_type` - authentication flow type, defaults to `"web"`
    - `:persist_session` - persist session, defaults to `true`
    - `:storage` - storage type
    - `:storage_key` - storage key

### Usage

There are two ways to create a `Supabase.Client`:
1. one off clients
2. self managed clients

#### One off clients

One off clients are clients that are created and managed by your application. They are useful for quick interactions with the Supabase API.

```elixir
iex> Supabase.init_client("https://<supabase-url>", "<supabase-api-key>")
iex> {:ok, %Supabase.Client{}}
```

Any additional config can be passed as the third argument:

```elixir
iex> Supabase.init_client("https://<supabase-url>", "<supabase-api-key>", %{db: %{schema: "another"}}})
iex> {:ok, %Supabase.Client{}}
```

For more information on the available options, see the [Supabase.Client](https://hexdocs.pm/supabase_potion/Supabase.Client.html) module documentation.

> There's also a bang version of `Supabase.init_client/3` that will raise an error if the client can't be created.

You can also define a module that will centralize the client initialization:

```elixir
defmodule MyApp.Supabase.Client do
  @behaviour Supabase.Client.Behaviour

  @impl true
  def init do
    # your client initialization
    # you should return {:ok, client} or {:error, reason}
    # you probably want to use `Supabase.init_client/3` here
    # but get the base_url and api_key from anywhere you want
  end

  @impl true
  def get_client do
    # your client retrieval
    # you should return the client
    # the management of the client state is up to you
  end
end
```

For self managed clients, check the [next section](#self-managed-clients).

#### Self managed clients

Self managed clients are clients that are created and managed by a separate process on your application. They are useful for long running applications that need to interact with the Supabase API.

If you don't have experience with processes or is a Elixir begginner, you should take a deep look into the Elixir official getting started section about processes, concurrency and distribution before to proceed.
- [Processes](https://hexdocs.pm/elixir/processes.html)
- [Agent getting started](https://hexdocs.pm/elixir/agents.html)
- [GenServer getting started](https://hexdocs.pm/elixir/genservers.html)
- [Supervison trees getting started](https://hexdocs.pm/elixir/supervisor-and-application.html)

So, to define a self managed client, you need to define a module that will hold the client state and the client process.

```elixir
defmodule MyApp.Supabase.Client do
  use Supabase.Client, otp_app: :my_app
end
```

For that to work, you also need to configure the client in your `config.exs`:

```elixir
import Config

config :my_app, MyApp.Supabase.Client,
  base_url: "https://<supabase-url>", # required
  api_key: "<supabase-api-key>", # required
  conn: %{access_token: "<supabase-token>"}, # optional
  db: %{schema: "another"} # additional options
```

Then, you can start the client process in your application supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Supabase.Client
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Now you can interact with the client process:

```elixir
iex> {:ok, %Supabase.Client{} = client} = MyApp.Supabase.Client.get_client()
iex> Supabase.GoTrue.sign_in_with_password(client, email: "", password: "")
```

For more examples on how to use the client, check clients implementations docs:
- [Supabase.GoTrue](https://hexdocs.pm/supabase_gotrue)
- [Supabase.Storage](https://hexdocs.pm/supabase_storage)
- [Supabase.PostgREST](https://hexdocs.pm/supabase_postgrest)

### How to find my Supabase base URL?

You can find your Supabase base URL in the Settings page of your project.
Firstly select your project from the initial Dashboard.
On the left sidebar, click on the Settings icon, then select API.
The base URL is the first field on the page.

### How to find my Supabase API Key?

You can find your Supabase API key in the Settings page of your project.
Firstly select your project from the initial Dashboard.
On the left sidebar, click on the Settings icon, then select API.
The API key is the second field on the page.

There two types of API keys, the public and the private. The last one
bypass any Row Level Security (RLS) rules you have set up.
So you shouldn't use it in your frontend application.

If you don't know what RLS is, you can read more about it here:
https://supabase.com/docs/guides/auth/row-level-security

For most cases you should prefer to use the public "anon" Key.
