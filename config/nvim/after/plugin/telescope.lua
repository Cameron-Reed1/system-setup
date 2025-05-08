local builtins = require('telescope.builtin')
vim.keymap.set("n", "<leader>pf", builtins.find_files, {})
vim.keymap.set("n", "<leader>pg", builtins.git_files, {})
vim.keymap.set("n", "<leader>pc", builtins.live_grep, {})

vim.keymap.set("n", "<leader>cs", builtins.colorscheme, {})

