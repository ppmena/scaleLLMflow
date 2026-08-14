# scaleLLMflow 0.4.0

## Release candidate

- Consolidates the prompt registry to one accepted, provider-neutral prompt per scale.
- Enforces matching `RUN_VERSION` and `metadata.json$prompt_version` values.
- Removes model- and provider-specific prompt selection and legacy fallbacks.
- Updates MQS Item 8 with the calibrated control-category scoring proposal.
- Adds GPT-5.6 reasoning configuration and keeps `temperature` compatible with `reasoning_effort = "none"`.
- Updates training projects, examples, RStudio help, README, `.Rd`, and TeX documentation.
