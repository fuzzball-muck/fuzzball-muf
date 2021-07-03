@program cmd-list
1 99999 d
1 i
( cmd-list by Natasha@HLM
 
  Copyright 2002 Natasha O'Brien. Copyright 2002 Here Lie Monsters.
  "@view $box/mit" for license information.
)
$include $lib/strings
$include $lib/match
: main  ( str )
    STRparse  ( strX strY strZ )
    rot "help" stringcmp not if pop pop .showhelp exit then  ( strY strZ )
    
    swap noisy_match dup ok? not if pop pop exit then swap  ( db strZ )
    array_get_proplist dup if  ( arr )
        me @ 1 array_make array_notify  (  )
    else
        pop "There is no such list." tell  (  )
    then  (  )
;
.
c
q
@register #me cmd-list=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
lsedit $tmp/prog1=_help
.del 1 999
.i 1
list #help
list <obj>=<list>
 
Display the <obj>'s list <list>, as set with lsedit.
.end
@action list=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
