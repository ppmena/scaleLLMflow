# Run MQS and compare with the local ideal reference scores.
pkgload::load_all(".", quiet = TRUE)
run <- scaleLLMflow::run_dataset(
  "examples/02_mqs_reference/articles", scale = "mqs", provider = "gemini",
  model = "gemini-3.6-flash", output_dir = "examples/02_mqs_reference/results",
  filetype = "pdf", reference_csv = "examples/02_mqs_reference/ideal_results.csv",
  validation_mode = "reference", temperature = 0
)
print(run$results)
