Test plan:
*    objects: _listen, ~listen, ~olisten props and subdirs, approved and not
*    rooms: _listen, ~listen, ~olisten props and subdirs, approved and not
*    parent room listeners, approved or not
*    parent room traps, approved or not
*    traps on objects, approved or not
*    traps on inventory and me, approved or not
*    Dark player (toggle @tune)
    Test with: allow_listeners, allow_listeners_obj, allow_listeners_env, allow_zombies
*    Test stop at room
*    MPI in props
*    db# in props
*    Unknown in props
*    bad DB ref in props
*    awake asleep players
*    Vehicles
*    asleep players with listener approved or not
*    Dark listener objects
*    dark/not zombies awake or not
*    dark vehicles
*    program listeners
*    Try selecting a room, zombie, me, here, vehicle, and someone else's room
*    Enable and disable autocheck

TODO:
    Add allow_listeners and allow_listeners_env room support.

( /quote -S -dsend '/data/spindizzy/muf/cmd-@sweep101.muf )
@prog cmd-@sweep.muf
1 5000 d
i
(  @sweep replacement v1.01 by Morticon@SpinDizzy 2006
  Valid for -- Muck2.2fb5.64 --
  Traps: page whisper pose say : "
  Listens: _listen ~listen ~olisten

  Also checks @tune parameters:
    allow_listeners  [not checked with regards to room env in v1.01]
    allow_listeners_obj
    allow_listeners_env  [Not checked in v1.01]
    allow_zombies
    who_hides_dark
  
  TO INSTALL:
    Make an action called @sweep [or whatever], and link it to this program.
    It should be set at the highest priority to make sure no other actions can
    override it.
    Next, to enable the auto-check feature, set props in _arrive and _connect
    in room #0 to point to this program [example: @set #0=/_arrive/sweep:111]
    Players may selectivly disable autocheck via the command [defaults to
    enabled].
    Finally, set the /autocheckmessage prop on this program object to a string
    that is printed when a potential privacy violation is found. If you do
    not set it, a default is provided.
    On programs or actions that are NOT privacy violations, @set the property
    /@/sweep-approved to yes and they will not have !!! next to them nor
    be reported as a malicious listener.  To have the scan halt at a certain
    parent in the environment and go no further [for instance, room #0 or
    a wizard controlled main environment room], @set /@/sweep-stop to yes .
)
  
lvar qs  (Quicksweep mode affects a number of functions.  1 if on, 0 if off )
lvar currentObject  (object being examined)
lvar headerOut  (Outputs header for object if not done)
  
: approvedProgram? (d -- i   returns 1 if program is approved as safe, 0
                            otherwise )
    "F" checkargs
    "/@/sweep-approved" getpropstr "yes" stringcmp not
;
  
: approvedTrap? ( d -- i  returns 1 if object is approved as safe for traps,
                          0 otherwise )
    "E" checkargs
    "/@/sweep-approved" getpropstr "yes" stringcmp not
;
  
: stopAtRoom? ( d  -- i  If this room is in the stop list, return 1 )
    dup room? not if pop 0 exit then

    "/@/sweep-stop" getpropstr "yes" stringcmp not
;
  
: trap? ( s -- i Returns 1 if string is a trap )
    dup "pose" stringcmp not if pop 1 exit then
    dup "whisper" stringcmp not if pop 1 exit then
    dup "page" stringcmp not if pop 1 exit then
    dup "say" stringcmp not if pop 1 exit then
    dup "\"" stringcmp not if pop 1 exit then
    ":" stringcmp not if 1 exit then

    ( Not a trap )
    0
;
  
: objectsCanListen? ( -- i returns 1 if @tune indicates objects can listen )
    "allow_listeners_obj" sysparm "yes" strcmp not
    "allow_listeners" sysparm "yes" strcmp not
    and
;
  
: setHeader ( d -- sets the header up for use with showHeader )
    currentObject !
    0 headerOut !
;

: showHeader ( --  If the header for the object has not been shown, show it )
    ( Don't print it out twice! )
    ( If quicksweep, always surpress )
    headerOut @ qs @ or if exit then

    currentObject @ player? if
        "    Player  "
        me @ owner currentObject @ controls if
            currentObject @ unparseobj strcat
        else
            currentObject @ name strcat
        then
        currentObject @ awake? not if " [sleeping]" strcat then
        ( if they are dark, add a !! and [dark] )
        currentObject @ "D" flag? if
            " [dark]" strcat 2 strcut swap pop "!!" swap strcat
        then
        me @ swap notify
        1 headerOut !
        exit
    then

    currentObject @ room? if
        "    "
        me @ owner currentObject @ controls currentObject @ "L" flag? currentObject @ "A" flag? or or if
            currentObject @ unparseobj strcat
        else
            currentObject @ name strcat
        then
  
        ( Show the owner )
        " [owner: " strcat
        currentObject @ owner
        dup me @ swap controls if
            unparseobj
        else
            name
        then
        strcat
        "]" strcat

        me @ swap notify
        1 headerOut !
        exit
    then

    currentObject @ thing? if
        "    Thing   "
        me @ owner currentObject @ controls currentObject @ "C" flag? currentObject @ "L" flag? or or if
            currentObject @ unparseobj strcat
        else
            currentObject @ name strcat
        then

        ( Show the owner )
        " [owner: " strcat
        currentObject @ owner
        dup me @ swap controls if
            unparseobj
        else
            name
        then
        strcat
        "]" strcat

        ( Check for zombie and vehicle )
        currentObject @ "Z" flag? if " [zombie]" strcat then
        currentObject @ "V" flag? if
            " [vehicle]" strcat 2 strcut swap pop "!!" swap strcat
        then
        currentObject @ "D" flag? if
            " [dark]" strcat 2 strcut swap pop "!!" swap strcat
        then
        me @ swap notify
        1 headerOut !
        exit
    then

    currentObject @ program? if
        "!!  Program "
        me @ owner currentObject @ controls currentObject @ "C" flag? currentObject @ "L" flag? or or if
            currentObject @ unparseobj strcat
        else
            currentObject @ name strcat
        then

        ( Show the owner )
        " [owner: " strcat
        currentObject @ owner
        dup me @ swap controls if
            unparseobj
        else
            name
        then
        strcat
        "]" strcat

        me @ swap notify
        1 headerOut !
        exit
    then
    
    "showHeader got a non program/thing/room/player!" abort
;
  
: clearExplode  ( s1...si i -- POPs the remainder of an explode, assuming i is counting the elements LEFT )
    "i" checkargs
  
    dup not if pop exit then

    BEGIN
        swap pop
        1 -
        dup not if pop break then
    REPEAT
;

: showTraps (d -- Given room or object d, outputs if it traps any say, pose,
                  etc)
            ( if qs:  d -- i.  Return 1 if unapproved trap found )
  
    dup setHeader
  
    ( Don't bother if it can't have exits )
    dup room? 2 pick player? 3 pick thing? or or not if
        pop
        qs @ if 0 then
        exit
    then

    exits
    dup ok? not if
        pop
        qs @ if 0 then
        exit
    then
    ( Loop through each exit on the object )
    BEGIN
        ( Parse the action name )
        dup name ";" explode
  
        ( See if the action is a trapper )
        BEGIN
            1 - swap
            dup trap? if
                ( It's a trap.  Is it approved? )
                2 pick 3 + pick approvedTrap? not if
                    qs @ if
                        ( quickscan - just return 1 )
                        pop clearExplode pop 1 exit
                    else
                        ( Not quickscan - output to user and stop this loop )
                        showHeader
                        me @
                            "!!    " rot strcat " is trapped here [" strcat 
                            3 pick 4 + pick name strcat "]" strcat
                        notify
                        clearExplode 0
                    then
                else
                    ( An approved trap - output anyway and stop loop )
                    qs @ if
                        pop
                    else
                        showHeader
                        me @
                            "      " rot strcat " is trapped here [" strcat
                            3 pick 4 + pick name strcat "]" strcat
                        notify
                    then
                    clearExplode 0
                then
            else
                pop
            then
            ( See if we've done analyzing the exit )
            dup not
        UNTIL
        pop
  
        next
        dup ok? not
    UNTIL
    pop

    ( Send the OK if in quickscan )
    qs @ if
        0
    then
;
  
: decodeListenLine (? -- d i   Given the result from getprop on a listen prop,
                               return the dbref the line references and a 0 for
                               MUF or a dbref of -1 and 1 for MPI, 2 for unknown,
                               3 for nonexistant )

    ( FIrst see if the prop exists )
    dup int? if
        dup 0 = if pop -1 dbref 3 exit then
    then

    dup int? if dbref then

    dup string? if
        ( See if it is MPi )
        strip

        dup 1 strcut pop "$" strcmp not if
            ( Uses @reg )
            match
            dup ok? if
                0 exit
            else
                2 exit
            then
        then
  
        dup "{" instr if
            ( MPI.  Exit )
            pop -1 dbref 1 exit
        then
  
        atoi dbref
    then

    dup dbref? if
        dup program? if
            ( MUF )
            0 exit
        else
            dup ok? not if
                pop -1 dbref 3 exit
            then
        then
    then

    ( Catch-all )
    pop
    -1 dbref 2
;
  
: outputWarning ( d i -- Given output from decodeListenLine, handles any
                         needed output to user )
                ( if qs:  d i -- i  Returns 1 if unapproved listener found
                                    or dark listener )

    ( Quick exit if nonexistant prop )
    dup 3 = if
        pop pop
        qs @ if 0 then
        exit
    then

    dup 0 = if
        ( Standard MUF )
        pop
        dup approvedProgram? if
            ( Approved listener, not a warning )
            qs @ not if
                "      "
            else
                ( Dark listeners are considered malicious )
                dup room? not swap "D" flag? and if 1 else 0 then
                exit
            then
        else
            ( Not an approved listener)
            qs @ not if
                "!!    "
            else
                pop 1 exit
            then
        then

        me @ owner 3 pick controls 3 pick "L" flag? or if
            swap unparseobj strcat
        else
            swap name strcat
        then
        " is a listening program" strcat
        showHeader
        me @ swap notify
        exit
    else
        dup 1 = if
            ( MPI is currently never approved )
            pop pop
            qs @ not if
                showHeader
                me @ "!!    MPI listener used" notify
            else
                1 exit
            then
        else
            ( If 2, warn about unknown )
            2 = if
                pop
                qs @ not if
                    showHeader
                    me @ "!!    UNKNOWN listener prop used" notify
                else
                    1 exit
                then
           then
        then
    then

    ( Fail safe )
    qs @ if
        1
    then
;
  
: showListenerHelper (d s -- Internal helper to peruse a listen propdir )
                     (if qs:  d s -- i  Returns 1 if unapproved listener)
  
    ( Check the root )
    2 pick 2 pick
    getprop decodeListenLine outputWarning
    qs @ if
        ( unapproved listener in qs mode )
        if pop pop 1 exit then
    then

    ( Now check the subdirs, if there are any )
    2 pick 2 pick propdir? if
        ( get ready to cycle through directory )
        "/" strcat
        swap dup rot
        nextprop
        BEGIN  
            ( If it is a propdir, recurse )
            2 pick 2 pick propdir? if
                2 pick 2 pick
                showListenerHelper
                ( We came back.  If QS, see if we need to stop )
                qs @ if
                    if pop pop 1 exit then
                then
            else
                ( process the prop itself - if it has something )
                2 pick 2 pick
                showListenerHelper
                qs @ if
                    ( unapproved listener in qs mode )
                    if pop pop 1 exit then
                then
            then
  
            ( Next prop, if there is one )
            swap dup rot nextprop
            dup strlen not
        UNTIL
        pop pop
    else
        pop pop
    then
  
    ( All approved.  If QS mode, say it's clear  )
    qs @ if 0 then
;
  
: showAreaListener (d --   Given a dbref, notifies user if
                           someone in the given room or vehicle or player is
                           listening )
                   ( if qs:  d -- i  return 1 if any inapproved listeners )
  
    ( Cycle through each object in room )
    contents
    BEGIN
        dup ok? not if break then
        ( Determine object type. )
        dup setHeader
        ( If player, output it.  Otherwise, check each of the three props
          on it )
        dup player? if
            ( Players will never trigger as an unapproved listener, even if
              they have bad programs in their _listen.  The exception is if
              they are dark and @tune indicates they should be seen, or are
              sleeping and using listen )
            dup awake? if
                dup "D" flag? 2 pick "W" flag? "who_hides_dark" sysparm "yes" strcmp not and and not if
                    ( They are online and can be seen on WHO - process them )
  
                    ( Trigger listener warning if a dark player doesn't meet the requirements )
                    qs @ if
                        dup "D" flag? if
                            pop 1 exit
                        then
                    then
  
                    showHeader
  
                    ( If @tune allows it, check for listener programs )
                    objectsCanListen? if
                        dup "/_listen" showListenerHelper
                        qs @ if
                            if pop 1 exit then
                        then
  
                        dup "/~listen" showListenerHelper
                        qs @ if
                           if pop 1 exit then
                        then
  
                        dup "/~olisten" showListenerHelper
                        qs @ if
                            if pop 1 exit then
                        then
                    then
                then
            else
                ( Asleep.  Process them no matter what. )
                ( Only show if they're listening )

                ( If @tune allows it, check for listener programs )
                objectsCanListen? if
                    dup "/_listen" showListenerHelper
                    qs @ if
                        if pop 1 exit then
                    then
    
                    dup "/~listen" showListenerHelper
                    qs @ if
                        if pop 1 exit then
                    then
  
                    dup "/~olisten" showListenerHelper
                    qs @ if
                        if pop 1 exit then
                    then
                then
            then
        then
  
        ( It is a thing or program or action - process it regardless )
        dup thing? over program? or if
            ( Show header instantly if it's an awake zombie, or vehicle )
            dup owner awake? over "Z" flag? "allow_zombies" sysparm "yes" strcmp not and and
            over "V" flag?
            or if dup thing? if showHeader then then

            ( Warn if vehicle object - they are unusual these days )
            qs @ if
                dup "V" flag? if
                    pop 1 exit
                then
            then

            ( Warn if dark zombie )
            qs @ if
                dup owner awake?
                over "Z" flag? and
                over "D" flag? and 
                "allow_zombies" sysparm "yes" strcmp not 
                and if
                    pop 1 exit
                then
            then

            ( If @tune allows it, check for listener programs )
            objectsCanListen? if
                dup "/_listen" showListenerHelper
                qs @ if
                    if pop 1 exit then
                then
    
                dup "/~listen" showListenerHelper
                qs @ if
                    if pop 1 exit then
                then
  
                dup "/~olisten" showListenerHelper
                qs @ if
                    if pop 1 exit then
                then
            then
  
            ( Check for traps on things. )
            dup showTraps
            qs @ if
                if 1 exit then
            then
        then

        ( next object, if there is one )
        next
        dup ok? not
    UNTIL
    pop

    ( If QS, we got through with nothing bad, so return such )
    qs @ if
        0
    then
;
  
: showRoomListener (d --   Given a dbref, notifies user if
                           the given room or vehicle or player is listening )
                   (if qs: d -- i  Returns 1 if unapproved listener)
  
    dup setHeader
  
    ( If room is actually a player or zombie but not a room, )
    ( then it is a listener )
    dup player? over "Z" flag? or over room? not and if
        showHeader
        qs @ if
            if 1 exit then
        then
    then
  
    ( Check each of the three listen props on the room and respond accordingly )
    dup "/_listen" showListenerHelper
    qs @ if
        if pop 1 exit then
    then
  
    dup "/~listen" showListenerHelper
    qs @ if
        if pop 1 exit then
    then
  
    dup "/~olisten" showListenerHelper
    qs @ if
        if pop 1 exit then
    then
  
    ( Check for traps )
    showTraps
    qs @ if
        if 1 exit then
    then

    ( We're OK - no bad listeners )
    qs @ if 0 then
;

: listenerWarning ( --  Prints warning about potential listeners )
    prog "/autocheckmessage" getpropstr
  
    dup strlen if
        me @ swap notify
    else
        pop
        me @ "## There are possible non obvious listeners here" notify
    then
;
  
: quickSweep (d -- Informs the user if there is a potential listener
                   starting from dbref d [room, vehicle, player] )
    1 qs !

    ( If program runner is a player or thing, first do inventory )
    me @ player? me @ thing? or me @ location 3 pick dbcmp and if
        ( Check actions attached to player )
        me @ setHeader
        me @ showTraps
        if pop listenerWarning exit then
  
        ( Now check inventory items for traps only )
        me @ contents
        dup ok? if
            BEGIN
                dup setHeader
                dup exit? not if
                    dup showTraps
                    if pop listenerWarning exit then
                then
  
                next
                dup ok? not
            UNTIL
        then
        pop
    then

    ( Call showAreaListener, abort if listener found )
    dup showAreaListener
    if pop listenerWarning exit then
    ( Check the environment )
    dup stopAtRoom? not if
        ( Do the start room, abort if listener found )
        dup showRoomListener
        if pop listenerWarning exit then
        ( Now do all the parents, if they can listen )
        location
        dup ok? not if pop exit then
        BEGIN
            ( Do we stop here? )
            dup stopAtRoom? if break then
            ( Call showRoomListener, abort if listener found )
            dup showRoomListener
            if pop listenerWarning exit then
            ( Go up, but don't go past #0 )
            dup 0 dbref dbcmp if break then
            location
        REPEAT
    then
    pop
;
  
: doIt (d --  Start listener sweep from room/player/vechicle d )
    ( If program runner is a player or thing, first do inventory )
    me @ player? me @ thing? or me @ location 3 pick dbcmp and if
        me @ "Listeners in your inventory:" notify
        ( Check actions attached to player )
        me @ setHeader
        me @ showTraps
  
        ( Now check inventory items for traps only )
        me @ contents
        dup ok? if
            BEGIN
                dup setHeader
                dup exit? not if
                    dup showTraps
                then
  
                next
                dup ok? not
            UNTIL
        then
        pop
    then
  
    ( "Listeners in ...:" )
    "Listeners in "
    me @ owner 3 pick controls 3 pick "L" flag? 4 pick "A" flag? or or if
        2 pick unparseobj
    else
        2 pick name
    then
    strcat
    ":" strcat
    me @ swap notify
    ( Call showAreaListener )
    dup showAreaListener
    ( "Listening rooms down the environment:" )
    me @ "Listening rooms down the environment:" notify
    dup stopAtRoom? not if
        ( Do the start room )
        dup showRoomListener
        ( Now do all the parents )
        location
        dup ok? not if pop exit then
        BEGIN
            ( Do we stop here? )
            dup stopAtRoom? if pop break then
            ( Call showRoomListener )
            dup showRoomListener
            ( Go up, but don't go past #0 )
            dup 0 dbref dbcmp if pop break then
            location
        REPEAT
    else
        pop
    then
;
  
: showHelp ( --   Print the help screen )
    me @ " " notify
    me @ "Newsweep v1.01  Morticon@SpinDizzy  2006" notify
    me @ command @ " shows you who or what might be listening in a room." strcat notify
    me @ "It is mostly useful to tell if you are being 'wiretapped' within the MUCK." notify
    me @ "Anything in the resulting output beginning with '!!' is a potential privacy" notify
    me @ "issue." notify
    me @ " " notify
    me @ "Usage:" notify
    me @ "                        - No arguments 'sweeps' the current room for bugs" notify
    me @ " #help                  - This screen" Notify
    me @ " #1234 / $room / etc    - Check for bugs in a particular room that you control." notify
    me @ " #disable               - Disables auto-check when entering a room." notify
    me @ " #enable                - Enables auto-check when entering a room. (default)" notify
    me @ " " notify
;
  
: main (s -- )
    0 qs !
    0 dbref setHeader
    background

    ( Were we activated from _arrive or _connect ? )
    dup "Arrive" strcmp not over "Connect" strcmp not or if
        pop
        ( See if we're ignored.  If so, exit )
        me @ "/_prefs/sweep-auto" getpropstr "no" stringcmp not if exit then
        ( Do quickSweep )
        me @ location
        quickSweep
        exit
    else
        ( Else, process commandLine )
        "me" match me !
        strip
        dup strlen if
            dup match
            dup ok? if
                ( User gave a DB# to check )
                swap pop
                me @ over controls if
                    doIt
                else
                    pop
                    me @ "Permission denied." notify
                then
            else
                ( Not a DB#, must be a regular argument )
                pop
                ( #help )
                dup "#help" stringcmp not if
                    pop
                    showHelp
                    me @ "*Done*" notify exit
                then
   
                ( #disable )
                dup "#disable" stringcmp not if
                    pop
                    me @ "/_prefs/sweep-auto" "no" setprop
                    me @ command @ " auto-check is disabled." strcat notify
                    me @ "*Done*" notify exit
                then
  
                ( #enable )
                dup "#enable" stringcmp not if
                    pop
                    me @ "/_prefs/sweep-auto" remove_prop
                    me @ command @ " auto-check is enabled." strcat notify
                    me @ "*Done*" notify exit
                then
    
                ( default )
                pop
                showHelp
            then
        else
            pop
            me @ location
            doIt
        then
    then
  
    ( for debug )
    ( depth dup if "Debug: Depth not 0!  == " swap intostr strcat me @ swap notify else pop then )
    me @ "*Done*" notify
;
.
c
q
@set cmd-@sweep.muf=W
@set cmd-@sweep.muf=3
@set cmd-@sweep.muf=L
@set cmd-@sweep.muf=!D
