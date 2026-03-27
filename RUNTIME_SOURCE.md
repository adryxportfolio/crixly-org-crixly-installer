# Runtime source for Crixly installers

We pin the Crixly runtime (forked + fully white-labeled) by commit SHA and download/build it in CI.

- Repo: https://github.com/frameflowmedia4partners-rgb/CrixlyFinalAgentic
- Pin: set `CRIXLY_RUNTIME_REF` (commit SHA or tag)

Install scripts and packaging should never reference any upstream name.
