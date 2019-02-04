( /quote -dsend 'e:\spindizzy\muf\mupl105.muf )
@prog mupl.muf
1 999 d
i


( MuckUserProximityLocator v1.05 )
(To install:  Make an action, link it to this program )

$include $lib/strings
lvar user
lvar location
lvar cleanCounter
lvar locCleanCounter
lvar locationCounter
lvar currentUser
lvar currentLocation
lvar temp
lvar cmdline

$def MUPLver 105

: clearstack ( -- less items on stack )
(Keeps the stack from accidently getting too big)
        BEGIN
         depth 1 > if pop then
         depth 2 > not
        UNTIL
        exit
;

: blankline ( -- )
        me @ " " notify exit
;

: playerName ( i -- s)
( Given an integer or dbref, returns a string with the name of the player, or returns '*Toaded Player*' if needed)
        dup dbref? not if dbref then
        dup player? if name else pop "*Toaded Player*" then
        exit
;

: anyUsers? ( -- i )
( Tells if there is anyone in the database. )
        trig "/users/" nextprop dup temp !
        "" stringcmp
        exit
;

: inDB? ( i -- i )
( Given an integer of the player's dbref, returns 1 if they are in the database )
        trig "/users/" rot intostr strcat getpropstr "" stringcmp
        exit
;

: addMsg ( -- )
( When ran, if calling player is not in the DB, it prints a friendly reminder )
        me @ int inDB? not if me @ "The MUPL database would grow if you added yourself to it.  Hint hint." notify then
        exit
;

: lockDB ( s -- )
( Marks the DB as locked with string s as the reason. )
( The DB shall be locked for the following reasons: Removing a user and cleanup of the DB.  This is to prevent any wierdness that might occur while searching during these operations )
        trig "/locked" rot setprop
        1 sleep
        exit
;

: unlockDB ( -- )
( Marks the DB as unlocked )
        trig "/locked" remove_prop
        exit
;

: checkLocation ( s -- i )
( s is the abbreviation or name of a place.  If it's no longer in use, delete it from the list.  Return 1 if deleted, 0 if not )
        currentLocation !
        anyUsers? if
          trig "/locations/" currentLocation @ strcat currentLocation @ setprop
          1 temp !
          trig "/users/" nextprop locCleanCounter !
          ( Check all users.  If no one uses that location, then delete the location )
          BEGIN
           trig locCleanCounter @ getpropstr currentLocation @ stringcmp not if 0 temp ! then
           trig locCleanCounter @  nextprop dup locCleanCounter !
           "" stringcmp not temp @ not or
          UNTIL else 1 temp ! then
        
          temp @ if trig "/locations/" currentLocation @ strcat remove_prop 1 else 0 then
        exit
;

: cleanDB ( -- )
( Cleans the DB up.  Locks DB during cleanup )
( Also doubles as the init for a new action with no props set yet )
        0 user !
        me @ "Backgrounding and locking DB..." notify
        "cleanDB" lockDB
        background

        ( Upgrade code is here )
        trig "/version" getpropval MUPLver < if
                me @ "Running upgrade code" notify
                trig "/users/zzzEND" remove_prop
                trig "/locations/zzzEND" remove_prop
        then
        ( End upgrade code )

        me @ "Cleaning MUPL DB..." notify
        trig "/version" MUPLver setprop

        ( Cleans up the users, which means removing any @toaded ones. Does NOT fiddle with locations )
        me @ "Cleaning MUPL DB: Users" notify
        anyUsers? if
        ( Go through all the users.  If a user is marked as @toaded, remove them from the DB )
        trig "/users/" nextprop cleanCounter !
        BEGIN
         cleanCounter @ strip 7 strcut swap pop atoi playerName "*Toaded Player*" stringcmp not if 
                user @ 1 + user !
                trig cleanCounter @ remove_prop
                "/users/" cleanCounter ! then
         trig cleanCounter @  nextprop dup cleanCounter !
         "" stringcmp not
        UNTIL then

        ( After user cleanup, any unused locations?  Find out and remove them.  Do this by calling checkLocation on each location )
        me @ "Cleaning MUPL DB: Locations" notify
        anyUsers? if
        trig "/locations/" nextprop cleanCounter !
        BEGIN
         trig cleanCounter @ getpropstr currentLocation !
         currentLocation @ checkLocation if "/locations/" cleanCounter ! then
         trig cleanCounter @  nextprop dup cleanCounter !
         "" stringcmp not
        UNTIL else trig "/locations" remove_prop then

        unlockDB
        me @ "Done cleaning MUPL DB.  Removed " user @ intostr strcat " user entries." strcat notify

        exit
;

: addUser ( i s -- )
( Adds a user to the DB.  i is the dbref as an integer, s is the location )
        location ! user !

        user @ inDB? if me @ "You are already in the MUPL database.  If you have changed locations, please #remove and then #add yourself again." notify exit then
        trig "/locations/" location @ strcat location @ setprop
        trig "/users/" user @ intostr strcat location @ setprop
        me @ "You have been added to the MUPL database." notify
        exit
;

: removeUser ( i -- )
( Removes user integer i from the db )
        user !
        user @ inDB? not if me @ "You are not currently in the MUPL database." notify exit then
        me @ "Please wait..." notify
        "removeUser" lockDB
        trig "/users/" user @ intostr strcat getpropstr location !
        trig "/users/" user @ intostr strcat remove_prop
        ( Is the location being used anymore?  If not, remove )
        location @ checkLocation pop
        unlockDB
        me @ "You have been removed from the MUPL database." notify
        exit
;

: listStats ( -- )
( Prints out stats.  At the moment the number of locations and number of users in the database )
        0 user ! 0 location !

        ( Count the number of users )
        trig "/users/" nextprop currentUser !
        anyUsers? if
        BEGIN
         user @ 1 + user !
         trig currentUser @  nextprop dup currentUser !
         "" stringcmp not
        UNTIL then

        ( Count the number of locations )
        trig "/locations/" nextprop dup currentLocation !
        "" stringcmp if
        BEGIN
         location @ 1 + location !
         trig currentLocation @  nextprop dup currentLocation !
         "" stringcmp not
        UNTIL else 0 user ! 0 location ! then

        ( Print out what it found )
        me @ "There are currently " user @ intostr strcat " users and " strcat location @ intostr strcat " locations in the MUPL database." strcat notify
        addMsg
        exit
;

: listLocations ( -- )
( Prints out currently entered locations into the DB )

        blankline
        me @ "The following are locations entered into the MUPL database that have users listed in them:" notify
        blankline

        ( Run through the locations, printing three on each line. )
        trig "/locations/" nextprop currentLocation !
        anyUsers? if
        0 temp !
        "" location !
        BEGIN
         ( If three locations are in the var 'location', then print them out and reset the temp counter )
         3 temp @ = if me @ location @ notify 0 temp ! "" location ! then
         temp @ 1 + temp !

         ( This appends each new location to the variable that is to be printed )
         location @ trig currentLocation @ getpropstr 25 strcut pop 26 STRleft strcat location !

         trig currentLocation @  nextprop dup currentLocation !
         "" stringcmp not
        UNTIL
        temp @ if me @ location @ notify then then

        blankline addMsg me @ "Done." notify
        exit
;

: listUserLocation ( s -- )
( Prints out users and their pinfo location entry of a location )
        toupper location !
        ( Location header )
        blankline me @ "The following users are in " location @ strcat ":" strcat notify
        blankline me @ "Name                   Pinfo 'Address' Entry" notify
        me @ "-----------------------------------------------------------------------------" notify
        ( Run through the users, listing only those who live in the var 'location' )
        trig "/users/" nextprop currentUser !
        anyUsers? if
        BEGIN
         trig currentUser @ getpropstr dup currentLocation ! location @ stringcmp not if
                ( If they match, print their name and their pinfo 'address' entry )
                 me @
                   currentUser @ 7 strcut swap pop atoi playerName 19 strcut pop 20 STRleft " | " strcat currentUser @ 7 strcut swap pop atoi dbref dup ok? if "/_ui/a" getpropstr else pop "" then 54 strcut pop 55 STRleft strcat
                 notify
         then
         trig currentUser @  nextprop dup currentUser !
         "" stringcmp not
        UNTIL then

        blankline addMsg me @ "Done." notify
        exit
;

: helptoo ( -- )
        me @ "MUPL (Muck User Proximity Locator) v1.05 by Kulan of Spindizzy.   2004" notify blankline
        me @ "Summary:  This command allows you to hopefully find a muck user living in your (real life) general area." notify
        me @ "#HELP2:" notify blankline
        me @ "   This program sorta works like the Internet Furry Proximity Locator" notify
        me @ "( http://ifpl.cattech.org/ ) except that it's limited by a vague location, in" notify
        me @ "this case a state or country.  Since it also hooks into Jordan Greywolf's" notify
        me @ "PLAYER-INFO, it may give you a more specific location depending on the player." notify
        blankline
        me @ "   The program is pretty self explanatory, except for when it comes to the" notify
        me @ "location choice (ie: #add ).  Within the US, use the state's two letter" notify
        me @ "abbreviation (example: 'mupl #add FL' for Florida).  For those in other" notify
        me @ "countries, use the country's FULL name (example: 'mupl #add Germany').  Do NOT" notify
        me @ "use spaces.  Try using _ instead." notify
        blankline
        me @ "   On mucks that do not have the PLAYER-INFO program mentioned, you can set" notify
        me @ "the '/_ui/a' property on yourself and put in your city and state" notify
        me @ "(example:  '@set me=/_ui/a:Howey-in-the-hills, Florida')." notify
        exit
;

: cmd-mupl ( s -- )
        "me" match me !
        strip cmdline !
        background
        ( If the DB has not been #clean ed  initially, then go ahead an do that automatically )
        trig "/version" getpropval MUPLver = not if me @ "Running initial MUPL set up..." notify 'cleanDB jmp exit then

        ( If the DB is locked, retry once and then quit if no success )
        trig "/locked" getpropstr dup "" stringcmp if
                me @ "MUPL DATABASE LOCKED: " rot strcat ".    Retrying..." strcat notify
                3 sleep
                trig "/locked" getpropstr "" stringcmp if me @ "Database still locked!  Please try again in a few moments." notify exit then
        then

        (Zombie check)
        me @ player? if
        cmdline @ " " explode 2 = if "#add" stringcmp not if toupper me @ int swap 'addUser jmp exit then then
        clearstack
        cmdline @ " " explode 2 = if "#list" stringcmp not if toupper 'listUserLocation jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#locations" stringcmp not if 'listLocations jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#remove" stringcmp not if me @ int 'removeUser jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#stats" stringcmp not if me @ int 'listStats jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#clean" stringcmp not me @ trig controls and if me @ int 'cleanDB jmp exit then then
        clearstack
        cmdline @ " " explode pop "#help2" stringcmp not if me @ int 'helptoo jmp exit then

                blankline
                me @ "MUPL (Muck User Proximity Locator) v1.05 by Kulan of Spindizzy.   2004" notify blankline
                me @ "Summary:  This command allows you to hopefully find a muck user living in your (real life) general area." notify
                me @ "#HELP:" notify
                me @ "   #add <location>    : Adds your player as living in a real life <location>." notify
                me @ "                          PLEASE see #help2 for more info!" notify
                me @ "   #remove            : Removes yourself from the database." notify
                me @ "   #locations         : Lists locations in the database with players in them." notify
                me @ "   #list <location>   : Lists the users that reside in <location>." notify
                me @ "   #stats             : Shows the database statistics." notify
                me @ "   #clean             : Cleans the database up, removing @toaded users (owner" notify
                me @ "                          only)." notify
                me @ "   #help              : This screen." notify
                me @ "   #help2             : Further information.  It is highly recommended you" notify
                me @ "                          read this!" notify
        exit
        then
        me @ "Sorry, only players can run this program." notify
        exit
;
.
c
q
@set mupl.muf=3
@set mupl.muf=W
@set mupl.muf=L

