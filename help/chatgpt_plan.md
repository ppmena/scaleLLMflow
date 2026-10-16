# ChatGPT plan provider

The optional `chatgpt_plan` provider uses the official local Sign in with
ChatGPT OAuth flow. It does not require `OPENAI_API_KEY`.

Node.js 22 or newer is required. The easiest setup is:

```r
chatgpt_plan_install()
```

This installs the small local bridge and its dependency under
`~/.scaleLLMflow/chatgpt-plan`.

Then use:

```r
library(scaleLLMflow)
chatgpt_plan_login()
available_provider_models("chatgpt_plan")
```

The browser opens for sign-in and consent. Credentials are stored locally
under `~/.scaleLLMflow/chatgpt-plan` unless `SCALELLMFLOW_CHATGPT_DIR` is set.
Tokens are never written to audit logs.

```r
run <- run_dataset(
  articles_dir = "articles",
  scale = "rob2",
  provider = "chatgpt_plan",
  model = "<model returned by available_provider_models>",
  output_dir = "results_chatgpt_plan",
  filetype = "md",
  reasoning_effort = "medium"
)
```

Use `chatgpt_plan_logout()` to remove the local credentials.
