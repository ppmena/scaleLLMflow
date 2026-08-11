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

For Claude, configure the API key first. The scale and model are defined
explicitly inside `examples/05_claude_free/run.R`:

```powershell
$env:ANTHROPIC_API_KEY = "your-key"
Rscript examples/05_claude_free/run.R
```

Each script writes results below its own numbered folder.

## Artículos de los ejemplos

Los ejemplos no comparten artículos. Cada carpeta contiene su propia copia de un
artículo de acceso abierto, con licencia indicada en la tabla siguiente. Se han
retirado los PDFs anteriores porque no tenían una licencia de acceso abierto
comprobable.

| Ejemplo | Archivo | Artículo | Licencia y fuente |
|---|---|---|---|
| 00 | `virtual_worlds_mi_training.pdf` | Manuel et al. (2023), *Virtual Worlds Technology to Enhance Training for Primary Care Providers in Assessment and Management of Posttraumatic Stress Disorder Using Motivational Interviewing* | CC BY 4.0; [JMIR Medical Education](https://mededu.jmir.org/2023/1/e42862/) |
| 01 | `young_people_mi_training.pdf` | Sanci et al. (2015), *Responding to Young People’s Health Risks in Primary Care* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0137581) |
| 02 | `multiple_behaviour_change_counselling.pdf` | Butler et al. (2013), *Training practitioners to deliver opportunistic multiple behaviour change counselling in primary care* | CC BY-NC; [BMJ](https://doi.org/10.1136/bmj.f1191) |
| 03 | `swedish_mi_dissemination.pdf` | Beckman et al. (2017), *The dissemination of motivational interviewing in Swedish county councils* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0181715) |
| 04 | `comon_coaching_oncology.pdf` | de Figueiredo et al. (2018), *ComOn-Coaching* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0205315) |
| 05 | `nurses_mi_training.pdf` | Persson et al. (2016), *Proficiency in Motivational Interviewing among Nurses in Child Health Services* | CC BY 4.0; [PLOS ONE](https://doi.org/10.1371/journal.pone.0163624) |

Los `ideal_results.csv` de los ejemplos 02 y 04 son fixtures de demostración
para mostrar el flujo de comparación; deben revisarse y sustituirse por
puntuaciones humanas validadas antes de usar esos ejemplos como evaluación.
