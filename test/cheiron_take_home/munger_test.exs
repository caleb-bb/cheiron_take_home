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
  defp condition_gen do
    member_of([
      "Lung Cancer",
      "Breast Cancer",
      "Diabetes",
      "Alzheimer's Disease",
      "Hypertension",
      "Asthma"
    ])
  end

  defp intervention_gen do
    member_of([
      "Pembrolizumab",
      "Radiation Therapy",
      "Metformin",
      "Placebo",
      "Surgery",
      "Chemotherapy"
    ])
  end

  defp sponsor_gen do
    member_of(["NIH", "Pfizer", "Novartis", "Mayo Clinic", "Johns Hopkins", "AstraZeneca"])
  end

  defp study_gen do
    gen all(
          nct_id <- string(:alphanumeric, min_length: 8, max_length: 12),
          title <- string(:alphanumeric, min_length: 5, max_length: 50),
          phases <- list_of(phase_gen(), min_length: 1, max_length: 2),
          start_date <- date_string_gen(),
          status <-
            member_of([
              "RECRUITING",
              "COMPLETED",
              "TERMINATED",
              "ACTIVE_NOT_RECRUITING",
              "WITHDRAWN"
            ]),
          conditions <- list_of(condition_gen(), min_length: 1, max_length: 2),
          interventions <- list_of(intervention_gen(), min_length: 1, max_length: 3),
          sponsor <- sponsor_gen(),
          enrollment <- integer(10..5000)
        ) do
      %{
        "protocolSection" => %{
          "identificationModule" => %{
            "nctId" => "NCT" <> nct_id,
            "briefTitle" => title
          },
          "designModule" => %{
            "phases" => phases,
            "enrollmentInfo" => %{"count" => enrollment, "type" => "ACTUAL"}
          },
          "statusModule" => %{
            "overallStatus" => status,
            "startDateStruct" => %{
              "date" => start_date,
              "type" => "ACTUAL"
            }
          },
          "conditionsModule" => %{
            "conditions" => conditions
          },
          "armsInterventionsModule" => %{
            "interventions" => Enum.map(interventions, &%{"name" => &1, "type" => "DRUG"})
          },
          "sponsorCollaboratorsModule" => %{
            "leadSponsor" => %{"name" => sponsor, "class" => "OTHER"}
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

  # Network graph: source and target are categorical, weight is quantitative and non-negative
  defp assert_network_graph_shape(viz_spec) do
    assert viz_spec.encoding.source.type == "categorical"
    assert viz_spec.encoding.target.type == "categorical"
    assert viz_spec.encoding.weight.type == "quantitative"

    weight_field = viz_spec.encoding.weight.field

    Enum.each(viz_spec.data, fn point ->
      val = point[weight_field]

      assert is_integer(val) and val >= 0,
             "Network graph weight must be a non-negative integer, got: #{inspect(val)}"
    end)
  end

  # Scatter plot: x and y are quantitative, every point has nct_id and label
  defp assert_scatter_plot_shape(viz_spec) do
    assert viz_spec.encoding.x.type == "quantitative"
    assert viz_spec.encoding.y.type == "quantitative"

    Enum.each(viz_spec.data, fn point ->
      assert is_integer(point["start_year"]), "Scatter plot x must be an integer"

      assert is_integer(point["enrollment"]) and point["enrollment"] > 0,
             "Scatter plot y must be a positive integer"
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

  # --- Bar Chart by Phase: Citations ---

  describe "build/2 bar_chart by phase citations" do
    property "every data point has a citations list" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert Map.has_key?(point, "citations"), "Data point missing citations key"
          assert is_list(point["citations"])
        end)
      end
    end

    property "every citation has nct_id and non-empty excerpt" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          Enum.each(point["citations"], fn citation ->
            assert is_binary(citation["nct_id"]) and citation["nct_id"] != ""
            assert is_binary(citation["excerpt"]) and citation["excerpt"] != ""
          end)
        end)
      end
    end

    property "every citation nct_id exists in input studies" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_nct_ids =
          studies
          |> Enum.map(&get_in(&1, ["protocolSection", "identificationModule", "nctId"]))
          |> MapSet.new()

        Enum.each(viz_spec.data, fn point ->
          Enum.each(point["citations"], fn citation ->
            assert citation["nct_id"] in input_nct_ids,
                   "Citation nct_id #{citation["nct_id"]} not found in input studies"
          end)
        end)
      end
    end

    property "citations in a phase bucket actually have that phase" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          phase = point["phase"]

          Enum.each(point["citations"], fn citation ->
            study = studies_by_nct[citation["nct_id"]]
            phases = get_in(study, ["protocolSection", "designModule", "phases"]) || []

            assert phase in phases,
                   "Citation #{citation["nct_id"]} in #{phase} bucket but study has phases #{inspect(phases)}"
          end)
        end)
      end
    end

    property "citation count equals trial_count for each data point" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert length(point["citations"]) == point["trial_count"],
                 "Citations count #{length(point["citations"])} != trial_count #{point["trial_count"]}"
        end)
      end
    end
  end

  # --- Bar Chart by Status: Citations ---

  describe "build/2 bar_chart by status citations" do
    property "citations in a status bucket actually have that status" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "status"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          status = point["status"]

          Enum.each(point["citations"], fn citation ->
            study = studies_by_nct[citation["nct_id"]]
            study_status = get_in(study, ["protocolSection", "statusModule", "overallStatus"])

            assert status == study_status,
                   "Citation #{citation["nct_id"]} in #{status} bucket but study has status #{study_status}"
          end)
        end)
      end
    end

    property "citation count equals trial_count for each data point" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "status"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert length(point["citations"]) == point["trial_count"]
        end)
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
               CheironTakeHome.Munger.build(studies_without_phases, %{
                 viz_type: :bar_chart,
                 group_by: "phase"
               })
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
            date_str =
              get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"]) || ""

            String.slice(date_str, 0, 4)
          end)
          |> Enum.reject(&(&1 == ""))
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

  # --- Time Series: Citations ---

  describe "build/2 time_series citations" do
    property "every data point has a citations list with nct_id and excerpt" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert is_list(point["citations"])

          Enum.each(point["citations"], fn citation ->
            assert is_binary(citation["nct_id"]) and citation["nct_id"] != ""
            assert is_binary(citation["excerpt"]) and citation["excerpt"] != ""
          end)
        end)
      end
    end

    property "citations in a period bucket have start dates in that period" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          period = point["period"]

          Enum.each(point["citations"], fn citation ->
            study = studies_by_nct[citation["nct_id"]]
            date = get_in(study, ["protocolSection", "statusModule", "startDateStruct", "date"])
            study_year = String.slice(date, 0, 4)

            assert study_year == period,
                   "Citation #{citation["nct_id"]} in period #{period} but study started in #{study_year}"
          end)
        end)
      end
    end

    property "citation count equals count for each data point" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert length(point["citations"]) == point["count"]
        end)
      end
    end
  end

  # --- Year Range Filtering ---

  describe "build/2 with start_year filtering" do
    property "no output period is before start_year" do
      check all(
              studies <- studies_gen(),
              start_year <- integer(2015..2020)
            ) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year, start_year: start_year}
        result = CheironTakeHome.Munger.build(studies, viz_intent)

        case result do
          {:ok, viz_spec} ->
            Enum.each(viz_spec.data, fn point ->
              {period_year, _} = Integer.parse(point["period"])

              assert period_year >= start_year,
                     "Period #{point["period"]} is before start_year #{start_year}"
            end)

          {:error, :empty_result} ->
            :ok
        end
      end
    end

    property "no output period is after end_year" do
      check all(
              studies <- studies_gen(),
              end_year <- integer(2020..2025)
            ) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year, end_year: end_year}
        result = CheironTakeHome.Munger.build(studies, viz_intent)

        case result do
          {:ok, viz_spec} ->
            Enum.each(viz_spec.data, fn point ->
              {period_year, _} = Integer.parse(point["period"])

              assert period_year <= end_year,
                     "Period #{point["period"]} is after end_year #{end_year}"
            end)

          {:error, :empty_result} ->
            :ok
        end
      end
    end

    property "year range filtering preserves count accuracy" do
      check all(studies <- studies_gen()) do
        start_year = 2018
        end_year = 2022

        viz_intent = %{
          viz_type: :time_series,
          time_granularity: :year,
          start_year: start_year,
          end_year: end_year
        }

        result = CheironTakeHome.Munger.build(studies, viz_intent)

        expected_count =
          studies
          |> Enum.count(fn s ->
            date_str = get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"])

            if date_str do
              {year, _} = Integer.parse(String.slice(date_str, 0, 4))
              year >= start_year and year <= end_year
            else
              false
            end
          end)

        case result do
          {:ok, viz_spec} ->
            output_total = viz_spec.data |> Enum.map(& &1["count"]) |> Enum.sum()
            assert output_total == expected_count

          {:error, :empty_result} ->
            assert expected_count == 0
        end
      end
    end
  end

  # --- Network Graph Properties (condition_to_intervention) ---

  describe "build/2 with network_graph viz_type (condition_to_intervention)" do
    property "every edge in the output traces to an input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_intervention}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_edges =
          studies
          |> Enum.flat_map(fn s ->
            conditions = get_in(s, ["protocolSection", "conditionsModule", "conditions"]) || []

            interventions =
              (get_in(s, ["protocolSection", "armsInterventionsModule", "interventions"]) || [])
              |> Enum.map(& &1["name"])
              |> Enum.reject(&is_nil/1)

            for c <- conditions, i <- interventions, do: {c, i}
          end)
          |> MapSet.new()

        output_edges =
          viz_spec.data
          |> Enum.map(&{&1["source"], &1["target"]})
          |> MapSet.new()

        assert MapSet.subset?(output_edges, input_edges),
               "Output contains edges not in input: #{inspect(MapSet.difference(output_edges, input_edges))}"
      end
    end

    property "no phantom weights: sum of weights equals total condition-intervention pairs in input" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_intervention}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_pair_count =
          studies
          |> Enum.flat_map(fn s ->
            conditions = get_in(s, ["protocolSection", "conditionsModule", "conditions"]) || []

            interventions =
              (get_in(s, ["protocolSection", "armsInterventionsModule", "interventions"]) || [])
              |> Enum.map(& &1["name"])
              |> Enum.reject(&is_nil/1)

            for c <- conditions, i <- interventions, do: {c, i}
          end)
          |> length()

        output_total =
          viz_spec.data
          |> Enum.map(& &1["weight"])
          |> Enum.sum()

        assert output_total == input_pair_count
      end
    end

    property "output has valid shape, encoding-data coherence, and network graph structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_intervention}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_network_graph_shape(viz_spec)
      end
    end
  end

  # --- Network Graph (condition_to_intervention): Citations ---

  describe "build/2 network_graph condition_to_intervention citations" do
    property "every data point has a citations list with nct_id and excerpt" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_intervention}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert is_list(point["citations"])

          Enum.each(point["citations"], fn citation ->
            assert is_binary(citation["nct_id"]) and citation["nct_id"] != ""
            assert is_binary(citation["excerpt"]) and citation["excerpt"] != ""
          end)
        end)
      end
    end

    property "citations on an edge have both the source condition and target intervention" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_intervention}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          source = point["source"]
          target = point["target"]

          Enum.each(point["citations"], fn citation ->
            study = studies_by_nct[citation["nct_id"]]

            conditions =
              get_in(study, ["protocolSection", "conditionsModule", "conditions"]) || []

            interventions =
              (get_in(study, ["protocolSection", "armsInterventionsModule", "interventions"]) ||
                 [])
              |> Enum.map(& &1["name"])

            assert source in conditions,
                   "Citation #{citation["nct_id"]} on edge from #{source} but study has conditions #{inspect(conditions)}"

            assert target in interventions,
                   "Citation #{citation["nct_id"]} on edge to #{target} but study has interventions #{inspect(interventions)}"
          end)
        end)
      end
    end

    property "citation count equals weight for each edge" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_intervention}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert length(point["citations"]) == point["weight"]
        end)
      end
    end
  end

  # --- Network Graph Properties (condition_to_sponsor) ---

  describe "build/2 with network_graph viz_type (condition_to_sponsor)" do
    property "every edge in the output traces to an input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_sponsor}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_edges =
          studies
          |> Enum.flat_map(fn s ->
            conditions = get_in(s, ["protocolSection", "conditionsModule", "conditions"]) || []

            sponsor =
              get_in(s, ["protocolSection", "sponsorCollaboratorsModule", "leadSponsor", "name"])

            if sponsor, do: Enum.map(conditions, &{&1, sponsor}), else: []
          end)
          |> MapSet.new()

        output_edges =
          viz_spec.data
          |> Enum.map(&{&1["source"], &1["target"]})
          |> MapSet.new()

        assert MapSet.subset?(output_edges, input_edges)
      end
    end

    property "no phantom weights: sum of weights equals total condition-sponsor pairs in input" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_sponsor}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_pair_count =
          studies
          |> Enum.flat_map(fn s ->
            conditions = get_in(s, ["protocolSection", "conditionsModule", "conditions"]) || []

            sponsor =
              get_in(s, ["protocolSection", "sponsorCollaboratorsModule", "leadSponsor", "name"])

            if sponsor, do: Enum.map(conditions, &{&1, sponsor}), else: []
          end)
          |> length()

        output_total =
          viz_spec.data
          |> Enum.map(& &1["weight"])
          |> Enum.sum()

        assert output_total == input_pair_count
      end
    end

    property "output has valid shape, encoding-data coherence, and network graph structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_sponsor}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_network_graph_shape(viz_spec)
      end
    end
  end

  # --- Network Graph (condition_to_sponsor): Citations ---

  describe "build/2 network_graph condition_to_sponsor citations" do
    property "citations on an edge have both the source condition and target sponsor" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_sponsor}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          source = point["source"]
          target = point["target"]

          Enum.each(point["citations"], fn citation ->
            study = studies_by_nct[citation["nct_id"]]

            conditions =
              get_in(study, ["protocolSection", "conditionsModule", "conditions"]) || []

            sponsor =
              get_in(study, [
                "protocolSection",
                "sponsorCollaboratorsModule",
                "leadSponsor",
                "name"
              ])

            assert source in conditions,
                   "Citation #{citation["nct_id"]} on edge from #{source} but study has conditions #{inspect(conditions)}"

            assert target == sponsor,
                   "Citation #{citation["nct_id"]} on edge to #{target} but study has sponsor #{sponsor}"
          end)
        end)
      end
    end

    property "citation count equals weight for each edge" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :network_graph, edge_type: :condition_to_sponsor}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert length(point["citations"]) == point["weight"]
        end)
      end
    end
  end

  # --- Scatter Plot Properties ---

  describe "build/2 with scatter_plot viz_type" do
    property "output has valid shape, encoding channels, encoding-data coherence, and scatter plot structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_scatter_plot_shape(viz_spec)
      end
    end

    property "every output nct_id exists in input studies" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        input_nct_ids =
          studies
          |> Enum.map(&get_in(&1, ["protocolSection", "identificationModule", "nctId"]))
          |> MapSet.new()

        Enum.each(viz_spec.data, fn point ->
          assert point["nct_id"] in input_nct_ids,
                 "Output nct_id #{point["nct_id"]} not found in input studies"
        end)
      end
    end

    property "every output point has non-empty nct_id and label" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        Enum.each(viz_spec.data, fn point ->
          assert is_binary(point["nct_id"]) and point["nct_id"] != ""
          assert is_binary(point["label"]) and point["label"] != ""
        end)
      end
    end

    property "no duplicate nct_ids in output" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        nct_ids = Enum.map(viz_spec.data, & &1["nct_id"])

        assert length(nct_ids) == length(Enum.uniq(nct_ids)),
               "Duplicate nct_ids in scatter plot output"
      end
    end

    property "output count equals input studies with both enrollment and start date" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        expected_count =
          Enum.count(studies, fn s ->
            enrollment = get_in(s, ["protocolSection", "designModule", "enrollmentInfo", "count"])
            date = get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"])
            enrollment != nil and date != nil and date != ""
          end)

        assert length(viz_spec.data) == expected_count
      end
    end

    property "each point's enrollment matches input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          study = studies_by_nct[point["nct_id"]]
          expected = get_in(study, ["protocolSection", "designModule", "enrollmentInfo", "count"])
          assert point["enrollment"] == expected
        end)
      end
    end

    property "each point's start_year matches input study's start date year" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          study = studies_by_nct[point["nct_id"]]
          date = get_in(study, ["protocolSection", "statusModule", "startDateStruct", "date"])
          {expected_year, _} = Integer.parse(String.slice(date, 0, 4))
          assert point["start_year"] == expected_year
        end)
      end
    end
  end

  # --- Scatter Plot with color_by ---

  describe "build/2 scatter_plot with color_by" do
    property "when color_by is status, each point's value matches input study" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot, color_by: "status"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert Map.has_key?(viz_spec.encoding, :color)
        assert viz_spec.encoding.color.type == "categorical"

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          study = studies_by_nct[point["nct_id"]]
          expected = get_in(study, ["protocolSection", "statusModule", "overallStatus"])
          assert point["status"] == expected
        end)
      end
    end

    property "when color_by is phase, each point's value matches input study's joined phases" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :scatter_plot, color_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        studies_by_nct =
          Map.new(studies, fn s ->
            {get_in(s, ["protocolSection", "identificationModule", "nctId"]), s}
          end)

        Enum.each(viz_spec.data, fn point ->
          study = studies_by_nct[point["nct_id"]]
          phases = get_in(study, ["protocolSection", "designModule", "phases"]) || []
          expected = Enum.join(phases, "/")
          assert point["phase"] == expected
        end)
      end
    end
  end

  # --- Scatter Plot Edge Cases ---

  describe "build/2 scatter_plot edge cases" do
    test "returns error when all studies lack enrollment" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "designModule" => %{"phases" => ["PHASE1"]},
            "statusModule" => %{
              "overallStatus" => "COMPLETED",
              "startDateStruct" => %{"date" => "2024-01-01"}
            }
          }
        }
      ]

      assert {:error, :empty_result} =
               CheironTakeHome.Munger.build(studies, %{viz_type: :scatter_plot})
    end

    test "returns error when all studies lack start dates" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "designModule" => %{
              "phases" => ["PHASE1"],
              "enrollmentInfo" => %{"count" => 100}
            },
            "statusModule" => %{"overallStatus" => "COMPLETED"}
          }
        }
      ]

      assert {:error, :empty_result} =
               CheironTakeHome.Munger.build(studies, %{viz_type: :scatter_plot})
    end
  end

  # --- Crash-path Validation Tests ---

  describe "build/2 with unknown viz_type" do
    test "returns error for unrecognized viz_type" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "designModule" => %{"phases" => ["PHASE1"]},
            "statusModule" => %{"overallStatus" => "COMPLETED"}
          }
        }
      ]

      assert {:error, _reason} =
               CheironTakeHome.Munger.build(studies, %{viz_type: :unknown})
    end
  end

  describe "build/2 time_series with malformed dates" do
    test "does not crash on non-ISO date like 'March 2024'" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "statusModule" => %{
              "overallStatus" => "COMPLETED",
              "startDateStruct" => %{"date" => "March 2024"}
            }
          }
        }
      ]

      result =
        CheironTakeHome.Munger.build(studies, %{
          viz_type: :time_series,
          time_granularity: :quarter
        })

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash on date 'N/A' in scatter_plot" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "designModule" => %{
              "phases" => ["PHASE1"],
              "enrollmentInfo" => %{"count" => 100}
            },
            "statusModule" => %{
              "overallStatus" => "COMPLETED",
              "startDateStruct" => %{"date" => "N/A"}
            }
          }
        }
      ]

      result = CheironTakeHome.Munger.build(studies, %{viz_type: :scatter_plot})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "build/2 scatter_plot with unknown color_by" do
    test "does not crash with color_by 'sponsor'" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "designModule" => %{
              "phases" => ["PHASE1"],
              "enrollmentInfo" => %{"count" => 100}
            },
            "statusModule" => %{
              "overallStatus" => "COMPLETED",
              "startDateStruct" => %{"date" => "2024-01-15"}
            },
            "sponsorCollaboratorsModule" => %{
              "leadSponsor" => %{"name" => "NIH"}
            }
          }
        }
      ]

      result =
        CheironTakeHome.Munger.build(studies, %{viz_type: :scatter_plot, color_by: "sponsor"})

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "build/2 network_graph with unknown edge_type" do
    test "returns error for unrecognized edge_type" do
      studies = [
        %{
          "protocolSection" => %{
            "identificationModule" => %{"nctId" => "NCT001", "briefTitle" => "Test"},
            "conditionsModule" => %{"conditions" => ["Cancer"]},
            "armsInterventionsModule" => %{
              "interventions" => [%{"name" => "Drug A", "type" => "DRUG"}]
            }
          }
        }
      ]

      assert {:error, _reason} =
               CheironTakeHome.Munger.build(studies, %{
                 viz_type: :network_graph,
                 edge_type: :unknown
               })
    end
  end
end
