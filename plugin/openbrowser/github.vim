" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Load Once {{{
if get(g:, 'loaded_openbrowser_github', 0) || &cp
    finish
endif
let g:loaded_openbrowser_github = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


function! s:error(msg)
    echohl ErrorMsg
    echomsg a:msg
    echohl None
endfunction

if !executable('git')
    call s:error('Please install git in your PATH.')
    finish
endif
if globpath(&rtp, 'plugin/openbrowser.vim') ==# ''
    call s:error('open-browser-github.vim depends on open-browser.vim. Please install open-browser.vim')
    finish
endif

if !exists('g:openbrowser_github_always_used_branch')
    let g:openbrowser_github_always_used_branch = ''
endif
if !exists('g:openbrowser_github_always_use_commit_hash')
    let g:openbrowser_github_always_use_commit_hash = 1
endif


command! -range=0 -bar -nargs=* -complete=file
\   OpenGithubFile
\   call openbrowser#github#file([<f-args>], <count>, <line1>, <line2>)

command! -bar -nargs=*
\   OpenGithubIssue
\   call openbrowser#github#issue([<f-args>])

" GitHub redirects /issues/1 to /pull/1 if #1 is pull req.
command! -bar -nargs=*
\   OpenGithubPullReq
\   OpenGithubIssue <args>


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
