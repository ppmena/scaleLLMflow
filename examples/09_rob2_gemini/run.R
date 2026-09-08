# Run RoB 2 on the 16 selected articles with Gemini.
library(scaleLLMflow)

example_dir <- "examples/09_rob2_gemini"
articles_dir <- file.path(example_dir, "articles")
gemini_key <- Sys.getenv("GOOGLE_GEMINI_KEY", unset = Sys.getenv("GEMINI_API_KEY", unset = ""))
stopifnot(nzchar(gemini_key))
mds <- list.files(articles_dir, pattern = "\\.md$", full.names = TRUE, ignore.case = TRUE)
stopifnot(length(mds) == 16)
run <- run_dataset(
  articles_dir = articles_dir,
  scale = "rob2",
  provider = "gemini",
  model = "gemini-3.6-flash",
  output_dir = file.path(example_dir, "results"),
  filetype = "md",
  strip_references = TRUE,
  tables_advanced = TRUE,
  conversion = "basic",
  api_key = gemini_key,
  temperature = 0,
  top_p = 0.1,
  max_retries = 3,
  retry_wait_seconds = 2,
  rate_limit_seconds = 1
)
print(run$summary)
cat("\nOutput directory:\n", run$output_dir, "\n", sep = "")
