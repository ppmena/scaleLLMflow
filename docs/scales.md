# Scales and registries

A registry directory contains one folder per scale with `prompt.md` and `metadata.json`. Metadata should define scale and prompt versions, item labels, allowed values, total-score rule, missing-value policy, response schema, and evidence fields.

Use `audit_model_registry()` before a run and `registry_dir` for private project scales. Adding a scale does not establish scientific validity; maintain human review and version control for definitions, prompts, reference scores, and changes.
