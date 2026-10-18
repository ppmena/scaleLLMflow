# Providers and models

Provider and model are explicit arguments. `available_provider_models()` is a discovery helper, not a frozen catalogue; hosted lists change and may require credentials. Reliability controls include `timeout`, `max_retries`, `retry_wait_seconds`, `retry_backoff`, and `rate_limit_seconds`.

The optional `chatgpt_plan` adapter uses local OAuth and is distinct from the OpenAI API provider. Record the selected model and settings in the audit output.
