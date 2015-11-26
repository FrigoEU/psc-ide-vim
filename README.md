# psc-ide-vim

Work in progress!

Installing the plugin via Vundle/NeoBundle: frigoeu/psc-ide-vim
1. Calling :PSCtype will give you the type of the identifier under the cursor
2. Omnicompletion should work out of the box
3. I'm reloading the current module before every command. This is not good for performance at all, so in big projects this might be an issue

Prerequisites:
1. Have a vim installation with python support (Needed to start psc-ide-server in the background)
1b. Without python support, it should work by running psc-ide-server in your project's root folder yourself
2. Have psc-ide-server installed and available on your path
3. Have port 4242 free

Todo's: 
1. Recompiling(?)/reloading
2. Better error handling
3. Support the rest of the commands
