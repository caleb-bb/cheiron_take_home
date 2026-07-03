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

        {:ok,
         %{
           status: 200,
           body: %{
             "totalCount" => 3,
             "studies" => [
               %{
                 "protocolSection" => %{
                   "identificationModule" => %{
                     "nctId" => "NCT00000001",
                     "briefTitle" => "Trial A"
                   },
                   "designModule" => %{"phases" => ["PHASE2"]},
                   "statusModule" => %{
                     "overallStatus" => "COMPLETED",
                     "startDateStruct" => %{"date" => "2020-01-15", "type" => "ACTUAL"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "identificationModule" => %{
                     "nctId" => "NCT00000002",
                     "briefTitle" => "Trial B"
                   },
                   "designModule" => %{"phases" => ["PHASE3"]},
                   "statusModule" => %{
                     "overallStatus" => "RECRUITING",
                     "startDateStruct" => %{"date" => "2021-06-01", "type" => "ACTUAL"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "identificationModule" => %{
                     "nctId" => "NCT00000003",
                     "briefTitle" => "Trial C"
                   },
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

      assert {:ok, viz_spec} =
               CheironTakeHome.Orchestrator.query(
                 "How many lung cancer trials are there by phase?"
               )

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
        # ClinicalTrials fails
        {:error, %{reason: :timeout}}
      end)

      assert {:error, _reason} = CheironTakeHome.Orchestrator.query("diabetes trials by phase")
    end

    test "full pipeline: network_graph viz type" do
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
                       "viz_type" => "network_graph",
                       "query_params" => %{"query_cond" => "lung cancer"},
                       "edge_type" => "condition_to_intervention"
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
                   "conditionsModule" => %{"conditions" => ["Lung Cancer"]},
                   "armsInterventionsModule" => %{
                     "interventions" => [
                       %{"name" => "Pembrolizumab", "type" => "DRUG"},
                       %{"name" => "Radiation", "type" => "RADIATION"}
                     ]
                   },
                   "sponsorCollaboratorsModule" => %{
                     "leadSponsor" => %{"name" => "NIH"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "conditionsModule" => %{"conditions" => ["Lung Cancer", "NSCLC"]},
                   "armsInterventionsModule" => %{
                     "interventions" => [
                       %{"name" => "Pembrolizumab", "type" => "DRUG"}
                     ]
                   },
                   "sponsorCollaboratorsModule" => %{
                     "leadSponsor" => %{"name" => "Pfizer"}
                   }
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, viz_spec} =
               CheironTakeHome.Orchestrator.query("What drugs are used to treat lung cancer?")

      assert viz_spec.type == "network_graph"
      assert is_list(viz_spec.data)
      assert length(viz_spec.data) > 0

      sources = Enum.map(viz_spec.data, & &1["source"])
      assert "Lung Cancer" in sources

      targets = Enum.map(viz_spec.data, & &1["target"])
      assert "Pembrolizumab" in targets
    end

    test "returns error when LLM produces no recognized search terms" do
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
                       "query_params" => %{"condition" => "cervical cancer"},
                       "group_by" => "phase"
                     })
                 }
               }
             ]
           }
         }}
      end)

      assert {:error, :no_search_terms} =
               CheironTakeHome.Orchestrator.query("cervical cancer trials")
    end

    test "returns error on empty query" do
      assert {:error, _reason} = CheironTakeHome.Orchestrator.query("")
    end
  end

  describe "query/2 with structured fields" do
    test "structured condition overrides LLM-inferred query_cond" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        # LLM returns query_cond "cancer" (generic)
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
        # The ClinicalTrials API should receive the user's specific condition, not the LLM's
        params = opts[:params]
        assert params["query.cond"] == "lung cancer"

        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{
                 "protocolSection" => %{
                   "designModule" => %{"phases" => ["PHASE2"]},
                   "statusModule" => %{"overallStatus" => "COMPLETED"}
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, _viz_spec} =
               CheironTakeHome.Orchestrator.query("trials by phase", %{
                 "condition" => "lung cancer"
               })
    end

    test "structured drug_name maps to query_intr" do
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

      assert {:ok, _viz_spec} =
               CheironTakeHome.Orchestrator.query("trials by phase", %{
                 "drug_name" => "Pembrolizumab"
               })
    end

    test "structured fields rescue LLM returning no valid search keys" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        # LLM returns garbage keys (no query_cond/query_intr/query_term)
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
                       "query_params" => %{"condition" => "cervical cancer"},
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
        assert params["query.cond"] == "cervical cancer"

        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{
                 "protocolSection" => %{
                   "designModule" => %{"phases" => ["PHASE1"]},
                   "statusModule" => %{"overallStatus" => "COMPLETED"}
                 }
               }
             ]
           }
         }}
      end)

      # Without structured fields this would fail with :no_search_terms
      assert {:ok, _viz_spec} =
               CheironTakeHome.Orchestrator.query("cervical cancer trials", %{
                 "condition" => "cervical cancer"
               })
    end

    test "structured trial_phase maps to filter_phase" do
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
                       "query_params" => %{"query_cond" => "diabetes"},
                       "group_by" => "status"
                     })
                 }
               }
             ]
           }
         }}
      end)
      |> expect(:request, fn opts ->
        params = opts[:params]
        assert params["filter.advanced"] == "AREA[Phase]PHASE3"

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

      assert {:ok, _viz_spec} =
               CheironTakeHome.Orchestrator.query("diabetes trial status", %{
                 "trial_phase" => "PHASE3"
               })
    end

    test "structured start_year filters out older studies" do
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
                       "viz_type" => "time_series",
                       "query_params" => %{"query_cond" => "diabetes"},
                       "time_granularity" => "year"
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
                   "statusModule" => %{
                     "startDateStruct" => %{"date" => "2018-03-01", "type" => "ACTUAL"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "statusModule" => %{
                     "startDateStruct" => %{"date" => "2020-06-15", "type" => "ACTUAL"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "statusModule" => %{
                     "startDateStruct" => %{"date" => "2022-01-10", "type" => "ACTUAL"}
                   }
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, viz_spec} =
               CheironTakeHome.Orchestrator.query("diabetes trials over time", %{
                 "start_year" => 2020
               })

      periods = Enum.map(viz_spec.data, & &1["period"])
      refute "2018" in periods
      assert "2020" in periods
      assert "2022" in periods
    end

    test "structured end_year filters out newer studies" do
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
                       "viz_type" => "time_series",
                       "query_params" => %{"query_cond" => "diabetes"},
                       "time_granularity" => "year"
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
                   "statusModule" => %{
                     "startDateStruct" => %{"date" => "2018-03-01", "type" => "ACTUAL"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "statusModule" => %{
                     "startDateStruct" => %{"date" => "2020-06-15", "type" => "ACTUAL"}
                   }
                 }
               },
               %{
                 "protocolSection" => %{
                   "statusModule" => %{
                     "startDateStruct" => %{"date" => "2022-01-10", "type" => "ACTUAL"}
                   }
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, viz_spec} =
               CheironTakeHome.Orchestrator.query("diabetes trials over time", %{
                 "end_year" => 2020
               })

      periods = Enum.map(viz_spec.data, & &1["period"])
      assert "2018" in periods
      assert "2020" in periods
      refute "2022" in periods
    end

    test "query/1 still works without structured fields" do
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
                       "query_params" => %{"query_cond" => "asthma"},
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
                   "designModule" => %{"phases" => ["PHASE2"]},
                   "statusModule" => %{"overallStatus" => "COMPLETED"}
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, viz_spec} = CheironTakeHome.Orchestrator.query("asthma trials by phase")
      assert viz_spec.type == "bar_chart"
    end
  end

  describe "query/2 ignores LLM page_size" do
    test "LLM-supplied page_size is dropped from API params" do
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
                       "query_params" => %{
                         "query_cond" => "diabetes",
                         "page_size" => 5
                       },
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

        refute Map.has_key?(params, "pageSize"),
               "LLM-supplied page_size should not reach the API"

        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{
                 "protocolSection" => %{
                   "designModule" => %{"phases" => ["PHASE2"]},
                   "statusModule" => %{"overallStatus" => "COMPLETED"}
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, _viz_spec} = CheironTakeHome.Orchestrator.query("diabetes trials by phase")
    end
  end

  describe "query/2 with scatter_plot" do
    test "scatter_plot viz_type flows through the pipeline" do
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
                       "viz_type" => "scatter_plot",
                       "query_params" => %{"query_cond" => "cancer"},
                       "color_by" => "phase"
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
                   "identificationModule" => %{
                     "nctId" => "NCT001",
                     "briefTitle" => "Test Trial"
                   },
                   "designModule" => %{
                     "phases" => ["PHASE3"],
                     "enrollmentInfo" => %{"count" => 200, "type" => "ACTUAL"}
                   },
                   "statusModule" => %{
                     "overallStatus" => "COMPLETED",
                     "startDateStruct" => %{"date" => "2024-01-15"}
                   }
                 }
               }
             ]
           }
         }}
      end)

      assert {:ok, viz_spec} =
               CheironTakeHome.Orchestrator.query("show individual cancer trial sizes")

      assert viz_spec.type == "scatter_plot"
    end
  end
end
