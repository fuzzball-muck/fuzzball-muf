@program cmd-uptime
1 99999 d
1 i
( cmd-uptime v2.0 by Revar Desmera <revar@belfry.com> )
( Designed to run under fb4 or later.                 )

lvar starttime
lvar yearday
lvar week
lvar year
lvar month
lvar day
lvar hour
lvar minute
lvar second

(Calculate and remember the server's local time zone.)
: tzoffset ( -- i)
  0 timesplit -5 rotate pop pop pop pop
  178 > if 24 - then
  60 * + 60 * +
;
  
: cmd-uptime
    #0 "_sys/startuptime" getpropval
    dup starttime !
    systime swap -
    tzoffset - timesplit
    1 - yearday ! week ! 1970 - year ! month ! day ! hour ! minute ! second !

    ""
    year @ 0 > if year @ intostr strcat then
    year @ 1 = if " year" strcat then
    year @ 1 > if " years" strcat then

    yearday @ 0 > if
        dup if ", " strcat then
        yearday @ intostr strcat
    then
    yearday @ 1 = if " day" strcat then
    yearday @ 1 > if " days" strcat then

    hour @ 0 > if
        dup if ", " strcat then
        hour @ intostr strcat
    then
    hour @ 1 = if " hour" strcat then
    hour @ 1 > if " hours" strcat then

    dup not minute @ 0 > or if
        dup if ", " strcat then
        minute @ intostr strcat " minute" strcat
        minute @ 1 = not if "s" strcat then
    then

    "Up " swap strcat
    " since " strcat
    "%H:%M %m/%d/%y" starttime @ timefmt strcat
    
    .tell
;
.
c
q
@register #me cmd-uptime=tmp/prog1
@set $tmp/prog1=A
@set $tmp/prog1=_norestart:yes
