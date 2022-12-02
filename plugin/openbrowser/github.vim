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


function! s:error(msg) abort
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
if !exists('g:openbrowser_github_always_use_upstream_commit_hash')
  let g:openbrowser_github_always_use_upstream_commit_hash = 0
endif
if !exists('g:openbrowser_github_url_exists_check')
  let g:openbrowser_github_url_exists_check = 'yes'
endif
if !exists('g:openbrowser_github_select_current_line')
  let g:openbrowser_github_select_current_line = 0
endif


command! -range=0 -bar -nargs=* -complete=file
\   OpenGithubFile
\   call openbrowser#github#file([<f-args>], <count>, <line1>, <line2>)

command! -bar -nargs=*
\   OpenGithubIssue
\   call openbrowser#github#issue([<f-args>])

command! -bar -nargs=*
\   OpenGithubPullReq
\   call openbrowser#github#pullreq([<f-args>])

command! -bar -nargs=*
\   OpenGithubProject
\   call openbrowser#github#project([<f-args>])

command! -bar -nargs=+
\   OpenGithubCommit
\   call openbrowser#github#commit([<f-args>])


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
