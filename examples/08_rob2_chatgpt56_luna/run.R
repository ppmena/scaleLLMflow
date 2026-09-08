# Run RoB 2 on the 16 selected meta-analysis articles with ChatGPT 5.6 Luna.
# Requires OPENAI_API_KEY in the environment.

library(scaleLLMflow)

articles_dir <- "C:/Users/jmenar/Downloads/transfer/DOCTORADO PSICOLOGIA/TRABAJO/20240325 META ANALISIS/BASE DE DATOS/Selected"
output_dir <- file.path(articles_dir, "rob2_chatgpt56_luna_results")

stopifnot(length(list.files(articles_dir, pattern = "\\.pdf$", full.names = TRUE,
  ignore.case = TRUE)) == 16)

run <- run_dataset(
  articles_dir = articles_dir,
  scale = "rob2",
  provider = "openai",
  model = "gpt-5.6-luna",
  output_dir = output_dir,
  filetype = "pdf",
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
