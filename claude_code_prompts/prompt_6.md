# Claude Code Prompt: Implement Munger, Write Orchestrator Smoke Tests, Implement Orchestrator

## Context
The project `cheiron_take_home` has:
- Working `CheironTakeHome.LLM` module with passing tests (mocks HTTP via `CheironTakeHome.MockHttpClient`)
- Working `CheironTakeHome.ClinicalTrials` module with passing tests (same mock pattern)
- `CheironTakeHome.Munger` stub with FAILING property tests in `test/cheiron_take_home/munger_test.exs`
- `CheironTakeHome.Orchestrator` stub with no tests
- `CheironTakeHome.HttpClient` behaviour and `CheironTakeHome.MockHttpClient` Mox mock already configured

The orchestrator's job: validate input → call LLM → destructure query plan → call ClinicalTrials → call Munger → return viz_spec.

The HTTP client is injectable via `Application.get_env(:cheiron_take_home, :http_client)`. The LLM and ClinicalTrials modules already use this pattern internally.

## Task: Three steps. Implement the munger, write orchestrator smoke tests, implement the orchestrator.

### Step 0: Assess
Read ALL of the following files before starting:
- `lib/cheiron_take_home/munger.ex`
- `test/cheiron_take_home/munger_test.exs` (read carefully — this defines the munger's contract)
- `lib/cheiron_take_home/orchestrator.ex`
- `lib/cheiron_take_home/llm.ex`
- `lib/cheiron_take_home/clinical_trials.ex`
- `lib/cheiron_take_home/http_client.ex`
- `test/test_helper.exs`
- `config/test.exs`

Confirm you understand the full architecture by listing your steps. Do not begin until you've confirmed.

## PART 1: Implement the Munger

### Step 1: Implement `CheironTakeHome.Munger.build/2`

Read `test/cheiron_take_home/munger_test.exs` thoroughly. The property tests define the exact contract. The munger must:

**Public API:** `build(studies, viz_intent)` returns `{:ok, viz_spec}`.

`viz_intent` is a map with at minimum `:viz_type` (`:bar_chart` or `:time_series`).

**For `:bar_chart` with `group_by: "phase"`:**
- Count studies per phase by extracting `protocolSection.designModule.phases` from each study
- A study with `["PHASE1", "PHASE2"]` counts once in each bucket
- Return a map shaped like:

```elixir
%{
  type: "bar_chart",
  title: "Clinical Trials by Phase",
  encoding: %{
    x: %{field: "phase", label: "Trial Phase", type: "categorical"},
    y: %{field: "trial_count", label: "Number of Trials", type: "quantitative"}
  },
  sort: %{field: "phase", order: "ordinal", sequence: ["EARLY_PHASE1", "PHASE1", "PHASE2", "PHASE3", "PHASE4", "NA"]},
  data: [%{"phase" => "PHASE1", "trial_count" => 12}, ...],
  meta: %{source: "clinicaltrials.gov", total_studies: 42}
}
```

**For `:time_series` with `time_granularity: :year`:**
- Bucket studies by start year from `protocolSection.statusModule.startDateStruct.date`
- Skip studies with nil or empty dates
- Data must be sorted chronologically
- Return a map shaped like:

```elixir
%{
  type: "time_series",
  title: "Clinical Trials Over Time",
  encoding: %{
    x: %{field: "period", label: "Year", type: "temporal", granularity: "year"},
    y: %{field: "count", label: "Number of Trials Started", type: "quantitative"}
  },
  data: [%{"period" => "2020", "count" => 5}, ...],
  meta: %{source: "clinicaltrials.gov", total_studies: 30, date_field: "startDateStruct"}
}
```

### Step 2: Run munger tests
Run `mix test test/cheiron_take_home/munger_test.exs`. ALL property tests must PASS. If any fail, fix the implementation until they pass. Do not modify the tests.

## PART 2: Write Orchestrator Smoke Tests

### Step 3: Write `test/cheiron_take_home/orchestrator_test.exs`

These are integration-level smoke tests. They mock at the HTTP layer (using `CheironTakeHome.MockHttpClient`) and let the real LLM, ClinicalTrials, and Munger modules run.

The orchestrator's public API is `CheironTakeHome.Orchestrator.query/1` which takes a user query string and returns `{:ok, viz_spec}` or `{:error, reason}`.

The mock setup needs to handle TWO sequential HTTP calls within a single test: first the LLM call (POST to OpenAI), then the ClinicalTrials call (GET to clinicaltrials.gov). Use `Mox.expect` twice in sequence.

```elixir
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
```

### Step 4: Verify orchestrator tests FAIL
Run `mix test test/cheiron_take_home/orchestrator_test.exs`. Tests must fail because `Orchestrator.query/1` does not exist. Confirm this before proceeding.

## PART 3: Implement the Orchestrator

### Step 5: Implement `CheironTakeHome.Orchestrator.query/1`

The orchestrator must:

1. Validate the input is a non-empty string. Return `{:error, :empty_query}` if not.
2. Call `LLM.interpret/1` to get a query plan.
3. Split the query plan into API params and viz intent. The query plan from the LLM is a map with `"viz_type"`, `"query_params"`, and optionally `"group_by"` and `"time_granularity"`.
4. Call `ClinicalTrials.search/1` with the API params.
5. Call `Munger.build/2` with the raw studies and the viz intent.
6. Return the viz_spec.

Use a `with` chain:

```elixir
def query(query_string) when is_binary(query_string) and query_string != "" do
  with {:ok, query_plan} <- CheironTakeHome.LLM.interpret(query_string),
       {api_params, viz_intent} <- split_query_plan(query_plan),
       {:ok, studies} <- CheironTakeHome.ClinicalTrials.search(api_params),
       {:ok, viz_spec} <- CheironTakeHome.Munger.build(studies, viz_intent) do
    {:ok, viz_spec}
  end
end

def query(""), do: {:error, :empty_query}
def query(nil), do: {:error, :empty_query}
```

The private `split_query_plan/1` function extracts:
- `api_params`: a map with keys like `query_cond`, `query_intr`, etc. — matching what `ClinicalTrials.search/1` expects. These come from the `"query_params"` key of the LLM output.
- `viz_intent`: a map with `:viz_type` (converted to atom), and optionally `:group_by`, `:time_granularity` (converted to atom if present). These come from the top-level keys of the LLM output.

It must return a plain tuple `{api_params, viz_intent}` (not an ok tuple) so the `with` chain treats it as a match, not a conditional.

**IMPORTANT:** Read the existing LLM and ClinicalTrials modules to understand what shapes they return and accept. The orchestrator must bridge those shapes. Do not assume — read the code.

### Step 6: Run ALL tests
Run `mix test`. Every test in the project must pass:
- LLM wrapper tests
- ClinicalTrials wrapper tests
- Munger property tests
- Orchestrator smoke tests

If any test fails, fix the implementation (not the tests) until all pass.

### Step 7: Stage only
```bash
git add -A
```

Do NOT commit.

### HARD STOP
Report what you did, including full `mix test` output showing all tests passing, and stop.`
