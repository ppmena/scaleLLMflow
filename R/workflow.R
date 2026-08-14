clean_article_id <- function(path) {
  tools::file_path_sans_ext(basename(path)) |>
    stringr::str_replace_all(" ", "_")
}

# Return a stable SHA-256 digest for text. Hashes tie an audit result to the
# exact inputs that produced it.
sha256_text <- function(text) {
  as.character(openssl::sha256(charToRaw(enc2utf8(text))))
}

build_provenance <- function(article_path, article_text, prompt_text, full_prompt,
                             resolved, provider, model, temperature, top_p,
                             timeout, strip_references, max_retries,
                             retry_wait_seconds, retry_backoff, rate_limit_seconds) {
  package_version <- tryCatch(as.character(utils::packageVersion("scaleLLMflow")),
    error = function(e) "development")
  list(
    created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    package_version = package_version,
    r_version = as.character(getRversion()),
    platform = R.version$platform,
    article_path = normalizePath(article_path, winslash = "/", mustWork = FALSE),
    article_file_bytes = if (file.exists(article_path)) as.numeric(file.info(article_path)$size) else NA_real_,
    article_text_characters = nchar(article_text),
    article_text_bytes = nchar(article_text, type = "bytes"),
    prompt_characters = nchar(prompt_text),
    prompt_bytes = nchar(prompt_text, type = "bytes"),
    request_characters = nchar(full_prompt),
    request_bytes = nchar(full_prompt, type = "bytes"),
    article_text_sha256 = sha256_text(article_text),
    prompt_sha256 = sha256_text(prompt_text),
    request_sha256 = sha256_text(full_prompt),
    requested_model = model,
    selected_prompt = if (is.null(resolved$selected_prompt)) resolved$selected_model else resolved$selected_prompt,
    selected_prompt_model = resolved$selected_model,
    prompt_match_strategy = resolved$strategy,
    prompt_source = resolved$prompt_path,
    prompt_version = if (!is.null(resolved$prompt_version)) resolved$prompt_version else if (is.null(resolved$metadata$prompt_version)) "unspecified" else as.character(resolved$metadata$prompt_version),
    provider = provider_alias(provider),
    temperature = temperature,
    top_p = top_p,
    timeout_seconds = timeout,
    strip_references = isTRUE(strip_references),
    max_retries = max_retries,
    retry_wait_seconds = retry_wait_seconds,
    retry_backoff = retry_backoff,
    rate_limit_seconds = rate_limit_seconds
  )
}

format_provenance <- function(provenance) {
  paste(c("--- REPRODUCIBILITY METADATA ---",
    vapply(names(provenance), function(key) paste0(key, ": ", provenance[[key]]), character(1))), collapse = "\n")
}

# Compare an LLM score vector with a previously reviewed reference vector.
# This function never changes the LLM output; it only reports agreement.
compare_reference_scores <- function(scores, reference_scores, items) {
  reference_scores <- reference_scores[paste0("Item_", items)]
  obtained <- as.numeric(scores[paste0("Item_", items)])
  expected <- as.numeric(reference_scores)
  data.frame(
    Item = paste0("Item_", items),
    Obtained = obtained,
    Expected = expected,
    Correct = !is.na(obtained) & !is.na(expected) & obtained == expected,
    stringsAsFactors = FALSE
  )
}

scale_default_items <- function(scale, items) {
  if (!is.null(items)) return(items)
  if (tolower(scale) == "pedro") return(1:11)
  1:10
}

write_prompt_snapshot <- function(output_dir, prompt_text, resolved_prompt) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  header <- paste(
    paste0("SCALE: ", resolved_prompt$scale),
    paste0("REQUESTED_MODEL: ", resolved_prompt$requested_model),
    paste0("SELECTED_PROMPT: ", if (is.null(resolved_prompt$selected_prompt)) resolved_prompt$selected_model else resolved_prompt$selected_prompt),
    paste0("SELECTED_PROMPT_MODEL: ", resolved_prompt$selected_model),
    paste0("PROMPT_MATCH_STRATEGY: ", resolved_prompt$strategy),
    paste0("PROMPT_SOURCE: ", resolved_prompt$prompt_path),
    paste0("PROMPT_VERSION: ", if (!is.null(resolved_prompt$prompt_version)) resolved_prompt$prompt_version else if (is.null(resolved_prompt$metadata$prompt_version)) "unspecified" else resolved_prompt$metadata$prompt_version),
    paste0("PROMPT_SHA256: ", sha256_text(prompt_text)),
    "--- PROMPT TEXT ---",
    sep = "\n"
  )

  writeLines(paste(header, prompt_text, sep = "\n\n"), file.path(output_dir, "prompt_used.md"), useBytes = TRUE)
}

build_audit_log <- function(clean_id, provider, model, strip_references, call_logs, calls_list,
                            scale = "mqs", calls_per_article = 1, items = 1:10,
                            provenance = NULL, raw_response = NULL, validation = NULL) {
  consensus_ordered_log <- build_consensus_ordered_log(calls_list, items = items)
  score_header <- if (tolower(scale) == "mqs") {
    "--- MQS CONSENSUS SCORES USED FOR EXCEL ---"
  } else {
    paste0("--- ", toupper(scale), " CONSENSUS SCORES USED FOR EXCEL ---")
  }

  sections <- c(
    paste0("ID: ", clean_id),
    paste0("MODEL_PROVIDER: ", provider_alias(provider)),
    paste0("MODEL: ", model),
    paste0("STRIP_REFERENCES: ", as.integer(isTRUE(strip_references))),
    paste0("CALLS_PER_ARTICLE: ", calls_per_article),
    if (!is.null(provenance)) format_provenance(provenance),
    if (!is.null(validation)) paste("--- REFERENCE VALIDATION ---", validation, sep = "\n\n"),
    score_header,
    consensus_ordered_log
  )
  # With one call, the consensus list is already the complete machine-readable
  # score output. Keep individual call blocks only when they add information.
  if (calls_per_article > 1) {
    sections <- c(sections,
      "--- INDIVIDUAL ORDERED CALLS ---",
      paste(call_logs, collapse = "\n\n"))
  }
  sections <- c(sections,
    if (!is.null(raw_response)) paste("--- RAW LLM RESPONSE ---", raw_response, sep = "\n\n"),
    "--- END OF ORDERED AUDIT ---"
  )
  paste(sections, collapse = "\n\n")
}

#' Run one article file through a registered scale prompt.
#'
#' @param article_path Article path. Supported extensions are `.pdf`, `.txt`, and `.md`.
#' @param scale Scale name. Defaults to `"mqs"`.
#' @param provider LLM provider. Defaults to `"gemini"`.
#' @param model Requested model. Defaults to `"gemini-3.6-flash"`.
#' @param registry_dir Optional prompt registry root.
#' @param filetype One of `"auto"`, `"pdf"`, `"txt"`, or `"md"`.
#' @param strip_references Whether to remove references before the LLM call.
#' @param tables_advanced Whether to structure extracted headings, lists, and
#'   table-like blocks as Markdown before the LLM call.
#' @param cache_markdown Whether PDF extraction writes a same-name `.md` cache
#'   beside the source PDF for reuse by `filetype = "auto"`.
#' @param conversion PDF conversion mode: `"basic"` or `"llm"`. LLM conversion
#'   generally gives better results for multi-column articles and complex layouts.
#' @param conversion_provider,conversion_model,conversion_prompt Settings for the
#'   LLM used only to convert PDF text into Markdown.
#' @param max_chars Maximum text size per LLM PDF-conversion call; larger PDFs
#'   are split and reassembled automatically.
#' @param items Item ids to parse. Defaults to 1:10.
#' @param output_dir Optional output directory for an audit log.
#' @param write_evidence Whether to write the per-article evidence CSV. Dataset
#' workflows set this to `FALSE` because they write one consolidated report.
#' @param temperature,top_p,timeout,api_key,project_id Provider call settings.
#' @param pdf_path Backward-compatible alias for `article_path`.
#' @param max_retries,retry_wait_seconds,retry_backoff,rate_limit_seconds Reliability settings.
#' @param reference_scores Optional reviewed scores for reference validation.
#' @param validation_mode Either `"free"` or `"reference"`.
#' @export
run_article <- function(article_path = NULL, scale = "mqs", provider = "gemini", model = "gemini-3.6-flash",
                        registry_dir = NULL, filetype = "auto", strip_references = TRUE, tables_advanced = TRUE, cache_markdown = TRUE,
                        conversion = "basic", conversion_provider = "openai", conversion_model = "gpt-5.6-luna", conversion_prompt = NULL,
                        max_chars = 50000,
                        items = NULL,
                        output_dir = NULL, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, project_id = NULL, pdf_path = NULL,
                        reasoning_effort = NULL,
                        max_retries = 3, retry_wait_seconds = 1, retry_backoff = 2,
                        rate_limit_seconds = 0, reference_scores = NULL,
                        validation_mode = c("free", "reference"), write_evidence = TRUE) {
  if (is.null(article_path)) {
    article_path <- pdf_path
  }
  if (is.null(article_path)) {
    stop("article_path is required.", call. = FALSE)
  }
  items <- scale_default_items(scale, items)
  validation_mode <- match.arg(validation_mode)
  if (!is.null(reference_scores)) validation_mode <- "reference"

  resolved <- resolve_prompt(scale, model, provider = provider, registry_dir = registry_dir)
  prompt_text <- paste(readLines(resolved$prompt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  article_text <- extract_article_text(article_path, filetype = filetype,
    strip_references = strip_references, tables_advanced = tables_advanced,
    cache_markdown = cache_markdown, conversion = conversion,
    provider = conversion_provider, model = conversion_model,
    conversion_prompt = conversion_prompt, max_chars = max_chars)

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
    reasoning_effort = reasoning_effort,
    api_key = api_key,
    project_id = project_id,
    max_retries = max_retries,
    retry_wait_seconds = retry_wait_seconds,
    retry_backoff = retry_backoff,
    rate_limit_seconds = rate_limit_seconds,
    response_schema = resolved$metadata$response_schema
  )

  provenance <- build_provenance(
    article_path, article_text, prompt_text, full_prompt, resolved, provider,
    model, temperature, top_p, timeout, strip_references, max_retries,
    retry_wait_seconds, retry_backoff, rate_limit_seconds
  )
  provenance$response_characters <- nchar(raw_response)
  provenance$response_bytes <- nchar(raw_response, type = "bytes")
  provenance$response_sha256 <- sha256_text(raw_response)
  evidence <- extract_scale_evidence(raw_response, items, resolved$metadata)
  evidence$Score <- as.numeric(parse_scale_scores(raw_response, items = items, metadata = resolved$metadata))
  evidence <- evidence[c("Item", "Score", "Decision", "Evidence", "Reason")]

  # Validate before parsing so malformed model output fails loudly and is
  # recorded by run_dataset instead of producing incomplete scores.
  validate_scale_response(raw_response, resolved$metadata, items)

  ordered_items <- if (!is.null(resolved$metadata$response_schema) &&
                       !identical(resolved$metadata$response_schema$type, "legacy_lines")) {
    scores <- parse_scale_scores(raw_response, items = items, metadata = resolved$metadata)
    validate_scale_scores(scores, items, resolved$metadata)
    paste(vapply(items, function(i) paste0("* Item ", i, ": ", format_scale_score(scores[[paste0("Item_", i)]])), character(1)), collapse = "\n\n")
  } else {
    paste(extract_ordered_items(list(raw_response), items = items), collapse = "\n\n")
  }
  calls_list <- c(ordered_items)
  call_logs <- c(paste("--- ORDERED CALL 1 OF 1 ---", ordered_items, sep = "\n\n"))
  validation <- NULL
  if (validation_mode == "reference") {
    if (is.null(reference_scores)) stop("reference_scores is required in reference mode.", call. = FALSE)
    validation <- compare_reference_scores(parse_scale_scores(raw_response, items = items, metadata = resolved$metadata), reference_scores, items)
    validation <- paste(utils::capture.output(print(validation, row.names = FALSE)), collapse = "\n")
  }
  clean_id <- clean_article_id(article_path)
  audit_log <- build_audit_log(
    clean_id = clean_id,
    provider = provider,
    model = model,
    strip_references = strip_references,
    call_logs = call_logs,
    calls_list = calls_list,
    scale = scale,
    items = items,
    provenance = provenance,
    raw_response = raw_response,
    validation = validation
  )

  if (!is.null(output_dir)) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
    write_prompt_snapshot(output_dir, prompt_text, resolved)
    if (isTRUE(write_evidence)) {
      utils::write.csv2(evidence, file.path(output_dir, paste0(clean_id, "_Evidence.csv")), row.names = FALSE)
    }
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
    scores = parse_scale_scores(raw_response, items = items, metadata = resolved$metadata),
    total_score = calculate_scale_total(parse_scale_scores(raw_response, items = items, metadata = resolved$metadata), resolved$metadata),
    score_definition = resolved$metadata$scale_definition$total,
    audit_log = audit_log,
    raw_response = raw_response,
    provenance = provenance,
    validation_mode = validation_mode,
    validation = if (is.null(validation)) NULL else compare_reference_scores(
      parse_scale_scores(raw_response, items = items, metadata = resolved$metadata), reference_scores, items),
    evidence = evidence
  )
}

#' Run article files in a directory through a registered scale prompt.
#'
#' Existing `*_AuditLog.txt` files larger than 100 bytes are reused and skipped.
#'
#' @param articles_dir Directory containing articles.
#' @param filetype One of `"auto"`, `"pdf"`, `"txt"`, or `"md"`.
#' @param output_dir Directory where audit logs and CSV are written.
#' @param scale Scale name.
#' @param provider LLM provider.
#' @param model Requested model.
#' @param registry_dir Optional prompt registry root.
#' @param strip_references,items,temperature,top_p,timeout,api_key,project_id Provider and parsing settings.
#' @param conversion,conversion_provider,conversion_model,conversion_prompt PDF
#'   conversion settings. LLM conversion generally gives better results for
#'   multi-column articles and complex layouts.
#' @param max_chars Maximum text size per LLM PDF-conversion call.
#' @param max_retries,retry_wait_seconds,retry_backoff,rate_limit_seconds Reliability settings.
#' @param reference_csv Optional reviewed-score CSV.
#' @param validation_mode Either `"free"` or `"reference"`.
#' @param max_articles Maximum pending PDFs to process. `0` means all.
#' @return A list containing the timestamped run directory, consensus report,
#' consolidated evidence report, and errors when any occurred.
#' @export
run_dataset <- function(articles_dir, scale = "mqs", provider = "gemini", model = "gemini-3.6-flash",
                        output_dir, registry_dir = NULL, filetype = "auto", strip_references = TRUE, tables_advanced = TRUE, cache_markdown = TRUE,
                        conversion = "basic", conversion_provider = "openai", conversion_model = "gpt-5.6-luna", conversion_prompt = NULL, max_articles = 0,
                        max_chars = 50000,
                        items = NULL, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, project_id = NULL, max_retries = 3,
                        retry_wait_seconds = 1, retry_backoff = 2,
                        rate_limit_seconds = 0, reference_csv = NULL,
                        reasoning_effort = NULL,
                        validation_mode = c("free", "reference")) {
  if (!dir.exists(articles_dir)) {
    stop("Articles directory not found: ", articles_dir, call. = FALSE)
  }
  items <- scale_default_items(scale, items)
  validation_mode <- match.arg(validation_mode)
  if (!is.null(reference_csv)) validation_mode <- "reference"
  reference_table <- NULL
  if (validation_mode == "reference") {
    if (is.null(reference_csv) || !file.exists(reference_csv)) {
      stop("reference_csv is required in reference mode and must exist.", call. = FALSE)
    }
    reference_table <- utils::read.csv2(reference_csv, stringsAsFactors = FALSE, check.names = FALSE)
    required_columns <- c("ID", paste0("Item_", items))
    if (!all(required_columns %in% names(reference_table))) {
      stop("reference_csv must contain: ", paste(required_columns, collapse = ", "), call. = FALSE)
    }
  }
  filetype <- validate_filetype(filetype)
  if (max_articles < 0) {
    stop("max_articles must be 0 or higher.", call. = FALSE)
  }
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  run_stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  run_dir <- file.path(output_dir, paste0(tolower(scale), "_", run_stamp))
  suffix <- 1L
  while (dir.exists(run_dir)) {
    run_dir <- file.path(output_dir, paste0(tolower(scale), "_", run_stamp, "_", suffix))
    suffix <- suffix + 1L
  }
  dir.create(run_dir, recursive = TRUE)
  output_dir <- run_dir

  resolved <- resolve_prompt(scale, model, provider = provider, registry_dir = registry_dir)
  prompt_text <- paste(readLines(resolved$prompt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  write_prompt_snapshot(output_dir, prompt_text, resolved)

  article_paths <- list_article_files(articles_dir, filetype = filetype)
  results_list <- list()
  evidence_list <- list()
  errors_list <- list()
  processed_pending <- 0

  for (article_path in article_paths) {
    clean_id <- clean_article_id(article_path)
    audit_full_path <- file.path(output_dir, paste0(clean_id, "_AuditLog.txt"))

    if (file.exists(audit_full_path) && file.info(audit_full_path)$size > 100) {
      existing_log <- paste(readLines(audit_full_path, warn = FALSE), collapse = "\n")
        existing_record <- build_consensus_record(clean_id, basename(article_path), list(existing_log), items = items, metadata = resolved$metadata)
      if (!is.null(existing_record)) {
        results_list[[length(results_list) + 1]] <- existing_record
      }
      next
    }

    if (max_articles > 0 && processed_pending >= max_articles) {
      break
    }

    result <- tryCatch(
      {
      reference_row <- NULL
      if (validation_mode == "reference") {
        reference_row <- reference_table[reference_table$ID == clean_id, , drop = FALSE]
        if (nrow(reference_row) != 1) stop("Reference CSV must contain exactly one row for ID: ", clean_id, call. = FALSE)
        reference_row <- unlist(reference_row[1, paste0("Item_", items)], use.names = TRUE)
      }
      run_article(
        article_path = article_path,
        scale = scale,
        provider = provider,
        model = model,
        registry_dir = registry_dir,
        filetype = filetype,
        strip_references = strip_references,
        tables_advanced = tables_advanced,
        cache_markdown = cache_markdown,
        conversion = conversion,
        conversion_provider = conversion_provider,
        conversion_model = conversion_model,
        conversion_prompt = conversion_prompt,
        max_chars = max_chars,
        items = items,
        output_dir = output_dir,
        temperature = temperature,
        top_p = top_p,
        timeout = timeout,
        reasoning_effort = reasoning_effort,
        api_key = api_key,
        project_id = project_id,
        max_retries = max_retries,
        retry_wait_seconds = retry_wait_seconds,
        retry_backoff = retry_backoff,
        rate_limit_seconds = rate_limit_seconds,
        reference_scores = reference_row,
        validation_mode = validation_mode,
        write_evidence = FALSE
      )
      },
      error = function(e) {
        message("Skipping ", basename(article_path), ": ", conditionMessage(e))
        errors_list[[length(errors_list) + 1]] <<- data.frame(
          ID = clean_id,
          File = basename(article_path),
          Error = conditionMessage(e),
          stringsAsFactors = FALSE
        )
        NULL
      }
    )

    processed_pending <- processed_pending + 1
    if (is.null(result)) next

    result_evidence <- result$evidence
    result_evidence$ID <- clean_id
    result_evidence <- result_evidence[c("ID", "Item", "Score", "Decision", "Evidence", "Reason")]
    evidence_list[[length(evidence_list) + 1]] <- result_evidence

    record <- build_consensus_record(clean_id, basename(article_path), list(result$audit_log), items = items, metadata = resolved$metadata)
    if (!is.null(record)) {
      results_list[[length(results_list) + 1]] <- record
    }
  }

  if (length(results_list) == 0) {
    final_df <- data.frame()
  } else {
    final_df <- do.call(rbind, results_list)
  }

  csv_path <- file.path(output_dir, paste0(tolower(scale), "_Consensus_Report.csv"))
  utils::write.csv2(final_df, csv_path, row.names = FALSE)
  errors_df <- if (length(errors_list) == 0) {
    data.frame(ID = character(), File = character(), Error = character(), stringsAsFactors = FALSE)
  } else {
    do.call(rbind, errors_list)
  }
  errors_path <- NULL
  if (nrow(errors_df) > 0) {
    errors_path <- file.path(output_dir, paste0(tolower(scale), "_Errors.csv"))
    utils::write.csv2(errors_df, errors_path, row.names = FALSE)
  }
  evidence_path <- file.path(output_dir, paste0(tolower(scale), "_Evidence_Report.csv"))
  evidence_df <- if (length(evidence_list) == 0) {
    data.frame(ID = character(), Item = character(), Score = numeric(), Decision = character(), Evidence = character(), Reason = character(), stringsAsFactors = FALSE)
  } else do.call(rbind, evidence_list)
  utils::write.csv2(evidence_df, evidence_path, row.names = FALSE)

  list(
    results = final_df,
    output_dir = output_dir,
    csv_path = csv_path,
    processed_pending_articles = processed_pending,
    errors = errors_df,
    errors_path = errors_path,
    evidence = evidence_df,
    evidence_path = evidence_path,
    resolved_prompt = resolved
  )
}
