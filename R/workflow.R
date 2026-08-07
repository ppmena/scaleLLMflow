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
    selected_prompt_model = resolved$selected_model,
    prompt_match_strategy = resolved$strategy,
    prompt_source = resolved$prompt_path,
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
    paste0("SELECTED_PROMPT_MODEL: ", resolved_prompt$selected_model),
    paste0("PROMPT_MATCH_STRATEGY: ", resolved_prompt$strategy),
    paste0("PROMPT_SOURCE: ", resolved_prompt$prompt_path),
    "--- PROMPT TEXT ---",
    sep = "\n"
  )

  writeLines(paste(header, prompt_text, sep = "\n\n"), file.path(output_dir, "prompt_used.md"), useBytes = TRUE)
}

build_audit_log <- function(clean_id, provider, model, strip_references, call_logs, calls_list,
                            scale = "mqs", calls_per_article = 1, items = 1:10,
                            provenance = NULL) {
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
    if (!is.null(provenance)) format_provenance(provenance),
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
                        registry_dir = NULL, filetype = "auto", strip_references = TRUE, items = NULL,
                        output_dir = NULL, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, project_id = NULL, pdf_path = NULL,
                        max_retries = 3, retry_wait_seconds = 1, retry_backoff = 2,
                        rate_limit_seconds = 0) {
  if (is.null(article_path)) {
    article_path <- pdf_path
  }
  if (is.null(article_path)) {
    stop("article_path is required.", call. = FALSE)
  }
  items <- scale_default_items(scale, items)

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
    project_id = project_id,
    max_retries = max_retries,
    retry_wait_seconds = retry_wait_seconds,
    retry_backoff = retry_backoff,
    rate_limit_seconds = rate_limit_seconds
  )

  provenance <- build_provenance(
    article_path, article_text, prompt_text, full_prompt, resolved, provider,
    model, temperature, top_p, timeout, strip_references, max_retries,
    retry_wait_seconds, retry_backoff, rate_limit_seconds
  )
  provenance$response_characters <- nchar(raw_response)
  provenance$response_bytes <- nchar(raw_response, type = "bytes")
  provenance$response_sha256 <- sha256_text(raw_response)

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
    provenance = provenance
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
    scores = parse_scale_scores(raw_response, items = items, metadata = resolved$metadata),
    total_score = calculate_scale_total(parse_scale_scores(raw_response, items = items, metadata = resolved$metadata), resolved$metadata),
    score_definition = resolved$metadata$scale_definition$total,
    audit_log = audit_log,
    raw_response = raw_response,
    provenance = provenance
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
                        items = NULL, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, project_id = NULL, max_retries = 3,
                        retry_wait_seconds = 1, retry_backoff = 2,
                        rate_limit_seconds = 0) {
  if (!dir.exists(articles_dir)) {
    stop("Articles directory not found: ", articles_dir, call. = FALSE)
  }
  items <- scale_default_items(scale, items)
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
        project_id = project_id,
        max_retries = max_retries,
        retry_wait_seconds = retry_wait_seconds,
        retry_backoff = retry_backoff,
        rate_limit_seconds = rate_limit_seconds
      ),
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
  errors_path <- file.path(output_dir, paste0(tolower(scale), "_Errors.csv"))
  errors_df <- if (length(errors_list) == 0) {
    data.frame(ID = character(), File = character(), Error = character(), stringsAsFactors = FALSE)
  } else {
    do.call(rbind, errors_list)
  }
  utils::write.csv2(errors_df, errors_path, row.names = FALSE)

  list(
    results = final_df,
    output_dir = output_dir,
    csv_path = csv_path,
    processed_pending_articles = processed_pending,
    errors = errors_df,
    errors_path = errors_path,
    resolved_prompt = resolved
  )
}
