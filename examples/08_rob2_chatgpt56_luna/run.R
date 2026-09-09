# Run RoB 2 on the 16 selected meta-analysis articles with ChatGPT 5.6 Luna.
# Requires OPENAI_API_KEY in the environment.

library(scaleLLMflow)

articles_dir <- "articles"
output_dir <- "results_md_v006"

stopifnot(length(list.files(articles_dir, pattern = "\\.md$", full.names = TRUE,
  ignore.case = TRUE)) == 16)

run <- run_dataset(
  articles_dir = articles_dir,
  scale = "rob2",
  provider = "openai",
  model = "gpt-5.6-luna",
  output_dir = output_dir,
  filetype = "md",
  strip_references = TRUE,
  tables_advanced = TRUE,
  conversion = "basic",
  temperature = 0,
  reasoning_effort = "medium",
  max_retries = 3,
  retry_wait_seconds = 2,
  rate_limit_seconds = 1
)

print(run$summary)
cat("\nOutput directory:\n", run$output_dir, "\n", sep = "")
