# Compare Gemini Flash-Lite and OpenAI GPT-4.1 mini against MQS references.
pkgload::load_all(".", quiet = TRUE)
for (x in list(
  list(name = "gemini_flash_lite", provider = "gemini", model = "gemini-3.5-flash-lite"),
  list(name = "openai_gpt41_mini", provider = "openai", model = "gpt-4.1-mini")
)) {
  run <- scaleLLMflow::run_dataset(
    "examples/04_model_reference_comparison/articles", scale = "mqs",
    provider = x$provider, model = x$model,
    output_dir = file.path("examples/04_model_reference_comparison/results", x$name),
    filetype = "pdf", reference_csv = "examples/04_model_reference_comparison/ideal_results.csv",
    validation_mode = "reference", temperature = 0
  )
  print(run$results)
}
