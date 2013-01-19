" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


function! openbrowser#github#load()
    " dummy function to load this script.
endfunction

function! openbrowser#github#file(args)
    " TODO
endfunction

function! openbrowser#github#issue(args)
    " TODO
endfunction


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
