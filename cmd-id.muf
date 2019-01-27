@program cmd-id.muf
1 1000 d
i
( cmd-id.muf by Natasha@HLM
  A simple object describer.

  Copyright 2003-2019 Natasha Snunkmeox. Copyright 2003-2019 Here Lie Monsters.
  "@view $box/mit" for license information.

  Version history
  1.0, 25 Oct 2003: First version.
  1.1, 26 Jan 2019: Vendorized the obj-color word for portability.
)
$author Natasha Snunkmeox <natmeox@neologasm.org>
$version 1.1
$note A simple object describer.

$include $lib/bits
$ifnlib $lib/stoplights
    $def .tellgood .tell
$endif

: rtn-getType  ( db -- str }  Returns a string identifying the object type of db. )
    dup ok? not if pop "garbage"  exit then  ( db )
    dup player? if pop "player"   exit then
    dup program? if pop "program" exit then
    dup exit?    if pop "exit"    exit then
    dup room?    if pop "room"    exit then
    pop "thing"
;

: obj-color  ( db -- str )
    dup ok? if  ( db )
        dup unparseobj over name strlen strcut  ( db strName strData )
        "bold,yellow" textattr strcat  ( db str )
    else "<unknown>" then  ( db str )
    prog "_obj-color/" 4 rotate rtn-getType strcat getpropstr  ( str strColor )
    textattr  ( str )
;

: main  ( str -- }  Print out the unparseobj for the given string. )
    dup strip "#help" stringcmp not if "_help" rtn-dohelp exit then  ( str )

    dup if match else pop me @ then  ( db )
    dup obj-color  ( db str )
    over ok? if  ( db str )
        over owner swap "%s     Owner: %D" fmtstring  ( db str )
        over exit? if  ( db str )
            over getlink obj-color swap "%s     Link: %s" fmtstring  ( db str )
        then  ( db str )
    then  ( db str )
    .tellgood pop  (  )
;

PUBLIC obj-color
.
c
q
@act id;db=#0
@link id=cmd-id
lsedit cmd-id=_help
.del 1 $
id <object>
db <object>
 
Displays the name and dbref for the given object.
.end
@set cmd-id=_obj-color/garbage:bold,black
@set cmd-id=_obj-color/player:bold,green
@set cmd-id=_obj-color/program:bold,red
@set cmd-id=_obj-color/exit:bold,green
@set cmd-id=_obj-color/room:bold,cyan
@set cmd-id=_obj-color/thing:bold,magenta
