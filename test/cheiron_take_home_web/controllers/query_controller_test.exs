defmodule CheironTakeHomeWeb.QueryControllerTest do
  use CheironTakeHomeWeb.ConnCase, async: true

  import Mox

  setup :verify_on_exit!

  describe "POST /api/query" do
    test "returns viz spec on success", %{conn: conn} do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        assert opts[:url] == "https://api.openai.com/v1/chat/completions"

        {:ok,
         %{
           status: 200,
           body: %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     Jason.encode!(%{
                       "viz_type" => "bar_chart",
                       "query_params" => %{"query_cond" => "diabetes"},
                       "group_by" => "phase"
                     })
                 }
               }
             ]
           }
         }}
      end)
      |> expect(:request, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{
                 "protocolSection" => %{
                   "identificationModule" => %{"nctId" => "NCT00000001"},
                   "designModule" => %{"phases" => ["PHASE2"]},
                   "statusModule" => %{"overallStatus" => "COMPLETED"}
                 }
               }
             ]
           }
         }}
      end)

      conn = post(conn, ~p"/api/query", %{"query" => "diabetes trials by phase"})
      resp = json_response(conn, 200)

      assert %{"visualization" => viz} = resp
      assert viz["type"] == "bar_chart"
      assert is_list(viz["data"])
    end

    test "returns 400 on missing query", %{conn: conn} do
      conn = post(conn, ~p"/api/query", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 on empty query", %{conn: conn} do
      conn = post(conn, ~p"/api/query", %{"query" => ""})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 422 when upstream fails", %{conn: conn} do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:error, %{reason: :timeout}}
      end)

      conn = post(conn, ~p"/api/query", %{"query" => "anything"})
      assert %{"error" => _} = json_response(conn, 422)
    end

    test "passes structured fields through to the pipeline", %{conn: conn} do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "choices" => [
               %{
                 "message" => %{
                   "content" =>
                     Jason.encode!(%{
                       "viz_type" => "bar_chart",
                       "query_params" => %{"query_cond" => "cancer"},
                       "group_by" => "phase"
                     })
                 }
               }
             ]
           }
         }}
      end)
      |> expect(:request, fn opts ->
        params = opts[:params]
        assert params["query.intr"] == "Pembrolizumab"

        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{
                 "protocolSection" => %{
                   "designModule" => %{"phases" => ["PHASE3"]},
                   "statusModule" => %{"overallStatus" => "RECRUITING"}
                 }
               }
             ]
           }
         }}
      end)

      conn =
        post(conn, ~p"/api/query", %{
          "query" => "trials by phase",
          "drug_name" => "Pembrolizumab"
        })

      resp = json_response(conn, 200)
      assert %{"visualization" => _} = resp
    end

    test "returns 400 for invalid start_year", %{conn: conn} do
      conn =
        post(conn, ~p"/api/query", %{
          "query" => "trials over time",
          "start_year" => "banana"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
