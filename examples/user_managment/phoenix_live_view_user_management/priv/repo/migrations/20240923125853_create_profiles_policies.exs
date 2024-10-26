defmodule Arcane.Repo.Migrations.CreateProfilesPolicies do
  use Ecto.Migration

  def up do
    execute("alter table profiles enable row level security;")

    execute("""
    create policy "Public profiles are viewable by everyone."
      on profiles for select
      using ( true );
    """)

    execute("""
    create policy "Users can insert their own profile."
      on profiles for insert
      with check ( (select auth.uid()) = id );
    """)

    execute("""
    create policy "Users can update own profile."
      on profiles for update
      using ( (select auth.uid()) = id );
    """)
  end

  def down do
    execute("alter table profiles disable row level security;")

    execute("""
    drop policy "Public profiles are viewable by everyone." on profiles;
    """)

    execute("""
    drop policy "Users can insert their own profile." on profiles;
    """)

    execute("""
    drop policy "Users can update own profile." on profiles;
    """)
  end
end
