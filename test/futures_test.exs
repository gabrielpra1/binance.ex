defmodule FuturesTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest Binance

  setup_all do
    Application.put_env(:binance, :api_key, "fake_api_key")
    Application.put_env(:binance, :secret_key, "fake_secret_key")
    HTTPoison.start()
  end

  test "ping returns an empty map" do
    use_cassette "futures/ping_ok" do
      assert Binance.Futures.ping() == {:ok, %{}}
    end
  end

  test "get_server_time success return an ok, time tuple" do
    use_cassette "futures/get_server_time_ok" do
      assert Binance.Futures.get_server_time() == {:ok, 1_568_879_218_176}
    end
  end

  test "get_exchange_info success returns the trading rules and symbol information" do
    use_cassette "futures/get_exchange_info_ok" do
      assert {:ok, %Binance.ExchangeInfo{} = info} = Binance.Futures.get_exchange_info()
      assert info.timezone == "UTC"
      assert info.server_time != nil

      assert info.rate_limits == [
               %{
                 "interval" => "MINUTE",
                 "limit" => 1200,
                 "rateLimitType" => "REQUEST_WEIGHT",
                 "intervalNum" => 1
               },
               %{
                 "interval" => "MINUTE",
                 "intervalNum" => 1,
                 "limit" => 600,
                 "rateLimitType" => "ORDERS"
               }
             ]

      assert info.exchange_filters == []
      assert [symbol | _] = info.symbols

      assert symbol == %{
               "baseAsset" => "BTC",
               "baseAssetPrecision" => 8,
               "filters" => [
                 %{
                   "filterType" => "PRICE_FILTER",
                   "maxPrice" => "100000",
                   "minPrice" => "0.01",
                   "tickSize" => "0.01"
                 },
                 %{
                   "filterType" => "LOT_SIZE",
                   "maxQty" => "1000",
                   "minQty" => "0.001",
                   "stepSize" => "0.001"
                 },
                 %{
                   "filterType" => "MARKET_LOT_SIZE",
                   "maxQty" => "1000",
                   "minQty" => "0.001",
                   "stepSize" => "0.001"
                 },
                 %{"filterType" => "MAX_NUM_ORDERS", "limit" => 0},
                 %{
                   "filterType" => "PERCENT_PRICE",
                   "multiplierDecimal" => "4",
                   "multiplierDown" => "0.8500",
                   "multiplierUp" => "1.1500"
                 }
               ],
               "maintMarginPercent" => "2.5000",
               "orderTypes" => ["LIMIT", "MARKET", "STOP"],
               "pricePrecision" => 2,
               "quantityPrecision" => 3,
               "quoteAsset" => "USDT",
               "quotePrecision" => 8,
               "requiredMarginPercent" => "5.0000",
               "status" => "TRADING",
               "symbol" => "BTCUSDT",
               "timeInForce" => ["GTC", "IOC", "FOK", "GTX"]
             }
    end
  end

  describe ".get_account" do
    test "returns current account information" do
      use_cassette "futures/get_account_ok" do
        assert Binance.Futures.get_account() == {
                 :ok,
                 %Binance.Futures.Account{
                   assets: [
                     %{
                       "asset" => "USDT",
                       "initialMargin" => "0.00000000",
                       "maintMargin" => "0.00000000",
                       "marginBalance" => "10.18000000",
                       "unrealizedProfit" => "0.00000000",
                       "walletBalance" => "10.18000000"
                     }
                   ],
                   can_deposit: true,
                   can_trade: true,
                   can_withdraw: true,
                   fee_tier: 0,
                   total_initial_margin: "0.00000000",
                   total_maint_margin: "0.00000000",
                   total_margin_balance: "10.18000000",
                   total_unrealized_profit: "0.00000000",
                   total_wallet_balance: "10.18000000",
                   update_time: 0
                 }
               }
      end
    end
  end

  describe ".get_open_orders" do
    test "when called without symbol returns all open orders for all symbols" do
      use_cassette "futures/get_open_orders_without_symbol_success" do
        assert {:ok,
                [
                  %Binance.Futures.Order{} = order_1,
                  %Binance.Futures.Order{} = order_2
                ]} = Binance.Futures.get_open_orders()

        assert order_1.client_order_id == "kFVOX0nClhOku6TTcB8B1X"
        assert order_1.cum_quote == "0"
        assert order_1.executed_qty == "0"
        assert order_1.order_id == 11_377_637
        assert order_1.orig_qty == "0.001"
        assert order_1.price == "11000"
        assert order_1.reduce_only == false
        assert order_1.side == "SELL"
        assert order_1.status == "NEW"
        assert order_1.stop_price == "0"
        assert order_1.symbol == "BTCUSDT"
        assert order_1.time_in_force == "GTC"
        assert order_1.type == "LIMIT"
        assert order_1.update_time == 1_568_997_441_781

        assert order_2.client_order_id == "qVG9BiiCkLqfvVqhHnVurH"
        assert order_2.cum_quote == "0"
        assert order_2.executed_qty == "0"
        assert order_2.order_id == 18_821_005
        assert order_2.orig_qty == "0.001"
        assert order_2.price == "9000"
        assert order_2.reduce_only == false
        assert order_2.side == "BUY"
        assert order_2.status == "NEW"
        assert order_2.stop_price == "0"
        assert order_2.symbol == "BTCUSDT"
        assert order_2.time_in_force == "GTC"
        assert order_2.type == "LIMIT"
        assert order_2.update_time == 1_568_007_063_660
      end
    end

    test "when called with symbol returns all open orders for that symbols(string)" do
      use_cassette "futures/get_open_orders_with_symbol_string_success" do
        assert {:ok, [%Binance.Futures.Order{} = order_1]} =
                 Binance.Futures.get_open_orders(%{symbol: "BTCUSDT"})

        assert order_1.client_order_id == "kFVoo0nClhOku6KbcB8B1X"
        assert order_1.cum_quote == "0"
        assert order_1.executed_qty == "0"
        assert order_1.order_id == 11_333_637
        assert order_1.orig_qty == "0.001"
        assert order_1.price == "11000"
        assert order_1.reduce_only == false
        assert order_1.side == "SELL"
        assert order_1.status == "NEW"
        assert order_1.stop_price == "0"
        assert order_1.symbol == "BTCUSDT"
        assert order_1.time_in_force == "GTC"
        assert order_1.type == "LIMIT"
        assert order_1.update_time == 1_568_995_541_781
      end
    end
  end

  describe ".get_order" do
    test "gets an order information by exchange order id" do
      use_cassette "futures/get_order_by_exchange_order_id_ok" do
        assert {:ok, %Binance.Futures.Order{} = response} =
                 Binance.Futures.get_order(%{symbol: "BTCUSDT", order_id: 10_926_974})

        assert response.client_order_id == "F1YDd19xJvGWNiBbt7JCrr"
        assert response.cum_quote == "0"
        assert response.executed_qty == "0"
        assert response.order_id == 10_926_974
        assert response.orig_qty == "0.001"
        assert response.price == "11000"
        assert response.reduce_only == false
        assert response.side == "SELL"
        assert response.status == "NEW"
        assert response.stop_price == "0"
        assert response.symbol == "BTCUSDT"
        assert response.time_in_force == "GTC"
        assert response.type == "LIMIT"
        assert response.update_time == 1_568_988_806_336
      end
    end

    test "gets an order information by client order id" do
      use_cassette "futures/get_order_by_client_order_id_ok" do
        assert {:ok, %Binance.Futures.Order{} = response} =
                 Binance.Futures.get_order(%{
                   symbol: "BTCUSDT",
                   orig_client_order_id: "F1YDd11xJvGWNiBbt7JCrr"
                 })

        assert response.client_order_id == "F1YDd19xJvGWNiBbt7JCrr"
        assert response.cum_quote == "0"
        assert response.executed_qty == "0"
        assert response.order_id == 10_926_974
        assert response.orig_qty == "0.001"
        assert response.price == "11000"
        assert response.reduce_only == false
        assert response.side == "SELL"
        assert response.status == "NEW"
        assert response.stop_price == "0"
        assert response.symbol == "BTCUSDT"
        assert response.time_in_force == "GTC"
        assert response.type == "LIMIT"
        assert response.update_time == 1_568_988_806_336
      end
    end

    test "returns an insufficient margin error tuple" do
      use_cassette "futures/get_order_error" do
        assert Binance.Futures.get_order(%{symbol: "BTCUSDT", order_id: 123_456_789}) ==
                 {:error, %{"code" => -2013, "msg" => "Order does not exist."}}
      end
    end
  end
end
