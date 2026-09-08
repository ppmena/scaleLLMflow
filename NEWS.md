# scaleLLMflow 0.4.1

## RoB 2 scale registry

Adds the Cochrane RoB 2 parallel-trial risk-of-bias prompt as a provider-neutral
scale-level registry entry. The flat-line categorical response is validated and
retained in evidence/audit output, with stable internal encoding for reports.

# scaleLLMflow 0.4.0

## First stable release

`scaleLLMflow` provides a general framework for applying scientific rating
scales to research articles with large language models. It supports article
text extraction and Markdown conversion, scale-specific prompt registries,
structured response validation, scoring, evidence capture, retries, audit
logs, dataset workflows, prompt training, and comparison of model outputs.

The release includes Gemini, OpenAI, and Claude integrations, provider-neutral
prompts with strict version control, MQS and PEDro scale definitions, GPT-5.6
reasoning configuration, and documentation and examples for local R/RStudio
use.
