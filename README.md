# psc-ide-vim
A vim plugin that interfaces with kRITZCREEK/psc-ide: Purescript's editor support server.

## Versions
Tag 0.1.0 should be working pretty well with compiler version < 8.1.0. 
Since 8.1.0 psc-ide is bundled with purescript (yay!). For compiler versions >= 8.1.0 -> Use tag 0.2.0 or higher.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

## Syntax checking
This plugin provides a syntax checker for syntastic. It relies on the --json-errors flag of psc, which is only available starting at version 0.8.0.0, and it uses pulp, so make sure you have the most recent version

![:PSCIDE syntastic gif](http://frigoeu.github.io/gifs/syntastic.gif)

## Commands 
* :PSCIDEtype : Returns the type of the expression under the cursor (Doesn't support fully qualified names).

![:PSCIDEtype gif](http://frigoeu.github.io/gifs/type.gif)
* :PSCIDEapplySuggestion : Automatically applies suggestions provided by the compiler. This uses the syntastic syntax checker, so syntastic is required for this to work. Errors/warnings with suggestions are marked as "Style" errors, which use the "S>" icon by default, while normal errors/warnings use ">>" by default

![:PSCIDEapplySuggestion gif](http://frigoeu.github.io/gifs/applysuggestion.gif)
* :PSCIDEcaseSplit : Splits variables in a function declaration into its different constructors. Will probably get improved soon so you don't have to input the type yourself

![:PSCIDEcaseSplit gif](http://frigoeu.github.io/gifs/casesplit.gif)
* :PSCIDEaddTypeAnnotation : Add type annotation.

![:PSCIDEaddtype gif](http://frigoeu.github.io/gifs/addtype.gif)
* :PSCIDEremoveImportQualifications : Remove all qualifications from your imports

![:PSCIDEremoveimport gif](http://frigoeu.github.io/gifs/removeimport.gif)
* :PSCIDEaddImportQualifications : Applies all import qualification suggestions in one go. Same as :PSCIDEapplySuggestion, but applies it to every line starting with "import"

![:PSCIDEaddimport gif](http://frigoeu.github.io/gifs/addimport.gif)

* :PSCIDEpursuit : Prints the info found on pursuit for the identifier under the cursor. Doesn't support fully qualified names.
* :PSCIDEcwd : Prints the current working directory of psc-ide-server.
* :PSCIDElist : Prints the loaded modules.

* :PSCIDEstart : Starts psc-ide-server on port 4242 and your project root directory (found by recursively walking up the tree until we find bower.json). Gets called automatically when trying to interact with the server, so you shouldn't need to call this yourself. If you have a psc-ide-server running already, this plugin will use that server for it's commands.
* :PSCIDEstop : Stops psc-ide-server. Gets called automatically when exiting VIM.
* :PSCIDEload : Loads the current module and it's dependencies into psc-ide-server. Gets called automatically whenever you open/switch to a purescript file. As psc-ide reloads new versions of the module for you, you also shouldn't need to call this yourself.

## Mappings
No custom mappings are provided, but it's easy to map the above commands to any key mapping you want. My personal setup:

```
au FileType purescript nmap <leader>t :PSCIDEtype<CR>
au FileType purescript nmap <leader>s :PSCIDEapplySuggestion<CR>
au FileType purescript nmap <leader>p :PSCIDEpursuit<CR>
au FileType purescript nmap <leader>c :PSCIDEcaseSplit<CR>
au FileType purescript nmap <leader>a :PSCIDEaddTypeAnnotation<CR>
au FileType purescript nmap <leader>qd :PSCIDEremoveImportQualifications<CR>
au FileType purescript nmap <leader>qa :PSCIDEaddImportQualifications<CR>
```


## Omnicompletion
* Omnicompletion gets possibilities based on the word under your cursor, and shows the types.

![:PSCIDE omnicompletion gif](http://frigoeu.github.io/gifs/omnicompletion.gif)

## Prerequisites
* Have psc-ide-server installed and available on your path
* Have port 4242 free
* Have a bower.json file on the root path of your project. The plugin will climb upward on the file tree until it finds bower.json.
