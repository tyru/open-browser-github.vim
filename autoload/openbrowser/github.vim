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


function! openbrowser#github#load() abort
  " dummy function to load this script.
endfunction

function! openbrowser#github#file(args, rangegiven, firstlnum, lastlnum) abort
  let file = s:resolve(expand(get(a:args, 0, '%')))
  let worktree = s:lookup_git_worktree(file)
  let lastlnum = max([a:firstlnum, a:lastlnum]) " a:firstlnum could be bigger in NeoVim
  call s:call_with_temp_dir(worktree, 's:cmd_file', [a:args, a:rangegiven, a:firstlnum, lastlnum])
endfunction

" Opens a specific file in github.com repository.
function! s:cmd_file(args, rangegiven, firstlnum, lastlnum) abort
  let rangegiven = a:rangegiven || get(g:, 'openbrowser_github_select_current_line', 0)
  let [path, err] = s:parse_cmd_file_args(a:args, rangegiven, a:firstlnum, a:lastlnum)
  if err !=# ''
    call s:error(err)
    return
  endif
  if executable('hub')
    let url = s:hub('browse', '-u', '--', path)
  else
    let [url, err] = s:get_url_from_git({'path': path})
    if err !=# ''
      call s:error(err)
      return
    endif
  endif
  if !s:url_exists(url) && input(
  \   "Maybe you are opening a URL which is not git-push'ed yet. OK?[y/n]: "
  \) !~? '^\%[YES]$'
    " TODO: Retry
    return
  endif
  return openbrowser#open(url)
endfunction

" * :OpenGithubFile [{path}]
function! s:parse_cmd_file_args(args, rangegiven, firstlnum, lastlnum) abort
  let file = s:resolve(expand(empty(a:args) ? '%' : a:args[0]))
  if !filereadable(file)
    if a:0 is 0
      return ['', 'current buffer is not a file.']
    else
      return ['', printf('''%s'' is not readable.', file)]
    endif
  endif

  let relpath = s:get_repos_relpath(file)

  if g:openbrowser_github_always_used_branch !=# ''
    let branch = g:openbrowser_github_always_used_branch
  elseif g:openbrowser_github_always_use_commit_hash
    if g:openbrowser_github_always_use_upstream_commit_hash
      let branch = s:git('rev-parse', 'HEAD@{upstream}')
    else
      let branch = s:git('rev-parse', 'HEAD')
    endif
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
    return ['', 'Could not detect current branch name.']
  endif
  if relpath ==# ''
    return ['', 'Could not detect relative path of repository.']
  endif

  let path = 'blob/' . branch . '/' . relpath . lnum
  return [path, '']
endfunction

function! s:get_url_from_git(repoinfo) abort
  let host = s:get_github_host()
  let user = get(a:repoinfo, 'user', '')
  let repos = get(a:repoinfo, 'repos', '')
  let path = get(a:repoinfo, 'path', '')

  if user ==# '' || repos ==# ''
    " May prompt user to choose which repos is used.
    try
      let github_repos =
      \   s:detect_github_repos_from_git_remote(host)
    catch /^INVALID INDEX$/
      return ['', 'canceled or invalid GitHub URL was selected.']
    endtry
    let user  = get(github_repos, 'user', '')
    let repos = get(github_repos, 'repos', '')
  endif

  if user ==# ''
    return ['', 'Could not detect repos user.']
  endif
  if repos ==# ''
    return ['', 'Could not detect current repos name on github.']
  endif

  let url = 'https://' . host . '/' . user . '/' . repos . '/' . path
  return [url, '']
endfunction

function! s:url_exists(url) abort
  if g:openbrowser_github_url_exists_check ==# 'ignore'
    return 1
  endif
  if !executable('curl')
    call s:warn('You must have ''curl'' command to check whether the opening URL exists.')
    call s:warn('You can suppress this check by writing the following '
    \         . 'config in your vimrc (:help g:openbrowser_github_url_exists_check).')
    call s:warn('  let g:openbrowser_github_url_exists_check = ''ignore''')
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
  let re = '^status:'
  let status_line = get(filter(headers, 'v:val =~? re'), 0, '')
  if status_line ==# ''
    call s:warn(cmdline)
    call s:warn('curl received a response without ''Status'' header.')
    return 1
  endif
  return status_line =~? '^status:\s*2'
endfunction

let s:TYPE_ISSUE = 0
function! openbrowser#github#issue(args) abort
  let file = expand('%')
  let worktree = s:lookup_git_worktree(file)
  call s:call_with_temp_dir(worktree, 's:cmd_open_url', [a:args, s:TYPE_ISSUE])
endfunction

let s:TYPE_PULLREQ = 1
function! openbrowser#github#pullreq(args) abort
  let file = expand('%')
  let worktree = s:lookup_git_worktree(file)
  call s:call_with_temp_dir(worktree, 's:cmd_open_url', [a:args, s:TYPE_PULLREQ])
endfunction

let s:TYPE_PROJECT = 2
function! openbrowser#github#project(args) abort
  let file = expand('%')
  let worktree = s:lookup_git_worktree(file)
  call s:call_with_temp_dir(worktree, 's:cmd_open_url', [a:args, s:TYPE_PROJECT])
endfunction

let s:TYPE_COMMIT = 3
function! openbrowser#github#commit(args) abort
  let file = expand('%')
  let worktree = s:lookup_git_worktree(file)
  call s:call_with_temp_dir(worktree, 's:cmd_open_url', [a:args, s:TYPE_COMMIT])
endfunction

" Opens a specific Issue/Pullreq/Project.
function! s:cmd_open_url(...) abort
  try
    let repoinfo = call('s:parse_cmd_open_url_args', a:000)
  catch
    call s:error(v:exception)
    return
  endtry
  if executable('hub')
    let url = s:hub('browse', '-u', '--', repoinfo.path)
  else
    let [url, err] = s:get_url_from_git(repoinfo)
    if err !=# ''
      call s:error(err)
      return
    endif
  endif
  return openbrowser#open(url)
endfunction

" * :OpenGithubIssue
" * :OpenGithubIssue [#]{number} [{user}/{repos}]
" * :OpenGithubIssue {user}/{repos}
" * :OpenGithubPullReq
" * :OpenGithubPullReq [#]{number} [{user}/{repos}]
" * :OpenGithubPullReq #{branch} [{user}/{repos}]
" * :OpenGithubPullReq {user}/{repos}
" * :OpenGithubProject [{user}/{repos}]
" * :OpenGithubCommit {commit hash} [{user}/{repos}]
function! s:parse_cmd_open_url_args(args, type) abort
  if a:type ==# s:TYPE_ISSUE
    " ex) '#1', '1'
    let nr = matchstr(get(a:args, 0, ''), '^#\?\zs\d\+\ze$')
    if nr !=# ''
      let path = 'issues/' . nr
    else
      let path = 'issues'
    endif
    " If the argument of repository was given and valid format, get user and repos.
    let idx = nr ==# '' ? 0 : 1
    let m = matchlist(get(a:args, idx, ''),
    \                     '^\([^/]\+\)/\([^/]\+\)$')
    let [user, repos] = !empty(m) ? m[1:2] : ['', '']
  elseif a:type ==# s:TYPE_PULLREQ
    " ex) '#1', '1', '#branch_name_of_pull_request'
    let nr_or_branch = matchstr(get(a:args, 0, ''), '^\%(#\?\zs\d\+\ze\|#\zs.\+\ze\)$')
    if nr_or_branch !=# ''
      let path = 'pull/' . nr_or_branch
    else
      let path = 'pulls'
    endif
    " If the argument of repository was given and valid format, get user and repos.
    let idx = nr_or_branch ==# '' ? 0 : 1
    let m = matchlist(get(a:args, idx, ''),
    \                     '^\([^/]\+\)/\([^/]\+\)$')
    let [user, repos] = !empty(m) ? m[1:2] : ['', '']
  elseif a:type ==# s:TYPE_PROJECT
    let path = ''
    let m = matchlist(get(a:args, 0, ''),
    \                     '^\([^/]\+\)/\([^/]\+\)$')
    let [user, repos] = !empty(m) ? m[1:2] : ['', '']
  else    " if a:type ==# s:TYPE_COMMIT
    if len(a:args) > 1
      let hash = a:args[0]
    else
      let hash = s:git('rev-parse', a:args[0])
      if v:shell_error
        throw "'" . a:args[0] .  "' is not valid commit hash"
      endif
    endif
    let path = 'commit/' . hash
    let m = matchlist(get(a:args, 1, ''),
    \                     '^\([^/]\+\)/\([^/]\+\)$')
    let [user, repos] = !empty(m) ? m[1:2] : ['', '']
  endif

  return {
  \ 'path': path,
  \ 'user': user,
  \ 'repos': repos,
  \}
endfunction


function! s:call_with_temp_dir(dir, funcname, args) abort
  let haslocaldir = haslocaldir()
  let cwd = getcwd()
  " a:dir could be empty string
  " when specifying opening repos.
  " e.g.)
  " * :OpenGithubFile path/to/file
  " * :OpenGithubIssue [#]{number} {user}/{repos}
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

function! s:parse_github_remote_url(github_host) abort
  let host_re = escape(a:github_host, '.')
  let gh_host_re = 'github\.com'

  " ex) ssh_re_fmt also supports 'ssh://' protocol. (#10)
  " - git@github.com:tyru/open-github-browser.vim
  " - ssh://git@github.com/tyru/open-github-browser.vim
  let ssh_re_fmt = 'git@%s[:/]\([^/]\+\)/\([^/]\+\)\s'
  let ssh2_re_fmt = '\s%s[:/]\([^/]\+\)/\([^/]\+\)\s'
  let ssh3_re_fmt = 'ssh://%s/\([^/]\+\)/\([^/]\+\)\s'
  let git_re_fmt = 'git://%s/\([^/]\+\)/\([^/]\+\)\s'
  let https_re_fmt = 'https\?://%s/\([^/]\+\)/\([^/]\+\)\s'

  let ssh_re = printf(ssh_re_fmt, host_re)
  let ssh2_re = printf(ssh2_re_fmt, host_re)
  let ssh3_re = printf(ssh3_re_fmt, host_re)
  let git_re = printf(git_re_fmt, host_re)
  let https_re = printf(https_re_fmt, host_re)

  let gh_ssh_re = printf(ssh_re_fmt, gh_host_re)
  let gh_ssh2_re = printf(ssh2_re_fmt, gh_host_re)
  let gh_ssh3_re = printf(ssh3_re_fmt, gh_host_re)
  let gh_git_re = printf(git_re_fmt, gh_host_re)
  let gh_https_re = printf(https_re_fmt, gh_host_re)

  let matched = []
  for line in s:git_lines('remote', '-v')
    " Even if host is not 'github.com',
    " parse also 'github.com'.
    for re in [ssh_re, ssh2_re, ssh3_re, git_re, https_re] +
    \   (a:github_host !=# 'github.com' ?
    \       [gh_ssh_re, gh_ssh2_re, gh_ssh3_re, gh_git_re, gh_https_re] : [])
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
function! s:detect_github_repos_from_git_remote(github_host) abort
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

function! s:get_repos_relpath(file) abort
  let relpath = ''
  if s:Filepath.is_relative(a:file)
    let dir = s:git('rev-parse', '--show-prefix')
    let dir = dir !=# '' ? dir.'/' : ''
    let relpath = dir.a:file
  else
    let relpath = s:lookup_git_relpath(a:file)
  endif
  let relpath = substitute(relpath, '\', '/', 'g')
  let relpath = substitute(relpath, '/\{2,}', '/', 'g')
  return relpath
endfunction

function! s:lookup_git_relpath(path) abort
  return get(s:split_repos_path(a:path), 1, '')
endfunction

function! s:lookup_git_worktree(path) abort
  return get(s:split_repos_path(a:path), 0, '')
endfunction

" Returns [git worktree, relative path] when git dir is found.
" Otherwise, returns empty List.
function! s:split_repos_path(path, ...) abort
  let parent = s:Filepath.dirname(a:path)
  let basename = s:Filepath.basename(a:path)
  let removed_path = a:0 ? a:1 : ''
  if a:path ==# parent
    " a:path is root directory. not found.
    return []
  elseif s:is_git_worktree(a:path)
    return [a:path, removed_path]
  else
    if removed_path ==# ''
      let removed_path = basename
    else
      let removed_path = s:Filepath.join(basename, removed_path)
    endif
    return s:split_repos_path(parent, removed_path)
  endif
endfunction

function! s:is_git_worktree(path) abort
  " .git may be a file when its repository is a submodule.
  let gitdir = s:Filepath.join(a:path, '.git')
  return isdirectory(gitdir) || filereadable(gitdir)
endfunction

" Enterprise GitHub is supported.
" ('hub' command is using this config key)
function! s:get_github_host() abort
  let url = s:git('config', '--get', 'hub.host')
  return url !=# '' ? url : 'github.com'
endfunction



" Default value is 1 (use vimproc)
if get(g:, 'openbrowser_use_vimproc', 1)
\       && globpath(&rtp, 'autoload/vimproc.vim') !=# ''
  function! s:git(...) abort
    return s:trim(vimproc#system(['git'] + a:000))
  endfunction

  function! s:hub(...) abort
    return s:trim(vimproc#system(['hub'] + a:000))
  endfunction
else
  function! s:git(...) abort
    return s:trim(system(join(['git'] + a:000, ' ')))
  endfunction

  function! s:hub(...) abort
    return s:trim(system(join(['hub'] + a:000, ' ')))
  endfunction
endif

function! s:git_lines(...) abort
  let output = call('s:git', a:000)
  let keepempty = 1
  return split(output, '\n', keepempty)
endfunction



function! s:trim(str) abort
  let str = a:str
  let str = substitute(str, '^[ \t\n]\+', '', 'g')
  let str = substitute(str, '[ \t\n]\+$', '', 'g')
  return str
endfunction

function! s:resolve(path) abort
  return exists('*resolve') ? resolve(a:path) : a:path
endfunction

function! s:echomsg(msg, hl) abort
  execute 'echohl' a:hl
  try
    echomsg '[openbrowser-github]' a:msg
  finally
    echohl None
  endtry
endfunction

function! s:warn(msg) abort
  call s:echomsg(a:msg, 'WarningMsg')
endfunction

function! s:error(msg) abort
  call s:echomsg(a:msg, 'ErrorMsg')
endfunction


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
