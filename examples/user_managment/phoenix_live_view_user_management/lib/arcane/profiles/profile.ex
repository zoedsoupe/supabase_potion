defmodule Arcane.Profiles.Profile do
  @moduledoc """
  Profiles are the main data structure for users.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          username: String.t() | nil,
          website: String.t() | nil,
          avatar_url: String.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "profiles" do
    field :username, :string
    field :website, :string
    field :avatar_url, :string

    timestamps()
  end

  def changeset(profile \\ %__MODULE__{}, %{} = params) do
    profile
    |> cast(params, [:id, :username, :website, :avatar_url])
    |> validate_required([:id])
    |> validate_length(:username, min: 3)
    |> validate_length(:website, max: 255)
    |> unique_constraint(:username)
    |> foreign_key_constraint(:id)
  end
end
