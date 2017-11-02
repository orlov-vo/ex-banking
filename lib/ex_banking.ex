defmodule ExBanking do
  @moduledoc """
  Test task for heathmont.net
  """
  import Utils, only: [is_error: 1]

  @type banking_error :: {:error,
    :wrong_arguments |
    :user_already_exists |
    :user_does_not_exist |
    :not_enough_money |
    :sender_does_not_exist |
    :receiver_does_not_exist |
    :too_many_requests_to_user |
    :too_many_requests_to_sender |
    :too_many_requests_to_receiver
  }

  @users_table :users
  @balance_table :balances

  @doc """
  - Function creates new user in the system
  - New user has zero balance of any currency
  """
  @spec create_user(user :: String.t) :: :ok | banking_error
  def create_user(user) do
    create_tables_if_not_exists()
    if :ets.insert_new(@users_table, {user}), do: :ok, else: {:error, :user_already_exists}
  end

  @doc """
  - Increases user's balance in given `currency` by `amount` value
  - Returns `new_balance` of the user in given format
  """
  @spec deposit(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency) do
    create_tables_if_not_exists()

    result = :ok
      |> RateLimit.request_start(user)
      |> check_amount(amount)
      |> check_user_exists(user)

    case result do
      :ok ->
        {:ok, b} = get_raw_balance(user, currency)
        new_balance = b + amount
        :ets.insert(@balance_table, {{user, currency}, new_balance})
        {:ok, money(new_balance)}
      err -> err
    end
    |> RateLimit.request_end(user)
  end

  @doc """
  - Decreases user's balance in given `currency` by `amount` value
  - Returns `new_balance` of the user in given format
  """
  @spec withdraw(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency) do
    create_tables_if_not_exists()

    result = :ok
      |> RateLimit.request_start(user)
      |> check_amount(amount)
      |> check_user_exists(user)

    case result do
      :ok ->
        {:ok, b} = get_raw_balance(user, currency)
        new_balance = b - amount
        if new_balance < 0 do
          {:error, :not_enough_money}
        else
          :ets.insert(@balance_table, {{user, currency}, new_balance})
          {:ok, money(new_balance)}
        end
      err -> err
    end
    |> RateLimit.request_end(user)
  end

  @doc """
  Returns `balance` of the user in given format
  """
  @spec get_balance(user :: String.t, currency :: String.t) :: {:ok, balance :: number} | banking_error
  def get_balance(user, currency) do
    RateLimit.request_start(user)

    case get_raw_balance(user, currency) do
      {:ok, b} -> {:ok, money(b)}
      err -> err
    end
    |> RateLimit.request_end(user)
  end

  @doc """
  - Decreases `from_user`'s balance in given `currency` by `amount` value
  - Increases `to_user`'s balance in given `currency` by `amount` value
  - Returns `balance` of `from_user` and `to_user` in given format
  """
  @spec send(from_user :: String.t, to_user :: String.t, amount :: number, currency :: String.t) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(from_user, to_user, amount, currency) do
    create_tables_if_not_exists()

    result = :ok
      |> RateLimit.request_start(from_user, :too_many_requests_to_sender)
      |> RateLimit.request_start(to_user, :too_many_requests_to_receiver)
      |> check_amount(amount)
      |> check_user_exists(from_user)
      |> check_user_exists(to_user)

    case result do
      :ok ->
        case withdraw(from_user, amount, currency) do
          {:ok, from_balance} ->
            {:ok, to_balance} = deposit(to_user, amount, currency)
            {:ok, from_balance, to_balance}
          err -> err
        end
      err -> err
    end
    |> RateLimit.request_end(from_user)
    |> RateLimit.request_end(to_user)
  end

  @spec create_tables_if_not_exists() :: :ok
  defp create_tables_if_not_exists do
    EtsUtils.create_table_if_not_exists(@users_table)
    EtsUtils.create_table_if_not_exists(@balance_table)
  end

  @spec get_raw_balance(user :: String.t, currency :: String.t) :: {:ok, balance :: number} | banking_error
  defp get_raw_balance(user, currency) do
    create_tables_if_not_exists()
    case check_user_exists(:ok, user) do
      :ok ->
        case :ets.lookup(@balance_table, {user, currency}) |> List.first() do
          nil -> {:ok, 0}
          t -> {:ok, elem(t, 1)}
        end
      err -> err
    end
  end

  @spec user_exists?(user :: String.t) :: boolean
  defp user_exists?(user) do
    create_tables_if_not_exists()
    u = :ets.lookup(@users_table, user) |> List.first()
    not is_nil(u)
  end

  @spec check_amount(res :: any, amount :: number) :: any | banking_error
  defp check_amount(res, _amount) when is_error(res), do: res
  defp check_amount(res, amount) when amount >= 0, do: res
  defp check_amount(_res, _amount), do: {:error, :wrong_arguments}

  @spec check_user_exists(res :: any, user :: String.t) :: any | banking_error
  defp check_user_exists(res, _user) when is_error(res), do: res
  defp check_user_exists(res, user) do
    if user_exists?(user), do: res, else: {:error, :user_does_not_exist}
  end

  @spec money(number) :: number
  defp money(x) when is_float(x), do: trunc(x * 100) / 100
  defp money(x), do: x
end
