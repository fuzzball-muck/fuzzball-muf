( /quote -dsend 'e:\spindizzy\muf\homefinder104.muf )
@prog homefinder.muf
1 999 d
i

( HomeFinder v1.04 )
(To install:  Make an action, link it to this program )

$def HFver 104

$include $lib/strings
lvar home
lvar theme
lvar currentHome
lvar currentTheme
lvar cleanCounter
lvar themeCleanCounter
lvar temp
lvar cmdline

lvar addTheme
lvar addOccupancy
lvar addDirections
lvar addComment
lvar addName
lvar addCreation

: clearstack ( -- less items on stack )
(Keeps the stack from accidently getting too big)
        BEGIN
         depth 1 > if pop then
         depth 2 > not
        UNTIL
        exit
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
        "<In Homefinder> " me @ name strcat " " strcat swap strcat .tell
      else
        dup me @ swap "<In Homefinder> You " me @ "_say/def/say" getpropstr 
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

: blankline ( -- )
        me @ " " notify exit
;

: aborted ( -- )
        blankline me @ "Program aborted.  Any unsaved information was lost." notify blankline
;

: playerName ( i -- s)
( Given an integer or dbref, returns a string with the name of the player, or returns '*Toaded Player*' if needed)
        dup dbref? not if dbref then
        dup player? if name else pop "*Toaded Player*" then
        exit
;

: anyHomes? ( -- i )
( Tells if there is any homes in the database )
        trig "/homes/" nextprop dup temp !
        "" stringcmp
        exit
;

: inDB? ( i -- i )
( Given an integer of the room's dbref, returns 1 if they are in the database )
        trig "/homes/" rot intostr strcat getpropstr "" stringcmp
        exit
;

: lockDB ( s -- )
( Marks the DB as locked with string s as the reason. )
        trig "/locked" rot setprop
        trig "/lockuser" me @ playerName setprop
        1 sleep
        exit
;

: unlockDB ( -- )
( Marks the DB as unlocked )
        trig "/locked" remove_prop
        trig "/lockuser" remove_prop
        exit
;

: checkTheme ( s -- i )
( s is the name of a theme.  If it's no longer in use, delete it from the list.  Return 1 if deleted, 0 if kept )
        currentTheme !
        anyHomes? if
          trig "/themes/" currentTheme @ strcat currentTheme @ setprop
          1 temp !
          trig "/homes/" nextprop themeCleanCounter !
          ( Check all homes.  If none use that theme, then delete the theme )
          BEGIN
           trig themeCleanCounter @ getpropstr currentTheme @ stringcmp not if 0 temp ! then
           trig themeCleanCounter @  nextprop themeCleanCounter !
           themeCleanCounter @ "" stringcmp not temp @ not or
          UNTIL else 1 temp ! then
        
          temp @ if trig "/themes/" currentTheme @ strcat remove_prop 1 else 0 then
        exit
;

: cleanDB ( -- )
( Cleans the DB up.  Locks DB during cleanup )
( Also doubles as the init for a new action with no props set yet )
        0 home !
        me @ "Backgrounding and locking DB..." notify
        background
        "cleanDB" lockDB
        me @ "Cleaning HomeFinder DB..." notify

        ( Upgrade code is here )
        trig "/version" getpropval 103 < if
                me @ "Running upgrade code" notify
                trig "/homes/zzzEND" remove_prop
                trig "/themes/zzzEND" remove_prop
        then
        ( End upgrade code )

        trig "/version" HFver setprop

        ( Cleans up the homes, which means removing any @recced ones. Does NOT fiddle with themes )
        me @ "Cleaning HomeFinder DB: Homes" notify
        anyHomes? if
        ( Go through all the homes.  If an home is not a room or does not have a version string, remove it from the DB )
        trig "/homes/" nextprop cleanCounter !
        BEGIN
         cleanCounter @ strip 7 strcut swap pop atoi dbref dup ok? if "/homefinder/version" getpropval not else 1 then if 
                home @ 1 + home !
                trig cleanCounter @ remove_prop
                "/homes/" cleanCounter ! then
         trig cleanCounter @  nextprop cleanCounter !
         cleanCounter @ "" stringcmp not
        UNTIL then

        ( After home cleanup, any unused themes?  Find out and remove them.  Do this by calling checkTheme on each theme )
        me @ "Cleaning HomeFinder DB: Themes" notify
        anyHomes? if
        trig "/themes/" nextprop cleanCounter !
        BEGIN
         trig cleanCounter @ getpropstr currentTheme !
         currentTheme @ checkTheme if "/themes/" cleanCounter ! then
         trig cleanCounter @  nextprop cleanCounter !
         cleanCounter @ "" stringcmp not
        UNTIL else trig "/themes" remove_prop then

        unlockDB
        me @ "Done cleaning HomeFinder DB.  Removed " home @ intostr strcat " homes." strcat notify

        exit
;

: listThemes ( -- )
( Prints out currently entered themes in the DB )

        blankline
        me @ "The following are themes entered into the HomeFinder database that have homes listed in them:" notify
        blankline

        ( Run through the themes, printing three on each line. )
        trig "/themes/" nextprop currentTheme !
        anyHomes? if
        0 temp !
        "" theme !
        BEGIN
         ( If three themes are in the var 'home', then print them out and reset the temp counter )
         3 temp @ = if me @ theme @ notify 0 temp ! "" theme ! then
         temp @ 1 + temp !

         ( This appends each new theme to the variable that is to be printed )
         theme @ trig currentTheme @ getpropstr 25 strcut pop 26 STRleft strcat theme !

         trig currentTheme @  nextprop dup currentTheme !
         "" stringcmp not
        UNTIL
        temp @ if me @ theme @ notify then then

        blankline me @ "Done." notify
;

: addHome ( d -- )
( Adds an home with DB# d to the DB. )
        dup home !

        int inDB? if me @ "This room is already in the HomeFinder database.  If you want to change listing information, please #edit the room" notify exit then

        listThemes
        blankline me @ "Add a home/dwelling area" notify blankline
        me @ "Above are the currently entered themes in the database. You may chose to use" notify
        me @ "a theme from above or make up your own. Use _ or - for a space." notify blankline
        me @ "Enter a theme (or a . to abort at any prompt) >> " notify
        do_read strip toupper " " explode pop dup addTheme ! "." stringcmp not if 'aborted jmp then
        clearstack

        ( If no theme is entered, abort! )
        addTheme @ strlen not if 'aborted jmp then

        blankline me @ "What is the name of the area? >> " notify
        do_read strip dup addName ! "." stringcmp not if 'aborted jmp then

        blankline me @ "Approximately how many people can live in this area? Enter 'unlimited' if it's" notify
        me @ "an apartment-style area and can accomodate any number of people. >>" notify
        do_read strip toupper dup addOccupancy ! "." stringcmp not if 'aborted jmp then

        blankline me @ "How are new rooms created?  Enter 'program' for ones that use a program," notify
        me @ "'page #mail' if it is a manual process, or '@chown' if rooms are already" notify
        me @ "there to take. >>" notify
        do_read strip toupper dup addCreation ! "." stringcmp not if 'aborted jmp then

        blankline me @ "How do you get to this area? Do NOT give a db#.  It will be provided" notify
        me @ "automatically if the room is teleport-able. >>" notify
        do_read strip dup addDirections ! "." stringcmp not if 'aborted jmp then

        blankline me @ "Add any extra comments here (or a space and enter for none) >>" notify
        do_read strip dup addComment ! "." stringcmp not if 'aborted jmp then

        blankline me @ "Adding your listing..." notify
        background

        trig "/locked" getpropstr dup "" stringcmp if
                me @ "HOMEFINDER DATABASE LOCKED BY USER " trig "/lockuser" getpropstr toupper strcat ": " strcat rot strcat ".    Retrying..." strcat notify
                4 sleep
                trig "/locked" getpropstr "" stringcmp if me @ "Database still locked!  Please try again in a few moments." notify exit then
        then

        "addHome" lockDB
        trig "/themes/" addTheme @ strcat addTheme @ setprop
        trig "/homes/" home @ intostr strcat addTheme @ setprop
        unlockDB

        home @ "/homefinder/version" HFver setprop
        home @ "/homefinder/occupancy" addOccupancy @ setprop
        home @ "/homefinder/directions" addDirections @ setprop
        home @ "/homefinder/comment" addComment @ setprop
        home @ "/homefinder/name" addName @ setprop
        home @ "/homefinder/creation" addCreation @ setprop

        me @ "Your area has been added to the HomeFinder database." notify
        exit
;

: removeHome ( i -- )
( Removes home integer i from the db )
        dbref dup home !
        int inDB? not if me @ "This area is not currently in the HomeFinder database." notify exit then
        me @ "Please wait..." notify
        background
        "removeHome" lockDB
        trig "/homes/" home @ intostr strcat getpropstr currentTheme !
        trig "/homes/" home @ intostr strcat remove_prop
        ( Is the theme being used anymore?  If not, remove )
        currentTheme @ checkTheme pop
        unlockDB

        home @ "/homefinder" remove_prop

        me @ "Your area has been removed from the HomeFinder database." notify
        exit
;

: listStats ( -- )
( Prints out stats.  At the moment the number of homes and number of themes in the database )
        0 home ! 0 theme !

        ( Count the number of homes )
        trig "/homes/" nextprop currentHome !
        anyHomes? if
        BEGIN
         home @ 1 + home !
         trig currentHome @  nextprop dup currentHome !
         "" stringcmp not
        UNTIL then

        ( Count the number of themes )
        trig "/themes/" nextprop dup currentTheme !
        "" stringcmp if
        BEGIN
         theme @ 1 + theme !
         trig currentTheme @  nextprop dup currentTheme !
         "" stringcmp not
        UNTIL then

        ( Print out what it found )
        me @ "There are currently " home @ intostr strcat " homes and " strcat theme @ intostr strcat " themes in the HomeFinder database." strcat notify
        exit
;

: listHome ( s -- )
( A way to list what's in the directory. Searchable by theme. )
        toupper theme !
        ( Header )
        blankline me @ "The following homes are in theme " theme @ strcat ":" strcat notify blankline
        ( Run through the homes, listing only those who live in the var 'theme', or #all.  If it is not a room, skip it! The DB should be cleaned eventually )
        trig "/homes/" nextprop currentHome !
        anyHomes? if
        BEGIN
         trig currentHome @ getpropstr theme @ stringcmp not theme @ "#ALL" stringcmp not or currentHome @ 7 strcut swap pop atoi dbref room? and if
        (Check the room extra careful - if it is a room and it doesn't have the version string, skip it)
         currentHome @ 7 strcut swap pop atoi dbref "/homefinder/version" getpropval if

                ( If they match and have valid directory data, print their entry out. )
               me @ "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" notify
               currentHome @ 7 strcut swap pop atoi dbref temp !
               me @  "<> Name: " temp @ "/homefinder/name" getpropstr strcat temp @ dup "link_ok" flag? swap "abode" flag? or if "(#" temp @ int intostr strcat ")" strcat else " " then strcat notify
               me @ 
                  "<> Theme: " trig currentHome @ getpropstr 25 strcut pop 36 STRleft strcat " <> Room Creation: " strcat temp @ "/homefinder/creation" getpropstr 13 strcut pop 14 STRleft strcat 
               notify
               me @ "<> Planned Occupancy: " temp @ "/homefinder/occupancy" getpropstr 24 strcut pop 25 STRleft strcat "<> Owner: " strcat temp @ owner playerName strcat notify
               me @ "<> Directions: " temp @ "/homefinder/directions" getpropstr strcat notify
               me @ "<> Comment: " temp @ "/homefinder/comment" getpropstr strcat notify

         then then
         trig currentHome @  nextprop dup currentHome !
         "" stringcmp not
        UNTIL then
        blankline me @ "Done." notify
;

: editHome ( d -- )
( Edits a home with DB# d )
        dup home !

        int inDB? not if me @ "This area is not in the HomeFinder database.  If you want to add it, please #add the room" notify exit then

        me @ "Loading listing information for area..." notify
        trig "/homes/" home @ intostr strcat getpropstr addTheme !
        home @ "/homefinder/occupancy" getpropstr addOccupancy !
        home @ "/homefinder/directions" getpropstr addDirections !
        home @ "/homefinder/comment" getpropstr addComment !
        home @ "/homefinder/name" getpropstr addName !
        home @ "/homefinder/creation" getpropstr addCreation !

        listThemes

        blankline me @ "Edit a home/dwelling area" notify blankline
        me @ "Above are the currently entered themes in the database. You may chose to use" notify
        me @ "a theme from above or make up your own. Use _ or - for a space." notify blankline
        me @ "Enter a theme (or a . to abort at any prompt) >>" notify
        me @ "A space and enter keeps this data: " addTheme @ strcat notify
        addTheme @ currentTheme !
        do_read toupper dup " " stringcmp not if pop else strip " " explode pop addTheme ! "." stringcmp not if 'aborted jmp then then
        clearstack

        ( If no theme is entered, abort! )
        addTheme @ strlen not if 'aborted jmp then

        blankline me @ "What is the name of the area? >> " notify
        me @ "A space and enter keeps this data: " addName @ strcat notify
        do_read dup dup " " stringcmp not if pop pop else strip addName ! "." stringcmp not if 'aborted jmp then then

        blankline me @ "Approximately how many people can live in this area? Enter 'unlimited' if it's" notify
        me @ "an apartment-style area and can accomodate any number of people. >>" notify
        me @ "A space and enter keeps this data: " addOccupancy @ strcat notify
        do_read toupper dup dup " " stringcmp not if pop pop else strip addOccupancy ! "." stringcmp not if 'aborted jmp then then

        blankline me @ "How are new rooms created?  Enter 'program' for ones that use a program," notify
        me @ "'page #mail' if it is a manual process, or '@chown' if rooms are already" notify
        me @ "there to take. >>" notify
        me @ "A space and enter keeps this data: " addCreation @ strcat notify
        do_read toupper dup dup " " stringcmp not if pop pop else strip addCreation ! "." stringcmp not if 'aborted jmp then then

        blankline me @ "How do you get to this area? Do NOT give a db#.  It will be provided" notify
        me @ "automatically if the room is teleport-able. >>" notify
        me @ "A space and enter keeps this data: " addDirections @ strcat notify
        do_read dup dup " " stringcmp not if pop pop else strip addDirections ! "." stringcmp not if 'aborted jmp then then

        blankline me @ "Add any extra comments here >>" notify
        me @ "A space and enter keeps this data: " addComment @ strcat notify
        do_read dup dup " " stringcmp not if pop pop else strip addComment ! "." stringcmp not if 'aborted jmp then then

        blankline me @ "Changing your listing..." notify
        background

        trig "/locked" getpropstr dup "" stringcmp if
                me @ "HOMEFINDER DATABASE LOCKED BY USER " trig "/lockuser" getpropstr toupper strcat ": " strcat rot strcat ".    Retrying..." strcat notify
                4 sleep
                trig "/locked" getpropstr "" stringcmp if me @ "Database still locked!  Please try again in a few moments." notify exit then
        then


        "editHome" lockDB
        trig "/themes/" addTheme @ strcat addTheme @ setprop
        trig "/homes/" home @ intostr strcat addTheme @ setprop
        currentTheme @ checkTheme pop
        unlockDB

        home @ "/homefinder/version" HFver setprop
        home @ "/homefinder/occupancy" addOccupancy @ setprop
        home @ "/homefinder/directions" addDirections @ setprop
        home @ "/homefinder/comment" addComment @ setprop
        home @ "/homefinder/name" addName @ setprop
        home @ "/homefinder/creation" addCreation @ setprop

        me @ "Your area information has been modified in the HomeFinder database." notify
        exit
;

: cmd-homefinder ( s -- )
        "me" match me !
        strip cmdline !

        ( If the DB has not been #clean ed  initially, then go ahead and do that automatically )
        trig "/version" getpropval HFver = not if me @ "Running initial HomeFinder set up..." notify 'cleanDB jmp exit then

        ( If the DB is locked, retry once and then quit if no success )
        trig "/locked" getpropstr dup "" stringcmp if
                me @ "HOMEFINDER DATABASE LOCKED BY USER " trig "/lockuser" getpropstr toupper strcat ": " strcat rot strcat ".    Retrying..." strcat notify
                4 sleep
                trig "/locked" getpropstr "" stringcmp if me @ "Database still locked!  Please try again in a few moments." notify exit then
        then

        ( If autolist is turned on and cmdline is empty, list all homes instead )
        trig "/autolist" getpropval "" cmdline @ stringcmp not and if me @ "Use '" command @ strcat " #help' for program options.  Listing all registered homes..." strcat notify "#ALL" listHome me @ "Use '" command @ strcat " #help' for program options." strcat notify exit then
        
        (Zombie check)
        me @ player? if 
        cmdline @ " " explode 1 = if "#add" stringcmp not me @ loc @ controls and if loc @ 'addHome jmp exit then then
        clearstack
        cmdline @ " " explode 2 = if "#list" stringcmp not if toupper 'listHome jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#themes" stringcmp not if 'listThemes jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#edit" stringcmp not me @ loc @ controls and if loc @ 'editHome jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#remove" stringcmp not me @ loc @ controls and if loc @ int 'removeHome jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#stats" stringcmp not if me @ int 'listStats jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#clean" stringcmp not me @ trig controls and if me @ int 'cleanDB jmp exit then then
        clearstack
        cmdline @ " " explode 1 = if "#autolist" stringcmp not me @ trig controls and if trig "/autolist" 1 setprop me @ "#autolist turned on" notify exit then then
        clearstack
        cmdline @ " " explode 1 = if "#!autolist" stringcmp not me @ trig controls and if trig "/autolist" remove_prop me @ "#autolist turned off" notify exit then then

                blankline
                me @ "HomeFinder v1.04 by Kulan of Spindizzy. 2004" notify blankline
                me @ "Summary:  This command allows you to find a place to live on the muck." notify
                me @ "#HELP:" notify
                me @ "   #list <theme>   : Lists the homes that reside in <theme> or #all for every" notify
                me @ "                       home." notify
                me @ "   #themes         : Lists themes in the database with homes in them." notify
                me @ "   #add            : Adds your current room as a place to live at (room owner" notify
                me @ "                       only). Make sure you are in the room you want to add!" notify
                me @ "   #remove         : Removes your current room from the database (room owner" notify
                me @ "                       only). Make sure you are in the room you want deleted!" notify
                me @ "   #edit           : Edits your current room listing (room owner only)." notify
                me @ "   #stats          : Shows the database statistics." notify
                me @ "   #clean          : Cleans the database up, removing @rec'd homes (owner" notify
                me @ "                       only)." notify
                me @ "   #autolist       : Shows all homes on startup (owner only)." notify
                me @ "                       Reverse is #!autolist." notify
                me @ "   #help           : This screen." notify
        exit
        then
        me @ "Sorry, only players can run this program." notify
        exit
;
.
c
q
@set homefinder.muf=3
@set homefinder.muf=W
@set homefinder.muf=L

