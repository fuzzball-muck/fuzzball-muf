( /quote -S -dsend '/data/spindizzy/muf/hurl112.muf )
@edit hurl.muf
1 2222 d
i
( hurl.muf v1.12 by Morticon @ Spindizzy.  Name by Kinsor @ Spindizzy       )
( What it does:  Records URLs said in a room for later retrieval in a       )
( spoof-like format.  Don't ask what the 'h' stands for...                  )
(     ----------------------------------------------------------------      )
( Setup: For an object:  Create an object, call it URL Listener or whatever )
(                        Create an action on the object, call it hurl.  Link)
(                           the action to hurl.muf [this program] .         )
(                        Type 'hurl #Help' to learn how to use #install     )
(                        Done!                                              )
(                                                                           )
(       For a room:     Create an action on the room, call it hurl.  Link   )
(                          the action to hurl.muf [ this program ]          )
(                        Type 'hurl #Help' to learn how to use #install     )
(                        Done!                                              )
(                                                                           )
(       To use in desc: Use the mpi {muf:#1234,5678} where #1234 is the     )
(                          dbref of hurl.muf, and 5678 is the room or object)
(                          where the URLs are stored                        )
  
( ** PROGRAM STARTS HERE ** )
$include $lib/strings
  
( Macros )
$def DEFAULTLISTLENGTH 15
$def COMMENTMARKER "<<"
$def ENTRYDIR "/./hURL/URLs"
$def ENTRYPTR "/./hURL/URLs/PTR"
$def ENTRYLIMIT "/./hURL/maxentry"
$def COMMENTDIR "/./hURL/comments"
$def IGNOREPROP "/_prefs/hURL_ignore?"
$def LISTENPROP "/_listen/hurl"
$def LOCKPROP "/./hURL/lock"
$def LOCKUSERPROP "/./hURL/lockUser"
   
( Uncomment for pre FB6 )
( $def ++ dup @ 1 + swap ! )
( $def -- dup @ 1 - swap ! )
  
( Globals )
lvar URLStorage
  
( May be used or changed by any function at any time )
lvar counterA
  
( Function specific )
lvar urlParse_string
lvar urlParse_URLpos
  
lvar urlList_stop

lvar urlFind_seenPtr
  
( -------------------------------------------------------------------------- )
  
( -- Helpers -- )
: sysMessage ( s --   Prefixes 'hURL:  ' to string and outputs completed string to user )
        me @ swap "hURL:  " swap strcat notify
;
  
: blankline ( -- )
        me @ " " notify exit
;
  
: playerName ( i -- s)
( Given an integer or dbref, returns a string with the name of the player, or returns '*Toaded Player*' if needed)
        dup dbref? not if dbref then
        ( Else, process player name normally )
        dup player? if name else pop " " then
        exit
;
( -- -- )
  
( -- Prop manager -- )
: abortHurl ( --   Emergency abort )
    "***An internal error prevented your request from being fufilled" sysMessage
    pid kill
    exit
;
  
: isLocked? ( -- i )
        URLStorage @ LOCKPROP getpropstr "" strcmp exit
;
  
: lockHold ( -- )
        ( If the DB is locked, loop until it's unlocked. )
        isLocked? if
          2 sleep
          isLocked? if
                  ( It will try up to 60 seconds.  If it cannot find it unlocked, program aborts )
                  0
                  begin
                    1 sleep
                    me @ awake? not if "User disconnected during lockHold.  Possible hURL problem?" abort then
  
                    1 + dup 60 > if pop 'abortHurl jmp then
  
                  isLocked? not
                  until
                  pop
          then
        then exit
;
  
: lockDB ( s -- )
( Marks the DB as locked with string s as the reason. )
        lockHold
        URLStorage @ LOCKPROP rot setprop
        URLStorage @ LOCKUSERPROP me @ setprop
        1 sleep
        exit
;
  
: unlockDB ( -- )
( Marks the DB as unlocked )
        URLStorage @ LOCKPROP remove_prop
        URLStorage @ LOCKUSERPROP remove_prop
        exit
;
( -- -- )
  
: isInstalled? ( -- i returns true if URLStorage is installed with hURL, false otherwise )
    URLStorage @ ENTRYLIMIT getpropval
    URLStorage @ LISTENPROP getpropstr atoi dbref prog
    dbcmp
    and
;
  
: isDuplicate? ( s -- i  If URL is already in list, return 1, else 0 )
    URLStorage @ ENTRYDIR getpropval dup
    ( Only bother if there is an entry )
    if
        ( Prime the loop )
        0 counterA !
        BEGIN
            ( If dupe found, return 1 )
            URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "string" strcat getpropstr 3 pick stringcmp not if
                pop pop 1 exit
            then

            ( Try the next entry until no more entries left )
            counterA ++
            counterA @ over >=
        UNTIL
    then

    pop pop

    ( No dupe found, so return 0 )
    0
;
  
: addLine ( d s1 s2 --  Adds string s1 with optional comment s2, as emitted from database entry d,
            to a scrolling list, like spoof #recent.  If s2 is "", no comment is added )

    ( Push the comment to the back for now )
    -3 rotate

    ( If the list of lines aren't full, just append the entry )
    URLStorage @ ENTRYDIR getpropval dup URLStorage @ ENTRYLIMIT getpropval < if
            (entrydir value) counterA !
            URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "string" strcat 3 rotate setprop
            URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "db" strcat 3 rotate setprop
            URLStorage @ ENTRYDIR counterA @ ++ setprop
            URLStorage @ ENTRYPTR -1 setprop

            ( And add the comment, if there is one )
            dup strlen if
                URLStorage @ COMMENTDIR "/" strcat counterA @ intostr strcat rot setprop
            else
                pop
                ( No comment, so remove the prop to erase the one from a previous URL )
                URLStorage @ COMMENTDIR "/" strcat counterA @ intostr strcat remove_prop
            then
            exit
        else
            pop
        then
  
    ( Else, we need to 'scroll' everything up by one to fit new entry )
    URLStorage @ ENTRYPTR getpropval 1 + dup
    URLStorage @ ENTRYDIR getpropval
    = if pop 0 then
    dup counterA !
    URLStorage @ ENTRYPTR rot setprop

    ( At correct entry slot, so put in new one )
    URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "string" strcat rot setprop
    URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "db" strcat rot setprop
    ( And add the comment, if there is one )
    dup strlen if
        URLStorage @ COMMENTDIR "/" strcat counterA @ intostr strcat rot setprop
    else
        pop
        ( No comment, so remove the prop to erase the one from a previous URL )
        URLStorage @ COMMENTDIR "/" strcat counterA @ intostr strcat remove_prop
    then
  
    exit
;
  
: urlParse  ( s -- Searches s for URLs.  If one or more are found, uses addLine to store them )

   ( Remove a trailing " if needed )
   dup dup "\"" rinstr swap strlen = if
     dup strlen 1 - strcut pop
   then

    urlParse_string !
    0 urlParse_URLpos !

    BEGIN
        ( Check for a familiar prefix, whichever comes first in the string is
          used )
        urlParse_string @ "http:" instring
        urlParse_string @ "https:" instring
  
        ( Pick the earliest matching prefix but skip zero! )
        over over      (h: s: h: s: )
        < if
            swap
        then
        dup if swap pop else pop then
        urlParse_URLpos !
        
        urlParse_string @
  
        dup "www." instring dup dup
            if
                urlParse_URLpos @ < urlParse_URLpos @ 0 = or if urlParse_URLpos ! else pop then
            else pop pop then
  
        dup "ftp:" instring dup dup
            if
                urlParse_URLpos @ < urlParse_URLpos @ 0 = or if urlParse_URLpos ! else pop then
            else pop pop then
  
        dup "ftp." instring dup dup
            if
                urlParse_URLpos @ < urlParse_URLpos @ 0 = or if urlParse_URLpos ! else pop then
            else pop pop then
  
        pop
  
        ( -- Future expansion -- )
        ( if not found that way, eventually make it check for things in the middle, like )
        (  .com ,  .org, .net  etc )
 
        ( if found )
        urlParse_URLpos @ if
            ( grab everything from instring up until the newline )
            urlParse_string @ urlParse_URLpos @ 1 - strcut swap pop
            ( Save off everything after the URL for another parse - they could have 2+ URLs in the string )
            dup " " instring dup if strcut urlParse_string ! else pop 0 urlParse_URLpos ! then
            strip
  
            ( ** Special edition hack! ** )
            ( Don't add if string is 'www.'.  This is a WORKAROUND until a )
            ( more robust parser is implemented )
                dup tolower dup "www.." instr 1 = swap "www." strcmp not or if pop else
            ( ** End hack ** )
  
            ( Store the result if not a duplicate )
            dup isDuplicate? not if
                ( Before storing, check for a comment to store it as well )
                urlParse_string @ striplead dup COMMENTMARKER instr 1 = if
                    ( Found a comment, extract it )
                    COMMENTMARKER strlen strcut swap pop strip
                    ( This will cause the loop to terminate)
                    0 urlParse_URLpos !
                else
                    pop ""
                then
                "urlParse" lockDB
                ( dup the URL, which is behind the comment )
                over swap

                dup me @ owner 4 rotate rot addLine
                unlockDB
                ( Notify person a URL was stored )
                strlen if
                    "URL saved (with comment): "
                else
                    "URL saved: "
                then

                swap strcat sysMessage
            else
                pop
            then

            ( ** SPECIAL EDITION HACK ** )
            then
            ( ** END HACK ** )
        then
  
        ( Just in case it somehow gets wierd )
        me @ owner awake? not if "User disconnected during hurl parsing.  Possible problem?" abort then
  
    urlParse_URLpos @ not
    UNTIL
    exit
;

: findLastUrl ( -- i  Finds the last URL recorded by user in var me, 
                      returning index number, or -1 if not found )
    0 urlFind_seenPtr !

    URLStorage @ ENTRYDIR getpropval
    ( Only bother if there is an entry )
    if
        ( Figure out where to stop/start )
        URLStorage @ ENTRYPTR getpropval  dup (Stop here )
        -1 = if 
            ( Start at end, if havn't scrolled )
            URLStorage @ ENTRYDIR getpropval 1 -
            swap pop dup
        else
            ( Start at pointer, since we've scrolled )
            dup
        then

        counterA !  ( Contains where to start )
        ( Remember the stop pointer is still in the stack )
        BEGIN
            URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "db" strcat getprop
            dup dbref? not if dbref then
            me @
            ( Is the current entry done by me? )
            dbcmp if
                pop 
                ( Return the index )
                counterA @
                exit
            then

            ( Just in case it somehow gets wierd )
            me @ owner awake? not if unlockDB "User disconnected during hurl searching.  Possible problem?" abort then

            ( We've scanned every entry.  Stop )
            dup counterA @ = if
                urlFind_seenPtr @ if
                    break
                else
                    1 urlFind_seenPtr !
                then
            then

            (Loop around as needed, wrapping around as needed too)
            counterA --
            ( Time to wrap around! )
            -1 counterA @ = if URLStorage @ ENTRYDIR getpropval 1 - counterA ! then
        REPEAT ( Leave manually )
        pop
    then
  
    ( Didn't find anything, so return -1 )
    -1
;
  
: urlErase ( s -- s Erase last URL said by var me, returning the string erased, or " " if none erased )
    findLastUrl

    dup -1 = not if
        ( Return this )
        URLStorage @ ENTRYDIR "/" strcat 3 pick intostr strcat "string" strcat getprop
        (It was!  Blank it out!)
        URLStorage @ ENTRYDIR "/" strcat 4 pick intostr strcat "db" strcat -1 dbref setprop
        URLStorage @ ENTRYDIR "/" strcat 4 pick intostr strcat "string" strcat " " setprop
        URLStorage @ COMMENTDIR "/" strcat 4 pick intostr strcat remove_prop
    else
        ( Didn't find anything, so return " " )
        " "
    then

    swap pop
;

: addUrlComment ( s -- s  Given a comment string, set comment for the last URL
                          recorded by the user in var me.  Return the URL
                          commented on, or " " if no comment was made )
    findLastUrl

    dup -1 = not if
        URLStorage @ ENTRYDIR "/" strcat 3 pick intostr strcat "string" strcat getprop
        URLStorage @ COMMENTDIR "/" strcat 4 pick intostr strcat 5 rotate setprop
    else
        ( Didn't find anything, so return " " )
        " "
    then

    swap pop
;

: urlList ( --  Outputs the current list of URLs )
    URLStorage @ ENTRYDIR getpropval
    ( Only bother if there is an entry )
    if
        ( Start after the ptr )
        URLStorage @ ENTRYPTR getpropval dup urlList_stop ! 1 +
        URLStorage @ ENTRYDIR getpropval
        %
        counterA !
  
        ( Now, do the loop )
        URLStorage @ ENTRYDIR getpropval
        BEGIN
            ( Get the name of the person who said the URL )
            ( Name )
            URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "db" strcat getprop playerName
            15 STRleft
            ( Name  | )
            "| " strcat
            (Name  | http://... )
            URLStorage @ ENTRYDIR "/" strcat counterA @ intostr strcat "string" strcat getpropstr strcat
            ( Output to user )
            me @ swap notify

            ( Output comment on separate line if there is one )
            URLStorage @ COMMENTDIR "/" strcat counterA @ intostr strcat getpropstr dup
            strlen if
                me @ "   - " rot strcat notify
            else
                pop
            then
  
            ( Just in case it somehow gets wierd )
            me @ owner awake? not if "User disconnected during hurl #recent.  Possible problem?" abort then

        ( Stop if we've wrapped around )
        counterA @ urlList_stop @ = if pop break then
        ( Else, increment and continue on )
        dup counterA @ 1 + swap % dup counterA !
        ( But don't wrap if we havn't ever scrolled )
        0 = urlList_stop @ -1 = and if pop break then
        REPEAT
    then
;
  
: hurlHelp ( --  Displays the help screen )
    me @ "hURL v1.12 by Morticon@SpinDizzy   {Name by Kinsor@SpinDizzy}  2014" notify
    me @ "  Description:  hURL listens in on a room and notes down any URLs said or" notify
    me @ "                posed. It does NOT listen in on pages or whispers.  The" notify
    me @ "                most recent URLs captured may be viewed by all." notify
    me @ "                Use << after a URL to make the rest of the line a" notify
    me @ "                comment." notify
    me @ "                Example: 'http://www.spindizzy.org << SpinDizzy MUCK'" notify
    me @ "  Usage:" notify
    me @ "      #comment xx - Sets the comment for the last URL you said to xx" notify
    me @ "      #recent     - Show the last few URLs recorded" notify
    me @ "      #ignore     - Causes hURL to ignore whatever you say (won't record URLs)" notify
    me @ "      #!ignore    - The reverse of #ignore. Causes hURL to listen to you again" notify
    me @ "      #erase      - Remove the last URL you said from the URL list" notify
    me @ "      #status     - Tells you if hURL is currently enabled" notify
    me @ "      #help       - This screen" notify
    blankline
    ( Show admin help if admin of the object )
    me @ URLStorage @ controls if
        me @ "  The following options are for the object owner only:" notify
        me @ "      #install xx - Activate hURL and keep a history of xx URLs.  xx > 2." notify
        me @ "                     example: 'hURL #install 25' keeps 25 URLs" notify
        me @ "      #install    - Activates hURL and keeps the last history setting" notify
        me @ "      #disable    - Causes hURL not to listen anymore to anyone in the room" notify
        me @ "      #clear      - Clears the list of URLs" notify
        me @ "      #remove     - Disables and removes all props related to hURL" notify
        me @ "      ## text     - Adds a divider line with 'text' in it" notify
        me @ "      #reset      - Used if program crashed and stops working" notify
        blankline
    then
    exit
;
  
: hurlProcess
    ( Only process if string is not empty )
    strip dup if
        background
        "me" match owner me !   ( Owner of zombies is used )
        ( If user has disabled prop, then exit right away )
        me @ IGNOREPROP getpropstr "y" instring if exit then
        ( Else, call urlParse on string )
        trig URLStorage !
        'urlParse jmp
    then
;
  
: paramProcess ( --  s Processes the arguments )
    background
    strip

    ( For #recent )
    dup "#rec" instring if
        lockHold
        me @ "Here are the last " URLStorage @ ENTRYDIR getpropval intostr strcat " URLs said:" strcat notify
        'urlList jmp
    then

    ( For #comment )
    dup "#co" instring 1 = if
        "me" match owner me !   ( Owner of zombies is used )
        dup " " instr dup if
            "paramProcess" lockDB
            strcut strip addUrlComment
            unlockDB
          dup " " strcmp if
            "Commented on URL: " swap strcat sysMessage
          else
            pop "No URLs by you are in the list, so the comment was not added." sysMessage
          then
        else
            'hurlHelp jmp
        then
        exit
    then

    ( For #erase )
    dup "#er" instring if
        "me" match owner me !   ( Owner of zombies is used )
        "paramProcess" lockDB
        urlErase
        unlockDB
        dup " " strcmp if "Erased URL: " swap strcat sysMessage
                       else
                          pop "No URLs by you are in the list, so none were erased." sysMessage
                       then
        exit
    then

    ( For #disable )
    dup "#di" instring if
        "me" match owner me !   ( Owner of zombies is used )
        (Security check)
        me @ URLStorage @ controls not if
            "Not owner.  Cannot run #disable" sysMessage
            exit
        then
  
        ( Do the disable if owner )
        URLStorage @ LISTENPROP remove_prop
        "Listening disabled.  No new URLs will be recorded." sysMessage
        exit
    then
  
    ( For #clear )
    dup "#cl" instring if
        "me" match owner me !   ( Owner of zombies is used )
        (Security check)
        me @ URLStorage @ controls not if
            "Not owner.  Cannot run #clear" sysMessage
            exit
        then
  
        ( Do the clear if owner )
        "paramProcess" lockDB
        URLStorage @ ENTRYDIR remove_prop
        URLStorage @ COMMENTDIR remove_prop
        "The list of URLs has been cleared." sysMessage
        unlockDB
        exit
    then
  
    ( For ##  [divider] )
    dup "##" instring if
        "me" match owner me !   ( Owner of zombies is used )
        (Security check)
        me @ URLStorage @ controls not if
            "Not owner.  Cannot run ##  (divider)" sysMessage
            exit
        then
  
        ( Get the text string to use )
        dup " " instr strcut swap pop strip
        ( Add some ### )
        "### " swap strcat " ###" strcat dup
        ( Now, add to the URL list )
        "paramProcess" lockDB
        me @ swap "" addLine
        unlockDB
        "Divider line added: " swap strcat sysMessage
    exit
    then

    ( For #remove )
    dup "#rem" instring if
        "me" match owner me !   ( Owner of zombies is used )
        (Security check)
        me @ URLStorage @ controls not if
            "Not owner.  Cannot run #remove" sysMessage
            exit
        then
  
        ( Do the remove if owner )
        "paramProcess" lockDB
        URLStorage @ ENTRYDIR remove_prop
        URLStorage @ LISTENPROP remove_prop
        URLStorage @ ENTRYLIMIT remove_prop
        URLStorage @ COMMENTDIR remove_prop
        "hURL has been removed (uninstalled) entirely." sysMessage
        unlockDB
        exit
    then
  
    ( For #install )
    dup "#in" instring if
        "me" match owner me !   ( Owner of zombies is used )
        (Security check)
        me @ URLStorage @ controls not if
            "Not owner.  Cannot run #install" sysMessage
            exit
        then
  
        strip dup " " rinstr dup if
            ( number specified, do install )
            strcut swap pop strip atoi dup
            ( But make sure it is > 2 )
            3 < if pop 3 3 else dup then

            "Using specified URL list limit of " swap intostr strcat "." strcat sysMessage
            URLStorage @ ENTRYLIMIT rot setprop
            ( Remove existing list, since it likely changed the amount )
            URLStorage @ ENTRYDIR remove_prop
        else
            pop pop
            ( No number specified, so use existing or make default )
            URLStorage @ ENTRYLIMIT getpropval dup if
                "Using existing URL list limit of " swap intostr strcat "." strcat sysMessage
            else
                pop
                "Using default URL list limit of " DEFAULTLISTLENGTH intostr strcat "." strcat sysMessage
                URLStorage @ ENTRYLIMIT DEFAULTLISTLENGTH setprop
            then
        then
  
        ( Add the listener )
        URLStorage @ LISTENPROP prog intostr setprop
  
        "hURL has been installed and is active." sysMessage
        exit
    then
  
    ( For #status )
    dup "#st" instring if
        isInstalled? if
            "hURL is properly installed and active (listening)." sysMessage
            "me" match owner me !   ( Owner of zombies is used )
            me @ IGNOREPROP getpropstr "yes" strcmp not if
                "hURL is currently set to ignore you." sysMessage
            then
        else
            "hURL is either not properly installed or not active (not listening)." sysMessage
        then
    exit
    then

    ( for #reset )
    dup "#reset" instring if
        "me" match owner me !   ( Owner of zombies is used )
        (Security check)
        me @ URLStorage @ controls not if
            "Not owner.  Cannot run #reset" sysMessage
            exit
        then

        unlockDB
        "Database was forcibly unlocked." sysMessage
    exit
    then
  
    ( For #ignore )
    dup "#ig" instring if
        "me" match owner me !   ( Owner of zombies is used )
        me @ IGNOREPROP "yes" setprop
        "hURL will now ignore everything you say." sysMessage
    exit
    then
  
    ( For #!ignore )
    "#!ig" instring if
        "me" match owner me !   ( Owner of zombies is used )
        me @ IGNOREPROP remove_prop
        "hURL will now listen for URLs said by you." sysMessage
    exit
    then
  
    ( Else, display help )
    'hurlHelp jmp
;
  
: hURL-dispatcher
    ( Security )
    "me" match me !

    ( Don't want non-alive objects to use this program - they may do all kinds of wacky stuff )
    me @ owner awake? not if pid kill then

    ( If triggered as a listener, jump to listener code )
    COMMAND @ "_Listen" rinstring if 'hurlProcess jmp exit then
  
    ( if triggered as {muf: }, then show the current list of URLs )
    dup atoi 0 > if 
        atoi dbref dup URLStorage !
        ( Security check. Must be owned by the same person )
        owner trig owner dbcmp not if
            ( Not the same owner. Abort )
            "Cannot use {muf:} with a target object that has a different owner than the trigger!" sysMessage
            exit
        then
        lockHold
        me @ "Here are the last " URLStorage @ ENTRYDIR getpropval intostr strcat " URLs said:" strcat notify
        'urlList jmp exit
    then

    ( Else, then process params )
    trig dup location dup URLStorage !
    ( Security check!  Action must be same owner as listener object )
    owner swap owner dbcmp not if
            ( Not the same owner. Abort )
            "Action and listener object have different owners!  Cannot run." sysMessage
            exit
        then
    'paramProcess jmp exit
;
.
c
q
@set hurl.muf=3
@set hurl.muf=L
( @set hurl.muf=/_docs:@list <PROG DB#>=1=18 )
