local cmp = require('cmp')
local lspconfig = require('lspconfig')
local job = require('plenary.job')

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

source.complete = function(self, request, callback)
    local line = trim(request.context.cursor_before_line)

    -- なんかrg --jsonで置き換えたいんだけどプロセスの終わりをうまく受け付けられないらしくて断念してる
    local items = {}
    job:new({
        command = 'git',
        args = { 'grep', '-F', '-e', line },
        cwd = vim.fn.getcwd(),
        on_stdout = function(error, data, j)
            local parts = split(data, "\t")
            local s1 = trim(parts[2])
            table.insert(items, {
                label = s1,
                documentation = parts[1],
            })
        end,
        on_exit = function(j, status)
            callback({
                items = items,
                isIncomplete = false,
            })
        end,
    }):sync()
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
