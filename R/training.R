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

#' Propose a revised prompt from the results of a training iteration.
#'
#' This function does not modify files, execute articles, or replace the
#' current prompt. It asks the selected provider to propose a complete revised
#' prompt using the current prompt, item-level comparison, and audit logs from
#' the latest iteration.
#'
#' @param prompt_path Path to the current prompt.md.
#' @param comparison A comparison data frame, or path to comparison.csv.
#' @param reason_files Character vector of audit-log or evidence files.
#' @param provider LLM provider used to generate the proposal.
#' @param model Model used to generate the proposal.
#' @param api_key Optional in-memory API key.
#' @param project_id Optional OpenAI project identifier.
#' @param temperature Generation temperature. Defaults to 0.
#' @param timeout Request timeout in seconds.
#' @param output_path Optional path where the proposal is written as Markdown.
#' @return A list with the proposed prompt, source paths, provider, and model.
#' @export
propose_prompt_revision <- function(prompt_path, comparison, reason_files,
                                    provider = "gemini", model = "gemini-3.6-flash",
                                    api_key = NULL, project_id = NULL,
                                    temperature = 0, timeout = 300, output_path = NULL) {
  if (!file.exists(prompt_path)) stop("Prompt not found: ", prompt_path, call. = FALSE)
  if (is.character(comparison) && length(comparison) == 1L) {
    if (!file.exists(comparison)) stop("Comparison file not found: ", comparison, call. = FALSE)
    comparison <- utils::read.csv2(comparison, check.names = FALSE, stringsAsFactors = FALSE)
  }
  if (!is.data.frame(comparison)) stop("comparison must be a data frame or CSV path.", call. = FALSE)
  if (length(reason_files) == 0 || !all(file.exists(reason_files))) {
    missing <- reason_files[!file.exists(reason_files)]
    stop("Reason file(s) not found: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  current_prompt <- paste(readLines(prompt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  comparison_text <- paste(utils::capture.output(print(comparison, row.names = FALSE)), collapse = "\n")
  reasons <- paste(vapply(reason_files, function(path) {
    paste(c(paste0("--- ", basename(path), " ---"), readLines(path, warn = FALSE, encoding = "UTF-8")), collapse = "\n")
  }, character(1)), collapse = "\n\n")
  instruction <- paste(
    "You are revising a scientific assessment prompt.",
    "Return only a complete proposed replacement prompt, with no commentary before or after it.",
    "Preserve the scale definition, item numbering, permitted values, JSON output contract, and evidence-only policy.",
    "Use the comparison and audit reasons to correct decision boundaries and reduce systematic errors.",
    "Do not encode answer-key values as article-specific rules or introduce outside scientific facts.",
    "Keep useful existing instructions and make changes explicit and generalizable.",
    "\nCURRENT PROMPT:\n", current_prompt,
    "\nITEM-LEVEL COMPARISON:\n", comparison_text,
    "\nLATEST ITERATION REASONS:\n", reasons,
    sep = "\n"
  )
  proposal <- run_llm(instruction, provider = provider, model = model,
    temperature = temperature, timeout = timeout, api_key = api_key,
    project_id = project_id, max_retries = 3, response_schema = NULL)
  if (!is.null(output_path)) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    writeLines(proposal, output_path, useBytes = TRUE)
  }
  list(prompt = proposal, prompt_path = normalizePath(prompt_path, winslash = "/", mustWork = TRUE),
    reason_files = normalizePath(reason_files, winslash = "/", mustWork = TRUE),
    provider = provider_alias(provider), model = model, output_path = output_path)
}
