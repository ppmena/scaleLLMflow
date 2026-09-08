# RoB 2 with ChatGPT 5.6 Luna

This example applies the registered Cochrane RoB 2 parallel-trial prompt to
the 16 PDFs in the `Selected` meta-analysis folder. Set `OPENAI_API_KEY` and
run `run.R`. Results are written to a timestamped subdirectory under
`Selected/rob2_chatgpt56_luna_results/`, including prompt provenance, audit
logs, evidence, consensus scores, and any errors.

The provider is `openai` and the model is `gpt-5.6-luna`. RoB 2 has no official
additive total; the consensus report therefore keeps `Total_Score` as `NA`.
