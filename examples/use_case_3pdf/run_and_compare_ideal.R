# Reproducible validation example: run the library and compare its predictions
# with the theoretical item scores stored in ideal_results.csv.
# The paths are resolved from this script's location, so it can be run from
# any working directory (including this folder or RStudio).
# Rscript "library/scaleLLMflow/examples/use_case_3pdf/run_and_compare_ideal.R"

script_file <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))[1]])
example_dir <- if (nzchar(script_file)) normalizePath(dirname(script_file), mustWork = TRUE) else getwd()
library_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
project_root <- normalizePath(file.path(library_dir, "..", ".."), mustWork = TRUE)

# Keep these settings aligned with the prompt and article set being evaluated.
# Use a new output directory for each prompt/model experiment.
scale_name <- "mqs"
provider <- "gemini"
model <- "gemini-2.5-flash"
articles_dir <- file.path(example_dir, "articles")
ideal_path <- file.path(example_dir, "ideal_results.csv")
output_dir <- file.path(project_root, "resultados", "use_case_3pdf_ideal_comparison")
item_cols <- paste0("Item_", 1:10)

# Install the local package when running from a clean checkout.
if (!requireNamespace("scaleLLMflow", quietly = TRUE)) {
  install.packages(library_dir, repos = NULL, type = "source")
}
# The key is read from the environment and is never stored in this example.
if (!nzchar(Sys.getenv("GOOGLE_GEMINI_KEY", unset = "")) &&
    !nzchar(Sys.getenv("GEMINI_API_KEY", unset = ""))) {
  stop("Missing Gemini API key. Set GOOGLE_GEMINI_KEY or GEMINI_API_KEY.", call. = FALSE)
}

library(scaleLLMflow)

# First run the LLM workflow. The result includes the consensus data frame and
# the path to the generated audit artifacts.
run <- run_dataset(
  articles_dir = articles_dir,
  scale = scale_name,
  provider = provider,
  model = model,
  output_dir = output_dir,
  filetype = "pdf",
  strip_references = TRUE
)

# Read the theoretical reference table and normalize decimal commas for R.
predicted <- run$results
ideal <- read.csv2(ideal_path, stringsAsFactors = FALSE, check.names = FALSE)
ideal[item_cols] <- lapply(ideal[item_cols], function(x) as.numeric(sub(",", ".", x, fixed = TRUE)))
predicted[item_cols] <- lapply(predicted[item_cols], as.numeric)

# Match articles by their normalized IDs, then compare every item separately.
comparison <- merge(predicted, ideal, by = "ID", suffixes = c("_obtained", "_ideal"))
if (nrow(comparison) == 0) stop("No article IDs matched the ideal results.", call. = FALSE)

# Produce one row per article with item-level agreement and an article total.
article_metrics <- data.frame(ID = comparison$ID, stringsAsFactors = FALSE)
for (item in item_cols) {
  obtained <- comparison[[paste0(item, "_obtained")]]
  expected <- comparison[[paste0(item, "_ideal")]]
  article_metrics[[item]] <- !is.na(obtained) & !is.na(expected) & obtained == expected
}
article_metrics$Items_Correct <- rowSums(article_metrics[item_cols])
article_metrics$Items_Total <- length(item_cols)
article_metrics$Percent <- round(100 * article_metrics$Items_Correct / article_metrics$Items_Total, 1)

# Aggregate the same comparison by item to reveal scale-specific weaknesses.
item_metrics <- data.frame(
  Item = item_cols,
  stringsAsFactors = FALSE
)
item_metrics$Correct <- sapply(item_cols, function(item) {
  sum(comparison[[paste0(item, "_obtained")]] == comparison[[paste0(item, "_ideal")]], na.rm = TRUE)
})
item_metrics$Evaluated <- sapply(item_cols, function(item) {
  sum(!is.na(comparison[[paste0(item, "_obtained")]]) & !is.na(comparison[[paste0(item, "_ideal")]]))
})
item_metrics$Percent <- round(100 * item_metrics$Correct / item_metrics$Evaluated, 1)

# Store run metadata with the overall agreement percentage for reproducibility.
summary <- data.frame(
  Scale = scale_name,
  Provider = provider,
  Model = model,
  Articles = nrow(article_metrics),
  Items = length(item_cols),
  Total_Correct = sum(article_metrics$Items_Correct),
  Total_Evaluated = sum(article_metrics$Items_Total),
  Total_Percent = round(100 * sum(article_metrics$Items_Correct) / sum(article_metrics$Items_Total), 1),
  stringsAsFactors = FALSE
)

# Write machine-readable reports that can be inspected or loaded into R/Python.
write.csv2(article_metrics, file.path(output_dir, "comparison_by_article.csv"), row.names = FALSE)
write.csv2(item_metrics, file.path(output_dir, "comparison_by_item.csv"), row.names = FALSE)
write.csv2(summary, file.path(output_dir, "comparison_summary.csv"), row.names = FALSE)

message("Comparison complete: ", summary$Total_Percent, "% total agreement")
message("Summary: ", file.path(output_dir, "comparison_summary.csv"))
