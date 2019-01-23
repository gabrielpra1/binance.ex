defmodule BinanceHelper do
  @moduledoc """
  false
  """

  def timestamp_ms do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end

  def api_key do
    Application.get_env(:binance, :api_key)
  end

  def secret_key do
    Application.get_env(:binance, :secret_key)
  end

  def sign(secret_key, argument_string) do
    :crypto.hmac(:sha256, secret_key, argument_string)
    |> Base.encode16()
  end
end
