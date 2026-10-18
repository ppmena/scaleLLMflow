\name{chatgpt_plan}
\alias{chatgpt_plan_install}
\alias{chatgpt_plan_login}
\alias{chatgpt_plan_logout}
\alias{chatgpt_plan_status}
\alias{chatgpt_plan_models}
\title{Use an eligible ChatGPT plan from the local package}
\description{
Installs the local bridge and manages an OAuth connection to an eligible
ChatGPT plan. The bridge uses the user's plan for Responses API requests and
does not require an OpenAI API key.
}
\usage{
chatgpt_plan_install(timeout = 300)
chatgpt_plan_login(label = "scaleLLMflow")
chatgpt_plan_logout()
chatgpt_plan_status()
chatgpt_plan_models(timeout = 60)
}
\arguments{
  \item{timeout}{Maximum installation or request time in seconds.}
  \item{label}{Local label for the ChatGPT connection.}
}
\value{A status object, a model data frame, or installation information.}
\details{
Credentials are stored by the local bridge under the user's local
\code{.scaleLLMflow/chatgpt-plan} directory and are not included in audit
logs.
}
\seealso{\code{run_llm}, \code{available_provider_models}}
