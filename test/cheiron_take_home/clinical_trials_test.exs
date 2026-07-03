defmodule CheironTakeHome.ClinicalTrialsTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "search/1" do
    test "sends correct query params for a condition search" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        assert opts[:url] == "https://clinicaltrials.gov/api/v2/studies"
        assert opts[:method] == :get
        assert opts[:params]["query.cond"] == "diabetes"
        assert opts[:params]["pageSize"] == 100
        assert opts[:params]["format"] == "json"

        {:ok,
         %{
           status: 200,
           body: %{
             "totalCount" => 1,
             "studies" => [
               %{
                 "protocolSection" => %{
                   "identificationModule" => %{
                     "nctId" => "NCT00000001",
                     "briefTitle" => "Test Trial"
                   },
                   "statusModule" => %{"overallStatus" => "COMPLETED"},
                   "designModule" => %{"phases" => ["PHASE3"]}
                 }
               }
             ]
           }
         }}
      end)

      params = %{query_cond: "diabetes", page_size: 100}
      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(params)
      assert is_list(studies)
      assert length(studies) == 1
    end

    test "sends correct query params for an intervention search" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        assert opts[:params]["query.intr"] == "Pembrolizumab"

        {:ok,
         %{
           status: 200,
           body: %{
             "totalCount" => 2,
             "studies" => [
               %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT00000002"}}},
               %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT00000003"}}}
             ]
           }
         }}
      end)

      params = %{query_intr: "Pembrolizumab"}
      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(params)
      assert length(studies) == 2
    end

    test "returns error on API failure" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:error, %{reason: :timeout}}
      end)

      assert {:error, _reason} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "anything"})
    end

    test "returns error on 400 bad request" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok, %{status: 400, body: "`filter.phase` is unknown parameter"}}
      end)

      assert {:error, %{reason: reason}} =
               CheironTakeHome.ClinicalTrials.search(%{query_cond: "anything"})

      assert reason =~ "400"
    end

    test "returns error on 404 not found" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok, %{status: 404, body: "Not Found"}}
      end)

      assert {:error, %{reason: reason}} =
               CheironTakeHome.ClinicalTrials.search(%{query_cond: "anything"})

      assert reason =~ "404"
    end

    test "returns error on 500 internal server error" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok, %{status: 500, body: "Internal Server Error"}}
      end)

      assert {:error, %{reason: reason}} =
               CheironTakeHome.ClinicalTrials.search(%{query_cond: "anything"})

      assert reason =~ "500"
    end

    test "returns error on 503 service unavailable" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok, %{status: 503, body: "Service Unavailable"}}
      end)

      assert {:error, %{reason: reason}} =
               CheironTakeHome.ClinicalTrials.search(%{query_cond: "anything"})

      assert reason =~ "503"
    end
  end

  describe "search/1 pagination" do
    test "fetches multiple pages when nextPageToken is present" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT001"}}}
             ],
             "nextPageToken" => "token_page2"
           }
         }}
      end)
      |> expect(:request, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT002"}}}
             ]
           }
         }}
      end)

      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "cancer"})
      assert length(studies) == 2

      nct_ids =
        Enum.map(studies, &get_in(&1, ["protocolSection", "identificationModule", "nctId"]))

      assert "NCT001" in nct_ids
      assert "NCT002" in nct_ids
    end

    test "sends pageToken param on subsequent requests" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn opts ->
        refute Map.has_key?(opts[:params], "pageToken")

        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [%{"protocolSection" => %{}}],
             "nextPageToken" => "abc123"
           }
         }}
      end)
      |> expect(:request, fn opts ->
        assert opts[:params]["pageToken"] == "abc123"

        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [%{"protocolSection" => %{}}]
           }
         }}
      end)

      assert {:ok, _studies} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "cancer"})
    end

    test "stops at max pages even if nextPageToken keeps coming" do
      # Expect exactly 5 requests (max_pages), not 6
      CheironTakeHome.MockHttpClient
      |> expect(:request, 5, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [%{"protocolSection" => %{}}],
             "nextPageToken" => "keep_going"
           }
         }}
      end)

      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "cancer"})
      assert length(studies) == 5
    end

    test "makes only one request when no nextPageToken" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [
               %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT001"}}},
               %{"protocolSection" => %{"identificationModule" => %{"nctId" => "NCT002"}}}
             ]
           }
         }}
      end)

      assert {:ok, studies} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "cancer"})
      assert length(studies) == 2
    end

    test "returns error if a subsequent page fails" do
      CheironTakeHome.MockHttpClient
      |> expect(:request, fn _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "studies" => [%{"protocolSection" => %{}}],
             "nextPageToken" => "page2"
           }
         }}
      end)
      |> expect(:request, fn _opts ->
        {:ok, %{status: 500, body: "Internal Server Error"}}
      end)

      assert {:error, _reason} = CheironTakeHome.ClinicalTrials.search(%{query_cond: "cancer"})
    end
  end
end
