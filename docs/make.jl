# Build the aggregate QuantumSavory documentation site.
#
# Usage:
#   julia --project=docs docs/make.jl [--temp] [deploy]
#
# Passing `deploy` pushes the generated site to the `gh-pages` branch.
# Passing `--temp` clones upstream docs into a temporary directory.

using Base64
using MultiDocumenter

const SITE_DOMAIN = "https://alldocs.quantumsavory.org"
const CUSTOM_DOMAIN = "alldocs.quantumsavory.org"
const DEPLOY_REPO = "git@github.com:QuantumSavory/multidoc.git"

const PACKAGES = [
    (; name = "QuantumSavory", owner = "QuantumSavory"),
    (; name = "QuantumClifford", owner = "QuantumSavory"),
    (; name = "Gabs", owner = "QuantumSavory"),
    (; name = "QuantumOptics", owner = "qojulia"),
    (; name = "QuantumSymbolics", owner = "QuantumSavory"),
]

function docref(clonedir, spec)
    return MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, spec.name),
        path = lowercase(spec.name),
        name = spec.name,
        giturl = "https://github.com/$(spec.owner)/$(spec.name).jl.git",
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

    docs = [docref(clonedir, spec) for spec in PACKAGES]

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

function decode_documenter_key(key::AbstractString)
    try
        return String(base64decode(key))
    catch
        return key
    end
end

function documenter_ssh_command()
    key = strip(get(ENV, "DOCUMENTER_KEY", ""))
    isempty(key) && return nothing

    sshdir = joinpath(homedir(), ".ssh")
    mkpath(sshdir)

    keyfile = joinpath(sshdir, "documenter_multidoc_key")
    write(keyfile, decode_documenter_key(key))
    chmod(keyfile, 0o600)

    known_hosts = joinpath(sshdir, "known_hosts")
    hosts = read(`ssh-keyscan github.com`, String)
    open(known_hosts, "a") do io
        write(io, hosts)
    end
    chmod(known_hosts, 0o600)

    return "ssh -i $(keyfile) -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"
end

function push_docs(gitroot, remote, outbranch, has_outbranch)
    if has_outbranch
        run(`git -C $gitroot push $remote $outbranch`)
    else
        run(`git -C $gitroot push -u $remote $outbranch`)
    end
end

function deploy(outpath)
    @warn "Deploying generated documentation to gh-pages"

    gitroot = normpath(joinpath(@__DIR__, ".."))
    outbranch = "gh-pages"
    source_branch = readchomp(`git -C $gitroot branch --show-current`)

    has_outbranch = success(`git -C $gitroot ls-remote --exit-code --heads origin $outbranch`)
    if has_outbranch
        run(`git -C $gitroot fetch origin $outbranch`)
        run(`git -C $gitroot checkout -B $outbranch FETCH_HEAD`)
    else
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
        ssh_command = documenter_ssh_command()
        if isnothing(ssh_command)
            push_docs(gitroot, "origin", outbranch, has_outbranch)
        else
            withenv("GIT_SSH_COMMAND" => ssh_command) do
                push_docs(gitroot, DEPLOY_REPO, outbranch, has_outbranch)
            end
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
