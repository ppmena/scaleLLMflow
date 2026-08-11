provider_model_env <- function(provider) {
  switch(provider_alias(provider),
    gemini = c("GEMINI_API_KEY", "GOOGLE_GEMINI_KEY"),
    openai = "OPENAI_API_KEY",
    claude = c("ANTHROPIC_API_KEY", "CLAUDE_API_KEY"),
    character(0)
  )
}

#' List models currently available to the configured provider.
#'
#' @param provider `"gemini"`, `"openai"`, `"claude"`, or an alias.
#' @param api_key Optional in-memory API key. Otherwise the provider's usual
#'   environment variables are used.
#' @param timeout Request timeout in seconds.
#' @param supported_only For Gemini, keep models supporting `generateContent`.
#' @return A data frame with provider, model id, display name, and raw metadata.
#' @export
available_provider_models <- function(provider, api_key = NULL, timeout = 30,
                                      supported_only = TRUE) {
  provider <- provider_alias(provider)
  if (!provider %in% c("gemini", "openai", "claude")) {
    stop("Unsupported provider: ", provider, call. = FALSE)
  }
  if (is.null(api_key) || !nzchar(api_key)) {
    api_key <- get_required_env(provider_model_env(provider))
  }

  if (provider == "openai") {
    resp <- httr2::request("https://api.openai.com/v1/models") |>
      httr2::req_auth_bearer_token(api_key) |>
      httr2::req_options(timeout = timeout) |>
      httr2::req_perform()
    rows <- httr2::resp_body_json(resp, simplifyVector = FALSE)$data %||% list()
    return(model_rows(provider, rows, "id", "owned_by"))
  }

  if (provider == "claude") {
    resp <- httr2::request("https://api.anthropic.com/v1/models") |>
      httr2::req_headers(`x-api-key` = api_key, `anthropic-version` = "2023-06-01") |>
      httr2::req_options(timeout = timeout) |>
      httr2::req_perform()
    rows <- httr2::resp_body_json(resp, simplifyVector = FALSE)$data %||% list()
    return(model_rows(provider, rows, "id", "display_name"))
  }

  endpoint <- "https://generativelanguage.googleapis.com/v1beta/models"
  page <- NULL
  rows <- list()
  repeat {
    req <- httr2::request(endpoint) |>
      httr2::req_headers(`x-goog-api-key` = api_key) |>
      httr2::req_url_query(pageSize = 1000)
    if (!is.null(page) && nzchar(page)) req <- httr2::req_url_query(req, pageToken = page)
    parsed <- httr2::resp_body_json(httr2::req_perform(httr2::req_options(req, timeout = timeout)), simplifyVector = FALSE)
    rows <- c(rows, parsed$models %||% list())
    page <- parsed$nextPageToken %||% ""
    if (!nzchar(page)) break
  }
  if (supported_only) {
    rows <- Filter(function(x) "generateContent" %in% (x$supportedGenerationMethods %||% character(0)), rows)
  }
  model_rows(provider, rows, "baseModelId", "displayName")
}

model_rows <- function(provider, rows, id_field, name_field) {
  if (length(rows) == 0) return(data.frame(provider = character(), model = character(), display_name = character()))
  data.frame(
    provider = provider,
    model = vapply(rows, function(x) as.character(x[[id_field]] %||% x$name %||% ""), character(1)),
    display_name = vapply(rows, function(x) as.character(x[[name_field]] %||% ""), character(1)),
    stringsAsFactors = FALSE
  )
}
