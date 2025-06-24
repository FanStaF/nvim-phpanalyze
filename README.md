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
    require("phpstan").setup()
  end,
}
```

## TODO

- [ ] Add support for Psalm
