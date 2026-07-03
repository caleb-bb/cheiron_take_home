defmodule CheironTakeHome.Munger do
  @moduledoc "Transforms raw ClinicalTrials.gov data plus visualization intent into a structured visualization spec."

  @supported_group_by ~w(phase status)

  def build(_studies, %{viz_type: :bar_chart, group_by: group_by})
      when group_by not in @supported_group_by do
    {:error, {:unsupported_group_by, group_by, @supported_group_by}}
  end

  def build(studies, %{viz_type: :bar_chart, group_by: group_by} = intent) do
    data =
      studies
      |> Enum.flat_map(&extract_group_values(&1, group_by))
      |> Enum.frequencies()
      |> Enum.map(fn {label, count} ->
        %{group_by => label, "trial_count" => count}
      end)
      |> Enum.sort_by(& &1["trial_count"], :desc)

    if data == [] do
      {:error, :empty_result}
    else
      label = group_by |> String.replace("_", " ") |> String.capitalize()
      title = build_title(intent[:subject], "by #{label}")

      {:ok, %{
        type: "bar_chart",
        title: title,
        encoding: %{
          x: %{field: group_by, label: label, type: "categorical"},
          y: %{field: "trial_count", label: "Number of Trials", type: "quantitative"}
        },
        data: data,
        meta: %{source: "clinicaltrials.gov", total_studies: length(studies)},
        sort: %{field: group_by, order: "descending"}
      }}
    end
  end

  def build(studies, %{viz_type: :time_series, time_granularity: granularity} = intent) do
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

    if data == [] do
      {:error, :empty_result}
    else
      title = build_title(intent[:subject], "Over Time")

      {:ok, %{
        type: "time_series",
        title: title,
        encoding: %{
          x: %{field: "period", label: "Year", type: "temporal", granularity: gran_str},
          y: %{field: "count", label: "Number of Trials Started", type: "quantitative"}
        },
        data: data,
        meta: %{source: "clinicaltrials.gov", total_studies: length(studies), date_field: "startDateStruct"}
      }}
    end
  end

  defp build_title(nil, suffix), do: "Clinical Trials #{suffix}"

  defp build_title(subject, suffix) do
    subject = subject |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
    "#{subject} Clinical Trials #{suffix}"
  end

  defp extract_group_values(study, "phase") do
    get_in(study, ["protocolSection", "designModule", "phases"]) || []
  end

  defp extract_group_values(study, "status") do
    case get_in(study, ["protocolSection", "statusModule", "overallStatus"]) do
      nil -> []
      status -> [status]
    end
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
