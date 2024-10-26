defmodule Arcane.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, references(:users, prefix: "auth", type: :binary_id), primary_key: true
      add :username, :text
      add :avatar_url, :text
      add :website, :text

      # inserted_at and updated_at
      timestamps()
    end

    create unique_index(:profiles, :username)
    create constraint(:profiles, :username, check: "char_length(username) >= 3")
  end
end
