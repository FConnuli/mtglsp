# mtglsp

!!WIP!!

language server to allow for convenient Magic: The Gathering deckbuilding in plaintext.

uses scryfall to source data

# current features:

- provide hover over info for card names

- autocomplete card names 

# current goals:

- syntax highlighting

- some form of namespacing to filter autocomplete to specific formats and color identities

- create some gui element that renders the deck and your current hover using images

- mana cost displayed in typehints

# Install:

This project will build correctly with zig 0.12.0-dev.1861+412999621

to install, download this repo, run `zig build`, then add the binary to your path.

# Usage:

here is the config I use for this with neovim:

```lua
local lsp_configurations = require('lspconfig.configs')

if not lsp_configurations.mtglsp then
  lsp_configurations.mtglsp = {
    default_config = {
      force_setup = true,
      single_file_support = true,
      name = 'mtglsp',
      cmd = {'mtglsp'},
      root_dir = require('lspconfig.util').root_pattern('*.mtg', '.git'),
      filetypes = {'mtg'}
    }
  }
end

require('lspconfig').mtglsp.setup({})
```

whenever I want to enable the lsp in nvim I use `:set ft=mtg`
