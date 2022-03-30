# Run this dashboard from the root of the
# github repository:
using Pkg
Pkg.activate(joinpath(pwd(), "dashboard"))
Pkg.resolve()
Pkg.instantiate()

DASHBOARD_VERSION = "0.1.0"
# Variables configuring the app:  
#
#  1. location  of the assets folder (CSS, etc.)
#  2. port to run on
# 
# Set an explicit path to the `assets` folder
# on the assumption that the dashboard will be started
# from the root of the gh repository!
assets = joinpath(pwd(), "dashboard", "assets")
datadir = joinpath(pwd(),"data")
DEFAULT_PORT = 8050

using Dash


"""Load data from local files."""
function loadtexts(dir)
    txts = filter(f -> endswith(f, ".txt"), readdir(dir))
    langcodes = map(t -> t[1:3], txts)
    metadatalines = readlines(joinpath(dir, "sources.cex"))
    metadata = map(ln -> split(ln, "|"), metadatalines[2:end])
    mddict = Dict()
    for cols in metadata
        mddict[cols[4]] = cols[1]
    end

    corpora = Dict()
    re = r"([^ ]+) ([^ ]+) (.+)"
    for txt in txts
        passages = []
        lines = readlines(joinpath(dir, txt))
        for ln in lines
            m = match(re, ln)
            if ! isnothing(m)
                (bk, ref, psg) = m.captures
                push!(passages, ("$(bk):$(ref)", psg))
            end
        end
        corpora[txt] = passages
    end
    (mddict, txts, langcodes, corpora)
end
(titlesdict, filenames, langs, texts)  = loadtexts(datadir)


"""Load data set mapping language codes to readable names."""
function loadbooksdict(dir)
    data = readlines(joinpath(dir, "books.cex"))
    dict = Dict()
    for ln in data[2:end]
        parts = split(ln, "|")
        dict[parts[1]] = parts[2]
    end
    dict
end
booksdict = loadbooksdict(datadir)


app = if haskey(ENV, "URLBASE")
    dash(assets_folder = assets, url_base_pathname = ENV["URLBASE"])
else 
    dash(assets_folder = assets)    
end

app.layout = html_div(className = "w3-container") do
    html_div(className = "w3-container w3-light-gray w3-cell w3-mobile w3-border-left w3-border-right w3-border-gray",
        children = [dcc_markdown("*Dashboard version*: **$(DASHBOARD_VERSION)**")]
    ),

    html_h1() do 
        dcc_markdown("`n-gram` viewer ")
    end,

    html_h3("Select texts to analyze"),
    dcc_markdown("Optionally filter by language, then select one or more texts."),


    html_div(className="w3-container",
    children = [

        html_div(className = "w3-col l6 m6",
        children = [
            dcc_markdown("*Filter texts by languages*:"),
            dcc_checklist(
                id="languages",
                options = [
                    Dict("label" => "Arabic", "value" => "arb"),
                    Dict("label" => "Dutch", "value" => "nld"),
                    Dict("label" => "English", "value" => "eng"),
                    Dict("label" => "French", "value" => "fra"),
                    Dict("label" => "German", "value" => "deu"),
                    Dict("label" => "Greek", "value" => "grc"),
                    Dict("label" => "Hebrew", "value" => "hbo"),
                    Dict("label" => "Latin", "value" => "lat"),
                    Dict("label" => "Russian", "value" => "rus")
                ],
                labelStyle = Dict("padding-right" => "10px")
            )]),


        html_div(className = "w3-col l6 m6",
        children = [
            dcc_markdown("*Translations to include:*"),
            dcc_checklist(id="translations",
            labelStyle = Dict("padding-right" => "5px", "display" => "block")
            )
        ])
    ]),
        
     

    html_div(className="w3-container", id = "header"),
    html_div(className="w3-container", id="columns") 
end

"""Compose options for menu of translations.
"""
function xlationoptions(files, titles, langlist)
    opts = []
    if isempty(langlist)
        for f in files
            push!(opts, (label = titles[f], value = f))
        end
    else
        for lang in langlist
            for f in filter(f -> startswith(f, lang), files)
                push!(opts, (label = titles[f], value = f))
            end
        end
    end
    opts
end


# Filter translations menu on language choices:
callback!(app,
    Output("translations", "options"),
    Input("languages", "value")
) do langg
    if isnothing(langg)
        xlationoptions(filenames, titlesdict, [])
    else
        xlationoptions(filenames, titlesdict, langg)
    end
end


run_server(app, "0.0.0.0", DEFAULT_PORT, debug=true)
