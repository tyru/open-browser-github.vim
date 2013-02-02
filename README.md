# open-browser-github.vim

## About

Opens GitHub URL of current file, etc. from Vim.
Also supports GitHub Enterprise.

## Install

Since this is a plugin of [open-browser.vim](https://github.com/tyru/open-browser.vim), you will need to install open-browser.vim first.

## Usage

There are 3 commands.

### `:OpenGithubFile`

Opens a specific file in github.com repository(it also opens in the current branch).

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
```

The third command is `:OpenGithubPullReq`, but it basically does the same thing as `:OpenGithubIssue` since GitHub redirects `/issues/1` to `/pull/1` if #1 is a Pull Request.

## GitHub Enterprise setting

Like the [hub command](https://github.com/defunkt/hub), by setting `hub.host`, you can open a GitHub Enterprise repository page.

You can set `hub.host` by executing the command below. Make sure you execute it in the git repository.

`$ git config --local hub.host my.git.org`
