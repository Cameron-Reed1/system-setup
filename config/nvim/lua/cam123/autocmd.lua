vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
    pattern = "*.txt,*.md",
    callback = function ()
        vim.api.nvim_set_option_value("spell", true, { scope = "local" })
        vim.api.nvim_set_option_value("wrap", true, { scope = "local" })
        vim.api.nvim_set_option_value("linebreak", true, { scope = "local" })
    end
})

vim.api.nvim_create_autocmd("BufWrite", {
    callback = function (opts)
        local filetype = vim.bo[opts.buf].filetype
        if filetype == "text" or filetype == "markdown" then
            return
        end
        vim.api.nvim_exec2("%s/[ \\t]\\+$//e", { output = false })
    end
})
