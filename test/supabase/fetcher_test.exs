defmodule Supabase.FetcherTest do
  use ExUnit.Case, async: true

  alias Supabase.Fetcher

  setup do
    {:ok, client: Supabase.init_client!("http://127.0.0.1:54321", "test-api")}
  end

  # unit testing the builder
  describe "new/1" do
    test "creates a new Fetcher struct with default values", %{client: client} do
      fetcher = Fetcher.new(client)

      assert %Fetcher{} = fetcher
      assert fetcher.client == client
      assert have_header?(fetcher.headers, "authorization")
      assert fetcher.method == :get
      refute fetcher.url
    end
  end

  describe "with_<service>_url/2" do
    test "sets the correct service URL and path", %{client: client} do
      fetcher = Fetcher.new(client)

      fetcher = Fetcher.with_auth_url(fetcher, "/token")
      assert fetcher.url == URI.parse("http://127.0.0.1:54321/auth/v1/token")
      assert fetcher.service == :auth
    end

    test "overwrites the URL on subsequent calls", %{client: client} do
      fetcher = Fetcher.new(client)

      fetcher = Fetcher.with_storage_url(fetcher, "/upload")
      assert fetcher.url == URI.parse("http://127.0.0.1:54321/storage/v1/upload")

      fetcher = Fetcher.with_storage_url(fetcher, "/download")
      assert fetcher.url == URI.parse("http://127.0.0.1:54321/storage/v1/download")
    end
  end

  describe "with_method/2" do
    test "sets the HTTP method", %{client: client} do
      fetcher = Fetcher.new(client) |> Fetcher.with_method(:post)

      assert fetcher.method == :post
    end

    test "defaults to :get if no method is specified", %{client: client} do
      fetcher = Fetcher.new(client) |> Fetcher.with_method()

      assert fetcher.method == :get
    end
  end

  describe "with_headers/2" do
    test "adds headers to the fetcher", %{client: client} do
      fetcher =
        Fetcher.new(client)
        |> Fetcher.with_headers(%{"Content-Type" => "application/json"})

      assert have_header?(fetcher.headers, "content-type")
    end

    test "merges headers overwriting lef-associative", %{client: client} do
      # new/1 already fills the "authorization" header
      fetcher =
        Fetcher.new(client)
        |> Fetcher.with_headers(%{"Content-Type" => "application/json"})
        |> Fetcher.with_headers(%{"Authorization" => "Bearer token"})

      assert have_headers?(fetcher.headers, ["content-type", "authorization"])
      assert get_header(fetcher.headers, "authorization") =~ "token"
    end

    test "removes headers with nil values", %{client: client} do
      fetcher =
        Fetcher.new(client)
        |> Fetcher.with_headers(%{"Content-Type" => "application/json"})
        |> Fetcher.with_headers(%{"Content-Type" => nil})

      assert have_header?(fetcher.headers, "content-type")
      assert get_header(fetcher.headers, "content-type") == "application/json"
    end
  end

  describe "with_body/2" do
    test "sets a JSON-encoded body when given a map", %{client: client} do
      body = %{key: "value"}
      fetcher = Fetcher.new(client) |> Fetcher.with_body(body)

      assert fetcher.body == Jason.encode_to_iodata!(%{"key" => "value"})
    end

    test "sets raw body when given a binary", %{client: client} do
      body = "raw body"
      fetcher = Fetcher.new(client) |> Fetcher.with_body(body)

      assert fetcher.body == body
    end
  end

  describe "with_query/2" do
    test "appends query parameters", %{client: client} do
      fetcher = Fetcher.new(client) |> Fetcher.with_query(%{"key" => "value"})

      assert fetcher.query == [{"key", "value"}]
    end

    test "do not overwrites existing query parameters", %{client: client} do
      fetcher =
        Fetcher.new(client)
        |> Fetcher.with_query(%{"key1" => "value1"})
        |> Fetcher.with_query(%{"key2" => "value2"})

      assert have_headers?(fetcher.query, ["key1", "key2"])
    end
  end

  describe "with_options/2" do
    test "sets Finch request options", %{client: client} do
      options = [pool_timeout: 5000, connect_timeout: 3000]
      fetcher = Fetcher.new(client) |> Fetcher.with_options(options)

      assert fetcher.options == options
    end
  end

  describe "extensibility with decoders and parsers" do
    test "sets a custom body decoder", %{client: client} do
      fetcher = Fetcher.new(client) |> Fetcher.with_body_decoder(MyCustomDecoder)

      assert fetcher.body_decoder == MyCustomDecoder
    end

    test "sets a custom error parser", %{client: client} do
      fetcher = Fetcher.new(client) |> Fetcher.with_error_parser(MyErrorParser)

      assert fetcher.error_parser == MyErrorParser
    end
  end

  describe "overwriting behavior" do
    test "overwrites previously set attributes", %{client: client} do
      fetcher =
        Fetcher.new(client)
        |> Fetcher.with_method(:post)
        |> Fetcher.with_method(:put)

      assert fetcher.method == :put
    end

    test "allows sequential updates", %{client: client} do
      fetcher =
        Fetcher.new(client)
        |> Fetcher.with_method(:post)
        |> Fetcher.with_headers(%{"Authorization" => "Bearer token"})
        |> Fetcher.with_query(%{"key" => "value"})

      assert fetcher.method == :post
      assert have_header?(fetcher.headers, "authorization")
      assert get_header(fetcher.headers, "authorization") =~ "token"
      assert fetcher.query == [{"key", "value"}]
    end
  end

  # VCR and "integration" tests
  defp have_header?(headers, name) do
    Enum.any?(headers, fn {k, _} ->
      String.downcase(k) == String.downcase(name)
    end)
  end

  defp have_headers?(headers, keys) do
    Enum.all?(keys, &have_header?(headers, &1))
  end

  defp get_header(headers, name) do
    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == String.downcase(name), do: v
    end)
  end
end
