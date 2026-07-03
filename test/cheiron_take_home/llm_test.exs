defmodule CheironTakeHome.LLMTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "interpret/1" do
    test "returns a query plan with viz_type and query_params for a condition query" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        # Assert it's calling the OpenAI endpoint
        assert opts[:url] == "https://api.openai.com/v1/chat/completions"
        assert opts[:method] == :post

        {:ok, %{
          status: 200,
          body: %{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(%{
                    "viz_type" => "bar_chart",
                    "query_params" => %{
                      "query_cond" => "lung cancer",
                      "filter_phase" => nil
                    },
                    "group_by" => "phase"
                  })
                }
              }
            ]
          }
        }}
      end)

      assert {:ok, query_plan} = CheironTakeHome.LLM.interpret("How many lung cancer trials are there by phase?")
      assert query_plan.viz_type == "bar_chart"
      assert query_plan.query_params["query_cond"] == "lung cancer"
    end

    test "returns a query plan with time_series for a temporal query" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok, %{
          status: 200,
          body: %{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(%{
                    "viz_type" => "time_series",
                    "query_params" => %{
                      "query_intr" => "Pembrolizumab"
                    },
                    "time_granularity" => "year"
                  })
                }
              }
            ]
          }
        }}
      end)

      assert {:ok, query_plan} = CheironTakeHome.LLM.interpret("How has the number of Pembrolizumab trials changed over time?")
      assert query_plan.viz_type == "time_series"
      assert query_plan.query_params["query_intr"] == "Pembrolizumab"
    end

    test "returns error on API failure" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:error, %{reason: :timeout}}
      end)

      assert {:error, _reason} = CheironTakeHome.LLM.interpret("anything")
    end
  end
end
