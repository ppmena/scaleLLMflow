# Examples

Each numbered folder is a self-contained experiment with its own local article
copies, script, and output directory:

1. `01_mqs_free`: MQS scoring without reference answers.
2. `02_mqs_reference`: MQS scoring compared with `ideal_results.csv`.
3. `03_pedro_free`: PEDro scoring without reference answers.
4. `04_model_reference_comparison`: MQS reference comparison with Gemini
   Flash-Lite and OpenAI GPT-4.1 mini.
5. `05_claude_free`: MQS or PEDro scoring with Claude via Anthropic's API.

Run scripts from the package root, for example:

```powershell
$env:R_ENVIRON_USER = (Join-Path (Get-Location) ".Renviron")
Rscript examples/03_pedro_free/run.R
```

For Claude, configure the API key first and optionally choose the scale/model:

```powershell
$env:ANTHROPIC_API_KEY = "your-key"
$env:SCALE = "mqs"
$env:CLAUDE_MODEL = "claude-sonnet-4-20250514"
Rscript examples/05_claude_free/run.R
```

Each script writes results below its own numbered folder.
