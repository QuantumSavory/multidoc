# QuantumSavory aggregated documentation

This repository builds the MultiDocumenter.jl site for the QuantumSavory GitHub
organization at <https://alldocs.quantumsavory.org>.

Included documentation sets:

- QuantumSavory
- QuantumClifford
- QuantumSymbolics

Build locally with:

```sh
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

The local build is written to `docs/out`. Passing `--temp` clones upstream docs
into a temporary directory instead of `docs/clones`:

```sh
julia --project=docs docs/make.jl --temp
```

Pushing to `main`, running the workflow manually, or waiting for the scheduled
workflow rebuilds the aggregate docs and pushes them to `gh-pages`.

Buildkite runs the same aggregate docs build without deployment through
`.buildkite/pipeline.yml`.
