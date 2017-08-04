# psc-ide-vim
A vim plugin that interfaces with `psc-ide`, Purescript's editor support server.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

If you manually install the plugin don't forget to generate help tags with `:helptags` vim commands.

## Syntax checking
This plugin provides two kinds of syntax checking with syntastic. Controlling which one you use happens via the global variable g:psc_ide_syntastic_mode.

- If 0 -> syntax checking is disabled
- If 1 (default) -> syntax checking happens with the fast-rebuild feature of psc-ide. This only checks the file that you're currently saving. You need psc version >= 0.8.5.0 for this to work.
- If 2 -> use pulp build. This rebuilds the whole project and is often quite a bit slower, so using the fast-rebuild mode is advised.

![:PSCIDE syntastic gif](http://frigoeu.github.io/gifs/syntastic.gif)

## Commands 

For documentation on commands check `:help psc-ide-vim`.

## Mappings
No custom mappings are provided, but it's easy to map the above commands to any key mapping you want. My personal setup (inside `after/ftplugin/purescript.vim`:

```
nm <buffer> <silent> <leader>t :<C-U>call PSCIDEtype(PSCIDEgetKeyword(), v:true)<CR>
nm <buffer> <silent> <leader>T :<C-U>call PSCIDEaddTypeAnnotation(matchstr(getline(line(".")), '^\s*\zs\k\+\ze'))<CR>
nm <buffer> <silent> <leader>s :<C-U>call PSCIDEapplySuggestion()<CR>
nm <buffer> <silent> <leader>a :<C-U>call PSCIDEaddTypeAnnotation()<CR>
nm <buffer> <silent> <leader>i :<C-U>call PSCIDEimportIdentifier(PSCIDEgetKeyword())<CR>
nm <buffer> <silent> <leader>r :<C-U>call PSCIDEload()<CR>
nm <buffer> <silent> <leader>p :<C-U>call PSCIDEpursuit(PSCIDEgetKeyword())<CR>
nm <buffer> <silent> <leader>C :<C-U>PSCIDEcaseSplit<SPACE>
nm <buffer> <silent> <leader>qd :<C-U>call PSCIDEremoveImportQualifications()<CR>
nm <buffer> <silent> <leader>qa :<C-U>call PSCIDEaddImportQualifications()<CR>
nm <buffer> <silent> ]d :<C-U>call PSCIDEgoToDefinition(PSCIDEgetKeyword())<CR>
```

## Omnicompletion
* Omnicompletion gets possibilities based on the word under your cursor, and shows the types.

![:PSCIDE omnicompletion gif](http://frigoeu.github.io/gifs/omnicompletion.gif)

## Prerequisites
* Have psc, psc-ide-server and psc-ide-client installed and available on your path. From version 0.8.1.0 of PureScript on, psc-ide-server and psc-ide-client are installed when installing PureScript.
* Have [purescript-vim](https://github.com/raichoo/purescript-vim) installed.
* Have chosen server port (by default 4242) free. You can change port value using `g:psc_ide_server_port` option.
* Have a bower.json file on the root path of your project. The plugin will climb upward on the file tree until it finds bower.json.

## Debugging
Add the following to have psc-ide-vim spit out all logs:

```
let g:psc_ide_log_level = 3
```
