@program cmd-3who
1 99999 d
1 i
(*
 * Compatibility is an issue -- with FB 7.1, we got rid of a separate
 * notion of connections vs. descriptors.  This block of code will
 * [hopefully] retain backward compatibility
 *)
$ifdef __version>Muck2.2fb7.0
$def CD_GET_DBREF descrdbref
$def CD_GET_TIME descrtime
$def CD_GET_IDLE descridle
$def CD_GET_FIRST #-1 firstdescr
$def CD_GET_NEXT nextdescr
$def CD_GET_COUNT descrcount
$else
$def CD_GET_DBREF condbref
$def CD_GET_TIME contime
$def CD_GET_IDLE conidle
$def CD_GET_FIRST concount
$def CD_GET_NEXT 1 -
$def CD_GET_COUNT concount
$endif

: stimestr (i -- s)
    dup 86400 > if
        86400 / intostr "d" strcat 
    else dup 3600 > if
            3600 / intostr "h" strcat
        else dup 60 > if
                60 / intostr "m" strcat
            else
                intostr "s" strcat
            then
        then
    then
    "    " swap strcat
    dup strlen 4 - strcut swap pop
;
  
: mtimestr (i -- s)
    "" over 86400 > if
        over 86400 / intostr "d " strcat strcat
        swap 86400 % swap
    then
    over 3600 / intostr
    "00" swap strcat
    dup strlen 2 - strcut
    swap pop strcat ":" strcat
    swap 3600 % 60 / intostr
    "00" swap strcat
    dup strlen 2 - strcut
    swap pop strcat
;
 
: collate-entry (i -- s)
    dup CD_GET_DBREF name
    over CD_GET_TIME mtimestr
    over strlen over strlen +
    dup 19 < if
        "                   " (19 spaces)
        swap strcut swap pop
    else
        19 - rot dup strlen rot -
        strcut pop swap ""
    then
    swap strcat strcat
    swap CD_GET_IDLE stimestr strcat
;
 
: get-namelist  ( -- {s})
    0 CD_GET_FIRST
    begin
        dup while
        dup collate-entry
        rot 1 + rot
        CD_GET_NEXT
    repeat
    pop
;
 
lvar col
: show-namelist ({s} -- )
    begin
        dup 3 >= while
        swap "   " strcat
        over 3 / 3 pick 3 % 2 + 3 / +
        dup col ! 2 +
        rotate strcat "   " strcat
        over 3 / 3 pick 3 % 1 +
        3 / + col @ + 1 +
        rotate strcat
        tell 3 -
    repeat
    dup if
        ""
        begin
            over 0 > while
            rot strcat "   " strcat
            swap 1 - swap
        repeat
        tell
    then
    pop
;
 
: show-who
    preempt
    "Name         OnTime Idle  " dup strcat
    "Name         Ontime Idle" strcat tell
    get-namelist
    show-namelist
    CD_GET_COUNT intostr
    " players are connected."
    strcat tell
;
.
c
q
@register #me cmd-3who=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
@set $tmp/prog1=W
@action 3who;3w=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
