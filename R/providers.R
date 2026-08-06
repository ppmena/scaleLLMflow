provider_alias <- function(provider) {
  provider <- tolower(provider)
  if (provider == "chatgpt") {
    return("openai")
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

call_gemini <- function(prompt, model, temperature = 0, top_p = 0.1, timeout = 300, api_key = NULL) {
  if (is.null(api_key) || !nzchar(api_key)) {
    api_key <- get_required_env(c("GEMINI_API_KEY", "GOOGLE_GEMINI_KEY"))
  }

  endpoint <- paste0(
    "https://generativelanguage.googleapis.com/v1beta/models/",
    model,
    ":generateContent"
  )

  body <- list(
    contents = list(list(parts = list(list(text = prompt)))),
    generationConfig = list(temperature = temperature, topP = top_p)
  )

  resp <- httr2::request(endpoint) |>
    httr2::req_url_query(key = api_key) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_options(timeout = timeout) |>
    httr2::req_perform()

  parsed <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  text_parts <- parsed$candidates[[1]]$content$parts
  paste(vapply(text_parts, function(part) part$text %||% "", character(1)), collapse = "\n")
}

call_openai <- function(prompt, model, temperature = 0, timeout = 300, api_key = NULL, project_id = NULL) {
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

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Call a supported LLM provider with user-owned API credentials.
#'
#' @param prompt Prompt text to send.
#' @param provider `"gemini"`, `"openai"`, or `"chatgpt"`.
#' @param model Model id.
#' @param temperature Sampling temperature.
#' @param top_p Gemini topP value.
#' @param timeout Request timeout in seconds.
#' @export
run_llm <- function(prompt, provider = "gemini", model = "gemini-2.5-flash",
                    temperature = 0, top_p = 0.1, timeout = 300,
                    api_key = NULL, project_id = NULL) {
  provider <- provider_alias(provider)

  if (provider == "gemini") {
    return(call_gemini(prompt, model, temperature, top_p, timeout, api_key))
  }

  if (provider == "openai") {
    return(call_openai(prompt, model, temperature, timeout, api_key, project_id))
  }

  stop("Unsupported provider: ", provider, call. = FALSE)
}
