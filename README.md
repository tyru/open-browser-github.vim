# open-browser-github.vim

## About

Opens GitHub URL of current file, etc. from Vim.
Also supports GitHub Enterprise.

## Install

This plugin requires:

* [open-browser.vim](https://github.com/tyru/open-browser.vim)
* `git` command in your PATH

## Usage

There are 4 commands.

### `:OpenGithubFile`

Opens a specific file in github.com repository(it also opens in the current branch by default).

```vimL
" Opens current files URL in github.com
:OpenGithubFile
" Opens current files highlighted place in github.com 
:'<,'>OpenGithubFile
" Opens a specific file in github.com
:OpenGithubFile PATH/TO/FILE
```

### `:OpenGithubIssue`

Opens a specific Issue.

```vimL
" Opens current repositories Issue #1
:OpenGithubIssue 1
" Opens a specific repositories Issue #1
:OpenGithubIssue 1 tyru/open-browser.vim
" Opens current repositories Issue List
:OpenGithubIssue
" Opens a specific repositories Issue list
:OpenGithubIssue tyru/open-browser.vim
```

### `:OpenGithubPullReq`

This command opens `/pulls` page when it has no argument.  Otherwise, it does entirely the same thing as `:OpenGithubIssue` since GitHub redirects `/issues/1` to `/pull/1` if #1 is a Pull Request.

### `:OpenGithubProject`

:OpenGithubProject [{repos}]

Opens a project page.
```vimL
" Opens current opening file's repository.
" ex) https://{hostname}/{user}/{name}
:OpenGithubProject

" Opens current opening file's repository.
" ex) https://{hostname}/tyru/open-browser.vim
:OpenGithubProject tyru/open-browser.vim
```

## GitHub Enterprise setting

### If you have `hub` command

If you have [hub command](https://github.com/github/hub) in your PATH,
`openbrowser-github` executes the following command:

```
hub browse -u -- {path}
```

And it will open the returned (output) URL.

### If you _don't_ have `hub` command

If you don't have `hub` command in your PATH, `openbrowser-github` tries to
get each part of URL from the following gitconfig key:

* hub.host

You can specify GitHub Enterprise repository URL by setting above keys in
gitconfig.

For example, you can set `hub.host` by executing the following command in your
git repository which you want to specify GitHub Enterprise repository URL.

```
git config --local hub.host my.git.org
```
