defmodule CheironTakeHome.OrchestratorTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "query/1" do
    test "full pipeline: user query → LLM → ClinicalTrials API → viz_spec" do
      # First HTTP call: LLM interprets the query
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        assert opts[:url] == "https://api.openai.com/v1/chat/completions"

        {:ok, %{
          status: 200,
          body: %{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(%{
                    "viz_type" => "bar_chart",
                    "query_params" => %{
                      "query_cond" => "lung cancer"
                    },
                    "group_by" => "phase"
                  })
                }
              }
            ]
          }
        }}
      end)

      # Second HTTP call: ClinicalTrials.gov search
      |> expect(:request, fn opts ->
        assert opts[:url] == "https://clinicaltrials.gov/api/v2/studies"

        {:ok, %{
          status: 200,
          body: %{
            "totalCount" => 3,
            "studies" => [
              %{
                "protocolSection" => %{
                  "identificationModule" => %{"nctId" => "NCT00000001", "briefTitle" => "Trial A"},
                  "designModule" => %{"phases" => ["PHASE2"]},
                  "statusModule" => %{
                    "overallStatus" => "COMPLETED",
                    "startDateStruct" => %{"date" => "2020-01-15", "type" => "ACTUAL"}
                  }
                }
              },
              %{
                "protocolSection" => %{
                  "identificationModule" => %{"nctId" => "NCT00000002", "briefTitle" => "Trial B"},
                  "designModule" => %{"phases" => ["PHASE3"]},
                  "statusModule" => %{
                    "overallStatus" => "RECRUITING",
                    "startDateStruct" => %{"date" => "2021-06-01", "type" => "ACTUAL"}
                  }
                }
              },
              %{
                "protocolSection" => %{
                  "identificationModule" => %{"nctId" => "NCT00000003", "briefTitle" => "Trial C"},
                  "designModule" => %{"phases" => ["PHASE2"]},
                  "statusModule" => %{
                    "overallStatus" => "COMPLETED",
                    "startDateStruct" => %{"date" => "2020-08-20", "type" => "ACTUAL"}
                  }
                }
              }
            ]
          }
        }}
      end)

      assert {:ok, viz_spec} = CheironTakeHome.Orchestrator.query("How many lung cancer trials are there by phase?")

      # Verify the output is a valid viz_spec
      assert viz_spec.type == "bar_chart"
      assert is_binary(viz_spec.title)
      assert is_map(viz_spec.encoding)
      assert is_list(viz_spec.data)
      assert length(viz_spec.data) > 0

      # Verify data is traceable to input
      phases = Enum.map(viz_spec.data, & &1["phase"])
      assert "PHASE2" in phases
      assert "PHASE3" in phases
    end

    test "returns error when LLM fails" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:error, %{reason: :timeout}}
      end)

      assert {:error, _reason} = CheironTakeHome.Orchestrator.query("anything")
    end

    test "returns error when ClinicalTrials API fails" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        # LLM succeeds
        {:ok, %{
          status: 200,
          body: %{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(%{
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
        # ClinicalTrials fails
        {:error, %{reason: :timeout}}
      end)

      assert {:error, _reason} = CheironTakeHome.Orchestrator.query("diabetes trials by phase")
    end

    test "returns error on empty query" do
      assert {:error, _reason} = CheironTakeHome.Orchestrator.query("")
    end
  end
end
