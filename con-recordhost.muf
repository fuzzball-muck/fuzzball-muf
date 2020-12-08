@program con-recordhost
1 99999 d
1 i
( con-recordhost 1.0     records the last host you connected from )
$def DISPLAY_MESG "## You last connected from %n"
 
: recordhost
   me @ "@/host" getpropstr
$ifdef DISPLAY_MESG
   dup if DISPLAY_MESG over "%n" subst tell then
$endif
   me @ "@/lasthost" rot 0 addprop
   me @ descriptors
   begin
      dup 1 > while
      rot pop 1 -
   repeat
   pop descrhost
   me @ "@/host" rot 0 addprop
;
.
c
q
@register #me con-recordhost=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
@set $tmp/prog1=W
@propset #0=dbref:_connect/lasthost:$tmp/prog1
@register #me =tmp
