" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:V = vital#of('open-browser-github.vim')
let s:Filepath = s:V.import('System.Filepath')
let s:List = s:V.import('Data.List')


function! openbrowser#github#load()
    " dummy function to load this script.
endfunction

function! openbrowser#github#file(args) range
    let file = expand(empty(a:args) ? '%' : a:args[0])
    let gitdir = s:lookup_gitdir(file)
    call s:call_with_temp_dir(gitdir, 's:cmd_file', [a:args, a:firstline, a:lastline])
endfunction

function! s:cmd_file(args, firstlnum, lastlnum)
    let file = expand(empty(a:args) ? '%' : a:args[0])
    if !filereadable(file)
        if a:0 is 0
            call s:error("current buffer is not a file.")
        else
            call s:error("'".file."' is not readable.")
        endif
        return
    endif

    let github_host  = s:get_github_host()
    try
        let github_repos =
        \   s:detect_github_repos_from_git_remote(github_host)
    catch /^INVALID INDEX$/
        call s:error('invalid GitHub URL was selected.')
        return
    endtry
    let user    = get(github_repos, 'user', '')
    let repos   = get(github_repos, 'repos', '')
    let branch  = s:get_repos_branch()
    let relpath = s:get_repos_relpath(file)
    let rangegiven = a:firstlnum isnot 1 || a:lastlnum isnot line('$')
    if rangegiven
        let lnum  = '#L'.a:firstlnum
        \          .(a:firstlnum is a:lastlnum ? '' : '-L'.a:lastlnum)
    else
        let lnum = ''
    endif

    if user ==# ''
        call s:error('Could not detect repos user.')
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
    \   github_host,
    \   '/'.user.'/'.repos.'/blob/'.branch.'/'.relpath.lnum)
endfunction

function! openbrowser#github#issue(args)
    let file = expand('%')
    let gitdir = s:lookup_gitdir(file)
    call s:call_with_temp_dir(gitdir, 's:cmd_issue', [a:args])
endfunction

function! s:cmd_issue(args)
    " '#1' and '1' are supported.
    let number = matchstr(a:args[0], '^#\?\zs\d\+\ze$')
    if number ==# ''
        call s:error("'".a:args[0]."' does not appear to be an issue number.")
        return
    endif

    let github_host = s:get_github_host()
    let mlist = matchlist(get(a:args, 1, ''),
    \                     '^\([^/]\+\)/\([^/]\+\)$')
    if !empty(mlist)
        let user  = mlist[1]
        let repos = mlist[2]
    else
        try
            let github_repos =
            \   s:detect_github_repos_from_git_remote(github_host)
        catch /^INVALID INDEX$/
            call s:error('invalid GitHub URL was selected.')
            return
        endtry
        let user         = get(github_repos, 'user', '')
        let repos        = get(github_repos, 'repos', '')
    endif

    if user ==# ''
        call s:error('Could not detect repos user.')
        return
    endif
    if repos ==# ''
        call s:error('Could not detect current repos name on github.')
        return
    endif

    call s:open_github_url(
    \   github_host,
    \   '/'.user.'/'.repos.'/issues/'.number)
endfunction



function! s:call_with_temp_dir(dir, funcname, args)
    let haslocaldir = haslocaldir()
    let cwd = getcwd()
    if a:dir !=# '' && a:dir !=# cwd
        execute 'lcd' a:dir
    endif
    try
        return call(a:funcname, a:args)
    finally
        if a:dir !=# cwd
            execute (haslocaldir ? 'lcd' : 'cd') cwd
        endif
    endtry
endfunction

function! s:parse_github_remote_url(github_host)
    let host_re = substitute(a:github_host, '\.', '\.', 'g')
    let gh_host_re = 'github\.com'

    let ssh_re_fmt = 'git@%s:\([^/]\+\)/\([^/]\+\)\s'
    let git_re_fmt = 'git://%s/\([^/]\+\)/\([^/]\+\)\s'
    let https_re_fmt = 'https\?://%s/\([^/]\+\)/\([^/]\+\)\s'

    let ssh_re = printf(ssh_re_fmt, host_re)
    let git_re = printf(git_re_fmt, host_re)
    let https_re = printf(https_re_fmt, host_re)

    let gh_ssh_re = printf(ssh_re_fmt, gh_host_re)
    let gh_git_re = printf(git_re_fmt, gh_host_re)
    let gh_https_re = printf(https_re_fmt, gh_host_re)

    let matched = []
    for line in s:git_lines('remote', '-v')
        " Even if host is not 'github.com',
        " parse also 'github.com'.
        for re in [ssh_re, git_re, https_re] +
        \   (a:github_host !=# 'github.com' ?
        \       [gh_ssh_re, gh_git_re, gh_https_re] : [])
            let m = matchlist(line, re)
            if !empty(m)
                call add(matched, {
                \   'user': m[1],
                \   'repos': substitute(m[2], '\.git$', '', ''),
                \})
            endif
        endfor
    endfor
    return matched
endfunction

function! s:detect_github_repos_from_git_remote(github_host)
    let github_urls = s:parse_github_remote_url(a:github_host)
    let github_urls = s:List.uniq(github_urls, 'v:val.user."/".v:val.repos')
    let NONE = {}
    if len(github_urls) ==# 0
        return NONE
    elseif len(github_urls) ==# 1
        return github_urls[0]
    else
        " Prompt which GitHub URL.
        let GITHUB_URL_FORMAT = 'http://%s/%s/%s'
        let list = ['Which GitHub repository?']
        for i in range(len(github_urls))
            let url = printf(GITHUB_URL_FORMAT,
            \                a:github_host,
            \                github_urls[i].user,
            \                github_urls[i].repos)
            call add(list, (i+1).'. '.url)
        endfor
        let index = inputlist(list)
        if 1 <=# index && index <=# len(github_urls)
            return github_urls[index-1]
        else
            throw 'INVALID INDEX'
        endif
    endif
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
        let relpath = dir.a:file
    else
        let relpath = s:lookup_relpath_from_gitdir(a:file)
    endif
    let relpath = substitute(relpath, '\', '/', 'g')
    let relpath = substitute(relpath, '/\{2,}', '/', 'g')
    return relpath
endfunction

function! s:lookup_relpath_from_gitdir(path)
    return get(s:split_repos_path(a:path), 1, '')
endfunction

function! s:lookup_gitdir(path)
    return get(s:split_repos_path(a:path), 0, '')
endfunction

" Returns [gitdir, relative path] when git dir is found.
" Otherwise, returns empty List.
function! s:split_repos_path(dir, ...)
    let parent = s:Filepath.dirname(a:dir)
    let basename = s:Filepath.basename(a:dir)
    let removed_path = a:0 ? a:1 : ''
    if a:dir ==# parent
        " a:dir is root directory. not found.
        return []
    elseif s:is_git_dir(a:dir)
        return [a:dir, removed_path]
    else
        if removed_path ==# ''
            let removed_path = basename
        else
            let removed_path = s:Filepath.join(basename, removed_path)
        endif
        return s:split_repos_path(parent, removed_path)
    endif
endfunction

function! s:is_git_dir(dir)
    " .git may be a file when its repository is a submodule.
    let dotgit = s:Filepath.join(a:dir, '.git')
    return isdirectory(dotgit) || filereadable(dotgit)
endfunction

function! s:is_relpath(path)
    return a:path !=# '' && a:path[0] !=# '/'
endfunction

function! s:open_github_url(github_host, path)
    let endpoint = 'http://'.a:github_host
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
