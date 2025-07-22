--[[

    This file defines the "styles" to replace acronyms.

    Such styles control how to use the acronym's short name,
    long name, whether one should be between parentheses, etc.

    Styles are largely inspired from the LaTeX package "glossaries"
    (and "glossaries-extra").
    A gallery of the their styles can be found at:
    https://www.dickimaw-books.com/gallery/index.php?label=sample-abbr-styles
    A more complete document (rather long) can be found at:
    https://mirrors.chevalier.io/CTAN/macros/latex/contrib/glossaries-extra/samples/sample-abbr-styles.pdf

    More specifically, this file defines a table of functions.
    Each function takes an acronym, and return one or several Pandoc elements.
    These elements will replace the original acronym call in the Markdown 
    document.

    Most styles will depend on whether this is the acronym's first occurrence,
    ("first use") or not ("next use"), similarly to the LaTeX "glossaries".

    For example, a simple (default) style can be to return the acronym's
    long name, followed by the short name between parentheses.
    When the parser encounters `\acr{RL}`, assuming that `RL` is correctly
    defined in the acronyms database, the corresponding function would 
    return a Pandoc Link, where the text is "Reinforcement Learning (RL)",
    and pointing to the definition of "RL" in the List of Acronyms.
    
    Note: the acronym's key MUST exist in the acronyms database.
    Functions to replace a non-existing key must be handled elsewhere.

--]]

local Helpers = require("acronyms_helpers")


-- The table containing all styles, indexed by the style's name.
local styles = {}

-- Local helper function to select the correct form of the acronym to be displayed.
local function select_form(acronym, isPlural, isFirst, isCapital)
    local text
    if isPlural then
        if isFirst then
            text = acronym.longplural or (acronym.longname and acronym.longname .. "s") or ""
        else
            text = acronym.shortplural or (acronym.shortname and acronym.shortname .. "s") or ""
        end
    else
        text = isFirst and acronym.longname or acronym.shortname
    end
    if isCapital and text then
        text = Helpers.capitalize_first(text)
    end
    return text
end


-- Local helper function to create either a Str or a Link,
-- depending on whether we want to insert links.
local function create_element(content, key, insert_links)
    if insert_links then
        return pandoc.Link(content, Helpers.key_to_link(key))
    else
        return pandoc.Str(content)
    end
end


-- First use: long name (short name)
-- Next use: short name
styles["long-short"] = function(acronym, insert_links, is_first_use, isPlural, isCapital)
    local text
    if is_first_use then
        local main = select_form(acronym, isPlural, true, isCapital)
        local alt = select_form(acronym, isPlural, false, isCapital)
        text = main .. " (" .. alt .. ")"
    else
        text = select_form(acronym, isPlural, false, isCapital)
    end
    return create_element(text, acronym.key, insert_links)
end


-- First use: short name (long name)
-- Next use: short name
styles["short-long"] = function(acronym, insert_links, is_first_use, isPlural, isCapital)
    local text
    if is_first_use then
        local main = select_form(acronym, isPlural, true, isCapital)
        local alt = select_form(acronym, isPlural, false, isCapital)
        text = alt .. " (" .. main .. ")"
    else
        text = select_form(acronym, isPlural, false, isCapital)
    end
    return create_element(text, acronym.key, insert_links)
end

-- First use: long name
-- Next use: long name
styles["long-long"] = function(acronym, insert_links)
    local text
    text = select_form(acronym, isPlural, true, isCapital)

    return create_element(text, acronym.key, insert_links)
end

-- First use: short name [^1]
-- [^1]: short name: long name
-- Next use: short name
styles["short-footnote"] = function(acronym, insert_links, is_first_use, isPlural, isCapital)
    local main = select_form(acronym, isPlural, false, isCapital)
    if is_first_use then
        -- The inline text (before the footnote)
        local footnote = select_form(acronym, isPlural, true, isCapital)
        local text = pandoc.Span{pandoc.Str(main), pandoc.Note{pandoc.Str(footnote)}}
        return create_element(text, acronym.key, insert_links)
    else
        -- Simply return the shortname
        return create_element(main, acronym.key, insert_links)
    end
end


-- The "public" API of this module, the function which is returned by
-- require.
return function(acronym, style_name, insert_links, is_first_use, isPlural, isCapital)
    -- Check that the requested strategy exists
    assert(style_name ~= nil,
        "[acronyms] The parameter style_name must not be nil!")
    assert(styles[style_name] ~= nil,
        "[acronyms] Style " .. tostring(style_name) .. " does not exist!")

    -- Check that the acronym exists
    assert(acronym ~= nil,
        "[acronyms] The acronym must not be nil!")

    -- Determine if it is the first use (if left unspecified)
    if is_first_use == nil then
        is_first_use = acronym:isFirstUse()
    end
    -- Call the style on this acronym
    return styles[style_name](acronym, insert_links, is_first_use, isPlural, isCapital)
end
