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
