@program cmd-@autostart
1 99999 d
1 i
: restart
  me @ "wizard" flag? not if
    "Permission denied."
    me @ swap notify exit
  then
  me @ "@kill all" force
  #0 begin
    int 1 + dbref
    dup int dbtop int < while
    dup program? if
      dup "abode" flag? if
        dup owner "wizard" flag? if
	  dup "_norestart" getpropstr "yes" stringcmp if
            0 over "Startup" queue pop
	  then
        then
      then
    then
  repeat pop
  me @ "All autostart programs have been restarted." notify
;
.
c
q
@set cmd-@autostart=3
@set cmd-@autostart=W
@action @autostart=#0=tmp/exit1
@link $tmp/exit1=cmd-@autostart
