# Results and auditability

Dataset runs write `prompt_used.md`, a consensus CSV, an evidence CSV, one audit log per article, and an errors CSV only when failures occurred. Audit metadata includes package/R versions, provider/model, prompt source and version, generation settings, input sizes, run ID, validation status, and SHA-256 hashes for article text, prompt, request, and response.

Treat raw responses and evidence as review material. Preserve the exact registry, prompt, article version, provider model, and output directory needed to reproduce an analysis. Do not publish private article text or credentials.
