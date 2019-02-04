( /quote -dsend -0 '/data/spindizzy/muf/eventlist128.muf )
@prog eventlist.muf
1 2222 d
i

(To install this program [wizzes only] do something like a
 /quote -dsend 'eventlist.muf    under TF.  basically, just cut and
 paste this file.  It will make the program, enter the editor, compile,
 and finally set the privs [WM3].  After that, add it to plib if you have it
  and, optionally, do a  @set eventlist.muf=/_docs:@list <PROG DB#>=7=17 )
( Please note guests are determined by the existance of a /@guest prop on them with a non-zero length string set )
  
( eventlist.muf v1.28 by Morticon@Spindizzy.  Some ideas by Kinsor@Spindizzy)
( 1.28 fix: Fix timezone problem where the time appears offset from what was entered )
  
( Welcome to my 1400+ line event lister!  Setup is easy:  Make an action and link this program to it.  Then, run #setup.  More Information can be found by running with #help )
( Wizzes will find instructions within #setup for global event notifications )
( To let people 'look' at your event object to see many events, add
  something to the desc of an object like {nl}{muf:#1234,showeventlist 5678}  Where
  1234 is the eventlist.muf db #, and 5678 is the db # of the action that
  contains the event listings )
  
$include $lib/strings
$include $lib/edit
$include $lib/lmgr
$include $lib/editor
$def LMGRgetcount lmgr-getcount
$def LMGRgetrange lmgr-getrange
$def LMGRputrange lmgr-putrange
$def LMGRdeleterange lmgr-deleterange
$def MAILCMD "mail"
$def ELver 128
$def DAYSEC 86400
  
( The Variables.  Whew )
lvar listDB    ( Used like trig.  Used because program could be run from things other than actions )
lvar parameters
lvar stepTime
  
lvar propIterA
lvar propIterB
  
lvar counterA
lvar counterB

( To get around DST offset bug )
lvar dstOffset
  
( For showing event lists only - short or long form )
lvar elShortOrLong
lvar elPropIter
lvar elNameIter
lvar elNames
lvar elDisplayProp
lvar elRSVPIter
lvar dupHold
  
( used while creating / editing an event )
lvar eventTitle
lvar eventSystimeFrom
lvar eventSystimeTo
lvar eventLocation
lvar eventAge
lvar eventRSVP
  
( Menu stuffs )
lvar menuState
lvar menuParameters
lvar eventNum

: stackCount ( -- )
        me @ "STACK SIZE: " depth 2 - intostr strcat notify
;
  
: clearstack ( -- less items on stack )
(Keeps the stack from accidently getting too big)
        BEGIN
         depth 1 > if pop then
         depth 1 > not
        UNTIL
        exit
;

: sysMessage ( s --   Prefixes 'eventlist.muf: ' to string and outputs completed string to user )
        me @ swap "eventlist.muf: " swap strcat notify
;

: blankline ( -- )
        me @ " " notify exit
;

: aborted ( -- )
        blankline "Program aborted.  Any unsaved information was lost." sysMessage blankline exit
;


: pause  ( -- )
        blankline
        me @ "--Output paused.  Press the SPACEBAR and ENTER to continue--" notify
        read pop exit
;

: playerName ( i -- s)
( Given an integer or dbref, returns a string with the name of the player, or returns '*Toaded Player*' if needed)
        dup dbref? not if dbref then
        dup player? if name else pop "Toaded_Player" then
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
        "<In Eventlist> " me @ name strcat " " strcat swap strcat .tell
      else
        dup me @ swap "<In Eventlist> You " me @ "_say/def/say" getpropstr 
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

( ---Copied and modified from cmd-lsedit )

: LMGRdeletelist
  over over LMGRgetcount
  1 4 rotate 4 rotate LMGRdeleterange
;
  
  
  
: LMGRgetlist
  over over LMGRgetcount
  rot rot 1 rot rot
  LMGRgetrange
;
  
  
: lsedit-loop  ( listname dbref {rng} mask currline cmdstr -- )
    EDITORloop
    dup "save" stringcmp not if
        pop pop pop pop
        3 pick 3 + -1 * rotate
        over 3 + -1 * rotate
        dup 5 + pick over 5 + pick
        over over LMGRdeletelist
        1 rot rot LMGRputrange
        4 pick 4 pick LMGRgetlist
        dup 3 + rotate over 3 + rotate
        "< List saved. >" .tell
        "" lsedit-loop exit
    then
    dup "abort" stringcmp not if
        "< list not saved. >" .tell
        pop pop pop pop pop pop pop pop pop exit
    then
    dup "end" stringcmp not if
        pop pop pop pop pop pop
        dup 3 + rotate over 3 + rotate
        over over LMGRdeletelist
        1 rot rot LMGRputrange
        "< list saved. >" .tell exit
    then
;
  
: cmd-lsedit
    "=" .split strip
    "/" swap strcat
    begin dup "//" instr while "/" "//" subst repeat
    swap strip
    atoi dbref
"<    Welcome to the list editor.  You can get help by entering '.h'     >"
.tell
"< '.end' will exit and save the list.  '.abort' will abort any changes. >"
.tell
"<    To save changes to the list, and continue editing, use '.save'     >"
.tell
    over over LMGRgetlist
    "save" 1 ".i $" lsedit-loop
;

( ----------- )


( ---- Taken from lib-propdirs    v1.1    Jessy @ FurryMUCK    5/97, 8/01  )
( ----    Library appears to be a security risk, so it is not included )
: copy_dir   ( d1 s1 d2 s2 --  ) (* copy dir s1 on d1 to dir s2 on d2.
                                    do not copy subdirs               *)
    4 pick 4 pick propdir? if
        3 pick "*/" smatch not if
            3 pick "/" strcat 3 put
        then
    else
        pop pop pop pop exit
    then
    dup "*/" smatch not if
        "/" strcat
    then
    
    3 pick 5 rotate 5 rotate 5 rotate 5 rotate
    dup 5 rotate 5 rotate 5 rotate 5 rotate
    
    4 pick 4 pick nextprop dup 4 put
    5 rotate 5 rotate 5 rotate 5 rotate
    
    begin
        4 pick 4 pick getprop if
            pop over
            7 pick 7 pick swap subst
            4 pick 4 pick 4 pick 4 pick
            4 rotate 4 rotate getprop setprop
            4 pick 4 pick nextprop dup not if
                break
            then
            dup 4 put 5 put
        else
            4 pick 4 pick dup "*/" smatch if
                dup strlen 1 - strcut pop
            then
            over over nextprop not if
                pop pop break
            then
            nextprop dup 4 put 5 put
        then
        pop over 7 pick 7 pick swap subst
    repeat
    pop pop pop pop pop pop pop pop
;
( ------------------------------------- )


: dateCheck ( s -- s     Returns the string put into it if it contains no :, -, or /.  Returns "0" if it does )
        dup "/" instr if pop "You may not use / when specifying a date" sysMessage "0" exit then
        dup ":" instr if pop "You may not use : when specifying a time" sysMessage "0" exit then
        dup "-" instr if pop "You may not use - when specifying a date" sysMessage "0" exit then
;

: lockDB ( s -- )
( Marks the DB as locked with string s as the reason. )
        ( If it's already locked, abort program )
        listDB @ "/lockuser" getpropval 0 = not if "Database already locked!  See object owner to fix" abort then
        listDB @ "/locked" rot setprop
        listDB @ "/lockuser" me @ int setprop
        1 sleep
        exit
;

: unlockDB ( -- )
( Marks the DB as unlocked )
        listDB @ "/locked" remove_prop
        listDB @ "/lockuser" remove_prop
        exit
;

: isLocked? ( -- i )
        listDB @ "/locked" getpropstr "" strcmp exit
;

: lockHold ( -- )
        ( If the DB is locked, say so and loop until it's unlocked.  To be used while inside the menus )
        listDB @ "/locked" getpropstr "" stringcmp if
          "Database locked by user: " listDB @ "/lockuser" getpropval dbref playerName strcat " >>for>> " strcat listDB @ "/locked" getpropstr strcat ".    Retrying..." strcat sysMessage
          3 sleep
          listDB @ "/locked" getpropstr "" stringcmp if 
                  "Database still locked!  Retrying... (Type '@Q' to abort program)" sysMessage
                  begin
                    2 sleep
                    me @ awake? not if "User disconnected during lockHold.  Possible event DB problem?" abort then
                    listDB @ "/locked" getpropstr "" stringcmp not
                  until
          then  "Database unlocked.  Resuming execution..." sysMessage
        then exit
;

: getNewEventNumber ( -- i  Find an available event number)
        isLocked? not if "getNewEventNumber: DB not locked." abort then

        0
        BEGIN
                1 + dup dup
                listDB @ "/events/db/" rot intostr strcat getpropval
        = not
        UNTIL
;

: addToCalendar (i --  Adds event i to the calendar.)
        (  Uses counterA, counter B, eventSystimeFrom, eventSystimeTo)
        isLocked? not if "addToCalendar: DB not locked." abort then

        counterA !

        ( Get the systimes... )
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeFrom" strcat getpropval eventSystimeFrom !
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeTo" strcat getpropval eventSystimeTo !

        ( Now, populate the calendar )
        eventSystimeFrom @ counterB !
        BEGIN
                "%y%m%d" counterB @ timefmt atoi "%y%m%d" eventSystimeTo @ timefmt atoi <= if
                        listDB @ dup "/events/calendar/" "%y%m%d" counterB @ timefmt strcat dup rot swap getpropval 1 + setprop
                        listDB @ "/events/calendar/" "%y%m%d" counterB @ timefmt strcat "/" strcat counterA @ intostr strcat counterA @ setprop
                        0 else 1 then  ( Used for UNTIL evaluating )
                counterB @ DAYSEC + counterB !
        UNTIL        
;

: copyEvent (i1 i2 istart iend --    Copies event i1 into i2, with new start and end times.  Does calendar updates)
        ( Uses counterA, counter B, eventSystimeFrom, eventSystimeTo )
        eventSystimeTo ! eventSystimeFrom !
        counterB ! counterA !

        ( Copy root props )

        ( Get them )
        listDB @ "/events/db/" counterA @ intostr strcat "/title" strcat getpropstr eventTitle !
        listDB @ "/events/db/" counterA @ intostr strcat "/location" strcat getpropstr eventLocation !
        listDB @ "/events/db/" counterA @ intostr strcat "/age" strcat getpropstr eventAge !
        listDB @ "/events/db/" counterA @ intostr strcat "/rsvp?" strcat getpropstr eventRSVP !

        ( Set them )
        listDB @ "/events/db/" counterB @ intostr strcat counterB @ setprop
        listDB @ dup "/events/db" dup rot swap getpropval 1 + setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/owner" strcat listDB @ "/events/db/" counterA @ intostr strcat "/owner" strcat getprop setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/desc#" strcat listDB @ "/events/db/" counterA @ intostr strcat "/desc#" strcat getprop setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/systimeFrom" strcat eventSystimeFrom @ setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/systimeTo" strcat eventSystimeTo @ setprop

        listDB @ "/events/db/" counterB @ intostr strcat "/title" strcat eventTitle @ setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/location" strcat eventLocation @ setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/age" strcat eventAge @ setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/rsvp?" strcat eventRSVP @ setprop
        listDB @ "/events/db/" counterB @ intostr strcat "/rsvp" strcat 0 setprop

        ( Copy description )
          listDB @ "/events/db/" counterA @ intostr strcat "/desc#/" strcat
          listDB @ "/events/db/" counterB @ intostr strcat "/desc#/" strcat
        copy_dir

        ( Add to calendar )
        counterB @ addToCalendar
;

( The views )
: longView  ( i --   Displays event i in long form )
        ( Uses all el* vars )

        ( Accepts integers OR a string number )
        dup int? if intostr then
        "/events/db/" swap strcat elDisplayProp !
        ( Let's see if the event exists.  If not, exit immediatly )
        listDB @ elDisplayProp @ getpropval dup 0 = if pop "Event does not exist!" sysMessage exit then

        me @ "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" notify
        
        intostr me @ "+Number:      " rot strcat notify
        me @ "+Title:       " listDB @ elDisplayProp @ "/title" strcat getpropstr strcat notify
        ( From.. To  formatting )
        "+From:        " "%a %x   %I:%M %p" listDB @ elDisplayProp @ "/systimefrom" strcat getpropval timefmt strcat
        "     +To:   " strcat "%a %x   %I:%M %p" listDB @ elDisplayProp @ "/systimeto" strcat getpropval timefmt strcat
        me @ swap notify
        ( Location )
        me @ "+Location:    " listDB @ elDisplayProp @ "/location" strcat getpropstr strcat notify
        ( Do the age )
        "+Age:         " listDB @ elDisplayProp @ "/age" strcat getpropstr 24 strcut pop 25 STRleft strcat
        ( output it )
        me @ swap notify
        me @ "+Event Owner: " listDB @ elDisplayProp @ "/owner" strcat getprop playerName strcat notify
        ( Make the RSVP string )
        "+RSVPs (" listDB @ elDisplayProp @ "/rsvp" strcat getpropval intostr strcat "):   " strcat
        listDB @ elDisplayProp @ "/rsvp?" strcat getpropstr "yes" stringcmp if "RSVPing on this event is disabled" strcat
                else
                listDB @ elDisplayProp @ "/rsvp/" strcat nextprop dup elRSVPIter !
                "" stringcmp if
                  BEGIN
                        (Displays everyone who RSVPed)
                        listDB @ elRSVPIter @ getprop playerName "   " strcat strcat
                        listDB @ elRSVPIter @ nextprop dup elRSVPIter !
                        "" stringcmp not
                  UNTIL then 
                then
        me @ swap notify

        me @ "+Description:" notify
        ( Do the long description )
        elDisplayProp @ "/desc" strcat listDB @ LMGR-FullRange LMGR-GetBRange
        dup if
                BEGIN
                        swap me @ swap notify
                        1 - dup not
                UNTIL pop
        else pop then
;

: shortViewHeader
        me @ "#  | Title                                   | FROM DATE/TIME |  TO DATE/TIME" notify
        me @ "---|-----------------------------------------|----------------|---------------" notify
;

: shortView  ( i -- Displays event i in short form )
        ( Uses all el* vars )

        ( Accepts integers OR a string number )
        dup int? if intostr then
        "/events/db/" swap strcat elDisplayProp !
        ( Let's see if the event exists.  If not, exit immediatly )
        listDB @ elDisplayProp @ getpropval dup 0 = if pop exit then

        ( Form the output line <<number | title | >> )
        intostr 3 STRleft "|" strcat listDB @ elDisplayProp @ "/title" strcat getpropstr 40 strcut pop 40 STRleft strcat " | " strcat
        ( Form the output line << from date/time | >> )
        "%x %R" listDB @ elDisplayProp @ "/systimefrom" strcat getpropval timefmt strcat " | " strcat
        ( Form the output line << to date/time >> )
        "%x %R" listDB @ elDisplayProp @ "/systimeto" strcat getpropval timefmt strcat
        ( Output to user)
        me @ swap notify
  
        ( Second output line has location )
        "   |  Location: "
        listDB @ elDisplayProp @ "/location" strcat getpropstr strcat 
        75 strcut pop
        me @ swap notify
;

: formatDate  (i1 -- s    i1 is in the format of YYMMDD, and s is in the format of "MM/DD/YY" )
        dup string? not if intostr then
        dup "0" strcmp not if pop "00/00/00" exit then
        dup strlen 3 = if "000" swap strcat then
        dup strlen 4 = if "00" swap strcat then
        dup strlen 5 = if "0" swap strcat then

        dup strlen 2 - strcut swap dup strlen 2 - strcut  "/" swap 4 rotate "/" swap 4 rotate 5 rotate strcat strcat strcat strcat
;

: formatTime (i1 -- s   i1 is in the format of HHMMSS, and s in the format of "HH:MM:SS" )
        intostr dup strlen 1 = if "00000" swap strcat then
        dup strlen 2 = if "0000" swap strcat then
        dup strlen 3 = if "000" swap strcat then
        dup strlen 4 = if "00" swap strcat then
        dup strlen 5 = if "0" swap strcat then

        dup strlen 2 - strcut swap dup strlen 2 - strcut ":" swap 4 rotate ":" swap strcat strcat strcat strcat
;

: dateToSystime ( i0 i1 -- i2   i0 in the format of HHMMSS, i1 is in the format of YYMMDD, and i2 is i1 and i0 in systime format )
        ( Turn into an MPI evaluation string, since they have a fucntion I want!)
        formatDate swap formatTime swap " " swap strcat strcat "{convtime:" swap "}" strcat strcat

        ( Store into a temporary property, parse the MPI, remove the property, and return the systime value as an int to the user )
        me @ "/_prefs/eventlist/systimeTemp" rot setprop
        me @ "/_prefs/eventlist/systimeTemp" "(@succ)" 1 parseprop atoi
        me @ "/_prefs/eventlist/systimeTemp" remove_prop

        ( DST offset bug with convtime which does not take DST into account )
        dstOffset @ +
;

: setDSTOffset  ( --  Sets the global variable dstOffset to account for bug in {convtime: } )
    var currentTime

    systime currentTime !
    0 dstOffset !

    "%H%M%S" currentTime @ timefmt atoi "%y%m%d" currentTime @ timefmt atoi dateToSystime
    currentTime @ swap - dstOffset !
;

: rsvp? (d i -- i    Given a player db# and the event number, determine if they are RSVPed for it.  1 if yes, 0 if no )
        listDB @ rot rot intostr "/events/db/" swap strcat swap intostr "/rsvp/" swap strcat strcat getprop dup dbref? if int then if 1 else 0 then
;

: event? (i -- i   Given an event number, returns 1 if it's a valid event, or 0 if not )
        dup int? if intostr then
        listDB @ "/events/db/" rot strcat "/systimefrom" strcat getpropval 0 = not
;

: controlsEvent? ( i --  Given an event number, returns true if user owns event or object, false if not )
        listDB @ "/events/db/" rot intostr strcat "/owner" strcat getprop int me @ int = me @ listDB @ controls or
;

: rsvpAdd  ( d i --  Given a player dbref and an event number, add player to RSVP list.  ASSUMES SECURITY CHECKS HAVE BEEN DONE  )
        lockHold
        "rsvpAdd" lockDB
        dup (dii) rot (iid) dup (iidd) rot (iddi) rsvp? if pop pop unlockDB exit else swap (di) then
        ( Add one to the number of RSVPed players for that event )
        dup intostr "/events/db/" swap strcat "/rsvp" strcat dup listDB @ swap getpropval 1 +  listDB @ rot rot setprop

        swap dup rot
        ( Add them into the DB for that event number )
        intostr "/events/db/" swap strcat swap intostr "/rsvp/" swap strcat strcat swap
        listDB @ rot rot setprop
        unlockDB
;

: rsvpDelete (d i --  Given a player dbref and the event number, remove that player from the RSVP list )
        lockHold
        "rsvpDelete" lockDB
        dup (dii) rot (iid) dup (iidd) rot (iddi) rsvp? not if pop pop unlockDB exit else swap (di) then
        ( Subtract one from the number of RSVPed players for that event )
        dup intostr "/events/db/" swap strcat "/rsvp" strcat dup listDB @ swap getpropval 1 -  listDB @ rot rot setprop

        ( Remove them and their comment from the RSVP list )
        intostr "/events/db/" swap strcat swap intostr "/rsvp/" swap strcat strcat listDB @ swap remove_prop
        unlockDB
;

: eventList ( i0 i1 --    i0 is a date in YYMMDD. Shows events in short form [i1=0] or long form [i1=1] for a particular day.  Include zeroes! )
        swap
        dup int? if intostr then dup strlen 3 = if "000" swap strcat then
        dup strlen 4 = if "00" swap strcat then
        dup strlen 5 = if "0" swap strcat then
        swap

        dup elShortOrLong ! not if shortViewHeader then
        "/events/calendar/" swap strcat elPropIter !
        listDB @ elPropIter @ getpropval if listDB @ elPropIter @ "/" strcat nextprop elPropIter !
        BEGIN
           listDB @ elPropIter @ getpropval elShortOrLong @ if longView else shortView then
           listDB @ elPropIter @ nextprop dup elPropIter !
        "" strcmp not
        UNTIL then
;



( ================== )
( === The interface === )
( ================== )


: getDateTime ( --  Returns the start and time entered by the user in eventSystimeFrom and eventSystimeTo)
        ( Both become 0 if user aborts )

        ( From... )
        BEGIN
           BEGIN
                   clearstack
                   me @ "Enter the starting date and time in the following format: YYMMDD HHMM >>" notify
                   do_read dateCheck strip dup
                   "." stringcmp not if "Aborted" sysMessage pop 0 eventSystimeFrom ! 0 eventSystimeTo ! exit then
                   dup " " instr dup rot swap strcut swap rot
                   7 =
           UNTIL
           strip swap atoi 100 * swap strip atoi dateToSystime dup
           systime > if 1 else pop blankline me @ "Starting date and time must occur after the current date and time!" notify 0 then
        UNTIL
        eventSystimeFrom !
        ( ...to )
        BEGIN
           BEGIN
                   clearstack
                   me @ "Enter the ending date and time in the following format: YYMMDD HHMM >>" notify
                   do_read dateCheck strip dup
                   "." stringcmp not if "Aborted" sysMessage pop 0 eventSystimeFrom ! 0 eventSystimeTo ! exit then
                   dup " " instr dup rot swap strcut swap rot
                   7 =
           UNTIL
           swap strip atoi 100 * swap strip atoi dateToSystime dup
           eventSystimeFrom @ > if 1 else pop blankline me @ "Ending date and time must occur after the starting date and time!" notify 0 then
        UNTIL
        eventSystimeTo !
;


: showRange (i0 i1 i2 --  i0 and i1 is a date in YYMMDD.  i2 indicates short =0 or long =1 display.  Shows all events with no duplicates from i0 to i1 )
        (counterB is the last day, while counterA increments torwards it)
        elShortOrLong !
        10 swap dateToSystime counterB !
        10 swap dateToSystime counterA !
        counterA @ 0 = counterB @ 0 = or if "showRange: Invalid date(s)" sysMessage exit then
        "" dupHold !

        BEGIN
                listDB @ "/events/calendar/" "%y%m%d" counterA @ timefmt strcat "/" strcat nextprop elPropIter !
                BEGIN
                        ( If there are events to show, then show them! )
                        elPropIter @ "" strcmp not if break then

                        listDB @ elPropIter @ getpropval dup
                        ( Determine if we've already shown this event before. If not, then show it )
                        dupHold @ swap intostr " " swap strcat " " strcat instring not if
                                dup intostr " " swap strcat " " strcat dupHold @ swap strcat dupHold !
                                elShortOrLong @ if longView else shortView then
                                else pop then
                        listDB @ elPropIter @ nextprop dup elPropIter !
                "" strcmp not
                UNTIL
        counterA @ DAYSEC + counterA !
        counterA @ counterB @ >
        UNTIL
;

: eventCopy  ( i --  Copies event i, after prompting user for details )
        ( Uses eventNum, eventSystimeFrom, eventSystimeTo variables )

        eventNum !

        me @ ">| COPY AN EVENT" notify blankline

        me @ "This is event #" eventNum @ intostr strcat ": " strcat listDB @ "/events/db/" eventNum @ intostr strcat "/title" strcat getpropstr strcat notify
        blankline

        ( Copy to 7 days ahead? )
        me @ "Copy event and make it occur 7 days from it's currently scheduled" notify
        me @ "time (YES/NO) ??" notify
        read "y" instring if
                ( Prepare SysTimes for 7 days ahead )
                listDB @ "/events/db/" eventNum @ intostr strcat "/systimeFrom" strcat getpropval DAYSEC 7 * + eventSystimeFrom !
                listDB @ "/events/db/" eventNum @ intostr strcat "/systimeTo" strcat getpropval DAYSEC 7 * + eventSystimeTo !
        else
                ( If no, then get start and end times )
                blankline
                me @ "Enter the start and end times of the copied event.  The date and time is read" notify
                me @ "on one line and is in the format of  'YYMMDD HHMM'.  Include zeroes to ensure" notify
                me @ "your time or date is exactly 4 or 6 digits long.  Type '.' to abort!" notify
                me @ "*Times and dates are in the MUCK server's timezone*" notify
                me @ "It is currently: " "%y%m%d %H%M" systime timefmt strcat notify
                blankline
        
                getDateTime
                eventSystimeFrom @ 0 = eventSystimeTo @ 0 = or if exit then
        then

        ( Verify )
        blankline
        me @ "Verify these dates and times; do not copy the event if they are incorrect:" notify
        me @ "Copied Event starts at (MM/DD/YY  HH:MM): " "%a %m/%d/%y  %I:%M %p" eventSystimeFrom @ timefmt strcat notify
        me @ "Copied Event ends at   (MM/DD/YY  HH:MM): " "%a %m/%d/%y  %I:%M %p" eventSystimeTo @ timefmt strcat notify
        blankline

        me @ "Type a '.' to abort the copy, or press the spacebar to start the process ??" notify
        read "." instring 1 = if
                "Aborted." sysMessage exit
        else
                ( OK, have the new systimes, now make the new event )
                "Copying event..." sysMessage
                lockHold
                "eventCopy" lockDB
                getNewEventNumber dup eventNum @ swap eventSystimeFrom @ eventSystimeTo @ copyEvent
                unlockDB
                "Done.  Event copied as #" swap intostr strcat " in the database." strcat sysMessage
        then
;


( add, remove, edit an event goes here )

: eventAdd ( --    Adds an event. ASSUMES SECURITY CHECKS HAVE BEEN DONE )
        ( Get the title of the event )
        me @ ">| ADD AN EVENT" notify
        blankline
        me @ "Please enter the following information.  You may abort at any time by pressing the . key" notify
        blankline
        me @ "[1/6] Enter the title of the event >>" notify
        do_read dup
        "." stringcmp not if "Aborted" sysMessage pop exit then
        strip eventTitle !
        ( Get the date/time from  and date/time to )
        blankline
        me @ "[2/6]" notify
        me @ "Now you will be entering dates and times.  The date and time is read on one" notify
        me @ "line and is in the format of  'YYMMDD HHMM'.  Include zeroes to ensure" notify
        me @ "your time or date is exactly 4 or 6 digits long." notify
        me @ "*Times and dates are in the MUCK server's timezone*" notify
        me @ "It is currently: " "%y%m%d %H%M" systime timefmt strcat notify
        blankline

        ( Gets the dates and times from the user, check for an abort )
        getDateTime
        eventSystimeFrom @ 0 = eventSystimeTo @ 0 = or if exit then

        ( Reshow so user can make sure it was correct )
        blankline
        me @ "Verify these dates and times.  If they are not correct, abort by hitting '.'" notify
        me @ "Event starts at (MM/DD/YY  HH:MM): " "%a %m/%d/%y  %I:%M %p" eventSystimeFrom @ timefmt strcat notify
        me @ "Event ends at   (MM/DD/YY  HH:MM): " "%a %m/%d/%y  %I:%M %p" eventSystimeTo @ timefmt strcat notify
        blankline
        ( Get the Location )
        me @ "[3/6] Enter the location/directions to the event >>" notify
        do_read dup
        "." stringcmp not if "Aborted" sysMessage pop exit then
        strip eventLocation !
        ( Get the age restriction )
        me @ "[4/6] Enter the age restrictions, or 'All' if none >>" notify
        do_read dup
        "." stringcmp not if "Aborted" sysMessage pop exit then
        strip eventAge !
        ( Allow RSVPs? )
        listDB @ "/eventsetup/allowrsvp" getpropstr "n" instring if
                me @ "[5/6] RSVPs disabled for this event object.  Skipping..." notify
                "no" eventRSVP !
        else
                me @ "[5/6] Allow RSVP lists?  (Answer YES or NO in full) >>" notify
                do_read dup
                "." stringcmp not if "Aborted" sysMessage pop exit then
                strip tolower eventRSVP !
        then
        blankline
        ( Create the event )
        "Creating event..." sysMessage
        lockHold
        "eventAdd" lockDB

        ( Find an available event number )
        getNewEventNumber counterA !

        ( Throw in the values )
        listDB @ "/events/db/" counterA @ intostr strcat counterA @ setprop
        listDB @ dup "/events/db" dup rot swap getpropval 1 + setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/owner" strcat me @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/title" strcat eventTitle @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/location" strcat eventLocation @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/age" strcat eventAge @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeFrom" strcat eventSystimeFrom @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeTo" strcat eventSystimeTo @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/rsvp?" strcat eventRSVP @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/rsvp" strcat 0 setprop

        ( Now, populate the calendar )
        counterA @ addToCalendar
        "Event created.  Event #" counterA @ intostr strcat sysMessage unlockDB

        ( Create the description via LSEDIT )
        me @ "[6/6] Now, enter the description of the event.  When done, type '.end' on a" notify
        me @ "     separate line." notify
        "Entering lsedit..." sysMessage
        listDB @ intostr "=" strcat "/events/db/" counterA @ intostr strcat "/desc" strcat strcat cmd-lsedit
        "Exited lsedit" sysMessage
        me @ "Your event has been created.  Its number in the database is " counterA @ intostr strcat "." strcat notify
;

: eventEdit ( i --    Edits an event i. ASSUMES SECURITY CHECKS HAVE BEEN DONE AND THAT EVENT IS VALID )
        dup string? if atoi then counterA !
        ( Read in the values to be edited )
        listDB @ "/events/db/" counterA @ intostr strcat "/title" strcat getpropstr eventTitle !
        listDB @ "/events/db/" counterA @ intostr strcat "/location" strcat getpropstr eventLocation !
        listDB @ "/events/db/" counterA @ intostr strcat "/age" strcat getpropstr eventAge !
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeFrom" strcat getpropval eventSystimeFrom !
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeTo" strcat getpropval eventSystimeTo !
        listDB @ "/events/db/" counterA @ intostr strcat "/rsvp?" strcat getpropstr eventRSVP !

        ( Get the title of the event )
        me @ ">| EDIT AN EVENT" notify
        blankline
        me @ "Editing event number " counterA @ intostr strcat notify blankline
        me @ "Please enter the following information.  You may abort at any time by pressing the . key." notify
        me @ "Keep existing data by pressing space and enter." notify
        blankline
        me @ "[1/5] Enter the title of the event >>" notify
        me @ eventTitle @ notify
        do_read dup dup
        "." stringcmp not if me @ "Aborted" notify pop pop exit then
        " " stringcmp not if me @ "Existing data kept" notify pop
          else strip eventTitle ! then
        ( Show date and time.  Cannot be modified )
        blankline me @ "Event dates and times cannot be modified.  If you must change the date or time" notify
        me @ "of your event, please erase this one and make a new event." notify
        me @ "Event starts at (MM/DD/YY  HH:MM): " "%a %m/%d/%y  %I:%M %p" eventSystimeFrom @ timefmt strcat notify
        me @ "Event ends at (MM/DD/YY  HH:MM):   " "%a %m/%d/%y  %I:%M %p" eventSystimeTo @ timefmt strcat notify
        blankline
        ( Get the Location )
        me @ "[2/5] Enter the location of the event and directions >>" notify
        me @ eventLocation @ notify
        do_read dup dup
        "." stringcmp not if me @ "Aborted" notify pop pop exit then
        " " stringcmp not if me @ "Existing data kept" notify pop
          else strip eventLocation ! then
        blankline
        ( Get the age restriction )
        me @ "[3/5] Enter the age restrictions, or 'All' if none >>" notify
        me @ eventAge @ notify
        do_read dup dup
        "." stringcmp not if me @ "Aborted" notify pop pop exit then
        " " stringcmp not if me @ "Existing data kept" notify pop
          else strip eventAge ! then
        blankline
        ( Allow RSVPs? )
        listDB @ "/eventsetup/allowrsvp" getpropstr "n" instring if
                me @ "[4/5] RSVPs disabled for this event object.  Skipping..." notify
                "no" eventRSVP !
        else
                me @ "[4/5] Allow RSVP lists?  (Answer YES or NO in full) >>" notify
                me @ eventRSVP @ notify
                do_read dup dup
                "." stringcmp not if me @ "Aborted" notify pop exit then
                " " stringcmp not if me @ "Existing data kept" notify pop
                  else strip tolower eventRSVP ! then
        then
        blankline
        ( Modify the event )
        me @ "Modifying the event..." notify
        lockHold
        "eventEdit" lockDB
        listDB @ "/events/db/" counterA @ intostr strcat counterA @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/title" strcat eventTitle @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/location" strcat eventLocation @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/age" strcat eventAge @ setprop
        listDB @ "/events/db/" counterA @ intostr strcat "/rsvp?" strcat eventRSVP @ setprop
        unlockDB
        "Event modified" sysMessage
        ( Create the description via LSEDIT )
        me @ "[5/5] Now, edit the description of the event.  When done, type '.end' on a" notify
        me @ "separate line." notify
        me @ "To start from scratch, enter '.del 1 1000' before typing." notify
        "Entering lsedit..." sysMessage
        listDB @ intostr "=" strcat "/events/db/" counterA @ intostr strcat "/desc" strcat strcat cmd-lsedit
        "Exited lsedit" sysMessage
        me @ "Event number " counterA @ intostr strcat " has been edited." strcat notify
        exit
;

: eventRemove  ( i1 i2 --    Removes an event i1. If i2 is nonzero, skip confirmation.  ASSUMES SECURITY CHECKS HAVE BEEN DONE AND THAT EVENT IS VALID )
        swap counterA !
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeFrom" strcat getpropval eventSystimeFrom !
        listDB @ "/events/db/" counterA @ intostr strcat "/systimeTo" strcat getpropval eventSystimeTo !
        not if
                me @ ">| REMOVE AN EVENT" notify
                blankline
                me @ "Event number " counterA @ intostr strcat "." strcat notify
                me @ "Title: " listDB @ "/events/db/" counterA @ intostr strcat "/title" strcat getpropstr strcat notify
                me @ "Event starts at (MM/DD/YY  HH:MM): " "%a %m/%d/%y  %I:%M %p" eventSystimeFrom @ timefmt strcat notify
                me @ "Event ends at (MM/DD/YY  HH:MM):   " "%a %m/%d/%y  %I:%M %p" eventSystimeTo @ timefmt strcat notify
                blankline
                me @ "Are you SURE you want to remove this event (YES/NO) ??" notify
                read strip
                "yes" stringcmp if me @ "Aborted removing event." notify exit then
        then
        ( If they are sure they want to erase it, continue )
        "Removing event " counterA @ intostr strcat "..." strcat sysMessage
        lockHold
        "eventRemove" lockDB
        ( Remove the DB entry )
        listDB @ "/events/db/" counterA @ intostr strcat remove_prop
        listDB @ dup "/events/db" dup rot swap getpropval 1 - setprop
        ( Remove it from the calendar )
        eventSystimeFrom @ counterB !
        BEGIN
                "%y%m%d" counterB @ timefmt atoi "%y%m%d" eventSystimeTo @ timefmt atoi <= if
                        listDB @ dup "/events/calendar/" "%y%m%d" counterB @ timefmt strcat dup rot swap getpropval 1 - setprop
                        listDB @ "/events/calendar/" "%y%m%d" counterB @ timefmt strcat "/" strcat counterA @ intostr strcat remove_prop
                        0 else 1 then  ( Used for UNTIL evaluating )
                counterB @ DAYSEC + counterB !
        UNTIL
        unlockDB
        "Event " counterA @ intostr strcat " removed." strcat sysMessage
;

( Cleaning support function )
: enumerationCount ( s -- i   s is the first prop in that directory.  i is the number of 'enumerations' inside that directory )
        0
        swap dup "" stringcmp not if pop exit else swap then
        BEGIN
                1 +
                swap listDB @ swap nextprop dup
        "" stringcmp not rot swap
        UNTIL
        swap pop
;

( The two cleaning functions )
: cleanDaily ( --   Old event entries are removed.  Checks all calendar entries at this time for sanity )
        "Locking DB and doing daily clean..." sysMessage
        lockHold
        "cleanDaily" lockDB
        ( Start at first entry in calendar, if there is one )
        listDB @ "/events/calendar/" nextprop dup propIterA !
        "" strcmp if
        ( LOOP until seen all days. )
        BEGIN
                ( Go through each DB number pointer.  If DB entry /systimeTo occurs before today,
                   then remove the DB entry and the entry from the calendar )
                listDB @ propIterA @ "/" strcat nextprop propIterB !
                BEGIN
                        listDB @ "/events/db/" listDB @ propIterB @ getpropval intostr strcat "/systimeto" strcat getpropval systime < if
                                ( Oop, time to remove one )
                                listDB @ propIterB @ getpropval counterA !
                                ( Remove it from the database, if it hasn't been done already )
                                listDB @ "/events/db/" counterA @ intostr strcat getpropval counterA @ = if
                                        listDB @ "/events/db/" counterA @ intostr strcat remove_prop
                                        listDB @ "/events/db" listDB @ "/events/db" getpropval 1 - setprop
                                        then
                                ( Now, remove it from the calendar entry )
                                listDB @ propIterB @ remove_prop
                                listDB @ propIterA @ listDB @ propIterA @ getpropval 1 - setprop
                                propIterA @ "/" strcat propIterB !
                        then
                        ( Next prop, or stop if end )
                        listDB @ propIterB @ nextprop dup propIterB !
                        "" strcmp not
                UNTIL
                ( If enumeration is 0 for calendar date, Remove calendar date )
                listDB @ propIterA @ getpropval 0 = if
                        listDB @ propIterA @ remove_prop
                        "/events/calendar/" propIterA !
                        then
                listDB @ propIterA @ nextprop dup propIterA !
                "" strcmp not
        UNTIL then
        unlockDB
        "Database unlocked.  Daily clean complete" sysMessage
        ( Update clean date )
        listDB @ "/lastclean" "%y%m%d" systime timefmt atoi setprop
        clearstack
;

: cleanDeep ( --  To be called after cleanDaily.  Events are checked for validity and enumerations are recounted. )
        "[1/3]  Deep cleaning (call daily clean)..." sysMessage
        cleanDaily
        ( Probably called when forcing an unlock - assume program crashed and needs checking.  Could also be used if the MUCK server crashed )
        ( Normally this should not be ran as it can be CPU/Time consuming )
        "cleanDeep" lockDB
        "[2/3]  Deep cleaning (recreate the calendar)..." sysMessage
        ( REMOVE the calendar.  it will be recreated during the clean )
        listDB @ "/events/calendar" remove_prop
        ( Start at first entry in DB listing )
        listDB @ "/events/db/" nextprop dup propIterA !
        ( LOOP until end of list/enumeration )
        "" strcmp if
          BEGIN
                ( Check entry for validity )
                ( Condition one:  Has a title )
                listDB @ propIterA @ "/title" strcat getpropstr "" strcmp not
                ( Condition two and three: Has valid systimes )
                listDB @ propIterA @ "/systimefrom" strcat getpropval 0 =
                listDB @ propIterA @ "/systimeto" strcat getpropval dup 0 =
                swap systime <
                ( Condition four:  Has an owner, even if they've been toaded )
                listDB @ propIterA @ "/owner" strcat getprop dup int? not if int then 0 =
                ( If any are true, then the entry is junk )
                or or or or if
                                listDB @ propIterA @ remove_prop
                                "/events/db/" propIterA !
                                else
                                ( Else entry is good.  Reset RSVP count and re-add to calendar )
                                listDB @ propIterA @ "/rsvp/" strcat nextprop dup "" strcmp if enumerationCount listDB @ propIterA @ "/rsvp" strcat rot setprop else listDB @ propIterA @ "/rsvp" strcat remove_prop then
                                listDB @ propIterA @ getpropval counterA !
                                listDB @ propIterA @ "/systimefrom" strcat getpropval counterB !
                                listDB @ propIterA @ "/systimeto" strcat getpropval eventSystimeTo !
                                BEGIN
                                        "%y%m%d" counterB @ timefmt atoi "%y%m%d" eventSystimeTo @ timefmt atoi <= if
                                                listDB @ dup "/events/calendar/" "%y%m%d" counterB @ timefmt strcat dup rot swap getpropval 1 + setprop
                                                listDB @ "/events/calendar/" "%y%m%d" counterB @ timefmt strcat "/" strcat counterA @ intostr strcat counterA @ setprop
                                                0 else 1 then  ( Used for UNTIL evaluating )
                                        counterB @ DAYSEC + counterB !
                                UNTIL        
                                then
                clearstack
                listDB @ propIterA @ nextprop dup propIterA !
                "" strcmp not
          UNTIL then
        ( Count number of entries, and reset enumeration count )
        listDB @ "/events/db" listDB @ "/events/db/" nextprop enumerationCount setprop
        unlockDB
        "[3/3]  Deep cleaning (call daily clean again)..." sysMessage
        cleanDaily
        "Done deep cleaning." sysMessage
;

: autoCheck ( --  The function called when a user connects )
        ( counterA is used for number of events that day.  counterB is number of events in the next 3 days )
        ( propIterA iterates through the events of a certain day. )
        0 0 counterA ! counterB !
        systime stepTime !

       
        ( Find out how many events today, if any )
        listDB @ "/events/calendar/" "%y%m%d" systime timefmt strcat getpropval counterA !
        
        ( Find out how many events in the next 3 days, if any )
        0 counterB !
        BEGIN
                stepTime @ DAYSEC + stepTime !
                listDB @ "/events/calendar/" "%y%m%d" stepTime @ timefmt strcat getpropval counterB @ + counterB !
        stepTime @ systime DAYSEC 3 * + >=
        UNTIL

        ( Report to the user how many events found )
        counterA @ 0 = counterB @ 0 = and if (No events today or in 3 days.  Show nothing) exit else
          me @ "## There are " counterA @ intostr strcat " event(s) occuring today" strcat counterB @ if " and more events are occuring within the next 3 days" else "" then strcat " on " strcat listDB @ "/eventsetup/title" getpropstr strcat "." strcat notify

          ( Show user what events they have RSVPed for today )
          counterA @ 0 > if
             ( counterA is used as a flag now to indicate if the header has been shown yet )
             0 counterA !
             "/events/calendar/" "%y%m%d" systime timefmt strcat "/" strcat propIterA !
             listDB @ propIterA @ nextprop propIterA !
             BEGIN
                me @ listDB @ propIterA @ getpropval dup rot rot rsvp? if 
                        counterA @ 0 = if me @ "## You have RSVPed for the following events today:" notify shortViewHeader 1 counterA ! then
                        shortView
                    else pop then
                listDB @ propIterA @ nextprop dup propIterA !
             "" strcmp not
             UNTIL
          then
        then
        exit
;

: objectLook ( --  All events, shortly. Used for when the program is in an object desc )
        ( make sure DB # is valid )
        listDB @ ok? if
            listDB @ "/eventsetup/title" getpropstr strlen if
                me @ "Events up to a month ahead on " listDB @ "/eventsetup/title" getpropstr strcat ":" strcat notify
                ( "%y%m%d" systime timefmt 1 eventList pop )
                "%y%m%d" systime timefmt atoi ( Time from )
                "%y%m%d" systime DAYSEC 30 * + timefmt atoi ( Time to )
                0 shortViewHeader
                showRange
            else
                "Eventlist DB given is not a valid eventlist!" sysMessage
            then
        else
            "Eventlist DB given is not a valid object!" sysMessage
        then

        exit
;

: setupSetup  ( -- Sets up the object.  Does a owner check )
        ( Owner check )
        me @ listDB @ controls not if "Not the owner of the object.  Cannot run setup!" sysMessage exit then
        ( Put in some basic prop into the object, such as the version number )
        listDB @ "/eventsetup/version" getpropval 0 = if cleanDeep then
        listDB @ "/eventsetup/version" ELver setprop
        me @ ">| SET UP EVENT LIST OBJECT" notify blankline
        me @ "Enter the name of this event list >>" notify
        me @ listDB @ "/eventsetup/title" getpropstr notify
        listDB @ "/eventsetup/title" do_read setprop
        blankline
        me @ "Should any user be allowed to add events? (YES/NO) ??" notify
        listDB @ "/eventsetup/allowadd" read setprop
        blankline
        me @ "Should RSVP lists be allowed? (YES/NO) ??" notify
        listDB @ "/eventsetup/allowrsvp" read setprop
        blankline
        me @ "The #autocheck function allows the user to be notified upon login" notify
        me @ "about upcoming events.  If you are a wiz, you may force all" notify
        me @ "users to see upcoming events by answering no to this question" notify
        me @ "and answering yes to the next one." notify
        me @ "Enable the #autocheck function for this event list? (YES/NO) ??" notify
        listDB @ "/eventsetup/allownotify" read setprop
        blankline

        ( If they are a wizard, allow for setting up of global forced notification )
        me @ "WIZARD" flag? if
                "You are a wizard.  Showing option for forced global #autocheck" sysMessage
                blankline
                me @ "Force all users to see the equivalent of #autocheck on this event list" notify
                me @ "on connect?  Saying YES will add properties to room #0, saying NO will" notify
                me @ "remove them.  (YES/NO) ??" notify
                read "y" instring if
                        ( Add the props )
                        0 dbref "/_connect/eventlist" prog setprop
                        0 dbref "/eventlistdb" trig setprop
                        "Props added to room #0 for forced #autocheck." sysMessage
                else
                        ( Remove the props )
                        0 dbref "/_connect/eventlist" remove_prop
                        0 dbref "/eventlistdb" remove_prop
                        "Props removed from room #0 to disable forced #autocheck." sysMessage
                then
                blankline
        then
        "Setup complete." sysMessage
;


: detailMenu  (i --   Gives detailed options on db entry i )
        lockHold
        blankline blankline
        me @ ">|  DETAILED EVENT VIEW" notify
        dup string? if atoi then dup eventNum !
        dup event? not if me @ "Invalid event number" notify pause pop exit then
        longView

        BEGIN
                me @ "+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +" notify
                me @ "[R]SVP to This Event   :: [D]elete This Event :: [A]gain (Redisplay)" notify
                me @ "[U]nRSVP to This Event :: [E]dit This Event   :: [B]ack to Main Menu" notify
                me @ "[M]ail RSVPed          :: [C]opy Event        :: [Q]uit" notify
                me @ "OPTION >>" notify

                ( Get the input and process each option )
                do_read strip
                eventNum @ event? not if blankline "Event was deleted" sysMessage pause pop exit then
                lockHold
                ( Is it a valid choice? )
                dup "" strcmp not if pop continue then
                dup "CRUEDAMBQ" swap instring not if me @ "Invalid option!" notify pop continue then

                ( Back and Again and Quit )
                dup "B" stringcmp not if pop break then
                dup "A" stringcmp not if eventNum @ longView pop continue then
                dup "Q" stringcmp not if pop "Program ended." sysMessage pid kill then

                ( Copy )
                dup "C" stringcmp not if
                                ( Can they do a copy? )
                                eventNum @ controlsEvent? not if blankline me @ "Sorry, you are not authorized to copy this event." notify pause pop continue then

                                ( If so, go to copy function )
                                eventNum @ eventCopy

                                pause pop continue
                        then
                ( RSVP )
                dup "R" stringcmp not if
                                ( Can they do an RSVP? )
                                listDB @ "/eventsetup/allowrsvp" getpropstr "n" instring if blankline "Sorry, RSVPs are disabled for this event object" sysMessage pause pop continue then
                                listDB @ "/events/db/" eventNum @ intostr strcat "/rsvp?" strcat getpropstr "n" instring if blankline me @ "Sorry, RSVPs are disabled for this event" notify pause pop continue then
                                ( If so, do it! )
                                me @ eventNum @ rsvpAdd
                                blankline me @ "You have been RSVPed to this event." notify
                                pause pop continue
                        then

                ( UnRSVP )
                dup "U" stringcmp not if
                                ( Can they do an RSVP? )
                                listDB @ "/eventsetup/allowrsvp" getpropstr "n" instring if blankline "Sorry, RSVPs are disabled for this event object" sysMessage pause pop continue then
                                listDB @ "/events/db/" eventNum @ intostr strcat "/rsvp?" strcat getpropstr "n" instring if blankline me @ "Sorry, RSVPs are disabled for this event" notify pause pop continue then
                                ( If so, do it! )
                                me @ eventNum @ rsvpDelete
                                blankline me @ "You have been unRSVPed to this event." notify
                                pause pop continue
                        then

                ( Edit )
                dup "E" stringcmp not if
                                ( Can they edit this event ? )
                                eventNum @ controlsEvent? not if blankline me @ "Sorry, you are not authorized to edit this event." notify pause pop continue then
                                ( They can.  Go to editing the event )
                                eventNum @ eventEdit
                                pause pop 
                                ( As they edited it, redisplay the event before giving them options )
                                eventNum @ longView
                                continue
                        then

                ( Mail all who RSVPed )
                dup "M" stringcmp not if
                                "Mailing owner and everyone RSVPed to the event..." sysMessage

                                ( Create a string with everyone who RSVPed and the event owner )
                                listDB @ "/events/db/" eventNum @ intostr strcat "/owner" strcat getprop name " " strcat

                                listDB @ "/events/db/" eventNum @ intostr strcat "/rsvp/" strcat nextprop dup elRSVPIter !
                                "" stringcmp if
                                  BEGIN
                                        (Displays everyone who RSVPed)
                                        listDB @ elRSVPIter @ getprop playerName " " strcat strcat
                                        listDB @ elRSVPIter @ nextprop dup elRSVPIter !
                                        "" stringcmp not
                                  UNTIL then 
                                ( background process )
                                background
                                ( force user to run 'mail' with the names from above as an argument )
                                me @ swap MAILCMD " " strcat swap strcat force
                                ( exit quietly )
                                pid kill
                        then

                ( Delete )
                dup "D" stringcmp not if
                                ( Can they delete this event ? )
                                eventNum @ controlsEvent? not if blankline me @ "Sorry, you are not authorized to delete this event." notify pause pop continue then
                                ( They can.  Go to removing the event )
                                eventNum @ 0 eventRemove
                                pause pop 
                                ( As they may have deleted it, exiting may be nessecary now )
                                eventNum @ event? if continue else break then
                        then
        REPEAT
        exit
;

: mainMenu  ( The main UI )
( menuState can be one of the following values: )
( 1-Events Today.  2-Events a week ahead  )
( 3-Date.  4-Date Range.  5-RSVPed Events )
( 6-Events You Own  7-All events)
        BEGIN
                blankline blankline
                me @ ">| EVENTLIST MAIN MENU FOR " listDB @ "/eventsetup/title" getpropstr toupper strcat notify
                blankline
                lockHold        
                ( Show the appropiate viewing mode )
                menuState @ 1 = if
                        me @ "+Events today:" notify
                        "%y%m%d" systime timefmt atoi 0 eventList
                then
        
                menuState @ 2 = if
                        me @ "+Events up to 7 days ahead ["  "%m/%d/%y" systime timefmt strcat " to " strcat "%m/%d/%y" systime DAYSEC 7 * + timefmt strcat "]:" strcat notify
                        "%y%m%d" systime timefmt atoi ( Time from )
                        "%y%m%d" systime DAYSEC 7 * + timefmt atoi ( Time to )
                        0 shortViewHeader
                        showRange
                then
        
                menuState @ 3 = if
                        me @ "+Events on a specific date [" menuParameters @ strcat "]:" strcat notify
                        menuParameters @ atoi 0 eventList
                then

                menuState @ 4 = if
                        me @ "+Events on a range of dates [" menuParameters @ strcat "]:" strcat notify
                        shortViewHeader
                        menuParameters @ " " explode pop atoi swap atoi 0 showRange
                then

                menuState @ 5 = if
                        me @ "+Events you have RSVPed for:" notify
                        shortViewHeader
                        listDB @ "/events/db/" nextprop dup propIterA !
                        "" strcmp if BEGIN
                                me @ listDB @ propIterA @ getpropval dup rot rot rsvp? if
                                        shortView else pop then

                                listDB @ propIterA @ nextprop dup propIterA !
                                "" stringcmp not
                        UNTIL then
                then

                menuState @ 6 = if
                        me @ "+Events you own:" notify
                        shortViewHeader
                        listDB @ "/events/db/" nextprop dup propIterA !
                        "" strcmp if BEGIN
                                   listDB @ propIterA @ "/owner" strcat getprop me @ dbcmp if
                                        listDB @ propIterA @ getpropval shortView then

                                listDB @ propIterA @ nextprop dup propIterA !
                                "" stringcmp not
                        UNTIL then
                then

                menuState @ 7 = if
                        me @ "+All events in the database:" notify
                        shortViewHeader
                        listDB @ "/events/db/" nextprop dup propIterA !
                        "" strcmp if BEGIN
                                listDB @ propIterA @ getpropval shortView

                                listDB @ propIterA @ nextprop dup propIterA !
                                "" stringcmp not
                        UNTIL then
                then

                menuState @ 8 = if
                        me @ "+Events up to a month ahead ["  "%m/%d/%y" systime timefmt strcat " to " strcat "%m/%d/%y" systime DAYSEC 30 * + timefmt strcat "]:" strcat notify
                        "%y%m%d" systime timefmt atoi ( Time from )
                        "%y%m%d" systime DAYSEC 30 * + timefmt atoi ( Time to )
                        0 shortViewHeader
                        showRange
                then

                ( Show the menu strip )
                me @ "+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +" notify
                me @ "[T]oday   :: [F]ind Event By Date  :: Your [R]SVPs" notify
                me @ "[W]eekly  :: [S]how Range of Dates :: Your [E]vents  ::  Make [D]efault View" notify
                me @ "[M]onthly :: [A]ll Events          :: [+] Add Event  ::  [Q]uit" notify
                me @ "MENU OPTION or EVENT NUMBER >>" notify

                clearstack
                ( Get Input )
                do_read strip
                ( Process input )
                dup "" strcmp not if pop continue then
                ( If they entered an event number, try and open the detailed view )
                dup atoi dup if swap pop detailMenu continue else pop then
                ( Else, process the various menu options )
                dup "T" stringcmp not if 1 menuState ! "" menuParameters ! pop continue then
                dup "W" stringcmp not if 2 menuState ! "" menuParameters ! pop continue then
                dup "F" stringcmp not if 
                        me @ "Enter a date to view in the format of YYMMDD >>" notify
                        do_read dateCheck
                        dup atoi 101 < if me @ "Invalid date!  Aborting." notify pause pop pop continue then
                        menuParameters ! 3 menuState !
                pop continue then
                dup "S" stringcmp not if
                        me @ "Enter a date to START your search in the format of YYMMDD >>" notify
                        do_read dateCheck
                        dup atoi 101 < if me @ "Invalid date!  Aborting." notify pause pop pop continue then
                        me @ "Enter a date to END your search in the format of YYMMDD >>" notify
                        do_read dateCheck
                        dup atoi 101 < if me @ "Invalid date!  Aborting." notify pop pop pop continue then
                        ( Do a final check to make sure the dates are in order )
                        dup rot dup rot atoi swap atoi < if me @ "Invalid range!  Aborting." notify pause pop pop pop continue then
                        swap " " swap strcat strcat
                        menuParameters ! 4 menuState !
                pop continue then
                dup "R" stringcmp not if 5 menuState ! "" menuParameters ! pop continue then
                dup "E" stringcmp not if 6 menuState ! "" menuParameters ! pop continue then
                dup "A" stringcmp not if 7 menuState ! "" menuParameters ! pop continue then
                dup "D" stringcmp not if 
                        me @ "/_prefs/eventlist/viewState" menuState @ setprop
                        me @ "/_prefs/eventlist/viewParams" menuParameters @ setprop
                        me @ "Current search settings saved." notify
                        pause
                        pop continue then
                dup "+" stringcmp not if
                        listDB @ "/eventsetup/allowadd" getpropstr "y" instring me @ listDB @ controls or not if blankline me @ "Sorry, you are not authorized to add an event." notify pause pop continue then
                        eventAdd
                        pop continue then
                dup "M" stringcmp not if 8 menuState ! "" menuParameters ! pop continue then
                "Q" stringcmp not if break then
                blankline me @ "Invalid Option" notify pause
        REPEAT
        "Program ended." sysMessage
        exit
;


: help-panel-1  ( --   Help panel 1 )
me @ "++  EVENTLIST HELP PANEL 1  ++++++++++++++++++++++++++++++++++++++++++++++++++" notify
me @ " * eventlist.muf v1.28 by Morticon of Spindizzy.  2006.  [Thanks Kinsor!]" notify
me @ " * Summary: This command maintains a list of upcoming events.  It is user" notify
me @ "            updateable and contains some handy features." notify
me @ " * Basic usage: Run '" command @ strcat "' by itself to display the menued interface" strcat notify
me @ " * Says and poses can be used at any >> prompt or in the editor with \" and : " notify
me @ " * Remember that times and dates are in the MUCK server's timezone!" notify
me @ " * Quick parameter reference:" notify
me @ "    #autocheck    : Checks for upcoming events upon login and notifies you for" notify
me @ "    #!autocheck     this event list object.  It also makes a special listing" notify
me @ "                    of events you have RSVPed for.  Opposite is #!autocheck" notify
blankline
me @ "    xx            : Shows event number xx.  Example: '" command @ strcat " 5'" strcat notify
blankline
me @ "    #today        : Shows events occuring today in short form.  Add #long" notify
me @ "                    to show the full event information." notify
blankline
me @ "    #week         : Shows events occuring within the next 7 days in short form." notify
me @ "                    Add a #long to show the full event information." notify
blankline
me @ "    #help2        : Next help panel." notify
me @ "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" notify
exit
;

: help-panel-2 ( -- Help panel 2 )
me @ "++  EVENTLIST HELP PANEL 2  ++++++++++++++++++++++++++++++++++++++++++++++++++" notify
me @ " * More parameters:" notify
me @ "    #month        : Shows events occuring within the next 31 days in short" notify
me @ "                    form.  Add a #long to show the full event information." notify
blankline
me @ "    #rsvped       : Shows events you have RSVPed for in short form." notify
blankline
me @ "    #mine         : Shows events you own/created in short form." notify
blankline
me @ "    #all          : Shows ALL events in the eventlist database in short form." notify
blankline
me @ "    #list YYMMDD              : Shows events for a particular date." notify
me @ "                                Use zeros where appropiate." notify
blankline
me @ "    #listrange YYMMDD YYMMDD  : Shows events for a range of dates.  Defaults" notify
me @ "                                to short view.  Use zeros where appropiate." notify
blankline
me @ "    #help3                    : Even more help" notify
me @ "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" notify
exit
;

: help-panel-3 ( -- Help panel 3 )
me @ "++  EVENTLIST HELP PANEL 3  ++++++++++++++++++++++++++++++++++++++++++++++++++" notify
me @ " * Even more parameters:" notify
me @ "    #rsvp xx                  : RSVP for event number xx.  The opposite is" notify
me @ "    #!rsvp xx                   the #!rsvp command." notify
blankline
me @ "    #show xx                  : Shows details for event number xx." notify
blankline
me @ "    #add                      : Jump to add an event." notify
blankline
me @ "    #edit xx                  : Edit or delete event number xx.  You must own" notify
me @ "    #delete xx                  the event and there will NOT be confirmation!" notify
blankline
me @ "    #copy xx                  : Copy event xx." notify
blankline
me @ "    #long                     : When used with certain other options, shows " notify
me @ "                                events with full information." notify
blankline
me @ "    #help4                    : Admin Functions help panel" notify
me @ "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" notify
exit
;

: help-panel-4 ( -- Help panel 4 )
me @ "++  EVENTLIST HELP PANEL 4  ++++++++++++++++++++++++++++++++++++++++++++++++++" notify
me @ " * Admin functions:" notify
me @ "    #clean             : Clean the database right now" notify
blankline
me @ "    #unlock            : If the program crashed during an update, this will" notify
me @ "                         unlock the DB so that the program may be used again." notify
blankline
me @ "    #setup             : Sets up this eventlist object" notify
blankline
me @ "    #version           : Technical version of the program" notify
blankline
me @ " * Note: The object owner or a wiz are the only one who can use admin" notify
me @ "   functions.  To give someone else admin access, merely let them @chown" notify
me @ "   the action object." notify
me @ "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" notify
exit
;

: processParams
        ( Inform the user if the object has not been set up )
        listDB @ "/eventsetup/version" getpropval ELver = not if "WARNING!  The object owner has NOT configured this event list with #setup.  It may not work properly." sysMessage then

        ( If there are invalid characters in dates, don't let them go farther )
        parameters @ dateCheck parameters !
  
        ( If the parameter is simply a number, assume they mean '#show xx' )
        parameters @ atoi dup 0 > if
                dup
                event? not if "Invalid event number" sysMessage pop exit then
                'longView jmp
                exit
        else
            pop
        then
  
        ( Do #autocheck and #!autocheck )
        parameters @ "#autocheck" instring if
                listDB @ "/eventsetup/allownotify" getpropstr "y" instring not if "Enabling of #autocheck is not allowed on this event object" sysMessage exit then
                me @ "/_prefs/eventlist/listDB" listDB @ setprop
                me @ "/_connect/eventautocheck" trig getlink setprop
                "#autocheck enabled for this event object." sysMessage
        exit then

        parameters @ "#!autocheck" instring if
                listDB @ "/eventsetup/allownotify" getpropstr "y" instring not if "Enabling of #autocheck is not allowed on this event object" sysMessage exit then
                me @ "/_prefs/eventlist/listDB" remove_prop
                me @ "/_connect/eventautocheck" remove_prop
                "#autocheck disabled." sysMessage
        exit then

        ( Do an #add, after checking for permission )
        parameters @ "#add" instring if
                listDB @ "/eventsetup/allowadd" getpropstr "y" instring me @ listDB @ controls or not if "Sorry, you are not authorized to #add an event." sysMessage exit then
                'eventAdd jmp
        then

        ( Do a #setup, after checking for permission )
        parameters @ "#setup" instring if
                me @ listDB @ controls not if "Sorry, you are not authorized to #setup this event object." sysMessage exit then
                'setupSetup jmp
        then

        ( Do a #clean, after checking for permission )
        parameters @ "#clean" instring if
                me @ listDB @ controls not if "Sorry, you are not authorized to #clean this event object." sysMessage exit then
                cleanDaily
                listDB @ "/lastclean" "%y%m%d" systime timefmt atoi setprop
        exit then

        ( Do a #unlock, after checking for permission )
        parameters @ "#unlock" instring if
                me @ listDB @ controls not if "Sorry, you are not authorized to #unlock this event object." sysMessage exit then
                unlockDB
                cleanDeep
                listDB @ "/lastclean" "%y%m%d" systime timefmt atoi setprop
        exit then

        ( Handles selecting of long or short view )
        parameters @ "#long" instring if 1 elShortOrLong ! else 0 elShortOrLong ! then
        
        ( Do #today )
        parameters @ "#today" instring if
                me @ "The following events are scheduled for today: " notify
                "%y%m%d" systime timefmt atoi elShortOrLong @ 'eventList jmp
        then

        ( #show )
        parameters @ "#show" instring if
                parameters @ dup "#show" instring 1 - 6 + strcut swap pop atoi dup
                event? not if "Invalid event number" sysMessage exit then
                'longView jmp
                exit
        then


        ( #week )
        parameters @ "#week" instring if
                me @ "The following events are scheduled within the next 7 days: " notify
                "%y%m%d" systime timefmt atoi ( Time from )
                "%y%m%d" systime DAYSEC 7 * + timefmt atoi ( Time to )
                elShortOrLong @ dup not if shortViewHeader then
                'showRange jmp
        then

        (#all)
        parameters @ "#all" instring if
                        me @ "All events in the database:" notify
                        elShortOrLong @ not if shortViewHeader then
                        listDB @ "/events/db/" nextprop dup propIterA !
                        "" strcmp if BEGIN
                                listDB @ propIterA @ getpropval
                                elShortOrLong @ if longView else shortView then

                                listDB @ propIterA @ nextprop dup propIterA !
                                "" stringcmp not
                        UNTIL then exit
        then

        (#mine)
        parameters @ "#mine" instring if
                        me @ "Events you own:" notify
                        elShortOrLong @ not if shortViewHeader then
                        listDB @ "/events/db/" nextprop dup propIterA !
                        "" strcmp if BEGIN
                                   listDB @ propIterA @ "/owner" strcat getprop me @ dbcmp if
                                        listDB @ propIterA @ getpropval 
                                        elShortOrLong @ if longView else shortView then
                                   then

                                listDB @ propIterA @ nextprop dup propIterA !
                                "" stringcmp not
                        UNTIL then exit
        then

        (#rsvped)
        parameters @ "#rsvped" instring if
                        me @ "Events you have RSVPed for:" notify
                        elShortOrLong @ not if shortViewHeader then
                        listDB @ "/events/db/" nextprop dup propIterA !
                        "" strcmp if BEGIN
                                me @ listDB @ propIterA @ getpropval dup rot rot rsvp? if
                                        elShortOrLong @ if longView else shortView then 
                                        else pop
                                then

                                listDB @ propIterA @ nextprop dup propIterA !
                                "" stringcmp not
                        UNTIL then exit
        then

        (#month)
        parameters @ "#month" instring if
                        me @ "Events up to a month ahead ["  "%m/%d/%y" systime timefmt strcat " to " strcat "%m/%d/%y" systime DAYSEC 30 * + timefmt strcat "]:" strcat notify
                        "%y%m%d" systime timefmt atoi ( Time from )
                        "%y%m%d" systime DAYSEC 30 * + timefmt atoi ( Time to )
                        elShortOrLong @ dup not if shortViewHeader then
                        'showRange jmp
                        exit
        then


        (#edit)
        parameters @ "#edit" instring if
                ( Remove #edit )
                parameters @ dup "#edit" instring 1 - 6 + strcut swap pop atoi dup dup
                ( Valid event? )
                event? not if pop pop "Invalid event" sysMessage exit then
                ( Do a security confirmation )
                controlsEvent? not if "Sorry, you are not authorized to edit this event." sysMessage pop exit then
                ( Everything's OK, so do the edit )
                'eventEdit jmp
                exit
        then

        (#copy)
        parameters @ "#copy" instring if
                ( Remove #edit )
                parameters @ dup "#copy" instring 1 - 6 + strcut swap pop atoi dup dup
                ( Valid event? )
                event? not if pop pop "Invalid event" sysMessage exit then
                ( Do a security confirmation )
                controlsEvent? not if "Sorry, you are not authorized to copy this event." sysMessage pop exit then
                ( Everything's OK, so do the copy )
                'eventCopy jmp
                exit
        then

        (#delete)
        parameters @ "#delete" instring if
                ( Remove #edit )
                parameters @ dup "#delete" instring 1 - 8 + strcut swap pop atoi dup dup
                ( Valid event? )
                event? not if pop pop "Invalid event" sysMessage exit then
                ( Do a security confirmation )
                controlsEvent? not if "Sorry, you are not authorized to delete this event." sysMessage pop exit then
                ( Everything's OK, so do the delete )
                1 'eventRemove jmp
                exit
        then


        (#listrange)
        parameters @ "#listrange" instring if
                ( Remove #listrange )
                parameters @ dup "#listrange" instring 1 - 11 + strcut swap pop strip
                " " explode 2 < if "FROM and TO date parameters needed." sysMessage exit then
                (Extract date from)
                strip atoi dup 101 < if "FROM date in incorrect format" sysMessage exit then
                (Extract date to)
                swap strip atoi dup 101 < if "TO date in incorrect format" sysMessage exit then
                ( Show 'em )
                elShortOrLong @ dup not if shortViewHeader then
                'showRange jmp
        then

        (#list)
        parameters @ "#list" instring if
                parameters @ dup "#show" instring 1 - 6 + strcut swap pop atoi dup
                dup 101 < if pop "Invalid date.  Dates are in the format YYMMDD" sysMessage exit then
                me @ "The following events are occuring on " rot formatDate strcat ":" strcat notify
                elShortOrLong @ 'eventList jmp
        then


        ( #rsvp )
        parameters @ "#rsvp" instring if
                background
                listDB @ "/eventsetup/allowrsvp" getpropstr "n" instring if "Sorry, RSVPs are disabled for this event object" sysMessage exit then
                parameters @ dup "#rsvp" instring 1 - 6 + strcut swap pop dup atoi swap
                dup event? not if "Invalid event number" sysMessage exit then
                listDB @ "/events/db/" rot strcat "/rsvp?" strcat getpropstr "n" instring if "Sorry, RSVPs are disabled for this event" sysMessage exit then
                dup me @ swap rsvpAdd
                me @ "You have been RSVPed to event #" rot intostr strcat "." strcat notify
        exit then

        ( #!rsvp )
        parameters @ "#!rsvp" instring if
                background
                listDB @ "/eventsetup/allowrsvp" getpropstr "n" instring if "Sorry, RSVPs are disabled for this event object" sysMessage exit then
                parameters @ dup "#!rsvp" instring 1 - 7 + strcut swap pop dup atoi swap
                dup event? not if "Invalid event number" sysMessage exit then
                listDB @ "/events/db/" rot strcat "/rsvp?" strcat getpropstr "n" instring if "Sorry, RSVPs are disabled for this event" sysMessage exit then
                dup me @ swap rsvpDelete
                me @ "Your RSVP has been removed for event #" rot intostr strcat "." strcat notify
        exit then

        ( The #helps )
        parameters @ "#help2" instring if
                'help-panel-2 jmp
        then

        parameters @ "#help3" instring if
                'help-panel-3 jmp
        then

        parameters @ "#help4" instring if
                'help-panel-4 jmp
        then

        parameters @ "#help" instring if
                'help-panel-1 jmp
        then

        parameters @ "#ver" instring if
                "Version 1.28 (ELver = " ELver intostr strcat ") by Morticon of Spindizzy" strcat sysMessage
        exit then

        parameters @ "" strcmp if
                "Invalid option(s).  Try #help" sysMessage
        exit then

        me @ "/_prefs/eventlist/viewState" getprop menuState !
        me @ "/_prefs/eventlist/viewParams" getpropstr menuParameters !
        menuState @ 0 = if 2 menuState ! then
        'mainMenu jmp
;

: cmd-eventlist
        "me" match me !
        trig listDB !
        setDSTOffset
        ( If the event list is being 'look'ed at, then jump to the event list for that day )
        dup strip dup "showeventlist" instring 1 = if
            ( Found that they want to do a look )
            " " explode pop pop atoi dup 0 > if dbref listDB ! pop 'objectLook jmp then
        else
            pop
        then
        (Zombie check)
        me @ player? if
          ( If ran upon connect, then jump to the event reminder )
          dup parameters ! "Connect" strcmp not if 
                ( Pick which eventlist DB to use. Room #0 has priority over a user's )
                0 dbref "/eventlistdb" getprop dup listDB ! dup int? not if int then 0 > if 'autoCheck jmp then
                ( If room #0 doesn't have it, check user.  If the event list DB is invalid, quietly erase and disable autocheck )
                me @ "/_prefs/eventlist/listDB" getprop dup listDB !  dup dbref? not if dbref then exit? if
                    'autoCheck jmp
                else
                    me @ "/_prefs/eventlist/listDB" remove_prop   me @ "/_connect/eventautocheck" remove_prop
                then
                exit
          then
  
         (GUEST CHECK.  It's checked here so they can at least see events for that day, but do nothing else)
         me @ "/@guest" getpropstr strlen if
                "Sorry, but you are a guest.  Here are today's events, in short form:" sysMessage
                "%y%m%d" systime timefmt atoi 0 eventList
                'aborted jmp
         then
  
          ( If the DB is locked, retry once and then quit if no success )
          listDB @ "/locked" getpropstr dup "" stringcmp if
                  me @ "EventList database locked for: " rot strcat ".    Retrying..." strcat notify
                  3 sleep
                  listDB @ "/locked" getpropstr "" stringcmp if me @ "Database still locked!  Please try again in a few moments." notify 
                  ( Fix to allow the owner to get in anyway )
                  me @ listDB @ controls if "You are the object owner.  Bypassing lock.  Please run #unlock right away if the program crashed!" sysMessage else aborted exit then then
          else pop then
  
          ( Determine if the database needs to be cleaned that day )
          listDB @ "/locked" getpropstr "" stringcmp not listDB @ "/lastclean" getpropval "%y%m%d" systime timefmt atoi < and if
             "Running daily maintenance.  Please wait a moment..." sysMessage
             cleanDaily
             listDB @ "/lastclean" "%y%m%d" systime timefmt atoi setprop
             "Restarting..." sysMessage
             ( Recover the params entered at program start to pass back in )
             parameters @
             ( Restart program )
             'cmd-eventlist jmp
          then
          ( If it is not these two, then the user must have ran the program directly.  Process the parameters, if any )
          'processParams jmp
        then
        "Zombies cannot use this program, sorry." sysMessage aborted
        exit
;
  
.
c
q
@set eventlist.muf=3
@set eventlist.muf=W
@set eventlist.muf=L
@set eventlist.muf=!D
( @set eventlist.muf=/_docs:@list <PROG DB#>=7=17 )
