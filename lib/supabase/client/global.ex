defmodule Supabase.Client.Global do
  @moduledoc """
  Global configuration schema. This schema is used to configure the global
  options. This schema is embedded in the `Supabase.Client` schema.

  ## Fields

  - `:headers` - The default headers to use in any Supabase request. Defaults to `%{}`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{headers: map}
  @type params :: %{headers: map}

  @primary_key false
  embedded_schema do
    field(:headers, {:map, :string}, default: %{})
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(schema, params) do
    schema
    |> cast(params, [:headers])
    |> validate_required([:headers])
  end
end
