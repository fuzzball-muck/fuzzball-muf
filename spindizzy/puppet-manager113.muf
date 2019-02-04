( /quote -dsend -S '/data/spindizzy/muf/puppet-manager113.muf )
@prog puppet-manager.muf
1 5000 d
i
$include $lib/strings
$include $lib/match
$include $lib/puppetdb

: blankline ( -- Outputs a blank line )
    me @ "  " notify
;

: listPuppets ( A -- Given an array of puppet dbrefs, pretty print
                          a list of them and their owner )

    dup array_count var! arraySize

    arraySize @ 100 > if me @ "Sorting..." notify then

    var zomb
    "   " var! spaces
    me @ owner var! controller
        
    ( Create a list so we can sort it )
    { }list
    
    swap
    FOREACH
        ( remove index )
        swap pop
        ( Add a formatted line to the list )
        zomb !
        
        zomb @ controller @ over controls if
            unparseobj
        else
            name
        then
        27 STRleft 27 strcut pop
        spaces @ strcat
        zomb @ owner name strcat
        swap array_appenditem
    REPEAT
    
    ( Sort the entries )
    SORTTYPE_CASE_ASCEND array_sort
    
    blankline
    me @ "   PUPPET NAME                   OWNER" notify
    me @ "----------------------------------------------" notify
    
    { me @ }list array_notify
    
    blankline
    me @ arraySize @ intostr " puppets listed." strcat notify
;

: filterPuppets ( A s -- Given an array and a smatch string, list puppets whose
                         name matches the string )
                         
    strip "*" swap strcat "*" strcat var! smatchString
    
    ( Create the output array )
    { }list
    
    swap
    FOREACH
        ( remove index )
        swap pop
        
        dup name smatchString @ smatch if
            ( A match! )
            swap array_appenditem
        else
            ( Does not match; skip )
            pop
        then
    REPEAT
    
    ( Show the result of the search )
    listPuppets
;

: listAwakePuppets ( s -- Lists all awake puppets with an optional search string)
    "s" checkargs
    blankline
    
    dup strlen if
        ( Filter desired )
        me @ "=== All Awake Puppets matching " 3 pick strcat " ===" strcat notify
        puppetdb-awakePuppets swap filterPuppets
    else
        pop
        me @ "=== All Awake Puppets ===" notify
        puppetdb-awakePuppets listPuppets
    then
;

: listAllPuppets ( s -- Lists all puppets with an optional search string )
    "s" checkargs
    blankline
    
    dup strlen if
        ( Filter desired )
        me @ "=== All Registered Puppets matching " 3 pick strcat " ===" strcat notify
        puppetdb-allPuppets swap filterPuppets        
    else
        pop
        me @ "=== All Registered Puppets ===" notify
        puppetdb-allPuppets listPuppets
    then    
;

: listMyPuppets ( d s -- Given a dbref of a player, list all their puppets with
                  an optional search string. )

    "Ps" checkargs
    
    var! searchString
    var! theOwner

    blankline
    
    me @
    searchString @ strlen if
        ( Search string provided )
        "=== All Puppets Belonging To "
        theOwner @ name strcat " matching " strcat searchString @ strcat
        " ===" strcat
    else
        "=== All Puppets Belonging To "
        theOwner @ name strcat " ===" strcat
    then
    notify

    { }list
    
    puppetdb-allPuppets
    dup array_count 300 > if me @ "Finding your puppets..." notify then
    
    FOREACH
        ( Remove index )
        swap pop
        
        ( If puppet belongs to player, put in list )
        dup owner theOwner @ = if
            swap array_appenditem
        else
            pop
        then
    REPEAT

    searchString @ strlen if
        ( Filter )
        searchString @ filterPuppets
    else        
        listPuppets
    then
;

: addPuppet ( d -- Given a puppet d, add it to the puppet list )
    var! puppet

    puppet @ thing? if
        puppet @ "Zombie" flag? not if
            me @
                "The puppet must have the Z flag set before it can be registered."
            notify
            exit
        then
    else
        me @ "Only things with a Z flag can be registered as puppets." notify
        exit
    then
    
    puppet @ puppetdb-isPuppetRegistered? if
        me @ puppet @ unparseobj " is already registered." strcat notify
        exit
    then

    puppet @ name puppetdb-matchAll dup ok? if
        name puppet @ name stringcmp not if
            me @ "Another puppet already has the name " puppet @ name strcat
              ".  Please choose another." strcat notify
            exit
        then
    else
        pop
    then
    
    puppet @ puppetdb-addPuppetToList if
        puppet @ name dup " " instr if
            me @ "NOTE: Having a space in the puppet name will cause some programs to fail." notify
        then
        
        ( Smatch didn't like these, so I just did this real quick )
        dup "(" instr
        over ")" instr or
        over "[" instr or
        over "]" instr or
        over "*" instr or
        over "#" instr or
        swap ":" instr or
        if
            me @ "NOTE: Having special characters in the puppet name will cause some programs to fail." notify
        then
        
        me @ "The puppet named " puppet @ unparseobj strcat " is now registered." strcat notify
    else
        me @ "Unable to add the puppet!  [Internal error]" notify
    then
;

: removePuppet (d -- Given a puppet d, remove it from the puppet list)
    var! puppet
    
    puppet @ ok? not if
        me @ "The dbref given is not valid.  Cannot unregister." notify
        exit
    then
    
    puppet @ puppetdb-deletePuppetFromList if
        me @ "Successfully unregistered "
             puppet @ unparseobj strcat
             " from the puppet list." strcat
        notify
    else
        me @ "Could not unregister " puppet @ unparseobj strcat
             " from the puppet list.  It may not be registered or a puppet."
             strcat
        notify
    then
;

: help
blankline
me @ "       ---- Puppet Manager v1.13 by Morticon@SpinDizzy 2014 ----" notify
me @ "Puppet Manager allows you to register and deregister puppets on the" notify
me @ "puppet list.  The puppet list is used by this program and others to show" notify
me @ "puppets on the MUCK as if real players.  Below are the subcommands" notify
me @ "that can be used.  Enter one of them after the '" COMMAND @ strcat "' command:" strcat notify
blankline
me @ "  #register      Registers a puppet with this program (ran by puppet)" notify
me @ "  #unregister    Unregisters a puppet with this program (ran by puppet)" notify
me @ "  #!puppets      Does not show any puppets when in puppetlist" notify
me @ "                 integrated programs" notify
me @ "  #puppets       Shows puppets when in puppetlist integrated programs (default)" notify
me @ trig controls if
    blankline
    me @ "  #unlock        For admin use: Unlocks puppet database in case of crash" notify
    me @ "  #clean         For admin use: Cleans puppetdb manually" notify
then
blankline
me @ "A search string may be added at the end of these options (example '#all flo'):" notify
me @ "  #awake         Shows all registered puppets that are awake" notify
me @ "  #all           Shows all registered puppets, awake or not" notify
me @ "  #mine          Shows all puppets you own" notify
    
blankline
me @ "Puppets are currently " me @ puppetdb-use?
   if "enabled." else "disabled." then strcat notify
;


: puppetcheck ( -- Checks if me is a puppet.  If not, prints an error and exits
                   the program )
    me @ "Zombie" flag? not if
        me @ "Sorry, you must be a zombie/puppet to run this subcommand." notify
        pid kill
    then
;

: main
    "me" match me !
    "" var! search
    
    strip
    dup " " instr dup if
        strcut strip search !
    else
        pop
    then

    (Guest check)
    me @ "/@guest" getpropstr strlen if
        me @ "Sorry, but guests cannot use this program." notify
        exit
    then


    ( Run the subcommand they're interested in )
      
    ( #register )
    dup "#reg" instring 1 = if
        puppetcheck
        me @ addPuppet
        exit
    then
    
    ( #unregister )
    dup "#unr" instring 1 = if
        me @ removePuppet
        exit
    then
    
    ( #awake )
    dup "#awa" instring 1 = if
        search @ listAwakePuppets
        exit
    then
    
    ( #all )
    dup "#all" instring 1 = if
        search @ listAllPuppets
        exit
    then
    
    ( #mine )
    dup "#min" instring 1 = if
        me @ owner search @ listMyPuppets
        exit
    then
    
    ( #!puppets )
    dup "#!pu" instring 1 = if
        me @ 0 puppetdb-setUse
        me @ "You will no longer see puppets in puppetdb-integrated programs." notify
        exit
    then
    
    ( #puppets )
    dup "#pup" instring 1 = if
        me @ 1 puppetdb-setUse
        me @ "You will see puppets in puppetdb-integrated programs." notify
        exit
    then

    ( #unlock )
    dup "#unl" instring 1 = if
        me @ owner trig controls if
            puppetdb-forceUnlock
        else
            me @ "Permission denied. [you don't control the action]" notify
        then
        exit
    then

    ( #clean )
    "#cle" instring 1 = if
        me @ owner trig controls if
            me @ "Starting puppetdb clean..." notify
            puppetdb-cleanPuppets
            me @ "Finished puppetdb clean." notify
        else
            me @ "Permission denied. [you don't control the action]" notify
        then
        exit
    then
    
    help
    blankline
;
.
c
q
@set puppet-manager.muf=L
@set puppet-manager.muf=3
@set puppet-manager.muf=W
@set puppet-manager.muf=!D
