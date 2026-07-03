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

  # --- Shape Assertion Helpers ---

  # Universal: every viz spec must have these keys with these types
  defp assert_viz_spec_shape(viz_spec) do
    assert is_binary(viz_spec.type) and viz_spec.type != ""
    assert is_binary(viz_spec.title) and viz_spec.title != ""
    assert is_map(viz_spec.encoding)
    assert is_list(viz_spec.data) and length(viz_spec.data) > 0
    assert is_map(viz_spec.meta)
  end

  # Every field declared in encoding must appear as a key in every data point
  defp assert_encoding_data_coherence(viz_spec) do
    encoding_fields =
      viz_spec.encoding
      |> Map.values()
      |> Enum.map(& &1.field)
      |> MapSet.new()

    Enum.each(viz_spec.data, fn data_point ->
      data_keys = data_point |> Map.keys() |> MapSet.new()

      assert MapSet.subset?(encoding_fields, data_keys),
             "Data point missing fields declared in encoding: #{inspect(MapSet.difference(encoding_fields, data_keys))}"
    end)
  end

  # Each encoding channel must have field, label, and type
  defp assert_encoding_channels(viz_spec) do
    Enum.each(viz_spec.encoding, fn {_channel, channel_spec} ->
      assert is_binary(channel_spec.field), "Encoding channel missing :field"
      assert is_binary(channel_spec.label), "Encoding channel missing :label"
      assert channel_spec.type in ["categorical", "quantitative", "temporal"],
             "Encoding channel :type must be categorical, quantitative, or temporal — got #{inspect(channel_spec.type)}"
    end)
  end

  # Bar chart: x is categorical, y is quantitative, sort key exists, y values are non-negative integers
  defp assert_bar_chart_shape(viz_spec) do
    assert viz_spec.encoding.x.type == "categorical"
    assert viz_spec.encoding.y.type == "quantitative"
    assert Map.has_key?(viz_spec, :sort), "Bar chart spec missing :sort key"

    y_field = viz_spec.encoding.y.field

    Enum.each(viz_spec.data, fn point ->
      val = point[y_field]
      assert is_integer(val) and val >= 0,
             "Bar chart y-axis value must be a non-negative integer, got: #{inspect(val)}"
    end)
  end

  # Time series: x is temporal with granularity, y is quantitative, y values non-negative integers
  defp assert_time_series_shape(viz_spec) do
    assert viz_spec.encoding.x.type == "temporal"

    assert Map.has_key?(viz_spec.encoding.x, :granularity),
           "Time series x-axis encoding missing :granularity"

    assert viz_spec.encoding.x.granularity in ["year", "month", "quarter"],
           "Time series granularity must be year, month, or quarter — got #{inspect(viz_spec.encoding.x.granularity)}"

    assert viz_spec.encoding.y.type == "quantitative"

    y_field = viz_spec.encoding.y.field

    Enum.each(viz_spec.data, fn point ->
      val = point[y_field]
      assert is_integer(val) and val >= 0,
             "Time series y-axis value must be a non-negative integer, got: #{inspect(val)}"
    end)
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

    property "output has valid shape, encoding channels, encoding-data coherence, and bar chart structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_bar_chart_shape(viz_spec)
      end
    end
  end

  # --- Bar Chart Error Cases ---

  describe "build/2 with bar_chart error cases" do
    test "returns error for unsupported group_by value" do
      assert {:error, {:unsupported_group_by, "cause", _supported}} =
               CheironTakeHome.Munger.build([], %{viz_type: :bar_chart, group_by: "cause"})
    end

    test "returns error when studies produce empty data" do
      studies_without_phases = [
        %{"protocolSection" => %{"designModule" => %{}}},
        %{"protocolSection" => %{"designModule" => %{"phases" => []}}}
      ]

      assert {:error, :empty_result} =
               CheironTakeHome.Munger.build(studies_without_phases, %{viz_type: :bar_chart, group_by: "phase"})
    end
  end

  # --- Bar Chart by Status ---

  describe "build/2 with bar_chart viz_type grouped by status" do
    property "every status in the output appears in at least one input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "status"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_statuses =
          studies
          |> Enum.map(fn s ->
            get_in(s, ["protocolSection", "statusModule", "overallStatus"])
          end)
          |> Enum.reject(&is_nil/1)
          |> MapSet.new()

        output_statuses =
          viz_spec.data
          |> Enum.map(& &1["status"])
          |> MapSet.new()

        assert MapSet.subset?(output_statuses, input_statuses)
      end
    end

    property "output has valid shape and bar chart structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "status"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_bar_chart_shape(viz_spec)
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

    property "output has valid shape, encoding channels, encoding-data coherence, and time series structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_time_series_shape(viz_spec)
      end
    end
  end
end
