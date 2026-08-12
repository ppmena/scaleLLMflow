# MQS local prompt-training example

This example demonstrates how to refine a private MQS prompt without changing
the installed package. It contains three open PDF articles, a reviewed
`ideal.csv`, and a local copy of the MQS prompt registry.

Run `Run.R` from RStudio after configuring an API key. The default uses
OpenAI/gpt-4.1-mini; Gemini can be selected with:

```r
Sys.setenv(TRAINING_PROVIDER = "gemini")
Sys.setenv(TRAINING_MODEL = "gemini-3.6-flash")
```

The first run writes `iterations/iteration_1`. To run another prompt version,
edit `scales/mqs/openai-generic/prompt.md`, update `metadata.json`, and set:

```r
Sys.setenv(TRAINING_ITERATION = "iteration_2")
source("Run.R")
```

Use `compare_training_iterations()` to compare all completed iterations with
`ideal.csv`. Generated Markdown caches and results remain local and are not
part of the source example.
