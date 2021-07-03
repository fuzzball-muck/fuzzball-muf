@program cmd-@exits
1 99999 d
1 i
$include $lib/match
  
: listem-loop (count dbref -- )
  dup not if
    pop intostr " exits." strcat
    tell exit
  then
  swap 1 + swap dup unparseobj tell
  next listem-loop
;
  
: main
  strip dup not if
    pop "here"
  then
  match_controlled dup not if pop exit then
  dup exit? over program? or if
    "That object doesn't have any exits."
    tell pop exit
  then
  exits dup not if
    "That object has no exits on it."
    tell pop exit
  then
  0 swap listem-loop
;
.
c
q
@register #me cmd-@exits=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
@set $tmp/prog1=W
@action @exits=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
