defmodule Binance.Credentials do
  require Logger

  @type t :: %Binance.Credentials{
          api_key: String.t(),
          api_secret: String.t()
        }

  @enforce_keys [:api_key, :api_secret]
  defstruct [:api_key, :api_secret]

  @doc """
  Get default API credentials

  ## Examples
      iex> Binance.Credentials.get()
  """
  def get(credentials \\ nil)

  def get(nil) do
    %__MODULE__{
      api_key: Application.get_env(:binance, :api_key),
      api_secret: Application.get_env(:binance, :secret_key)
    }
  end

  @doc """
  Get dynamic API credentials via ENVs

  ## Examples
      iex> Binance.Credentials.get({"B1_API_KEY", "B1_API_SECRET"})
  """
  def get({api_key_access, api_secret_access}) do
    %__MODULE__{
      api_key: Application.get_env(:binance, api_key_access),
      api_secret: Application.get_env(:binance, api_secret_access)
    }
  end

  def get(_) do
    Logger.error("Incorrect Credentials setup.")
  end
end
