defmodule Arcane.Repo do
  use Ecto.Repo,
    otp_app: :arcane,
    adapter: Ecto.Adapters.Postgres
end
