" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:V = vital#of('open_browser_github')
let s:Filepath = s:V.import('System.Filepath')
let s:List = s:V.import('Data.List')
unlet s:V


function! openbrowser#github#load()
    " dummy function to load this script.
endfunction

function! openbrowser#github#file(args, rangegiven, firstlnum, lastlnum)
    let file = s:resolve(expand(empty(a:args) ? '%' : a:args[0]))
    let gitdir = s:lookup_gitdir(file)
    call s:call_with_temp_dir(gitdir, 's:cmd_file', [a:args, a:rangegiven, a:firstlnum, a:lastlnum])
endfunction

" Opens a specific file in github.com repository.
"
" ex)
" Opens current files URL in github.com
"   :OpenGithubFile
" Opens current files highlighted place in github.com
"   :'<,'>OpenGithubFile
" Opens a specific file in github.com
"   :OpenGithubFile PATH/TO/FILE
function! s:cmd_file(args, rangegiven, firstlnum, lastlnum)
    let file = s:resolve(expand(empty(a:args) ? '%' : a:args[0]))
    if !filereadable(file)
        if a:0 is 0
            call s:error("current buffer is not a file.")
        else
            call s:error("'".file."' is not readable.")
        endif
        return
    endif

    let relpath = s:get_repos_relpath(file)

    if g:openbrowser_github_always_used_branch !=# ''
        let branch = g:openbrowser_github_always_used_branch
    elseif g:openbrowser_github_always_use_commit_hash
        let branch = s:git('rev-parse', 'HEAD')
    else
        " When working tree is detached state,
        " branch becomes commit hash.
        let head_ref = s:git('symbolic-ref', '--short', '-q', 'HEAD')
        let is_detached_state = (head_ref ==# '')
        if is_detached_state
            let branch = s:git('rev-parse', 'HEAD')
        else
            let branch = head_ref
        endif
    endif

    if a:rangegiven
        let lnum = '#L'.a:firstlnum
        \          .(a:firstlnum is a:lastlnum ? '' : '-L'.a:lastlnum)
    else
        let lnum = ''
    endif

    " Check input values.
    if branch ==# ''
        call s:error('Could not detect current branch name.')
        return
    endif
    if relpath ==# ''
        call s:error('Could not detect relative path of repository.')
        return
    endif

    let path = 'blob/' . branch . '/' . relpath . lnum

    if executable('hub')
        let url = s:hub('browse', '-u', '--', path)
    else
        let github_host = s:get_github_host()

        " May prompt user to choose which repos is used.
        try
            let github_repos =
            \   s:detect_github_repos_from_git_remote(github_host)
        catch /^INVALID INDEX$/
            call s:error('canceled or invalid GitHub URL was selected.')
            return
        endtry

        let user  = get(github_repos, 'user', '')
        let repos = get(github_repos, 'repos', '')
        if user ==# ''
            call s:error('Could not detect repos user.')
            return
        endif
        if repos ==# ''
            call s:error('Could not detect current repos name on github.')
            return
        endif

        let url = 'https://' . github_host . '/' . user . '/' . repos . '/' . path
    endif
    if !s:url_exists(url) && input(
    \   "Maybe you are opening a URL which is not git-push'ed yet. OK?[y/n]: "
    \) !~? '^\%[YES]$'
        " TODO: Retry
        return
    endif
    return openbrowser#open(url)
endfunction

function! s:url_exists(url)
    if g:openbrowser_github_url_exists_check ==# 'ignore'
        return 1
    endif
    if g:openbrowser_github_url_exists_check ==# 'yes'
    \   && !executable('curl')
        call s:warn("You must have 'curl' command to check whether the opening URL exists.")
        call s:warn("You can suppress this check by writing the following "
        \         . "config in your vimrc (:help g:openbrowser_github_url_exists_check).")
        call s:warn("  let g:openbrowser_github_url_exists_check = 'ignore'")
        call input('Press ENTER to continue...')
        return 1
    endif
    let cmdline = 'curl -k -LI "' . a:url . '"'
    let headers = split(system(cmdline), '\n')
    if v:shell_error
        call s:warn(cmdline)
        call s:warn('curl returned error code: ' . v:shell_error)
        return 1
    endif
    let status_line = get(filter(headers, 'v:val =~# "^Status:"'), 0, '')
    if status_line ==# ''
        call s:warn(cmdline)
        call s:warn("curl received a response without 'Status' header.")
        return 1
    endif
    return status_line =~# '^Status:\s*2'
endfunction

let s:TYPE_ISSUE = 0
function! openbrowser#github#issue(args)
    let file = expand('%')
    let gitdir = s:lookup_gitdir(file)
    call s:call_with_temp_dir(gitdir, 's:cmd_open_url', [a:args, s:TYPE_ISSUE])
endfunction

let s:TYPE_PULLREQ = 1
function! openbrowser#github#pullreq(args)
    let file = expand('%')
    let gitdir = s:lookup_gitdir(file)
    call s:call_with_temp_dir(gitdir, 's:cmd_open_url', [a:args, s:TYPE_PULLREQ])
endfunction

let s:TYPE_PROJECT = 2
function! openbrowser#github#project(args)
    let file = expand('%')
    let gitdir = s:lookup_gitdir(file)
    call s:call_with_temp_dir(gitdir, 's:cmd_open_url', [a:args, s:TYPE_PROJECT])
endfunction

" Opens a specific Issue/Pullreq/Project.
"
" ex)
" Opens current repositories Issue #1
"   :OpenGithubIssue 1
" Opens a specific repositories Issue #1
"   :OpenGithubIssue 1 tyru/open-browser.vim
" Opens current repositories Issue List
"   :OpenGithubIssue
" Opens a specific repositories Issue List
"   :OpenGithubIssue tyru/open-browser.vim
function! s:cmd_open_url(args, type)
    " Both '#1' and '1' are supported.
    let number = matchstr(get(a:args, 0, ''), '^#\?\zs\d\+\ze$')

    if a:type ==# s:TYPE_ISSUE
        if number !=# ''
            let path = 'issues/' . number
        else
            let path = 'issues'
        endif
    elseif a:type ==# s:TYPE_PULLREQ
        if number !=# ''
            let path = 'pull/' . number
        else
            let path = 'pulls'
        endif
    else    " if a:type ==# s:TYPE_PROJECT
        let path = ''
    endif

    if executable('hub')
        let url = s:hub('browse', '-u', '--', path)
    else

        let github_host = s:get_github_host()

        " If the issue number is omitted, the index of argument of repository will
        " become 0 (a:args[0]), otherwise 1 (a:args[1])
        let repos_arg_index = number == '' ? 0 : 1

        " If the argument of repository was given and valid format,
        " set user and repos.
        let mlist = matchlist(get(a:args, repos_arg_index, ''),
        \                     '^\([^/]\+\)/\([^/]\+\)$')
        if !empty(mlist)
            let user  = mlist[1]
            let repos = mlist[2]
        else
            try
                let github_repos =
                \   s:detect_github_repos_from_git_remote(github_host)
            catch /^INVALID INDEX$/
                call s:error('canceled or invalid GitHub URL was selected.')
                return
            endtry
            let user  = get(github_repos, 'user', '')
            let repos = get(github_repos, 'repos', '')
        endif

        " Check input values.
        if user ==# ''
            call s:error('Could not detect repos user.')
            return
        endif
        if repos ==# ''
            call s:error('Could not detect current repos name on github.')
            return
        endif
        let url = 'https://' . github_host . '/' . user . '/' . repos . '/' . path
    endif
    return openbrowser#open(url)
endfunction



function! s:call_with_temp_dir(dir, funcname, args)
    let haslocaldir = haslocaldir()
    let cwd = getcwd()
    " a:dir could be empty string
    " when specifying opening repos.
    " e.g.)
    " * :OpenGithubFile path/to/file
    " * :OpenGithubIssue {number} {user}/{repos}
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
    let host_re = escape(a:github_host, '.')
    let gh_host_re = 'github\.com'

    " ex) ssh_re_fmt also supports 'ssh://' protocol. (#10)
    " - git@github.com:tyru/open-github-browser.vim
    " - ssh://git@github.com/tyru/open-github-browser.vim
    let ssh_re_fmt = 'git@%s[:/]\([^/]\+\)/\([^/]\+\)\s'
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

" Detect user name and repos name from 'git remote -v' output.
" * Duplicated candidates of user and repos are removed.
" * Returns empty Dictionary if no valid GitHub repos are found.
" * Returns an Dictionary with 'user' and 'repos'
"   if exact 1 repos is found.
" * Prompt a user to choose which repos
"   if 2 or more repos are found.
"   * Throws "INVALID INDEX" if invalid input was given.
function! s:detect_github_repos_from_git_remote(github_host)
    let github_urls = s:parse_github_remote_url(a:github_host)
    let github_urls = s:List.uniq_by(github_urls, 'v:val.user."/".v:val.repos')
    let NONE = {}
    if len(github_urls) ==# 0
        return NONE
    elseif len(github_urls) ==# 1
        return github_urls[0]
    else
        " Prompt which GitHub URL.
        let GITHUB_URL_FORMAT = 'https://%s/%s/%s'
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

function! s:get_repos_relpath(file)
    let relpath = ''
    if s:Filepath.is_relative(a:file)
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

function! s:get_github_host()
    " Enterprise GitHub is supported.
    " ('hub' command is using this config key)
    let url = s:git('config', '--get', 'hub.host')
    return url !=# '' ? url : 'github.com'
endfunction



if g:openbrowser_use_vimproc
\       && globpath(&rtp, 'autoload/vimproc.vim') !=# ''
    function! s:git(...)
        return s:trim(vimproc#system(['git'] + a:000))
    endfunction

    function! s:hub(...)
        return s:trim(vimproc#system(['hub'] + a:000))
    endfunction
else
    function! s:git(...)
        return s:trim(system(join(['git'] + a:000, ' ')))
    endfunction

    function! s:hub(...)
        return s:trim(system(join(['hub'] + a:000, ' ')))
    endfunction
endif

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

function! s:resolve(path)
    return exists('*resolve') ? resolve(a:path) : a:path
endfunction

function! s:echomsg(msg, hl)
    execute 'echohl' a:hl
    try
        echomsg '[openbrowser-github]' a:msg
    finally
        echohl None
    endtry
endfunction

function! s:warn(msg)
    call s:echomsg(a:msg, 'WarningMsg')
endfunction

function! s:error(msg)
    call s:echomsg(a:msg, 'ErrorMsg')
endfunction


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
