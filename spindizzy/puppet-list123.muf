Maybe it could do
0) Exact match for player
1) exact match for puppet
2) substring match for player
3) substring match for puppet" to you.



( /quote -dsend -S '/data/spindizzy/muf/puppet-list123.muf )
@prog lib-puppetdb.muf
1 5000 d
i
( lib-puppetdb is a collection of M3 or above functions to work with global
  puppet/zombie registration.  It supports multiple props to handle lots and 
  lots of puppets being registered.
    
  To install, create an object or room to store the registration info, and
  then set it in the define below )
  
( Public Methods:
    puppetdb-isPuppetAwake?       [d -- i] Returns 1 if puppet is awake
    puppetdb-isPuppetListening?   [d -- i] Returns 1 if puppet can hear things
    puppetdb-isPuppetRegistered?  [d -- i] Returns >1 if puppet is already
                                             registered.  Expensive.
    puppetdb-puppetHasRegProp?    [d -- i] Like call above, only much cheaper.
    puppetdb-addPuppetToList [d -- i] Adds puppet d to list, returning 1 if
                                        successfully added.
    puppetdb-deletePuppetFromList
                             [d -- i] Removes puppet d from list, returning 1
                                        if successfully removed.
    puppetdb-awakePuppets    [  -- a] Returns an array of awake puppet dbrefs
    puppetdb-allPuppets      [  -- a] Returns an array of all puppet dbrefs
                                        which are registered
    puppetdb-allOnlinePlayersPuppets [ -- a]  Returns an array of all
                                        registered, awake puppets AND awake
                                        players.
    puppetdb-match           [s -- d] Matches an awake puppet.  Returns dbref
                                        if found, #-1 if not found, #-2 if
                                        ambigious.
    puppetdb-matchAll        [s -- d] Like puppetdb-match, except all puppets.
    puppetdb-pmatch          [s -- d] First exact matches all players, then
                                        partial matches awake players, then
                                        awake puppets.  Returns dbref if found,
                                        #-1 if not found, #-2 if ambigious.
    puppetdb-formatName      [d -- s] Adds puppet owner in parentheses after
                                        the puppet name and Z indicator.
    puppetdb-formatNameSimple[d -- s] Adds Z indicator to end of puppet name.
    puppetdb-unformatName    [s -- s'] Removes zombie indicators from puppet
                                       name
    puppetdb-cleanPuppets    [  --  ] Removes nonexistant puppets.  Compacts
                                        things too.
    puppetdb-setUse          [di--  ] If i > 0, activates puppetlist portion
                                        of any programs that support it for d.
                                        Default is 1.
    puppetdb-use?            [d -- i] Returns > 0 if d wants to activate
                                        puppetlist portions of integrated
                                        programs.
    puppetdb-forceUnlock     [  --  ] Used only by the controller of the
                                        puppet list, it will unlock it in case
                                        the program crashed.
)

(
    History:
    v1.23: Allow operation with backgrounded programs and cronjobs for cleaning
    v1.22: Overzealous with picking online players over offline players and
           sometimes selecting the wrong player overall,
           so tweaking puppet pmatch to allow exact match for offline players.
    v1.21: Fix matching puppet names to account for 2+ puppets with the same
           name, so it properly returns ambigious #-2.
)
  
( Approximate limit, in bytes, for each line that lists puppets )
$def LISTLIMIT 390
( Dbref where the puppet DB is stored )
$def PUPPETDB #0

$def PUPPETLISTCOUNT "/_puppetdb/list#"
$def PUPPETLISTPREFIX "/_puppetdb/list#/"
$def PUPPETLOCK "/_puppetdb/locked"
$def PUPPETLOCKUSER "/_puppetdb/lockuser"
$def PUPPETIDPROP "/@prefs/puppet-registered?"
$def NOPUPPETDBPROP "/_prefs/no-puppet-list"

: sysMessage ( s --   Prefixes library name to string and outputs completed string to user )
        me @ swap "puppetdb: " swap strcat notify
;

: playerName ( i -- s)
( Given an integer or dbref, returns a string with the name of the player, or returns '*Toaded Player*' if needed)
        dup dbref? not if dbref then
        dup player? if name else pop "*Toaded Player*" then
        exit
;

( ----- LOCK STUFF ----- )
: lockDBprops ( s -- )
( Marks the DB as locked with string s as the reason.  Assumes already in preempt mode )
        mode pr_mode = not if "Internal error: Not in preempt mode." abort then
        ( If it's already locked, abort program )
        PUPPETDB PUPPETLOCKUSER getprop 0 = not if "Internal error: Puppet List already locked!  Try again later." abort then
  
        PUPPETDB PUPPETLOCK rot setprop
        PUPPETDB PUPPETLOCKUSER me @ owner setprop
;

: unlockDB ( -- )
( Marks the DB as unlocked )
        PUPPETDB PUPPETLOCK remove_prop
        PUPPETDB PUPPETLOCKUSER remove_prop
;

: isLocked? ( -- i )
        PUPPETDB PUPPETLOCKUSER getprop 0 = not
;

: lockDBwait ( s --  Waits for the lock to be free.  s is the reason for the
               lock.  If empty, lock is not performed, but will still wait. )
    0 var! waitMessageShown
    ( multitasking mode program was in prior to lock DB )
    mode var! multitaskMode

    preempt
    isLocked? not if
        dup strlen if
            ( Not locked, so grab it while we can! )
            lockDBprops
        else
            ( Locking is not desired - just wanted to wait for it )
            pop
        then
        
        multitaskMode @ setmode
    else
        ( Wait until unlocked )
        multitaskMode @ setmode
        BEGIN
            2 sleep
            preempt
            isLocked? not if
                ( Finally found it to be unlocked.  Lock and return )
                dup strlen if
                    lockDBprops
                else
                    ( Locking is not desired - just wanted to wait for it )
                    pop
                then
                multitaskMode @ setmode
                "Puppet List unlocked.  Resuming execution..." sysMessage
                BREAK
            else
                multitaskMode @ setmode

                waitMessageShown @ not if
                    1 waitMessageShown !
                    
                    ( Show the message once, indicating we're retrying )
                    "Puppet List locked by player " PUPPETDB PUPPETLOCKUSER getprop
                    playerName strcat " for: " strcat PUPPETDB PUPPETLOCK getpropstr
                    strcat sysMessage
                    "Waiting for unlock... (Type '@Q' to abort program)"
                    sysMessage
                then

                me @ awake? not if "Player disconnected during lockDBwait.  Possible internal program problem?" abort then
            then
        REPEAT
    then
;
  
: lockHold ( -- )
    "" lockDBwait
;
  
( -------------- )

: isPuppetPropSet? ( d -- i Given a dbref d, return 1 if d is a thing and
                            has the puppet prop set )
    "d" checkargs
                           
    dup thing? if    
        (Return true if length is 3, for 'yes')
        PUPPETIDPROP getpropstr strlen 3 =
    else
        pop
        0
    then
;

: getMaxSublists ( -- i  Returns how many sublists are present )
    PUPPETDB PUPPETLISTCOUNT getpropval
    
    ( If there's no list at all, make it 1 to seed things )
    dup 0 = if pop 1 then
;

: getSublistProp ( i -- d s  Given sublist i, return the puppet list dbref and
                             the full prop path to the sublist )
    "i" checkargs
    PUPPETDB PUPPETLISTPREFIX rot intostr strcat
;

: deletePuppetFromListInternal ( i d -- Given the sublist number and the dbref
                                 to remove, remove the puppet and reshuffle
                                 dbrefs as needed.  No locking is performed.
                                 It assumes the dbref exists where it's
                                 supposed to. )

    "id" checkargs

    var! puppet
    var! sublist
    getMaxSublists var! maxSublist
    var sublistArray
    var maxSublistArray

    sublist @ 0 < if "delete: Internal error.  Sublist < 0." abort then

    ( Now, several things can happen after the dbref is removed:
      Either the last sublist is empty, the byte count is still too
      high [no action], or we can shuffle another dbref in its place to
      keep the lists compact )
      
    sublist @ maxSublist @ = if
        ( Last sublist.  Remove the dbref and the sublist if it's empty )
        sublist @ getSublistProp puppet @ reflist_del
        
        sublist @ getSublistProp getpropstr strlen 1 <= if
            ( Last sublist is empty.  Remove it )
            PUPPETDB PUPPETLISTPREFIX sublist @ intostr strcat remove_prop
            PUPPETDB PUPPETLISTCOUNT getpropval
            --
            PUPPETDB PUPPETLISTCOUNT rot setprop
        then
    else
        ( Might need to shuffle a dbref into its place, if not the last sublist
          and there is room after deleting the dbref 'd' )
          
        ( Remove the dbref d from the sublist it is in )
        sublist @ getSublistProp array_get_reflist sublistArray !
        sublistArray @ dup puppet @ array_findval 0 []
            array_delitem sublistArray !

        ( Determine if there is room to shuffle another dbref in its place )
        sublist @ getSublistProp getpropstr strlen LISTLIMIT < if
            ( Grab the last dbref from the last sublist and put it in the
              deleted dbref's place )
            maxSublist @ getSublistProp array_get_reflist maxSublistArray !
            maxSublistArray @ array_count -- dup
            maxSublistArray @ swap []
            maxSublistArray @ rot array_delitem maxSublistArray !
            maxSublist @ getSublistProp maxSublistArray @ array_put_reflist

            maxSublistArray @ array_count 0 = if
                ( The last sublist is now empty.  Remove it )
                maxSublist @ getSublistProp remove_prop
                PUPPETDB PUPPETLISTCOUNT getpropval
                --
                PUPPETDB PUPPETLISTCOUNT rot setprop
            then

            ( The last dbref from the last sublist is on the stack.
              Put it on the sublist the dbref 'd' being removed is on )
            sublistArray @ array_appenditem sublistArray !
        then

        ( Write out the changed sublist )
        sublist @ getSublistProp sublistArray @ array_put_reflist
    then
;

: isPuppetRegistered? ( d -- i Given a puppet dbref, return > 0
                                if found in list, or 0 if not.  The number
                                is what sublist it is located in [for
                                internal use only]. Internal, non-locking.)
    "d" checkargs

    getMaxSublists var! max_sublist
    var! dbref_to_find

    ( Search all sublists for it )    
    max_sublist @ 1 -1 FOR
        dup getSublistProp dbref_to_find @ reflist_find if
            ( Found it!  Return the sublist number )
            exit
        else
            pop
        then
    REPEAT
    
    ( Did not find it )
    0
;

: countDuplicates ( Ad s -- i  Given a list of puppet dbrefs and a string, return
                             the number of times an exact match is found for
                             the dbref name )
    "?S" checkargs
    var! matchTarget
    var! puppets
    0 var! numMatches

    puppets @ FOREACH
        ( remove index )
        swap pop
        
        dup ok? if
            name matchTarget @ stringcmp not if
                ( Found a match )
                numMatches ++
            then
        else
            pop
        then
    REPEAT
    
    numMatches @
;

: matchPuppetFromList ( Ad s -- d  Given a list of puppet dbrefs and a string,
                           return the dbref of the puppet most closely
                           matching the string, or #-1 if none found,
                           #-2 if ambigious )

    "?S" checkargs
    var! matchTarget
    { }list var! matches
    
    ( list of puppet dbrefs in stack )
    FOREACH
        ( remove index )
        swap pop
        
        ( Check the name )
        dup name matchTarget @ instring 1 = if
            ( A match! )
            matches @ array_appenditem matches !
        else
            pop
        then
    REPEAT
    
    matches @ array_count 0 = if
        ( No matches )
        #-1
        exit
    then

    ( If we have exactly one match, then we're done.  If we have more than
      one, find which is exact and use that )      
    matches @ array_count 1 = if
        matches @ dup array_first pop [] exit
    then
    
    ( More than one! )
    matches @ FOREACH
        ( Dump index )
        swap pop
        
        ( See if entry is exact.  If so, we found our match )
        dup name matchTarget @ stringcmp not if
            ( Exact match )
            ( Confirm there are not multiple exact matches )
            matches @ matchTarget @ countDuplicates 1 = not if
                ( More than one exact match - ambigious )
                pop
                #-2
                exit
            then
            
            exit
        else
            pop
        then
    REPEAT
    
    ( If we got this far, there were multiple matches, none of them exact.
      Ambigious )
    #-2
;

( -------------- )

( ---- Public Functions ---- )

: puppetdb-isPuppetAwake? ( d -- i  Given a puppet dbref d, return 1 if puppet
                           has the puppet prop on it and is awake )
    "d" checkargs
                           
    dup thing? if
        ( Check if owner awake first to avoid a potential DB file access )
        dup owner awake? if
            isPuppetPropSet?
        else
            ( owner not awake )
            pop
            0
        then
    else
        pop
        0
    then
;

: puppetdb-isPuppetListening? (d -- i  Given a puppet dbref d, return 1 if
                                puppet is awake AND able to listen [has Z
                                flag set])
    "d" checkargs
    
    dup puppetdb-isPuppetAwake? swap "Zombie" flag? and
;

: puppetdb-isPuppetRegistered? ( d -- i  Given a puppet dbref, return > 0
                                if found in list, or 0 if not.  The number
                                is what sublist it is located in [for
                                internal use only]. Can be expensive. )
    "d" checkargs

    lockHold
    
    isPuppetRegistered?                           
;
  
: puppetdb-puppetHasRegProp? ( d -- i  Given a puppet dbref, return 1 if
                                       it has the registration prop on it,
                                       or 0 if not.  Very quick check, not
                                       100% accurate )
    isPuppetPropSet?
;
  
: puppetdb-addPuppetToList ( d -- i Given a puppet dbref, add it to the
                             puppet list. Returns 1 if added, or 0 if not due
                             to duplicate )
    "T" checkargs
    
    "Add Puppet" lockDBwait
    
    var! puppet
    getmaxSublists var! current_length
    
    ( Duplicate check )
    puppet @ isPuppetRegistered? if unlockDB 0 exit then
    
    ( Determine if we can add the dbref to the list sublist, or if we need to
      make a new one )
    current_length @ getSublistProp getpropstr
    
    strlen LISTLIMIT > if
        ( We need to make a new list )
        current_length ++
    then

    PUPPETDB PUPPETLISTCOUNT current_length @ setprop

    ( Actually do the addition )
    current_length @ getSublistProp puppet @ reflist_add
    
    unlockDB
        
    ( We added it successfully )
    puppet @ PUPPETIDPROP "yes" setprop
    1
;

: puppetdb-deletePuppetFromList ( d -- i  Given a dbref, delete it from the
                                 puppet list, returning 1 if success, or 0
                                 if not found )

    "d" checkargs
    
    "Delete Puppet" lockDBwait
    
    var! puppet
    puppet @ isPuppetRegistered? var! sublist

    ( Existance check )
    sublist @ not if unlockDB 0 exit then
        
    ( do the deletion )
    sublist @ puppet @ deletePuppetFromListInternal
      
    unlockDB

    ( We removed it successfully )
    puppet @ PUPPETIDPROP remove_prop
      
    1
;

: puppetdb-awakePuppets ( -- a  Returns a list array of puppet dbrefs that
                          are awake )
    lockHold
    
    getMaxSublists var! maxSublist

    ( List of online dbrefs kept in stack to avoid dupes )
    { }list

    ( Go through each sublist, adding any awake, valid puppets to the list )
    maxSublist @ 1 -1 FOR
        getSublistProp array_get_reflist
        FOREACH
            ( Get rid of index - don't need it )
            swap pop
            
            dup puppetdb-isPuppetAwake? if
                ( Awake.  Add to list )
                swap array_appenditem
            else
                ( Not awake, skip )
                pop
            then            
        REPEAT
    REPEAT
;

: puppetdb-allPuppets ( -- a Returns a list array of all registered, valid
                        puppets )
    lockHold
    
    getMaxSublists var! maxSublist

    ( List of dbrefs kept in stack to avoid dupes )
    { }list

    ( Go through each sublist, adding any valid puppets to the list )
    maxSublist @ 1 -1 FOR
        getSublistProp array_get_reflist
        FOREACH
            ( Get rid of index - don't need it )
            swap pop
            
            dup isPuppetPropSet? if
                ( Valid.  Add to list )
                swap array_appenditem
            else
                ( Not valid, skip )
                pop
            then
            
        REPEAT
    REPEAT
;

: puppetdb-allOnlinePlayersPuppets ( -- a Returns an array of all registered,
                                        awake puppets AND awake players.  Does
                                        not filter on dark )
    online_array
    puppetdb-awakePuppets
    array_union
;

: puppetdb-match ( s -- d  Given a string, return the dbref of the closest
                           awake puppet matching the string, or #-1 if none
                           found, #-2 if ambigious )
    "S" checkargs
    puppetdb-awakePuppets swap matchPuppetFromList
;

: puppetdb-matchAll ( s -- d Given a string, return the dbref of any puppet
                             most closely matching the string, or #-1 if none
                             found, #-2 if ambigious )
    "S" checkargs
    puppetdb-allPuppets swap matchPuppetFromList
;

: puppetdb-pmatch ( s -- d Given a string, exact match it, then partial match it
                           against awake players.  Finally, if no match from
                           that, try matching awake puppets.  Return dbref
                           if match, #-1 if no match, #-2 if ambigious )
    "S" checkargs
    strip var! matchTarget

    matchTarget @ pmatch
    dup player? if
        ( Exact player match overrides everything )
        exit
    then
    pop

    matchTarget @ puppetdb-match var! puppetMatchDbref
    matchTarget @ part_pmatch var! playerMatchDbref

    ( Partial player match is valid, but a puppet could match too.  If the
      puppet is an exact match, use it, otherwise use the player )
    playerMatchDbref @ player? if
        puppetMatchDbref @ thing? not if
            ( Got a player partial match, but nothing from puppets.  Return
              player )
            playerMatchDbref @
            exit
        else
            puppetMatchDbref @ name matchTarget @ stringcmp not if
                ( Puppet exact match, return that instead )
                puppetMatchDbref @
                exit
            else
                ( A puppet and player match, but don't know which to pick )
                #-2 exit
            then
        then
    then

    ( Partial player match is ambiguous, so check puppet match.  If not a
      match there either, then return #-2 )
    playerMatchDbref @ #-2 = if
        ( Check puppet match )
        puppetMatchDbref @ thing? if
            ( If puppet matches exactly, then return it, otherwise
              return ambiguous )
            puppetMatchDbref @ name matchTarget @ stringcmp not if
                ( Exact match )
                puppetMatchDbref @
                exit
            else
                ( Ambiguous )
                #-2 exit
            then
        else
            ( No match, so return ambiguous )
            #-2 exit
        then
    then
    
    ( Could not find any players, return result of puppet matching )
    puppetMatchDbref @
;
  
: puppetdb-formatName ( d -- s  Given a puppet dbref, return the puppet
                                name with a Z indicator at the end, and
                                the player's name in brackets )
    "d" checkargs
    var! target
    
    target @ ok? not if
        "[INVALID DBREF]"
        exit
    then
    
    target @ player? if
        target @ name
        exit
    then
    
    target @ thing? if
        target @ name "(Z)[" strcat target @ owner name strcat "]" strcat
    else
        "[NOT A PUPPET]"
    then
;

: puppetdb-formatNameSimple ( d -- s Given a puppet dbref, return the
                              puppet name with a Z indicator at the end, or the
                              name of the object if not a puppet )
    "d" checkargs
    var! target
    
    target @ ok? not if
        "[INVALID DBREF]"
        exit
    then
    
    target @ player? if
        target @ name
        exit
    then
    
    target @ thing? if
        target @ name "(Z)" strcat
    else
        "[NOT A PUPPET]"
    then
;

: puppetdb-unformatName (s -- s'  Removes puppet indicators on names.  Works
                         on multiple names if space separated)
    "s" checkargs

    BEGIN
        dup "(Z)" instr dup if
            ( Remove the Z indicator plus owner name if found )
            -- strcut 3 strcut swap pop
            ( Stack has two strings.  The second may have [owner], and if
              so remove it and rejoin the strings, since there may be multiple
              zombies to unformat )
            dup "[" instr 1 = if
                dup "]" instr dup if
                    ( Remove the owner indicator )
                    strcut swap pop
                else
                    pop
                then
            then
            
            ( Combine the two halves, now without the Z indicator on the first
              name which had it )
            strcat
        else
            pop
            break
        then
    REPEAT
;

: puppetdb-cleanPuppets ( -- Cleans the puppet list of invalid stuff )
    ( multitasking mode program was in prior to cleaning )
    mode var! multitaskMode
    
    preempt
    
    isLocked? if
        multitaskMode @ setmode
        "Currently locked, unable to clean puppets.  Try again later." sysMessage
        exit
    then
    
    ( Directly lock instead of lockDBwait because this can be used on cronjobs )
    "Clean Puppets" lockDBprops
    multitaskMode @ setmode
    
    getMaxSublists var! maxSublist

    ( Go through each sublist, removing invalid puppets.
      Going backwards to make shuffling valid dbrefs
      around easier. )
    maxSublist @ 1 -1 FOR
        dup
        getSublistProp array_get_reflist
        FOREACH
            ( Get rid of index - don't need it )
            swap pop
            
            dup isPuppetPropSet? if
                ( Valid.  Do nothing. )
                pop
            else
                ( Not valid, remove )
                dup "Removing invalid dbref #" swap intostr strcat sysMessage
                2 pick swap deletePuppetFromListInternal
            then
        REPEAT
        
        (remove sublist on stack)
        pop
    REPEAT    
    
    unlockDB
;

: puppetdb-use? (d -- Given a dbref, returns > 0 if they want to use
                      puppetlist in integrated programs )
    "d" checkargs
    
    dup ok? if
        owner NOPUPPETDBPROP getpropstr "yes" stringcmp abs
    else
        pop 0
    then
;

: puppetdb-setUse (d i --  Given a dbref and an int, if i > 0 activate
                           the use of puppetlist in integrated programs for
                           d, otherwise deactivate it )
    "di" checkargs

    if
        NOPUPPETDBPROP remove_prop
    else
        NOPUPPETDBPROP "yes" setprop
    then
;

: puppetdb-forceUnlock ( -- Used in case the program crashes, this will
                            unlock the database )

    me @ PUPPETDB controls not if "Permission denied." sysMessage exit then

    isLocked? if
        "Unlocking..." sysMessage
        5 sleep
        unlockDB
        "Done." sysMessage
    then
;
  
( -- Main program does cleaning )
: main
    "Starting puppetdb clean..." sysMessage
    puppetdb-cleanPuppets
    "Finished puppetdb clean." sysMessage
;
  
PUBLIC puppetdb-isPuppetAwake?
PUBLIC puppetdb-isPuppetRegistered?
PUBLIC puppetdb-puppetHasRegProp?
WIZCALL puppetdb-addPuppetToList
WIZCALL puppetdb-deletePuppetFromList
PUBLIC puppetdb-awakePuppets
PUBLIC puppetdb-allPuppets
PUBLIC puppetdb-allOnlinePlayersPuppets
PUBLIC puppetdb-match
PUBLIC puppetdb-matchAll
PUBLIC puppetdb-pmatch
PUBLIC puppetdb-formatName
PUBLIC puppetdb-formatNameSimple
PUBLIC puppetdb-unformatName
WIZCALL puppetdb-cleanPuppets
PUBLIC puppetdb-use?
WIZCALL puppetdb-setUse
WIZCALL puppetdb-forceUnlock
$lib-version 1.230
$libdef puppetdb-isPuppetAwake?
$libdef puppetdb-isPuppetListening?
$libdef puppetdb-isPuppetRegistered?
$libdef puppetdb-puppetHasRegProp?
$libdef puppetdb-addPuppetToList
$libdef puppetdb-deletePuppetFromList
$libdef puppetdb-awakePuppets
$libdef puppetdb-allPuppets
$libdef puppetdb-allOnlinePlayersPuppets
$libdef puppetdb-match
$libdef puppetdb-matchAll
$libdef puppetdb-pmatch
$libdef puppetdb-formatName
$libdef puppetdb-formatNameSimple
$libdef puppetdb-unformatName
$libdef puppetdb-cleanPuppets
$libdef puppetdb-use?
$libdef puppetdb-setUse
$libdef puppetdb-forceUnlock
.
c
q

@reg lib-puppetdb.muf=lib/puppetdb
@set lib-puppetdb.muf=L
@set lib-puppetdb.muf=3
@set lib-puppetdb.muf=W
@set lib-puppetdb.muf=!D
