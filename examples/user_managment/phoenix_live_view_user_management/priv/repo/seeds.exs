# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Arcane.Repo.insert!(%Arcane.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
Arcane.Repo.query!("""
insert into storage.buckets (id, name) values ('avatars', 'avatars');
""")
