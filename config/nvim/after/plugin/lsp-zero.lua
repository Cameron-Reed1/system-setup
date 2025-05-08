vim.filetype.add({ extension = { templ = "templ" } })


local lsp = require('lsp-zero').preset({})

lsp.on_attach(function(_, bufnr)
  lsp.default_keymaps({buffer = bufnr})
  local bufopts = { noremap = true, silent = true, buffer = bufnr }
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
end)

local lsp_config = require('lspconfig')
lsp_config.lua_ls.setup(lsp.nvim_lua_ls())

lsp_config.arduino_language_server.setup({
    cmd = {
        "arduino-language-server",
        "-cli", "/usr/bin/arduino-cli",
        "-clangd", "/usr/bin/clangd",
        "-cli-config", "/home/cameron-arch/.config/arduino/arduino-cli.yaml",
        "-fqbn", "arduino:avr:uno"
    },
})

lsp.setup()

