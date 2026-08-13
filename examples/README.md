# Examples

The examples are numbered in execution order. Each folder is self-contained
and includes its own script and article files.

| Folder | Purpose |
|---|---|
| `01_simple_example` | Minimal dataset workflow using one local article. |
| `02_mqs_free` | MQS scoring without reference answers. |
| `03_mqs_reference` | MQS scoring compared with `ideal_results.csv`. |
| `04_pedro_free` | PEDro scoring without reference answers. |
| `05_model_reference_comparison` | Compare Gemini Flash-Lite and OpenAI GPT-4.1 mini against MQS references. |
| `06_claude_free` | MQS or PEDro scoring with Claude through Anthropic's API. |
| `07_training_mqs_1` | Two-iteration local MQS prompt-refinement workflow with `ideal.csv`. |

## Running examples

Open the relevant `run.R` or `Run.R` file in RStudio and run it from the
package project. For example:

```powershell
$env:R_ENVIRON_USER = (Join-Path (Get-Location) ".Renviron")
Rscript examples/04_pedro_free/run.R
```

For the Claude example, configure an Anthropic key first. The provider and
model are defined inside the script:

```powershell
$env:ANTHROPIC_API_KEY = "your-key"
Rscript examples/06_claude_free/run.R
```

The training example is intended to be opened directly in RStudio:

```text
examples/07_training_mqs_1/Run.R
```

It uses a private local prompt registry, runs two prompt-improvement cycles,
and writes comparison files and prompt proposals locally. It does not modify
the package registry.

## Open-access articles

The examples keep their own article copies. The following table records the
source and licence for the bundled PDFs.

| Example | Article file | Article | Licence and source |
|---|---|---|---|
| 01 | `virtual_worlds_mi_training.pdf` | Manuel et al. (2023), *Virtual Worlds Technology to Enhance Training for Primary Care Providers in Assessment and Management of Posttraumatic Stress Disorder Using Motivational Interviewing* | CC BY 4.0; [JMIR Medical Education](https://mededu.jmir.org/2023/1/e42862/) |
| 02 | `young_people_mi_training.pdf` | Sanci et al. (2015), *Responding to Young People’s Health Risks in Primary Care* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0137581) |
| 03 | `multiple_behaviour_change_counselling.pdf` | Butler et al. (2013), *Training practitioners to deliver opportunistic multiple behaviour change counselling in primary care* | CC BY-NC; [BMJ](https://doi.org/10.1136/bmj.f1191) |
| 04 | `swedish_mi_dissemination.pdf` | Beckman et al. (2017), *The dissemination of motivational interviewing in Swedish county councils* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0181715) |
| 05 | `comon_coaching_oncology.pdf` | de Figueiredo et al. (2018), *ComOn-Coaching* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0205315) |
| 06 | `nurses_mi_training.pdf` | Persson et al. (2016), *Proficiency in Motivational Interviewing among Nurses in Child Health Services* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0163624) |
| 07 | `2004 Miller.pdf`, `2005 Scholomskas.pdf`, `2007 Moyers.pdf` | MQS prompt-training articles | Training fixtures included for the reproducible example; review their source and reuse conditions before redistribution. |

The `ideal_results.csv` files in examples 03 and 05 are demonstration fixtures.
They should be replaced with human-validated scores before using those
examples as an evaluation.
