defmodule CheironTakeHome.Orchestrator do
  @moduledoc "Routes user input through the pipeline: LLM interpretation, API retrieval, munging, output."

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

  @param_keys %{
    "query_cond" => :query_cond,
    "query_intr" => :query_intr,
    "query_term" => :query_term,
    "filter_phase" => :filter_phase,
    "filter_status" => :filter_status,
    "page_size" => :page_size
  }

  defp split_query_plan(query_plan) do
    api_params =
      for {k, v} <- query_plan.query_params || %{},
          atom_key = @param_keys[k],
          atom_key != nil,
          v != nil,
          into: %{} do
        {atom_key, v}
      end

    viz_intent =
      %{viz_type: to_viz_type(query_plan.viz_type)}
      |> maybe_put(:group_by, query_plan.group_by)
      |> maybe_put(:time_granularity, to_granularity(query_plan.time_granularity))

    {api_params, viz_intent}
  end

  defp to_viz_type("bar_chart"), do: :bar_chart
  defp to_viz_type("time_series"), do: :time_series

  defp to_granularity("year"), do: :year
  defp to_granularity("month"), do: :month
  defp to_granularity("quarter"), do: :quarter
  defp to_granularity(nil), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
