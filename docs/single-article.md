# Single-article workflow

`run_article()` accepts `.pdf`, `.txt`, and `.md` files. With `filetype = "auto"`, the extension is detected and a Markdown cache may be created beside a PDF. Set `cache_markdown = FALSE` when source directories must remain unchanged.

Use `conversion = "llm"` only for difficult layouts after checking privacy, cost, and provider suitability. The result exposes `scores`, `total_score`, `evidence`, `provenance`, `raw_response`, and `audit_log`.
