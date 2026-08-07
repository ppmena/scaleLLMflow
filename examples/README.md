# Examples

Each numbered folder is a self-contained experiment with its own local article
copies, script, and output directory:

1. `01_mqs_free`: MQS scoring without reference answers.
2. `02_mqs_reference`: MQS scoring compared with `ideal_results.csv`.
3. `03_pedro_free`: PEDro scoring without reference answers.
4. `04_model_reference_comparison`: MQS reference comparison with Gemini
   Flash-Lite and OpenAI GPT-4.1 mini.

Run scripts from the package root, for example:

```powershell
$env:R_ENVIRON_USER = (Join-Path (Get-Location) ".Renviron")
Rscript examples/03_pedro_free/run.R
```

Each script writes results below its own numbered folder.
