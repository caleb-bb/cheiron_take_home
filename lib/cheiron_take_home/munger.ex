defmodule CheironTakeHome.Munger do
  @moduledoc "Transforms raw ClinicalTrials.gov data plus visualization intent into a structured visualization spec."

  def build(studies, %{viz_type: :bar_chart, group_by: group_by}) do
    data =
      studies
      |> Enum.flat_map(&extract_group_values(&1, group_by))
      |> Enum.frequencies()
      |> Enum.map(fn {label, count} ->
        %{group_by => label, "trial_count" => count}
      end)
      |> Enum.sort_by(& &1["trial_count"], :desc)

    label = group_by |> String.replace("_", " ") |> String.capitalize()

    {:ok, %{
      type: "bar_chart",
      title: "Clinical Trials by #{label}",
      encoding: %{
        x: %{field: group_by, label: label, type: "categorical"},
        y: %{field: "trial_count", label: "Number of Trials", type: "quantitative"}
      },
      data: data,
      meta: %{source: "clinicaltrials.gov", total_studies: length(studies)},
      sort: %{field: group_by, order: "descending"}
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

  defp extract_group_values(study, "phase") do
    get_in(study, ["protocolSection", "designModule", "phases"]) || []
  end

  defp extract_group_values(_, _), do: []

  defp extract_period(date_str, :year), do: String.slice(date_str, 0, 4)
  defp extract_period(date_str, :month), do: String.slice(date_str, 0, 7)

  defp extract_period(date_str, :quarter) do
    year = String.slice(date_str, 0, 4)
    month = date_str |> String.slice(5, 2) |> String.to_integer()
    quarter = div(month - 1, 3) + 1
    "#{year}-Q#{quarter}"
  end
end
