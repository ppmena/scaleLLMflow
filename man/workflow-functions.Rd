\name{available_scales}
\alias{available_scales}
\alias{available_models}
\alias{resolve_prompt}
\alias{build_scale_prompt}
\alias{extract_article_text}
\alias{extract_pdf_text}
\alias{strip_references_section}
\alias{parse_scale_scores}
\alias{run_llm}
\alias{run_article}
\alias{run_dataset}
\title{Scale LLM workflow functions}
\usage{
available_scales(registry_dir = NULL)
available_models(scale, registry_dir = NULL)
resolve_prompt(scale, model, registry_dir = NULL)
build_scale_prompt(prompt_text, article_text)
extract_article_text(file_path, filetype = "auto", strip_references = TRUE)
extract_pdf_text(pdf_path, strip_references = TRUE)
strip_references_section(article_text)
parse_scale_scores(text, items = 1:10)
run_llm(prompt, provider = "gemini", model = "gemini-2.5-flash",
  temperature = 0, top_p = 0.1, timeout = 300, api_key = NULL,
  project_id = NULL)
run_article(article_path = NULL, scale = "mqs", provider = "gemini",
  model = "gemini-2.5-flash", registry_dir = NULL, filetype = "auto",
  strip_references = TRUE, items = NULL, output_dir = NULL,
  temperature = 0, top_p = 0.1, timeout = 300, api_key = NULL,
  project_id = NULL, pdf_path = NULL)
run_dataset(articles_dir, scale = "mqs", provider = "gemini",
  model = "gemini-2.5-flash", output_dir, registry_dir = NULL,
  filetype = "auto", strip_references = TRUE, max_articles = 0, items = NULL,
  temperature = 0, top_p = 0.1, timeout = 300, api_key = NULL,
  project_id = NULL)
}
\description{
Public helpers for resolving trained scale prompts, extracting PDF text, calling
LLM APIs with user-owned credentials, parsing item scores, and running article
or dataset workflows.
}
\arguments{
\item{registry_dir}{Optional prompt registry root. Defaults to bundled package prompts.}
\item{scale}{Scale name, for example \code{"mqs"}.}
\item{model}{Requested model id.}
\item{prompt_text}{Scale prompt text.}
\item{article_text}{Extracted article text.}
\item{article_path}{Path to a supported article file.}
\item{file_path}{Path to a supported article file.}
\item{filetype}{One of \code{"auto"}, \code{"pdf"}, \code{"txt"}, or \code{"md"}.}
\item{pdf_path}{Path to a PDF article.}
\item{strip_references}{Whether to remove the reference section before sending text to the LLM.}
\item{text}{LLM response text.}
\item{items}{Numeric item ids to parse.}
\item{prompt}{Prompt text to send to the LLM provider.}
\item{provider}{Provider id: \code{"gemini"}, \code{"openai"}, or \code{"chatgpt"}.}
\item{temperature}{Sampling temperature.}
\item{top_p}{Gemini topP value.}
\item{timeout}{Request timeout in seconds.}
\item{api_key}{Optional API key supplied in memory. Defaults to environment variables.}
\item{project_id}{Optional OpenAI project id. Defaults to \code{OPENAI_PROJECT_ID}.}
\item{output_dir}{Directory where audit logs and CSV files are written.}
\item{articles_dir}{Directory containing article files.}
\item{max_articles}{Maximum pending article files to process. \code{0} means all.}
}
\details{
Prompt resolution tries exact model, family token, numeric version, generic, and
nearest available model folder. API keys are read from the user environment:
\code{GEMINI_API_KEY} or \code{GOOGLE_GEMINI_KEY} for Gemini, and
\code{OPENAI_API_KEY} plus optional \code{OPENAI_PROJECT_ID} for OpenAI.
}
