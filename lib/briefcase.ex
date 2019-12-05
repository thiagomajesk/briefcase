defmodule Briefcase do
  import Plug.Conn

  alias Briefcase.Store
  alias Briefcase.Envelope

  @session_key "briefcase_store"

  def init(opts), do: opts

  def call(conn, _opts) do
    mark_incoming_entries_dirty(conn)

    # Cleans all entries already marked as dirty in the store
    register_before_send(conn, &handle_response/1)
  end

  @doc """
  Packs the content into the session store
  """
  def pack(conn, keyword) when is_list(keyword) do
    conn
    |> get_store()
    |> Store.merge(keyword, false)
    |> put_store(conn)
  end

  @doc """
  Unpack the stored content without marking it dirty
  """
  @spec peek(Plug.Conn.t(), atom(), any()) :: any()
  def peek(conn, key, default \\ nil) when is_atom(key) do
    with store <- get_store(conn),
         store <- Store.toggle_dirty(store, key, false),
         conn <- put_store(store, conn) do
      case Map.fetch(store, key) do
        {:ok, %Envelope{value: value}} -> {conn, value}
        :error -> {conn, default}
      end
    end
  end

  @doc """
  Unpack the stored content marking it dirty
  """
  @spec unpack(Plug.Conn.t(), atom(), any()) :: any()
  def unpack(conn, key, default \\ nil) when is_atom(key) do
    with store <- get_store(conn),
         store <- Store.toggle_dirty(store, key, true),
         conn <- put_store(store, conn) do
      case Map.fetch(store, key) do
        {:ok, %Envelope{value: value}} -> {conn, value}
        :error -> {conn, default}
      end
    end
  end

  defp mark_incoming_entries_dirty(conn) do
    conn
    |> get_store()
    |> Store.make_all_dirty()
    |> put_store(conn)
  end

  defp handle_response(conn) do
    conn
    |> get_store()
    |> Store.clean()
    |> put_store(conn)
  end

  defp get_store(conn) do
    conn
    |> fetch_session()
    |> get_session(@session_key)
  end

  defp put_store(store, conn) do
    put_session(conn, @session_key, store)
  end
end
