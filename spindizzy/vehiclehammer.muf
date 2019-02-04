( /quote -S -dsend '/data/spindizzy/muf/vehiclehammer.muf )
@prog vehiclehammer.muf
1 2222 d
i
( Wizards: To install, simply link a global to this program and
  set the following props on the program object itself:
    @set vehiclehammer.muf=indoorenv:123 [ Default environment room ]
    @set vehiclehammer.muf=outprog:456   [ Prog to leave ship. ObjExit.muf ]
    @set vehiclehammer.muf=driveprog:789 [ Prog to drive.  StarDrive.muf ]
    @set vehiclehammer.muf=scanprog:999  [ Scan area ship is in.  window.muf ]
    @set vehiclehammer.muf=listenprog:77 [ Used to listen to outside. listen.muf ]
    @set vehiclehammer.muf=lookprog:111  [ Used to autolook when vehicle moves. ]
  
  Set the @guest prop on each guest to some string, to prevent them from
  using this program.
)
  
( v1.0  : Initial )
( v1.01 : Autolook when room changes in immersive )
( v1.02 : Check to make sure action is @locked in immersive )
( v1.03 : Added autolook, puppets can use immersive )
    
(Program begins HERE)
 
$def VERSIONSTR "1.03"
 
(Includes)
$include $lib/strings
$include $lib/match
 
(Vars)
lvar input
lvar listPropLoop
lvar totPennies
 
( Names of things )
lvar shortName
lvar vehicleName
lvar actionName
 
( DB #s of important parts of ship )
lvar vehDB
lvar actionDB
lvar envDB
lvar airlockDB
lvar cockpitDB
( Other stuff, for incidental actions like 'drive' or 'out' )
lvar tempDB
lvar iMode
 
( Used while deleting)
lvar numLinkProgs
lvar numLinkRooms
 
: sysMessage ( s --   Prefixes 'eventlist.muf: ' to string and outputs completed string to user )
        me @ swap "vehiclehammer.muf: " swap strcat notify
;
  
: blankline
        me @ " " notify exit
;
 
: noSpaces (s -- s' Removes ALL spaces from s )
    strip
    " " explode 1 - dup if
        BEGIN
            1 -
            rot rot swap strcat swap
        dup not
        UNTIL
    then
    pop
;
 
( --- Poses and says while in the program.  Courtesy of Kinsor @ Spindizzy )
: in-program-tell
dup ":" instr 1 =
over "\"" instr 1 = or
  if
    dup ":" instr 1 =
      if
        1 strcut swap pop
        me @ name " " strcat over strcat
        loc @ swap me @ swap notify_except
        "<In VehicleHammer> " me @ name strcat " " strcat swap strcat .tell
      else
        dup me @ swap "<In VehicleHammer> You " me @ "_say/def/say" getpropstr 
dup strip not
          if
            pop
            "say"
          then
        ", " strcat strcat swap strcat "\"" strcat notify
        me @ dup location swap rot over name " " strcat me @ 
"_say/def/osay" getpropstr dup strip not
          if
            pop
            "says"
          then
        ", " strcat strcat swap strcat "\"" strcat notify_except
      then
  then
;
 
: do_read  
begin
  read
  dup ":" instr 1 =
  over "\"" instr 1 = or
while
  in-program-tell
repeat
;
( ----------- )
 
: pause
        blankline
        me @ "--Output paused.  Press the SPACEBAR and ENTER to continue--" notify
        read pop exit
;
  
: securityCheck ( s -- i  Given a shortname, return 1 if vehicle is controlled by owner and valid, else 0)
    dup dup dup me @ "/_prefs/vehicles/" rot strcat getprop dup ok? if
        ( Do we control the vehicle object? )
        dup dup thing? swap me @ swap owner dbcmp and if
  
            ( Does the vehicle have the right shortname attached to it?)
            dup "/_prefs/vehicle/shortName" getpropstr rot strcmp if
                pop pop pop 0 exit
            then
  
            (Now, if we control both the airlock and cockpit, we are set)
            dup "/_prefs/vehicle/cockpit" getprop dup dbref? if 
                dup dup room? if
                    me @ swap owner dbcmp not swap "/_prefs/vehicle/shortName" getpropstr 4 rotate strcmp or if
                        pop pop 0 exit
                    then
                else
                    pop pop pop pop pop 0 exit
                then
            else
                pop pop pop pop 0 exit
            then
  
            "/_prefs/vehicle/airlock" getprop dup dbref? if 
                dup dup room? if
                    me @ swap owner dbcmp not swap "/_prefs/vehicle/shortName" getpropstr 3 rotate strcmp or if
                        0 exit
                    then
                else
                    pop pop pop 0 exit
                then
            else
                ( Airlock is optional )
                pop pop
            then
  
        else
            pop pop pop pop 0 exit
        then
    else
        pop pop pop pop 0 exit
    then
    1
;
  
: anyVehicles? ( -- i  returns 1 if vehicles listed on player, 0 if none )
    me @ "/_prefs/vehicles/" nextprop strlen
;
  
: cleanList ( -- Cleans the list of vehicles on the character, removing invalid entries )
    me @ "/_prefs/vehicles/" nextprop
    dup strlen if
        ( Start looping through all vehicles on list if there is at least one vehicle listed )
        BEGIN
            ( See if the selected vehicle is valid.  If not, remove it )
            dup dup "/" rinstr strcut swap pop securityCheck not if
                ( Get the vehicle after it so we don't have to restart our loop.  Then delete the bad entry )
                dup me @ swap nextprop  ( stack: bad_entry next_entry )
                swap
                me @ swap remove_prop
                ( If the next entry is blank, just stop the loop, else jump to the top )
                dup strlen if 
                                continue
                           else
                                break
                           then
            then
            ( Advance to next vehicle, if last was good.  If next is END, then let the until know )
            me @ swap nextprop
            dup strlen not
        UNTIL pop
    else
        pop
    then
;
   
: listVehicles ( --  Displays a list of valid vehicles )
    cleanList
    ( Only continue if there are vehicles! )
    anyVehicles? not if
        "There are no vehicles to list!" sysMessage
        exit
    then
  
    ( Display a header )
    me @ "Shortname | Vehicle Name                          | Location                 " notify
    me @ "----------|---------------------------------------|--------------------------" notify
        ( 123456789   1234567890123456789012345678901234567   1234567890123456789012345 )
    me @ "/_prefs/vehicles/" nextprop
    dup "" strcmp if
        listPropLoop !
        ( Start looping through all vehicles on list if there is at least one vehicle listed )
        BEGIN
            me @ listPropLoop @ getprop vehDB !
            ( Shortname )
            listPropLoop @ dup "/" rinstr strcut swap pop 9 strcut pop 9 STRleft
            ( Shortname | Vehicle name )
            " | " strcat
            vehDB @ unparseobj 37 strcut pop 37 STRleft strcat
            ( Shortname | Vehicle name | Location )
            " | " strcat
            vehDB @ location 
            dup me @ swap owner dbcmp if
                unparseobj
            else 
                name
            then
            25 strcut pop strcat
            ( Send it off )
            me @ swap notify
  
            ( Set it up for the next iteration, if there is one )
            me @ listPropLoop @ nextprop dup listPropLoop !
            strlen not
        UNTIL
    else
        pop
    then
;
  
: doTeleport ( s --  Teleport to cockpit of vehicle shortname s)
       ( In case they enter an invalid shortname )
        dup "/_prefs/vehicles/" swap strcat me @ swap getprop ok? not if
            pop
            blankline
            "Invalid vehicle specified." sysMessage
            exit
        then
 
        ( Do an extra security check to be safe )
        dup securityCheck if
            ( If all passes, do the teleport! )
            "Teleporting..." sysMessage
            "/_prefs/vehicles/" swap strcat me @ swap getprop "/_prefs/vehicle/cockpit" getprop
            me @ swap moveto
            pid kill
        else
            pop
            "Unexpected error when trying to teleport!  Do you still own/control the ship?" sysMessage
            exit
        then
;
  
: teleportToVehicle ( -- Interface to teleport to vehicle cockpit )
    ( Do cleanup, show the vehicles, and ask where they want to go )
    listVehicles
  
    anyVehicles? if
        BEGIN
            blankline
            me @ "Enter shortname of vehicle to teleport to, or '.' to abort >>" notify
            do_read strip
            (In case they abort )
            dup "." strcmp not if
                pop
                me @ "Aborted teleport." notify
                exit
            then
  
            ( Nothing entered! )
            dup strlen not if
            pop
                continue
            then
  
            ( If teleport succeeds, it will autokill program )
            doTeleport
        REPEAT
    then
;
  
: setX ( d --  Outputs message to explain how to set vehicle X.  One day might be automated )
    dup
    (Output message on how to set X bit and exit)
    ( A cute little TF hook to type it 'for' you )
    me @ "##edit> @set #" rot intostr strcat "=X" strcat notify
    blankline
    (  ) 
    ( Tell user how to finish making the zombie, then abort program )
    me @ "vehiclehammer.muf: User interaction required to finish.  READ BELOW" notify
    me @ "  Please type in the following line EXACTLY as you see it to finish" notify
    me @ "  making your vehicle.  Afterwards, it is a good idea to drop the" notify
    me @ "  vehicle and start the process of customizing it (descriptions, etc)." notify
    me @ "  Remember, the command to enter your vehicle is: " actionName @ strcat notify
    blankline
    me @ "Type this:" notify
    me @ "@set #" rot intostr strcat "=X" strcat notify
    blankline
;
  
: makeOne (i --  i=0 = default env, 1 = use existing, 2 = new environment)
    (Get stuff from @tune and verify they have enough money to make it)
    "exit_cost" sysparm atoi 4 *
    "link_cost" sysparm atoi 4 *
    ( Select room cost based on new env room or not )
    "room_cost" sysparm atoi 4 pick 2 = if 2 else 1 then *
    "object_cost" sysparm atoi
    + + + dup totPennies ! me @ pennies <= not if
        pop "You need more " "pennies" sysparm strcat " to make a vehicle.  Aborting." strcat sysMessage exit
    then
  
    ( Set the environment room stuff )
    dup 0 = if
        pop
        prog "indoorenv" getpropstr atoi dbref envDB !
    else
        2 = if
            prog "indoorenv" getpropstr atoi dbref vehicleName @ " Environment Room" strcat newroom envDB !
        then
    then
    (Create cockpit)
    "Creating cockpit..." sysMessage
    envDB @ vehicleName @ ": Cockpit" strcat newroom cockpitDB !
  
    (Create main vehicle object)
    "Creating main vehicle object..." sysMessage
    me @ vehicleName @ newobject vehDB !
    ( vehDB @ "Vehicle" set )
  
    (Create entrance action and link it to cockpit)
    "Creating and linking entrance action..." sysMessage
    vehDB @ actionName @ newexit actionDB !
    actionDB @ cockpitDB @ setlink
  
    (Create 'out', 'drive', and 'scan' in vehicle and set props and link them correctly)
    "Creating 'out' 'drive' 'scan' actions and linking them..." sysMessage
    cockpitDB @ "[O]ut;o;out" newexit prog "outprog" getpropstr atoi dbref setlink
    cockpitDB @ "goto" vehDB @ intostr setprop
  
    cockpitDB @ "[D]rive;d;drive" newexit
    dup "me" setlockstr pop
    dup "/_/fl" "Sorry, driving is currently @locked." setprop
    dup prog "driveprog" getpropstr atoi dbref setlink
    ( exit db from above )  "_object" vehDB @ intostr setprop
  
    iMode @ if
        cockpitDB @ "[Im]mersive Mode;im;immersive;immersive mode" newexit
        dup "me" setlockstr pop
        dup "/_/fl" "Sorry, immersive mode is currently @locked." setprop
        dup dup prog setlink
        "/_prefs/vehicle/immersive" "yes" setprop
        "/_prefs/vehicle/object" vehDB @ intostr setprop
    else
        cockpitDB @ "[S]can;s;scan" newexit prog "scanprog" getpropstr atoi dbref setlink
    then
  
    (Do the listen...)
    vehDB @ "/_listen/veh" prog "listenprog" getpropstr setprop
    vehDB @ "/listen/dest" cockpitDB @ intostr setprop
    vehDB @ "/listen/filter" "off" setprop
    vehDB @ "/listen/power" "on" setprop
    vehDB @ "/listen/recurse" "off" setprop
    iMode @ if
        vehDB @ "/listen/pre" ">> " setprop
    else
        vehDB @ "/listen/pre" "Outside>> " setprop
    then
 
    (Do the autolook on move...)
    vehDB @ "/_arrive/forcelook" "&{muf:#" prog "lookprog" getpropstr strcat ",here}" strcat setprop
 
    (Set props on vehicle object and user for bookkeeping)
    "Finishing up..." sysMessage
  
    me @ totPennies @ -1 * addpennies
  
    me @ "/_prefs/vehicles/" shortName @ strcat vehDB @ setprop
    cockpitDB @ "/_prefs/vehicle/shortName" shortName @ setprop
    vehDB @ "/_prefs/vehicle/shortName" shortName @ setprop
 
    vehDB @ "/_prefs/vehicle/cockpit" cockpitDB @ setprop
    vehDB @ "/_prefs/vehicle/env" envDB @ setprop
    vehDB @ "/@/flk" "me" parselock setprop
 
    (Output message on how to set X bit and exit)
    vehDB @ setX
    pid kill
;
 
: makeTwo (i --  i=0 = default env, 1 = use existing, 2 = new environment)
    (Get stuff from @tune and verify they have enough money to make it)
    "exit_cost" sysparm atoi 6 *
    "link_cost" sysparm atoi 6 *
    ( Select room cost based on new env room or not )
    "room_cost" sysparm atoi 4 pick 2 = if 3 else 2 then *
    "object_cost" sysparm atoi
    + + + dup totPennies ! me @ pennies <= not if
        pop "You need more " "pennies" sysparm strcat " to make a vehicle.  Aborting." strcat sysMessage exit
    then
  
    ( Set the environment room stuff )
    dup 0 = if
        pop
        prog "indoorenv" getpropstr atoi dbref envDB !
    else
        2 = if
            prog "indoorenv" getpropstr atoi dbref vehicleName @ " Environment Room" strcat newroom envDB !
        then
    then
    (Create cockpit)
    "Creating cockpit..." sysMessage
    envDB @ vehicleName @ ": Cockpit" strcat newroom cockpitDB !
 
    (Create main vehicle object)
    "Creating main vehicle object..." sysMessage
    me @ vehicleName @ newobject vehDB !
    ( vehDB @ "Vehicle" set )
  
    "Creating Entryway..." sysMessage
    envDB @ vehicleName @ ": Entryway" strcat newroom airlockDB !
    airlockDB @ "[C]ockpit;c;cockpit" newexit cockpitDB @ setlink
    cockpitDB @ "[O]ut;o;out" newexit airlockDB @ setlink
  
    (Create entrance action and link it to cockpit)
    "Creating and linking entrance action..." sysMessage
    vehDB @ actionName @ newexit actionDB !
    actionDB @ airlockDB @ setlink
  
    (Create 'out', 'drive', and 'scan' in vehicle and set props and link them correctly)
    "Creating 'out' 'drive' 'scan' actions and linking them..." sysMessage
    airlockDB @ "[O]ut;o;out" newexit prog "outprog" getpropstr atoi dbref setlink
    cockpitDB @ "goto" vehDB @ intostr setprop
    airlockDB @ "goto" vehDB @ intostr setprop
  
    cockpitDB @ "[D]rive;d;drive" newexit
    dup "me" setlockstr pop
    dup "/_/fl" "Sorry, driving is currently @locked." setprop
    dup prog "driveprog" getpropstr atoi dbref setlink
    ( exit db from above )  "_object" vehDB @ intostr setprop
  
    iMode @ if
        cockpitDB @ "[Im]mersive Mode;im;immersive;immersive mode" newexit
        dup "me" setlockstr pop
        dup "/_/fl" "Sorry, immersive mode is currently @locked." setprop
        dup dup prog setlink
        "/_prefs/vehicle/immersive" "yes" setprop
        "/_prefs/vehicle/object" vehDB @ intostr setprop
    else
        cockpitDB @ "[S]can;s;scan" newexit prog "scanprog" getpropstr atoi dbref setlink
    then
  
    (Do the listen...)
    vehDB @ "/_listen/veh" prog "listenprog" getpropstr setprop
    vehDB @ "/listen/dest" cockpitDB @ intostr setprop
    vehDB @ "/listen/filter" "off" setprop
    vehDB @ "/listen/power" "on" setprop
    vehDB @ "/listen/recurse" "off" setprop
    iMode @ if
        vehDB @ "/listen/pre" ">> " setprop
    else
        vehDB @ "/listen/pre" "Outside>> " setprop
    then
 
    (Set props on vehicle object and user for bookkeeping)
    "Finishing up..." sysMessage
  
    me @ totPennies @ -1 * addpennies
  
    me @ "/_prefs/vehicles/" shortName @ strcat vehDB @ setprop
    vehDB @ "/_prefs/vehicle/shortName" shortName @ setprop
    cockpitDB @ "/_prefs/vehicle/shortName" shortName @ setprop
    airlockDB @ "/_prefs/vehicle/shortName" shortName @ setprop
    vehDB @ "/_prefs/vehicle/cockpit" cockpitDB @ setprop
    vehDB @ "/_prefs/vehicle/airlock" airlockDB @ setprop
    vehDB @ "/_prefs/vehicle/env" envDB @ setprop
    vehDB @ "/@/flk" "me" parselock setprop
 
 
    (Output message on how to set X bit and exit)
    vehDB @ setX
    pid kill
;
  
: askQuestions ( -- i0 i1  Asks the user about the veh to be made.  Sets up needed name vars, and
                returns veh type [#rooms, i0 = 1 or 2], and if env room is desired [i1 = 0, 1, 2].
                2 means a new room is to be created. If aborted, returns 0 0 )
  
    cleanList
  
    (Find out vehicle's shortname and use if valid)
    BEGIN
        blankline
        me @ "[1/6]  Enter a short name (no spaces) used to identify the vehicle" notify
        me @ "       while in this program or a '.' to abort." notify
        me @ "Short Name>>" notify
        do_read strip tolower
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Creation of vehicle aborted." notify
            0 0 exit
        then
        ( Make sure the shortname IS actually short! )
        dup strlen 9 > if
            pop
            me @ "Shortnames must be 9 characters or less.  Try again." notify
            continue
        then
        (Don't allow spaces)
        dup " " instr if
            pop
            me @ "Sorry, spaces are not allowed in the shortname. Try again."  notify
            continue
        then
        (No / _ . *)
        dup "*[./_\*]*" smatch if
            pop
            me @ "Sorry, the / _ . * characters cannot be used in the shortname." notify
            continue
        then
        ( Check for shortname already used )
        dup me @ swap "/_prefs/vehicles/" swap strcat getprop dbref? if
            pop 
            me @ "This shortname is already in use.  Try another one." notify
            continue
        then
        ( Gauntlet passed! )
        dup shortName ! 
        me @ "Vehicle shortname is: " rot strcat notify
        break
    REPEAT
  
    (Find out veh's name)
    BEGIN
        blankline
        me @ "[2/6]  Enter the vehicle's name or a '.' to abort." notify
        me @ "Vehicle Name>>" notify
        do_read strip
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Creation of vehicle aborted." notify
            0 0 exit
        then
        ( Gauntlet passed! )
        dup vehicleName !
        me @ "Vehicle name is: " rot strcat notify
        break
    REPEAT
  
    (Find out enter action's name)
    BEGIN
        blankline
        me @ "[3/6]  Enter the name of the action used to enter/board the vehicle or '.'" notify
        me @ "       to abort.  It is recommended to keep the name short and without spaces." notify
        me @ "       Suggested actions are 'board', 'enter', 'enter"
            vehiclename @ noSpaces tolower strcat "'," strcat
          notify 
        me @ "       'airlock', etc." notify
        me @ "Enter Action Name>>" notify
        do_read strip
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Creation of vehicle aborted." notify
            0 0 exit
        then
        ( Gauntlet passed! )
        dup actionName ! 
        me @ "Enter action for vehicle is: " rot strcat notify
        break
    REPEAT
  
    ( Find out how many rooms they want )
    BEGIN
        blankline
        me @ "[4/6]  Do you want a single room inside the vehicle (the cockpit) or two" notify
        me @ "       rooms (an entryway and a cockpit)?  If you plan to expand your" notify
        me @ "       vehicle later, it is best to pick two rooms." notify
        me @ "       Examples of one room vehicles include cars, jet fighters, and mecha/robots." notify
        me @ "       Two room vehicles include spaceships, trains, and large mobile homes." notify
        me @ "       Please enter '1' (for one room), '2' (for two rooms), or '.' to abort." notify
        me @ "Number of Rooms>>" notify
        do_read strip
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Creation of vehicle aborted." notify
            0 0 exit
        then
        ( Probably numeric input by now, so convert and check for valid range )
        atoi dup dup
        1 = swap 2 = or not if
            pop
            me @ "Incorrect choice.  Try '1', '2', or '.' ." notify
            continue
        then
        ( Gauntlet passed, keep on stack )
        dup
        me @ "Number of rooms in vehicle: " rot intostr strcat notify
        break
    REPEAT
  
    ( Find out if they want an immersive vehicle )
    BEGIN
        blankline
        me @ "[5/6]  Do you want an immersive vehicle?  An immersive vehicle allows" notify
        me @ "       you to enter a special mode where the vehicle does everything you" notify
        me @ "       type directly without having to prepend it with 'drive'.  This is" notify
        me @ "       especially useful for 1-room gundam type vehicles." notify
        me @ "       You may also type '.' to abort vehicle creation." notify
        me @ "Immersive mode (YES/NO)??" notify
        do_read strip tolower
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Creation of vehicle aborted." notify
            pop 0 0 exit
        then
        ( See if they entered yes or no, and continue based on that )
        dup "n" instr if
            pop
            me @ "Normal vehicle (no immersive mode) desired." notify
            0 iMode !
            break
        then
        "y" instr if
            me @ "Immersive mode vehicle desired." notify
            1 iMode !
            break
        then
 
        me @ "Please enter 'yes', 'no', or '.'" notify
    REPEAT
  
    ( Finally, find out if they want an env room for veh )
    BEGIN
        blankline
        me @ "[6/6]  Do you want a custom environment room associated with the room(s)" notify
        me @ "       inside the vehicle?  If yes, you can choose to make a new environment" notify
        me @ "       room just for the vehicle or use any existing one.  If no," notify
        me @ "       the environment room will be:" notify
        me @ "            "
            prog "indoorenv" getpropstr atoi dbref dup name swap "(#" swap intostr ")." strcat strcat  strcat strcat
        notify
        me @ "       The default answer for this question is 'NO'.  If you are an advanced" notify
        me @ "       builder and do not want the default environment room, answer 'YES'." notify
        me @ "       You may also type '.' to abort." notify
        me @ "Custom Environment Room (YES/NO)??" notify
  
        do_read strip tolower
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Creation of vehicle aborted." notify
            pop 0 0 exit
        then
        ( See if they entered yes or no, and continue based on that )
        dup "n" instr if
            pop
            me @ "No special environment room desired." notify
            0
            exit
        then
        "y" instr if
            blankline
            me @ "[6a/6]  Enter a dbref (example: #1234) or a @reg name (example: $environment)" notify
            me @ "        that you wish to use, or 'new' to indicate a new environment room is" notify
            me @ "        desired.  To abort, hit '.'" notify
            me @ "Environment Room>>" notify
            do_read strip
  
            ( Check for nothing entered)
            dup strlen 0 = if
                pop
                me @ "You did not enter anything!" notify
               continue
            then
            ( Check for abort )
            dup "." strcmp not if
                pop
                me @ "Creation of vehicle aborted." notify
                pop 0 0 exit
            then
            ( If they entered 'new', then we're set, otherwise do a match and security checks )
            dup tolower "new" strcmp not if
                pop
                me @ "New environment room will be created." notify
                2
                exit
            then
            ( Try and get the dbref.  It must be a room AND abode )
            match dup room? if
                dup "Abode" flag? if
                    dup envDB !
                    me @ "Environment room set to #" rot intostr strcat "." strcat notify
                    1
                    exit
                else
                    pop
                    me @ "The room must be set Abode to be a parent!" notify
                    continue
                then
            else
                pop
                me @ "You did not specify a valid room!" notify
                continue
            then
        then
   
        me @ "Please enter 'yes', 'no', or '.'" notify
    REPEAT
;
  
: linkedExits ( d -- i1 i2  Given a dbref, return the number of exits linked to rooms[i1] and progs[i2] )
    exits
    0 0 rot  (These are the return vals  -- i1 i2)
    BEGIN
        dup ok? not if break then
        dup getlink dup
            room? if 4 rotate 1 + 4 rotate 4 rotate 4 rotate then
            program? if swap 1 + swap then
        next
        dup
        ok? not
    UNTIL
    pop
;
 
: exitToThere ( d1 d2 -- i  Is there an exit on d1 that links to d2? )
    swap exits
    BEGIN
        dup ok? not if break then
        dup getlink 3 pick dbcmp if pop pop 1 exit then
        next
        dup
        ok? not
    UNTIL
    pop pop
    0  (Could not find such an exit)
;
 
: printVehicleRooms
    vehDB @ ok? if
        me @ "Vehicle Object: " vehDB @ unparseobj strcat
            notify
    then
    
    cockpitDB @ ok? if
        me @ "Cockpit Room: " cockpitDB @ unparseobj strcat
            notify
    then
    
    airlockDB @ ok? if
        me @ "Airlock Room: " airlockDB @ unparseobj strcat
            notify
    then
    
    envDB @ ok? if
        me @ "Environment Room: " envDB @ unparseobj strcat
            notify
    then
;
  
: deleteVehicle ( -- Removes a vehicle from the list and possibly from muck DB)
    ( Do cleanup, show the vehicles, and ask which to delete )
    listVehicles
  
    anyVehicles? if
        BEGIN
            blankline
            me @ "Enter shortname of vehicle to delete, or '.' to abort >>" notify
            do_read strip tolower
            (In case they abort )
            dup "." strcmp not if
                pop
                me @ "Aborted delete." notify
                exit
            then
  
            ( Nothing entered! )
            dup strlen not if
                pop
                continue
            then
 
            ( Valid? )
            dup securityCheck if
                ( If manually added, offer to remove the entry )
                dup me @ "/_prefs/vehicles/" rot strcat getprop
                "/_prefs/vehicle/manual_add" getpropstr tolower "yes" strcmp not if
                    blankline
                    me @ "This vehicle was manually added, so only the entry may be removed." notify
                    me @ "The vehicle itself cannot be @recycled using this program." notify
                    me @ "Remove vehicle from list (YES/NO)??" notify
                    do_read strip tolower
                    ( If yes, then do it )
                    "yes" strcmp not if
                        blankline
                        "Removing vehicle from list..." sysMessage
                        dup me @ "/_prefs/vehicles/" rot strcat getprop "/_prefs/vehicle" remove_prop
                        me @ "/_prefs/vehicles/" rot strcat remove_prop
                        "Done." sysMessage
                        exit
                    else
                        pop
                        blankline
                        me @ "Aborting removal from list." notify
                        exit
                    then
                else
                    ( else vehicle was made by program, check if it's been modified)
                    shortName !
                    me @ "/_prefs/vehicles/" shortName @ strcat getprop vehDB !
                    ( Is it 1 or 2 room? )
                    vehDB @ "/_prefs/vehicle/airlock" getprop ok? not if
                        ( 1 room )
                        ( Object will have one action to cockpit )
                        vehDB @ dup dup linkedExits 0 = swap 1 = and rot rot
                            "/_prefs/vehicle/cockpit" getprop exitToThere
                        and not if
                            0
                        else
                            (Cockpit will have three actions linked to progs)
                            vehDB @ "/_prefs/vehicle/cockpit" getprop linkedExits
                            3 = swap 0 = and not if
                                0
                            else
                                1
                            then
                        then
                    else
                        ( 2 rooms )
                        ( Object will have one action to airlock )
                        vehDB @ dup dup linkedExits 0 = swap 1 = and rot rot
                            "/_prefs/vehicle/airlock" getprop exitToThere
                        and not if
                            0
                        else
                            (Cockpit will have two actions linked to progs and 1 to room)
                            vehDB @ dup dup "/_prefs/vehicle/cockpit" getprop linkedExits 2 = swap 1 = and
                            rot rot "/_prefs/vehicle/cockpit" getprop swap "/_prefs/vehicle/airlock" getprop
                                exitToThere
                            and not if
                                0
                            else
                                (Airlock will have one action linked to room and one to program)
                                vehDB @ dup dup "/_prefs/vehicle/airlock" getprop linkedExits 1 = swap 1 = and
                                rot rot "/_prefs/vehicle/airlock" getprop swap "/_prefs/vehicle/cockpit" getprop
                                    exitToThere
                                and not if
                                    0
                                else
                                    1
                                then
                            then
                        then
                    then
                then
            else
                pop
                me @ "Invalid vehicle specified." notify
                blankline
                listVehicles
                continue
            then
 
            ( Above modify-check code leaves 1 on stack for 'original', and a 0 for 'modified' )
            not if
                ( If modified, offer to delete entry only and explain why )
                blankline
                me @ "This vehicle has likely been modifed, so only the entry may be removed." notify
                me @ "The vehicle itself cannot be @recycled using this program." notify
                blankline
                me @ "The objects that WOULD be recycled are as follows, though there may be" notify
                me @ "more or less than those listed that are part of the vehicle:" notify

                ( Populate so we can display the info )
                vehDB @ "/_prefs/vehicle/env" getprop envDB !
                vehDB @ "/_prefs/vehicle/airlock" getprop airlockDB !
                vehDB @ "/_prefs/vehicle/cockpit" getprop cockpitDB !
  
                ( Junk environment room if we don't own it - don't need to see it )
                envDB @ ok? if
                    envDB @ owner me @ dbcmp not if
                        -1 dbref envDB !
                    then
                then
                printVehicleRooms
                blankline

                me @ "Remove vehicle from list (YES/NO)??" notify
                do_read strip tolower
                ( If yes, then do it )
                "yes" strcmp not if
                    blankline
                    "Removing vehicle from list..." sysMessage
                    vehDB @ "/_prefs/vehicle" remove_prop
                    me @ "/_prefs/vehicles/" shortName @ strcat remove_prop
                    "Done." sysMessage
                    exit
                else
                    blankline
                    me @ "Aborting removal from list." notify
                    exit
                then
            else
                ( We can do a deletion!  populate the vars in preparation )
                vehDB @ "/_prefs/vehicle/env" getprop envDB !
                vehDB @ "/_prefs/vehicle/airlock" getprop airlockDB !
                vehDB @ "/_prefs/vehicle/cockpit" getprop cockpitDB !
        
                ( Else, check environment room )
                blankline
                ( If room is OWNED by player, print warning and ask about deletion )
                envDB @ owner me @ dbcmp if
                    me @ "You own the environment room for the vehicle.  The room" notify
                    me @ "is: " envDB @ unparseobj strcat notify
                    me @ "Would you like to delete the environment room with the vehicle? If" notify
                    me @ "YES, the room will be deleted.  If NO, the room will be left alone." notify
                    me @ "Enter NO if you have other vehicles or areas using the enviroment room!" notify
                    blankline
                    me @ "Delete environment room (YES/NO)??" notify
                    do_read strip tolower
                    "yes" strcmp not if
                        me @ "Environment room will be deleted." notify
                    else
                        me @ "Environment room will be kept." notify
                        -1 dbref envDB !
                    then
                else
                    ( If room not owned by player, say so, give db #, and do nothing )
                    me @ "The environment room for the vehicle is not owned by you, so it" notify
                    me @ "cannot be deleted by this program.  For reference, the environment" notify
                    me @ "room is: " envDB @ unparseobj strcat notify
                    -1 dbref envDB !
                then
        
                ( Confirm )
                blankline
                me @ "Are you SURE you want to delete the following objects?" notify
                printVehicleRooms
                blankline
        
                me @ "Delete Vehicle (YES/NO)??" notify
                do_read strip tolower
                "yes" strcmp not if
                    ( Do the recycle! )
                    vehDB @ ok? if
                        me @ vehDB @ owner dbcmp if
                            vehDB @ recycle
                            "Recycled vehicle object." sysMessage
                            ( Refund pennies )
                            me @
                            "exit_cost" sysparm atoi
                            "link_cost" sysparm atoi
                            "object_cost" sysparm atoi
                            + + addpennies
                        else
                            "Could not recycle vehicle object!" sysMessage
                        then
                    then
    
                    cockpitDB @ ok? if
                        me @ cockpitDB @ owner dbcmp if
                            cockpitDB @ recycle
                            "Recycled cockpit room." sysMessage
                            ( Refund pennies )
                            me @
                            "exit_cost" sysparm atoi 3 *
                            "link_cost" sysparm atoi 3 *
                            "room_cost" sysparm atoi
                            + + addpennies
                        else
                            "Could not recycle cockpit room!" sysMessage
                        then
                    then
    
                    airlockDB @ ok? if
                        me @ airlockDB @ owner dbcmp if
                            airlockDB @ recycle
                            "Recycled airlock room." sysMessage
                            ( Refund pennies )
                            me @
                            "exit_cost" sysparm atoi 2 *
                            "link_cost" sysparm atoi 2 *
                            "room_cost" sysparm atoi
                            + + addpennies
                        else
                            "Could not recycle airlock room!" sysMessage
                        then
                    then
    
                    envDB @ ok? if
                        me @ envDB @ owner dbcmp if
                            envDB @ recycle
                            "Recycled environment room." sysMessage
                            ( Refund pennies )
                            me @
                            "room_cost" sysparm atoi
                            addpennies
                        else
                            "Could not recycle environment room!" sysMessage
                        then
                    then
    
                    cleanList
    
                    blankline
                    me @ "Vehicle has been recycled." notify
                    exit
                else
                    me @ "Aborted @recycling vehicle." notify exit
                then
            then
        REPEAT
    then
;
  
: addVehicle ( -- adds user created vehicle to list, purely as a convieniance )
    cleanList
    BEGIN
        blankline
        me @ "[1/3]  Enter a short name (no spaces) used to identify the vehicle" notify
        me @ "       while in this program or a '.' to abort." notify
        me @ "Short Name>>" notify
        do_read strip
        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Adding of vehicle aborted." notify
            exit
        then
        ( Make sure the shortname IS actually short! )
        dup strlen 9 > if
            pop
            me @ "Shortnames must be 9 characters or less.  Try again." notify
            continue
        then
        (Don't allow spaces)
        dup " " instr if
            pop
            me @ "Sorry, spaces are not allowed in the shortname. Try again."  notify
            continue
        then
        (No / _ . *)
        dup "*[./_\*]*" smatch if
            pop
            me @ "Sorry, the / _ . * characters cannot be used in the shortname." notify
            continue
        then
        ( Check for shortname already used )
        dup me @ swap "/_prefs/vehicles/" swap strcat getprop dbref? if
            pop 
            me @ "This shortname is already in use.  Try another one." notify
            continue
        then
        ( Gauntlet passed! )
        dup shortName ! 
        me @ "Vehicle shortname is: " rot strcat notify
        break
    REPEAT
  
    BEGIN
        blankline
        me @ "[2/3] Enter the dbref (starting with #) or name of the vehicle" notify
        me @ "      object (if it is close to you) or a '.' to abort.  The vehicle" notify
        me @ "       must already exist.  Examples: #1234, MyShip" notify
        me @ "Vehicle Object>>" notify
  
        do_read strip

        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Addition of vehicle aborted." notify
            exit
        then
        ( Try and get the dbref.  It must be a room AND abode )
        match dup thing? if
            dup me @ swap owner dbcmp if
                dup vehDB !
                me @ "Vehicle object set to "
                    rot dup name rot swap strcat swap intostr "(#" swap strcat strcat ")." strcat
                notify
                break
            else
                pop
                me @ "You must control the vehicle object!" notify
                continue
            then
        else
            pop
            me @ "You did not specify a valid object!" notify
            continue
        then
    REPEAT
 
    BEGIN
        blankline
        me @ "[3/3] Enter the dbref (starting with #) of the vehicle's cockpit" notify
        me @ "      or a '.' to abort.  The cockpit must already exist." notify
        me @ "      Example: #1234" notify
        me @ "Cockpit Room>>" notify
  
        do_read strip

        ( Check for nothing entered)
        dup strlen 0 = if
            pop
            me @ "You did not enter anything!" notify
            continue
        then
        ( Check for abort )
        dup "." strcmp not if
            pop
            me @ "Addition of vehicle aborted." notify
            exit
        then
        ( Try and get the dbref.  It must be a room AND abode )
        match dup room? if
            dup me @ swap owner dbcmp if
                dup cockpitDB !
                me @ "Vehicle cockpit set to "
                    rot dup name rot swap strcat swap intostr "(#" swap strcat strcat ")." strcat
                notify
                break
            else
                pop
                me @ "You must control the vehicle cockpit!" notify
                continue
            then
        else
            pop
            me @ "You did not specify a valid room!" notify
            continue
        then
    REPEAT
  
    blankline
    me @ "Adding vehicle to list..." notify
    me @ "/_prefs/vehicles/" shortName @ strcat vehDB @ setprop
    vehDB @ "/_prefs/vehicle/shortName" shortName @ setprop
    vehDB @ "/_prefs/vehicle/cockpit" cockpitDB @ setprop
    vehDB @ "/_prefs/vehicle/manual_add" "yes" setprop
    cockpitDB @ "/_prefs/vehicle/shortName" shortName @ setprop
    me @ "Vehicle has been added to the vehicle list." notify
;
  
: mainMenu  ( --   The main menu - user interface )
    BEGIN
        blankline
        me @ "VehicleHammer Main Menu" notify
        me @ "-----------------------" notify
        blankline
  
        me @ "  1. Create a Vehicle" notify
        me @ "  2. List Vehicles You Own" notify
        me @ "  3. Teleport to Vehicle Cockpit" notify
        me @ "  4. Recycle Vehicle" notify
        me @ "  5. Add Vehicle to List Manually" notify
        blankline
        me @ "Enter NUMBER or 'Q' to Quit >>" notify
        do_read strip
        blankline
  
        ( Quit )
        dup "Q" stringcmp not if
            pop
            "Program ended." sysMessage exit
        then
  
        (Everything else is numbers )
        atoi
        (Create a vehicle)
        dup 1 = if
            pop
            blankline
            me @ "CREATE A VEHICLE" notify
            me @ "----------------" notify
            askQuestions
            swap dup 1 = if pop makeOne continue then
            2 = if makeTwo continue then
            blankline
            pop
            pause
            continue 
        then
        (List vehicles)
        dup 2 = if
            pop
            blankline
            me @ "VEHICLE LISTING" notify
            me @ "---------------" notify
            blankline
            listVehicles
            blankline
            pause
            blankline
            continue
        then
        dup 3 = if
            pop
            blankline
            me @ "TELEPORT TO VEHICLE COCKPIT" notify
            me @ "---------------------------" notify
            blankline
            teleportToVehicle
            blankline
            pause
            continue
        then
        dup 4 = if
            pop
            blankline
            me @ "RECYCLE VEHICLE" notify
            me @ "---------------" notify
            blankline
            deleteVehicle
            blankline
            pause
            continue
        then
        5 = if
            blankline
            me @ "ADD VEHICLE TO LIST MANUALLY" notify
            me @ "----------------------------" notify
            blankline
            me @ "Please have the DB#s of the vehicle object and cockpit room ready in advance!" notify
            blankline
            addVehicle
            pause
            continue
        then
  
    me @ "Invalid option." notify blankline
    REPEAT
;
  
: immersiveCheck ( -- i  returns 1 if vehicle still OK, 0 otherwise.  Outputs errors to user. )
    ( Is program configured right? )
    actionDB @ "/_prefs/vehicle/object" getprop atoi dbref dup thing? not if
        pop 
        "Immersive mode ERROR: Program not configured." sysMessage
        0 exit
    else
        vehDB !
    then
 
    ( Make sure the vehicle is forceable )
    vehDB @ "Xforcible" flag? not if
        "Immersive mode ERROR: Vehicle not forcible (X flag)." sysMessage
        0 exit
    then
 
    ( Make sure the vehicle is not dark )
    vehDB @ "Dark" flag? if
        "Immersive mode ERROR: Vehicle is set Dark." sysMessage
        0 exit
    then
 
    ( Verify they are all owned by the SAME person.  owned, not controlled )
    actionDB @ owner tempDB !
    cockpitDB @ owner tempDB @ dbcmp
    vehDB @ owner tempDB @ dbcmp
    and not if
        "Immersive mode ERROR: Action, cockpit, and vehicle object have different owners." sysMessage
        0 exit
    then
 
    ( Verify action is @locked.  Doesn't matter to who )
    actionDB @ getlockstr "*UNLOCKED*" stringcmp not if
        "Immersive mode ERROR: Action is unlocked." sysMessage
        0 exit
    then
 
    ( Finally, make sure vehicle is @flocked to it's owner by testing the lock )
    vehDB @ "/@/flk" getprop dup lock? not if
        pop
        "Immersive mode ERROR: Vehicle is not @flock-ed to its owner." sysMessage
        0 exit
    then
 
    vehDB @ owner swap testlock not if
        "Immersive mode ERROR: Vehicle is @flock-ed but not to its owner!" sysMessage
        0 exit
    then
 
    (We're here, so everything is OK)
    1
;
    
: immersiveMode ( --  Sends everything typed as a @force to an object)
 
    trig dup actionDB !
    location cockpitDB !
 
    immersiveCheck not if exit then
  
    ( Gauntlet passed!)
    ( Explain how this mode works )
    blankline
    blankline
    me @ "You are entering immersive mode.  Everything you type in this mode will" notify
    me @ "be sent to the vehicle directly. This means you do not need to prepend" notify
    me @ "your commands with anything.  'say hi' will make the vehicle say hello," notify
    me @ "for instance.  Prepend commands destined for yourself with a ','.  For an" notify
    me @ "example: ',page person=See my vehicle?' will make yourself page the message." notify
    blankline
    me @ " **** To exit this mode, type ',quit'. ****" notify
    blankline
    me @ "### Immersive mode has started." notify
    blankline
  
    ( Main loop.  read, parse, force, repeat )
    BEGIN
        read
  
        ( This has to be checked as the vehicle might change during runtime )
        immersiveCheck not if exit then
  
        me @ location cockpitDB @ dbcmp not if
            pop
            me @ "### You are out of the cockpit.  Immersive mode has ended." notify
            break
        then
  
        dup

        ( Store the location of the vehicle.  If it changes rooms, we can
          autolook )
        vehDB @ location tempDB !
  
        "," instr 1 = if
            1 strcut swap pop dup
            strip "quit" stringcmp not if
                pop
                me @ "### Immersive mode has ended." notify
                break
            else
               dup strlen 1 > if
                   me @ swap force
               else
                   pop
               then
            then
        else
            vehDB @ swap force
        then

        ( if they changed location, autolook for them )
        vehDB @ location tempDB @ dbcmp not if
            vehDB @ "autolook_cmd" sysparm force
        then
    REPEAT
;
  
: doHelp ( --  Displays command line help )
    blankline
    me @ "VehicleHammer v" VERSIONSTR strcat " by Morticon@SpinDizzy 2010  (Idea by Argon@SpinDizzy)" strcat notify
    blankline
    me @ "This tool allows for easy creation and management of advanced vehicles." notify
    me @ "Entering no arguments starts the program normally, presenting a menu" notify
    me @ "of options.  You may use \" to say and : to pose while in the program." notify
    blankline
    me @ "Command line arguments:" notify
    me @ "  #help         -  This screen" notify
    me @ "  #list         -  List vehicles you own" notify
    me @ "  #teleport veh -  Teleports to cockpit of vehicle with" notify
    me @ "                     shortname 'veh'" notify
    blankline
;
  
: parseCommands  (s --   Parses command line and does requested action )
    strip tolower
    ( #help )
    dup "#h" instr 1 = if
        pop doHelp exit
    then
  
    ( #list )
    dup "#l" instr 1 = if
        pop 
        blankline
        me @ "Vehicle Listing:" notify
        blankline
        listVehicles blankline exit
    then
  
    ( #teleport )
    dup "#t" instr 1 = if
        ( Get rid of #t[eleport], if syntax is valid )
        " " explode 2 = not if doHelp exit then
        pop
        ( Now, get the vehicle name, and try to teleport! )
        strip doTeleport exit
    then

    ( Catch all - show #help )
    pop doHelp exit
;
  
: dispatcher
    "me" match me !
  
    strip

    ( Check setup )
    prog "indoorenv" getpropstr atoi dbref dup room? if "Abode" flag? not if
            "Prop 'indoorenv' on program not set to valid environment room.  Aborted." sysMessage
            exit
        then
    else
        "Prop 'indoorenv' on program not set to valid environment room.  Aborted." sysMessage
        exit        
    then
 
    prog "outprog" getpropstr atoi dbref dup program? if "Link_ok" flag? not if
            "Prop 'outprog' on program not set to valid program.  Aborted." sysMessage
            exit
        then
    else
        "Prop 'outprog' on program not set to valid program.  Aborted." sysMessage
        exit
    then
 
    prog "driveprog" getpropstr atoi dbref dup program? if "Link_ok" flag? not if
            "Prop 'driveprog' on program not set to valid program.  Aborted." sysMessage
            exit
        then
    else
        "Prop 'driveprog' on program not set to valid program.  Aborted." sysMessage
        exit
    then
 
    prog "scanprog" getpropstr atoi dbref dup program? if "Link_ok" flag? not if
            "Prop 'scanprog' on program not set to valid program.  Aborted." sysMessage
            exit
        then
    else
        "Prop 'scanprog' on program not set to valid program.  Aborted." sysMessage
        exit
    then
 
    prog "listenprog" getpropstr atoi dbref dup program? if "Link_ok" flag? not if
            "Prop 'listenprog' on program not set to valid program.  Aborted." sysMessage
            exit
        then
    else
        "Prop 'listenprog' on program not set to valid program.  Aborted." sysMessage
        exit
    then

    prog "lookprog" getpropstr atoi dbref dup program? if "Link_ok" flag? not if
            "Prop 'lookprog' on program not set to valid program.  Aborted." sysMessage
            exit
        then
    else
        "Prop 'lookprog' on program not set to valid program.  Aborted." sysMessage
        exit
    then

    (Zombie check)
    me @ player? if
        ( Guest check )
        me @ "/@guest" getpropstr strlen not if
            ( if this action is actually to enter immersive mode, do that instead )
            trig "/_prefs/vehicle/immersive" getpropstr "yes" stringcmp not if
                pop
                immersiveMode
            else
                ( If they want to use the program proper, action must be )
                ( owned by a wiz )
                trig owner "Truewizard" flag? not if
                    "A wizard must own the global action." sysMessage
                else
                    ( Other command line arguments go here, if any.  Else, to the main menu! )
                    dup strlen if
                        parseCommands
                    else
                        pop
                        ( me @ "Current Depth: " depth intostr strcat notify )
    
                        mainMenu
    
                        ( me @ "New Depth: " depth intostr strcat notify )
                    then
                then
            then
        else
            me @ "Sorry, guests cannot use this command." notify
        then
    else
        ( Puppets can only do immersive mode )
        trig "/_prefs/vehicle/immersive" getpropstr "yes" stringcmp not if
            pop
            immersiveMode
        else
            "Sorry, only players may use this command." sysMessage
        then
    then
;
 
.
c
q
@set vehiclehammer.muf=3
@set vehiclehammer.muf=W
@set vehiclehammer.muf=L
@set vehiclehammer.muf=!D
(@set vehiclehammer.muf=indoorenv:116
(@set vehiclehammer.muf=outprog:77
(@set vehiclehammer.muf=driveprog:77
(@set vehiclehammer.muf=scanprog:77
(@set vehiclehammer.muf=listenprog:77
(@set vehiclehammer.muf=lookprog:77
(SD Specific)
(@set vehiclehammer.muf=indoorenv:62
(@set vehiclehammer.muf=outprog:2851
(@set vehiclehammer.muf=driveprog:6489
(@set vehiclehammer.muf=scanprog:5566
(@set vehiclehammer.muf=listenprog:6860
(@set vehiclehammer.muf=lookprog:8
