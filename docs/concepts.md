# Concepts and workflow

Each run combines a registered scale, provider/model, local articles, and a validation mode (`free` or `reference`). Metadata defines items, allowed decisions, evidence fields, and totals; the prompt defines the operational task. Metadata is authoritative for validation and scoring.

The pipeline resolves the registry, extracts article text, marks article text as untrusted source material, calls the provider, validates the response, calculates scores and evidence, and writes audit metadata. Invalid structured responses fail closed instead of becoming guessed or partial scores.
