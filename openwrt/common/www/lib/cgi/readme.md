Serverside scripts for SuperGlue server
Documentation | Files | Commits

## post.sh - all POST requests are redirected to this script.                                                
## 
## examples:
## text:    curl --data-urlencode '<html><title>' http://host/file.html
## image:   curl --form "userimage=@file.png" -H "Expect:" http://host/file.png 
## command: curl --data-urlencode 'ls' http://host/cmd
##
## returns: 200 (+ output of operation) on success
##          406 (+ error message in debug mode) on error
Curently, there is only one live and public SuperGlue server running this CGI, try it: http://test.superglue.it

SuperGlue browser extension / client that talks to post.sh can be found here: http://git.superglue.it/superglue/clientplugin/repository/archive.zip

Take a look a SuperGlue project summary to learn more about the project.

http://superglue.it
