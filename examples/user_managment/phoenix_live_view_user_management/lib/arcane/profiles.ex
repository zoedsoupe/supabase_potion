defmodule Arcane.Profiles do
  import Ecto.Query

  alias Arcane.Profiles.Profile
  alias Arcane.Repo

  def get_profile(id: id) do
    Repo.get(Profile, id)
  end

  def create_profile(user_id: user_id) do
    changeset = Profile.changeset(%Profile{}, %{id: user_id})
    Repo.insert(changeset, on_conflict: :nothing, conflict_target: [:id])
  end

  def update_profile(%{"id" => profile_id} = attrs) do
    changeset = Profile.update_changeset(attrs)

    if changeset.valid? do
      updated_at = NaiveDateTime.utc_now()
      changes = [{:updated_at, updated_at} | Map.to_list(changeset.changes)]
      q = from p in Profile, where: p.id == ^profile_id, select: p

      case Repo.update_all(q, set: changes) do
        {1, [profile]} -> {:ok, profile}
        _ -> {:error, :failed_to_update_profile}
      end
    else
      {:error, changeset}
    end
  end
end
