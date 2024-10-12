" Tab exp
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smartindent

" General
set hidden
set number
set relativenumber
syntax on
set scrolloff=8
colorscheme desert

" Golang
command! Gobuild :!go build
command! Go :!go build

" C-like comments
nnoremap <C-/> I// <Esc>
vnoremap <C-/> I// <Esc>
nnoremap <C-\> ^xxx
vnoremap <C-\> ^xxx

