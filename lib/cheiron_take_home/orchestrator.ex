defmodule CheironTakeHome.Orchestrator do
  @moduledoc "Routes user input through the pipeline: LLM interpretation, API retrieval, munging, output."

  @search_keys [:query_cond, :query_intr, :query_term]

  @default_time_series_page_size 100

  def query(query_string) when is_binary(query_string) and query_string != "" do
    query(query_string, %{})
  end

  def query(""), do: {:error, :empty_query}
  def query(nil), do: {:error, :empty_query}

  def query(query_string, structured_fields)
      when is_binary(query_string) and query_string != "" and is_map(structured_fields) do
    with {:ok, query_plan} <- CheironTakeHome.LLM.interpret(query_string),
         {api_params, viz_intent} = build_intent(query_plan, structured_fields),
         :ok <- validate_search_params(api_params),
         {:ok, studies} <- CheironTakeHome.ClinicalTrials.search(api_params),
         {:ok, viz_spec} <- CheironTakeHome.Munger.build(studies, viz_intent) do
      {:ok, viz_spec}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected, other}}
    end
  end

  defp build_intent(query_plan, structured_fields) do
    {base_api_params, base_viz_intent} = split_query_plan(query_plan)

    merged_api_params =
      base_api_params
      |> merge_structured_fields(structured_fields)

    final_viz_intent =
      base_viz_intent
      |> update_subject(merged_api_params)
      |> merge_year_filters(structured_fields)

    final_api_params = ensure_page_size(merged_api_params, final_viz_intent)

    {final_api_params, final_viz_intent}
  end

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

    viz_type = to_viz_type(query_plan.viz_type)

    viz_intent =
      %{viz_type: viz_type}
      |> maybe_put(:group_by, query_plan.group_by)
      |> maybe_put(:time_granularity, to_granularity(query_plan.time_granularity))
      |> maybe_put(:edge_type, to_edge_type(query_plan[:edge_type]))
      |> maybe_put(:subject, subject)
      |> ensure_defaults(viz_type)

    {api_params, viz_intent}
  end

  defp ensure_defaults(viz_intent, :time_series) do
    Map.put_new(viz_intent, :time_granularity, :year)
  end

  defp ensure_defaults(viz_intent, :network_graph) do
    Map.put_new(viz_intent, :edge_type, :condition_to_intervention)
  end

  defp ensure_defaults(viz_intent, _), do: viz_intent

  defp to_viz_type("bar_chart"), do: :bar_chart
  defp to_viz_type("time_series"), do: :time_series
  defp to_viz_type("network_graph"), do: :network_graph

  defp to_edge_type("condition_to_intervention"), do: :condition_to_intervention
  defp to_edge_type("condition_to_sponsor"), do: :condition_to_sponsor
  defp to_edge_type(nil), do: nil

  defp to_granularity("yearly"), do: :year
  defp to_granularity("year"), do: :year
  defp to_granularity("month"), do: :month
  defp to_granularity("quarter"), do: :quarter
  defp to_granularity(nil), do: nil

  defp ensure_page_size(api_params, %{viz_type: :time_series}) do
    Map.put_new(api_params, :page_size, @default_time_series_page_size)
  end

  defp ensure_page_size(api_params, %{viz_type: :network_graph}) do
    Map.put_new(api_params, :page_size, @default_time_series_page_size)
  end

  defp ensure_page_size(api_params, _viz_intent), do: api_params

  defp validate_search_params(api_params) do
    if Enum.any?(@search_keys, &Map.has_key?(api_params, &1)),
      do: :ok,
      else: {:error, :no_search_terms}
  end

  @structured_field_mapping %{
    "condition" => :query_cond,
    "drug_name" => :query_intr,
    "trial_phase" => :filter_phase,
    "sponsor" => :query_term
  }

  defp merge_structured_fields(api_params, structured_fields) do
    Enum.reduce(@structured_field_mapping, api_params, fn {user_key, api_key}, acc ->
      case structured_fields[user_key] do
        nil -> acc
        value -> Map.put(acc, api_key, value)
      end
    end)
  end

  defp update_subject(viz_intent, api_params) do
    case api_params[:query_cond] || api_params[:query_intr] || api_params[:query_term] do
      nil -> viz_intent
      subject -> Map.put(viz_intent, :subject, subject)
    end
  end

  defp merge_year_filters(viz_intent, structured_fields) do
    viz_intent
    |> maybe_put(:start_year, structured_fields["start_year"])
    |> maybe_put(:end_year, structured_fields["end_year"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
