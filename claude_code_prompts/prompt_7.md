iex(1)> CheironTakeHome.Orchestrator.query("What causes lung cancer?")
** (FunctionClauseError) no function clause matching in CheironTakeHome.Orchestrator.to_viz_type/1    
    
    The following arguments were given to CheironTakeHome.Orchestrator.to_viz_type/1:
    
        # 1
        "text_summary"
    
    Attempted function clauses (showing 2 out of 2):
    
        defp to_viz_type("bar_chart")
        defp to_viz_type("time_series")
    
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/orchestrator.ex:43: CheironTakeHome.Orchestrator.to_viz_type/1
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/orchestrator.ex:36: CheironTakeHome.Orchestrator.split_query_plan/1
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/orchestrator.ex:6: CheironTakeHome.Orchestrator.query/1
    iex:1: (file)


   why does this happen? Don't touch anything yet. Just tell me what's doing this.                  

-------------------------------------------------------------------------------

Create a hardcoded list of `viz_types` in the LLM module and make sure that they form part of the
prompt so that only one of those types can be chosen. JUST DO THAT. Nothing else yet.

-------------------------------------------------------------------------------

try it  gain [Pasted text #2 +4 lines] I got this from attempting to use the orchestrator's public function. It also seems to return the ENTIRE API RESULT FROM CLINICALTRIALS which it is no  sup osed to do. Don't make any changes yet. Just diagnose why it's returni g all the API results and also diagnose why it's throwing that error. I notice that it's passing %{group_by: "risk_factor", viz_type: :bar_chart} whhen the only `build/2` clause for :bar_chart requires that the group_by key be "risk_factor". That's wrong. It should require a `group_by` key, but it should not require the value of that key to be "risk_factor" or anything else in particular.
