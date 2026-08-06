# Use Case: 3 PDFs with scaleLLMflow

This example runs the `scaleLLMflow` library on a separate folder containing 3 PDF articles.

## Contents

```text
library/scaleLLMflow/examples/use_case_3pdf/
  articles/
    2004 Miller.pdf
    2005 Scholomskas.pdf
    2007 Moyers.pdf
  run_use_case_3pdf.R
```

## Requirements

Run from the project root.

The library reads API keys from the environment:

- Gemini: `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- OpenAI/ChatGPT: `OPENAI_API_KEY`
- Optional OpenAI project: `OPENAI_PROJECT_ID`

## Execution

The parameters are fixed inside `run_use_case_3pdf.R`:

- scale: `mqs`
- provider: `gemini`
- model: `gemini-2.5-flash`
- file type: `pdf`
- article folder: `library/scaleLLMflow/examples/use_case_3pdf/articles`
- output folder: `resultados/use_case_3pdf_mqs`

```powershell
Rscript "library/scaleLLMflow/examples/use_case_3pdf/run_use_case_3pdf.R"
```

Expected output:

```text
resultados/use_case_3pdf_mqs/
  prompt_used.md
  2004_Miller_AuditLog.txt
  2005_Scholomskas_AuditLog.txt
  2007_Moyers_AuditLog.txt
  mqs_Consensus_Report.csv
```

To change provider, model, folder, or file type, edit the `USE CASE CONFIGURATION` block at the beginning of `run_use_case_3pdf.R`.

## Compare with ideal results

`ideal_results.csv` contains the theoretical expected MQS scores for the three
example articles. To run the LLM and compare the obtained scores with those
ideal results:

```powershell
Rscript "library/scaleLLMflow/examples/use_case_3pdf/run_and_compare_ideal.R"
```

The script writes the prompt snapshot, audit logs, consensus report, and these
comparison files under `resultados/use_case_3pdf_ideal_comparison/`:

- `comparison_by_article.csv`: agreement for each article and item.
- `comparison_by_item.csv`: agreement aggregated by item.
- `comparison_summary.csv`: total agreement and run metadata.

## Resume Behavior

The library does not reanalyze articles that already have a `_AuditLog.txt` file larger than 100 bytes in the output folder.
