" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


function! openbrowser#github#load()
    " dummy function to load this script.
endfunction

function! openbrowser#github#file(args) range
    let file = expand(empty(a:args) ? '%' : a:args[0])
    if !filereadable(file)
        if a:0 is 0
            call s:error("current buffer is not a file.")
        else
            call s:error("'".file."' is not readable.")
        endif
        return
    endif

    let user    = s:get_github_user()
    let repos   = s:get_github_repos_name()
    let branch  = s:get_repos_branch()
    let relpath = s:get_repos_relpath(file)
    let rangegiven = a:firstline isnot 1 || a:lastline isnot line('$')
    if rangegiven
        let lnum  = '#L'.a:firstline
        \          .(a:firstline is a:lastline ? '' : '-L'.a:lastline)
    else
        let lnum = ''
    endif

    if user ==# ''
        call s:error('github.user is not set.')
        call s:error("Please set by 'git config github.user yourname'.")
        return
    endif
    if repos ==# ''
        call s:error('Could not detect current repos name on github.')
        return
    endif
    if branch ==# ''
        call s:error('Could not detect current branch name.')
        return
    endif
    if relpath ==# ''
        call s:error('Could not detect relative path of repository.')
        return
    endif

    call s:open_github_url(
    \   '/'.user.'/'.repos.'/blob/'.branch.'/'.relpath.lnum)
endfunction

function! openbrowser#github#issue(args)
    " '#1' and '1' are supported.
    let number = matchstr(a:args[0], '^#\?\zs\d\+\ze$')
    if number ==# ''
        call s:error("'".a:args[0]."' does not appear to be an issue number.")
        return
    endif

    let user  = s:get_github_user()
    let repos = s:get_github_repos_name()

    if user ==# ''
        call s:error('github.user is not set.')
        call s:error("Please set by 'git config github.user yourname'.")
        return
    endif
    if repos ==# ''
        call s:error('Could not detect current repos name on github.')
        return
    endif

    call s:open_github_url(
    \   '/'.user.'/'.repos.'/issues/'.number)
endfunction



function! s:get_github_user()
    return s:git('config', '--get', 'github.user')
endfunction

function! s:get_github_repos_name()
    let host = s:get_github_host()
    let host_re = substitute(host, '\.', '\.', 'g')
    let ssh_re = 'git@'.host_re.':[^/]\+/\([^/]\+\)\s'
    let git_re = 'git://'.host_re.'/[^/]\+/\([^/]\+\)\s'
    let https_re = 'https\?://'.host_re.'/[^/]\+/\([^/]\+\)\s'

    for line in s:git_lines('remote', '-v')
        for re in [ssh_re, git_re, https_re]
            let m = matchlist(line, re)
            if !empty(m)
                return substitute(m[1], '\.git$', '', '')
            endif
        endfor
    endfor
    return ''
endfunction

function! s:get_repos_branch()
    let lines = s:git_lines('branch')
    let re = '\* '
    call filter(lines, 'v:val =~# re')
    if empty(lines)
        return ''
    endif
    let idx = matchend(lines[0], re)
    return idx >= 0 ? lines[0][idx :] : ''
endfunction

function! s:get_repos_relpath(file)
    let relpath = ''
    if s:is_relpath(a:file)
        let dir = s:git('rev-parse', '--show-prefix')
        let dir = dir !=# '' ? dir.'/' : ''
        let relpath = substitute(dir.a:file, '/\{2,}', '/', 'g')
    else
        " TODO
        call s:error('absolute path is not supported yet. -> '.a:file)
    endif
    return relpath
endfunction

function! s:is_relpath(path)
    return a:path !=# '' && a:path[0] !=# '/'
endfunction

function! s:open_github_url(path)
    let endpoint = 'http://'.s:get_github_host()
    return openbrowser#open(endpoint.a:path)
endfunction

function! s:get_github_host()
    " Enterprise GitHub is supported.
    " ('hub' command is using this config key)
    let url = s:git('config', '--get', 'hub.host')
    return url !=# '' ? url : 'github.com'
endfunction



function! s:git(...)
    return s:trim(system(join(['git'] + a:000, ' ')))
endfunction

function! s:git_lines(...)
    let output = call('s:git', a:000)
    let keepempty = 1
    return split(output, '\n', keepempty)
endfunction



function! s:trim(str)
    let str = a:str
    let str = substitute(str, '^[ \t\n]\+', '', 'g')
    let str = substitute(str, '[ \t\n]\+$', '', 'g')
    return str
endfunction

function! s:error(msg)
    echohl ErrorMsg
    try
        echomsg 'openbrowser/github:' a:msg
    finally
        echohl None
    endtry
endfunction


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
