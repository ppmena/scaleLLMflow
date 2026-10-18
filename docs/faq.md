# FAQ

**Does the package validate scientific validity?** No. It validates the registered response contract and computes the declared score; scientific review remains a project responsibility.

**Can I use a private scale?** Yes. Supply a private `registry_dir` and keep its prompt, metadata, articles, and reviewed references under the project's access controls.

**Are failures silently scored?** No. Structured violations fail closed and dataset failures are recorded in the errors report.

**Does reference mode overwrite the model answer?** No. It reports comparison while preserving the model response.
