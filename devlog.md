# Development Log

(This was all typed by hand with the exception of the response fields, which were copy-pasted from a Claude Code response. I did, however, *tak to* Claude Code a lot while writing this.)

## Approach
### Thu Jul  2 17:56:01 2026

Okay, so before I make any real decisions, here's the approach:

1. Read the assignment
2. Map out the architecture at the highest level of abstraction: What's MVP? How do I get there? Do I iterate after? How and why?
3. Spec out each iteration: MVP (meets requirements), and then following versions that meet the optional parts of the assignment for a higher grade
4. Define working process. When do I write tests? how do I iterate? How should each commit look? What do I document?
5. THEN make the decision of which tech to use: repurpose CAKE, from-scratch Elixir with some cues taken from CAKE, Python
6. Take the chosen tech and execute 4 until MVP, then iterate.

## Iterations, first pass
#### Thu Jul  2 18:09:30 2026

### MVP (iteration 1)

ABSTRACTION: Users may input a string. The application returns a JSON map designating type of visualization, title, encoding for that visualization, data to be rendered, and metadata for rendering. The returned spec must be articulated well enough that the front-end can be implemented deterministically (i.e. the front end does the same thing with the same data no matter who designs it). Should support at least **2** visualization types: bar chart and time series.

ADDITIONAL DOCUMENTS: all source code, a README on installation, configuration, explanation of nontrivial design decisions, and options for further development. Also need 3 to 5 example queries with the JSON outputs for each one.

ITERATION: Look at ClinicalTrials.gov's API and map the API's capabilities to the optional requirements.

### ClinicalTrials.gov API

Talking to Claude Chat about this endpoint and also reading the docs. Priorities for this assignment are marked `!!`

The ClinicalTrials.gov API is a clean v2 REST API. The base URL is `https://clinicaltrials.gov/api/v2`. Rate limit is approx 50 requests/minute. Conforms to OpenAPI 3.0. `GET /api/2/studies` is the endpoint we'll use the most. 

#### Tyoed Query Parameters

- `query.cond` (condition/disease) !!
- `query.intr` (intervention/drug - broadly, a treament) !!
- `query.term` (full-text, fallback for anything that does not clearly decompose into `query.cond` or `query.intr`) !! 
- `query.locn` (location)
- `query.spons` (sponsor - likely not important)
- `filter.overallStatus` (RECRUITING, COMPLETED, TERMINATED, etc)
- `filter.phase` (phase of the study, PHASE1, PHASE2, EARLY_PHASE1, NA, etc, important for bar charts) !!
- `filter.ids` (for specific NCT IDs)

#### Response 

##### Core response fields

- `protocolSection` (everything lives in here)
- `identificationModule` → `nctId`, `briefTitle` (for citations, labeling)
- `statusModule` → `overallStatus`, `startDateStruct`, `completionDateStruct` (for time series and status bar charts)
- `designModule` → `phases` (for phase bar charts — this is an array, watch for multi-phase trials)
- `sponsorCollaboratorsModule` → `leadSponsor`, `collaborators` (for network graphs)
- `conditionsModule` → `conditions` (for network graphs linking drugs to diseases)
- `armsInterventionsModule` → `interventions` (for network graphs linking drugs to sponsors/conditions)
- `descriptionModule` → `briefSummary` (for deep citation excerpts)

##### Secondary priority

- `eligibilityModule` → enrollment count, age ranges, sex — could feed scatter plots (enrollment by phase, enrollment over time)
- outcomesModule → primary/secondary outcome measures — interesting for richer queries but adds parsing complexity
- `contactsLocationsModule` → locations — relevant only if you support geographic visualization

### Iteration 2

ABSTRACTION: As Iteration 1, but user input now includes a set of extra fields based on query params. The assignment is graded partially on breadth of coverage, so the more the better. Each of those fields must have names, types, and validation. They may or may not be optional. These fields must meaningfully affect what the application returns. Should support at least an **additional 2** visualization types prompted by the query parameters, e.g. network graphs for sponsors to conditions or a histogram of trial statuses.

### Iteration 3

ABSTRACTION: As Iteration 2, but now we want to support deep citations. That means that, for any given trial, we include at least an `nct_id`. No new visualization types required, although we may add citations to existing types, e.g. a mouseover of a scatterplot may show a tooltip with extra information about a given data point.

### Iteration 4

ABSTRACTION: As Iteration 3, but with an at least **moderately sexy** front-end.

## Iterations, second pass
#### Thu Jul  2 19:41:57 2026 

Given the above considerations, I'm electing to do a from-scratch project in Elixir/Phoenix. Python would be faster in a vacuum but Elixir is my strongest language. The biggest missing piece is LLM wrappers, but I've written those as part of my CAKE project anyway so I can import or quickly rewrite them. At this stage, I can do a second pass on the iterations showing how they'll be implemented in Elixir.

### MVP (Iteration 1)

This holds no state, but the processing is fairly complicated: two API wrappers, a munger, and an input layer. This holds no state so the input layer might as well be the orchestration layer as well. The LLM APi needs its own wrapper and we'll assume OpenAI at this point, although if I had more time I'd make it agnostic about which LLM platform is being used. The architecture at MVP is orchestrator/input layer → LLM wrapper → orchestrator → ClinicalStudies API wrapper → orchestrator → munger → orchestrator/output.


1. Spin up an Elixir/Phoenix project without a front-end using  `mix phx.new . --no-html --no-assets --no-ecto`.
2. Unit testing: property-based tests for the munger (specs for the spec!), mocks for API calls from both API boundary layers. No integration tests yet because we may need to split modules later on and integration tests will just slow that down. Tests for the munger must cover specs for both bar charts and time series. The property-based tests *must force traceability between the spec and the data that came back from the ClinicalTrials API!!*. TESTS MUST FAIL.
3. Build the two API wrappers, two commits, tests pass. The LLM API wrapper defines a struct that contains both the query params for the ClinicalTrials.gov API *and* the visualization choice, with a hardcoded list of allowable choices. The latter may eventually affect the former.
4. Build the munger, property tests pass.
5. Build the orchestrator. Smoke tests at most because anything else is an integration test. If we need smoke tests, build them first.

### Iteration 2

This is where the LLM wrapper earns its keep. The whole point of the LLM here is to NLP the user query into a set of params. In MVP, that's just `query.cond` and `query.intr`. In practice, that cashes out to careful prompt engineering so the LLM gives us the right params. Integration testing of live LLM use is outside the scope of this assignment; however, if I had time, I would generate a large number of LLM responses (say, 1000) periodically (say, once a week) and property-test those, with a tolerance for failures (too many fails = too many retries = fix the prompts!). This, of course, implies retry logic for LLM output if it turns out bad.

1. Revise the LLM wrapper tests to include the extra query param fields; this is the step where we define which are required and which are optional. This is where we add extra visualization types. The LLM TESTS MUST FAIL. Then, revise the wrapper to make them pass.
2. As 1, but with the ClinicalStudies wrapper. 
3. Revise the munger test to cover the two new visualization types with specs appropriate to eac. TESTS MUST FAIL. Revise the munger module to make the tests pass.
4. Integration testing. Which shakes out to "test the orchestrator"

### Iteration 3
This is where we include deep citations. Since deep citations come from the ClinicalTrials API, this means modifying the wrapper thereof.

1. Modify the struct inside of the ClinicalTrials wrapper to include `nctId` and some metadata fields TBD, and change the API calls to include that info
2. Make citations an option the user can select via some flag in the input layer
3. Modify the munger so that each visualization's data key also contains citation metadata and make sure that's returned with the visualization spec.

### Iteration 4
This is just a nice frontend. We may partially build this at the beginning anyway just to ensure that the visualization spec is easy to render.
1. DaisyUI or similar
2. Pre-made components online
3. Chatbox with rendering component at `/home`
