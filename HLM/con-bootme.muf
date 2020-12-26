@program con-bootme
1 99999 d
1 i
( con-bootme.muf by Aerowolf@HLM and Natasha@HLM )
: main
    "me" match awake? 1 > if
        0 sleep
        "You have more than one connection. Type @bootme to drop the old ones." tell
    then
;
.
c
q
@register #me con-bootme=tmp/prog1
@set $tmp/prog1=1
@set $tmp/prog1=V
@propset #0=dbref:_connect/bootme:$tmp/prog1
@register #me =tmp
