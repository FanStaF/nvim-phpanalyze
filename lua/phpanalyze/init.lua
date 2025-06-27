local fanstaf = {}

local default_config = {
    auto_jump = false,
    open_qflist = true,
    skip_ignored_error_pattern_lines = true;
}
local user_config = {}

-- Detect root using .git, composer.json, or phpstan.neon
local function detect_project_root()
    local path_sep = package.config:sub(1, 1)
    local markers = { ".git", "composer.json", "phpstan.neon" }

    local function exists(path)
        return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
    end

    local function is_root(path)
        for _, marker in ipairs(markers) do
            if exists(path .. path_sep .. marker) then
                return true
            end
        end
        return false
    end

    local function parent_dir(path)
        local parent = vim.fn.fnamemodify(path, ":h")
        return parent ~= path and parent or nil
    end

    local dir = vim.fn.expand("%:p:h")

    while dir do
        if is_root(dir) then
            return dir
        end
        dir = parent_dir(dir)
    end

    return vim.fn.getcwd()
end

-- Spinner utilities
local spinner = {}
spinner.frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
spinner.timer = nil
spinner.index = 1
spinner.id = nil

function spinner.start(msg, title)
    spinner.index = 1
    vim.notify(msg .. " " .. spinner.frames[spinner.index], vim.log.levels.INFO, {
        title = title,
        timeout = false,
    })

    spinner.timer = vim.loop.new_timer()
    spinner.timer:start(100, 100, vim.schedule_wrap(function()
        spinner.index = (spinner.index % #spinner.frames) + 1
        vim.notify(msg .. " " .. spinner.frames[spinner.index], vim.log.levels.INFO, {
            title = title,
            timeout = false,
        })
    end))
end

function spinner.stop(final_msg, level, title)
    if spinner.timer then
        spinner.timer:stop()
        spinner.timer:close()
        spinner.timer = nil
    end
    vim.notify(final_msg, level or vim.log.levels.INFO, {
        title = title,
    })
end

-- Main async function
fanstaf.run_phpanalyze_async = function(opts)
    opts = vim.tbl_deep_extend("force", default_config, opts or {})
    local tool_name = opts.tool or "PHPStan"
    local root = detect_project_root() or "."

    local cmd = opts.command or {
        "vendor/bin/phpstan", "analyse",
        "--no-progress", "--error-format=raw",
        "--configuration=" .. (opts.config or "phpstan.neon"),
    }

    local output = {}
    spinner.start("🔍 " .. tool_name .. " scanning for errors...", tool_name)

    local job_id = vim.fn.jobstart(
        cmd,
        {
            cwd = root,
            stdout_buffered = true,
            on_stdout = function(_, data)
                for _, line in ipairs(data) do
                    if line ~= "" then
                        table.insert(output, line)
                    end
                end
            end,
            on_exit = function(_, _)
                local ok, err = pcall(function()
                    local items = {}

                    local ignored_count = 0

                    for _, line in ipairs(output) do
                        -- ignore lines starting with "Ignored error pattern"
                        if opts.skip_ignored_error_pattern_lines and line:find("Ignored error pattern") then
                            ignored_count = ignored_count + 1
                        else
                            local file, lnum, msg = line:match("^%s*([^:]+%.php):(%d+):%s*(.+)")
                            if file and lnum and msg then
                                table.insert(items, {
                                    filename = file,
                                    lnum = tonumber(lnum),
                                    col = 1,
                                    text = msg,
                                })
                            end
                        end
                    end

                    -- add info line if any 'Ignored error pattern' lines where skipped
                    if opts.skip_ignored_error_pattern_lines and ignored_count > 0 then
                        table.insert(items, 1, {
                            filename = "",
                            lnum = 0,
                            col = 0,
                            text = string.format("%d lines with 'Ignored error pattern' skipped", ignored_count, ignored_count > 1 and "s" or "")
                        })
                    end

                    local final_msg
                    local final_level

                    if #items > 0 then
                        local ok_qf, qf_err = pcall(function()
                            vim.fn.setqflist({}, ' ', { title = tool_name, items = items })
                        end)
                        if not ok_qf then
                            spinner.stop("💥 Failed to set quickfix list: " .. qf_err, vim.log.levels.ERROR, tool_name)
                            return
                        end
                        final_msg = "❌ " .. tool_name .. " found issues"
                        final_level = vim.log.levels.WARN
                    elseif #output > 0 then
                        final_msg = "⚠️ " .. tool_name .. " finished: No parseable issues"
                        final_level = vim.log.levels.WARN
                    else
                        final_msg = "✅ " .. tool_name .. " finished: No issues!"
                        if ignored_count > 0 then
                            final_msg = final_msg .. " (But " .. ignored_count .. " lines with 'Ignored error pattern ' skipped)"
                        end
                        final_level = vim.log.levels.INFO
                    end

                    spinner.stop(final_msg, final_level, tool_name)

                    if #items > 0 then
                        -- Close existing quickfix window if open
                        for _, win in ipairs(vim.fn.getwininfo()) do
                            if win.quickfix == 1 then
                                vim.cmd("cclose")
                                break
                            end
                        end

                        -- conditionally Open quickfix with a height of 6 lines
                        if opts.open_qflist then
                            vim.cmd("botright copen 6")
                        end

                        -- conditionally jump to the first quickfix item
                        if opts.auto_jump then
                            vim.cmd("cfirst")
                        end
                    end
                end)

                if not ok then
                    spinner.stop("💥 Error in PHP analyzer: " .. err, vim.log.levels.ERROR, tool_name)
                end
            end
        }
    )

    if job_id <= 0 then
        vim.notify("Failed to start " .. tool_name .. " job", vim.log.levels.ERROR)
    end
end

fanstaf.setup = function(opts)
    user_config = vim.tbl_deep_extend("force", default_config, opts or {})

    vim.api.nvim_create_user_command("PhpAnalyze", function()
        fanstaf.run_phpanalyze_async(user_config)
    end, {})
end

return fanstaf
