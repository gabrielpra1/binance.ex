defmodule BinanceTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest Binance

  setup_all do
    HTTPoison.start()
  end

  test "ping returns an empty map" do
    use_cassette "ping_ok" do
      assert Binance.ping() == {:ok, %{}}
    end
  end

  test "get_server_time success return an ok, time tuple" do
    use_cassette "get_server_time_ok" do
      assert Binance.get_server_time() == {:ok, 1_521_781_361_467}
    end
  end

  test "get_exchange_info success returns the trading rules and symbol information" do
    use_cassette "get_exchange_info_ok" do
      assert {:ok, %Binance.ExchangeInfo{} = info} = Binance.get_exchange_info()
      assert info.timezone == "UTC"
      assert info.server_time != nil

      assert info.rate_limits == [
               %{"interval" => "MINUTE", "limit" => 1200, "rateLimitType" => "REQUESTS"},
               %{"interval" => "SECOND", "limit" => 10, "rateLimitType" => "ORDERS"},
               %{"interval" => "DAY", "limit" => 100_000, "rateLimitType" => "ORDERS"}
             ]

      assert info.exchange_filters == []
      assert [symbol | _] = info.symbols

      assert symbol == %{
               "baseAsset" => "ETH",
               "baseAssetPrecision" => 8,
               "filters" => [
                 %{
                   "filterType" => "PRICE_FILTER",
                   "maxPrice" => "100000.00000000",
                   "minPrice" => "0.00000100",
                   "tickSize" => "0.00000100"
                 },
                 %{
                   "filterType" => "LOT_SIZE",
                   "maxQty" => "100000.00000000",
                   "minQty" => "0.00100000",
                   "stepSize" => "0.00100000"
                 },
                 %{"filterType" => "MIN_NOTIONAL", "minNotional" => "0.00100000"}
               ],
               "icebergAllowed" => false,
               "orderTypes" => [
                 "LIMIT",
                 "LIMIT_MAKER",
                 "MARKET",
                 "STOP_LOSS_LIMIT",
                 "TAKE_PROFIT_LIMIT"
               ],
               "quoteAsset" => "BTC",
               "quotePrecision" => 8,
               "status" => "TRADING",
               "symbol" => "ETHBTC"
             }
    end
  end

  test "get_all_prices returns a list of prices for every symbol" do
    use_cassette "get_all_prices_ok" do
      assert {:ok, symbol_prices} = Binance.get_all_prices()
      assert [%Binance.SymbolPrice{price: "0.06137000", symbol: "ETHBTC"} | _tail] = symbol_prices
      assert symbol_prices |> Enum.count() == 288
    end
  end

  describe ".get_ticker" do
    test "returns a ticker struct with details for the given symbol" do
      use_cassette "get_ticker_ok" do
        assert {
                 :ok,
                 %Binance.Ticker{
                   ask_price: "0.01876000",
                   bid_price: "0.01875200",
                   close_time: 1_521_826_338_547,
                   count: 30612
                 }
               } = Binance.get_ticker("LTCBTC")
      end
    end

    test "returns an error tuple when the symbol doesn't exist" do
      use_cassette "get_ticker_error" do
        assert Binance.get_ticker("IDONTEXIST") == {
                 :error,
                 %{"code" => -1121, "msg" => "Invalid symbol."}
               }
      end
    end
  end

  describe ".get_depth" do
    test "returns the bids & asks up to the given depth" do
      use_cassette "get_depth_ok" do
        assert Binance.get_depth("BTCUSDT", 5) == {
                 :ok,
                 %Binance.OrderBook{
                   asks: [
                     ["8400.00000000", "2.04078100", []],
                     ["8405.35000000", "0.50354700", []],
                     ["8406.00000000", "0.32769800", []],
                     ["8406.33000000", "0.00239000", []],
                     ["8406.51000000", "0.03241000", []]
                   ],
                   bids: [
                     ["8393.00000000", "0.20453200", []],
                     ["8392.57000000", "0.02639000", []],
                     ["8392.00000000", "1.40893300", []],
                     ["8390.09000000", "0.07047100", []],
                     ["8388.72000000", "0.04577400", []]
                   ],
                   last_update_id: 113_634_395
                 }
               }
      end
    end

    test "returns an error tuple when the symbol doesn't exist" do
      use_cassette "get_depth_error" do
        assert Binance.get_depth("IDONTEXIST", 1000) == {
                 :error,
                 %{"code" => -1121, "msg" => "Invalid symbol."}
               }
      end
    end
  end

  describe ".order_limit_buy" do
    test "creates an order with a duration of good til cancel by default" do
      use_cassette "order_limit_buy_good_til_cancel_default_duration_success" do
        assert {:ok, %Binance.OrderResponse{} = response} =
                 Binance.order_limit_buy("LTCBTC", 0.1, 0.01)

        assert response.client_order_id == "9kITBshSwrClye1HJcLM3j"
        assert response.executed_qty == "0.00000000"
        assert response.order_id == 47_511_548
        assert response.orig_qty == "0.10000000"
        assert response.price == "0.01000000"
        assert response.side == "BUY"
        assert response.status == "NEW"
        assert response.symbol == "LTCBTC"
        assert response.time_in_force == "GTC"
        assert response.transact_time == 1_527_278_150_709
        assert response.type == "LIMIT"
      end
    end

    test "can create an order with a fill or kill duration" do
      use_cassette "order_limit_buy_fill_or_kill_success" do
        assert {:ok, %Binance.OrderResponse{} = response} =
                 Binance.order_limit_buy("LTCBTC", 0.1, 0.01, "FOK")

        assert response.client_order_id == "dY67P33S4IxPnJGx5EtuSf"
        assert response.executed_qty == "0.00000000"
        assert response.order_id == 47_527_179
        assert response.orig_qty == "0.10000000"
        assert response.price == "0.01000000"
        assert response.side == "BUY"
        assert response.status == "EXPIRED"
        assert response.symbol == "LTCBTC"
        assert response.time_in_force == "FOK"
        assert response.transact_time == 1_527_290_557_607
        assert response.type == "LIMIT"
      end
    end

    test "can create an order with am immediate or cancel duration" do
      use_cassette "order_limit_buy_immediate_or_cancel_success" do
        assert {:ok, %Binance.OrderResponse{} = response} =
                 Binance.order_limit_buy("LTCBTC", 0.1, 0.01, "IOC")

        assert response.client_order_id == "zyMyhtRENlvFHrl4CitDe0"
        assert response.executed_qty == "0.00000000"
        assert response.order_id == 47_528_830
        assert response.orig_qty == "0.10000000"
        assert response.price == "0.01000000"
        assert response.side == "BUY"
        assert response.status == "EXPIRED"
        assert response.symbol == "LTCBTC"
        assert response.time_in_force == "IOC"
        assert response.transact_time == 1_527_291_300_912
        assert response.type == "LIMIT"
      end
    end

    test "returns an insufficient balance error tuple" do
      use_cassette "order_limit_buy_error_insufficient_balance" do
        assert {:error, reason} = Binance.order_limit_buy("LTCBTC", 10_000, 0.001, "FOK")

        assert reason == %Binance.InsufficientBalanceError{
                 reason: %{
                   code: -2010,
                   msg: "Account has insufficient balance for requested action."
                 }
               }
      end
    end
  end

  describe ".order_limit_sell" do
    test "creates an order with a duration of good til cancel by default" do
      use_cassette "order_limit_sell_good_til_cancel_default_duration_success" do
        assert {:ok, %Binance.OrderResponse{} = response} =
                 Binance.order_limit_sell("BTCUSDT", 0.001, 50_000)

        assert response.client_order_id == "9UFMPloZsQ3eshCx66PVqD"
        assert response.executed_qty == "0.00000000"
        assert response.order_id == 108_212_133
        assert response.orig_qty == "0.00100000"
        assert response.price == "50000.00000000"
        assert response.side == "SELL"
        assert response.status == "NEW"
        assert response.symbol == "BTCUSDT"
        assert response.time_in_force == "GTC"
        assert response.transact_time == 1_527_279_796_770
        assert response.type == "LIMIT"
      end
    end

    test "can create an order with a fill or kill duration" do
      use_cassette "order_limit_sell_fill_or_kill_success" do
        assert {:ok, %Binance.OrderResponse{} = response} =
                 Binance.order_limit_sell("BTCUSDT", 0.001, 50_000, "FOK")

        assert response.client_order_id == "lKYECwEPSTPzurwx6emuN2"
        assert response.executed_qty == "0.00000000"
        assert response.order_id == 108_277_184
        assert response.orig_qty == "0.00100000"
        assert response.price == "50000.00000000"
        assert response.side == "SELL"
        assert response.status == "EXPIRED"
        assert response.symbol == "BTCUSDT"
        assert response.time_in_force == "FOK"
        assert response.transact_time == 1_527_290_985_305
        assert response.type == "LIMIT"
      end
    end

    test "can create an order with am immediate or cancel duration" do
      use_cassette "order_limit_sell_immediate_or_cancel_success" do
        assert {:ok, %Binance.OrderResponse{} = response} =
                 Binance.order_limit_sell("BTCUSDT", 0.001, 50_000, "IOC")

        assert response.client_order_id == "roSkLhwX9KCgYqr4yFPx1V"
        assert response.executed_qty == "0.00000000"
        assert response.order_id == 108_279_070
        assert response.orig_qty == "0.00100000"
        assert response.price == "50000.00000000"
        assert response.side == "SELL"
        assert response.status == "EXPIRED"
        assert response.symbol == "BTCUSDT"
        assert response.time_in_force == "IOC"
        assert response.transact_time == 1_527_291_411_088
        assert response.type == "LIMIT"
      end
    end
  end

  describe "withdraw" do
    test "can't make withdraw if doesn't have permission" do
      use_cassette "withdraw_fail_no_permission" do
        assert {:error, {:binance_error, "You don't have permission."}} ==
                 Binance.withdraw("BTC", "address", 0.000001)
      end
    end

    test "can't make withdraw if doesn't have enough" do
      use_cassette "withdraw_fail_not_enough" do
        assert {:error, {:binance_error, "Minimum withdrawal amount not met."}} ==
                 Binance.withdraw("BTC", "address", 0.000001)
      end
    end

    test "withdraw with custom keys" do
      use_cassette "withdraw_fail_wrong_key" do
        assert {:error, {:binance_error, "API key does not exist"}} ==
                 Binance.withdraw("api_key", "secret_key", "BTC", "address", 0.000001)
      end
    end

    test "can make a withdraw" do
      use_cassette "withdraw_success" do
        #assert {:error, {:binance_error, "Minimum withdrawal amount not met."}} == Binance.withdraw("ETH", "0xa2b7a84477b401549faa7f646d64b48e61eaed5b", 0.001)
      end
    end

    test "get withdraw history" do
      use_cassette "withdraw_history" do
        assert {:ok,
          %{
            "withdrawList" => [
              %{"address" => "0x1e79a1C5b9795a2AD7B029A5071cdbc1a4DB257e", "addressTag" => "", "amount" => 0.2897, "applyTime" => 1553708864000, "asset" => "ETH", "id" => "f60ddde4295c4b6fb73bfd291ae68383", "status" => 6, "successTime" => 1553709884000, "txId" => "0xe47fc4de1e43a2538a502c2397440df84160570e25ac6c7fb763d8dc736e06c6"},
              %{"address" => "0x1e79a1C5b9795a2AD7B029A5071cdbc1a4DB257e", "addressTag" => "", "amount" => 0.2897, "applyTime" => 1553706652000, "asset" => "ETH", "id" => "e1b6d09c6d294dd1b011af00481a9a38", "status" => 1, "successTime" => 1553708497000},
              %{"address" => "0x1e79a1C5b9795a2AD7B029A5071cdbc1a4DB257e", "addressTag" => "", "amount" => 0.2897, "applyTime" => 1553695416000, "asset" => "ETH", "id" => "161f1340c8e14ba5a128576a53d25378", "status" => 1, "successTime" => 1553697337000}
            ],
            "success" => true
          }} == Binance.get_withdraw_history("api_key", "secret_key", %{})
      end
    end
  end

  describe "deposits" do
    test "can get deposit address" do
      use_cassette "get_deposit_address_success" do
        assert {:ok,
                %{
                  "address" => "0xa2b7a84477b401549faa7f646d64b48e61eaed5b",
                  "asset" => "ETH",
                  "addressTag" => "",
                  "success" => true
                }} == Binance.get_deposit_address("ETH")
      end
    end

    test "get deposit history" do
      use_cassette "deposit_history" do
        assert {:ok,
          %{
            "depositList" => [
              %{"addressTag" => "", "address" => "1HiifV4ofJQmtqmHQBhheNwfe2JeJbtxMr", "amount" => 0.36272882, "asset" => "BTC", "status" => 1, "txId" => "2a995e1d8ad4c8512eed52d31e8a063fdc3f6d81bd2d6e4b2322f21529f28da0", "insertTime" => 1556114796000},
              %{"addressTag" => "", "status" => 1, "address" => "1HiifV4ofJQmtqmHQBhheNwfe2JeJbtxMr", "amount" => 0.12, "asset" => "BTC", "insertTime" => 1554418244000, "txId" => "3adc2a340eb90dfa34d8efe0a2f86c9a7c2c7b14a353761f5933f7a7f09341c5"},
              %{"addressTag" => "", "status" => 1, "address" => "1HiifV4ofJQmtqmHQBhheNwfe2JeJbtxMr", "amount" => 1.10552355, "asset" => "BTC", "insertTime" => 1554238157000, "txId" => "7dc9a6fe43626bff9d7d73328fdfe0ed5248be42f7c48642833c03ac963cb868"},
              %{"address" => "1HiifV4ofJQmtqmHQBhheNwfe2JeJbtxMr", "addressTag" => "", "amount" => 0.8735, "asset" => "BTC", "insertTime" => 1553711201000, "status" => 1, "txId" => "4b517de9e75eb36775354a98ce56ccf33b62cc1cffe4a5e0bbe16b58efdf9e82"},
              %{"address" => "1HiifV4ofJQmtqmHQBhheNwfe2JeJbtxMr", "addressTag" => "", "amount" => 0.105715, "asset" => "BTC", "insertTime" => 1553616725000, "status" => 1, "txId" => "b6ecfa7778d5c003abebab249742e7c754bc3886d70059a2df42a419d1f36b79"},
              %{"address" => "0x99d66472969fdc8dea1b87267fbedfdb5beabeb0", "addressTag" => "", "amount" => 0.2897, "asset" => "ETH", "insertTime" => 1548260977000, "status" => 1, "txId" => "0x3fcf514ffe3925598699de7c2ac617cdf354e6f168f320dfbc80ff1e3dcca034"}
            ],
            "success" => true
          }} == Binance.get_deposit_history("api_key", "secret_key", %{})
      end
    end
  end
end
