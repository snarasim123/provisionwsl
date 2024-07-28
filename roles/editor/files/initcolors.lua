function set_colors()
    -- enable_bamboo()
    -- enable_catpuccin()
    -- enable_kanagawa()
    -- enable_oxocarbon()
        enable_moonfly()
    end
    
    function enable_moonfly()
        vim.cmd [[colorscheme moonfly]]
    end
    
    function enable_oxocarbon()
        vim.opt.background = "dark" -- set this to dark or light
        vim.cmd("colorscheme oxocarbon")
    end
    
    function enable_kanagawa()
        -- Default options:
      require('kanagawa').setup({
        compile = false,             -- enable compiling the colorscheme
        undercurl = true,            -- enable undercurls
        commentStyle = { italic = true },
        functionStyle = {},
        keywordStyle = { italic = true},
        statementStyle = { bold = true },
        typeStyle = {},
        transparent = false,         -- do not set background color
        dimInactive = false,         -- dim inactive window `:h hl-NormalNC`
        terminalColors = true,       -- define vim.g.terminal_color_{0,17}
        colors = {                   -- add/modify theme and palette colors
            palette = {},
            theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
        },
        overrides = function(colors) -- add/modify highlights
            return {}
        end,
        theme = "wave",              -- Load "wave" theme when 'background' option is not set
        background = {               -- map the value of 'background' option to a theme
            dark = "wave",           -- try "dragon" !
            light = "lotus"
        },
      })
      
      -- setup must be called before loading
      -- vim.cmd("colorscheme kanagawa")
      -- vim.cmd("colorscheme kanagawa-dragon")
      -- vim.cmd("colorscheme kanagawa-lotus")
      vim.cmd("colorscheme kanagawa-wave")
    end
    
    function enable_bamboo()
        require("bamboo").setup {}
        require('bamboo').load()
    end
      
      function enable_catpuccin()
        require("catppuccin").setup {}
        vim.cmd.colorscheme "catppuccin-macchiato"
    end