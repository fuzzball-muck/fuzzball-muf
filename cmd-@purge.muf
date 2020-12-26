@program cmd-@purge
1 99999 d
1 i
$include $lib/strings
$include $lib/match
  
: main
   "me" match me !
  
   "=" split strip
   "yes" stringcmp if
      "Use \"@purge <player>=yes\" to purge a player's possessions."
      me @ swap notify pop exit
   then
   strip noisy_pmatch
   dup not if pop exit then
  
   dup me @ dbcmp not
   me @ "wizard" flag? not and if
      "Permission denied." tell
      pop exit
   then
  
   "Beginning purge." tell
   0 sleep
   dbtop begin
      int 1 - dup 0 > while dbref
      dup ok? not if continue then
      dup player? if continue then
      over over owner dbcmp if dup recycle 0 sleep then
   repeat pop pop
   me @ "Purge complete." notify
;
.
c
q
@register #me cmd-@purge=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=W
@action @purge=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
