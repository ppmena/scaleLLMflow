clean_article_id <- function(path) {
  tools::file_path_sans_ext(basename(path)) |>
    stringr::str_replace_all(" ", "_")
}

write_prompt_snapshot <- function(output_dir, prompt_text, resolved_prompt) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  header <- paste(
    paste0("SCALE: ", resolved_prompt$scale),
    paste0("REQUESTED_MODEL: ", resolved_prompt$requested_model),
    paste0("SELECTED_PROMPT_MODEL: ", resolved_prompt$selected_model),
    paste0("PROMPT_MATCH_STRATEGY: ", resolved_prompt$strategy),
    paste0("PROMPT_SOURCE: ", resolved_prompt$prompt_path),
    "--- PROMPT TEXT ---",
    sep = "\n"
  )

  writeLines(paste(header, prompt_text, sep = "\n\n"), file.path(output_dir, "prompt_used.md"), useBytes = TRUE)
}

build_audit_log <- function(clean_id, provider, model, strip_references, call_logs, calls_list,
                            scale = "mqs", calls_per_article = 1, items = 1:10) {
  consensus_ordered_log <- build_consensus_ordered_log(calls_list, items = items)
  score_header <- if (tolower(scale) == "mqs") {
    "--- MQS CONSENSUS SCORES USED FOR EXCEL ---"
  } else {
    paste0("--- ", toupper(scale), " CONSENSUS SCORES USED FOR EXCEL ---")
  }

  paste(
    paste0("ID: ", clean_id),
    paste0("MODEL_PROVIDER: ", provider_alias(provider)),
    paste0("MODEL: ", model),
    paste0("STRIP_REFERENCES: ", as.integer(isTRUE(strip_references))),
    paste0("CALLS_PER_ARTICLE: ", calls_per_article),
    score_header,
    consensus_ordered_log,
    "--- INDIVIDUAL ORDERED CALLS ---",
    paste(call_logs, collapse = "\n\n"),
    "--- END OF ORDERED AUDIT ---",
    sep = "\n\n"
  )
}

#' Run one article file through a registered scale prompt.
#'
#' @param article_path Article path. Supported extensions are `.pdf`, `.txt`, and `.md`.
#' @param scale Scale name. Defaults to `"mqs"`.
#' @param provider LLM provider. Defaults to `"gemini"`.
#' @param model Requested model. Defaults to `"gemini-2.5-flash"`.
#' @param registry_dir Optional prompt registry root.
#' @param filetype One of `"auto"`, `"pdf"`, `"txt"`, or `"md"`.
#' @param strip_references Whether to remove references before the LLM call.
#' @param items Item ids to parse. Defaults to 1:10.
#' @param output_dir Optional output directory for an audit log.
#' @export
run_article <- function(article_path = NULL, scale = "mqs", provider = "gemini", model = "gemini-2.5-flash",
                        registry_dir = NULL, filetype = "auto", strip_references = TRUE, items = 1:10,
                        output_dir = NULL, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, project_id = NULL, pdf_path = NULL) {
  if (is.null(article_path)) {
    article_path <- pdf_path
  }
  if (is.null(article_path)) {
    stop("article_path is required.", call. = FALSE)
  }

  resolved <- resolve_prompt(scale, model, registry_dir = registry_dir)
  prompt_text <- paste(readLines(resolved$prompt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  article_text <- extract_article_text(article_path, filetype = filetype, strip_references = strip_references)

  if (nchar(trimws(article_text)) < 100) {
    stop("Article without sufficient extractable text: ", article_path, call. = FALSE)
  }

  full_prompt <- build_scale_prompt(prompt_text, article_text)
  raw_response <- run_llm(
    full_prompt,
    provider = provider,
    model = model,
    temperature = temperature,
    top_p = top_p,
    timeout = timeout,
    api_key = api_key,
    project_id = project_id
  )

  ordered_items <- paste(extract_ordered_items(list(raw_response), items = items), collapse = "\n\n")
  calls_list <- c(ordered_items)
  call_logs <- c(paste("--- ORDERED CALL 1 OF 1 ---", ordered_items, sep = "\n\n"))
  clean_id <- clean_article_id(article_path)
  audit_log <- build_audit_log(
    clean_id = clean_id,
    provider = provider,
    model = model,
    strip_references = strip_references,
    call_logs = call_logs,
    calls_list = calls_list,
    scale = scale,
    items = items
  )

  if (!is.null(output_dir)) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
    write_prompt_snapshot(output_dir, prompt_text, resolved)
    writeLines(audit_log, file.path(output_dir, paste0(clean_id, "_AuditLog.txt")), useBytes = TRUE)
  }

  list(
    id = clean_id,
    file = article_path,
    filetype = if (filetype == "auto") tolower(tools::file_ext(article_path)) else validate_filetype(filetype),
    scale = scale,
    provider = provider_alias(provider),
    model = model,
    resolved_prompt = resolved,
    scores = parse_scale_scores(ordered_items, items = items),
    audit_log = audit_log,
    raw_response = raw_response
  )
}

#' Run article files in a directory through a registered scale prompt.
#'
#' Existing `*_AuditLog.txt` files larger than 100 bytes are reused and skipped.
#'
#' @param articles_dir Directory containing articles.
#' @param filetype One of `"auto"`, `"pdf"`, `"txt"`, or `"md"`.
#' @param output_dir Directory where audit logs and CSV are written.
#' @param max_articles Maximum pending PDFs to process. `0` means all.
#' @export
run_dataset <- function(articles_dir, scale = "mqs", provider = "gemini", model = "gemini-2.5-flash",
                        output_dir, registry_dir = NULL, filetype = "auto", strip_references = TRUE, max_articles = 0,
                        items = 1:10, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, project_id = NULL) {
  if (!dir.exists(articles_dir)) {
    stop("Articles directory not found: ", articles_dir, call. = FALSE)
  }
  filetype <- validate_filetype(filetype)
  if (max_articles < 0) {
    stop("max_articles must be 0 or higher.", call. = FALSE)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  resolved <- resolve_prompt(scale, model, registry_dir = registry_dir)
  prompt_text <- paste(readLines(resolved$prompt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  write_prompt_snapshot(output_dir, prompt_text, resolved)

  article_paths <- list_article_files(articles_dir, filetype = filetype)
  results_list <- list()
  processed_pending <- 0

  for (article_path in article_paths) {
    clean_id <- clean_article_id(article_path)
    audit_full_path <- file.path(output_dir, paste0(clean_id, "_AuditLog.txt"))

    if (file.exists(audit_full_path) && file.info(audit_full_path)$size > 100) {
      existing_log <- paste(readLines(audit_full_path, warn = FALSE), collapse = "\n")
      existing_record <- build_consensus_record(clean_id, basename(article_path), list(existing_log), items = items)
      if (!is.null(existing_record)) {
        results_list[[length(results_list) + 1]] <- existing_record
      }
      next
    }

    if (max_articles > 0 && processed_pending >= max_articles) {
      break
    }

    result <- tryCatch({
      run_article(
        article_path = article_path,
        scale = scale,
        provider = provider,
        model = model,
        registry_dir = registry_dir,
        filetype = filetype,
        strip_references = strip_references,
        items = items,
        output_dir = output_dir,
        temperature = temperature,
        top_p = top_p,
        timeout = timeout,
        api_key = api_key,
        project_id = project_id
      )
    }, error = function(e) {
      warning("Error processing article '", basename(article_path), "': ", e$message, call. = FALSE)
      NULL
    })

    if (is.null(result)) {
      processed_pending <- processed_pending + 1
      next
    }

    record <- build_consensus_record(clean_id, basename(article_path), list(result$audit_log), items = items)
    if (!is.null(record)) {
      results_list[[length(results_list) + 1]] <- record
    }
    processed_pending <- processed_pending + 1
  }

  if (length(results_list) == 0) {
    final_df <- data.frame()
  } else {
    final_df <- do.call(rbind, results_list)
  }

  csv_path <- file.path(output_dir, paste0(tolower(scale), "_Consensus_Report.csv"))
  utils::write.csv2(final_df, csv_path, row.names = FALSE)

  list(
    results = final_df,
    output_dir = output_dir,
    csv_path = csv_path,
    processed_pending_articles = processed_pending,
    resolved_prompt = resolved
  )
}
