# nvim-phpanalyze

A lightweight Neovim plugin to run [PHPStan](https://phpstan.org/) asynchronously and populate the quickfix list with any issues found.

## 🚀 Features

- Runs PHPStan via `jobstart`
- Parses errors and displays them in the quickfix list
- Adds `:Phpanalyze` command to Neovim
- Uses `vim.notify` for nice status messages

## 📦 Installation

## Requirements

- PHPStan installed at vendor/bin/phpstan
- Neovim 0.8+

### lazy.nvim

```lua
{
  "fanstaf/nvim-phpanalyze",
  config = function()
    require("fanstaf.phpanalyze").setup()
  end,
}
```

## 🔧 Configuration

`nvim-phpanalyze` supports optional configuration via `.setup()`:

```lua
require("phpstan").setup({
  auto_jump = true,     -- Jump to first quickfix entry after analysis (default: false)
  open_qflist = true,   -- Open quickfix list automatically if issues are found (default: true)
})
```

## TODO

- [ ] Add support for Psalm
