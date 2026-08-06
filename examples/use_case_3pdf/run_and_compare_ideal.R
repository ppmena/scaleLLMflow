# Run the library on the example PDFs and compare predictions with ideal scores.
# Run from the project root:
# Rscript "library/scaleLLMflow/examples/use_case_3pdf/run_and_compare_ideal.R"

scale_name <- "mqs"
provider <- "gemini"
model <- "gemini-2.5-flash"
articles_dir <- file.path("library", "scaleLLMflow", "examples", "use_case_3pdf", "articles")
ideal_path <- file.path("library", "scaleLLMflow", "examples", "use_case_3pdf", "ideal_results.csv")
output_dir <- file.path("resultados", "use_case_3pdf_ideal_comparison")
item_cols <- paste0("Item_", 1:10)

if (!requireNamespace("scaleLLMflow", quietly = TRUE)) {
  install.packages(file.path("library", "scaleLLMflow"), repos = NULL, type = "source")
}
if (!nzchar(Sys.getenv("GOOGLE_GEMINI_KEY", unset = "")) &&
    !nzchar(Sys.getenv("GEMINI_API_KEY", unset = ""))) {
  stop("Missing Gemini API key. Set GOOGLE_GEMINI_KEY or GEMINI_API_KEY.", call. = FALSE)
}

library(scaleLLMflow)

run <- run_dataset(
  articles_dir = articles_dir,
  scale = scale_name,
  provider = provider,
  model = model,
  output_dir = output_dir,
  filetype = "pdf",
  strip_references = TRUE
)

predicted <- run$results
ideal <- read.csv2(ideal_path, stringsAsFactors = FALSE, check.names = FALSE)
ideal[item_cols] <- lapply(ideal[item_cols], function(x) as.numeric(sub(",", ".", x, fixed = TRUE)))
predicted[item_cols] <- lapply(predicted[item_cols], as.numeric)

comparison <- merge(predicted, ideal, by = "ID", suffixes = c("_obtained", "_ideal"))
if (nrow(comparison) == 0) stop("No article IDs matched the ideal results.", call. = FALSE)

article_metrics <- data.frame(ID = comparison$ID, stringsAsFactors = FALSE)
for (item in item_cols) {
  obtained <- comparison[[paste0(item, "_obtained")]]
  expected <- comparison[[paste0(item, "_ideal")]]
  article_metrics[[item]] <- !is.na(obtained) & !is.na(expected) & obtained == expected
}
article_metrics$Items_Correct <- rowSums(article_metrics[item_cols])
article_metrics$Items_Total <- length(item_cols)
article_metrics$Percent <- round(100 * article_metrics$Items_Correct / article_metrics$Items_Total, 1)

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

write.csv2(article_metrics, file.path(output_dir, "comparison_by_article.csv"), row.names = FALSE)
write.csv2(item_metrics, file.path(output_dir, "comparison_by_item.csv"), row.names = FALSE)
write.csv2(summary, file.path(output_dir, "comparison_summary.csv"), row.names = FALSE)

message("Comparison complete: ", summary$Total_Percent, "% total agreement")
message("Summary: ", file.path(output_dir, "comparison_summary.csv"))
