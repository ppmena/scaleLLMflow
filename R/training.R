#' Compare local prompt-training iterations with a reviewed answer key.
#'
#' Each iteration directory must contain one timestamped `*_Consensus_Report.csv`
#' produced by [run_dataset()]. The answer key must contain an `ID` column and
#' columns named `IT01`, `IT02`, etc., or another `IT`-prefixed item scheme.
#'
#' @param ideal_csv Path to the reviewed answer-key CSV.
#' @param iterations_dir Directory containing `iteration_1`, `iteration_2`, etc.
#' @return A list with `comparison` (item-level rows) and `summary` (accuracy by
#'   iteration).
#' @export
compare_training_iterations <- function(ideal_csv, iterations_dir) {
  if (!file.exists(ideal_csv)) stop("Answer key not found: ", ideal_csv, call. = FALSE)
  if (!dir.exists(iterations_dir)) stop("Iterations directory not found: ", iterations_dir, call. = FALSE)
  ideal <- utils::read.csv2(ideal_csv, check.names = FALSE, stringsAsFactors = FALSE)
  if (!"ID" %in% names(ideal)) stop("ideal_csv must contain an ID column.", call. = FALSE)
  ideal_items <- grep("^IT[0-9]+", names(ideal), value = TRUE)
  if (length(ideal_items) == 0) stop("ideal_csv must contain IT-prefixed item columns.", call. = FALSE)
  iteration_dirs <- sort(list.dirs(iterations_dir, full.names = TRUE, recursive = FALSE))
  rows <- list()
  for (iteration_dir in iteration_dirs) {
    report <- list.files(iteration_dir, pattern = "_Consensus_Report\\.csv$", full.names = TRUE, recursive = TRUE)
    if (length(report) != 1) next
    obtained <- utils::read.csv2(report, check.names = FALSE, stringsAsFactors = FALSE)
    for (j in seq_len(nrow(ideal))) {
      for (k in seq_along(ideal_items)) {
        obtained_col <- paste0("Item_", k)
        if (!obtained_col %in% names(obtained) || j > nrow(obtained)) next
        expected <- as.numeric(ideal[[ideal_items[[k]]]][[j]])
        actual <- as.numeric(obtained[[obtained_col]][[j]])
        rows[[length(rows) + 1L]] <- data.frame(
          Iteration = basename(iteration_dir), ID = ideal$ID[[j]], Item = k,
          Obtained = actual, Ideal = expected, Correct = !is.na(actual) && !is.na(expected) && actual == expected,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  comparison <- if (length(rows)) do.call(rbind, rows) else data.frame()
  summary <- if (nrow(comparison)) {
    groups <- split(comparison$Correct, comparison$Iteration)
    do.call(rbind, lapply(names(groups), function(name) {
      values <- groups[[name]]
      data.frame(Iteration = name, Correct = sum(values), Total = length(values),
        Accuracy = mean(values), stringsAsFactors = FALSE)
    }))
  } else data.frame()
  list(comparison = comparison, summary = summary)
}
