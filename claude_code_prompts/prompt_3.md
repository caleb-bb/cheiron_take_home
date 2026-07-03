# Make tests pass

Fill out the stubbed wrapper modules to make the tests for those modules pass.

-------------------------------------------------------------------------------


 Problem: in `dev`, the http client becomes nil. It needs to be `Req` in dev.
 
-------------------------------------------------------------------------------

iex(2)> CheironTakeHome.LLM.interpret("How many studies are there for lung cancer?")
** (Jason.DecodeError) unexpected byte at position 0: 0x60 ("`")
    (jason 1.4.5) lib/jason.ex:92: Jason.decode!/2
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/llm.ex:27: CheironTakeHome.LLM.handle_response/1
    iex:2: (file)
