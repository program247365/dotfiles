" macOS: $HOME/.config/nvim/init.vim
" config file for Neovim
" assumes using [GitHub - junegunn/vim-plug: Minimalist Vim Plugin Manager](https://github.com/junegunn/vim-plug)

call plug#begin()

  " Synthwave Theme - https://github.com/artanikin/vim-synthwave84
  Plug 'artanikin/vim-synthwave84'

  Plug 'tpope/vim-sensible'
  " [GitHub - nvim-telescope/telescope.nvim: Find, Filter, Preview, Pick. All lua, all the time.](https://github.com/nvim-telescope/telescope.nvim)
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim'
  Plug 'mxw/vim-jsx'
  Plug 'pangloss/vim-javascript'
  Plug 'w0rp/ale'

  " [GitHub - lewis6991/gitsigns.nvim: Git integration for buffers](https://github.com/lewis6991/gitsigns.nvim)
  Plug 'lewis6991/gitsigns.nvim'

  "" On demand loading of plugins
  " Loaded when clojure file is opened
  Plug 'tpope/vim-fireplace', { 'for': 'clojure' }

  " Multiple file types
  Plug 'kovisoft/paredit', { 'for': ['clojure', 'scheme'] }

  " On-demand loading on both conditions
  Plug 'junegunn/vader.vim',  { 'on': 'Vader', 'for': 'vader' }

  " Code to execute when the plugin is lazily loaded on demand
  Plug 'junegunn/goyo.vim', { 'for': 'markdown' }

  " VSCode like autocompletion - https://github.com/neoclide/coc.nvim/
  Plug 'neoclide/coc.nvim', {'branch': 'release'}

  " Rust for file detection, syntax highlighting, formatting, Syntastic integration, and more - [GitHub - rust-lang/rust.vim: Vim configuration for Rust.](https://github.com/rust-lang/rust.vim)
  Plug 'rust-lang/rust.vim'

  " Reload nvim config with :Reload - https://github.com/famiu/nvim-reload
  Plug 'famiu/nvim-reload'

  " Better Filepane navigation - https://github.com/ms-jpq/chadtree
  Plug 'ms-jpq/chadtree', {'branch': 'chad', 'do': 'python3 -m chadtree deps'}

  " Place cursor hit <leader>j and awesome! - https://github.com/pechorin/any-jump.vim
  Plug 'pechorin/any-jump.vim'

  " BufferLine - akinsho/bufferline.nvim: A snazzy bufferline for Neovim - https://github.com/akinsho/bufferline.nvim
  Plug 'kyazdani42/nvim-web-devicons' " Recommended (for coloured icons)
  Plug 'akinsho/bufferline.nvim', { 'tag': 'v3.*' }

  " Treesitter - [GitHub - nvim-treesitter/nvim-treesitter: Nvim Treesitter configurations and abstraction layer](https://github.com/nvim-treesitter/nvim-treesitter)
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

  " https://github.com/folke/which-key.nvim
  Plug 'folke/which-key.nvim'

call plug#end()

" -----------------------------------------
" Options
set termguicolors
set background=dark
set clipboard=unnamedplus " Enables the clipboard between Vim/Neovim and other applications.
set completeopt=noinsert,menuone,noselect " Modifies the auto-complete menu to behave more like an IDE.
set cursorline " Highlights the current line in the editor
set hidden " Hide unused buffers
set autoindent " Indent a new line
set inccommand=split " Show replacements in a split screen
set mouse=a " Allow to use the mouse in the editor
set number " Shows the line numbers
set splitbelow splitright " Change the split screen behavior
set title " Show file title
set wildmenu " Show a more advance menu
" set cc=80 " Show at 80 column a border for good code style
filetype plugin indent on   " Allow auto-indenting depending on file type
syntax on
" set spell " enable spell check (may need to download language package)
set ttyfast " Speed up scrolling in Vim
set encoding=utf-8

" Make <leader> be comma rather than \
let mapleader = ","

" Keyboard shortcuts (telescope)
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>
nnoremap <leader>f <cmd>Telescope current_buffer_fuzzy_find<cr>

" Keyboard shortcuts (rust debugging with coc)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Keyboard shortcut for ChadOpen
nnoremap <leader>v <cmd>CHADopen<cr>

" Coc rust things
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" Ale config - https://github.com/dense-analysis/ale
" ESlint Config for w0rp/ale plugin
let g:ale_fixers = {
 \ 'javascript': ['eslint']
 \ }

let g:ale_sign_error = '❌'
let g:ale_sign_warning = '⚠️'

let g:ale_fix_on_save = 1
let g:ale_fixers = {
    \ '*': ['remove_trailing_lines', 'trim_whitespace'],
    \ 'rust': ['rustfmt'],
    \ }

" For BufferLine plugin
lua << EOF
  require("bufferline").setup{}
EOF

" For GitSigns plugin
lua << EOF
  require('gitsigns').setup()
EOF

" For WhichKey plugin
lua << EOF
  require("which-key").setup {}
EOF

colorscheme synthwave84