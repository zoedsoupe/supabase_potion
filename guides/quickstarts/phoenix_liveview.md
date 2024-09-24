# Use Supabase with Phoenix LiveView

Learn how to create a LiveView project and connect it to your Supabase Postgres database.

## 1. Create a Phoenix LiveView Project

Make sure your Elixir and Phoenix installer versions are up to date, then use `mix phx.new` to scaffold a new LiveView project. Postgresql is the default database for Phoenix apps.

Go to the [Phoenix docs](https://phoenixframework.org) for more details.

```sh
mix phx.new blog
```

## 2. Set up the Postgres connection details

Go to [database.new](https://database.new/) and create a new Supabase project. Save your database password securely.

When your project is up and running, navigate to the [database settings](https://supabase.com/dashboard/project/_/settings/database) to find the URI connection string. Make sure **Use connection pooling** is checked and **Session mode** is selected. Then copy the URI. Replace the password placeholder with your saved database password.

> [!INFO]
> If your network supports IPv6 connections, you can also use the direct connection string. Uncheck **Use connection pooling** and copy the new URI.

For the production environment, you can set up this env var on your `config/runtime.exs`
```sh
export DATABASE_URL=ecto://postgres.xxxx:password@xxxx.pooler.supabase.com:5432/postgres
```

For your local dev environment your can modify the `config/dev.exs` file to look like this (replacing placeholders with your `supabase-cli` config):

```elixir
# config/dev.exs

import Config

config :blog, Blog.Repo,
  hostname: "localhost",
  port: 54322, # default supabase-cli postgres port
  username: "postgres",
  password: "postgres",
  database: "postgres"

# other configs
```

## 3. Create and run a database migration

Phoenix LiveView includes [Ecto](https://hexdocs.pm/ecto) as the data mapping and database schema magement tool (aka ORM in other stacks) as well as database migration tooling which generates the SQL migration files for you.

Create an example `Article` model and generate the migration files.

```sh
mix phx.gen.schema Posts.Article articles title:string views:integer
mix ecto.migrate
```

The first argument is the schema module followed by its plural name (used as the table name).

The generated schema above will contain:
- a schema file in `lib/blog/posts/article.ex`, with a articles table
- a migration file for the repository

More information on the [mix phx.new.schema task documentation](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html)

## 4. Use the Model to interact with the database

You can use the included Phoenix console to interact with the database. For example, you can create new entries or list all entries in a Model's table.

```sh
iex -S mix
```

```iex
article = %Blog.Posts.Article{title: "Hello Phoenix", body: "I am on Phoenix!"}
Blog.Repo.insert!(article) # Saves the entry to the database
Blog.Repo.all(Blog.Posts.Article) # Lists all the entries of a model in the database
```

## 5. Start the app

Run the development server. Go to [http://127.0.0.1:4000](http://127.0.0.1:4000) in a browser to see your application running.

```sh
iex -S mix phx.server
```

> This command also starts an iex session (REPL) while staring the web server
