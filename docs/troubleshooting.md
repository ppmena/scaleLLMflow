# Troubleshooting

For missing credentials, check the provider-specific environment variable and restart R/RStudio after editing `.Renviron`. Never paste a token into a committed script.

For PDF failures, confirm the file exists and contains a readable text layer. A scanned image-only PDF needs OCR before scoring. For invalid structured responses, inspect the raw response and audit log: missing, extra, duplicated, or disallowed items are intentionally rejected.

On Windows, use UTF-8 project files and ASCII-compatible directory and fixture names. The bundled article filenames avoid spaces and non-ASCII characters.
