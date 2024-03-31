set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
call plug#begin()
Plug 'Raimondi/delimitMate.git'
Plug 'preservim/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'fholgado/minibufexpl.vim'
Plug 'tomasr/molokai'
Plug 'gkjgh/cobalt.git'
Plug 'vim-airline/vim-airline.git'
Plug 'felixhummel/setcolors.vim'
Plug 'tpope/vim-fugitive.git'
Plug 'airblade/vim-gitgutter.git'
Plug 'skywind3000/vim-quickui'
"Plug 'ludovicchabant/vim-gutentags.git'


call plug#end()
filetype plugin indent on
syntax on
set number
set ic
set wrap
"to disable mouse completely
"set mouse=
set mouse=a
set guifont=Source\ Code\ Pro:h14 
set showmatch
set tabstop=4
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<
set list
nmap <F4> :colorscheme cobalt<CR>
nmap <F5> :colorscheme molokai<CR>
nmap <F6> :NERDTreeToggle<CR>
imap <F6> :NERDTreeToggle<CR>
let NERDTreeShowHidden=1

let GitGutterBufferEnable=1
let GitGutterEnable=1
let g:gitgutter_sign_added = '++'
let g:gitgutter_sign_modified = 'mm'
let g:gitgutter_sign_removed = '--'
let g:gitgutter_sign_removed_first_line = '^^'
let g:gitgutter_sign_modified_removed = '-w'

"indentLine plugin conceals chars without warning. turn it off.
let g:indentLine_setConceal = 0

colorscheme cobalt

autocmd VimEnter * NERDTree
autocmd VimEnter * wincmd p
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif





