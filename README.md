# psc-ide-vim
A vim plugin that interfaces with `psc-ide`, Purescript's editor support server.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

## Syntax checking
This plugin provides two kinds of syntax checking with syntastic. Controlling which one you use happens via the global variable g:psc_ide_syntastic_mode.

- If 0 -> syntax checking is disabled
- If 1 (default) -> syntax checking happens with the fast-rebuild feature of psc-ide. This only checks the file that you're currently saving. You need psc version >= 0.8.5.0 for this to work.
- If 2 -> use pulp build. This rebuilds the whole project and is often quite a bit slower, so using the fast-rebuild mode is advised.

![:PSCIDE syntastic gif](http://frigoeu.github.io/gifs/syntastic.gif)

## Commands 
* :PSCIDEtype : Returns the type of the expression under the cursor (Doesn't support fully qualified names).

![:PSCIDEtype gif](http://frigoeu.github.io/gifs/type.gif)
* :PSCIDEaddTypeAnnotation : Add type annotation.

![:PSCIDEaddtype gif](http://frigoeu.github.io/gifs/addtype.gif)
* :PSCIDEimportIdentifier: Add import statement for identifier under cursor. If there are multiple options, you can select the module you want to import from with the number keys. Needs Purescript 0.8.4.0 or higher

![:PSCIDEimportIdentifier](http://frigoeu.github.io/gifs/importidentifier.gif)
* :PSCIDEapplySuggestion : Automatically applies suggestions provided by the compiler. This uses the syntastic syntax checker, so syntastic is required for this to work. Errors/warnings with suggestions are marked as "Style" errors, which use the "S>" icon by default, while normal errors/warnings use ">>" by default

![:PSCIDEapplySuggestion gif](http://frigoeu.github.io/gifs/applysuggestion.gif)
* :PSCIDEcaseSplit : Splits variables in a function declaration into its different constructors. Will probably get improved soon so you don't have to input the type yourself

![:PSCIDEcaseSplit gif](http://frigoeu.github.io/gifs/casesplit.gif)
* :PSCIDEremoveImportQualifications : Remove all qualifications from your imports

![:PSCIDEremoveimport gif](http://frigoeu.github.io/gifs/removeimport.gif)
* :PSCIDEaddImportQualifications : Applies all import qualification suggestions in one go. Same as :PSCIDEapplySuggestion, but applies it to every line starting with "import"

![:PSCIDEaddimport gif](http://frigoeu.github.io/gifs/addimport.gif)

* :PSCIDEgoToDefinition : Go to definition of word under cursor (sorry no gif yet!)

* :PSCIDEaddClause : Add function template based on type signature
* :PSCIDEpursuit : Prints the info found on pursuit for the identifier under the cursor. Doesn't support fully qualified names.
* :PSCIDEcwd : Prints the current working directory of psc-ide-server.
* :PSCIDElist : Prints the loaded modules.

* :PSCIDEstart : Starts psc-ide-server on port 4242 (configurable via `g:psc_ide_server_port`) and your project root directory (found by recursively walking up the tree until we find bower.json). Gets called automatically when trying to interact with the server, so you shouldn't need to call this yourself. If you have a psc-ide-server running already, this plugin will use that server for it's commands.
* :PSCIDEend : Stops psc-ide-server. Gets called automatically when exiting VIM.
* :PSCIDEload : Loads all modules into psc-ide-server. This gets called automatically when psc-ide-server gets started. Afterwards it's up to you to refresh it now and then. This used to happen automatically on file save/buffer switch, but this took multiple seconds on bigger projects and ended up being more trouble than it was worth.

## Mappings
No custom mappings are provided, but it's easy to map the above commands to any key mapping you want. My personal setup:

```
au FileType purescript nmap <leader>t :PSCIDEtype<CR>
au FileType purescript nmap <leader>s :PSCIDEapplySuggestion<CR>
au FileType purescript nmap <leader>a :PSCIDEaddTypeAnnotation<CR>
au FileType purescript nmap <leader>i :PSCIDEimportIdentifier<CR>
au FileType purescript nmap <leader>r :PSCIDEload<CR>
au FileType purescript nmap <leader>p :PSCIDEpursuit<CR>
au FileType purescript nmap <leader>c :PSCIDEcaseSplit<CR>
au FileType purescript nmap <leader>qd :PSCIDEremoveImportQualifications<CR>
au FileType purescript nmap <leader>qa :PSCIDEaddImportQualifications<CR>
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
