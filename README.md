# psc-ide-vim
A vim plugin that interfaces with `purs ide`, PureScript's editor support
server.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

If you manually install the plugin don't forget to generate help tags with
`:helptags` vim commands:
```
helptags ~/.vim/bundles/psc-ide-vim/doc
```
Just change the path to one that points to the `doc` dir.

## Syntax checking
This plugin provides two kinds of syntax checking with syntastic. Controlling
which one you use happens via the global variable `g:psc_ide_syntastic_mode`.

- if `0` -> syntax checking is disabled, but `:Prebuild` will run whenever the
  file is saved (an your quickfix will be synced) 
- if `1` (default) -> syntax checking happens with the fast-rebuild feature of
  psc-ide. This only checks the file that you're currently saving. You need psc
  version >= 0.8.5.0 for this to work.
- if `2` -> use pulp build. This rebuilds the whole project and is often quite
  a bit slower, so using the fast-rebuild mode is advised.

![:PSCIDE syntastic gif](http://frigoeu.github.io/gifs/syntastic.gif)

## Commands 

Check `:help psc-ide-vim` or
[here](https://github.com/FrigoEU/psc-ide-vim/blob/master/doc/psc-ide-vim.txt).

## Mappings
No custom mappings are provided, but it's easy to map the above commands to any
key mapping you want.  You can add these mappings to
`after/ftplugin/purescript.vim`: 

```
nm <buffer> <silent> <leader>L :Plist<CR>
nm <buffer> <silent> <leader>l :Pload!<CR>
nm <buffer> <silent> <leader>r :Prebuild!<CR>
nm <buffer> <silent> <leader>f :PaddClause<CR>
nm <buffer> <silent> <leader>t :PaddType<CR>
nm <buffer> <silent> <leader>a :Papply<CR>
nm <buffer> <silent> <leader>A :Papply!<CR>
nm <buffer> <silent> <leader>C :Pcase!<CR>
nm <buffer> <silent> <leader>i :Pimport<CR>
nm <buffer> <silent> <leader>qa :PaddImportQualifications<CR>
nm <buffer> <silent> <leader>g :Pgoto<CR>
nm <buffer> <silent> <leader>p :Pursuit<CR>
nm <buffer> <silent> <leader>T :Ptype<CR>
```

## Omnicompletion and user completion
Omnicompletion gets possibilities based on the word under your cursor, and
shows the types.

![:PSCIDE omnicompletion gif](http://frigoeu.github.io/gifs/omnicompletion.gif)

## Prerequisites
* Vim version 8 or higher or NeoVim version 0.2.0 or higher.
* purs installed and available on your path
* [purescript-vim](https://github.com/raichoo/purescript-vim)
* `bower.json`, `psc-package.json` or `spago.dhall` file in the root path of your project

## Debugging
Add the following to have psc-ide-vim spit out all logs:
```
let g:psc_ide_log_level = 3
```
