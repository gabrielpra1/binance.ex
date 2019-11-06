defmodule BinanceHttp do
  @moduledoc """
  false
  """

  alias Binance.Credentials

  def get_endpoint(:binance), do: "https://api.binance.com"
  def get_endpoint(:futures), do: "https://fapi.binance.com"

  def get(service, url, headers \\ []) do
    endpoint = get_endpoint(service)
    HTTPoison.get("#{endpoint}#{url}", headers)
    |> parse_get_response
  end

  def get(_service, _url, _params, nil, api_key) when not is_nil(api_key),
    do: {:error, {:config_missing, "Secret key missing"}}

  def get(_service, _url, _params, secret_key, nil) when not is_nil(secret_key),
    do: {:error, {:config_missing, "API key missing"}}


  def get(service, url, params, nil, nil) do
    %Credentials{api_key: api_key, api_secret: api_secret} = Credentials.get()
    get(service, url, params, api_secret, api_key)
  end

  def get(service, url, params, secret_key, api_key) do
    headers = [{"X-MBX-APIKEY", api_key}]
    receive_window = 5000

    params =
      Map.merge(params, %{
        timestamp: BinanceHelper.timestamp_ms(),
        recvWindow: receive_window
      })

    argument_string = URI.encode_query(params)

    signature = BinanceHelper.sign(secret_key, argument_string)
    get(service, "#{url}?#{argument_string}&signature=#{signature}", headers)
  end

  def post(service, url, params) do
    %Credentials{api_key: api_key, api_secret: api_secret} = Credentials.get()
    post(service, url, api_key, api_secret, params)
  end

  def post(_service, _url, nil, secret_key, _params) when not is_nil(secret_key),
  do: {:error, {:config_missing, "Secret key missing"}}

  def post(_service, _url, api_key, nil, _params) when not is_nil(api_key),
    do: {:error, {:config_missing, "API key missing"}}

  def post(service, url, nil, nil, params) do
    %Credentials{api_key: api_key, api_secret: api_secret} = Credentials.get()
    post(service, url, api_key, api_secret, params)
  end

  def post(service, url, api_key, secret_key, params) do
    argument_string = URI.encode_query(params)
    signature = BinanceHelper.sign(secret_key, argument_string)
    endpoint = get_endpoint(service)

    case HTTPoison.post("#{endpoint}#{url}?#{argument_string}&signature=#{signature}", "", [
           {"X-MBX-APIKEY", api_key}
         ]) do
      {:error, err} ->
        {:error, {:http_error, err}}

      {:ok, response} ->
        case Poison.decode(response.body) do
          {:ok, data} -> {:ok, data}
          {:error, err} -> {:error, {:poison_decode_error, err}}
        end
    end
  end

  defp parse_get_response({:ok, response}) do
    response.body
    |> Poison.decode()
    |> parse_response_body
  end

  defp parse_get_response({:error, err}) do
    {:error, {:http_error, err}}
  end

  defp parse_response_body({:ok, data}) do
    case data do
      %{"code" => _c, "msg" => _m} = error -> {:error, error}
      _ -> {:ok, data}
    end
  end

  defp parse_response_body({:error, err}) do
    {:error, {:poison_decode_error, err}}
  end
end
