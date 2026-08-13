# MQS local prompt-training example

This example demonstrates how to refine a private MQS prompt without changing
the installed package. It contains three open PDF articles, a reviewed
`ideal.csv`, and a local copy of the MQS prompt registry.

Open `Run.R` directly from this `examples/training_mqs_1` folder and run it in
RStudio after configuring an API key. The script detects the example folder
automatically. If RStudio has no saved active-document path, set the working
directory to `examples/training_mqs_1` before running it. The provider and model
are defined explicitly near the top of `Run.R`. The script performs two prompt
improvement cycles:

1. It evaluates the original prompt as `iteration_1`.
2. It creates `prompt_proposal_2.md` from the comparison and audit reasons.
3. It evaluates that proposal as `iteration_2`.
4. It creates `prompt_proposal_3.md` from the second iteration for later review.

The provider, model, and scale are defined directly in the script:

```r
provider <- "openai"
model <- "gpt-4.1-mini"
scale <- "mqs"
```

The original prompt is preserved as `prompt_iteration_1.md`. The generated
proposals are not silently treated as scientifically validated; inspect them
before using them in a future iteration.

The decision files are written in the example folder:

```text
comparison_iteration_1.csv
comparison_summary_iteration_1.csv
comparison_iteration_2.csv
comparison_summary_iteration_2.csv
```

The detailed files show the obtained and ideal score for every article and
item. The summary files show the number of correct items and accuracy for each
completed iteration. The audit logs inside each `iterations/iteration_N/`
directory contain the evidence and reasons used by the model.

Use `compare_training_iterations()` to compare all completed iterations with
`ideal.csv`. Generated Markdown caches and results remain local and are not
part of the source example.

To obtain a proposed prompt revision from the latest comparison and audit
reasons, use `propose_prompt_revision()`. It returns text for human review and
does not overwrite the local prompt or rerun the articles.

To save it directly as a separate file:

```r
proposal <- propose_prompt_revision(
  prompt_path = "scales/mqs/openai-generic/prompt.md",
  comparison = "comparison.csv",
  reason_files = list.files("iterations/iteration_1", pattern = "_AuditLog\\.txt$",
    full.names = TRUE, recursive = TRUE),
  provider = "openai", model = "gpt-4.1-mini",
  output_path = "scales/mqs/openai-generic/prompt_proposal.md"
)
```
