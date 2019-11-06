defmodule Binance.Futures.Balance do
  defstruct [
    :account_id,
    :asset,
    :balance,
    :withdraw_available
  ]

  use ExConstructor
end
