( /quote -dsend -S '/data/spindizzy/muf/vote210.muf )

(
need:
    Add color
)


@prog vote.muf
1 9999 d
i

(  VOTE.MUF  v2.10 by Morticon of Spindizzy )
  
(To install this program [wizzes only] do something like a
 /quote -dsend 'vote201.muf    under TF.  basically, just cut and
 paste this file.  It will make the program, enter the editor, compile,
 and finally set the privs [WM3].  After that, add it to plib if you have it
  and, optionally, do a  @set vote.muf=/_docs:@list <PROG DB#>=10=18
 See line 153 or so [BEFORE uploading to muck server] if you want to give
   users shinies for voting )
  
( For the end user:  To use, make an action [call it 'vote', for an example]
  and link it to this program.  Then, type 'vote #help' to get started.
  
  To let people 'look' at your voting object to see the vote topics, add
  something to the desc of the object like {nl}{muf:#1234,5678}  Where
  1234 is the vote.muf db #, and 5678 is the db # of the action that is the
  voting booth )
  
( BEGIN PROGRAM )
$include $lib/strings
$include $lib/nu-ansi-free

( Uncomment second line to give money for voting )
$def REWARDVOTE
( $def REWARDVOTE me @ 5 addpennies "Credited you 5 monetary units for voting" sysMessage )
$def ALTCHECK 1


$def VOTEVERSION 210
$def VERSIONPROP "/votecfg/version"
$def BOOTHOPENPFX "/@/vote/open/"
$def BOOTHCLOSEDPFX "/@/vote/closed/"
$def ALTLISTPROP "/@pc/aka"
$def LOCKEDPROP "/lockedby"

(For instant runoff: Winner if > this percent of votes for a round )
$def IRVWINNERPCT 50
$def CHOICESEP ","
( Length of topic column in IRV result screen )
$def IRVCOLCHOICELEN 15
( Length of result columns in IRV result screen )
$def IRVCOLVOTECOUNTLEN 3
$def IRVCOLSEP " "

lvar votetopic
lvar counter
lvar dump
lvar choice
lvar input
lvar topicToShow
( used in some spots to indicate user owns a topic )
lvar ownerStatus ( true if owns the topic being processed )
lvar lockStatus  ( dbref of who locked it if topic is locked )
  
: clearstack ( -- less items on stack )
(Keeps the stack from accidently getting too big)
        depth 4 > if me @ "## >>>> Stack leak? <<<<" notify then
        
        BEGIN
         depth 3 > if pop then
         depth 3 > not
        UNTIL
        exit
;

: blankline ( -- )
        me @ " " notify exit
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
        "<In Vote> " me @ name strcat " " strcat swap strcat .tell
      else
        dup me @ swap "<In Vote> You " me @ "_say/def/say" getpropstr 
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

: do_read  ( -- s  Acts like read, but allow in program poses and says.  Does
             not allow blanks )
begin
  read striplead
  
  dup strlen not if
    ( Empty strings not allowed - side affect of read wants blanks )
    pop
    continue
  then
  
  dup ":" instr 1 =
  over "\"" instr 1 = or
while
  in-program-tell
repeat
;

: do_read_allow_blanks ( -- s Same as do_read, but allows for blanks )
begin
  read striplead
  dup ":" instr 1 =
  over "\"" instr 1 = or
while
  in-program-tell
repeat
;
( ----------- )

: getYesNo ( -- s Returns either a "yes" or "no" string, prompting the user
                  for it until they give a valid answer )
    BEGIN
        do_read strip
        dup "{yes|no}" smatch if tolower break then
        pop
        me @ "Please enter 'yes' or 'no'." notify
    REPEAT
;

: pause  ( -- )
        blankline
        me @ "--Output paused.  Press ENTER to continue--" notify
        do_read_allow_blanks pop
        blankline
;

: playerName ( i -- s)
( Given an integer or dbref, returns a string with the name of the player, or returns '*Toaded Player*' if needed)
        dup dbref? not if dbref then
        dup player? if name else pop "*Toaded Player*" then
        exit
;

: getPropSuffix ( s -- s'  Given a prop s, return the prop s' at the end
                                of the propdir name.  Example: abc/def/2 returns
                                2.  "" is returned if error or empty string )
    "s" checkargs
    
    ( Cut the string after the last /, then discard the prefix and
      return the suffix )
    dup "/" rinstr strcut swap pop
;

: sysMessage ( s --   Prefixes 'vote: ' to string and outputs completed string to user )
        me @ swap "vote: " swap strcat notify
;

: progExit
        "Program ended." sysMessage
        pid kill
;

: checkValidTopic ( s -- Given the full prop to a topic, abort the program if
                    the topic does not exist )
    ( This is a lazy placeholder for properly dealing with topics being closed
      while someone is voting on them.  It would happen very rarely, if at all,
      so I believe this behavior is adequate for the time being )
    trig swap "/topic" strcat getpropstr strlen not if
        "The topic was closed while you were voting on it." sysMessage
        progExit
    then
;

: isAltVoted? ( d1 s d2 -- i Given a voting booth d1, an open topic s,
                and dbref d2, return 1 if an alt or d2 has voted on the topic,
                or 0 if not )
    "DSD" checkargs
    var! playerDbref
    BOOTHOPENPFX swap strcat "/usersvoted/" strcat var! votedPrefix
    var! boothDbref
    
    boothDbref @ votedPrefix @ playerDbref @ intostr strcat getpropstr strlen if
        ( The player voted )
        1 exit
    then
    
$ifdef ALTCHECK
    ( Get list of player's alts )
    playerDbref @ ALTLISTPROP array_get_reflist
    FOREACH
        ( Discard index )
        swap pop
        
        boothDbref @ votedPrefix @ rot intostr strcat getpropstr strlen if
            ( An alt voted )
            1 exit
        then
    REPEAT
$endif

    ( Neither the player nor alt voted )
    0
;

( ----- LOCK STUFF ----- )
: lockDB ( s -- )
( Marks the DB as locked with string s as the reason. )
        ( If it's already locked, abort program )
        preempt
        trig "/lockuser" getpropval 0 = not if "Internal error: Voting booth already locked!  Try again later." abort then
  
        trig "/locked" rot setprop
        trig "/lockuser" me @ setprop
        foreground
;

: unlockDB ( -- )
( Marks the DB as unlocked )
        trig "/locked" remove_prop
        trig "/lockuser" remove_prop
;

: isLocked? ( -- i )
        trig "/locked" getpropstr strlen
;

: lockDBwait ( s --  Works like lockDB, only it waits for the
               voting booth lock to be free.  s is the reason for the lock. 
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
            2 sleep
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
                "Voting booth unlocked.  Resuming execution..." sysMessage
                BREAK
            else
                foreground

                waitMessageShown @ not if
                    1 waitMessageShown !
                    
                    ( Show the message once, indicating we're retrying )
                    "Voting booth locked by player " trig "/lockuser" getprop
                    playerName strcat " for: " strcat trig "/locked" getpropstr
                    strcat sysMessage
                    "Waiting for unlock... (Type '@Q' to abort program)"
                    sysMessage
                then

                me @ awake? not if "Player disconnected during lockDBwait.  Possible internal vote program problem?" abort then
            then
        REPEAT
    then
;
  
: lockHold ( -- )
    "" lockDBwait
;
  
( -------------- )

: isClosedTopicLocked? ( s -- i  Given a closed topic identifier, returns 0 if
                                 not locked, or the dbref of the person who
                                 locked it if locked. )
    trig BOOTHCLOSEDPFX rot strcat LOCKEDPROP strcat getpropval
;

: isClosedTopicControlledByMe? ( s -- i Given a closed topic identifier,
                                 returns false if current user does not control
                                 it, or true if they do. )
    dup
    
    trig BOOTHCLOSEDPFX rot strcat "/owner" strcat getpropval
    dbref me @ =
    trig BOOTHCLOSEDPFX 4 rotate strcat "/closedby" strcat getpropval
    dbref me @ =
    me @ trig controls
    or or 
;

: voteDisplay ( i -- )
(check to see if there ARE any topics at all. if not, then exit to main menu)
(If i > 0, use it as the DB # of the action to list the topics for.  Example:  i=0, use current action.  i=3423, use action #3423 for topic list)
        dup 0 > if dbref dup input ! me @ swap "/votecfg/name" getpropstr notify else pop trig input ! then

        input @ "/@/vote/open" getpropval not if me @ " " notify me @ "vote: No topics available for voting!" notify exit then
        clearstack
        lockHold
(display voting items as well as how many have voted on them, and if you've voted on them.  Uses nextprop, with /.../end as a sentinel)
        me @ "Open topics:  (** = NEW!)  (r  = Results available)" notify
        blankline
        me @ "_NUM__ _____TOPIC________________________________________________ _# VOTED_" notify
        input @ BOOTHOPENPFX nextprop counter !
        BEGIN
         counter @ strlen if
           input @ counter @ getPropSuffix me @ isAltVoted? not if
             "**"
           else
             input @ counter @ "/allowresults?" strcat getpropstr
             "no" stringcmp if
               "r "
             else
               "  "
             then
           then
           counter @ 13 strcut swap pop 3 STRleft " |   " strcat strcat
           input @ counter @ "/topic" strcat getpropstr 53 strcut pop 54 STRleft
           strcat " |   "
           input @ counter @ "/total" strcat getpropval intostr strcat strcat
           me @ swap notify
         then
         input @ counter @ nextprop counter !
         counter @ strlen not
        UNTIL
        exit
;

: stringChoicesToList ( s i1 i2 -- list  Converts a string s composed of
                  CHOICESEP separated choices to a list of ints, in the order of
                  the string.  i1 is the max choice value [1..i1], and i2
                  is true if verbose output is desired, or false for silence )
    "sii" checkargs
    var! noisy
    var! maxChoice
    { }list var! result
    
    CHOICESEP explode_array
    FOREACH
        ( Get rid of index )
        swap pop
        strip
        ( Skip anything that's empty )
        dup strlen if
            ( Skip anything that's not a number )
            dup number? if
                atoi
                ( Skip anything we've already seen )
                result @ over array_findval array_count not if
                    ( Skip over anything out of range )
                    dup dup 0 > swap maxChoice @ <= and if
                        ( A valid value.  Add to list )
                        result @ array_appenditem result !
                    else
                        noisy @ if
                            "Skipping out of range value: "
                              swap intostr strcat sysMessage
                        else
                            pop
                        then
                    then
                else
                    noisy @ if
                        "Skipping duplicate value: "
                          swap intostr strcat sysMessage
                    else
                        pop
                    then
                then
            else
                noisy @ if
                    "Skipping non-integer value: "
                        swap strcat sysMessage
                else
                    pop
                then
            then
        else
            noisy @ if
                "Skipping empty value." sysMessage
            then
            pop
        then
    REPEAT
    
    result @
;

: choicesListToString ( list -- s  Converts a list made with stringChoicesToList
                          back to a string, normalized )
    "?" checkargs
    
    ""
    swap
    FOREACH
        ( Get rid of index )
        swap pop
        
        intostr strcat CHOICESEP strcat
    REPEAT
    
    ( Get rid of last, excess separator )
    dup strlen
    CHOICESEP strlen
    -
    strcut pop
;
    
: getCards ( s -- dict i   Given a closed topic, returns the voting cards as a
             dict of lists.  Also returns the maximum number of choices any
             voter had )
    "S" checkargs
    { }dict var! usedChoices  (A set -- keys only )
    1 var! maxTopicChoices
    { }list var! cards

    "Getting the voting cards..." sysMessage
        
    ( Figure out how many vote choices there are )
    dup
    BOOTHCLOSEDPFX swap strcat "/" strcat
    BEGIN
        dup
        ( Find the first choice number prop with a blank string. That's the end)
        maxTopicChoices @ intostr strcat trig swap getpropstr
        strlen if
            ( More topic choices )
            maxTopicChoices ++
        else
            ( No more topic choices )
            maxTopicChoices --
            break
        then
    REPEAT
    pop
    
    ( Start going through all the cards in the propdir )
    trig BOOTHCLOSEDPFX rot strcat "/usersvoted/" strcat nextprop dup strlen
    if
        BEGIN
            dup
            ( For each card, convert it into a list of ints )
            trig swap getpropstr maxTopicChoices @ 0 stringChoicesToList

            ( Add choices to set )
            dup
            FOREACH
                ( Get rid of index )
                swap pop
                ( Put choice in set even if already there )
                1 usedChoices @ rot ->[] usedChoices !
            REPEAT
            
            ( Add card to list )
            cards @ array_appenditem cards !
            
            ( Loop evaluation / next property to look at )
            trig swap nextprop dup strlen not
        UNTIL
        pop
    else
        pop
    then
    
    cards @ usedChoices @ array_count
;
  
: showIRVResults ( s -- Display instant runoff results for closed topic s )
    "S" checkargs

    ( The output to the screen is being queued up in 'output' because it
      could take a while to generate.  This way, when it finally comes out,
      there's less of a chance of chatter in the room getting interspersed )
    
    var! irvTopic
    
    { }dict var! shownChoices
    { }list var! output
    BOOTHCLOSEDPFX irvTopic @ strcat "/" strcat var! topicPropPrefix
    topicPropPrefix @ "irvresults/" strcat var! irvPropPrefix
    trig topicPropPrefix @ "irvresults" strcat getpropval var! rounds
    0 var! currentChoice

    rounds @ not if
        "This topic does not exist or is not an IRV-style topic." sysMessage
        exit
    then

    "Building table..." sysMessage
    blankline

    "Full list of choices:" output @ array_appenditem output !
    
    1
    BEGIN
        dup
        intostr ". " strcat
        trig topicPropPrefix @ 4 pick intostr strcat getpropstr dup
        rot swap strcat
        "   " swap strcat output @ array_appenditem output !
        
        swap ++ swap
        strlen not
    UNTIL
    pop
    ( Get rid of last choice, since it's not really there )
    output @ output @ array_count -- array_delitem output !

    " " output @ array_appenditem output !

    ( Generate header  )
    "CHOICE" IRVCOLCHOICELEN STRleft
    1 rounds @ 1 FOR
        "R" swap intostr strcat IRVCOLVOTECOUNTLEN STRleft " " swap strcat
        strcat
    REPEAT
    output @ array_appenditem output !

    ( Main Loop - For i = max rounds to 1)
    rounds @ 1 -1 FOR
        ( For each choice in round )
        BEGIN
            ( Find next choice not in shownChoices )
            0 currentChoice !
            trig irvPropPrefix @ 3 pick intostr strcat "/" strcat nextprop
            BEGIN
                dup
                getPropSuffix dup number? if
                    ( Found a voting choice.  If we havn't seen it before,
                      use it! )
                    atoi

                    shownChoices @ over [] if
                        ( Seen it.  Skip )
                        pop
                    else
                        ( Not seen it.  Use and exit the loop. )
                        currentChoice !
                        break
                    then
                else
                    ( Prop isn't a voting choice, skip )
                    pop
                then

                ( Get the next prop, but exit if we've seen them all )
                trig swap nextprop dup
                strlen not
            UNTIL
            pop

            currentChoice @ if
                ( Using found choice, generate its result line )

                ( Output a truncated choice text )
                trig topicPropPrefix @ currentChoice @ intostr strcat
                getpropstr IRVCOLCHOICELEN STRleft IRVCOLCHOICELEN strcut pop

                ( Then, strcat the number of votes from each round for it )
                1 rounds @ 1 FOR
                    irvPropPrefix @ swap intostr strcat "/" strcat
                    currentChoice @ intostr strcat

                    trig swap getpropval

                    ( If there were 0 votes, just leave the field blank for
                      readability )
                    dup if
                        intostr
                    else
                        pop
                        " "
                    then

                    IRVCOLVOTECOUNTLEN STRright IRVCOLSEP swap strcat

                    strcat
                REPEAT

                ( If this is the winner line, add something to indicate )
                trig irvPropPrefix @ "winner" strcat getpropval
                currentChoice @ = if
                    " <<WON" strcat
                then

                ( Store off the finished, formatted result line )
                output @ array_appenditem output !
                ( Put choice in shownChoices so it won't be used again )
                1 shownChoices @ currentChoice @ ->[] shownChoices !
            else
                ( Go to the next round )
                break
            then
        REPEAT ( end of look for next choice within round )
        
        pop
    REPEAT  ( end of loop from round N to round 1 )
    
    ( Generate footer with totals )
    " " output @ array_appenditem output !
    "TOTAL" IRVCOLCHOICELEN STRleft
    1 rounds @ 1 FOR
        trig irvPropPrefix @ rot intostr strcat "/total" strcat getpropval
        intostr IRVCOLVOTECOUNTLEN STRright
        " " swap strcat strcat
    REPEAT
    output @ array_appenditem output !
    
    ( Add note if present )
    trig topicPropPrefix @ "/note" strcat getpropstr dup strlen if
        " " output @ array_appenditem output !
        "Topic owner's note: " swap strcat output @ array_appenditem output !
    else
        pop
    then

    
    ( Output in order )
    output @ { me @ }list array_notify
    blankline
;
  
: showCards ( s -- Print the anonymous voting cards to the screen of
                  closed topic s )
    "S" checkargs
    
    var! cardTopic
    { }list var! output
    
    trig BOOTHCLOSEDPFX cardTopic @ strcat "/usersvoted/" strcat nextprop
    strlen not if
        ( No cards available or topic doesn't exist )
        "No voting cards available for this topic." sysMessage
        exit
    then
    
    "Getting voting cards..." sysMessage
    
    ( For each card, store the string representation in a list for sorting )
    trig BOOTHCLOSEDPFX cardTopic @ strcat "/usersvoted/" strcat nextprop
    BEGIN
        dup
        
        trig swap getpropstr output @ array_appenditem output !
        
        ( Get the next prop or exit if done )
        trig swap nextprop dup
        strlen not
    UNTIL
    pop

    ( Sort them to anonymize further; currently they are ordered by dbref )
    output @ SORTTYPE_CASE_ASCEND array_sort output !
    
    blankline blankline
    me @ "Here are the voting cards for topic:" notify
    
    me @
        "   " trig BOOTHCLOSEDPFX cardTopic @ strcat "/topic" strcat getpropstr
        strcat
    notify
    blankline
    
    output @ { me @ }list array_notify
    blankline
;
  
: topicResults  ( s1 s2 -- )
( Display results for topic, as located in 's1 "/" s2 strcat strcat'.  OMIT the '/@/vote/' part )
        lockHold
        over "close" instr var! closedTopic
        "/" swap strcat strcat votetopic !
        "/@/vote/" votetopic @ strcat votetopic !

         ( Vote results header )
         blankline blankline

         me @ trig votetopic @ "/topic" strcat getpropstr notify
         me @ "  Added on " "%D" trig votetopic @ "/opendate" strcat getpropval
              timefmt strcat " by " strcat
              trig votetopic @ "/owner" strcat getpropval playerName strcat
         notify

         closedTopic @ if
             me @
               " Closed on " "%D" trig votetopic @ "/closedate" strcat
               getpropval
               timefmt strcat " by " strcat trig votetopic @ "/closedby"
               strcat getpropval playerName strcat
             notify
         else
             me @ "  Closed by:  -Open Topic-" notify
         then
         blankline

         trig votetopic @ "/mode" strcat getpropval closedTopic @ and if
           ( IRV vote results )
           votetopic @ getPropSuffix showIRVResults
         else
           ( Standard vote results )
           me @ "_Votes_ __Choice_________________________________________________________" notify
           0 counter !
           BEGIN
             1 counter @ + counter !
  (breaks out of choice display loop if no more choices to display)
             trig votetopic @ "/" strcat counter @ intostr strcat getpropstr
             strlen not if break then
             
  (otherwise, displays the next choice, and loops)
             me @
                " " trig votetopic @ "/tally/" strcat counter @ intostr strcat
                getpropval
                intostr 5 STRright strcat " |  " strcat
                trig votetopic @ "/" strcat counter @ intostr strcat getpropstr
                strcat
            notify
           REPEAT
           
            blankline
            me @
                "  Total players voted: "
                trig votetopic @ "/total" strcat getpropval
                intostr strcat
            notify
            
            trig votetopic @ "/note" strcat getpropstr dup strlen if
              blankline
              me @ "Topic owner's note: " rot strcat notify
              blankline
            else
              pop
            then
            0 counter !
         then
;

: doVote ( s -- )
( # to vote comes from main menu... or elsewhere.  It is a number, but in string format )
        choice !
        ( Normal=0 or IRV=1 )
        0 var! voteMode
        ( User choices in list form when using IRV )
        { }list var! irvChoices
        
( Verify the topic is not still being added.  If it is, then say so and abort )
        trig BOOTHOPENPFX choice @ strcat "/addchoices?" strcat getpropstr strlen not if
                blankline blankline 
                me @ "Sorry, the topic selected is still being added or modified.  If you believe" notify
                me @ "this to be in error, please contact someone in charge of the voting booth." notify
                pause blankline exit then
(show the topic and choices)
         BEGIN (3)
         lockHold
         blankline
         BOOTHOPENPFX choice @ strcat checkValidTopic
         me @ trig BOOTHOPENPFX choice @ strcat "/topic" strcat getpropstr notify
         me @ "  Added on " "%D" trig BOOTHOPENPFX choice @ strcat "/opendate" strcat getpropval timefmt strcat " by " strcat trig BOOTHOPENPFX choice @ strcat "/owner" strcat getpropval playerName strcat notify
         blankline
         0 votetopic !
         BEGIN (4)
           1 votetopic @ + votetopic !
(breaks out of choice display loop if no more choices to display)
           trig BOOTHOPENPFX choice @ strcat "/" strcat votetopic @ intostr
             strcat getpropstr strlen
           not if break then
           
(otherwise, displays the next choice, and loops)
           me @ "  " votetopic @ intostr 3 STRright strcat " :  " strcat
             trig BOOTHOPENPFX choice @ strcat "/" strcat votetopic @ intostr
             strcat getpropstr strcat
           notify
         REPEAT (4)
(get choice number from keyboard, and check for validity, or exit to voting menu if 'b' chosen)
          blankline
          trig BOOTHOPENPFX choice @ strcat "/mode" strcat getpropval
          dup voteMode !
          if
            ( As this is IRV, explain how to enter choices )
            me @ "This is an instant runoff type vote.  One or more choices may be entered, in" notify
            me @ "order of preference.  The choices are entered in comma separated format, as" notify
            me @ "in this example: 1,2,3,4" notify
            blankline
          then
          me @ "+++" notify
          trig BOOTHOPENPFX choice @ strcat "/addchoices?" strcat getpropstr "no" stringcmp if me @ "+  (A)dd a choice" notify then
          me @ "+  (B)ack to voting menu  ::  (Q)uit" notify
          me @ "+++" notify
          blankline
          me @ "CHOICE(s) or MENU ITEM:" notify
          BOOTHOPENPFX choice @ strcat checkValidTopic
          do_read strip input ! lockHold

          "q" input @ stringcmp not if 'progExit jmp then
          "b" input @ stringcmp not if "Voting on topic aborted." sysMessage exit then
          (If they choose to add a topic, make sure it is allowed.  If so, then add the choice and jump to the vote confirm prompt)
          "a" input @ stringcmp not trig BOOTHOPENPFX choice @ strcat "/addchoices?" strcat getpropstr "no" stringcmp and if
                blankline
                "Adding choice #" votetopic @ intostr strcat sysMessage
                me @ "Please enter the name of the choice (Type a . to abort): " notify
                do_read dup input !
                "." stringcmp if
                    BOOTHOPENPFX choice @ strcat checkValidTopic
                    "Adding Choice" lockDBwait
                    ( As someone else may have added a vote choice in the
                      meantime, increment the topic until we find an unused one )
                    BEGIN (5)
                        trig BOOTHOPENPFX choice @ strcat "/" strcat votetopic @ intostr strcat getpropstr strlen not if break then
                        1 votetopic @ + votetopic !
                    REPEAT (5)
                    trig BOOTHOPENPFX choice @ strcat "/" strcat votetopic @ intostr strcat input @ setprop
                    unlockDB
                    "Choice added" sysMessage
                    ( Loop back to show the choices again )
                    continue
                else
                    "Aborted adding choice" sysMessage continue then then

( Parse choice and confirm they are allowed to vote more than one.  If not,
  loop back and try again. )
          ( Find max choice - this can change each time )
          trig BOOTHOPENPFX choice @ strcat "/" strcat votetopic @ intostr
          strcat getpropstr strlen if
            ( We are at the last [max] choice )
            votetopic @
          else
            ( We are one past the max choice )
            votetopic @ --
          then
          
          ( Using the user input, max choice, and verbose mode, convert input
            to list of choices in order )
          input @ swap ( << max choice) 1 stringChoicesToList dup irvChoices !
          
          ( Confirm how many they are allowed to pick and loop if incorrect )
          array_count dup not if
            me @ "No valid commands or choices entered." notify
            pop
            0
          else
              voteMode @ if
                ( IRV - 1..n are valid.  Leave count on stack for UNTIL 3 )
                ( Normalize )
                irvChoices @ choicesListToString input !
              else
                ( Normal - Only one choice is valid )
                1 > if
                    me @ "Only one choice may be voted on." notify
                    0
                else
                    ( Normalize )
                    irvChoices @ choicesListToString input !
                    1
                then
              then          
          then
         UNTIL (3 - until true)
(verify)
         blankline blankline
         BOOTHOPENPFX choice @ strcat checkValidTopic
         me @ "You have chosen to vote this way on the selected topic:" notify
         
         irvChoices @ array_count 1 = if
            ( Standard one choice )
            me @ "   " trig BOOTHOPENPFX choice @ strcat "/" strcat
                 input @ strcat getpropstr strcat
            notify
         else
            ( Multiple choices.  Format it in terms of 'preferred N' )
            blankline
            irvChoices @ FOREACH
                ( "   Preferred N: " )
                swap ++
                "   Preferred " swap intostr strcat ": " strcat
                ( "   Preferred N: <choice string for N>" )
                trig BOOTHOPENPFX choice @ strcat "/" strcat 4 rotate intostr
                     strcat getpropstr
                strcat
                
                me @ swap notify
            REPEAT
         then
         
         blankline
         me @ "Record vote (type 'yes' or 'no' fully)?" notify
         getYesNo
         BOOTHOPENPFX choice @ strcat checkValidTopic
         "yes" stringcmp not if
(if verify OK, record vote. lvar counter is used here during the tally updates )
          blankline "Recording vote..." sysMessage
          "Voting" lockDBwait
          ( Add the first user choice to the tally. This allows a 'preview' of
            retsults when using IRV mode and won't break normal voting )
          trig BOOTHOPENPFX choice @ strcat "/tally/" strcat
            irvChoices @ 0 [] intostr strcat getpropval counter !
          counter @ 1 + counter !
          trig BOOTHOPENPFX choice @ strcat "/tally/" strcat
            irvChoices @ 0 [] intostr strcat counter @ setprop

          trig BOOTHOPENPFX choice @ strcat "/total" strcat getpropval counter !
          counter @ 1 + counter !
          trig BOOTHOPENPFX choice @ strcat "/total" strcat counter @ setprop

          trig BOOTHOPENPFX choice @ strcat "/usersvoted/" strcat me @ intostr strcat input @ setprop

          REWARDVOTE
          
          unlockDB
          "DONE recording vote." sysMessage

(if verify NOT ok, then abort)
         else blankline "Voting on this topic has been cancelled." sysMessage then
        exit
;

: results ( -- )
(display topics that have results available, if any exist)
BEGIN (1)
        clearstack
        lockHold
        blankline blankline me @ ">> CLOSED TOPICS:" notify blankline
        trig "/@/vote/closed" getpropval 0 = not if
        me @ "_NUM__ _____TOPIC________________________________________________ _# VOTED_" notify
        trig BOOTHCLOSEDPFX nextprop counter !
        BEGIN
         counter @ strlen if
          me @ "  " counter @ 15 strcut swap pop 3 STRleft " |   " strcat strcat trig counter @ "/topic" strcat getpropstr 53 strcut pop 54 STRleft strcat " |   " trig counter @ "/total" strcat getpropval intostr strcat strcat notify
         then
         trig counter @ nextprop counter !
         counter @ strlen not
        UNTIL then
        trig "/@/vote/closed" getpropval not if blankline me @ "vote: No topics available" notify pause blankline exit then
        blankline
        me @ "+++" notify
        me @ "+   (B)ack to main menu  ::  (D)ump All  ::  (Q)uit" notify
        me @ "+++" notify
        me @ "NUMBER or MENU ITEM:" notify
(read from keyboard)
        do_read choice !
        lockHold
        choice @ "q" stringcmp not if 'progExit jmp then
        choice @ "d" stringcmp not if 
                me @ "WARNING!  About to dump the results of ALL closed topics to the screen!" notify pause
                trig BOOTHCLOSEDPFX nextprop dump !
                BEGIN
                 dump @ strlen if
                        ( This is the topic identifier )
                        dump @ dup "/" rinstr strcut swap pop
                        
                        dup isClosedTopicLocked? if
                            ( Locked.  See if we can view it )
                            dup isClosedTopicControlledByMe? if
                                ( We can view it )
                                "closed" swap topicResults
                            else
                                ( Not allowed )
                                blankline
                                "Unable to view results of topic " swap strcat
                                    " because it is locked." strcat sysMessage
                                blankline
                            then
                        else
                            ( Not locked )
                            "closed" swap topicResults
                        then
                 then
                 trig dump @ nextprop dump !
                 dump @ strlen not
                UNTIL
                pause
        continue then
        choice @ "b" stringcmp not if exit then
        ( See if it's a topic number, to display the result )
        trig BOOTHCLOSEDPFX choice @ strcat "/owner" strcat getpropval if
            ( Determine if we 'own' this closed topic )
            choice @ isClosedTopicControlledByMe? ownerStatus !

            ( Determine if locked )            
            choice @ isClosedTopicLocked? lockStatus !

            ( Display the topic result if not locked )
            lockStatus @ if
                ( Locked. Only show if owner )
                ownerStatus @ if
                    "closed" choice @ topicResults
                else
                    blankline
                    "This topic is locked by " lockStatus @ playerName strcat
                      " and cannot be viewed at this time." strcat
                    sysMessage
                    blankline
                    pause
                    blankline
                    continue
                then
            else
                ( Not locked.  Display as always )
                "closed" choice @ topicResults
            then
            
            BEGIN (2)
                ( Perform any optional operations before exiting )
                me @ "+++" notify
                me @ "+   <ENTER> / (B)ack :: See (V)oting Cards :: Set (N)ote [Owner/Closer only]" notify
                ( Show locking option only if owner or closer )
                ownerStatus @ if
                    me @
                    lockStatus @ if
                        "+   (U)nlock Results [so all can see], currently LOCKED"
                    else
                        "+   (L)ock Results [only owner can see], currently UNLOCKED"
                    then
                    notify
                then
                
                me @ "+++" notify
                me @ "MENU ITEM:" notify

                do_read_allow_blanks
                
                ( hit enter - exit )
                dup strlen not if break then
                ( back - exit )
                dup "b" stringcmp not if break then
                
                ( See voting cards )
                dup "v" stringcmp not if
                    choice @ showCards
                    pause
                    break
                then
                
                dup "l" stringcmp not ownerStatus @ lockStatus @ not and and if
                    ( Locking is desired )
                    trig BOOTHCLOSEDPFX choice @ strcat LOCKEDPROP strcat
                    me @ int setprop
                    me @ int lockStatus !
                    blankline
                    me @ "Topic is now locked." notify
                    blankline
                    pause
                    pop
                    continue
                then

                dup "u" stringcmp not ownerStatus @ lockStatus @ and and if
                    ( Unlocking is desired )
                    trig BOOTHCLOSEDPFX choice @ strcat LOCKEDPROP strcat
                    remove_prop
                    0 lockStatus !
                    blankline
                    me @ "Topic is now unlocked." notify
                    blankline
                    pause
                    pop
                    continue
                then
                
                ( Set note )
                dup "n" stringcmp not if
                    ( Confirm permissions first.  Must be owner or closer )
                    ownerStatus @ if
                        me @ "Enter a note to be displayed with the topic results (or . to erase):" notify
                        do_read
                        
                        ( Remove note )
                        dup "." strcmp not if
                            pop
                            trig BOOTHCLOSEDPFX choice @ strcat "/note" strcat
                            remove_prop
                            "Note removed." sysMessage
                        else
                            ( Set / Add note )
                            trig BOOTHCLOSEDPFX choice @ strcat "/note" strcat
                            rot setprop
                            "Note set or added." sysMessage
                        then
                    else
                        "Only the owner or closer may set the note." sysMessage
                    then
                    
                    pause
                    pop
                    continue
                then
                
                me @ "Unknown command: " rot strcat notify
                blankline
            REPEAT (2)
            pop
        else
            me @ "vote: Invalid command or topic number" notify
        then
REPEAT (1)
;
  
: setIRVRoundResultProps (s i dict --  Sets the round results dict for closed
                             topic s, round i )
    "Si?" checkargs
    var! roundResult
    var! round
    var! irvtopic
    0 var! totalRoundVotes
    
    BOOTHCLOSEDPFX irvtopic @ strcat "/irvresults/" strcat
        round @ intostr strcat "/" strcat
    var! roundResultPropPrefix
    
    roundResult @
    FOREACH
        dup totalRoundVotes @ + totalRoundVotes !
        
        ( Simply make the key a prop name, and the value the prop value )
        roundResultPropPrefix @ rot intostr strcat swap
        trig -3 rotate setprop
    REPEAT
    
    ( And add in the total votes that round for ease of retrieval )
    trig roundResultPropPrefix @ "total" strcat totalRoundVotes @ setprop
    
    ( Since rounds are added incrementally, include a total on irvresults )
    trig BOOTHCLOSEDPFX irvtopic @ strcat "/irvresults" strcat round @ setprop
;
  
: calcIRV (s --  Calculates instant runoff results. i is the topic, which must
            be already closed )
    ( closedprefix/#/irvresults/round#/choice#: #votes )
    ( closedprefix/#/usersvoted/db#: # # # #  ... )

    var! irvtopic
    
    1 var! round
    { }dict var! usedChoices  (this is actually a set - uses keys only )
    { }dict var! roundResult
    0 var! totalVotes
    0 var! winnerChoice
    0 var! winnerVotes
    0 var! loserVotes
    
    var cards
    var maxChoices

    ( Get the voting cards )
    irvtopic @ getCards maxChoices ! cards !
    
    ( instant runoff round loop )
    BEGIN
        "Processing round " round @ intostr strcat "..." strcat sysMessage
        
        { }dict roundResult !
        0 winnerChoice !
        0 winnerVotes !
        0 loserVotes !
        0 totalVotes !
        ( For each card... )
        cards @
        FOREACH
            ( Throw away index )
            swap pop
            ( Find the first choice that has not been removed, if any )
            FOREACH
                ( Throw away index )
                swap pop
                usedChoices @ over [] if
                    ( In the set, the choice was removed - skip over )
                    pop
                else
                    ( Not in the set - this is the first choice )
                    ( Found a valid choice to use.  Add to the totals and the
                      tally for the choice )
                    totalVotes ++
                    roundResult @ over []
                    ++ roundResult @ rot ->[] roundResult !
                    
                    break
                then
            REPEAT
        REPEAT
        
        ( All cards have been processed.  Write out the result. )
        irvtopic @ round @ roundResult @ setIRVRoundResultProps

        ( Figure out if we have a winner.  If so, indicate it )
        roundResult @
        FOREACH
            dup winnerVotes @ > if
                ( Found someone with more votes )
                winnerVotes !
                winnerChoice !
            else
                pop pop
            then
        REPEAT
        
        ( Run the loop again to check for a tie )
        0 ( init to no tie )
        roundResult @
        FOREACH
            winnerVotes @ = swap winnerChoice @ = not and if
                ( Found someone who has the same number of votes as the
                  winner but is not the winner.  A tie occurred )
                  pop 1 break
            then
        REPEAT        
        
        if
            ( A tie - there's no winner )
            0 winnerChoice !
        else
            ( No tie, see if the winner can meet the % requirement )
            winnerVotes @ float totalVotes @ float / 100 float *
            IRVWINNERPCT float > if
                ( Winner found )
                trig
                  BOOTHCLOSEDPFX irvtopic @ strcat "/irvresults/winner" strcat
                  winnerChoice @ setprop
            else
                ( No winner. )
                0 winnerChoice !
            then
        then

        winnerChoice @ not if
            ( No winner.  Remove least popular choices )
            ( First loop finds the least popular vote count )
            winnerVotes @ loserVotes !
            roundResult @
            FOREACH
                ( Don't need choice/index for this loop )
                swap pop
                dup loserVotes @ < if
                    ( Found a new loser )
                    loserVotes !
                else
                    pop
                then
            REPEAT

            ( Second loop removes any choices that had that vote count )
            roundResult @
            FOREACH
                loserVotes @ = if
                    ( Found a choice to be removed )
                    1 usedChoices @ rot ->[] usedChoices !
                else
                    pop
                then
            REPEAT
        then
        
        round ++
        ( Check if we're done! )
        winnerChoice @ usedChoices @ array_count maxChoices @ = or
    UNTIL

    "Finished processing." sysMessage
;
  
: setupAddtopic ( -- )
	blankline me @ ">> ADD TOPIC:" notify blankline
(Read from keyboard topic name)
	me @ "Enter the voting topic (or a . to abort): " notify
        do_read dup
        "." stringcmp not if me @ "vote: Aborted" notify exit then
        votetopic !
(If they do not want to abort, find a free topic number)
        blankline
        me @ "vote:  Please wait... " notify
        "Adding Topic" lockDBwait
        0
        counter !
        begin
         counter @ 1 + counter !
(determines if the number is in use elsewhere [open or closed topics] if it is, advance number until it gets to a unused one )
         trig BOOTHOPENPFX counter @ intostr strcat "/topic" strcat getpropstr strlen not trig BOOTHCLOSEDPFX counter @ intostr strcat "/topic" strcat getpropstr strlen not and
        until (true)
( inform the user what topic # they are, and start assembling the props for it)
        me @ "vote:  You are voting topic # " counter @ intostr strcat notify
        trig BOOTHOPENPFX counter @ intostr strcat "/topic" strcat votetopic @ setprop
        trig BOOTHOPENPFX counter @ intostr strcat "/total" strcat 0 setprop
        trig BOOTHOPENPFX counter @ intostr strcat "/number" strcat counter @ setprop
        trig BOOTHOPENPFX counter @ intostr strcat "/owner" strcat me @ int setprop
        trig BOOTHOPENPFX counter @ intostr strcat "/opendate" strcat systime setprop
( adds a number to /@/vote/open so the prog can tell when there are topics at all )
        trig "/@/vote/open" trig "/@/vote/open" getpropval 1 + setprop
        unlockDB
        me @ "vote:  DONE initing new vote topic" notify
(read from keyboard vote choices.  a . ends)
        blankline
        me @ "Enter the choices the user has to vote on, each on a separate line.  When you are done type '.'" notify
        0 choice !
        begin
         choice @ 1 + choice !
         me @ "Choice " choice @ intostr strcat ":" strcat notify
         do_read
         dup
( lvar votetopic is reused to mean topic choices here )
         votetopic ! 
         "." stringcmp not if
            break
         else
            ( Echo choice back and store it )
            me @ votetopic @ notify
            trig BOOTHOPENPFX counter @ intostr strcat "/" strcat
              choice @ intostr strcat votetopic @ setprop
         then
        repeat
        
        blankline
        me @ "Would you like this topic to be an instant runoff vote (IRV)?" notify
        me @ "In IRV, voters make preferential choices.  Multiple rounds of vote counting are" notify
        me @ "conducted and the least popular choice eliminated until a winner has received" notify
        me @ "more than " IRVWINNERPCT intostr strcat "% of the #1 votes." strcat notify
        me @ "See http://en.wikipedia.org/wiki/Instant-runoff_voting for details of IRV." notify
        me @ "Answer 'yes' (IRV) or 'no' (standard/simple) fully:" notify
        trig BOOTHOPENPFX counter @ intostr strcat "/mode" strcat getYesNo "yes" stringcmp not setprop
        blankline

        me @ "Would you like those who have voted on the topic to be able to see the" notify
        me @ "results of it right away?  Answer 'yes' or 'no' fully:" notify
        trig BOOTHOPENPFX counter @ intostr strcat "/allowresults?" strcat getYesNo tolower setprop

        blankline
        me @ "Would you like voters to be able to add their own choices to the topic?" notify
        me @ "Answer 'yes' or 'no' fully:" notify
        trig BOOTHOPENPFX counter @ intostr strcat "/addchoices?" strcat getYesNo tolower setprop

        blankline
        me @ "vote: Voting topic added" notify
        exit
;
  
: setupClosetopic ( -- )
BEGIN
        lockHold
        clearstack
(check to see if there ARE any topics at all. if not, then exit to main menu)
        trig "/@/vote/open" getpropval not if me @ " " notify me @ "vote: No topics available to close!" notify exit then
(show open topics)
        blankline blankline me @ ">> OPEN TOPICS:" notify blankline
        trig BOOTHOPENPFX nextprop counter !
        BEGIN
         counter @ strlen if
          me @ counter @ 13 strcut swap pop ": " strcat trig counter @ "/topic" strcat getpropstr strcat notify
 ( this appears after every vote topic name and number.  it tells how many have voted, and the owner)
 ( because of it's complexity I split it up into multiple lines for easier understanding )
          me @ 
                 "   Total votes on topic: " trig counter @ "/total" strcat getpropval intostr strcat
                 "     " strcat "OWNER: " strcat trig counter @ "/owner" strcat getpropval playerName strcat
          notify
         then
         trig counter @ nextprop counter !
         counter @ strlen not
        UNTIL (true)
        blankline me @ "+++" notify
        me @ "+  (B)ack to admin menu  ::  (Q)uit" notify
        me @ "+++" notify
        me @ "Please note you can ONLY close topics you made, unless you own the object" notify
        me @ "NUMBER or MENU ITEM:" notify
(read from keyboard)
        do_read choice !
        lockHold
        choice @ "q" stringcmp not if 'progExit jmp then
        choice @ "b" stringcmp not if exit then
(if user owns that topic or is the object owner and the topic exists, then verify they want to close it )
        me @ trig controls trig BOOTHOPENPFX choice @ strcat "/owner" strcat getpropval me @ int = or trig BOOTHOPENPFX choice @ strcat "/topic" strcat getpropstr strlen and if
        blankline
        me @ "The following topic is about to be closed:" notify
        me @ "   " trig BOOTHOPENPFX choice @ strcat "/topic" strcat getpropstr strcat notify
        blankline
        me @ "Close topic (Answer 'yes' or 'no' fully)?" notify
        getYesNo "yes" stringcmp not if
(if yes, move all data structure to /../closed)
          me @ "vote: Closing topic..." notify
          "Closing Topic" lockDBwait
          trig "/@/vote/closed" trig "/@/vote/closed" getpropval 1 + setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/topic" strcat trig BOOTHOPENPFX choice @ strcat "/topic" strcat getpropstr setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/total" strcat trig BOOTHOPENPFX choice @ strcat "/total" strcat getpropval setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/owner" strcat trig BOOTHOPENPFX choice @ strcat "/owner" strcat getpropval setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/closedby" strcat me @ int setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/opendate" strcat trig BOOTHOPENPFX choice @ strcat "/opendate" strcat getpropval setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/closedate" strcat systime setprop
          trig BOOTHCLOSEDPFX choice @ strcat "/mode" strcat trig BOOTHOPENPFX choice @ strcat "/mode" strcat getpropval setprop
          ( Copy the choices and their total votes )
          0 counter !
          BEGIN
                counter @ 1 + counter !
                ( Stop when we've hit the end )
                trig BOOTHOPENPFX choice @ strcat "/" strcat counter @ intostr
                     strcat getpropstr strlen not if break then

                trig BOOTHCLOSEDPFX choice @ strcat "/" strcat counter @
                     intostr strcat trig BOOTHOPENPFX choice @ strcat "/"
                     strcat counter @ intostr strcat getpropstr setprop
                trig BOOTHCLOSEDPFX choice @ strcat "/tally/" strcat counter @
                     intostr strcat
                     trig BOOTHOPENPFX choice @ strcat "/tally/" strcat counter @
                     intostr strcat getpropval setprop
          REPEAT
  
          ( Copy the users voted props for later review via anonymous voting
            cards )
          trig BOOTHOPENPFX choice @ strcat "/usersvoted/" strcat nextprop
            dup strlen if
              BEGIN
                ( Extract the dbref )
                dup getPropSuffix
                
                ( Get the voting card )
                trig 3 pick getpropstr
                
                ( Save the dbref and card off )
                trig BOOTHCLOSEDPFX choice @ strcat "/usersvoted/" strcat
                    4 rotate strcat rot setprop
                
                trig swap nextprop
                dup strlen not
              UNTIL
            then
            pop
          
          ( If this is an IRV, compute the rounds )
          trig BOOTHOPENPFX choice @ strcat "/mode" strcat getpropval if
            choice @ calcIRV
          then
          
( erase the old prop tree under /../open )
          trig BOOTHOPENPFX choice @ strcat 1 setprop
          trig BOOTHOPENPFX choice @ strcat remove_prop
          trig "/@/vote/open" trig "/@/vote/open" getpropval 1 - setprop
          unlockDB
          me @ "vote: DONE closing topic" notify
        else me @ " " notify me @ "vote: Aborted closing topic" notify then
(displays this if they do not own the topic or it doesn't exist)
        else me @ " " notify me @ "vote: No permission to modify topic OR topic does not exist" notify then
(loop back to beginning of menu)
REPEAT
;
  
: setupRemovetopic ( -- )
( defaults to closed topics display, as usually thats what they will delete )
        BOOTHCLOSEDPFX votetopic !
        15 choice !
( Show open or closed topic.  'choice' is used temporairily here for strcut)
BEGIN
        lockHold
        clearstack
        blankline blankline
        BOOTHOPENPFX votetopic @ stringcmp not if me @ ">> REMOVE OPEN TOPICS:" notify else me @ ">> REMOVE CLOSED TOPICS:" notify then
        blankline
        trig votetopic @ choice @ 1 - strcut pop getpropval if
        trig votetopic @ nextprop counter !
        BEGIN
         counter @ strlen if
          me @ counter @ choice @ strcut swap pop ": " strcat trig counter @ "/topic" strcat getpropstr strcat notify
 ( this appears after every vote topic name and number.  it tells how many have voted, and the owner)
 ( because of it's complexity I split it up into multiple lines for easier understanding )
          me @ 
                 "     Total votes on topic: " trig counter @ "/total" strcat getpropval intostr strcat
                 "     " strcat "OWNER: " strcat trig counter @ "/owner" strcat getpropval playerName strcat
          notify
         then
         trig counter @ nextprop dup counter !
         strlen not
        UNTIL (true)
        else me @ "vote: No topics available" notify then
        blankline
        me @ "+++" notify
        me @ "+  (S)witch to Open or Closed topics  ::  (B)ack to setup menu  ::  (Q)uit" notify
        me @ "+++" notify
        me @ "NUMBER or MENU ITEM:" notify
(read from keyboard)
        do_read input !
        lockHold
        input @ "q" stringcmp not if 'progExit jmp then
        input @ "s" stringcmp not if
           BOOTHOPENPFX votetopic @ stringcmp not if BOOTHCLOSEDPFX votetopic ! 15 choice !
                else BOOTHOPENPFX votetopic ! 13 choice ! then then
        input @ "b" stringcmp not if exit
        else
( make sure the topic exists and that they are the owner )
        me @ trig controls trig votetopic @ input @ strcat "/owner" strcat getpropval me @ int = or trig votetopic @ input @ strcat "/topic" strcat getpropstr strlen and if
         blankline
         me @ "The following topic is about to be REMOVED:" notify
         me @ "   " trig votetopic @ input @ strcat "/topic" strcat getpropstr strcat notify
         blankline
(confirm)
         me @ "REMOVE topic (Answer 'yes' or 'no' fully)?" notify
         getYesNo "yes" stringcmp not if
(if owner of topic, then delete props.  if not, then don't)
          me @ "vote: Removing topic..." notify
          "Removing Topic" lockDBwait
          trig votetopic @ input @ strcat 1 setprop
          trig votetopic @ input @ strcat remove_prop
          trig votetopic @ choice @ 1 - strcut pop trig votetopic @ choice @ 1 - strcut pop getpropval 1 - setprop
          unlockDB
          me @ "vote: DONE removing topic" notify
         else me @ " " notify me @ "vote: User abort removing topic" notify then
        else input @ number? if me @ " " notify me @ "vote:  No permission to delete topic OR topic does not exist" notify then then
        then
REPEAT
exit
;

: unlockObject ( -- )
( makes sure they are the object owner before running setup! )
	me @ trig controls if
                "Unlocking..." sysMessage
                3 sleep isLocked? if unlockDB then
                "DB Unlocked." sysMessage
        	exit
	then
( OR, if they are not the owner of the object, say so and abort )
	me @ "vote:  You are NOT the owner of the object.  Unlock aborted." notify
;
  
: setupSetup ( -- )
( makes sure they are the object owner before running setup! )
    me @ trig controls if
        "Setup Booth" lockDBwait
        ( Perform some upgrade work if not a new booth )
        trig VERSIONPROP getpropval dup if
            200 < if
                "Upgrading..." sysMessage
                trig BOOTHOPENPFX nextprop "/@/vote/open/end" strcmp if
                    "Close all open voting topics before upgrading." sysMessage
                    unlockDB
                    exit
                then
                ( Remove obsolete props )
                trig "/@/vote/open/end" remove_prop
                trig "/@/vote/closed/end" remove_prop
                ( For each closed topic, remove its users voted since it is
                  incompatible with the new format )
                trig BOOTHCLOSEDPFX nextprop dup strlen if
                    BEGIN
                        dup "/usersvoted" strcat
                        trig swap remove_prop
                        
                        trig swap nextprop dup
                        strlen not
                    UNTIL
                    pop
                else
                    ( Nothing was closed )
                    pop
                then
            then
        else
            pop
        then

(adds vote props)
        me @ "vote: Setting up object..." notify
        trig VERSIONPROP VOTEVERSION setprop
        blankline
        me @ "Enter the name of the voting booth:" notify
        trig "/votecfg/name" do_read setprop blankline
        me @ "Do you want to allow users to add/close/remove their own voting topics?  Please enter a 'yes' or 'no' fully." notify
        me @ "CHOICE (yes/no):" notify
        trig "/votecfg/public" getYesNo setprop
        blankline
        me @ "Enter a quitting/closing message string, or enter to have none: " notify
        trig "/votecfg/closemsg" do_read setprop
        blankline
        unlockDB
        me @ "vote:  Setup complete." notify
(back to setup)
        exit
    then
( OR, if they are not the owner of the object, say so and abort )
        blankline me @ "vote:  You are NOT the owner of the object.  Setup aborted." notify blankline
    exit
;
  
: setup ( -- )
(Show setup menu, but make sure they are authorized to view it)
    trig "/votecfg/public" getpropstr "yes" stringcmp not me @ trig controls or if
	BEGIN
        lockHold
        clearstack
	blankline blankline me @ ">> ADMIN MENU:" notify blankline
        me @ "+++" notify
	me @ "+   (A)dd a voting topic" notify
	me @ "+   (R)emove a voting topic" notify
	me @ "+   (C)lose a voting topic" notify
	me @ "+   (S)etup/Install this voting object" notify
	me @ "+   (B)ack" notify
        me @ "+   (Q)uit" notify
        me @ "+++" notify
	blankline
	me @ "MENU ITEM:" notify
(read from keyboard)
	do_read
        lockHold
(branch)
          dup "q" stringcmp not if pop 'progExit jmp then
	dup "a" stringcmp not if pop setupAddtopic else
	dup "r" stringcmp not if pop setupRemovetopic else
	dup "c" stringcmp not if pop setupClosetopic else
	dup "s" stringcmp not if pop setupSetup else
	"b" stringcmp not if exit
	then then then then then
	REPEAT
	then
( OR, if they are not the owner of the object, say so and abort )
    blankline
    "This object does not allow non-owner voting administration access." sysMessage
    blankline pause blankline
;

: resultOrVote  ( s -- )
( Calls the results displayer or votes, depending on if the topic has already been voted on )
( Also serves as an error checker for both doVote and topicResults )

choice !

trig choice @ me @ isAltVoted? var! altVoted

        lockHold
        (If it exists and they havn't voted, then vote)
        trig BOOTHOPENPFX choice @ strcat "/owner" strcat getpropval
        altVoted @ not and if
            choice @ doVote exit
        (else, if it exists and they HAVE voted, and they are allowed to see the results, show them)
        else
            altVoted @
            trig BOOTHOPENPFX choice @ strcat "/allowresults?" strcat getpropstr
            "no" stringcmp AND if
                "open" choice @ topicResults pause exit
            then
            
            (error messages here)
            trig BOOTHOPENPFX choice @ strcat "/owner" strcat getpropval not
            trig "/@/vote/open" getpropval AND choice @ atoi AND
            if
                me @ "vote: Topic does not exist" notify exit
            then
            
            altVoted @
            trig BOOTHOPENPFX choice @ strcat "/allowresults?" strcat getpropstr
            "no" stringcmp not and
            if
                me @ "vote: You have already voted on this topic and results cannot be displayed" notify
                exit
            then
        then
        
        me @ "vote: Invalid command" notify
;

: mainMenu ( -- )
(display main menu)
	BEGIN
        blankline me @ ">> " trig "/votecfg/name" getpropstr toupper strcat " MAIN MENU:" strcat notify blankline
        0 voteDisplay clearstack
        blankline lockHold
	trig VERSIONPROP getpropval VOTEVERSION = not if "THIS BOOTH IS NOT CONFIGURED.  PLEASE RUN SETUP UNDER THE * MENU" sysMessage blankline then
        me @ "+++" notify

        trig "/votecfg/public" getpropstr "yes" stringcmp not me @ trig controls or if me @ "+  (S)ee results of closed topics  ::  (*) Admin Menu / Add Topics ::" notify else
        me @ "+  (S)ee results of closed topics  ::" notify then
        me @ "+  (#) Vote on topic number / see results  ::  (V)ote all  ::  (Q)uit" notify
        me @ "+++" notify
	me @ "NUMBER or MENU ITEM:" notify
(get choice from user)
	do_read
        lockHold
(branch to appropiate subprogram)
        dup "s" stringcmp not if pop results else
        dup "#" stringcmp not if pop blankline blankline me @ "Do NOT type #.  Instead, type the actual number of the topic you wish to vote on." notify blankline pause else
        dup "*" stringcmp not if pop setup else
        dup "v" stringcmp not if
            pop
            trig "/@/vote/open" getpropval not if blankline "No topics available for voting!" sysMessage pause continue then

            me @ "WARNING!  About to vote on ALL topics you have not voted on!  Use 'b' to skip voting for a topic." notify pause
            trig BOOTHOPENPFX nextprop dump !
            BEGIN
             dump @ strlen if
                 trig BOOTHOPENPFX dump @ dup "/" rinstr strcut swap pop strcat "/owner" strcat getpropval trig BOOTHOPENPFX dump @ dup "/" rinstr strcut swap pop strcat "/usersvoted/" strcat me @ intostr strcat getpropval not and if
                 dump @ dup "/" rinstr strcut swap pop resultOrVote then
             then
             trig dump @ nextprop dump !
             dump @ strlen not
            UNTIL
            me @ "DONE voting on all topics." notify pause
            continue else
        dup "q" stringcmp not if pop me @ trig "/votecfg/closemsg" getpropstr notify me @ "vote:  Program ended." notify exit else
        resultOrVote
	then then then then then
	REPEAT
;
  
: helpmsg ( -- )
        blankline
        me @ "vote.muf  v2.10 by Morticon of SpinDizzy   2015" notify
	me @ "#Help:" notify
        me @ "   #new         -  See if there are new voting topics" notify
        me @ "   #setup       -  Jumps to setting up the object" notify
        me @ "   #unlock      -  Unlocks the object if program crashed" notify
        me @ "   #autocheck   -  Check for new topics on this object upon MUCK" notify
        me @ "                   connection.  Works on one object only!" notify
        me @ "   #!autocheck  -  Disables #autocheck" notify
        blankline
        me @ "   No parameters starts vote.muf normally and allows you to vote, etc." notify
        me @ "   Says and poses can be used at any prompt with \" and : ." notify
	blankline
	exit
;
  
: checknew ( d i -- )
( Checks for new voting topics without entering interactive mode)
( You must supply the db object to check against, for use both with #new and _connect stuff )
( If i is true, then be more verbose (IE: #new command)

        choice ! dbref input !
        background
        0 votetopic !
        input @ BOOTHOPENPFX nextprop counter !
        BEGIN
         counter @ strlen if
          input @ counter @ getPropSuffix me @ isAltVoted? not if
            ( They did not vote on topic, so increment )
            votetopic ++
          then
         
          input @ counter @ nextprop counter !
         then
         counter @ strlen not
        UNTIL
        votetopic @ dup if 1 = if me @ "## There is a new topic you have not voted on in " input @ "/votecfg/name" getpropstr strcat "." strcat else me @ "## There are " votetopic @ intostr strcat " topics you have not voted on in " strcat input @ "/votecfg/name" getpropstr strcat "." strcat then
          else choice @ if me @ "vote:  No new topics to vote on in " input @ "/votecfg/name" getpropstr strcat else " " then then
        dup input ! " " stringcmp if input @ notify then
        exit
;
  
( Program starts execution HERE )
: cmd-vote
        "me" match me !
        read_wants_blanks

        (Zombie check)
        me @ player? if
        ( Process params )
	dup "#help" stringcmp not if 'helpmsg jmp then
        dup "#new" stringcmp not if me @ "vote:  [backgrounded] Checking for new topics..." notify trig int 1 'checknew jmp then
        ( Before doing anything upon Connect autocheck, make sure the object still exists )
        dup "Connect" strcmp not if me @ "/_prefs/vote/boothdb" getpropval dbref dup input ! 
                exit? if input @ else 0 dbref then VERSIONPROP getpropval if input @ int 0 'checknew jmp
                ( If the vote object doesn't exist anymore, remove the props and exit )
                else me @ "/_prefs/vote/boothdb" remove_prop  me @ "/_connect/voteautocheck" remove_prop then exit then
                
        trig VERSIONPROP getpropval VOTEVERSION not = if
            ( Not configured for this version.  Only let the owner in )
            me @ trig controls not if
                "This booth needs to be configured by the owner." sysMessage
                exit
            then
        then

        dup atoi 0 > if atoi 'voteDisplay jmp exit then

          ( If the DB is locked, retry once and then quit if no success )
          trig "/locked" getpropstr dup strlen if
                  me @ "Vote database locked for: " rot strcat ".    Retrying..." strcat notify
                  2 sleep
                  trig "/locked" getpropstr strlen if me @ "Database still locked!  Please try again in a few moments." notify 
                  ( Fix to allow the owner to get in anyway )
                  me @ trig controls if "You are the object owner.  Bypassing lock.  Please run #unlock right away if the program crashed!" sysMessage else 'progExit jmp then then
          else pop then

        dup "#autocheck" stringcmp not if 
                me @ "/_prefs/vote/boothdb" trig int setprop
                me @ "/_connect/voteautocheck" trig getlink int intostr setprop
                me @ "vote:  Autocheck enabled for this voting booth." notify 
                exit then
        dup "#!autocheck" stringcmp not if
                me @ "/_prefs/vote/boothdb" remove_prop
                me @ "/_connect/voteautocheck" remove_prop
                me @ "vote:  Autocheck disabled." notify
                exit then
        dup "#unlock" stringcmp not if 'unlockObject jmp then
        "#setup" stringcmp not if 'setupSetup jmp then
        
        'mainMenu jmp then
        me @ "vote:  Sorry, only players can vote." notify
        exit
;
.
c
q
@set vote.muf=3
@set vote.muf=W
@set vote.muf=L
@set vote.muf=!D
