defmodule Supabase.Client.Auth do
  @moduledoc """
  Auth configuration schema. This schema is used to configure the auth
  options. This schema is embedded in the `Supabase.Client` schema.

  ## Fields

  - `:auto_refresh_token` - Automatically refresh the token when it expires. Defaults to `true`.
  - `:debug` - Enable debug mode. Defaults to `false`.
  - `:detect_session_in_url` - Detect session in URL. Defaults to `true`.
  - `:flow_type` - Authentication flow type. Defaults to `"implicit"`.
  - `:persist_session` - Persist session. Defaults to `true`.
  - `:storage` - Storage type.
  - `:storage_key` - Storage key. Default to `"sb-$host-auth-token"` where $host is the hostname of your Supabase URL.

  For more information about the auth options, see the documentation for
  the [client](https://supabase.com/docs/reference/javascript/initializing) and
  [auth guides](https://supabase.com/docs/guides/auth)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          auto_refresh_token: boolean(),
          debug: boolean(),
          detect_session_in_url: boolean(),
          flow_type: String.t(),
          persist_session: boolean(),
          storage_key: String.t()
        }

  @type params :: %{
          auto_refresh_token: boolean(),
          debug: boolean(),
          detect_session_in_url: boolean(),
          flow_type: String.t(),
          persist_session: boolean(),
          storage_key: String.t()
        }

  @flow_types ~w[implicit pkce magicLink]a

  @primary_key false
  embedded_schema do
    field(:auto_refresh_token, :boolean, default: true)
    field(:debug, :boolean, default: false)
    field(:detect_session_in_url, :boolean, default: true)
    field(:flow_type, Ecto.Enum, values: @flow_types, default: :implicit)
    field(:persist_session, :boolean, default: true)
    field(:storage_key, :string)
  end

  @fields ~w[auto_refresh_token debug detect_session_in_url persist_session flow_type storage_key]a

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> validate_required(@fields -- [:storage_key])
  end
end
