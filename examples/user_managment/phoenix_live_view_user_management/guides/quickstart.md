# Build a User Management App with Phoenix LiveView

Learn how to use Supabase in your Phoenix LiveView App.

This tutorial demonstrates how to build a basic user management app. The app authenticates and identifies the user, stores their profile information in the database, and allows the user to log in, update their profile details, and upload a profile photo. The app uses:

- [Supabase Database](https://supabase.com/docs/guides/database) - a Postgres database for storing your user data and [Row Level Security](https://supabase.com/docs/guides/auth#row-level-security) so data is protected and users can only access their own information.
- [Supabase Auth](https://supabase.com/docs/guides/auth) - allow users to sign up and log in.
- [Supabase Storage](https://supabase.com/docs/guides/storage) - users can upload a profile photo.

![Supabase User Management example](https://supabase.com/docs/img/user-management-demo.png)

> [!INFO]
> If you get stuck while working through this guide, refer to the [full example on GitHub](https://github.com/zoedsoupe/supabase-ex/tree/main/examples/user_management/phoenix_live_view_user_management).

## Project Setup

Before we start building we're going to set up our Database and API. This is as simple as starting a new Project in Supabase and then creating a "schema" inside the database.

### Create a Project

1. [Create a new project](https://supabase.com/dashboard) in the Supabase Dashboard.
2. Enter your project details.
3. Wait for the new database to launch.

### Set up the database schema

I'll be doing that using the [Ecto migrations](https://hexdocs.pm/ecto_sql), but you can also do that manually in the Supabase Dashboard.

### Get the API Keys

Now that you've created some database tables, you are ready to insert data using the auto-generated API. We just need to get the Project URL and `anon` key from the API settings.

1. Go to the [API Settings](https://supabase.com/dashboard/project/_/settings/api) page in the Dashboard.
2. Find your Project `URL`, `anon`, and `service_role` keys on this page.

## Building the app

Let's start building the Phoenix LiveView app from scratch.

### Initialize a Phoenix LiveView app

We can use [`mix phx.new`](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html) to create an app called `arcane`:

> Before issuing this command, ensure you have [elixir](https://elixir-lang.org) installed
> Also ensure that you have the [phoenix installer](https://hexdocs.pm/phoenix/installation.html) in your machine

```bash
mix phx.new --adapter bandit --no-tailwind --app arcane phoenix_live_view_user_management

cd phoenix_live_view_user_management
```

Then let's install the needed dependencies to integrate with supabase: [Supabase Potion](https://hexdocs.pm/supabase_potion). We only need to add these lines to your `deps` in `mix.exs`:

```elixir
defp deps do
  [
    {:supabase_potion, "~> 0.5"},
    {:supabase_gotrue, "~> 0.3"},
    {:supabase_storage, "~> 0.3"},
    # other dependencies
  ]
end
```

Then install them with:

```sh
mix deps.get
```

And finally we want to save the environment variables in a `.env`.
All we need are the API URL and the `anon` key that you copied [earlier](#get-the-api-keys).

```bash .env
export SUPABASE_URL="YOUR_SUPABASE_URL"
export SUPABASE_KEY="YOUR_SUPABASE_ANON_KEY"
```

These variables will be exposed on the browser, and that's completely fine since we have [Row Level Security](/docs/guides/auth#row-level-security) enabled on our Database.
Amazing thing about [NuxtSupabase](https://supabase.nuxtjs.org/) is that setting environment variables is all we need to do in order to start using Supabase.
No need to initialize Supabase. The library will take care of it automatically.

### App styling (optional)

An optional step is to update the CSS file `assets/main.css` to make the app look nice.
You can find the full contents of this file [here](https://github.com/zoedsoupe/supabase-ex/blob/main/examples/user_managment/phoenix_live_view_user_management/assets/css/app.css).

### Set up Auth component

TODO

### User state

TODO

### Account component

TODO

### Launch!

TODO

Once that's done, run this in a terminal window:

```bash
iex -S mix phx.server
```

And then open the browser to [localhost:4000](http://localhost:4000) and you should see the completed app.

![Supabase Phoenix LiveView](https://supabase.com/docs/img/supabase-vue-3-demo.png)

## Bonus: Profile photos

Every Supabase project is configured with [Storage](https://supabase.com//docs/guides/storage) for managing large files like photos and videos.

### Create an upload widget

TODO

### Add the new widget

TODO

That is it! You should now be able to upload a profile photo to Supabase Storage and you have a fully functional application.
