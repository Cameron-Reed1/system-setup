vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("n", "<Escape>", function () vim.opt.hlsearch = false end)

vim.keymap.set("n", "<leader>pr", "<cmd>!just run<cr>")
vim.keymap.set("n", "<leader>pb", "<cmd>!just build<cr>")


--  Keymaps to insert symbols
local function insert_text(text)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, row - 1, col, row -1, col, { text })
end

vim.keymap.set("n", "<leader>st", function() insert_text("θ") end)
vim.keymap.set("n", "<leader>sp", function() insert_text("π") end)


local function open_if_exists(filename)
    if vim.fn.filereadable(filename) == 1 then
        vim.cmd.edit(filename)
        return 1
    end

    return 0
end

vim.keymap.set("n", "<leader>fh", function()
    local filename = vim.api.nvim_buf_get_name(0)
    local extension = filename:match("^.+%.([^%./\\]+)$")

    if (extension == "h") then
        local c_name = filename:gsub("%.h$", ".c")
        local cpp_name = filename:gsub("%.h$", ".cpp")

        if open_if_exists(c_name) == 1 then return end
        c_name = c_name:gsub("/inc/", "/src/")
        if open_if_exists(c_name) == 1 then return end
        c_name = c_name:gsub("/include/", "/src/")
        if open_if_exists(c_name) == 1 then return end

        if open_if_exists(cpp_name) == 1 then return end
        cpp_name = cpp_name:gsub("/inc/", "/src/")
        if open_if_exists(cpp_name) == 1 then return end
        cpp_name = cpp_name:gsub("/include/", "/src/")
        if open_if_exists(cpp_name) == 1 then return end

    elseif (extension == "c" or extension == "cpp") then
        local header_name = filename:gsub("%.[^%./\\]+$", ".h")

        if open_if_exists(header_name) == 1 then return end
        header_name = header_name:gsub("/src/", "/inc/")
        if open_if_exists(header_name) == 1 then return end
        header_name = header_name:gsub("/inc/", "/include/")
        if open_if_exists(header_name) == 1 then return end
    end
end)
