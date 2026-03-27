local ix = ix or {}
ix.markdown = ix.markdown or {}

-- LRU Cache implementation
local LRUCache = {}
LRUCache.__index = LRUCache

function LRUCache.new(capacity)
    local self = setmetatable({}, LRUCache)
    self.capacity = capacity
    self.cache = {}
    self.usage = {}
    self.usageCount = 0
    return self
end

function LRUCache:get(key)
    local value = self.cache[key]
    if value then
        self.usageCount = self.usageCount + 1
        self.usage[key] = self.usageCount
        return value
    end
    return nil
end

function LRUCache:put(key, value)
    if self.capacity <= 0 then return end
    
    if #self.cache >= self.capacity then
        -- Find least recently used item
        local lru_key, lru_count = next(self.usage)
        for k, count in pairs(self.usage) do
            if count < lru_count then
                lru_key = k
                lru_count = count
            end
        end
        -- Remove it
        self.cache[lru_key] = nil
        self.usage[lru_key] = nil
    end
    
    self.usageCount = self.usageCount + 1
    self.cache[key] = value
    self.usage[key] = self.usageCount
end

-- Theme System
ix.markdown.themes = {
    default = {
        container = "color: white;",
        header = "color:white;margin:0.5em 0;font-weight:bold;",
        code = "background:#1e1e1e;padding:8px;border-radius:4px;font-family:monospace;",
        codeInline = "background:#333;padding:2px 4px;border-radius:2px;font-family:monospace;",
        blockquote = "border-left:3px solid #555;padding-left:10px;margin:8px 0;color:#aaa;",
        link = "color:#4CAF50;text-decoration:underline;",
        list = "margin:0.5em 0;padding-left:2em;",
        table = "border-collapse:collapse;width:100%;margin:1em 0;",
        tableCell = "border:1px solid #555;padding:8px;",
        taskList = "list-style-type:none;margin:0.5em 0;padding-left:2em;",
        footnote = "font-size:0.9em;color:#888;",
    },
    dark = {
        container = "color: #e1e1e1;background:#1a1a1a;",
        header = "color:#e1e1e1;margin:0.5em 0;font-weight:bold;",
        code = "background:#2d2d2d;padding:8px;border-radius:4px;font-family:monospace;",
        codeInline = "background:#2d2d2d;padding:2px 4px;border-radius:2px;font-family:monospace;",
        blockquote = "border-left:3px solid #666;padding-left:10px;margin:8px 0;color:#bbb;",
        link = "color:#6abf69;text-decoration:underline;",
        list = "margin:0.5em 0;padding-left:2em;",
        table = "border-collapse:collapse;width:100%;margin:1em 0;",
        tableCell = "border:1px solid #666;padding:8px;",
        taskList = "list-style-type:none;margin:0.5em 0;padding-left:2em;",
        footnote = "font-size:0.9em;color:#999;",
    }
}

-- Markdown Parser Class
local MarkdownParser = {}
MarkdownParser.__index = MarkdownParser

function MarkdownParser.new(theme)
    local self = setmetatable({}, MarkdownParser)
    self.theme = theme or "default"
    self.cache = LRUCache.new(50)
    self:initializePatterns()
    return self
end

function MarkdownParser:initializePatterns()
    self.patterns = {
        escape = {
            { pat = "\\([\\`*_{}[]()#+-.!])", rep = "%1" }
        },
        headers = {
            { pat = "^(#+)%s*(.-)%s*$", rep = function(hashes, text)
                local level = #hashes
                if level > 6 then level = 6 end
                if level < 1 then level = 1 end
                return string.format("<h%d style='%s'>%s</h%d>", 
                    level, ix.markdown.themes[self.theme].header, text, level)
            end }
        },
        blocks = {
            -- Code blocks with language support
            { pat = "```([%w]*)[\n](.-)[%s]```", process = function(lang, code)
                return string.format("<pre style='%s'><code class='language-%s'>%s</code></pre>",
                    ix.markdown.themes[self.theme].code, lang or "plaintext", code)
            end },
            -- Blockquotes with nested support
            { pat = "^>+%s*(.-)$", process = function(text)
                return string.format("<blockquote style='%s'>%s</blockquote>",
                    ix.markdown.themes[self.theme].blockquote, text)
            end },
        },
        tables = {
            { pat = "^%s*|(.+)|%s*$", process = function(row, state)
                local cells = {}
                for cell in row:gmatch("([^|]+)") do
                    table.insert(cells, string.format("<td style='%s'>%s</td>",
                        ix.markdown.themes[self.theme].tableCell, cell:match("^%s*(.-)%s*$")))
                end
                if not state.inTable then
                    state.inTable = true
                    return string.format("<table style='%s'><tr>%s</tr>",
                        ix.markdown.themes[self.theme].table, table.concat(cells))
                end
                return string.format("<tr>%s</tr>", table.concat(cells))
            end }
        },
        tasklists = {
            { pat = "^%s*-%s%[([xX%s])%]%s(.-)$", process = function(checked, text)
                local checkmark = checked:lower() == "x" and "checked" or ""
                return string.format("<div style='%s'><input type='checkbox' %s disabled> %s</div>",
                    ix.markdown.themes[self.theme].taskList, checkmark, text)
            end }
        },
        footnotes = {
            { pat = "%[%^(%d+)%]", process = function(num)
                return string.format("<sup style='%s'>[%s]</sup>",
                    ix.markdown.themes[self.theme].footnote, num)
            end }
        },
        inline = {
            -- Bold
            { pat = "%*%*([^%*]+)%*%*", rep = "<strong>%1</strong>" },
            { pat = "__([^_]+)__", rep = "<strong>%1</strong>" },
            -- Italic
            { pat = "%*([^%*]+)%*", rep = "<em>%1</em>" },
            { pat = "_([^_]+)_", rep = "<em>%1</em>" },
            -- Code
            { pat = "`([^`]+)`", rep = function(code)
                return string.format("<code style='%s'>%s</code>",
                    ix.markdown.themes[self.theme].codeInline, code)
            end },
            -- Strikethrough
            { pat = "~~([^~]+)~~", rep = "<del>%1</del>" },
            -- Links with URL validation
            { pat = "%[([^%]]+)%]%(([^%)]+)%)", process = function(text, url)
                -- Basic URL validation
                if url and type(url) == "string" then
                    if not url:match("^https?://") and not url:match("^/") then
                        url = "https://" .. url
                    end
                    return string.format("<a href='%s' style='%s'>%s</a>",
                        url, ix.markdown.themes[self.theme].link, text)
                end
                return text
            end }
        }
    }
end

function MarkdownParser:processBlock(text, patterns, state)
    if not text then return "" end
    
    local result = text
    for _, pattern in ipairs(patterns) do
        if pattern.rep then
            if type(pattern.rep) == "function" then
                result = result:gsub(pattern.pat, pattern.rep)
            else
                result = result:gsub(pattern.pat, pattern.rep)
            end
        elseif pattern.process then
            result = result:gsub(pattern.pat, function(...)
                return pattern.process(..., state or {})
            end)
        end
    end
    
    return result
end

function MarkdownParser:parse(text)
    if type(text) ~= "string" then
        error("Expected string input for markdown conversion")
    end
    
    local cached = self.cache:get(text)
    if cached then return cached end
    
    local success, result = pcall(function()
        -- Escape special characters first
        local html = text:gsub("[&\"'><]", {
            ["&"] = "&amp;",
            ['"'] = "&quot;",
            ["'"] = "&#39;",
            ["<"] = "&lt;",
            [">"] = "&gt;"
        })
        
        -- Process escaped characters
        html = self:processBlock(html, self.patterns.escape)
        
        local lines = {}
        for line in html:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        
        local processed = {}
        local state = {}
        
        for i, line in ipairs(lines) do
            local processedLine = line
            
            -- Process in order: headers, tables, blocks, tasklists, footnotes, inline
            processedLine = self:processBlock(processedLine, self.patterns.headers)
            processedLine = self:processBlock(processedLine, self.patterns.tables, state)
            processedLine = self:processBlock(processedLine, self.patterns.blocks)
            processedLine = self:processBlock(processedLine, self.patterns.tasklists)
            processedLine = self:processBlock(processedLine, self.patterns.footnotes)
            processedLine = self:processBlock(processedLine, self.patterns.inline)
            
            -- Handle table closing
            if state.inTable and (not lines[i + 1] or not lines[i + 1]:match("^%s*|")) then
                processedLine = processedLine .. "</table>"
                state.inTable = false
            end
            
            table.insert(processed, processedLine)
        end
        
        local final = table.concat(processed, "\n")
        final = string.format('<div style="%s">%s</div>', 
            ix.markdown.themes[self.theme].container, final)
        
        return final
    end)
    
    if not success then
        error("Failed to parse markdown: " .. tostring(result))
    end
    
    self.cache:put(text, result)
    return result
end

-- Create default parser instance
local defaultParser = MarkdownParser.new()

-- Public API
function ix.markdown.ToHTML(text, themeOrNoCache)
    -- Handle legacy noCache parameter
    if type(themeOrNoCache) == "boolean" then
        if themeOrNoCache then
            -- Create temporary parser without caching
            local parser = MarkdownParser.new(defaultParser.theme)
            parser.cache = LRUCache.new(0)  -- Cache size 0 effectively disables caching
            return parser:parse(text)
        end
        return defaultParser:parse(text)
    end
    
    -- Handle theme parameter
    if themeOrNoCache and themeOrNoCache ~= defaultParser.theme then
        local parser = MarkdownParser.new(themeOrNoCache)
        return parser:parse(text)
    end
    return defaultParser:parse(text)
end

function ix.markdown.SetTheme(theme)
    if not ix.markdown.themes[theme] then
        error("Theme '" .. theme .. "' not found")
    end
    defaultParser = MarkdownParser.new(theme)
end

function ix.markdown.AddTheme(name, theme)
    ix.markdown.themes[name] = theme
end

-- Split function remains largely unchanged but with error handling
function ix.markdown.Split(text)
    if type(text) ~= "string" then
        error("Expected string input for markdown splitting")
    end

    local sections = {}
    local current = ""
    local inCode = false
    local lines = string.Split(text, "\n")

    for _, line in ipairs(lines) do
        if line:match("^```") then
            if current ~= "" then
                table.insert(sections, {
                    text = current,
                    isMarkdown = false
                })
                current = ""
            end
            inCode = not inCode
            table.insert(sections, {
                text = line,
                isMarkdown = true
            })
        elseif inCode then
            table.insert(sections, {
                text = line,
                isMarkdown = true
            })
        else
            if line:match("^#") or
               line:match("^>%s*") or
               line:match("^%s*[%*%-]%s") or
               line:match("^%s*%d+%.%s") or
               line:match("^%s*|.+|%s*$") or  -- Tables
               line:match("^%s*-%s%[[ xX]%]") then -- Task lists
                if current ~= "" then
                    table.insert(sections, {
                        text = current,
                        isMarkdown = false
                    })
                    current = ""
                end
                table.insert(sections, {
                    text = line,
                    isMarkdown = true
                })
            else
                current = current .. (current ~= "" and "\n" or "") .. line
            end
        end
    end

    if current ~= "" then
        table.insert(sections, {
            text = current,
            isMarkdown = false
        })
    end

    return sections
end