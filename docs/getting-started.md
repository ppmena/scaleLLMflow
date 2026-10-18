# Getting started

Build and install from the package root with `R CMD build .` followed by `R CMD INSTALL scaleLLMflow_0.4.3.tar.gz`. Configure one provider credential in `.Renviron` or the operating-system environment, never in Git.

Load the package, inspect `available_scales()` and `available_provider_models("gemini")`, then call `run_article()` with an article path, scale, provider, model, and `filetype = "pdf"`. This performs a real provider call, so confirm cost and terms first.

Use `run_dataset()` for a directory and `reference_csv` when reviewed scores are available. See [results](results.md) before interpreting outputs.
