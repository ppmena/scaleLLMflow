#' scaleLLMflow: General LLM Workflows for Scientific Quality Scales
#'
#' Reusable helpers to register MQS, PEDro, and other scientific scale prompts,
#' resolve provider-specific or model-specific prompts, call Gemini, OpenAI,
#' and Claude APIs, discover live provider model catalogues, validate responses,
#' parse item scores, and write audit logs and evidence reports.
#'
#' The bundled registry currently contains MQS and PEDro. Each scale includes
#' `claude-generic`, `gemini-generic`, and `openai-generic` prompt folders, with
#' optional model-specific variants. API keys are read from the user's
#' environment or supplied in memory and are never stored by the package.
#'
#' @name scaleLLMflow-package
#' @aliases scaleLLMflow
#' @keywords internal
"_PACKAGE"
