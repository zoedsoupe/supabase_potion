defmodule SupabaseTest do
  use ExUnit.Case, async: true

  alias Supabase.Client
  alias Supabase.MissingSupabaseConfig

  describe "init_client/1" do
    test "should return a valid client on valid attrs" do
      assert {:ok, %Client{} = client} =
               Supabase.init_client("https://test.supabase.co", "test")

      assert client.base_url == "https://test.supabase.co"
      assert client.api_key == "test"
    end

    test "should return a valid client on valid attrs and additional attrs" do
      assert {:ok, %Client{} = client} =
               Supabase.init_client("https://test.supabase.co", "test",
                 auth: [debug: true, storage_key: "test-key"],
                 db: [schema: "custom"]
               )

      assert client.base_url == "https://test.supabase.co"
      assert client.api_key == "test"
      assert client.auth.debug
      assert client.auth.storage_key == "test-key"
      assert client.db.schema == "custom"
    end
  end

  describe "init_client!/1" do
    test "should return a valid client on valid attrs" do
      assert %Client{} =
               client =
               Supabase.init_client!("https://test.supabase.co", "test")

      assert client.base_url == "https://test.supabase.co"
      assert client.api_key == "test"
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
