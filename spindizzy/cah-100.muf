( /quote -dsend -S '/data/spindizzy/muf/cah-100.muf )
@prog cah-clone.muf
1 5000 d
i
$include $lib/strings

$def CAH_ROOT_PROP "/cah/"
$def DAEMON_PID_PROP "/cah/daemonpid"
$def ACTIVITY_TIMESTAMP_PROP "/cah/timestamp"
$def OBSERVERS_PROP "/cah/observers"
$def JUDGE_PROP "/cah/judge"
$def PLAYER_ADMIN_PROP "/cah/admin"
$def STATE_PROP "/cah/state"

$def CARD_LOADING_PREFIX_PROP "/cah/loading/"
$def CARD_PREFIX_PROP "/cah/cards/"
$def CARD_CURRENT_PREFIX_PROP "/cah/currentIndex/"
$def CARD_IN_PLAY_PROP "/cah/currentInPlay"
$def PLAYER_PREFIX_PROP "/cah/players/"
$def PLAYER_MAP_PROP "/cah/playermap"

( These are meant to be appended to the end of a player prop )
$def PLAYER_CARDS_SUFFIX_PROP "/cards"
$def PLAYER_CARDS_SELECTION_SUFFIX_PROP "/cardselection"
$def PLAYER_SCORE_SUFFIX "/score"
$def PLAYER_JOINED_SUFFIX "/joined"
$def CARDS_SELECTION_EXTRA_SUFFIX_PROP "/extra/"

$def CARD_SKIP_ID "SKIP"

$def LIST_SEPARATOR ","
$def CARD_SEPARATOR "  [|]  "

$def BEGIN_CUSTOM "["
$def END_CUSTOM "]"

$def DAEMON_SLEEP_INTERVAL   600
$def INACTIVITY_CLEANUP_TIME 3600
$def CARDS_PER_PLAYER 10
$def MIN_BLACK_CARDS 5

$def BLACK_CARD "black"
$def WHITE_CARD "white"

$def BLANK_SYMBOL_REGEX "_+"
$def BLANK_SYMBOL "_"

( The valid states )
$def NOT_INITIALIZED_STATE "not_initialized"
$def INACTIVE_STATE "inactive"
$def JOIN_STATE "join"
$def CARD_SELECT_STATE "card_select"
$def JUDGE_STATE "judge"

lvar trigLocation

: clearstack ( -- less items on stack )
        BEGIN
         depth if pop else break then
        UNTIL
;
  
: blankline ( -- )
        me @ " " notify exit
;

: sysMessage ( s --   Prefixes 'cah: ' to string and outputs completed string to user )
        me @ swap "cah: " swap strcat notify
;

: sysMessageAll ( s -- Tells everyone in the room the system message )
    "cah: " swap strcat
    trigLocation @ #-1 rot notify_except
;

: gameMessage (d s -- Prefixes something in front of string to indicate a normal
                      game message.  Works like notify )
    "Ds" checkargs
    "## " swap strcat notify
;

( ----- LOCK STUFF ----- )
: lockDB ( s --   Marks the DB as locked with string s as the reason. )
        ( If it's already locked, abort program )
        preempt
        trig "/lockuser" getpropval 0 = not if "Internal error: Database already locked!  Try again later." abort then
  
        trig "/locked" rot setprop
        trig "/lockuser" me @ setprop
        foreground
;

: unlockDB ( --  Marks the DB as unlocked )
        preempt
        trig "/locked" remove_prop
        trig "/lockuser" remove_prop
        foreground
;

: isLocked? ( -- i  Returns true if database is locked )
        trig "/locked" getpropstr strlen
;

: lockDBwait ( s --  Works like lockDB, only it waits for the
               lock to be free.  s is the reason for the lock.
               If empty, lock is not performed, but will still wait. )
    0 var! waitMessageShown

    preempt
    isLocked? not if
        dup strlen if
            ( Not locked, so grab it while we can! )
            lockDB
        else
            ( Locking is not desired - just wanted to wait for it )
            pop
        then
        
        foreground
    else
        ( Wait until unlocked )
        foreground
        BEGIN
            1 sleep
            preempt
            isLocked? not if
                ( Finally found it to be unlocked.  Lock and return )
                dup strlen if
                    lockDB
                else
                    ( Locking is not desired - just wanted to wait for it )
                    pop
                then
                foreground
                
                waitMessageShown @ if
                    "Database unlocked.  Resuming execution..." sysMessage
                then
                
                BREAK
            else
                foreground

                waitMessageShown @ not if
                    1 waitMessageShown !
                    
                    ( Show the message once, indicating we're retrying )
                    "Database locked by player " trig "/lockuser" getprop
                    name strcat " for: " strcat trig "/locked" getpropstr
                    strcat sysMessage
                    "Waiting for unlock... (Type '@Q' to abort program)"
                    sysMessage
                then

                me @ awake? not if "Player disconnected during lockDBwait.  Possible internal cah problem?" abort then
            then
        REPEAT
    then
;
  
: lockHold ( -- )
    "" lockDBwait
;

( ---------  Utility functions ------------- )

: getState ( -- s  Gets the game state as a string )
    trig STATE_PROP getpropstr

    ( If not set, make it the not initialized state )
    dup not if
        pop
        NOT_INITIALIZED_STATE
    then
;

: setState ( s -- Sets the game state as the string )
    "S" checkargs
    
    trig STATE_PROP rot setprop
;

: checkState ( s -- Confirms the game state is currently s, and aborts
                    if not )
    "S" checkargs
    dup
    
    getState strcmp if
        "Expected state " swap strcat ", but got " strcat getState strcat abort
    else
        pop
    then
;

: howManyBlanks (str -- i  Given a string, indicates how many blanks ___ there
                           are.  This is used only for black cards. )
    "s" checkargs
    0 var! blanks
  
    BEGIN
        ( Find the next blank )
        dup BLANK_SYMBOL_REGEX 0 regexp pop
        ( get matching string if any, get length of string. )
        dup array_count if
            ( Found a match )
            blanks ++
            ( get length of matching ___ )
            0 [] strlen
            ( find where the blank starts)
            over BLANK_SYMBOL instr
  
            ( Sanity check )
            dup not if
                "howManyBlanks(): Got regexp match but not instr!" abort
            then
  
            ( Stack now has: string size_of_blank start_of_blank)
            ( Cut out leading blank from string so we can loop around and find
              the next blank )
            + strcut swap pop
        else
            ( Nothing else matches, we're done )
            pop pop
            break
        then
    REPEAT

    ( Some cards don't have any blanks, but that equals 1 )
    blanks @ not if
        1
    else
        blanks @
    then
;

: getCardText ( s1 s2 -- s3  Given card ID s1 and card group s2, return the card
                             text, or empty string if it doesn't exist )
    "SS" checkargs
    
    ( Create the card prop string )
    CARD_PREFIX_PROP swap strcat "/" strcat swap strcat
    trig swap getpropstr
    
    ( What's left is the card text - return it )
;
  
: freeform? (s -- i  Returns true if white card ID s indicates freeform card )
    "S" checkargs

    WHITE_CARD getCardText
    BLANK_SYMBOL instr
;

: getCardList ( s -- dict  Given a prop s, return the card ID listing as a dict
                           where key == value, both strings, or empty
                           dict if nothing found )
    "S" checkargs
    
    trig swap getpropstr
    
    dup if
        ( Deepest item is always "" since there's always a separator at the end )
        LIST_SEPARATOR explode
        pop
        ( For each exploded string, turn into the dictionary, and stop at the 0 )
        { }dict
        BEGIN
            ( Get next item )
            swap
            
            dup if
                ( Put into dictionary )
                swap over array_insertitem
            else
                ( Empty string -- At the end )
                pop BREAK
            then
        REPEAT
    else
        ( Nothing was there )
        pop
        { }dict
    then
    
    ( Return the dictionary )
;

: setCardList ( s dict -- Given a prop s and a dictionary of card indexes as
                          strings, where key == value, store the card indexes
                          in the property as a string.  Only the key is used)
    "S?" checkargs
    
    ( Create the string to store )
    ""
    swap FOREACH
        ( ignore value )
        pop
        
        strcat LIST_SEPARATOR strcat
    REPEAT
    
    ( Save it )
    trig -3 rotate setprop
;

: clearCardSelection ( d --  Removes the currently selected cards from the
                             given player )
    "d" checkargs
    trig PLAYER_PREFIX_PROP rot intostr strcat
    PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat remove_prop
;

: getPlayerList ( -- a  Gets a list of player dbrefs in the game)
    { }list
    
    PLAYER_PREFIX_PROP
    BEGIN
        trig swap nextprop
        
        ( Check for end )
        dup not if
            pop
            break
        then
        
        ( Extract the player dbref as an int, convert it, add it )
        dup dup "/" rinstr strcut swap pop
        atoi dbref rot array_appenditem swap
    REPEAT
    
    ( All that's left is the list, return it )
;

: holdingWhiteCard? ( s -- i  Given white card ID s, return true if anyone is
                      currently holding it )
    "S" checkargs
    var! cardId

    getPlayerList FOREACH
        ( Remove index )
        swap pop
        
        ( Get the raw list of held cards and do a simple string search to see
          if card is held )
        trig
        PLAYER_PREFIX_PROP rot intostr strcat PLAYER_CARDS_SUFFIX_PROP strcat
        getpropstr
        
        dup cardId @ LIST_SEPARATOR strcat instr 1 =
        swap LIST_SEPARATOR cardId @ strcat LIST_SEPARATOR strcat instr or if
            ( Found it )
            1
            exit
        then
    REPEAT
    
    0
;

: activePlayer? ( d -- i  Returns true if dbref d is in the game )
    "d" checkargs
    
    trig PLAYER_PREFIX_PROP rot intostr strcat propdir?
;

: selectedCards? ( d -- i Returns true if dbref has selected their cards or skipped )
    "d" checkargs
    
    trig PLAYER_PREFIX_PROP rot intostr strcat PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
    getpropstr if 1 else 0 then
;

: admin? ( d -- i  Returns true if player has admin rights for this game )
    "d" checkargs
    
    ( Owner or wizard is always an admin )
    dup trig controls if pop 1 exit then
    
    trig PLAYER_ADMIN_PROP getprop dup if
        =
    else
        ( No admin set yet )
        pop pop
        0
    then
;

: judge? ( d -- i Returns true if dbref is the judge )
    "d" checkargs
    
    trig JUDGE_PROP getprop dup
    dbref? if
        =
    else
        pop pop 0
    then
;

: getCardIdFromIndex (i dict -- s  Given a dictionary of card IDs and an index
                                   from getCardList, return the card ID that
                                   corresponds to the index. The index starts
                                   at 1.  Returns empty string if error or
                                   not found )
    "i?" checkargs
    
    swap var! desiredIndex
    0 var! currentIndex
    
    ( If dictionary is too small, never found )
    dup array_count desiredIndex @ < if pop "" exit then
    
    (cards dict on stack)
    FOREACH
        ( Discard value )
        pop
        currentIndex ++
        
        currentIndex @ desiredIndex @ = if
            ( Found it )
            BREAK
        else
            pop
        then
    REPEAT
    
    ( All that's on the stack is the card ID )
;

: messageAll ( s -- Notifies all players and observers with the provided text,
                 as a game message )
    "s" checkargs
    var! messageToSend
    
    ( Notify players ... )
    getPlayerList FOREACH
        ( Remove index )
        swap pop
        
        dup ok? if
            messageToSend @ gameMessage
        else
            pop
        then
    REPEAT
    
    ( ... then observers )
    trig OBSERVERS_PROP array_get_reflist FOREACH
        ( Remove index )
        swap pop
        
        dup ok? if
            messageToSend @ gameMessage
        else
            pop
        then
    REPEAT
;

: blankLineAll ( -- Notifies all players and observers with a blank line)
    " " messageAll
;

: sanityCheck ( i -- i  Given the number of players that desire to play,
                        return true if the game can support it.  The cards
                        must already be loaded. )
    "i" checkargs
    var! desiredPlayers
    
    desiredPlayers @ 2 < if
        ( Must have at least two players )
        "There must be at least two players." sysMessage
        0 exit
    then
    
    trig CARD_PREFIX_PROP BLACK_CARD strcat getpropval not if
        ( Not enough black cards )
        "The black cards have not been loaded." sysMessage
        0 exit
    then
    
    trig CARD_PREFIX_PROP WHITE_CARD strcat getpropval
    desiredPlayers @ CARDS_PER_PLAYER * 3 +
    < if
        ( Not enough white cards )
        "There are not enough white cards to support the player count, or the cards are not loaded." 
        sysMessage
        0 exit
    then
    
    1
;

: validDbref? ( d -- i  Returns true if the dbref is valid for playing
                        or observing the game )
    "d" checkargs
    
    ( Valid if player or thing, in the room, and awake )
    
    var! target
    
    target @ ok? if
        target @ player? target @ thing? or
        trigLocation @ target @ location = and
        target @ owner awake? and
    else
        0
    then
;

( ---------  Daemon functions ------------- )

: daemonMain ( -- Loops and periodically checks to see if game is totally
                  inactive.  If so, clean it up )
    ( This method is needed because the card lists can be very very large,
      consuming a lot of server and database memory.  This makes sure the cards
      are removed once everyone is done playing with them, conserving memory )
                  
    background
    BEGIN
         DAEMON_SLEEP_INTERVAL sleep
         
         ( See if we're supposed to exit )
         trig DAEMON_PID_PROP getpropval pid = not if
            ( We're supposed to exit )
            pid kill
         then
         
         ( See if game is inactive.  If so, clean it up )
         systime INACTIVITY_CLEANUP_TIME -
         trig ACTIVITY_TIMESTAMP_PROP getpropval > if
            trig CAH_ROOT_PROP remove_prop
            unlockDB
            pid kill
         then
    REPEAT
;

: startDaemon ( --  If the daemon cleanup process hasn't been started, start it.
                    Assumes database is currently locked )
    trig DAEMON_PID_PROP getpropval
    
    ( If a PID that is not active, need to start )
    ispid? not if
        fork
        dup if
            ( Parent process )
            trig DAEMON_PID_PROP rot setprop
        else
            ( Child process - go right to the daemon code )
            pop
            clearstack
            'daemonMain jmp
        then
    then
;

: stopDaemon ( -- If daemon is running, tell it to stop
                  Assumes database is currently locked )
    trig DAEMON_PID_PROP remove_prop
;

( ---------------------------------- )
  
: shuffleCards ( s --  Sorts card group s and puts them into their final prop for
                    use in the game. addCards must have been used previously for
                    the group )
    "S" checkargs
    
    var! cardGroup
    CARD_PREFIX_PROP cardGroup @ strcat "/" strcat var! propPrefix
    CARD_LOADING_PREFIX_PROP cardGroup @ strcat "/" strcat var! loadingPrefix
    0 var! cardsLoaded
    
    "Sorting " cardGroup @ strcat " cards..." strcat sysMessage
    
    ( reset sorted area )
    trig propPrefix @ remove_prop
    
    ( Read in the randomized cards and add them in the order traversed )
    loadingPrefix @
    BEGIN
        trig swap nextprop
        
        dup if
            dup
            cardsLoaded ++
            
            trig swap getpropstr
            trig propPrefix @ cardsLoaded @ intostr strcat rot setprop
        else
            ( All done )
            pop
            BREAK
        then
    REPEAT
    
    ( Set the number of cards loaded )
    trig propPrefix @ cardsLoaded @ setprop
    trig CARD_CURRENT_PREFIX_PROP cardGroup @ strcat cardsLoaded @ setprop
    
    trig loadingPrefix @ remove_prop
    
    ( If none loaded, give an error and exit )
    cardsLoaded @ not if
        trig propPrefix @ remove_prop
        "No " cardGroup @ strcat " were loaded!  Aborted." strcat sysMessage
        unlockDB
        pid kill
    then
;

: addCard ( s1 s2 -- Adds card s1 to the group s2 [black, white] for future
                     sorting.  Can only be used when loading cards.  Use
                     before sortCards )
    "SS" checkargs
    
    CARD_LOADING_PREFIX_PROP swap strcat "/" strcat var! propPrefix
    
    BEGIN
        ( Find an open random slot for the card )
        propPrefix @ random intostr strcat dup
    
        trig swap getprop string? if
            ( Already exists.  Try again. )
            pop
            CONTINUE
        else
            trig swap rot setprop
            BREAK
        then
    REPEAT
;


: pullBlackCard ( -- s  Assuming cards have been shuffled, returns the next
                        random black card ID, looping back to the beginning if
                        needed )
    trig CARD_CURRENT_PREFIX_PROP BLACK_CARD strcat getpropval
    
    dup not if
        pop
        "pullBlackCard():  Current card is 0!  Not initialized?" abort
    then
    
    ( Stringify ID so it remains on the stack to return )
    dup intostr
    
    ( Point to the next randomized card )
    swap --
    dup not if
        ( Reset to the first black card if we're at the beginning )
        pop
        trig CARD_PREFIX_PROP BLACK_CARD strcat getpropval
    then
    
    trig CARD_CURRENT_PREFIX_PROP BLACK_CARD strcat rot setprop
    
    ( All that's on the stack is the newly pulled card, which is returned )
;

: pullWhiteCard ( -- s  Assuming cards have been shuffled, returns the next
                        random white card ID, looping back to the beginning if
                        needed.  Because any card could be held by a player,
                        this will check and skip over cards currently in use )
    0 var! loopedOnce
    "" var! selectedCard

    trig CARD_CURRENT_PREFIX_PROP WHITE_CARD strcat getpropval

    dup not if
        pop
        "pullWhiteCard():  Current card is 0!  Not initialized?" abort
    then
        
    ( Point to the next randomized card )
    BEGIN
        --
        
        dup not if
            pop
            ( At the end; need to loop around to the top card )
            
            ( Protection against infinite loop )
            loopedOnce @ if
                "pullWhiteCard():  ERROR: Already looped once to try and find free card!"
                abort
            then
            
            trig CARD_PREFIX_PROP WHITE_CARD strcat getpropval
            
            1 loopedOnce !
        then

        dup intostr holdingWhiteCard? not if
            intostr selectedCard !
        then
            
    selectedCard @
    UNTIL
    
    trig CARD_CURRENT_PREFIX_PROP WHITE_CARD strcat selectedCard @ atoi setprop
    
    
    ( Return selected card ID )
    selectedCard @
;

: showHeldCards ( d --  Given a player dbref, notify them of their current held
                        card list )
    "D" checkargs
    dup OK? not if pop exit then
    
    var! target

    target @ "Your white cards:" gameMessage

    PLAYER_PREFIX_PROP target @ intostr strcat PLAYER_CARDS_SUFFIX_PROP strcat
        getCardList
  
    FOREACH                
        ( Convert card ID to card text )
        WHITE_CARD getCardText
        
        target @ "    " 4 rotate strcat ": " strcat rot strcat gameMessage
    REPEAT
;

: getPlayerSelectedCards ( d -- s  Given player dbref, return a string
                                   containing all their selected cards,
                                   suitable for display to the user )
    "D" checkargs
    
    PLAYER_PREFIX_PROP swap intostr strcat PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat dup
    CARDS_SELECTION_EXTRA_SUFFIX_PROP strcat var! cardExtraPrefixProp
    
    ( Get the player's selected cards )
    getCardList
    
    ( Go through card list, adding to string the actual card text, or the
      custom entry if found )
    ""
    swap FOREACH
        ( Ignore index )
        swap pop
        
        trig cardExtraPrefixProp @ 3 pick strcat getpropstr dup
        if
            ( Has a custom entry.  Use it instead of the actual card text )
            swap pop
        else
            ( No custom entry, just show the card text )
            pop
            
            WHITE_CARD getCardText
        then
        
        ( Add the card separator at the end, in preparation for the next loop )
        strcat
        CARD_SEPARATOR strcat
    REPEAT
    
    ( String is left on the stack, which is the selected card list )
    
    ( Remove excess separator if any cards were added )
    dup if
        dup CARD_SEPARATOR rinstr 1 - strcut pop
    then
;

: allCardsSubmitted? ( -- i  Checks each player and returns true if all players have
                             submitted at least one card to judge.  The number
                             of cards to judge is checked by the input
                             routine. )
    1 var! allSubmitted
    trig JUDGE_PROP getprop var! judge
    
    getPlayerList FOREACH
        ( Discard index )
        swap pop
        
        ( Don't check the judge, since they never select cards )
        dup judge @ = if
            pop
        else
            PLAYER_PREFIX_PROP swap intostr strcat
            PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
            trig swap getpropstr
            
            not if
                ( Cards not yet submitted for this player )
                0 allSubmitted !
            then
        then
    REPEAT
    
    allSubmitted @
;

: initiateJudging ( -- Anonymizes the selected cards, shows them to everyone,
                       and puts the program in a state to allow the judge to
                       select one )

    trig JUDGE_PROP getprop "D" checkargs var! judge
    CARD_SELECT_STATE checkState
    
    
    ( Insert into dict with random keys )
    { }dict
    getPlayerList FOREACH
        ( Ignore index )
        swap pop
        
        ( The judge cannot be a part of this list )
        dup judge @ = if
            pop
            continue
        then
        
        ( A player who was skipped cannot be part of this list )
        dup trig PLAYER_PREFIX_PROP rot intostr strcat PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
        getpropstr CARD_SKIP_ID strcmp not if
            pop
            continue
        then
        
        ( In case the random number is already in use, loop until new one found )
        BEGIN
            random
            
            3 pick over [] dbref? if
                ( Already exists, try again )
                continue
            then
            
            rot swap ->[]
        1
        UNTIL
    REPEAT
    
    blankLineAll
    "Card selection complete for black card:   "
        trig CARD_IN_PLAY_PROP getpropstr BLACK_CARD getCardText strcat
        messageAll
    judge @ name " must select the winning card(s) using '" strcat
        COMMAND @ strcat " winner':" strcat messageAll
    blankLineAll
    
    ( Convert into array and store as dbreflist)
    array_vals array_make dup
    trig PLAYER_MAP_PROP rot array_put_reflist
    ( On stack: array of randomized players )
    
    ( Get the cards selected for each player, print them out )
    FOREACH
        ( Form the start of the line )
        swap ++ intostr ": " strcat "    " swap strcat
        
        ( Add the cards )
        swap getPlayerSelectedCards strcat
        
        ( Tell everyone )
        messageAll
    REPEAT
    
    blankLineAll
    
    ( set state to initiate judging )
    JUDGE_STATE setState
;

: clearAllPlayerSelections ( --  Used when a round completes, deletes selection
                                 prop on all players in game )
    getPlayerList FOREACH
        ( Ignore index )
        swap pop
        
        clearCardSelection
    REPEAT
;

: getObservers ( -- a  Returns a list of the observer dbrefs )
    trig OBSERVERS_PROP array_get_reflist
;

: addObserver ( d -- Adds an observer to the list, if not already there )
    "D" checkargs
    var! dbrefToAdd

    getObservers
    
    ( See if it's already in the list )
    dup dbrefToAdd @ array_findval array_count if
        ( Already there.  Stop )
        pop
    else
        ( Add observer )
        dbrefToAdd @ swap array_appenditem
        trig OBSERVERS_PROP rot array_put_reflist
        
        dbrefToAdd @ name " is now an observer." strcat messageAll
    then
;

: removeObserver ( d -- Removes an observer from the list if found )
    "d" checkargs
    
    getObservers
    dup rot array_findval
    
    dup array_count if
        ( Found them.  Remove )
        
        ( Get the index of the dbref )
        1 []
        ( Do the actual deletion )
        array_delitem
        
        ( Save it off )
        trig OBSERVERS_PROP rot array_put_reflist
    else
        ( Observer didn't exist in the list )
        pop pop
    then
;

: getObserverNames ( -- s Returns a string consisting of the names of the
                          observers )
    getObservers
    
    ""
    
    swap FOREACH
        ( Ignore index )
        swap pop
        
        name strcat "  " strcat
    REPEAT
    
    dup if
        ( Chop off extra space )
        dup strlen 2 - strcut pop
    then
    
    ( All that's left is the string with the names )
;

: printJudgingCards ( d --  Prints the cards to judge to the provided dbref )
    "D" checkargs
    
    trig PLAYER_MAP_PROP array_get_reflist
    FOREACH
        ( Form the start of the line )
        swap ++ intostr ": " strcat "    " swap strcat
        
        ( Add the cards )
        swap getPlayerSelectedCards strcat
        
        ( Tell the dbref )
        over swap gameMessage
    REPEAT
    pop
;

( Print out players, observers, current score, and who the judge is )
: printStatus ( d -- Print the current game status to the given dbref )
    "D" checkargs
    var! target
    trig JUDGE_PROP getprop var! currentJudge
    
    target @ " " notify
    
    ( Indicate game state )
    target @ "Game state:   "
    getState
    
    dup JOIN_STATE strcmp not if
        pop
        "Open for people to join (type: '"
            COMMAND @ strcat " join')" strcat
    else
        dup CARD_SELECT_STATE strcmp not if
            pop
            "Players are selecting cards to be judged (type: '"
                COMMAND @ strcat " pick <card number(s)>')" strcat
        else
            dup JUDGE_STATE strcmp not if
                pop
                "The judge is selecting the winning card(s) (type: '"
                    COMMAND @ strcat " winner <line number>')" strcat
            else
                pop
                "The game is currently not being played"
            then
        then
    then
    
    strcat gameMessage
    
    ( Players and their scores )
    target @ "Players, score, card selection status:" gameMessage
    
    getPlayerList FOREACH
        ( Ignore index )
        swap pop
        
        ( Player name )
        "    " over name 25 STRleft strcat "  " strcat
        
        ( Player score )
        trig PLAYER_PREFIX_PROP 4 pick intostr strcat PLAYER_SCORE_SUFFIX strcat
        getpropval intostr 5 STRleft strcat
        
        ( If they have selected cards )
        trig PLAYER_PREFIX_PROP 4 pick intostr strcat
            PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
        getpropstr if
            "[Has selected cards]" strcat
        then
        
        ( Indicate if they are the judge )
        swap judge? if
            "[Judge]" strcat
        then
        
        target @ swap gameMessage
    REPEAT
    
    ( List observers )
    target @ "Observers:   " getObserverNames strcat gameMessage
    target @ " " gameMessage
  
    ( List black card, if any )
    trig CARD_IN_PLAY_PROP getpropstr dup if
        target @ "Black card:   " rot BLACK_CARD getCardText strcat gameMessage
        target @ " " gameMessage
    else
        pop
    then
  
    ( List judge )
    currentJudge @ dbref? if
        target @ "Current judge:   " currentJudge @ name strcat gameMessage
        
        getState JUDGE_STATE strcmp not if
            target @ "Cards to judge:" gameMessage
            ( Re-print the cards to judge )
            target @ printJudgingCards
            target @ " " gameMessage
        then
    then
            
    ( List cards held, if playing and not the judge )
    target @ activePlayer? if
        currentJudge @ dbref? if
            target @ currentJudge @ = not if
                target @ showHeldCards
            then
        else
            target @ showHeldCards
        then
    then
;

: showStatusToAll ( -- Shows everyone their individualized status )
    trig JUDGE_PROP getprop var! currentJudge

    getPlayerList FOREACH
        swap pop dup printStatus
        dup " " gameMessage
        
        dup currentJudge @ = if
            ( Judges don't see their cards since they can't play )
            "You are the judge this round and cannot select cards to play."
            gameMessage
        then
    REPEAT

    getObservers FOREACH
        swap pop printStatus
    REPEAT

    currentJudge @ name " is the judge." strcat messageAll
;

: passOutCards ( -- Makes sure everyone has the correct number of cards.  If
                    not, cards will be randomly drawn and added )
    var playerCardsProp
    
    getPlayerList FOREACH
        ( Ignore index )
        swap pop
    
        ( Create the property string )
        PLAYER_PREFIX_PROP swap intostr strcat PLAYER_CARDS_SUFFIX_PROP strcat
        playerCardsProp !
    
        ( Get cards, count them, discard array in case it's reshuffled )
        playerCardsProp @ getCardList array_count
        
        ( Determine how many cards to draw, if any )
        CARDS_PER_PLAYER swap -
        
        dup 0 > if
            ( Draw cards )
            { }list
            0 rot -- 1 FOR
                ( Iteration count not important )
                pop
                
                pullWhiteCard swap array_appenditem
            REPEAT
        
            ( Get cards from player again, append cards from list )
            playerCardsProp @ getCardList
            swap FOREACH
                ( Discard index )
                swap pop
                
                swap over ->[]
            REPEAT
        
            ( Store cards )
            playerCardsProp @ swap setCardList
        else
            ( They already have the right number of cards )
            pop
        then
    REPEAT
;

: selectJudge ( -- d  Selects the next judge, sets it on the judge prop, and
                      returns the dbref )
    trig JUDGE_PROP getprop var! currentJudge
    getPlayerList var! playerList
    
    currentJudge @ int? not if
        ( Judge already existing.  Select the one next in the list )
        playerList @ currentJudge @ array_findval
        
        ( Sanity check )
        dup array_count not if
            ( Judge not found, so pick random by going back in )
            pop
            trig JUDGE_PROP remove_prop
            selectJudge
            exit
        then
        
        ( Get the index )
        0 []
        
        ( Determine if we need to loop the index back around, or if we can just
          use the next entry )
        dup playerList @ array_count -- = if
            ( We're at the end.  Start over )
            pop
            0
        else
            ( Not at the end, just advance to the next player )
            ++
        then
        
        ( save it, returning the dbref to the caller )
        playerList @ swap [] dup trig JUDGE_PROP rot setprop
    else
        ( No existing judge, pick one randomly )
        playerList @ random over array_count % [] dup
        trig JUDGE_PROP rot setprop
        ( dbref of judge is left on the stack.  Return it )
    then
;

: removePlayer ( d -- Removes player with dbref d if found )
    "d" checkargs
    
    var! target
    
    PLAYER_PREFIX_PROP target @ intostr strcat dup
    
    trig swap propdir? if
        trig swap remove_prop
                        
        target @ ok? if
            target @ name " has been removed from the game." strcat
        else
            "Invalid dbref removed from the game."
        then
        messageAll
        
        target @ judge? if
            ( Currently the judge, select a new one )
            selectJudge
            name " is the new judge." strcat messageAll
        then
        
        getState CARD_SELECT_STATE strcmp not if
            allCardsSubmitted? if
                ( Everyone is done - start judging )
                initiateJudging
            then
        then
    else
        ( Not found, do nothing )
        pop
    then
;

: addPlayer ( d --  Adds dbref d as a game player and lets everyone know.
                    Checks for validity )
    "D" checkargs
    dup var! target
    
    ( Don't allow more players than available cards, when joining mid-game )
    getState JOIN_STATE strcmp if
        getPlayerList array_count 1 + sanityCheck not if
            exit
        then
    then
    
    validDbref? if
        ( Don't re-add if already in the game )
        PLAYER_PREFIX_PROP target @ intostr strcat dup var! targetPropPrefix
        
        target @ removeObserver
        
        trig swap propdir? not if
            ( Needs to be added )
            trig targetPropPrefix @ PLAYER_SCORE_SUFFIX strcat 0 setprop
            trig targetPropPrefix @ PLAYER_JOINED_SUFFIX strcat 1 setprop
            
            ( Determine if new player needs cards.  This only happens if
              they're in a state where cards were already passed out )
            getState CARD_SELECT_STATE strcmp not if
                ( Draw full set of cards and save them )
                { }dict
                0 CARDS_PER_PLAYER -- 1 FOR
                    ( Iteration count not important )
                    pop
                    
                    pullWhiteCard swap over ->[]
                REPEAT
                
                targetPropPrefix @ PLAYER_CARDS_SUFFIX_PROP strcat swap setCardList
            then
        then
        
        target @ name " has been added as a CAH game player." strcat messageAll
    else
        "Invalid object (not valid to play the game): " target @ unparseobj strcat
        sysMessage
    then
;

: removeInvalids ( -- Removes Observers or Players that are no longer in the
                      room )
                      
    ( Removes any game players who are no longer in the room )
    getPlayerList FOREACH
        ( Remove index )
        swap pop
        
        dup validDbref? not if
            ( Recycled )
            removePlayer
        else
            dup location trigLocation @ = not if
                ( No longer here )
                removePlayer
            else
                ( OK )
                pop
            then
        then
    REPEAT
    
    getObservers FOREACH
        ( Remove index )
        swap pop
        
        dup validDbref? not if
            ( Recycled )
            removeObserver
        else
            dup location trigLocation @ = not if
                ( No longer here )
                removeObserver
            else
                ( OK )
                pop
            then
        then
    REPEAT
    
    getState JUDGE_STATE not if
        trig JUDGE_PROP getprop printJudgingCards
    then
;

: judgeParser ( s -- Takes a string from the judge, parses it to determine the
                     winner, updates the score, picks a new judge,
                     prepares the game for the next state, then changes the game
                     state )
    "s" checkargs
    JUDGE_STATE checkState
    
    strip
    0 var! judgeSelection
    
    ( Confirm this is the judge )
    trig JUDGE_PROP getprop var! judgeDbref
    
    me @ judgeDbref @ = not if
        pop
        "You are not the judge!" sysMessage
        exit
    then
    
    ( Protect against missing input )
    dup number? not if
        pop
        "Please indicate the number of the winning card(s)." sysMessage
        exit
    then
    
    ( Convert it into an int )
    atoi judgeSelection !
    
    ( Make sure the selection makes sense )
    judgeSelection @ 0 <= if
        "Invalid selection.  Indicate the number of the winning card(s) from the numbered list."
        sysMessage
        exit
    then

    ( Arrays are 0 indexed )
    judgeSelection --

    ( Get the lookup map to find the winner )
    trig PLAYER_MAP_PROP array_get_reflist var! cardMap
    
    ( Make sure it's not out of range )
    judgeSelection @ cardMap @ array_count >= if
        "Invalid selection.  Indicate the number of the winning card(s) from the numbered list."
        sysMessage
        exit
    then
    
    ( Entry is valid.  Select the winner, increase the score,
      announce the winner, and change the game state )
    cardMap @ judgeSelection @ [] var! winnerDbref
    
    winnerDbref @ validDbref? not winnerDbref @ activePlayer? not or if
        "The selection is no longer valid.  Please pick another." sysMessage
        exit
    then
    
    ( Increment score )
    PLAYER_PREFIX_PROP winnerDbref @ intostr strcat PLAYER_SCORE_SUFFIX strcat
    trig over getpropval
    ++
    trig rot rot setprop
    
    ( Announce the winner )
    blankLineAll
      judgeDbref @ name " has selected " strcat
      winnerDbref @ name strcat " as the winner this round:" strcat
    messageAll
    
    "Black card: "
        trig CARD_IN_PLAY_PROP getpropstr BLACK_CARD getCardText strcat
        messageAll
        
    "Winning white card(s): " winnerDbref @ getPlayerSelectedCards strcat
        messageAll

    blankLineAll
    
    ( Clear out selected cards, make sure everyone has a full set of cards,
      selects new black card, selects a new judge, and changes the game state )
    clearAllPlayerSelections
    passOutCards
    trig CARD_IN_PLAY_PROP pullBlackCard setprop
    selectJudge pop
    CARD_SELECT_STATE setState
    showStatusToAll
    
    
;

: playerCardSelectParser ( d s --  Given the player's dbref and commandline
                                 string that represents their card
                                 selection[s], determine if the selections
                                 are valid, are the correct number of
                                 selections, figure out the custom entries,
                                 etc, and puts them in the selection prop )
    "Ds" checkargs
    CARD_SELECT_STATE checkState
    
    strip var! selectString
    var! target
    
    ( Validate not a judge )
    target @ judge? if
        target @ "You are a judge and therefore cannot select cards this round." sysMessage
        exit
    then
    
    ( Validate not empty )
    selectString @ not if
        target @ "Please select cards by number." sysMessage
        exit
    then
    
    ( Validate not already selected cards )
    trig
    PLAYER_PREFIX_PROP target @ intostr strcat PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
    getpropstr if
        target @ "You have already selected cards." sysMessage
        exit
    then
    
    ( Figure out what cards were selected, and grab custom if available )
    ( "23 54 25 [My custom entry] 10" )
    
    ( Add a space at the end to keep logic easy )
    selectString @ " " strcat selectString !
    
    ( Get their map of currently held cards )
    PLAYER_PREFIX_PROP target @ intostr strcat PLAYER_CARDS_SUFFIX_PROP strcat
    getCardList var! cardsHeld
    
    ( Search for " " until found, parse if card, determine if custom.  If custom, look for [ ], use as is.)
    1 var! keepSearching
    0 var! currentPosition
    "" var! selectedCard
    "" var! freeformText
    { }DICT var! selectedCards
    
    BEGIN
        selectString @ dup " " instr strcut striplead selectString ! strip selectedCard !
        
        ( Expecting the number of the card to play )
        selectedCard @ if
            selectedCard @ number? if
                ( See if holding card )
                cardsHeld @ selectedCard @ [] string? not if
                    ( Card not found - abort )
                    target @ "Invalid selection (you don't own one of the cards or you used a card twice)." sysMessage
                    
                    ( Remove anything stored in selected cards )
                    target @ clearCardSelection
                    exit
                then
                
                ( If freeform, then look for brackets )
                selectedCard @ freeform? if
                    selectString @ BEGIN_CUSTOM instr 1 = not
                    selectString @ END_CUSTOM instr 1 > not or
                    if
                        ( Did not follow the correct format - abort )
                        target @ "Invalid selection (incorrect freeform format - check help screen)." 
                        sysMessage
                        
                        ( Remove anything stored in selected cards )
                        target @ clearCardSelection
                        exit
                    else
                        ( Extract the freeform text and remove it from select string )
                        selectString @ dup END_CUSTOM instr strcut striplead selectString !
                        dup strlen -- strcut pop
                        1 strcut swap pop strip
                        freeformText !
                    then
                then
                
                
                ( Add to list, set freeform prop if applicable, remove from held )
                selectedCard @ selectedCards @ selectedCard @ ->[] selectedCards !
                freeformText @ if
                    trig PLAYER_PREFIX_PROP target @ intostr strcat
                         PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
                         CARDS_SELECTION_EXTRA_SUFFIX_PROP strcat
                         selectedCard @ strcat
                    freeformText @ setprop
                then
                
                cardsHeld @ selectedCard @ array_delitem cardsHeld !
                
                "" freeformText !
            else
                target @ "Invalid selection (number expected)." sysMessage
                
                ( Remove anything stored in selected cards )
                target @ clearCardSelection
                exit
            then
        then

        ( exit when there's nothing left to parse )
        selectString @ not
    UNTIL
        
    ( Confirm needed card count matches )
    selectedCards @ array_count
    trig CARD_IN_PLAY_PROP getpropstr BLACK_CARD getCardText howManyBlanks
    = not if
        target @ "Invalid selection (you did not select enough cards, or too many)." sysMessage
    
        ( Remove anything stored in selected cards )
        target @ clearCardSelection
        exit
    then
        
    ( Add cards to list in order, set updated list of held cards )
    PLAYER_PREFIX_PROP target @ intostr strcat PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
    selectedCards @ setCardList
    
    PLAYER_PREFIX_PROP target @ intostr strcat PLAYER_CARDS_SUFFIX_PROP strcat
    cardsHeld @ setCardList
    
    target @ "Cards selected." sysMessage
;


( main game driver )


: helpScreen ( -- Shows the helps screen )
  {
    "Cahclone v0.98  2018  Morticon@SpinDizzy - Thanks Daisy and Sondra!"
    " "
    "  This program allows playing a Cards Against Humanity type game on the MUCK."
    " "
    " Parameters: "
    "   reset   -  Clears and resets everything, including erasing all loaded cards"
    "   new     -  Creates a new game, prompting to load cards as needed" 
    "   start   -  Starts a game after the initial players have joined"
    "   stop    -  Ends a game early"
    "   status  -  Shows current game status, held cards, etc"
    "   join    -  Joins a game about to start or already in progress"
    "   observe -  Watches a game in progress"
    "   leave   -  Leaves a game (either as a player or watcher)"
    "   unlock  -  Only use if game crashed and is always locked"
    " "
    "   kick <player>  -  Kicks the named player from the game"
    "   skip <player>  -  Skips the named player just for the current round"
    " "
    "   pick <cards>   -  During card selection, picks the cards you want to"
    "   p    <cards>        be judged."
    "                       Example:  pick 1 2 3"
    "                       Example (for custom card 1): pick 1 [Custom text] 5"
    "   winner <entry> -  Used by the judge to select the winning entry number"
    "   w      <entry>      Example:  winner 4"
  }list
  
  { me @ }list
  
  array_notify
;

: makeNewGame ( -- Starts a new game, loading cards if needed )
    ( Set admin )
    trig PLAYER_ADMIN_PROP me @ setprop

    getState NOT_INITIALIZED_STATE strcmp not if
        ( Need to load cards first )
        
        "Card loading required.  Follow directions below:" sysMessage
        
        "BLACK card loading.  Enter one card per line, use '.' on a line when done.  Use one or more underscores (_) to indicate fill in the blanks."
        sysMessage
        me @ ">>" notify
        
        foreground
        0 var! cardCounter
        "" var! cardInput
        
        BEGIN
            read strip cardInput !
            
            ( End )
            cardInput @ "." strcmp not if break then
            
            cardInput @ howManyBlanks if
                cardInput @ BLACK_CARD addCard
                cardCounter ++
                
                cardCounter @ 50 % not if
                    ( Give a progress message )
                    "Loaded " cardCounter @ intostr strcat " BLACK cards so far." strcat
                    sysMessage
                then
            else
                "Skipping card [" cardInput @ strcat "] because it has no blanks." strcat
                sysMessage
            then
        REPEAT

        cardCounter @ MIN_BLACK_CARDS >= not if
            "You did not add enough black cards.  Aborted." sysMessage
            trig CARD_LOADING_PREFIX_PROP remove_prop
            exit
        then
        
        blankline
        "WHITE card loading.  Enter one card per line, use '.' on a line when done.  Use one or more underscores (_) to indicate a freeform card."
        sysMessage
        me @ ">>" notify
        
        0 cardCounter !
        "" cardInput !

        BEGIN
            read strip cardInput !
            
            ( End )
            cardInput @ "." strcmp not if break then
            
            cardInput @ if
                cardInput @ WHITE_CARD addCard
                cardCounter ++
                
                cardCounter @ 50 % not if
                    ( Give a progress message )
                    "Loaded " cardCounter @ intostr strcat " WHITE cards so far." strcat
                    sysMessage
                then
            else
                "Skipping empty card." sysMessage
            then
        REPEAT
        
        cardCounter @ CARDS_PER_PLAYER >= not if
            "You did not add enough white cards.  Aborted." sysMessage
            trig CARD_LOADING_PREFIX_PROP remove_prop
            exit
        then

        ( Got all cards, sort them )
        BLACK_CARD shuffleCards
        WHITE_CARD shuffleCards
    then
    
    ( Has cards, now prep props for new game )
    trig PLAYER_PREFIX_PROP remove_prop
    trig PLAYER_MAP_PROP remove_prop
    trig JUDGE_PROP remove_prop
    trig CARD_IN_PLAY_PROP remove_prop
    
    ( Put game in state so others can join )
    JOIN_STATE setState
    
    "New game created.  Players (including yourself) may 'join' the game.  "
        "Let everyone know they can join!" strcat
    sysMessage
;

: parseArguments ( s -- Parses and executes commandline arguments )
    "s" checkargs
    strip var! args
        
    ( -- RESET -- )
    args @ "reset" stringcmp not if
        "parseArguments - reset" lockDBwait
        
        ( Allowed if admin or game is not currently running )
        getState NOT_INITIALIZED_STATE strcmp not
        getState INACTIVE_STATE strcmp not
        or
        me @ admin? or if
            stopDaemon
            trig CAH_ROOT_PROP remove_prop
            "All game data reset." sysMessage
        else
            "You do not have permission to reset the game." sysMessage
        then
        
        unlockDB
        exit
    then
    
    ( -- NEW -- )
    args @ "new" stringcmp not if
        "parseArguments - new" lockDBwait
        
        getState NOT_INITIALIZED_STATE strcmp not
        getState INACTIVE_STATE strcmp not
        or if
            makeNewGame
            startDaemon
        else
            "Game is already in progress.  Cannot make a new game." sysMessage
        then
        
        unlockDB
        exit
    then
    
    ( --START-- )
    args @ "start" stringcmp not if
        "parseArguments - start" lockDBwait
    
        removeInvalids
    
        getState JOIN_STATE strcmp if
            "Cannot start.  Either a game is in progress, or a new game has not been initiated."
            sysMessage
        else
            ( Make sure it's reasonable to start )
            
            me @ admin? not if
                "You do not have permission to start the game." sysMessage
            else
                getPlayerList array_count sanityCheck if
                    ( Get the cards passed out, select a black card, select a
                      judge and start! )
                    "Starting new game." messageAll
                    "Passing out cards..." messageAll
                    passOutCards
                    selectJudge pop
                    trig CARD_IN_PLAY_PROP pullBlackCard setprop
                    
                    CARD_SELECT_STATE setState
                    
                    ( All set.  Let everyone see their current status )
                    showStatusToAll
                    
                    startDaemon
                else
                    "There are not enough players or cards to start the game."
                    sysMessage
                then
            then
        then
    
        unlockDB
        exit
    then
    
    ( --STOP-- )
    args @ "stop" stringcmp not if
        "parseArguments - stop" lockDBwait
        
        me @ admin? not if
            "You do not have permission to stop the game." sysMessage
        else
            getState JUDGE_STATE strcmp not
            getState CARD_SELECT_STATE strcmp not
            or if
                me @ name " has stopped the game.  GAME OVER." strcat messageAll
                INACTIVE_STATE setState
            else
                "The game is not currently active and therefore cannot be stopped." sysMessage
            then
        then
        
        unlockDB
        exit
    then
    
    ( -- STATUS -- )
    args @ "status" stringcmp not if
        "parseArguments - status" lockDBwait
        
        me @ printStatus
        
        unlockDB
        exit
    then
    
    ( -- JOIN -- )
    args @ "join" stringcmp not if
        "parseArguments - join" lockDBwait
    
        removeInvalids
    
        JOIN_STATE getState strcmp not
        CARD_SELECT_STATE getState strcmp not or
        if
            me @ addPlayer
            me @ printStatus
        else
            "The game is not ready for you to join.  "
            "Try again later or make a new game." strcat
            sysMessage
        then
    
        unlockDB
        exit
    then

    ( -- OBSERVER -- )
    args @ "observe" stringcmp not if
        "parseArguments - observe" lockDBwait
    
        removeInvalids
    
        NOT_INITIALIZED_STATE getState strcmp not if
            "The game is uninitialized.  Wait until a new game has been made to become an observer."
            sysMessage
        else
            getPlayerList me @ array_findval array_count if
                "You are already playing!  You do not need to be an observer."
                sysMessage
            else
                me @ addObserver
            then        
        then
        
        unlockDB
        exit
    then
    
    ( -- LEAVE -- )
    args @ "leave" stringcmp not if
        "parseArguments - leave" lockDBwait

        removeInvalids

        NOT_INITIALIZED_STATE getState strcmp if
            me @ removeObserver
            me @ removePlayer
        then

        "You have been completely removed from the game." sysMessage

        unlockDB
        exit
    then
    
    ( -- UNLOCK -- )
    args @ "unlock" stringcmp not if
        me @ admin? if
            isLocked? if
                "Unlocking game..." sysMessage
                3 sleep
                removeInvalids
                unlockDB
                "Done." sysMessage
            else
                "Game is not currently locked." sysMessage
            then
        else
            "Permission denied." sysMessage
        then
        
        exit
    then
    
    ( -- KICK <player> -- )
    args @ "kick" instring 1 = args @ " " instring 1 > and if
        "parseArguments - kick" lockDBwait
        
        removeInvalids
        
        ( See if we're in the right state to kick someone out )
        getState JUDGE_STATE strcmp not
        getState JOIN_STATE strcmp not
        getState CARD_SELECT_STATE strcmp not or or
        if
            me @ admin? if
                args @ dup " " instr strcut swap pop strip
                ( Find the person to kick )
                match dup ok? if
                    removePlayer
                    "Kick complete." sysMessage
                else
                    pop
                    "Could not find character or ambiguous." sysMessage
                then
            else
                "Permission denied." sysMessage
            then
        else
            "You cannot kick someone out right now." sysMessage
        then
        
        unlockDB
        exit
    then
    
    ( -- SKIP <player> -- )
    args @ "skip" instring 1 = args @ " " instring 1 > and if
        "parseArguments - skip" lockDBwait
    
        removeInvalids
    
        getState CARD_SELECT_STATE strcmp not if
            me @ admin? if
                args @ dup " " instr strcut swap pop strip
                ( Find the person to kick )
                match dup ok? if
                    var! target
                    ( Valid dbref, now see if they're a player )
                    target @ activePlayer? if
                        ( See if they have already selected cards )
                        target @ selectedCards? target @ judge? or if
                            ( Already have selected or skipped.  Can't skip )
                            "That character has already selected cards or skipped."
                            sysMessage
                        else
                            ( Mark as skipped )
                            trig PLAYER_PREFIX_PROP target @ intostr strcat PLAYER_CARDS_SELECTION_SUFFIX_PROP strcat
                            CARD_SKIP_ID setprop
                            target @ name " has been skipped." strcat messageAll
                            
                            allCardsSubmitted? if
                                ( Everyone is done - start judging )
                                initiateJudging
                            then
                        then
                    else
                        "That person is not currently playing the game."
                        sysMessage
                    then
                else
                    pop
                    "Could not find character or ambiguous." sysMessage
                then
            else
                "Permission denied." sysMessage
            then
        else
            "You cannot skip someone right now." sysMessage
        then
    
        unlockDB
        exit
    then
    
    ( -- PICK <cards> -- )
    args @ "pick" instring 1 = args @ " " instring 1 > and
    args @ "p " instring 1 =
    or if
        "parseArguments - pick" lockDBwait
    
        removeInvalids
        
        getState CARD_SELECT_STATE strcmp not if
            ( Make sure they are in the game and have not selected cards already )
            me @ activePlayer? if
                me @ selectedCards? not if
                    me @ judge? if
                        "Judges cannot pick cards." sysMessage
                    else
                        me @
                        args @ dup " " instr strcut swap pop strip
                        playerCardSelectParser
                        
                        allCardsSubmitted? if
                            ( Everyone is done - start judging )
                            initiateJudging
                        then
                    then
                else
                    "You have already selected your cards this round." sysMessage
                then
            else
                "You are not currently in the game.  Please join it first." sysMessage
            then
        else
            "Cards cannot be selected right now." sysMessage
        then
        
        unlockDB
        exit
    then
    
    ( -- WINNER <entry> -- )
    args @ "winner" instring 1 = args @ " " instring 1 > and
    args @ "w " instring 1 =
    or if
        "parseArguments - winner" lockDBwait

        removeInvalids

        getState JUDGE_STATE strcmp if
            "You cannot judge at this time." sysMessage
        else
            args @ dup " " instr strcut swap pop strip judgeParser
        then
                
        unlockDB
        exit
    then
    
    helpScreen
;

: main
    "me" match me !

    ( Find nearest containing room for action )
    trig
    BEGIN
        location
        
        dup room? if
            trigLocation !
            break
        then
    REPEAT
    
    trig ACTIVITY_TIMESTAMP_PROP systime setprop

    parseArguments
;
.
c
q
@set cah-clone.muf=3
@set cah-clone.muf=W
@set cah-clone.muf=L
@set cah-clone.muf=!D
