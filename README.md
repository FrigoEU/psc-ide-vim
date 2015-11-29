# psc-ide-vim

A vim plugin that interfaces with Purescript's editor support server psc-ide.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

## Important
At the time of writing, psc-ide works on the identifiers exported by your modules and the one you're importing. This causes completions and type info to not be available for local or unexported identifiers. Secondly, if you add new identifiers and you want psc-ide to make use of them, these identifiers need to be compiled into the output/ folder.

## Commands 
* :PSCIDEtype : Returns the type of the expression under the cursor. Doesn't support fully qualified names.
* :PSCIDEstart : Starts psc-ide-server on port 4242 and your project root directory (found by recursively walking up the tree until we find bower.json). Gets called automatically when opening a .purs file.
* :PSCIDEstop : Stops psc-ide-server. Gets called automatically when exiting VIM.
* :PSCIDEload : Loads the current module and it's dependencies into psc-ide-server. Gets called automatically before each relevant command. So far this seems to be not too bad for performance. If you do have issues, let me know.
* :PSCIDEcwd : Prints the current working directory of psc-ide-server
* :PSCIDEpursuit : Prints the info found on pursuit for the identifier under the cursor. Doesn't support fully qualified names.
* :PSCIDElist : Prints the loaded modules

## Other features
* Omnicompletion gets possibilities based on the word under your cursor, and shows the types.

## Prerequisites
* Have psc-ide-server installed and available on your path
* Have port 4242 free
* Have a bower.json file on the root path of your project. The plugin will climb upward on the file tree until it finds bower.json.
