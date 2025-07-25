--[[

    This file defines an Acronym and the Acronyms table.

--]]


local Helpers = require("acronyms_helpers")


-- Define an Acronym with some default values
Acronym = {
    -- The acronym's key, or label. Used to identify it. Must be unique.
    key = nil,
    -- The acronym's short form (i.e., the acronym itself).
    shortname = nil,
    -- The acronym's definition, or description.
    longname = nil,
    -- The plural of the short form (optional).
    shortplural = nil,  -- <<<<<<<<< ADDED FIELD
    -- The plural of the long form (optional).
    longplural = nil,  -- <<<<<<<<<<<<<<<< ADDED FIELD
    -- The number of times this acronym was used.
    occurrences = 0,
    -- The order in which acronyms are defined. 1=first, 2=second, etc.
    definition_order = nil,
    -- The order in which acronyms appear in the document. 1=first, nil=never.
    usage_order = nil,
}


-- Helper method to generate a precise error message describing the user the
-- problem when creating an acronym (e.g., if the shortname is missing).
local function raiseAcronymCreationError(object)
    local msg = lunacolors.red("Error when creating an acronym:\n")
    msg = msg .. "! Both `shortname`` and `longname` must be specified:\n"
    if object.shortname == nil then
        msg = msg .. "x `shortname` was nil\n"
    end
    if object.longname == nil then
        msg = msg .. "x `longname` was nil\n"
    end
    local unexpected_keys = {}
    for k, _ in pairs(object.original_metadata) do
        if k ~= "shortname" and k ~= "longname" and k ~= "key" and k ~= "shortplural" and k ~= "longplural" then -- <<<< allow longplural and shortplural
            table.insert(unexpected_keys, k)
        end
    end
    if #unexpected_keys > 0 then
    -- Concatenate the message only if there is at least 1 unexpected key
        msg = msg .. "i Found unexpected keys: " .. table.concat(unexpected_keys, ",") .. ".\n"
    end
    -- This str here represents the original metadata, not the formatted
    -- Acronym (which could be obtained with `tostring(object)`).
    local acronym_str = Helpers.metadata_to_str(object.original_metadata)
    msg = msg .. "i The acronym was defined as: " .. acronym_str .. "\n"
    quarto.log.error("[acronyms]", msg, "\n")
    assert(false)
end


-- Create a new Acronym
function Acronym:new(object)
    setmetatable(object, self)
    self.__index = self

    -- Check that important attributes are non-nil
    if object.shortname == nil or object.longname == nil then
        raiseAcronymCreationError(object)
    end

    -- If the key is not set, we want to use the shortname instead.
    -- (Most of the time, the key is the shortname in lower case anyway...)
    object.key = object.key or object.shortname

    -- Populate shortplural if present in original_metadata
    if object.shortplural == nil and object.original_metadata then
        if object.original_metadata.shortplural ~= nil then
            object.shortplural = pandoc.utils.stringify(object.original_metadata.shortplural)
        end
    end
    -- Populate longplural if present in original_metadata
    if object.longplural == nil and object.original_metadata then
        if object.original_metadata.longplural ~= nil then
            object.longplural = pandoc.utils.stringify(object.original_metadata.longplural)
        end
    end
    
    return object
end


-- Debug (helper) function
function Acronym.__tostring(acronym)
    local str = "Acronym{"
    str = str .. "key=" .. acronym.key .. ";"
    str = str .. "short=" .. acronym.shortname .. ";"
    str = str .. "long=" .. acronym.longname .. ";"
    if acronym.shortplural then
        str = str .. "shortplural=" .. acronym.shortplural .. ";"
    end
    if acronym.longplural then
        str = str .. "longplural=" .. acronym.longplural .. ";"
    end
    str = str .. "occurrences=" .. acronym.occurrences .. ";"
    str = str .. "definition_order=" .. tostring(acronym.definition_order) .. ";"
    str = str .. "usage_order=" .. tostring(acronym.usage_order)
    str = str .. "}"
    return str
end


-- Increment the count of occurrences
function Acronym:incrementOccurrences()
    self.occurrences = self.occurrences + 1
end


-- Is this the acronym's first occurrence?
function Acronym:isFirstUse()
    return self.occurrences == 0
end


-- The Acronyms database.
Acronyms = {
    -- The table that contains all acronyms, indexed by their key.
    acronyms = {},

    -- The current "definition_order" value.
    -- Each time a new acronym is defined, we increment this value to keep
    -- count of the order in which acronyms are defined.
    current_definition_order = 0,

    -- The current "usage order" value.
    -- We increment this value each time an acronym is used for the first time,
    -- to keep count of their order of appearance. This can be necessary for
    -- generating the List of Acronyms, depending on the desired order.
    current_usage_order = 0,

    -- Access to the `Acronym` class, if necessary.
    Acronym = Acronym,
}


-- Get the Acronym with the given key, or nil if not found.
function Acronyms:get(key)
    return self.acronyms[key]
end


-- Does the table contains the given key?
function Acronyms:contains(key)
    return self:get(key) ~= nil
end


-- Add a new acronym to the table. Also handles duplicates.
function Acronyms:add(acronym, on_duplicate)
    quarto.log.debug("[acronyms] Trying to add a new acronym...", acronym)
    assert(acronym ~= nil,
        "[acronyms] The acronym should not be nil in Acronyms:add!")
    assert(acronym.key ~= nil,
        "[acronyms] The acronym key should not be nil in Acronyms:add!")
    assert(on_duplicate ~= nil,
        "[acronyms] The parameter on_duplicate should not be nil in Acronyms:add!")

    -- Handling duplicate keys
    if self:contains(acronym.key) then
        quarto.log.debug("[acronyms] Found an acronym with a duplicate key: ", acronym.key)
        if on_duplicate == "replace" then
            -- Do nothing, let us replace the previous acronym.
        elseif on_duplicate == "keep" then
            -- Do nothing, but do not replace: we return here.
            return
        elseif on_duplicate == "warn" then
            -- Warn, and do not replace.
            quarto.log.warning("[acronyms] Found an acronym with a duplicate key: ", acronym.key)
            return
        elseif on_duplicate == "error" then
            -- Stop execution.
            quarto.log.error("[acronyms] Found an acronym with a duplicate key: ", acronym.key)
            assert(false)
        else
            quarto.log.error("[acronyms] Unrecognized option `on_duplicate`=", tostring(on_duplicate), " in Acronyms:add.")
            assert(false)
        end
    end

    self.current_definition_order = self.current_definition_order + 1
    acronym.definition_order = self.current_definition_order
    self.acronyms[acronym.key] = acronym
end


function Acronyms:setAcronymUsageOrder(acronym)
    assert(acronym ~=nil,
        "[acronyms] The acronym should not be nil in Acronyms:setAcronymUsageOrder!")
    self.current_usage_order = self.current_usage_order + 1
    acronym.usage_order = self.current_usage_order
end


-- Populate the Acronyms database from a YAML metadata
function Acronyms:parseFromMetadata(metadata, on_duplicate)
    quarto.log.debug("[acronyms] Parsing acronyms from metadata...", metadata.acronyms)
    -- We expect the acronyms to be in the `metadata.acronyms.keys` field.
    if not (metadata and metadata.acronyms and metadata.acronyms.keys) then
        return
    end
    -- This field should be a Pandoc "MetaList" (so we can iter over it).
    if not Helpers.isMetaList(metadata.acronyms.keys) then
        quarto.log.error("[acronyms] The `acronyms.keys` metadata should be a list!")
        assert(false)
    end

    -- Iterate over the defined acronyms. We use `ipairs` since we want to
    -- keep their original order (useful for the `definition_order`!).
    for _, v in ipairs(metadata.acronyms.keys) do
        -- Remember that each of these values can be nil!
        -- By using `and`, we make sure that `stringify` is applied on non-nil.
        local key = v.key and pandoc.utils.stringify(v.key)
        local shortname = v.shortname and pandoc.utils.stringify(v.shortname)
        local longname = v.longname and pandoc.utils.stringify(v.longname)
        local shortplural = v.shortplural and pandoc.utils.stringify(v.shortplural) -- <<<<<< shortplural handled here
        local longplural = v.longplural and pandoc.utils.stringify(v.longplural) -- <<<<<<< longplural handled here
        local acronym = Acronym:new{
            key = key,
            shortname = shortname,
            longname = longname,
            shortplural = shortplural, -- <<<<<< shortplural handled here
            longplural = longplural, -- <<<<<<< longplural handled here
            original_metadata = v,
        }
        Acronyms:add(acronym, on_duplicate)
    end
end


-- Populate the Acronyms database from a YAML file
-- Inspired from https://github.com/dsanson/pandoc-abbreviations.lua/
function Acronyms:parseFromYamlFile(filepath, on_duplicate)
    quarto.log.debug("[acronyms] Trying to parse acronyms from file: ", filepath)
    assert(filepath ~= nil,
        "[acronyms] filepath must not be nil when parsing from external file!")

    -- First, read the file's content.
    local file = io.open(filepath, "r")
    if file == nil then
        quarto.log.warning("[acronyms] File ", filepath, " could not be read! (does not exist?)")
        return
    end
    local content = file:read("*a")
    file:close()

    -- Secondly, use Pandoc's read ability to parse the content.
    -- Pandoc does not know how to read YAML, so we'll trick it by
    -- asking to parse Markdown instead (since the Markdown's metadata
    -- is YAML anyway).
    local metadata = pandoc.read(content, "markdown").meta

    -- Finally, read the metadata; we have 2 formats and need to find the correct one.
    if (metadata and metadata.acronyms and metadata.acronyms.keys) then
        -- The "original" format, a list of `{ key, shortname, longname }`.
        self:parseFromMetadata(metadata, on_duplicate)
    else
        -- The "simplified" format, a map of `shortname: longname`.
        self:parseSimplifiedFormat(metadata, on_duplicate)
    end
end


-- Parse acronyms in a simplified format consisting of `key: value` like lines.
-- Example:
-- ```
-- ---
-- shortname1: Long name for acronym 1
-- shortname2: Long name for acronym 2
-- ---
-- ```
function Acronyms:parseSimplifiedFormat(metadata, on_duplicate)
    for shortname, longname in pairs(metadata) do
        local original_metadata = { shortname = shortname, longname = longname }
        shortname = pandoc.utils.stringify(shortname)
        longname = pandoc.utils.stringify(longname)
        local acronym = Acronym:new{
            key = nil,
            shortname = shortname,
            longname = longname,
            original_metadata = original_metadata,
        }
        Acronyms:add(acronym, on_duplicate)
    end
end


return Acronyms
