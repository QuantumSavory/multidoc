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

Buildkite runs the aggregate docs build through `.buildkite/pipeline.yml`.
Builds on `main` deploy the generated site to `gh-pages`; builds on other
branches only validate the aggregate docs.
