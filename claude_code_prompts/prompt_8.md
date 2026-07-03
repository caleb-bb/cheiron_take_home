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
