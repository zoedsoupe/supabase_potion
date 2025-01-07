defmodule Supabase.Fetcher.RequestTest do
  use ExUnit.Case, async: true

  alias Supabase.Fetcher.Request

  setup do
    {:ok, client: Supabase.init_client!("http://127.0.0.1:54321", "test-api")}
  end

  # unit testing the builder
  describe "new/1" do
    test "creates a new Request struct with default values", %{client: client} do
      builder = Request.new(client)

      assert %Request{} = builder
      assert builder.client == client
      assert have_header?(builder.headers, "authorization")
      assert builder.method == :get
      refute builder.url
    end
  end

  describe "with_<service>_url/2" do
    test "sets the correct service URL and path", %{client: client} do
      builder = Request.new(client)

      builder = Request.with_auth_url(builder, "/token")
      assert builder.url == URI.parse("http://127.0.0.1:54321/auth/v1/token")
      assert builder.service == :auth
    end

    test "overwrites the URL on subsequent calls", %{client: client} do
      builder = Request.new(client)

      builder = Request.with_storage_url(builder, "/upload")
      assert builder.url == URI.parse("http://127.0.0.1:54321/storage/v1/upload")

      builder = Request.with_storage_url(builder, "/download")
      assert builder.url == URI.parse("http://127.0.0.1:54321/storage/v1/download")
    end
  end

  describe "with_method/2" do
    test "sets the HTTP method", %{client: client} do
      builder = Request.new(client) |> Request.with_method(:post)

      assert builder.method == :post
    end

    test "defaults to :get if no method is specified", %{client: client} do
      builder = Request.new(client) |> Request.with_method()

      assert builder.method == :get
    end
  end

  describe "with_headers/2" do
    test "adds headers to the builder", %{client: client} do
      builder =
        Request.new(client)
        |> Request.with_headers(%{"Content-Type" => "application/json"})

      assert have_header?(builder.headers, "content-type")
    end

    test "merges headers overwriting lef-associative", %{client: client} do
      # new/1 already fills the "authorization" header
      builder =
        Request.new(client)
        |> Request.with_headers(%{"Content-Type" => "application/json"})
        |> Request.with_headers(%{"Authorization" => "Bearer token"})

      assert have_headers?(builder.headers, ["content-type", "authorization"])
      assert get_header(builder.headers, "authorization") =~ "token"
    end

    test "removes headers with nil values", %{client: client} do
      builder =
        Request.new(client)
        |> Request.with_headers(%{"Content-Type" => "application/json"})
        |> Request.with_headers(%{"Content-Type" => nil})

      assert have_header?(builder.headers, "content-type")
      assert get_header(builder.headers, "content-type") == "application/json"
    end
  end

  describe "with_body/2" do
    test "sets a JSON-encoded body when given a map", %{client: client} do
      body = %{key: "value"}
      builder = Request.new(client) |> Request.with_body(body)

      assert builder.body == Jason.encode_to_iodata!(%{"key" => "value"})
    end

    test "sets raw body when given a binary", %{client: client} do
      body = "raw body"
      builder = Request.new(client) |> Request.with_body(body)

      assert builder.body == body
    end
  end

  describe "with_query/2" do
    test "appends query parameters", %{client: client} do
      builder = Request.new(client) |> Request.with_query(%{"key" => "value"})

      assert builder.query == [{"key", "value"}]
    end

    test "do not overwrites existing query parameters", %{client: client} do
      builder =
        Request.new(client)
        |> Request.with_query(%{"key1" => "value1"})
        |> Request.with_query(%{"key2" => "value2"})

      assert have_headers?(builder.query, ["key1", "key2"])
    end
  end

  describe "extensibility with decoders and parsers" do
    test "sets a custom body decoder", %{client: client} do
      builder = Request.new(client) |> Request.with_body_decoder(MyCustomDecoder)

      assert builder.body_decoder == MyCustomDecoder
    end

    test "sets a custom error parser", %{client: client} do
      builder = Request.new(client) |> Request.with_error_parser(MyErrorParser)

      assert builder.error_parser == MyErrorParser
    end
  end

  describe "overwriting behavior" do
    test "overwrites previously set attributes", %{client: client} do
      builder =
        Request.new(client)
        |> Request.with_method(:post)
        |> Request.with_method(:put)

      assert builder.method == :put
    end

    test "allows sequential updates", %{client: client} do
      builder =
        Request.new(client)
        |> Request.with_method(:post)
        |> Request.with_headers(%{"Authorization" => "Bearer token"})
        |> Request.with_query(%{"key" => "value"})

      assert builder.method == :post
      assert have_header?(builder.headers, "authorization")
      assert get_header(builder.headers, "authorization") =~ "token"
      assert builder.query == [{"key", "value"}]
    end
  end

  describe "get_query_param/3" do
    setup ctx do
      builder =
        ctx.client
        |> Request.new()
        |> Request.with_query(%{"key1" => "value1", "key2" => "value2"})

      {:ok, Map.put(ctx, :builder, builder)}
    end

    test "retrieves an existing query parameter", %{builder: builder} do
      assert Request.get_query_param(builder, "key1") == "value1"
    end

    test "returns nil for a missing query parameter", %{builder: builder} do
      assert Request.get_query_param(builder, "key3") == nil
    end

    test "returns the default value for a missing query parameter", %{builder: builder} do
      assert Request.get_query_param(builder, "key3", "default_value") == "default_value"
    end

    test "handles empty query parameters gracefully", %{client: client} do
      builder = Request.new(client)
      assert Request.get_query_param(builder, "key") == nil
    end
  end

  describe "get_header/3" do
    setup ctx do
      builder =
        Request.new(ctx.client)
        |> Request.with_headers(%{
          "Authorization" => "Bearer token",
          "Content-Type" => "application/json"
        })

      {:ok, builder: builder}
    end

    test "retrieves an existing header", %{builder: builder} do
      assert Request.get_header(builder, "Authorization") == "Bearer token"
    end

    test "returns nil for a missing header", %{builder: builder} do
      assert Request.get_header(builder, "Accept") == nil
    end

    test "returns the default value for a missing header", %{builder: builder} do
      assert Request.get_header(builder, "Accept", "application/xml") == "application/xml"
    end

    test "handles empty headers gracefully", %{client: client} do
      builder = Request.new(client)
      assert Request.get_header(builder, "Authorization") == nil
    end
  end

  describe "merge_query_param/4" do
    setup ctx do
      builder = Request.new(ctx.client) |> Request.with_query(%{"key1" => "value1"})
      {:ok, builder: builder}
    end

    test "merges a new query parameter when key does not exist", %{builder: builder} do
      updated_fetcher = Request.merge_query_param(builder, "key2", "value2")
      assert Request.get_query_param(updated_fetcher, "key2") == "value2"
    end

    test "merges with default separator when key exists", %{builder: builder} do
      updated_fetcher = Request.merge_query_param(builder, "key1", "value2")
      assert Request.get_query_param(updated_fetcher, "key1") == "value1,value2"
    end

    test "merges with custom separator when specified", %{builder: builder} do
      updated_fetcher = Request.merge_query_param(builder, "key1", "value2", with: "|")
      assert Request.get_query_param(updated_fetcher, "key1") == "value1|value2"
    end

    test "handles merging into an empty query", %{client: client} do
      builder = Request.new(client)
      updated_fetcher = Request.merge_query_param(builder, "key1", "value1")
      assert Request.get_query_param(updated_fetcher, "key1") == "value1"
    end
  end

  describe "merge_req_header/4" do
    setup ctx do
      builder = Request.new(ctx.client) |> Request.with_headers(%{"key1" => "value1"})
      {:ok, builder: builder}
    end

    test "merges a new header value when key does not exist", %{builder: builder} do
      updated_fetcher = Request.merge_req_header(builder, "key2", "value2")
      assert Request.get_header(updated_fetcher, "key2") == "value2"
    end

    test "merges with default separator when key exists", %{builder: builder} do
      updated_fetcher = Request.merge_req_header(builder, "key1", "value2")
      assert Request.get_header(updated_fetcher, "key1") == "value1,value2"
    end

    test "merges with custom separator when specified", %{builder: builder} do
      updated_fetcher = Request.merge_req_header(builder, "key1", "value2", with: "|")
      assert Request.get_header(updated_fetcher, "key1") == "value1|value2"
    end

    test "handles merging into an empty header", %{client: client} do
      builder = Request.new(client)
      updated_fetcher = Request.merge_req_header(builder, "key1", "value1")
      assert Request.get_header(updated_fetcher, "key1") == "value1"
    end
  end

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
