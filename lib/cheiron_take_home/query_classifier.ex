defmodule CheironTakeHome.QueryClassifier do
  @moduledoc "Deterministic query classification from structured fields + keyword matching."

  @plan_base %{
    viz_type: nil,
    query_params: %{},
    group_by: nil,
    time_granularity: nil,
    edge_type: nil,
    color_by: nil
  }

  @phase_keywords ["by phase", "phase breakdown", "phases", "per phase", "phase distribution"]
  @status_keywords ["by status", "status breakdown", "recruiting status", "per status"]
  @time_keywords ["over time", "trend", "timeline", "history", "changed over"]
  @network_keywords [
    "drugs",
    "drug",
    "treatments",
    "treat",
    "therapy",
    "interventions",
    "medications"
  ]
  @scatter_keywords ["individual", "enrollment", "per trial", "each trial", "per study"]

  def classify(query_string, structured_fields) do
    q = String.downcase(query_string)
    has_condition = is_binary(structured_fields["condition"])
    has_drug = is_binary(structured_fields["drug_name"])

    cond do
      has_condition and matches?(q, @phase_keywords) ->
        {:ok, %{@plan_base | viz_type: "bar_chart", group_by: "phase"}}

      has_condition and matches?(q, @status_keywords) ->
        {:ok, %{@plan_base | viz_type: "bar_chart", group_by: "status"}}

      has_drug and matches?(q, @time_keywords) ->
        {:ok, %{@plan_base | viz_type: "time_series", time_granularity: "yearly"}}

      has_condition and matches?(q, @network_keywords) ->
        {:ok, %{@plan_base | viz_type: "network_graph", edge_type: "condition_to_intervention"}}

      has_condition and matches?(q, @scatter_keywords) ->
        {:ok, %{@plan_base | viz_type: "scatter_plot"}}

      true ->
        :no_match
    end
  end

  defp matches?(query, keywords) do
    Enum.any?(keywords, &String.contains?(query, &1))
  end
end
