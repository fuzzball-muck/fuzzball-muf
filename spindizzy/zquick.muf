( /quote -dsend -S '/data/spindizzy/muf/zquick.muf )
@prog zquick.muf
1 500 d
i
( Provides a way to turn on/off zombie display quick to run a command, and then
  turns it back off/on.  It checks the action name, turns on or off zombies,
  forces the command to be ran without the z or x, then turns zombies back
  off, if needed. )
  
( To use:  Make an action with all the names of the commands you want to toggle
  zombie access for.  Prefix each command with a z to turn on zombies
  temporarily, or an x to turn off zombies temporarily.
  Example: zfindall;xfindall )
  
$include $lib/puppetdb
  
: main
    foreground
    "me" match me !
    me @ puppetdb-use? var! usePuppetsSetting
    me @ getpids array_count var! currentProcs
    1 var! zSetting  (1 or 0)
    
    ( Strip the 'z' or 'x' off the command if needed )
    COMMAND @ "z" instring 1 = if
        ( Zombies toggled on )
        1 zSetting !
        COMMAND @ 1 strcut swap pop
    else
        COMMAND @ "x" instring 1 = if
            ( Zombies toggled off )
            0 zSetting !
            COMMAND @ 1 strcut swap pop
        else
            me @ "Configuration error: Must begin with x or z." notify exit
        then
    then
    
    ( Append the arguments )
    " " strcat swap strcat var! commandToForce
    
    ( Toggle zombies )
    me @ zSetting @ puppetdb-setUse
      
    ( Run the command )
    me @ commandToForce @ force
    
    BEGIN
        ( Poll until program ends, done by checking the process count )
        1 sleep
        me @ getpids array_count currentProcs @ <= if
            ( Program has finished )
            break
        then
    REPEAT
    
    ( Turn zombies back to their original setting )
    me @ usePuppetsSetting @ puppetdb-setUse
;
.
c
q
@set zquick.muf=W
@set zquick.muf=3
