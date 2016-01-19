# psc-ide-vim
A vim plugin that interfaces with kRITZCREEK/psc-ide: Purescript's editor support server.

## Disclaimer
Many things are in flux in the purescript ecosystem at the moment. Both the purescript compiler and psc-ide are moving fast, and at their own pace. This is something that will probably calm down later on, but for now it's pretty easy to break this plugin depending on what version on purescript/psc-ide you're running. I'm personally on commit 11b2662 of purescript, and commit 369bb5a of psc-ide (current master). With those commits, everything should be working pretty well.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

## Syntax checking
This plugin provides a syntax checker for syntastic. It relies on the --json-errors flag of psc, which is only available starting at version 0.8.0.0, and it uses pulp, so make sure that's installed as well.

## Commands 
* :PSCIDEtype : Returns the type of the expression under the cursor (Doesn't support fully qualified names).
* :PSCIDEcwd : Prints the current working directory of psc-ide-server.
* :PSCIDEpursuit : Prints the info found on pursuit for the identifier under the cursor. Doesn't support fully qualified names.
* :PSCIDElist : Prints the loaded modules.
* :PSCIDEapplySuggestion : Automatically applies suggestions provided by the compiler. This uses the syntastic syntax checker, so syntastic is required for this to work. Errors/warnings are marked as "Style" errors, which have use the "S>" by default, while normal errors/warnings use ">>" by default
* :PSCIDEcaseSplit : Splits variables in a function declaration into its different constructors.

* :PSCIDEstart : Starts psc-ide-server on port 4242 and your project root directory (found by recursively walking up the tree until we find bower.json). Gets called automatically when trying to interact with the server, so you shouldn't need to call this yourself. If you have a psc-ide-server running already, this plugin will use that server for it's commands.
* :PSCIDEstop : Stops psc-ide-server. Gets called automatically when exiting VIM.
* :PSCIDEload : Loads the current module and it's dependencies into psc-ide-server. Gets called automatically whenever you open/switch to a purescript file. As psc-ide reloads new versions of the module for you, you also shouldn't need to call this yourself.

## Mappings
No custom mappings are provided, but it's easy to map the above commands to any key mapping you want. My personal setup:

`au FileType purescript nmap <leader>t :PSCIDEtype<CR>
au FileType purescript nmap <leader>s :PSCIDEapplySuggestion<CR>
au FileType purescript nmap <leader>p :PSCIDEpursuit<CR>
au FileType purescript nmap <leader>c :PSCIDEcaseSplit<CR>`

## Omnicompletion
* Omnicompletion gets possibilities based on the word under your cursor, and shows the types.

## Prerequisites
* Have psc-ide-server installed and available on your path
* Have port 4242 free
* Have a bower.json file on the root path of your project. The plugin will climb upward on the file tree until it finds bower.json.
