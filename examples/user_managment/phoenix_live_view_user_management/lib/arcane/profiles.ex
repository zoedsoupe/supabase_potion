defmodule Arcane.Profiles do
  alias Arcane.Profiles.Profile
  alias Arcane.Repo

  def get_profile(id: id) do
    Repo.get(Profile, id)
  end

  def upsert_profile(attrs) do
    changeset = Profile.changeset(%Profile{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: :id
    )
  end
end
