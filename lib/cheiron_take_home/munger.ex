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
      |> Enum.flat_map(fn study ->
        citation = citation_for(study)
        extract_group_values(study, group_by) |> Enum.map(&{&1, citation})
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {label, citations} ->
        %{group_by => label, "trial_count" => length(citations), "citations" => citations}
      end)
      |> Enum.sort_by(& &1["trial_count"], :desc)

    if data == [] do
      {:error, :empty_result}
    else
      label = group_by |> String.replace("_", " ") |> String.capitalize()
      title = build_title(intent[:subject], "by #{label}")

      {:ok,
       %{
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
        {get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"]), s}
      end)
      |> Enum.reject(fn {date, _s} -> is_nil(date) or date == "" end)
      |> filter_by_year_range(intent)
      |> Enum.map(fn {date, study} ->
        {extract_period(date, granularity), citation_for(study)}
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {period, citations} ->
        %{"period" => period, "count" => length(citations), "citations" => citations}
      end)
      |> Enum.sort_by(& &1["period"])

    if data == [] do
      {:error, :empty_result}
    else
      title = build_title(intent[:subject], "Over Time")

      {:ok,
       %{
         type: "time_series",
         title: title,
         encoding: %{
           x: %{field: "period", label: "Year", type: "temporal", granularity: gran_str},
           y: %{field: "count", label: "Number of Trials Started", type: "quantitative"}
         },
         data: data,
         meta: %{
           source: "clinicaltrials.gov",
           total_studies: length(studies),
           date_field: "startDateStruct"
         }
       }}
    end
  end

  def build(studies, %{viz_type: :network_graph, edge_type: edge_type} = intent) do
    data =
      studies
      |> Enum.flat_map(fn study ->
        citation = citation_for(study)
        extract_edges(study, edge_type) |> Enum.map(fn {s, t} -> {{s, t}, citation} end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {{source, target}, citations} ->
        %{
          "source" => source,
          "target" => target,
          "weight" => length(citations),
          "citations" => citations
        }
      end)
      |> Enum.sort_by(& &1["weight"], :desc)

    if data == [] do
      {:error, :empty_result}
    else
      {source_label, target_label} = edge_labels(edge_type)
      title = build_title(intent[:subject], "Treatment Network")

      {:ok,
       %{
         type: "network_graph",
         title: title,
         encoding: %{
           source: %{field: "source", label: source_label, type: "categorical"},
           target: %{field: "target", label: target_label, type: "categorical"},
           weight: %{field: "weight", label: "Number of Trials", type: "quantitative"}
         },
         data: data,
         meta: %{
           source: "clinicaltrials.gov",
           total_studies: length(studies),
           edge_type: Atom.to_string(edge_type)
         }
       }}
    end
  end

  def build(studies, %{viz_type: :scatter_plot} = intent) do
    data =
      studies
      |> Enum.filter(fn s ->
        get_in(s, ["protocolSection", "designModule", "enrollmentInfo", "count"]) != nil and
          get_in(s, ["protocolSection", "statusModule", "startDateStruct", "date"]) not in [
            nil,
            ""
          ]
      end)
      |> Enum.map(fn study ->
        date = get_in(study, ["protocolSection", "statusModule", "startDateStruct", "date"])
        {year, _} = Integer.parse(String.slice(date, 0, 4))

        %{
          "start_year" => year,
          "enrollment" =>
            get_in(study, ["protocolSection", "designModule", "enrollmentInfo", "count"]),
          "nct_id" => get_in(study, ["protocolSection", "identificationModule", "nctId"]),
          "label" => get_in(study, ["protocolSection", "identificationModule", "briefTitle"])
        }
        |> maybe_add_color(study, intent[:color_by])
      end)

    if data == [] do
      {:error, :empty_result}
    else
      title = build_title(intent[:subject], "by Enrollment")

      encoding =
        %{
          x: %{field: "start_year", label: "Start Year", type: "quantitative"},
          y: %{field: "enrollment", label: "Enrollment", type: "quantitative"}
        }
        |> maybe_add_color_encoding(intent[:color_by])

      {:ok,
       %{
         type: "scatter_plot",
         title: title,
         encoding: encoding,
         data: data,
         meta: %{source: "clinicaltrials.gov", total_studies: length(studies)}
       }}
    end
  end

  defp maybe_add_color(point, _study, nil), do: point

  defp maybe_add_color(point, study, "phase") do
    phases = get_in(study, ["protocolSection", "designModule", "phases"]) || []
    Map.put(point, "phase", Enum.join(phases, "/"))
  end

  defp maybe_add_color(point, study, "status") do
    Map.put(point, "status", get_in(study, ["protocolSection", "statusModule", "overallStatus"]))
  end

  defp maybe_add_color_encoding(encoding, nil), do: encoding

  defp maybe_add_color_encoding(encoding, color_by) do
    label = color_by |> String.replace("_", " ") |> String.capitalize()
    Map.put(encoding, :color, %{field: color_by, label: label, type: "categorical"})
  end

  defp edge_labels(:condition_to_intervention), do: {"Condition", "Intervention"}
  defp edge_labels(:condition_to_sponsor), do: {"Condition", "Sponsor"}

  defp extract_edges(study, :condition_to_intervention) do
    conditions = get_in(study, ["protocolSection", "conditionsModule", "conditions"]) || []

    interventions =
      (get_in(study, ["protocolSection", "armsInterventionsModule", "interventions"]) || [])
      |> Enum.map(& &1["name"])
      |> Enum.reject(&is_nil/1)

    for c <- conditions, i <- interventions, do: {c, i}
  end

  defp extract_edges(study, :condition_to_sponsor) do
    conditions = get_in(study, ["protocolSection", "conditionsModule", "conditions"]) || []

    sponsor =
      get_in(study, ["protocolSection", "sponsorCollaboratorsModule", "leadSponsor", "name"])

    if sponsor, do: Enum.map(conditions, &{&1, sponsor}), else: []
  end

  defp citation_for(study) do
    %{
      "nct_id" => get_in(study, ["protocolSection", "identificationModule", "nctId"]),
      "excerpt" => get_in(study, ["protocolSection", "identificationModule", "briefTitle"])
    }
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

  defp filter_by_year_range(pairs, intent) do
    pairs
    |> maybe_filter_start(intent[:start_year])
    |> maybe_filter_end(intent[:end_year])
  end

  defp maybe_filter_start(pairs, nil), do: pairs

  defp maybe_filter_start(pairs, start_year) do
    Enum.filter(pairs, fn {date_str, _study} ->
      {year, _} = Integer.parse(String.slice(date_str, 0, 4))
      year >= start_year
    end)
  end

  defp maybe_filter_end(pairs, nil), do: pairs

  defp maybe_filter_end(pairs, end_year) do
    Enum.filter(pairs, fn {date_str, _study} ->
      {year, _} = Integer.parse(String.slice(date_str, 0, 4))
      year <= end_year
    end)
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
