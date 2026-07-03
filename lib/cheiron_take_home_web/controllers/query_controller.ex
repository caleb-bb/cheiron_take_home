defmodule CheironTakeHomeWeb.QueryController do
  use CheironTakeHomeWeb, :controller

  @structured_keys ~w(condition drug_name trial_phase sponsor start_year end_year)

  def create(conn, %{"query" => query} = params) when is_binary(query) and query != "" do
    structured_fields = Map.take(params, @structured_keys)

    case validate_structured_fields(structured_fields) do
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})

      :ok ->
        structured_fields = cast_year_fields(structured_fields)

        case CheironTakeHome.Orchestrator.query(query, structured_fields) do
          {:ok, viz_spec} ->
            json(conn, %{visualization: viz_spec})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: format_error(reason)})
        end
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing or empty \"query\" field"})
  end

  @string_fields ~w(condition drug_name trial_phase sponsor)

  defp validate_structured_fields(fields) do
    with :ok <- validate_year_field(fields, "start_year"),
         :ok <- validate_year_field(fields, "end_year"),
         :ok <- validate_string_fields(fields) do
      :ok
    end
  end

  defp validate_string_fields(fields) do
    Enum.reduce_while(@string_fields, :ok, fn key, :ok ->
      case fields[key] do
        nil -> {:cont, :ok}
        val when is_binary(val) -> {:cont, :ok}
        _ -> {:halt, {:error, "Invalid #{key}: must be a string"}}
      end
    end)
  end

  defp validate_year_field(fields, key) do
    case fields[key] do
      nil ->
        :ok

      val when is_integer(val) ->
        :ok

      val when is_binary(val) ->
        case Integer.parse(val) do
          {_, ""} -> :ok
          _ -> {:error, "Invalid #{key}: must be a number"}
        end

      _ ->
        {:error, "Invalid #{key}: must be a number"}
    end
  end

  defp cast_year_fields(fields) do
    fields
    |> cast_year_field("start_year")
    |> cast_year_field("end_year")
  end

  defp cast_year_field(fields, key) do
    case fields[key] do
      nil ->
        fields

      val when is_integer(val) ->
        fields

      val when is_binary(val) ->
        {int, ""} = Integer.parse(val)
        Map.put(fields, key, int)
    end
  end

  defp format_error(:no_search_terms),
    do:
      "Could not extract search terms from the query — try being more specific about a condition or treatment"

  defp format_error(:empty_result),
    do: "No data matched the query — try broadening your search terms"

  defp format_error({:unsupported_group_by, value, supported}),
    do: "Unsupported grouping \"#{value}\". Supported: #{Enum.join(supported, ", ")}"

  defp format_error({:unexpected, _}), do: "Unexpected response from upstream service"
  defp format_error(%{reason: reason}), do: "Upstream error: #{inspect(reason)}"
  defp format_error(reason), do: inspect(reason)
end
