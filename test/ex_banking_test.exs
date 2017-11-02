defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  @username "joe"

  test "should return user with zero balance" do
    assert ExBanking.create_user(@username) == :ok
    assert ExBanking.get_balance(@username, "USD") == {:ok, 0}
  end

  test "should return an error when user exists" do
    assert ExBanking.create_user(@username) == :ok
    assert ExBanking.create_user(@username) == {:error, :user_already_exists}
  end

  test "should successful deposit user's balance" do
    assert ExBanking.create_user(@username) == :ok
    assert ExBanking.deposit(@username, 3024.91, "USD") == {:ok, 3024.91}
    assert ExBanking.get_balance(@username, "USD") == {:ok, 3024.91}
  end

  test "should cast to 2 decimal precision" do
    assert ExBanking.create_user(@username) == :ok
    x = 100.38123
    assert ExBanking.deposit(@username, 100.38123, "USD") == {:ok, 100.38}
    x = x - 50.12974
    assert ExBanking.withdraw(@username, 50.12974, "USD") == {:ok, 50.25}
    x = x + 20.82341
    assert ExBanking.deposit(@username, 20.82341, "USD") == {:ok, 71.07}
    x = x + 10.128384
    assert ExBanking.deposit(@username, 10.128384, "USD") == {:ok, 81.20}
    x = x + 10.128384
    assert ExBanking.deposit(@username, 10.128384, "USD") == {:ok, 91.33}
    x = x + 10.228384
    assert ExBanking.deposit(@username, 10.228384, "USD") == {:ok, 101.56}

    assert ExBanking.get_balance(@username, "USD") == {:ok, trunc(x * 100) / 100}
  end

  test "should return an error when user withdraw more than it have" do
    assert ExBanking.create_user(@username) == :ok
    assert ExBanking.withdraw(@username, 50, "USD") == {:error, :not_enough_money}
  end

  test "should return an error when negative amount" do
    assert ExBanking.create_user(@username) == :ok
    assert ExBanking.deposit(@username, -10, "USD") == {:error, :wrong_arguments}
    assert ExBanking.withdraw(@username, -10, "USD") == {:error, :wrong_arguments}
  end

  test "should return an error when user isn't exists" do
    assert ExBanking.get_balance("nonexists", "USD") == {:error, :user_does_not_exist}
    assert ExBanking.deposit("nonexists", 10, "USD") == {:error, :user_does_not_exist}
    assert ExBanking.withdraw("nonexists", 10, "USD") == {:error, :user_does_not_exist}
  end

  test "should correct send from user to user" do
    assert ExBanking.create_user("foo") == :ok
    assert ExBanking.create_user("bar") == :ok
    assert ExBanking.deposit("foo", 100, "USD") == {:ok, 100}
    assert ExBanking.deposit("bar", 10, "USD") == {:ok, 10}
    assert ExBanking.send("foo", "bar", 20.25, "USD") == {:ok, 79.75, 30.25}
    assert ExBanking.get_balance("foo", "USD") == {:ok, 79.75}
    assert ExBanking.get_balance("bar", "USD") == {:ok, 30.25}
  end

  test "should has different amounts for currencies (case sensitive)" do
    assert ExBanking.create_user(@username) == :ok
    assert ExBanking.deposit(@username, 80, "USD") == {:ok, 80}
    assert ExBanking.deposit(@username, 20, "EUR") == {:ok, 20}
    assert ExBanking.get_balance(@username, "USD") == {:ok, 80}
    assert ExBanking.get_balance(@username, "usd") == {:ok, 0}
    assert ExBanking.get_balance(@username, "EUR") == {:ok, 20}
    assert ExBanking.get_balance(@username, "eur") == {:ok, 0}
  end
end
