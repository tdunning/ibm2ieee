using Documenter, HFP

makedocs(modules = [HFP], sitename = "HFP.jl")

deploydocs(repo = "github.com/tdunning/HFP.jl.git")
