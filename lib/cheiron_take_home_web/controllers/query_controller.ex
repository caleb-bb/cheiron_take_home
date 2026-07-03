defmodule CheironTakeHomeWeb.QueryController do
  use CheironTakeHomeWeb, :controller

  def create(conn, %{"query" => query}) when is_binary(query) and query != "" do
    case CheironTakeHome.Orchestrator.query(query) do
      {:ok, viz_spec} ->
        json(conn, %{visualization: viz_spec})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_error(reason)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing or empty \"query\" field"})
  end

  defp format_error(:no_search_terms), do: "Could not extract search terms from the query — try being more specific about a condition or treatment"
  defp format_error(:empty_result), do: "No data matched the query — try broadening your search terms"
  defp format_error({:unsupported_group_by, value, supported}),
    do: "Unsupported grouping \"#{value}\". Supported: #{Enum.join(supported, ", ")}"
  defp format_error({:unexpected, _}), do: "Unexpected response from upstream service"
  defp format_error(%{reason: reason}), do: "Upstream error: #{inspect(reason)}"
  defp format_error(reason), do: inspect(reason)
end
