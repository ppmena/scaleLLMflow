# Architecture

The package has four layers: registry resolution selects prompt and metadata; text extraction converts local documents into evidence text; provider adapters perform authenticated calls and retries; validation and reporting turn responses into scores, evidence, and audit records.

`run_article()` composes the layers for one document. `run_dataset()` adds file discovery, collision checks, resumability, consensus reports, and error output. Pure parsing and scoring functions are testable without network calls.
