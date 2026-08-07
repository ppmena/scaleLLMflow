# Three-article reference test

This test runs the three bundled MQS articles against `../ideal_results.csv`
with two providers:

- Gemini `gemini-3.5-flash-lite`.
- OpenAI `gpt-4.1-mini`.

Run it from the package directory with:

```powershell
$env:R_ENVIRON_USER = (Join-Path (Get-Location) ".Renviron")
Rscript examples/use_case_3pdf/test_reference_models/run_test_reference_models.R
```

Each provider has its own subdirectory containing prompt snapshots, complete
raw LLM responses, audit logs, scores, totals, validation sections, and errors.
The top-level `comparison_summary.csv` summarizes both runs. No API keys are
written to this test directory.
