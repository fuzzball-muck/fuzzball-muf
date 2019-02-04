( How about a way of setting the sort order, and seeing idle times? )


( /quote -dsend -S '/data/spindizzy/muf/findeveryone101.muf )
@prog findeveryone.muf
1 5000 d
i
(FindEveryone, a clone of findall with improved performance and features)
(v1.01: Remove duplicates when players connected multiple times
 v1.00: Initial release )

$include $lib/puppetdb
$include $lib/strings

$def VERSION "1.01"
$def SEP_STRING ";$^~;"
$def REP_STRING "-----"

$def PREFS_PROP "/_prefs/findeveryone"
( Do not modify just by itself.  Set default flags elsewhere too )
$def DEFAULT_SETTINGS "#puppets #!privpuppets #private"

$def PRIVACY_STRING "... private ..."
$def DEFAULT_AREA_STRING "-None-"

$def AREA_PROP "_area"
$def PRIVATE_PROP "_private"

lvar use_puppets
lvar hide_all_private
lvar hide_private_puppets


: usePuppets? ( -- i returns true if puppets are to be used )
    use_puppets @ me @ puppetdb-use? and
;

: yes? ( s -- i Returns 1 if string begins with y )
    ( Taken from the original FindAll )
    1 strcut pop "y" stringcmp not
;

: mergeFields (s1 s2 s3 -- s' Combines the three strings into one, with a
                              special separator between each.  If the
                              separator is found in the strings, it will
                              be replaced with something else.  Order is
                              preserved)
    "sss" checkargs
    "" var! resultString
    
    ( Create a list of the three items for easier iterating and future
       expansion )
    3 array_make
    FOREACH
        ( Don't allow strings to be totally empty )
        dup strlen not if pop " " then
        
        ( Replace anything in the string that looks like our separator )
        REP_STRING SEP_STRING subst
        
        swap 2 = not if        
            ( Append our separator and add it to the result )
            SEP_STRING strcat
        then
        
        resultString @ swap strcat resultString !
    REPEAT
    
    resultString @
;

: splitFields (s' -- s3 s2 s1  The opposite of mergeFields )
    "S" checkargs
    
    SEP_STRING explode
    
    3 = not if
        "splitFields: Did not get 3 fields back" abort
    then
;

: sortFields ({s1..sn} -- {s1'..sn'}  Sorts the list of strings)
    "?" checkargs
    
    SORTTYPE_NOCASE_ASCEND array_sort
;

: private?  ( playerdbref -- private? )
    "D" checkargs
    ( Taken from the original FindAll )
    dup PRIVATE_PROP getpropstr yes? if pop 1
    else location PRIVATE_PROP getpropstr yes? if 2
    else 0 then then
;

: playerName ( d -- s  Converts a player or zombie dbref into a name )
    dup player? if
        name
    else
        name "(Z)" strcat
    then
;

: getAreaName  ( dbref -- areaname  Given a player/puppet dbref, gets a room's 
                                    area name)
    "D" checkargs
    "" var! areaNameString
    location var! areaDbref

    ( Don't allow empty area names.  Search upwards until one is found )    
    BEGIN                                
        areaDbref @ AREA_PROP envpropstr swap areaDbref ! strip dup
        areaNameString !
        
        ( See if we're done or need to go up a level )
        strlen not if
            areaDbref @ #0 <= if
                ( At the top, and still empty.  Insert a default )
                DEFAULT_AREA_STRING areaNameString !
            else
                ( Still empty.  Go up a level and see if the next prop is
                  non-empty )
                areaDbref @ #0 <= if
                    ( End of the line )
                    DEFAULT_AREA_STRING areaNameString !
                else
                    areaDbref @ location areaDbref !
                then
            then
        then
    
    areaNameString @
    UNTIL
    
    areaNameString @
;

: getRoomName ( d i -- s  Given a player or puppet and if they are marked
                          private, return the name of the room, accounting
                          for privacy )
    "Di" checkargs
    
    if
        ( Marked private )
        pop
        PRIVACY_STRING
    else
        location dup me @ owner swap controls if unparseobj else name then
    then
    striplead
;

: dark? ( d -- i  If the dbref is dark, return true )
    "D" checkargs
    "dark" flag?
;
  
: printList ( A i -- Takes a sorted list of merged fields, takes them
                     apart and prints them to the screen with a header and
                     footer. If the bool is true, this is printing the result
                     of a filter.)
    "?i" checkargs
    
    var! searched
    dup array_count var! characterListLength
    
    ( Header )
         (         1         2         3         4         5         6         7         8)
         (12345678901234567890123456789012345678901234567890123456789012345678901234567890)
    me @ "NAME                   AREA              ROOM" notify
    
    ( Characters )
    FOREACH
        swap pop
        splitFields
        ( make NRA -> RAN)
        rot
        ( Format and print )
        
        ( Name )
        21 strcut pop 21 STRleft

        "  " strcat
        
        ( Area )
        swap 16 strcut pop 16 STRleft strcat
        "  " strcat
        
        ( Room )
        swap strcat
        
        ( Print it out )
        me @ swap notify
    REPEAT
    
    ( Count characters up and print the footer )
    characterListLength @ intostr
    usePuppets? if
        searched @ if
            characterListLength @ 1 = if
                " character found."
            else
                " characters found."
            then
        else
            characterListLength @ 1 = if
                " character located."
            else
                " characters located."
            then
        then
    else
        searched @ if
            characterListLength @ 1 = if
                " player found."
            else
                " players found."
            then
        else
            characterListLength @ 1 = if
                " player located."
            else
                " players located."
            then
        then
    then
    
    strcat
    me @ swap notify
;

: hiddenPuppetFilter ( A -- A'  Given a list of dbrefs, return a list
                                without any private/hidden puppets or players)
    "?" checkargs
    
    { }list
    
    swap
    FOREACH
        ( Dump index )
        swap pop
        
        dup player? if
            ( Players always pass the filter if visible )
            dup dark? if
                ( Dark players aren't included )
                pop
            else
                swap array_appenditem
            then
        else
            dup private? if
                ( Private puppets are excluded in thie filter )
                pop
            else
                dup dark? if
                    ( Dark puppets aren't included )
                    pop
                else
                    swap array_appenditem
                then
            then
        then
    REPEAT
;

: darkFilter ( A -- A'  Given a list of dbrefs, return a list without
                        any dark puppets or players )
    "?" checkargs
    
    { }list
    
    swap
    FOREACH
        ( Dump index )
        swap pop
        
        dup dark? if
            ( Filter out dark dbrefs )
            pop
        else
            swap array_appenditem
        then
    REPEAT
;

: darkHiddenFilter ( A -- A' Given a list of dbrefs, return a list without
                            any dark or hidden puppets and players )
    "?" checkargs
    
    { }list
    
    swap
    FOREACH
        ( Dump index )
        swap pop
        
        dup private? if
            ( Filter out private dbrefs )
            pop
        else
            dup dark? if
                ( Filter out dark dbrefs )
                pop
            else
                swap array_appenditem
            then
        then
    REPEAT
;

: getAllOnline ( -- A   Based on program settings, returns a list of all
                        awake players and maybe puppets. )
    var listIndex
    #-1 var! lastListItem

    usePuppets? if
        puppetdb-allOnlinePlayersPuppets
    else
        online_array
    then
    
    ( Sort and remove adjacent duplicates )
    SORTTYPE_CASE_ASCEND array_sort
    
    ( Remove duplicates )
DEBUG_ON
    dup array_count dup listIndex !
    
    1 > if
        listIndex --
        
        ( List has items in it, so remove duplicates.
          Work backwards and remove adjacent duplicates. )
        BEGIN
            dup listIndex @ array_getitem
        
            dup lastListItem @ = if
                ( Found a duplicate.  Remove it.  Since we're going backwards,
                  removing it won't affect our traversal )
                pop
                listIndex @ array_delitem
            else
                ( Not a duplicate. Update the 'last list item' so we can check
                  for an adjacent duplicate next iteration )
                lastListItem !
            then
        
            ( Select the next entry )        
            listIndex --
        
        ( Only exit if we're at the last index )
        listIndex @ -1 =
        UNTIL
    then
DEBUG_OFF
;

: makeMergedFieldList ( A -- A' Given an array of dbrefs, turn them into
                                an array of names, areas, locations.
                                Assumes all dark dbrefs have been filtered out
                                List is returned sorted.)
    "?" checkargs
    
    var currentCharacter
    var isPrivate
    
    { }list
    
    swap
    FOREACH
        ( Dump index )
        swap pop
        
        dup currentCharacter !
        private? isPrivate !
    
        ( Order to call mergeFields is is area, room, name )
        isPrivate @ if
            ( Private means empty area )
            " "
        else
            currentCharacter @ getAreaName
        then
        
        currentCharacter @ isPrivate @ getRoomName
                
        currentCharacter @ playerName
        
        mergeFields        
        swap array_appenditem
    REPEAT
    
    sortFields    
;

: searchList ( A s -- A'  Given a list of dbrefs and a search string, return
                          a list of dbrefs that contain the string.  Assumes
                          all dark dbrefs have been filtered out. )
    "?s" checkargs

    var! searchString
    
    { }list
    
    swap
    FOREACH
        ( Dump index )
        swap pop
        
        dup name searchString @ instring if
            ( Found a match )
            swap array_appenditem
        else
            pop
        then
    REPEAT
;

: findAll ( -- Called after arguments have been parsed, finds everyone online
               that matches the filtering criteria )
    getAllOnline
        
    hide_all_private @ not hide_private_puppets @ not and if
        ( Not filtering anything, so just remove dark objects )
        darkFilter
    else
        hide_all_private @ if
            ( Hide everyone marked private )
            darkHiddenFilter
        else
            ( Hide only private puppets )
            hiddenPuppetFilter
        then
    then
        
    ( Display to the user )
    makeMergedFieldList 0 printList
;

: showProps ( --  Shows property help screen )
    {
    "Information on properties for area naming and privacy: "
    " "
    "If you want not to be seen,                @set "
        me @ name strcat " = _private:yes" strcat
    " "
    "If you want your room not to be seen,      @set here = _private:yes"
    " "
    "To set the name of your area, "
    "   (or set it on your environment room"
    "    to set all your rooms at once)         @set here = _area:A cute name"
    " "
    }list
    
    { me @ }list array_notify
    
    pid kill
;
: showHelp ( --   Shows a help screen )
    {
    "FindEveryone v" VERSION strcat " by Morticon@SpinDizzy 2015" strcat
    " "
    "  This program helps you find where people are.  When no options are"
    "specified, the stored settings are used to filter and show everyone"
    "online.  If you want to find a specific person (online or not), just"
    "give part of their name and the program will look them up."
    " "
    "Current (stored) settings: "
    me @ PREFS_PROP getpropstr dup if
        strcat
    else
        pop
        DEFAULT_SETTINGS strcat
    then
    " "
    "To find everyone online  : " COMMAND @ strcat
    "To find a specific person: " COMMAND @ strcat " <name>" strcat
    "                  example: " COMMAND @ strcat " zen" strcat
    " "
    "  Otherwise, the following program options may be used.  Multiple options" 
    "are allowed, each separated by a space:"
    "   #help        : This screen."
    "   #props       : Shows properties related to marking things private."
    "   #set         : Put FIRST, this will make the arguments after it the"
    "                    default setting(s).  If by itself, the default is reset."
    "                    Example: #set #private #privpuppets"
    "   #puppets     : Includes puppets in lists.  Puppet Manager must also be" 
    "                    enabled (see 'pman'). [default]"
    "   #!puppets    : Always EXCLUDES puppets in lists regardless of puppet"
    "                    manager setting."
    "   #private     : When showing everyone online, show those who are marked"
    "                    private or in private rooms. [default]"
    "   #!private    : When showing everyone online, DO NOT show those who are"
    "                    marked private or in private rooms."
    "   #privpuppets : When showing everyone online, show puppets who are"
    "                    marked private or in private rooms."
    "   #!privpuppets: When showing everyone online, DO NOT show puppets who"
    "                    are marked private or in private rooms. [default]"
    " "
    }list
    
    { me @ }list array_notify
    
    pid kill
;

: processArgs (s -- Processes commandline or prop-based arguments and sets
                    global variables accordingly.  Certain actions will
                    cause this method never to exit, such as invalid
                    arguments or setting the default. )
    "s" checkargs
    var! args
    0 var! wantsSet
    
    ( Jump to showing help if they have it anywhere in the args )
    args @ "#h" instring if showHelp then
    args @ "#pro" instring if showProps then
    
    ( See if they plan on #setting the default )
    args @ "#set" instring 1 = if
        wantsSet ++
        
        ( Remove the #set from the args list )
        args @ " " instr dup if
            args @ swap strcut swap pop striplead args !
        else
            pop
            ( They desire to reset to defaults )
            me @ PREFS_PROP remove_prop
            me @ "FindEveryone defaults set." notify
            pid kill
        then
    then
    
    ( Go through each argument one at a time, and set globals accordingly.
      If anything is invalid, abort )
    args @ " " explode_array
    FOREACH
        ( Dump index )
        swap pop
        
        striplead
        
        ( #puppets )
        dup "#pu" instring 1 = if
            1 use_puppets !
            pop continue
        then
        
        ( #!puppets )
        dup "#!pu" instring 1 = if
            0 use_puppets !
            pop continue
        then
        
        ( #private )
        dup "#priva" instring 1 = if
            0 hide_all_private !
            pop continue
        then
        
        ( #!private )
        dup "#!priva" instring 1 = if
            1 hide_all_private !
            pop continue
        then
        
        ( #privpuppets )
        dup "#privp" instring 1 = if
            0 hide_private_puppets !
            pop continue
        then
        
        ( #!privpuppets )
        dup "#!privp" instring 1 = if
            1 hide_private_puppets !
            pop continue
        then
        
        ( Unknown! )
        me @ "Unknown argument: " rot strcat notify
        me @ " " notify
        showHelp
    REPEAT
    
    ( Set these as default if desired, then exit )
    wantsSet @ if
        me @ PREFS_PROP args @ setprop
        me @ "FindEveryone options set." notify
        pid kill
    then
;

: main ( s -- )
    "me" match me !
    
    strip var! arguments
    
    1 use_puppets !
    0 hide_all_private !
    1 hide_private_puppets !
    
    arguments @ if
        arguments @ "#" instr 1 = if
            ( Option mode and find all )
            arguments @ processArgs
            findAll
        else
            ( Search mode )
            ( First try and match a player exactly, for offline usage )
            arguments @ pmatch dup player? if
                ( Found a player )
                dup dark? if
                    pop
                    { }list
                else
                    { swap }list
                then
                
                makeMergedFieldList 1 printList
            else
                pop
                
                ( Do general search of online characters )
                getAllOnline darkFilter arguments @ searchList
                makeMergedFieldList 1 printList
            then
        then
    else
        ( Run with pre-set options )
        me @ PREFS_PROP getpropstr dup if
            processArgs
        else
            pop
        then
        
        ( Wants to see everyone with pre-set arguments )
        findAll
    then
;
.
c
q
@set findeveryone.muf=3
@set findeveryone.muf=W
@set findeveryone.muf=!D
