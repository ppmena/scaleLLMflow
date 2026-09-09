# RoB 2 with ChatGPT 5.6 Luna

This example applies the registered Cochrane RoB 2 parallel-trial prompt to
the 16 Markdown articles included in the local `articles/` directory. Set
`OPENAI_API_KEY`, run `run.R` from this directory, and keep the working
directory unchanged so the relative paths resolve correctly. Results are
written to a timestamped subdirectory under `results_md_v006/`, including the
resolved prompt, prompt provenance, audit logs, evidence, consensus scores,
and any errors.

The provider is `openai`, the model is `gpt-5.6-luna`, and the registered RoB 2
prompt revision is `v006`. The example uses `filetype = "md"` and does not
convert PDFs during execution. RoB 2 has no official additive total; the
consensus report therefore keeps `Total_Score` as `NA`.

The `articles/` directory contains exactly 16 `.md` inputs. The latest
successful run produced 16 consensus rows with no errors under
`results_md_v006/`.
