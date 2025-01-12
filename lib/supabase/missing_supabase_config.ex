defmodule Supabase.MissingSupabaseConfig do
  defexception [:message]

  @impl true
  def exception(key: key, client: client) do
    missing = get_missing_desc(key)
    walktrough = get_walktrough(key)

    message = """
    Missing #{missing} configuration for your Supabase Client #{if client, do: client, else: ""}.

    #{if client do
      """
      Please ensure or add the following to your config/config.exs file:

          import Config

          config :supabase_potion, #{client},
            base_url: "https://<app-name>.supabase.co",
            api_key: "<supabase-api-key>",
            conn: %{access_token: "<supabase-access-token>"},
            db: %{schema: "another"}, # default to public
            auth: %{debug: true}

      Remember to set the environment variables SUPABASE_BASE_URL and SUPABASE_API_KEY
      if you choose this option. Otherwise you can pass the values directly to the config file.
      """
    end}

    #{if is_nil(client) do
      """
      Please ensure you're passing the values directly to the `Supabase.init_client/3` function:

          iex> Supabase.init_client!(
          iex>   System.fetch_env!("SUPABASE_BASE_URL"),
          iex>   System.fetch_env!("SUPABASE_API_KEY"),
          iex> )
      """
    end}

    #{walktrough}
    """

    %__MODULE__{message: message}
  end

  defp get_missing_desc(:key), do: "API Key"
  defp get_missing_desc(:url), do: "Base URL"
  defp get_missing_desc(:config), do: "API Key and Base URL"

  defp get_walktrough(:key), do: missing_key_config_walktrough()
  defp get_walktrough(:url), do: missing_url_config_walktrough()

  defp get_walktrough(:config) do
    missing_key_config_walktrough() <> "\n\n" <> missing_url_config_walktrough()
  end

  defp missing_url_config_walktrough do
    """
    You can find your Supabase base URL in the Settings page of your project.
    Firstly select your project from the initial Dashboard.
    On the left sidebar, click on the Settings icon, then select API.
    The base URL is the first field on the page.
    """
  end

  defp missing_key_config_walktrough do
    """
    You can find your Supabase API key in the Settings page of your project.
    Firstly select your project from the initial Dashboard.
    On the left sidebar, click on the Settings icon, then select API.
    The API key is the second field on the page.

    There two types of API keys, the public and the private. The last one
    bypass any Row Level Security (RLS) rules you have set up.
    So you shouldn't use it in your frontend application.

    If you don't know what RLS is, you can read more about it here:
    https://supabase.com/docs/guides/auth/row-level-security

    For most cases you should prefer to use the public "anon" Key.
    """
  end
end
