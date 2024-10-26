defmodule Arcane.Repo.Migrations.SetUpStorage do
  use Ecto.Migration

  def up do
    execute("""
    create policy "Avatar images are publicly accessible."
      on storage.objects for select
      using ( bucket_id = 'avatars' );
    """)

    execute("""
    create policy "Anyone can upload an avatar."
      on storage.objects for insert
      with check ( bucket_id = 'avatars' );
    """)
  end

  def down do
    execute("""
    drop policy "Avatar images are publicly accessible." on storage.objects;
    """)

    execute("""
    drop policy "Anyone can upload an avatar." on storage.objects;
    """)
  end
end
