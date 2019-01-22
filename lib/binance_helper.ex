defmodule BinanceHelper do
  @moduledoc """
  false
  """

  def timestamp_ms do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end
end
