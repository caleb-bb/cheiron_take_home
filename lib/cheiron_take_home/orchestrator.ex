defmodule CheironTakeHome.Orchestrator do
  @moduledoc "Routes user input through the pipeline: LLM interpretation, API retrieval, munging, output."

  @search_keys [:query_cond, :query_intr, :query_term]

  @default_time_series_page_size 100

  def query(query_string) when is_binary(query_string) and query_string != "" do
    with {:ok, query_plan} <- CheironTakeHome.LLM.interpret(query_string),
         {api_params, viz_intent} <- split_query_plan(query_plan),
         :ok <- validate_search_params(api_params),
         api_params = ensure_page_size(api_params, viz_intent),
         {:ok, studies} <- CheironTakeHome.ClinicalTrials.search(api_params),
         {:ok, viz_spec} <- CheironTakeHome.Munger.build(studies, viz_intent) do
      {:ok, viz_spec}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected, other}}
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

    subject = api_params[:query_cond] || api_params[:query_intr] || api_params[:query_term]

    viz_intent =
      %{viz_type: to_viz_type(query_plan.viz_type)}
      |> maybe_put(:group_by, query_plan.group_by)
      |> maybe_put(:time_granularity, to_granularity(query_plan.time_granularity))
      |> maybe_put(:subject, subject)

    {api_params, viz_intent}
  end

  defp to_viz_type("bar_chart"), do: :bar_chart
  defp to_viz_type("time_series"), do: :time_series

  defp to_granularity("yearly"), do: :year
  defp to_granularity("year"), do: :year
  defp to_granularity("month"), do: :month
  defp to_granularity("quarter"), do: :quarter
  defp to_granularity(nil), do: nil

  defp ensure_page_size(api_params, %{viz_type: :time_series}) do
    Map.put_new(api_params, :page_size, @default_time_series_page_size)
  end

  defp ensure_page_size(api_params, _viz_intent), do: api_params

  defp validate_search_params(api_params) do
    if Enum.any?(@search_keys, &Map.has_key?(api_params, &1)),
      do: :ok,
      else: {:error, :no_search_terms}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
