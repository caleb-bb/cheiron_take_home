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


## Actual Changes
#### Thu Jul  2 21:55:09 2026

This is where I'm recording the actual changes I make and hand off to Claude Code, which is how I'll write most of this. I burned the first 4 hours of development time on planning, research, and architecting. If done correctly, the actual implementation will be the shorter part. I did this by talking to Claude Code about what I wanted it to do in chat, having it generate prompts, feeding those prompts into Claude Code. You can find the prompts I generated under `/claude_code_prompts`.

How do I link to another file in markdown?
To link to another file in markdown, you can use the following syntax:

Replace "Link Text" with the text you want to display as the link, and "path/to/another/file" with the relative or absolute path to the file you want to link to.

### [Prompt 1](claude_code_prompts/prompt_1.md)

We're gonna need `Req` for http requests, `Mox` for mocking API calls, `stream_data` for property testing, and `nimble_options` because I created this repo with Ecto to validate things.  This is the kind of boilerplate busywork that LLMs are for: stub out modules and tests, add dependencies, run CLI commands.

### [Prompt 2](claude_code_prompts/prompt_2.md)

This prompt creates the failing tests for the API wrapper modules. There will be another prompt to make the tests pass. At that point, I'm going to pause prompting in order to stop and test the API modules in-terminal. If everything shakes out ok, then I'll move on. But if the API responses have unexpected shapes, I'll copy the shape of the responses into Claude Chat, ask for new prompts to fix the tests based on those, run those prompts to revise the tests, allow the tests to fail, and then prompt Claude Code to modify the wrapper modules so that those tests will pass.

### [Prompt 3](claude_code_prompts/prompt_3.md)

See above. This is a series of prompts that I gave to Claude Code as a result of it screwing up the modules.

I tested the http client in an `iex` REPL session and it's a good thing I did because it defaults to `nil` in a dev environment which is pants-on-head stupid. After we fixed that, I got this error:

```elixir
iex(1)> CheironTakeHome.LLM.interpret("How many studies are there for lung cancer?")
** (Jason.DecodeError) unexpected byte at position 0: 0x60 ("`")
    (jason 1.4.5) lib/jason.ex:92: Jason.decode!/2
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/llm.ex:27: CheironTakeHome.LLM.handle_response/1
    iex:1: (file)
```

which I fed to Claude Code without commentary. It seems to be working in the REPL now! Woo-hoo! Tests and modules for the API wrappers are up and working! Trials API. The next step is bar chart and time series specs for the munger, which means testing for the munger.

The munger itself will define the viz_specs as hardcoded functions returning maps. I would make those sub-modules like CheironTakeHome.Munger.BarChart​ and define them with a defmodule​ statement inside of the 

### [Prompt 4](claude_code_prompts/prompt_4.md)

Created munger tests. But they only assert traceability to data points returned by the ClinicalTrials API. They don't force the data to actually be something the front-end can render.

### [Prompt 5](claude_code_prompts/prompt_5.md)

Forces the munger test to define a shape that makes front-end rendering determinstic.

### [Prompt 6](claude_code_prompts/prompt_6.md)

These are fairly simple Claude Code prompts but they serve to detect anything very obviously wrong. These property tests enforce invariants, so getting them right gives us a leg to stand on with autogenerated code that makes them pass. Claude Code mutation-tested the properties by introducing bugs that would violate those properties and then running the tests again. For 10 mutations, all bugs were caught, so these property tests seem to be working as designed. These were the mutation tests:

  ┌─────┬─────────────────────────────────┬─────────────────────────────────────────────────────┐
  │  #  │            Mutation             │                      Caught by                      │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 1   │ BAR: phantom phase              │ "every phase in output appears in input" + "no      │
  │     │                                 │ phantom counts"                                     │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 2   │ BAR: doubled counts             │ "no phantom counts: sum of trial_counts equals      │
  │     │                                 │ input"                                              │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 3   │ BAR: missing sort key           │ "bar chart structure" (shape helper)                │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 4   │ BAR: wrong x encoding type      │ "bar chart structure" (x must be categorical)       │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 5   │ TS: phantom period "9999"       │ "every time bucket corresponds to input" + "no      │
  │     │                                 │ phantom counts"                                     │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 6   │ TS: doubled counts              │ "no phantom counts: sum equals input studies with   │
  │     │                                 │ dates"                                              │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
 ─│ 7   │ TS: reverse sort                │ "output data is sorted chronologically"             │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 8   │ TS: missing granularity         │ "time series structure" (shape helper)              │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 9   │ SHAPE: empty title              │ shape helper on both bar + time series              │
  ├─────┼─────────────────────────────────┼─────────────────────────────────────────────────────┤
  │ 10  │ COHERENCE: encoding field not   │ encoding-data coherence helper                      │
  │     │ in data                         │                                                     │
  └─────┴─────────────────────────────────┴─────────────────────────────────────────────────────┘
