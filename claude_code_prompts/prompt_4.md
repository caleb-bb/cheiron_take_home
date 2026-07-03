# Claude Code Prompt: Failing Property Tests for the Munger

## Context
The Phoenix project `cheiron_take_home` has working API wrapper modules and tests for `CheironTakeHome.LLM` and `CheironTakeHome.ClinicalTrials`. The next module is `CheironTakeHome.Munger`, which is currently an empty stub.

The munger transforms raw ClinicalTrials.gov API data plus a visualization intent into a structured visualization spec. Its public API is:

```elixir
Munger.build(raw_data, viz_intent)
```

Where:
- `raw_data` is a list of study maps as returned by the ClinicalTrials.gov API (nested maps with `protocolSection`, etc.)
- `viz_intent` is a map like `%{viz_type: :bar_chart, group_by: "phase"}` or `%{viz_type: :time_series, time_granularity: :year}`

It returns `{:ok, viz_spec}` where `viz_spec` is a map with keys: `type`, `title`, `encoding`, `data`, `meta`.

## Task: Write failing property-based tests for the Munger using StreamData.

### Step 0: Assess
Read this entire prompt. Confirm you understand by listing your steps. Do not begin until you've confirmed.

### Step 1: Write the test file

File: `test/cheiron_take_home/munger_test.exs`

This file must:
1. `use ExUnit.Case, async: true`
2. `use ExUnitProperties` (from StreamData)
3. Define StreamData generators for fake study data
4. Define property tests that enforce traceability between input and output
5. ALL TESTS MUST FAIL because `Munger.build/2` does not exist yet

Here is the full test file to create:

```elixir
defmodule CheironTakeHome.MungerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  # --- Generators ---

  # Generate a valid phase string matching ClinicalTrials.gov enum values
  defp phase_gen do
    member_of(["PHASE1", "PHASE2", "PHASE3", "PHASE4", "EARLY_PHASE1", "NA"])
  end

  # Generate a date string in YYYY-MM-DD format (2010-2026 range)
  defp date_string_gen do
    gen all(
          year <- integer(2010..2026),
          month <- integer(1..12),
          day <- integer(1..28)
        ) do
      Date.new!(year, month, day) |> Date.to_string()
    end
  end

  # Generate a single study map with the nested structure the munger actually reads.
  # Fields not used by the munger are omitted — the munger must tolerate their absence.
  defp study_gen do
    gen all(
          nct_id <- string(:alphanumeric, min_length: 8, max_length: 12),
          title <- string(:alphanumeric, min_length: 5, max_length: 50),
          phases <- list_of(phase_gen(), min_length: 1, max_length: 2),
          start_date <- date_string_gen(),
          status <- member_of(["RECRUITING", "COMPLETED", "TERMINATED", "ACTIVE_NOT_RECRUITING", "WITHDRAWN"])
        ) do
      %{
        "protocolSection" => %{
          "identificationModule" => %{
            "nctId" => "NCT" <> nct_id,
            "briefTitle" => title
          },
          "designModule" => %{
            "phases" => phases
          },
          "statusModule" => %{
            "overallStatus" => status,
            "startDateStruct" => %{
              "date" => start_date,
              "type" => "ACTUAL"
            }
          }
        }
      }
    end
  end

  # Generate a non-empty list of studies
  defp studies_gen do
    list_of(study_gen(), min_length: 1, max_length: 20)
  end

  # --- Bar Chart Properties ---

  describe "build/2 with bar_chart viz_type grouped by phase" do
    property "every phase in the output appears in at least one input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        # Collect all phases present in the input
        input_phases =
          studies
          |> Enum.flat_map(fn s ->
            get_in(s, ["protocolSection", "designModule", "phases"]) || []
          end)
          |> MapSet.new()

        # Every phase label in the output must exist in the input
        output_phases =
          viz_spec.data
          |> Enum.map(& &1["phase"])
          |> MapSet.new()

        assert MapSet.subset?(output_phases, input_phases),
               "Output contains phases not in input: #{inspect(MapSet.difference(output_phases, input_phases))}"
      end
    end

    property "no phantom counts: sum of output trial_counts equals total input study-phase pairs" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        # A study with phases ["PHASE1", "PHASE2"] counts once in each bucket
        input_phase_count =
          studies
          |> Enum.flat_map(fn s ->
            get_in(s, ["protocolSection", "designModule", "phases"]) || []
          end)
          |> length()

        output_total =
          viz_spec.data
          |> Enum.map(& &1["trial_count"])
          |> Enum.sum()

        assert output_total == input_phase_count
      end
    end

    property "output has required viz_spec keys" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert is_binary(viz_spec.type)
        assert is_binary(viz_spec.title)
        assert is_map(viz_spec.encoding)
        assert is_list(viz_spec.data)
      end
    end
  end

  # --- Time Series Properties ---

  describe "build/2 with time_series viz_type" do
    property "every time bucket in the output corresponds to at least one input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        # Collect all start years from input
        input_years =
          studies
          |> Enum.map(fn s ->
            date_str = get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"]) || ""
            String.slice(date_str, 0, 4)
          end)
          |> Enum.reject(& &1 == "")
          |> MapSet.new()

        output_years =
          viz_spec.data
          |> Enum.map(& &1["period"])
          |> MapSet.new()

        assert MapSet.subset?(output_years, input_years),
               "Output contains time periods not in input: #{inspect(MapSet.difference(output_years, input_years))}"
      end
    end

    property "no phantom counts: sum of output counts equals number of input studies with valid dates" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_with_dates =
          studies
          |> Enum.count(fn s ->
            date_str = get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"])
            date_str != nil and date_str != ""
          end)

        output_total =
          viz_spec.data
          |> Enum.map(& &1["count"])
          |> Enum.sum()

        assert output_total == input_with_dates
      end
    end

    property "output data is sorted chronologically" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        periods = Enum.map(viz_spec.data, & &1["period"])
        assert periods == Enum.sort(periods)
      end
    end

    property "output has required viz_spec keys" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert is_binary(viz_spec.type)
        assert is_binary(viz_spec.title)
        assert is_map(viz_spec.encoding)
        assert is_list(viz_spec.data)
      end
    end
  end
end
```

### Step 2: Verify tests FAIL
Run `mix test test/cheiron_take_home/munger_test.exs`. All property tests must FAIL because `Munger.build/2` does not exist. If any test passes, something is wrong — report it.

### Step 3: Stage only
```bash
git add -A
```

Do NOT commit. Do NOT run `git commit`.

### HARD STOP
Do NOT implement `Munger.build/2`. Do NOT modify the Munger stub module. Do NOT make the tests pass. Report what you did, including the test failure output, and stop.

