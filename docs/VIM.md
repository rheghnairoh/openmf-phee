- open file in vim

```bash
vi values.yml
```

- Vim Cheats

0 - start of line
$ - end of line
1G - top of file
G - bottom of file

:x - save and exit
:w - write
:w filename - write as filename
:q - quit
:wq - write and quit
:q! - quit and discard
:<linenumber> - jump to line number
:i - enter insert mode at cursor
esc - escape insert mode
:set number - enable line numbers. Or put in ~/.vimrc for auto enable

u - undo
CTRL + r - redo

/pattern - find first occurance of pattern. Enter then use n to move to next occurance
?pattern - find previous occurance of pattern
:s/old/new/g - search for "old" and replace with "new" on current line
:1,%s/old/new/g - got to line 1. %s for substituion. Search and replace entire file

x - delete at cursor
dd - delete current line
#dd - delete # lines
yy - copy current line
#yy - copy # lines
p - paste
P - paste after cursor
:%d - delete all lines


:6,9w >> /tmp/newfile - append lines 6 to 9, inclusive, to a file called /tmp/newfile.
:!<linuxcommand> - execute commands from within vim
