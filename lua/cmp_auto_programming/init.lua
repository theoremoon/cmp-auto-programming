local cmp = require('cmp')
local lspconfig = require('lspconfig')

local map = function(f, tbl)
    if tbl == nil then
        return {}
    end
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

local split = function(s, sep)
    local t = {}
    for l in s:gmatch("[^"..sep.."]+") do
        table.insert(t, l)
    end
    return t
end

local trim = function(s)
    if s == nil then
        return  nil
    end
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

local source = {}

source.new = function()
    return setmetatable({
    }, { __index = source })
end

source.get_debug_name = function()
    return 'auto-programming'
end

-- 全部マッチしても困るので3文字以上入力されてたら検索する
source.get_keyword_pattern = function()
    return [[....*]]
end

source.complete = function(self, request, callback)
    local query = trim(request.context.cursor_before_line)
    if query == "" then
        return
    end

    
    local j = nil
    local items = {}
    if vim.fn.executable('rg') == 1 then
        j = vim.fn.jobstart({
            'rg', '--json', '-F', query,
        }, {
            stdin = 'null',
            cwd = vim.fn.getcwd(),
            on_stdout = function(j, data, ev)
                for i, line in ipairs(data) do
                    xpcall(function()
                        local t = vim.json.decode(line)
                        if t["type"] == "match" then
                            table.insert(items, {
                                label = trim(t["data"]["lines"]["text"]),
                                documentation = t["data"]["path"]["text"],
                            })
                        end
                    end, function(err)
                    end)
                end
            end,
            on_exit = function(j, status, event)
                callback({
                    items = items,
                    isIncomplete = false,
                })
            end,
        })
    else
        j = vim.fn.jobstart({
            'git', 'grep', '-F', query,
        }, {
            stdin = 'null',
            cwd = vim.fn.getcwd(),
            on_stdout = function(j, data, ev)
                for i, line in ipairs(data) do
                    local parts = split(line, ":")
                    table.insert(items, {
                        label = trim(parts[2]),
                        documentation = parts[1],
                    })
                end
            end,
            on_exit = function(j, status, event)
                callback({
                    items = items,
                    isIncomplete = false,
                })
            end,
        })
    end
    vim.fn.jobwait({j},1)
end


source.deindent = function(_, text)
  local indent = string.match(text, '^%s*')
  if not indent then
    return text
  end
  return string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n')
end

source.is_available = function()
    local git_dir = lspconfig.util.root_pattern('.git')(vim.fn.getcwd())
    return (git_dir ~= 0)
end

return source
