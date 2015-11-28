# psc-ide-vim

Work in progress!

Installing the plugin via Vundle/NeoBundle: frigoeu/psc-ide-vim
1. Calling :PSCtype will give you the type of the identifier under the cursor
2. Omnicompletion should work out of the box
3. I'm reloading the current module before every command. This is probably not good for performance, so in big projects this might be an issue, but you do always have the most recently compiled types.

Prerequisites:
1. Have psc-ide-server installed and available on your path
2. Have port 4242 free

Todo's: 
1. Recompiling(?)/reloading
2. Better error handling
3. Support the rest of the commands
