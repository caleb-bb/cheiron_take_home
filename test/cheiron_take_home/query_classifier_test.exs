defmodule CheironTakeHome.QueryClassifierTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias CheironTakeHome.QueryClassifier

  @phase_synonyms ["by phase", "phase breakdown", "phases", "per phase", "phase distribution"]
  @status_synonyms ["by status", "status breakdown", "recruiting status", "per status"]
  @time_synonyms ["over time", "trend", "timeline", "history", "changed over"]
  @network_synonyms ["drugs", "treatments", "therapy", "interventions", "medications"]
  @scatter_synonyms ["individual", "enrollment", "per trial", "each trial", "per study"]

  @all_synonyms @phase_synonyms ++
                  @status_synonyms ++
                  @time_synonyms ++
                  @network_synonyms ++
                  @scatter_synonyms

  defp query_with_keyword(keywords) do
    gen all(
          keyword <- member_of(keywords),
          prefix <- string(:alphanumeric, min_length: 0, max_length: 15),
          suffix <- string(:alphanumeric, min_length: 0, max_length: 15)
        ) do
      String.trim("#{prefix} #{keyword} #{suffix}")
    end
  end

  defp query_without_keywords do
    gen all(n <- integer(1..99_999)) do
      "info #{n}"
    end
  end

  describe "synonym consistency" do
    property "any phase synonym + condition → bar_chart by phase" do
      check all(
              query <- query_with_keyword(@phase_synonyms),
              condition <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, plan} = QueryClassifier.classify(query, %{"condition" => condition})
        assert plan.viz_type == "bar_chart"
        assert plan.group_by == "phase"
      end
    end

    property "any status synonym + condition → bar_chart by status" do
      check all(
              query <- query_with_keyword(@status_synonyms),
              condition <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, plan} = QueryClassifier.classify(query, %{"condition" => condition})
        assert plan.viz_type == "bar_chart"
        assert plan.group_by == "status"
      end
    end

    property "any time synonym + drug_name → time_series" do
      check all(
              query <- query_with_keyword(@time_synonyms),
              drug <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, plan} = QueryClassifier.classify(query, %{"drug_name" => drug})
        assert plan.viz_type == "time_series"
        assert plan.time_granularity == "yearly"
      end
    end

    property "any network synonym + condition → network_graph" do
      check all(
              query <- query_with_keyword(@network_synonyms),
              condition <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, plan} = QueryClassifier.classify(query, %{"condition" => condition})
        assert plan.viz_type == "network_graph"
        assert plan.edge_type == "condition_to_intervention"
      end
    end

    property "any scatter synonym + condition → scatter_plot" do
      check all(
              query <- query_with_keyword(@scatter_synonyms),
              condition <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, plan} = QueryClassifier.classify(query, %{"condition" => condition})
        assert plan.viz_type == "scatter_plot"
      end
    end
  end

  describe "structured field gating" do
    property "phase keyword without condition → :no_match" do
      check all(
              query <- query_with_keyword(@phase_synonyms),
              drug <- string(:alphanumeric, min_length: 1)
            ) do
        assert :no_match = QueryClassifier.classify(query, %{"drug_name" => drug})
      end
    end

    property "time keyword without drug_name → :no_match" do
      check all(
              query <- query_with_keyword(@time_synonyms),
              condition <- string(:alphanumeric, min_length: 1)
            ) do
        assert :no_match = QueryClassifier.classify(query, %{"condition" => condition})
      end
    end

    property "empty structured fields → always :no_match" do
      check all(query <- query_with_keyword(@all_synonyms)) do
        assert :no_match = QueryClassifier.classify(query, %{})
      end
    end
  end

  describe "no-match fallback" do
    property "unrecognized query text → :no_match" do
      check all(
              query <- query_without_keywords(),
              condition <- string(:alphanumeric, min_length: 1)
            ) do
        assert :no_match = QueryClassifier.classify(query, %{"condition" => condition})
      end
    end
  end

  describe "edge cases" do
    test "case insensitive: uppercase keywords match" do
      assert {:ok, plan} = QueryClassifier.classify("SHOW PHASES", %{"condition" => "cancer"})
      assert plan.viz_type == "bar_chart"
      assert plan.group_by == "phase"
    end

    test "case insensitive: mixed case keywords match" do
      assert {:ok, plan} =
               QueryClassifier.classify("Timeline of trials", %{"drug_name" => "Aspirin"})

      assert plan.viz_type == "time_series"
    end

    test "returns plan with all required keys" do
      assert {:ok, plan} = QueryClassifier.classify("trials by phase", %{"condition" => "cancer"})
      assert Map.has_key?(plan, :viz_type)
      assert Map.has_key?(plan, :query_params)
      assert Map.has_key?(plan, :group_by)
      assert Map.has_key?(plan, :time_granularity)
      assert Map.has_key?(plan, :edge_type)
      assert Map.has_key?(plan, :color_by)
    end

    test "ambiguous query: time keyword wins over network when drug_name present" do
      # "drug trend" contains "drug" (network) and "trend" (time)
      assert {:ok, plan} =
               QueryClassifier.classify("drug trend", %{
                 "condition" => "cancer",
                 "drug_name" => "Aspirin"
               })

      assert plan.viz_type == "time_series"
    end
  end
end
