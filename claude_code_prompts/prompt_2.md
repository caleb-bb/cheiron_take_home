# Claude Code Prompt: Failing Tests for API Wrappers

## Context
The Phoenix project `cheiron_take_home` exists with module stubs for `CheironTakeHome.LLM`, `CheironTakeHome.ClinicalTrials`, `CheironTakeHome.Munger`, and `CheironTakeHome.Orchestrator`. All are empty `defmodule` blocks. Mox and StreamData are in deps.

This project builds an AI agent that takes natural language questions about clinical trials, calls the ClinicalTrials.gov API, and returns structured visualization specs. The LLM wrapper interprets user queries. The ClinicalTrials wrapper fetches data. Tests must be written FIRST and must FAIL.

## Task: Write failing tests for the two API wrapper modules.

### Step 0: Assess
Read this entire prompt. Confirm you understand by listing your steps. Do not begin until you've confirmed.

### Step 1: Configure Mox for the HTTP layer

We mock at the HTTP transport level, not at the wrapper level. Both wrappers use Req internally to make HTTP calls. We make the Req client configurable so tests can inject a mock.

Create `lib/cheiron_take_home/http_client.ex`:
```elixir
defmodule CheironTakeHome.HttpClient do
  @moduledoc "Behaviour for HTTP calls. Exists solely so Mox can mock it."

  @callback request(keyword()) :: {:ok, map()} | {:error, term()}
end
```

In `test/test_helper.exs`, add after `ExUnit.start()`:
```elixir
Mox.defmock(CheironTakeHome.MockHttpClient, for: CheironTakeHome.HttpClient)
```

In `config/test.exs`, add:
```elixir
config :cheiron_take_home, :http_client, CheironTakeHome.MockHttpClient
```

### Step 2: Write failing tests for CheironTakeHome.LLM

File: `test/cheiron_take_home/llm_test.exs`

The LLM wrapper will have a function `interpret/1` that takes a user query string and returns `{:ok, query_plan}` where `query_plan` is a map with at least `:viz_type` and `:query_params`. It calls OpenAI's chat completions endpoint internally.

Write these tests. They MUST fail because `interpret/1` doesn't exist yet.

```elixir
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
```

### Step 3: Write failing tests for CheironTakeHome.ClinicalTrials

File: `test/cheiron_take_home/clinical_trials_test.exs`

The ClinicalTrials wrapper will have a function `search/1` that takes a map of params and returns `{:ok, studies}` where `studies` is a list of maps. The base URL is `https://clinicaltrials.gov/api/v2/studies`. It can be hardcoded.

Write these tests. They MUST fail because `search/1` doesn't exist yet.

```elixir
defmodule CheironTakeHome.ClinicalTrialsTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "search/1" do
    test "sends correct query params for a condition search" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        assert opts[:url] == "https://clinicaltrials.gov/api/v2/studies"
        assert opts[:method] == :get
        assert opts[:params]["query.cond"] == "diabetes"
        assert opts[:params]["pageSize"] == 100
        assert opts[:params]["format"] == "json"

        {:ok, %{
          status: 200,
          body: %{
            "totalCount" => 1,
            "studies" => [
              %{
                "protocolSection" => %{
                  "identificationModule" => %{"nctId" => "NCT00000001", "briefTitle" => "Test Trial"},
                  "statusModule" => %{"overallStatus" => "COMPLETED"},
                  "designModule" => %{"phases" => ["PHASE3"]}
                }
              }
            ]
          }
        }}
      end)

      params = %{query_cond: "diabetes", page_size: 100}
      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(params)
      assert is_list(studies)
      assert length(studies) == 1
    end

    test "sends correct query params for an intervention search" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        assert opts[:params]["query.intr"] == "Pembrolizumab"

        {:ok, %{
          status: 200,
          body: %{
            "totalCount" => 2,
            "studies" => [
              %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT00000002"}}},
              %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT00000003"}}}
            ]
          }
        }}
      end)

      params = %{query_intr: "Pembrolizumab"}
      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(params)
      assert length(studies) == 2
    end

    test "returns error on API failure" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:error, %{reason: :timeout}}
      end)

      assert {:error, _reason} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "anything"})
    end
  end
end
```

### Step 4: Verify tests FAIL
Run `mix test`. All six new tests must FAIL. The failures should be because `interpret/1` and `search/1` are not defined on their respective modules. If any test passes, something is wrong — report it.

### Step 5: Stage only
```bash
git add -A
```

Do NOT commit. Do NOT run `git commit`.

### HARD STOP
Do NOT implement any functions. Do NOT make the tests pass. Do NOT modify the stub modules. Report what you did, including the test failure output, and stop.

