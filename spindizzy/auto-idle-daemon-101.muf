( Add code to readjust idle if haven cancelled )
( Add code to skip killing maxonline people if prop is 0 )
( Add code to quit if loop time is 0 )

( /quote -dsend -S '/data/spindizzy/muf/auto-idle-daemon-101.muf )
@prog auto-idle-daemon.muf
1 5000 d
i
(
    This simple program allows for the maxidle system parameter to be
    automatically set based on how many people are online.  It also
    allows idle booting to be temporarily disabled for special events, etc.
    
Bracket example:
    03:120
    05:100
    10:80
    15:45
    
/autoidle/defaultidletime:42
)

( Time in minutes between loop executions )
$def CHECK_INTERVAL_TIME_PROP "/autoidle/intervaltime"
( Default max idle time in minutes when brackets are exceeded )
$def DEFAULT_IDLE_TIME_PROP "/autoidle/defaultidletime"
( Max time someone may be online in minutes before being booted )
$def MAX_ONLINE_TIME_PROP "/autoidle/maxonlinetime"
( Message shown to booted player.  Optional, as it has a default )
$def BOOT_MESSAGE_PROP "/autoidle/bootmessage"
( Where the brackets are.  Brackets have idle times in minutes. Optional )
$def BRACKET_PROP "/autoidle/brackets/"
( Dbref of player to send pmails from for disconnect warnings )
$def MAIL_FROM_DBREF_PROP "/mailfrom"
( Remaining time in minutes the idle haven will last )
$def IDLE_HAVEN_TIME_PROP "/autoidle/idlehaventime"
( Dbref of who last set the haven time )
$def IDLE_HAVEN_USER_PROP "/autoidle/idlehavenuser"
( Used when user turns off idle haven before time is up )
$def IDLE_HAVEN_FORCE_ENDED "/autoidle/idlehavenforcedoff"
( Counts how many times program has booted someone )
$def BOOTED_COUNT_PROP "/@/idlebooted_count"

$def SECONDS_DAY 86400
$def SECONDS_HOUR 3600
$def SECONDS_MINUTE 60


: minutesToSeconds (s -- i  Takes a string number in minutes, and returns it
                            as an int in seconds )
    "s" checkargs
    
    atoi
    abs
    60 *
;

: getIdleHavenTime ( -- i  Idle haven time in seconds )
    prog IDLE_HAVEN_TIME_PROP getpropval
;

: setIdleHavenTime ( i -- Sets idle haven time in seconds )
    "i" checkargs
    
    dup 0 > if
        prog IDLE_HAVEN_TIME_PROP rot setprop
    else
        pop
        prog IDLE_HAVEN_TIME_PROP remove_prop
        prog IDLE_HAVEN_USER_PROP remove_prop
    then
;

: getIntervalTime ( -- i  Interval loop time in seconds )
    prog CHECK_INTERVAL_TIME_PROP getpropstr minutesToSeconds
;

: getDefaultIdleTime ( -- i default idle time in seconds )
    prog DEFAULT_IDLE_TIME_PROP getpropstr minutesToSeconds
;

: getMaxOnlineTime ( -- i Max time someone can be online in seconds )
    prog MAX_ONLINE_TIME_PROP getpropstr minutesToSeconds
;

: getBootMessage ( -- s  Returns the message to show to a booted player )
    prog BOOT_MESSAGE_PROP getpropstr
    
    dup strlen not if
        pop
        "## You have exceeded the maximum per-connection time online, indicating an anti-idler is possibly in use.  Please refrain from using such programs, or contact a wizard for details.  Your connection will be booted now. ##"
    then
;

: incrementBootCount ( d -- Increments the boot count on player d )
    "P" checkargs
    dup
    BOOTED_COUNT_PROP getpropval
    ++
    BOOTED_COUNT_PROP swap setprop
;

: decrementIdleHaven ( -- i  Decrements the idle haven prop by the loop interval
                             Returns 1 if haven still active, else 0 )

    getIdleHavenTime getIntervalTime -
    dup 0 > if
        setIdleHavenTime
        1
    else
        pop
        0 setIdleHavenTime
        0
    then
;

: getBracketNumFromProp ( s -- i Given a property string, extract the
                                 bracket and return it as an int )
    dup "/" rinstr strcut swap pop
    atoi
;

: getBracketTime ( i -- i1  Given an online count, return the max idle time i1)
    "i" checkargs
    var! onlineCount
    var bracketProp
    var bracket
    
    prog BRACKET_PROP nextprop bracketProp !
    
    bracketProp @ strlen if
        BEGIN
            bracketProp @ getBracketNumFromProp onlineCount @ >= if
                prog bracketProp @ getpropstr minutesToSeconds
                exit
            then
            
            prog bracketProp @ nextprop dup bracketProp !
            strlen not
        UNTIL
        
        ( Above the brackets given, use default )
        getDefaultIdleTime
    else
        ( No brackets defined, use default )
        getDefaultIdleTime
    then
;

: sendBootMail ( d -- Sends mail to wizards about player dbref being booted )
    "P" checkargs
    var! playerBooted
    
    prog MAIL_FROM_DBREF_PROP getpropstr atoi dbref
    
    "page #mail wizzes=: <<>> Player " playerBooted @ unparseobj strcat
    " was booted due to excessive online time.  This has occurred " strcat
    playerBooted @ BOOTED_COUNT_PROP getpropval intostr strcat
    " times for this player. <<>>" strcat
    
    force
;

: changeSystemMaxIdle ( i --  @tunes the maxidle to i seconds )
    "i" checkargs

    var! secondsRemaining
    0 var! days
    0 var! hours
    0 var! minutes

    ( Figure out days, hours, minutes )
    secondsRemaining @ SECONDS_DAY /
    dup days !
    secondsRemaining @ swap SECONDS_DAY * - secondsRemaining !
    
    secondsRemaining @ SECONDS_HOUR /
    dup hours !
    secondsRemaining @ swap SECONDS_HOUR * - secondsRemaining !
    
    secondsRemaining @ SECONDS_MINUTE /
    dup minutes !
    secondsRemaining @ swap SECONDS_MINUTE * - secondsRemaining !

    ( Create the time string )
    days @ intostr "d " strcat
    hours @ intostr strcat
    ":" strcat
    minutes @ intostr strcat
    ":" strcat
    secondsRemaining @ intostr strcat
    
    "maxidle" swap setsysparm
;

: daemon
    #-1 var! playerDbref
    -1 var! playerDescr
    0 var! idle_haven  ( 1 if a temporary haven from idling is set )
    getDefaultIdleTime var! current_bracket_time
    getMaxOnlineTime var! maxOnlineTime

    ( Do this forever, until the muck is shut down )
    BEGIN
( *** DEBUG *** )
depth 0 > if "Stack leak!" abort then
( *** DEBUG *** )
        
        background
        getIntervalTime sleep
        preempt

        getIntervalTime 0 <= if
            "Interval time is 0!" abort
        then
        
        getMaxOnlineTime maxOnlineTime !
        
        idle_haven @ if
            decrementIdleHaven not if
                ( Haven has ended )
                0 idle_haven !
            then
        else
            getIdleHavenTime dup if
                current_bracket_time !
                1 idle_haven !                
            else
                pop
                
                ( If idle haven ended early, set the max idle again just to
                  make things consistent )
                prog IDLE_HAVEN_FORCE_ENDED getpropval if
                    0 current_bracket_time !
                    prog IDLE_HAVEN_FORCE_ENDED remove_prop
                then
                
                ( see if maxidle needs to be changed, and change it if so )
                concount getBracketTime dup current_bracket_time @ = not if
                    dup
                    changeSystemMaxIdle
                    current_bracket_time !
                else
                    pop
                then
                
                maxOnlineTime @ 0 > if
                    ( Remove everyone who has been on too long )
                    online_array
                    FOREACH
                        ( Remove index )
                        swap pop
                        
                        ( Get descriptors )
                        dup playerDbref ! descriptors array_make
                        FOREACH
                            ( Remove index )
                            swap pop
                            
                            dup playerDescr !
                            descrtime maxOnlineTime @ >= if
                                ( Someone has been on too long! )
                                playerDescr @ getBootMessage descrnotify
                                playerDescr @ descrboot
                                playerDbref @ incrementBootCount
                                playerDbref @ sendBootMail
                            then                        
                        REPEAT
                    REPEAT
                then
            then
        then
    REPEAT
;

: main
    
    getIntervalTime not if
        me @
        "ERROR: " CHECK_INTERVAL_TIME_PROP strcat " not set!" strcat 
        notify
        exit
    then

    getDefaultIdleTime not if
        me @
        "ERROR: " DEFAULT_IDLE_TIME_PROP strcat " not set!" strcat 
        notify
        exit
    then
    
    prog BRACKET_PROP propdir? not if
        me @
        "ERROR: " BRACKET_PROP strcat " brackets not set!" strcat 
        notify
        exit
    then
    
    trigger @ #-1 = if
        ( Daemon mode )
        pop
        daemon
    else
        ( Interactive mode )
        "me" match me !
        strip
        preempt
        dup number? not if
            pop
            ( Show help and current state )
            me @ " " notify
            me @ "Maximum Idle Adjustment Program v1.01 by Morticon@SpinDizzy (2013)" notify
            me @ "------------------------------------------------------------------" notify
            me @ " " notify
            me @ "Syntax is '" COMMAND @ strcat " <minutes>'" strcat notify
            me @ "  Where <minutes> is how long to turn off max idle (haven mode)." notify
            me @ "  Example: '" COMMAND @ strcat " 120' turns on idle havening for about 2 hours." strcat notify
            me @ " " notify
            me @ " " notify
            me @ "Current status:" notify
            
            getIdleHavenTime if
                me @ "  There are " getIdleHavenTime 60 / intostr strcat " minutes left on idle havening." strcat notify
                me @ "  This was set by " prog IDLE_HAVEN_USER_PROP getprop name strcat "." strcat notify
            else
                me @ "  Max idling is active (normal operation)." notify
            then
        else
            atoi
            dup 0 < if
                pop
                me @ "ERROR: Invalid idle time." notify
            else
                ( Convert to seconds )
                60 *
                
                dup dup getDefaultIdleTime < swap 0 > and if
                    me @ "ERROR: Too little time specified!" notify
                else
                    dup 0 = if
                        pop
                        
                        getIdleHavenTime if
                            prog IDLE_HAVEN_FORCE_ENDED 1 setprop
                        then
                        
                        0 setIdleHavenTime
                        me @ "Idle havening has been disabled." notify
                    else
                        ( Add a bit of breathing room )
                        getIntervalTime 2 * +

                        dup
                        ( Make the change )
                        changeSystemMaxIdle
                        setIdleHavenTime
                        prog IDLE_HAVEN_USER_PROP me @ setprop
                        prog IDLE_HAVEN_FORCE_ENDED remove_prop
                        me @ "Idle havening has been updated." notify                
                    then
                then
            then
        then
        
        me @ " " notify
    then
;
.
c
q
@set auto-idle-daemon.muf=3
@set auto-idle-daemon.muf=W
@set auto-idle-daemon.muf=A
@set auto-idle-daemon.muf=L
@set auto-idle-daemon.muf=!D
