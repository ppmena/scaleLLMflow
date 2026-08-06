\name{scaleLLMflow-package}
\alias{scaleLLMflow-package}
\alias{scaleLLMflow}
\docType{package}
\title{General LLM Workflows for Scientific Quality Scales}
\description{
Reusable helpers to register scale prompts by model, resolve the best available
prompt for a requested LLM, extract article PDF text, call user-configured LLM
APIs, parse item scores, and write compatible audit logs.
}
\details{
The first bundled scale is MQS with the consolidated v019 Gemini prompt under
\code{inst/scales/mqs/gemini-2.5-flash}. API keys are always read from the
user environment and are never stored in the package.
}
