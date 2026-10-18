# Creating a scale

Start from `help/add_new_scale_skill.md`. Define scientific items and scoring rules first, then encode them in `metadata.json` and write a prompt that requests exactly the declared response schema. Add reviewed fixtures and tests for allowed values, totals, missing-value policy, and evidence fields.

Run `audit_model_registry()` and compare a prompt revision against a fixed reference set. Keep versions explicit and never alter an existing definition in place when results already exist.
