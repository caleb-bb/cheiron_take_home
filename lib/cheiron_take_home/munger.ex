defmodule CheironTakeHome.Munger do
  @moduledoc "Transforms raw ClinicalTrials.gov data plus visualization intent into a structured visualization spec."

  def build(studies, %{viz_type: :bar_chart, group_by: "phase"}) do
    data =
      studies
      |> Enum.flat_map(fn s ->
        get_in(s, ["protocolSection", "designModule", "phases"]) || []
      end)
      |> Enum.frequencies()
      |> Enum.map(fn {phase, count} ->
        %{"phase" => phase, "trial_count" => count}
      end)
      |> Enum.sort_by(& &1["trial_count"], :desc)

    {:ok, %{
      type: "bar_chart",
      title: "Clinical Trials by Phase",
      encoding: %{
        x: %{field: "phase", label: "Trial Phase", type: "categorical"},
        y: %{field: "trial_count", label: "Number of Trials", type: "quantitative"}
      },
      data: data,
      meta: %{source: "clinicaltrials.gov", total_studies: length(studies)},
      sort: %{field: "phase", order: "ordinal", sequence: ["EARLY_PHASE1", "PHASE1", "PHASE2", "PHASE3", "PHASE4", "NA"]}
    }}
  end

  def build(studies, %{viz_type: :time_series, time_granularity: granularity}) do
    gran_str = Atom.to_string(granularity)

    data =
      studies
      |> Enum.map(fn s ->
        get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"])
      end)
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.map(&extract_period(&1, granularity))
      |> Enum.frequencies()
      |> Enum.map(fn {period, count} ->
        %{"period" => period, "count" => count}
      end)
      |> Enum.sort_by(& &1["period"])

    {:ok, %{
      type: "time_series",
      title: "Clinical Trials Over Time",
      encoding: %{
        x: %{field: "period", label: "Year", type: "temporal", granularity: gran_str},
        y: %{field: "count", label: "Number of Trials Started", type: "quantitative"}
      },
      data: data,
      meta: %{source: "clinicaltrials.gov", total_studies: length(studies), date_field: "startDateStruct"}
    }}
  end

  defp extract_period(date_str, :year), do: String.slice(date_str, 0, 4)
  defp extract_period(date_str, :month), do: String.slice(date_str, 0, 7)

  defp extract_period(date_str, :quarter) do
    year = String.slice(date_str, 0, 4)
    month = date_str |> String.slice(5, 2) |> String.to_integer()
    quarter = div(month - 1, 3) + 1
    "#{year}-Q#{quarter}"
  end
end
