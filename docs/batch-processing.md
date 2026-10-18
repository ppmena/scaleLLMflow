# Batch processing

`run_dataset()` discovers supported article files, normalizes document IDs, skips reusable audit logs, and creates a timestamped output directory. It rejects identifier collisions before creating that output directory.

Keep generated result folders separate from source articles. Use `max_articles` for a controlled pilot and inspect the errors report before scaling up.
