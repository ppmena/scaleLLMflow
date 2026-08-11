provider_alias <- function(provider) {
  provider <- tolower(provider)
  if (provider == "chatgpt") {
    return("openai")
  }
  if (provider %in% c("anthropic", "claude")) {
    return("claude")
  }
  provider
}

get_required_env <- function(names) {
  values <- Sys.getenv(names, unset = "")
  hit <- values[nzchar(values)]
  if (length(hit) == 0) {
    stop("Missing API key. Set one of: ", paste(names, collapse = ", "), call. = FALSE)
  }

  hit[[1]]
}

# Keep a process-local timestamp so sequential dataset runs do not burst the
# provider API. A value of zero disables the delay.
enforce_rate_limit <- function(rate_limit_seconds) {
  if (!is.numeric(rate_limit_seconds) || length(rate_limit_seconds) != 1 ||
      is.na(rate_limit_seconds) || rate_limit_seconds < 0) {
    stop("rate_limit_seconds must be a non-negative number.", call. = FALSE)
  }
  if (rate_limit_seconds == 0) return(invisible(NULL))
  last_call <- getOption("scaleLLMflow.last_call_time", default = NA_real_)
  if (!is.na(last_call)) {
    wait <- rate_limit_seconds - (as.numeric(Sys.time()) - last_call)
    if (wait > 0) Sys.sleep(wait)
  }
  options(scaleLLMflow.last_call_time = as.numeric(Sys.time()))
  invisible(NULL)
}

# Extract useful details from httr2 errors without exposing credentials.
format_provider_error <- function(error, provider, model, attempt) {
  response <- error$resp %||% error$response
  status <- NA_integer_
  body <- ""
  if (!is.null(response)) {
    status <- tryCatch(httr2::resp_status(response), error = function(e) NA_integer_)
    body <- tryCatch(httr2::resp_body_string(response), error = function(e) "")
  }
  if (nzchar(body)) body <- substr(gsub("\\s+", " ", body), 1, 500)
  message <- paste0("LLM request failed (provider=", provider, ", model=", model,
                    ", attempt=", attempt, ")")
  if (!is.na(status)) message <- paste0(message, "; HTTP status=", status)
  if (nzchar(body)) message <- paste0(message, "; response=", body)
  message <- paste0(message, "; error=", conditionMessage(error))
  structure(list(message = message, provider = provider, model = model,
                 attempt = attempt, status = status, response_body = body,
                 parent = error), class = c("scaleLLMflow_provider_error", "error", "condition"))
}

is_retryable_error <- function(error) {
  response <- error$resp %||% error$response
  status <- if (is.null(response)) NA_integer_ else
    tryCatch(httr2::resp_status(response), error = function(e) NA_integer_)
  is.na(status) || status %in% c(408, 409, 425, 429) || status >= 500
}

# Translate the compact registry contract into the JSON Schema expected by
# Gemini Interactions structured output.
build_gemini_json_schema <- function(response_schema) {
  keys <- as.character(unlist(response_schema$required_item_keys, use.names = FALSE))
  allowed <- as.character(unlist(response_schema$allowed_decisions, use.names = FALSE))
  item_schema <- list(
    type = "object",
    properties = list(
      decision = list(type = "string", enum = allowed),
      evidence = list(type = "string"),
      reason = list(type = "string")
    ),
    required = as.list(unlist(response_schema$required_item_fields, use.names = FALSE)),
    additionalProperties = FALSE
  )
  list(
    type = "object",
    properties = list(items = list(
      type = "object",
      properties = setNames(rep(list(item_schema), length(keys)), keys),
      required = as.list(keys),
      additionalProperties = FALSE
    )),
    required = list("items"),
    additionalProperties = FALSE
  )
}

# Retry transient failures with capped exponential backoff. Client errors and
# malformed successful responses are not retried.
with_retries <- function(operation, provider, model, max_retries = 3,
                         retry_wait_seconds = 1, retry_backoff = 2,
                         rate_limit_seconds = 0) {
  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 0 ||
      max_retries != as.integer(max_retries)) stop("max_retries must be a non-negative integer.", call. = FALSE)
  if (!is.numeric(retry_wait_seconds) || retry_wait_seconds < 0 ||
      !is.numeric(retry_backoff) || retry_backoff < 1) {
    stop("retry_wait_seconds must be non-negative and retry_backoff must be at least 1.", call. = FALSE)
  }
  total_attempts <- as.integer(max_retries) + 1L
  for (attempt in seq_len(total_attempts)) {
    enforce_rate_limit(rate_limit_seconds)
    result <- tryCatch(operation(), error = identity)
    if (!inherits(result, "condition")) return(result)
    detailed <- format_provider_error(result, provider, model, attempt)
    if (attempt == total_attempts || !is_retryable_error(result)) stop(detailed)
    Sys.sleep(min(60, retry_wait_seconds * retry_backoff^(attempt - 1)))
  }
}

call_gemini <- function(prompt, model, temperature = 0, top_p = 0.1, timeout = 300,
                        api_key = NULL, response_schema = NULL) {
  if (is.null(api_key) || !nzchar(api_key)) {
    api_key <- get_required_env(c("GEMINI_API_KEY", "GOOGLE_GEMINI_KEY"))
  }

  # Gemini Interactions is the current unified REST endpoint. The API key is
  # sent in a header, avoiding credentials in URLs and request logs.
  endpoint <- "https://generativelanguage.googleapis.com/v1beta/interactions"

  response_format <- list(type = "text", mime_type = "application/json")
  if (!is.null(response_schema)) {
    response_format$schema <- build_gemini_json_schema(response_schema)
  }
  body <- list(
    model = model,
    input = prompt,
    store = FALSE,
    response_format = response_format,
    generation_config = list(temperature = temperature, top_p = top_p)
  )

  resp <- httr2::request(endpoint) |>
    httr2::req_headers(`x-goog-api-key` = api_key) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_options(timeout = timeout) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  # Interactions returns model output inside steps[]. Extract only text from
  # model_output steps and fail clearly if no usable output is present.
  text <- unlist(lapply(parsed$steps %||% list(), function(step) {
    if (!identical(step$type, "model_output")) return(character(0))
    unlist(lapply(step$content %||% list(), function(content) paste(content$text %||% "", collapse = "")), use.names = FALSE)
  }))
  result <- paste(text[nzchar(text)], collapse = "\n")
  if (!nzchar(result)) stop("Gemini Interaction completed without model output text.", call. = FALSE)
  result
}

call_openai <- function(prompt, model, temperature = 0, timeout = 300, api_key = NULL,
                        project_id = NULL, response_schema = NULL) {
  if (is.null(api_key) || !nzchar(api_key)) {
    api_key <- get_required_env("OPENAI_API_KEY")
  }
  if (is.null(project_id)) {
    project_id <- Sys.getenv("OPENAI_PROJECT_ID", unset = "")
  }

  body <- list(
    model = model,
    input = prompt,
    temperature = temperature
  )
  if (!is.null(response_schema)) {
    body$text <- list(format = list(
      type = "json_schema",
      name = "scale_rating",
      strict = TRUE,
      schema = build_gemini_json_schema(response_schema)
    ))
  }

  req <- httr2::request("https://api.openai.com/v1/responses") |>
    httr2::req_auth_bearer_token(api_key)

  if (nzchar(project_id)) {
    req <- httr2::req_headers(req, "OpenAI-Project" = project_id)
  }

  resp <- req |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_options(timeout = timeout) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  if (!is.null(parsed$output_text)) {
    return(parsed$output_text)
  }

  # Also accept Chat Completions responses when a compatible endpoint or
  # proxy returns the conventional choices/message/content shape.
  if (!is.null(parsed$choices[[1]]$message$content)) {
    return(parsed$choices[[1]]$message$content)
  }

  text <- unlist(lapply(parsed$output %||% list(), function(output_item) {
    unlist(lapply(output_item$content, function(content_item) {
      content_item$text %||% ""
    }))
  }))

  result <- paste(text[nzchar(text)], collapse = "\n")
  if (!nzchar(result)) {
    stop("OpenAI response did not contain readable output text.", call. = FALSE)
  }
  result
}

call_claude <- function(prompt, model, temperature = 0, timeout = 300,
                        api_key = NULL, response_schema = NULL) {
  if (is.null(api_key) || !nzchar(api_key)) {
    api_key <- get_required_env(c("ANTHROPIC_API_KEY", "CLAUDE_API_KEY"))
  }

  # Anthropic Messages API. The scale prompt requires strict JSON and the
  # parser validates the response against the registered scale schema.
  body <- list(
    model = model,
    max_tokens = 8192,
    temperature = temperature,
    messages = list(list(role = "user", content = prompt))
  )

  resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(
      `x-api-key` = api_key,
      `anthropic-version` = "2023-06-01"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_options(timeout = timeout) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  text <- unlist(lapply(parsed$content %||% list(), function(content) {
    if (identical(content$type, "text")) content$text %||% "" else ""
  }), use.names = FALSE)
  result <- paste(text[nzchar(text)], collapse = "\n")
  if (!nzchar(result)) stop("Claude response did not contain readable output text.", call. = FALSE)
  result
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Call a supported LLM provider with user-owned API credentials.
#'
#' @param prompt Prompt text to send.
#' @param provider `"gemini"`, `"openai"`, `"chatgpt"`, `"claude"`, or `"anthropic"`.
#' @param model Model id.
#' @param temperature Sampling temperature.
#' @param top_p Gemini nucleus-sampling value; ignored by OpenAI and Claude.
#' @param timeout Maximum duration in seconds for each individual API attempt.
#' @param max_retries Maximum retries for transient failures.
#' @param retry_wait_seconds Initial exponential-backoff delay.
#' @param retry_backoff Multiplicative exponential-backoff factor.
#' @param rate_limit_seconds Minimum delay between requests in this R process.
#' @param api_key Optional in-memory API key.
#' @param project_id Optional OpenAI project id.
#' @param response_schema Optional registered response schema.
#' @export
run_llm <- function(prompt, provider = "gemini", model = "gemini-3.6-flash",
                    temperature = 0, top_p = 0.1, timeout = 300,
                    api_key = NULL, project_id = NULL, max_retries = 3,
                    retry_wait_seconds = 1, retry_backoff = 2,
                    rate_limit_seconds = 0, response_schema = NULL) {
  provider <- provider_alias(provider)

  if (provider == "gemini") {
    return(with_retries(function() call_gemini(prompt, model, temperature, top_p, timeout, api_key, response_schema),
      provider, model, max_retries, retry_wait_seconds, retry_backoff, rate_limit_seconds))
  }

  if (provider == "openai") {
    return(with_retries(function() call_openai(prompt, model, temperature, timeout, api_key, project_id, response_schema),
      provider, model, max_retries, retry_wait_seconds, retry_backoff, rate_limit_seconds))
  }

  if (provider == "claude") {
    return(with_retries(function() call_claude(prompt, model, temperature, timeout, api_key, response_schema),
      provider, model, max_retries, retry_wait_seconds, retry_backoff, rate_limit_seconds))
  }

  stop("Unsupported provider: ", provider, call. = FALSE)
}
