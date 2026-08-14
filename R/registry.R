registry_root <- function(registry_dir = NULL) {
  if (!is.null(registry_dir) && nzchar(registry_dir)) {
    return(normalizePath(registry_dir, winslash = "/", mustWork = FALSE))
  }

  system.file("scales", package = "scaleLLMflow")
}

list_dirs <- function(path) {
  if (!dir.exists(path)) {
    return(character(0))
  }

  basename(list.dirs(path, full.names = TRUE, recursive = FALSE))
}

read_prompt_metadata <- function(model_dir) {
  metadata_path <- file.path(model_dir, "metadata.json")
  if (!file.exists(metadata_path)) {
    return(list())
  }

  jsonlite::read_json(metadata_path, simplifyVector = TRUE)
}

#' List scales available in the local prompt registry.
#'
#' @param registry_dir Optional registry root. Defaults to bundled package prompts.
#' @export
available_scales <- function(registry_dir = NULL) {
  list_dirs(registry_root(registry_dir))
}

read_run_version <- function(prompt_path) {
  lines <- readLines(prompt_path, warn = FALSE, encoding = "UTF-8")
  hit <- grep("^RUN_VERSION:[[:space:]]*", lines, value = TRUE)
  if (length(hit) != 1) {
    stop("Prompt must contain exactly one RUN_VERSION line: ", prompt_path, call. = FALSE)
  }
  trimws(sub("^RUN_VERSION:[[:space:]]*", "", hit[[1]]))
}

validate_prompt_version <- function(prompt_path, metadata) {
  run_version <- read_run_version(prompt_path)
  metadata_version <- if (!is.null(metadata$prompt_version)) as.character(metadata$prompt_version) else ""
  if (!nzchar(metadata_version) || !identical(run_version, metadata_version)) {
    stop("RUN_VERSION (", run_version, ") does not match metadata prompt_version (",
      metadata_version, ") for prompt: ", prompt_path, call. = FALSE)
  }
  run_version
}

#' Resolve the accepted prompt registered for a scale.
#'
#' The official registry is scale-level: `scales/<scale>/prompt.md` and
#' `metadata.json`. Model and provider are execution parameters, not prompt
#' selection parameters. No model/provider-specific prompt fallback is used.
#'
#' @param scale Scale name, for example `"mqs"`.
#' @param model Requested model name.
#' @param provider Optional provider retained for API compatibility. It does not
#'   select the official scale prompt.
#' @param registry_dir Optional registry root. Defaults to bundled package prompts.
#' @return A list containing prompt path, prompt version, match strategy, and metadata.
#' @export
resolve_prompt <- function(scale, model, provider = NULL, registry_dir = NULL) {
  root <- registry_root(registry_dir)
  scale_name <- tolower(scale)
  scale_dir <- file.path(root, scale_name)
  canonical_prompt <- file.path(scale_dir, "prompt.md")
  canonical_metadata <- file.path(scale_dir, "metadata.json")

  if (file.exists(canonical_prompt)) {
    if (!file.exists(canonical_metadata)) {
      stop("Scale-level prompt exists but metadata.json is missing: ", scale_name, call. = FALSE)
    }
    metadata <- read_prompt_metadata(scale_dir)
    run_version <- validate_prompt_version(canonical_prompt, metadata)
    result <- list(
      scale = scale_name,
      requested_model = model,
      selected_model = "scale",
      selected_prompt = "scale",
      strategy = "scale",
      prompt_version = run_version,
      prompt_path = normalizePath(canonical_prompt, winslash = "/", mustWork = TRUE),
      metadata = metadata
    )
    validate_scale_definition(result$metadata)
    return(result)
  }

  stop("Scale-level prompt not found for scale: ", scale_name,
    ". Expected prompt.md and metadata.json in the scale directory.", call. = FALSE)
}
