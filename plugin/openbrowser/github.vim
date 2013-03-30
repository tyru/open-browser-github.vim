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


if globpath(&rtp, 'plugin/openbrowser.vim') ==# ''
    echohl ErrorMsg
    echomsg 'open-browser-github.vim depends on open-browser.vim. Please install open-browser.vim'
    echohl None
    finish
endif

if !exists('g:openbrowser_github_always_used_branch')
    let g:openbrowser_github_always_used_branch = ''
endif


command! -range=0 -bar -nargs=* -complete=file
\   OpenGithubFile
\   call openbrowser#github#file([<f-args>], <count>, <line1>, <line2>)

command! -bar -nargs=+
\   OpenGithubIssue
\   call openbrowser#github#issue([<f-args>])

" GitHub redirects /issues/1 to /pull/1 if #1 is pull req.
command! -bar -nargs=+
\   OpenGithubPullReq
\   OpenGithubIssue <args>


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
