# Build the aggregate QuantumSavory documentation site.
#
# Usage:
#   julia --project=docs docs/make.jl [--temp] [deploy]
#
# Passing `deploy` pushes the generated site to the `gh-pages` branch.
# Passing `--temp` clones upstream docs into a temporary directory.

using MultiDocumenter

const SITE_DOMAIN = "https://alldocs.quantumsavory.org"
const CUSTOM_DOMAIN = "alldocs.quantumsavory.org"

const REPOSITORIES = [
    (; name = "QuantumSavory", path = "quantumsavory", repo = "QuantumSavory.jl"),
    (; name = "QuantumClifford", path = "quantumclifford", repo = "QuantumClifford.jl"),
    (; name = "QuantumSymbolics", path = "quantumsymbolics", repo = "QuantumSymbolics.jl"),
]

function docref(clonedir, spec)
    return MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, spec.name),
        path = spec.path,
        name = spec.name,
        giturl = "https://github.com/QuantumSavory/$(spec.repo).git",
        branch = "gh-pages",
    )
end

function build()
    clonedir = ("--temp" in ARGS) ? mktempdir() : joinpath(@__DIR__, "clones")
    outpath = mktempdir()

    @info """
    Cloning package documentation into: $(clonedir)
    Building aggregate site into: $(outpath)
    """

    docs = [docref(clonedir, spec) for spec in REPOSITORIES]

    MultiDocumenter.make(
        outpath,
        docs;
        search_engine = MultiDocumenter.SearchConfig(
            index_versions = ["stable", "dev"],
            engine = MultiDocumenter.FlexSearch,
        ),
        rootpath = "/",
        canonical_domain = SITE_DOMAIN,
        sitemap = true,
    )

    write(joinpath(outpath, "CNAME"), CUSTOM_DOMAIN * "\n")
    touch(joinpath(outpath, ".nojekyll"))

    return outpath
end

function deploy(outpath)
    @warn "Deploying generated documentation to gh-pages"

    gitroot = normpath(joinpath(@__DIR__, ".."))
    outbranch = "gh-pages"
    source_branch = readchomp(`git -C $gitroot branch --show-current`)

    has_outbranch = true
    if !success(`git -C $gitroot checkout $outbranch`)
        has_outbranch = false
        if !success(`git -C $gitroot switch --orphan $outbranch`)
            error("Cannot create new orphaned branch $outbranch.")
        end
    end

    for file in readdir(gitroot; join = true)
        basename(file) == ".git" && continue
        rm(file; force = true, recursive = true)
    end

    for file in readdir(outpath)
        cp(joinpath(outpath, file), joinpath(gitroot, file); force = true)
    end

    run(`git -C $gitroot add .`)
    if success(`git -C $gitroot commit -m "Aggregate documentation"`)
        @info "Pushing updated documentation."
        if has_outbranch
            run(`git -C $gitroot push origin $outbranch`)
        else
            run(`git -C $gitroot push -u origin $outbranch`)
        end
    else
        @info "No changes to aggregated documentation."
    end

    if !isempty(source_branch) && source_branch != outbranch
        run(`git -C $gitroot checkout $source_branch`)
    end
end

outpath = build()

if "deploy" in ARGS
    deploy(outpath)
else
    localout = joinpath(@__DIR__, "out")
    rm(localout; force = true, recursive = true)
    cp(outpath, localout; force = true)
    @info "Skipping deployment. Generated files are in $(localout)."
end
