import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :arcane, Arcane.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "arcane_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 54322,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :arcane, ArcaneWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "W0RjQEaGhgYhQRvuaYSomPIeJ9iJLUtDVgMn3yJvwC9By/R9jpThnEdXxngvGQLG",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
