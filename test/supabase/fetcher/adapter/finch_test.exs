defmodule Supabase.Fetcher.Adapter.FinchTest do
  use ExUnit.Case, async: true

  import Mox

  alias Supabase.Error
  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @mock Supabase.TestHTTPAdapter

  setup do
    client = Supabase.init_client!("http://localhost:54321", "test-api")

    {:ok,
     client: client,
     builder:
       client
       |> Request.new()
       |> Request.with_http_client(@mock)
       |> Request.with_method(:get)
       |> Request.with_database_url("/films")}
  end

  describe "dealing with responses" do
    test "makes a successful request and returns a response", %{builder: builder} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        {:ok, %Finch.Response{status: 200, headers: [], body: ~s({"data": "ok"})}}
      end)

      assert {:ok, %Response{status: 200, body: %{"data" => "ok"}}} =
               Fetcher.request(builder)
    end

    test "handles error response from server", %{builder: builder} do
      @mock
      |> expect(:request, fn %Request{}, _opts ->
        {:ok,
         %Finch.Response{status: 500, headers: [], body: ~s({"error": "Internal Server Error"})}}
      end)

      assert {:error, %Error{code: :server_error}} = Fetcher.request(builder)
    end

    test "uploads a file successfully", %{builder: builder} do
      file_path = "/path/to/file.txt"

      @mock
      |> expect(:upload, fn %Request{}, ^file_path, _opts ->
        {:ok, %Finch.Response{status: 201, headers: [], body: ~s({"upload": "success"})}}
      end)

      assert {:ok, %Response{status: 201, body: %{"upload" => "success"}}} =
               Fetcher.upload(builder, file_path)
    end
  end

  describe "dealing with streams" do
    test "streams a response successfully", %{builder: builder} do
      @mock
      |> expect(:stream, fn %Request{}, _opts ->
        status = 200
        headers = [{"content-length", 80_543}]
        stream = Stream.cycle(["chunk1", "chunk2"])
        body = Enum.take(stream, 2) |> Enum.to_list() |> Enum.join(",")
        {:ok, %Finch.Response{status: status, headers: headers, body: body}}
      end)

      builder =
        Request.with_body_decoder(builder, fn %{body: body}, _opts ->
          {:ok, String.split(body, ",", trim: true)}
        end)

      assert {:ok, %Response{} = resp} = Fetcher.stream(builder)
      assert resp.status == 200
      assert Response.get_header(resp, "content-length") == 80_543
      assert resp.body == ["chunk1", "chunk2"]
    end

    test "streams a response successfully with custom on_response handler with no body", %{
      builder: builder
    } do
      @mock
      |> expect(:stream, fn %Request{}, on_response, _opts ->
        status = 200
        headers = [{"content-length", 80_543}]
        stream = Stream.cycle(["chunk1", "chunk2"])
        on_response.({status, headers, stream})
      end)

      on_response = fn {status, headers, body} ->
        assert status == 200
        assert List.keyfind(headers, "content-length", 0) == {"content-length", 80_543}

        # very expensing body consuming
        _ = Enum.take(body, 2) |> Enum.to_list()

        :ok
      end

      assert :ok = Fetcher.stream(builder, on_response)
    end

    test "streams a response successfully with custom on_response handler returning body", %{
      builder: builder
    } do
      @mock
      |> expect(:stream, fn %Request{}, on_response, _opts ->
        status = 200
        headers = [{"content-length", 80_543}]
        stream = Stream.cycle(["chunk1", "chunk2"])
        on_response.({status, headers, stream})
      end)

      on_response = fn {status, headers, body} ->
        assert status == 200
        assert List.keyfind(headers, "content-length", 0) == {"content-length", 80_543}

        {:ok,
         body
         |> Enum.take(2)
         |> Enum.to_list()}
      end

      assert {:ok, body} = Fetcher.stream(builder, on_response)
      assert body == ["chunk1", "chunk2"]
    end

    test "returns an error from response streaming with custom on_response handler", %{
      builder: builder
    } do
      @mock
      |> expect(:stream, fn %Request{}, on_response, _opts ->
        status = 404
        headers = [{"content-length", 80_543}]
        stream = Stream.cycle([])
        on_response.({status, headers, stream})
      end)

      on_response = fn {status, headers, _body} ->
        assert status == 404
        assert List.keyfind(headers, "content-length", 0) == {"content-length", 80_543}

        {:error, Error.new(code: :not_found, metadata: %{status: status})}
      end

      assert {:error, %Error{}} = Fetcher.stream(builder, on_response)
    end
  end

  describe "dealing with errors" do
    test "handles network errors", %{builder: builder} do
      @mock
      |> expect(:request, fn _, _opts ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      assert {:error, err} = Fetcher.request(builder)

      assert %Error{
               code: :unexpected,
               metadata: %{raw_error: %Mint.TransportError{reason: :timeout}}
             } = err
    end

    test "handles exceptions", %{builder: builder} do
      @mock
      |> expect(:upload, fn _builder, _file_path, _opts ->
        raise File.Error, reason: :enoent, path: "doesnt-matter", action: "read file stats"
      end)

      assert {:error, err} = Fetcher.upload(builder, "doesnt-matter")
      assert %Error{code: :exception, metadata: %{exception: file_error}} = err
      assert is_exception(file_error, File.Error)
      assert err.message =~ "could not read file stats"
    end
  end
end
