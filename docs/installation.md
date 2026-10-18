# Installation and credentials

`scaleLLMflow` requires R 4.3 or newer and the packages listed in `DESCRIPTION`. Use `R CMD build` and `R CMD INSTALL`, or `devtools::load_all()` during development.

| Provider | Credential or local service |
| --- | --- |
| Gemini | `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY` |
| OpenAI | `OPENAI_API_KEY`; optionally `OPENAI_PROJECT_ID` |
| ChatGPT plan | `chatgpt_plan_login()`; see `help/chatgpt_plan.md` |
| Claude | `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| Ollama | Running Ollama server; optionally `OLLAMA_BASE_URL` |

Credentials are read at call time and are not written to logs. Keep tokens, private articles, and generated results outside commits. On Windows, use portable project and article names; bundled fixtures use ASCII-compatible names.
