# psc-ide-vim
A vim plugin that interfaces with kRITZCREEK/psc-ide: Purescript's editor support server.

## Setup
Installing the plugin via Vundle/NeoBundle/etc:

`NeoBundle "frigoeu/psc-ide-vim"`

## Commands 
* :PSCIDEtype : Returns the type of the expression under the cursor (Doesn't support fully qualified names).
* :PSCIDEcwd : Prints the current working directory of psc-ide-server.
* :PSCIDEpursuit : Prints the info found on pursuit for the identifier under the cursor. Doesn't support fully qualified names.
* :PSCIDElist : Prints the loaded modules.

* :PSCIDEstart : Starts psc-ide-server on port 4242 and your project root directory (found by recursively walking up the tree until we find bower.json). Gets called automatically when trying to interact with the server, so you shouldn't need to call this yourself. If you have a psc-ide-server running already, this plugin will use that server for it's commands.
* :PSCIDEstop : Stops psc-ide-server. Gets called automatically when exiting VIM.
* :PSCIDEload : Loads the current module and it's dependencies into psc-ide-server. Gets called automatically whenever you open/switch to a purescript file. As psc-ide reloads new versions of the module for you, you also shouldn't need to call this yourself.

## Omnicompletion
* Omnicompletion gets possibilities based on the word under your cursor, and shows the types.

## Prerequisites
* Have psc-ide-server installed and available on your path
* Have port 4242 free
* Have a bower.json file on the root path of your project. The plugin will climb upward on the file tree until it finds bower.json.
