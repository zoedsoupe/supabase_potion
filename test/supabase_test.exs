defmodule SupabaseTest do
  use ExUnit.Case, async: true

  alias Supabase.Client
  alias Supabase.MissingSupabaseConfig

  describe "init_client/1" do
    test "should return a valid client on valid attrs" do
      {:ok, %Client{} = client} =
        Supabase.init_client("https://test.supabase.co", "test")

      assert client.conn.base_url == "https://test.supabase.co"
      assert client.conn.api_key == "test"
    end
  end

  describe "init_client!/1" do
    test "should return a valid client on valid attrs" do
      assert %Client{} = client =
        Supabase.init_client!("https://test.supabase.co", "test")

      assert client.conn.base_url == "https://test.supabase.co"
      assert client.conn.api_key == "test"
    end

    test "should raise MissingSupabaseConfig on missing base_url" do
      assert_raise MissingSupabaseConfig, fn ->
        Supabase.init_client!("", "")
      end
    end

    test "should raise MissingSupabaseConfig on missing api_key" do
      assert_raise MissingSupabaseConfig, fn ->
        Supabase.init_client!("https://test.supabase.co", "")
      end
    end
  end
end
