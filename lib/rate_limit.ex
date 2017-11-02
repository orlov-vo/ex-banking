defmodule RateLimit do
  @moduledoc """
  The module allows you to limit the number of requests for the user by username
  """
  import Utils, only: [is_error: 1]

  @max_request 10
  @tablename :requests

  @doc """
  Short version of `request_start/2`, to which it is passed `:ok` as the first argument
  """
  @spec request_start(user :: String.t) :: any | {:error, :too_many_requests_to_user}
  def request_start(user), do: request_start(:ok, user)

  @doc """
  Short version of `request_start/3`, to which it is passed `:too_many_requests_to_user` as the thrid argument
  """
  @spec request_start(res :: any, user :: String.t) :: any | {:error, :too_many_requests_to_user}
  def request_start(res, user), do: request_start(res, user, :too_many_requests_to_user)

  @doc """
  The marker of what the request started.
  If `res` contains error (checked with macro `Utils.is_error/1`) then it pass `res` as return.
  """
  @spec request_start(res :: any, user :: String.t, error :: atom) :: any | {:error, atom}
  def request_start(res, _user, _error) when is_error(res), do: res
  def request_start(res, user, error) do
    create_tables_if_not_exists()
    if (req = requests(user)) < @max_request do
      :ets.insert(@tablename, {user, req + 1})
      res
    else
      {:error, error}
    end
  end

  @doc """
  The marker of what the request ended
  If `res` contains error (checked with macro `Utils.is_error/1`) then it pass `res` as return.
  """
  @spec request_end(res :: any, user :: String.t) :: any | {:error, :request_hack}
  def request_end(res, _user) when is_error(res), do: res
  def request_end(res, user) do
    create_tables_if_not_exists()
    if (req = requests(user)) <= @max_request do
      :ets.insert(@tablename, {user, req - 1})
      res
    else
      {:error, :request_hack}
    end
  end

  @doc """
  Returns the number of requests for the user at the moment
  """
  @spec requests(user :: String.t) :: integer
  def requests(user) do
    create_tables_if_not_exists()
    case :ets.lookup(@tablename, user) |> List.first() do
      nil -> 0
      x -> elem(x, 1)
    end
  end

  @spec create_tables_if_not_exists() :: :ok
  defp create_tables_if_not_exists do
    EtsUtils.create_table_if_not_exists(@tablename)
  end
end
