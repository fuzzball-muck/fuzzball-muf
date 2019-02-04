( /quote -S -dsend '/data/spindizzy/muf/ZombieHammer120.muf )

@prog editzombie.muf
1 999 d
i


( editzombie.muf  v1.20 by Morticon )

(NOTE TO WIZZES:  You MUST have the do-nothing.muf program @registered}
{   as $nothing.  You must also make this program owned by a wiz or user #1 )
( v1.20: Added teleport to zombie )
( v1.13: Added check to make sure stuff you don't own can't be deleted or
         renamed )

(Program begins HERE)
$include $lib/strings
$include $lib/match
lvar actionName
lvar counter
lvar zombieName
  
: clearstack
(Keeps the stack from accidently getting too big)
        BEGIN
         depth 2 > if pop then
         depth 2 > not
        UNTIL
        exit
;

: blankline
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
        "<In ZombieHammer> " me @ name strcat " " strcat swap strcat .tell
      else
        dup me @ swap "<In ZombieHammer> You " me @ "_say/def/say" getpropstr 
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

: pause
        blankline
        me @ "--Output paused.  Press ENTER to continue--" notify
        do_read_allow_blanks pop exit
;

: getName (d -- s)  (Returns the name of zombie d, or an error string if it's not a valid zombie)
        dup dup ok? not swap me @ swap controls not or if pop "*Bad Zombie Object*" exit then
        name
;

: getLocation  (d -- s)  (Returns the location name of object d, or an error string if it's been recced)
        dup dup ok? not swap me @ swap controls not or if pop " " exit then
        location name
;

: ActionDBtoZombieDB
( d -- d')
( pull the force string of d and get the db# it's forcing, returning it.  if not a zombie forcer, return -1)
        dup
        ( Look at succ of the action.)
        succ " " strcat dup
        ( Make sure it has 'force' in it.  If not, then return a -1 )
        rot me @ swap controls not swap "*force*" smatch not or if pop -1 dbref exit then
        ( if it does have 'force' in it, cut appropiatly till a DB # is gotten, sorta.  Convert and Return that number )
        8 strcut swap pop atoi dbref dup
        ( Make sure zombie DB# is controlled by current player.  If not, then return -1 )
        me @ swap controls not if pop -1 dbref then
        exit
;

: anyZombies?
( -- i )
(Tells if there are any actions on player running prog that may force zombies)
        0 counter !
        me @ exits actionName !
        actionName @ int 0 > if
          BEGIN
           actionName @ succ " " strcat "*force*" smatch   me @ actionName @ controls   and
                if counter @ 1 + counter ! break then
           actionName @ next actionName !
           actionName @ int -1 = if break then
          REPEAT
        then
        counter @
;

: actionExists?  ( s -- i  Given an action name, returns true if it exists on the
                  player running the program )

    ( Add a ; at the begining and end of the action for easier searching )
    ";" swap strcat ";" strcat

    me @ exits

    dup exit? not if
        ( No exits, so it doesn't exist )
        2 popn
        0
        exit
    then

    BEGIN
        ( if the exit name matches, exit immediately with a 1 )
        dup name

        ( Add a ; at the beginning and end of the action for a single search
          string )
        ";" swap strcat ";" strcat

        3 pick instring if
            ( Found it )
            2 popn
            1
            exit
        then

    ( Stop when we're at the end of the exits list )
    next
    dup exit? not
    UNTIL

    ( Did not find action )
    2 popn
    0
    exit
;

: listZombies
(Lists the zombies, and information the header suggests.  If no zombie actions located it will exit immediatly with no message)
        anyZombies? not if exit then
        me @ exits actionName !
        0 zombieName !
        ( Header )
        me @ "__ACTION______ZOMBIE NAME_____________ZOMBIE LOCATION______________________" notify
        ( Start from the first action on player. If 'force' is in succ, then display action name, zombie name, and location )
        BEGIN
          actionName @ ActionDBtoZombieDB zombieName !
          zombieName @ int 0 > if
                me @ " " actionName @ name strcat 12 strcut pop 12 STRleft " | " strcat zombieName @ getName 21 strcut pop 21 STRleft strcat " | " strcat zombieName @ getLocation 36 strcut pop 36 STRleft strcat notify then
          actionName @ next actionName !
          actionName @ int -1 = if break then
        REPEAT
        exit
;
: createZ
        blankline me @ "Create Zombie" notify blankline
        (WARN about shinies cost, and confirm)
        me @ "Warning!  You must have enough currency to create an action, link it, and" notify
        me @ "create an object.  You currently have " me @ pennies intostr strcat " of the currency." strcat notify
        me @ "If you do not have enough, push the SPACEBAR and then ENTER at the next prompt" notify
        me @ "to abort making a zombie." notify
        ( Get name of action wanted )
        blankline
        me @ "Enter name of desired action to control your zombie:" notify
        do_read_allow_blanks
        ( make sure action doesn't already exist)
        strip dup actionName ! "" stringcmp not if me @ "editzombie.muf: Aborted making zombie." notify pause exit then
        actionName @ actionExists? if me @ "editzombie.muf: Action name already exists!  Please choose another." notify exit then
        ( Get name of zombie )
        blankline
        me @ "Enter the name you want to call your zombie:" notify
        do_read_allow_blanks
        strip dup zombieName ! "" stringcmp not if me @ "editzombie.muf: Aborted making zombie." notify exit then
        blankline
        (create action, link it to $nothing )
        me @ "editzombie.muf: Creating action and linking to $nothing..." notify
        me @ actionName @ newexit actionName !
        actionName @ "$nothing" match setlink
        (create zombie object, noting db # )
        me @ "editzombie.muf: Creating zombie object and setting it's props..." notify
        me @ zombieName @ newobject zombieName !
        zombieName @ "/@/flk" "me" parselock setprop
        (Set zombie Z)
        zombieName @ "Zombie" set
        (on succ, set it to  {force:#db, {&arg}} )
        actionName @ "{force:#" zombieName @ intostr strcat ", {&arg}}" strcat setsucc

        ( A cute little TF hook to type it 'for' you )
        me @ "##edit> @set #" zombieName @ intostr strcat "=X" strcat notify
        blankline
        (  )

        ( Tell user how to finish making the zombie, then abort program )
        me @ "editzombie.muf: User interaction required to finish.  READ BELOW" notify
        me @ "  Please type in the following line EXACTLY as you see it to finish" notify
        me @ "  making your zombie.  You may then rerun editzombie if needed:" notify
        blankline
        me @ "@set #" zombieName @ intostr strcat "=X" strcat notify
        blankline
        "q"
        exit 
;

: deleteZ
        blankline me @ "Delete Zombie" notify blankline
        anyZombies? if listZombies else me @ "editzombie.muf: No zombies to delete!" notify exit then
        blankline
        ( Get name of action )
        me @ "Enter the ACTION of the zombie you wish to remove:" notify
        do_read_allow_blanks strip .noisy_match actionName !
        actionName @ int 0 > if actionName @ ActionDBtoZombieDB int 0 > if
                ( CONFIRM! )
                me @ "Are you SURE you wish to remove the action '" actionName @ name strcat "' and it's zombie '" strcat actionName @ ActionDBtoZombieDB getName strcat "' (YES/NO)?" strcat notify
                do_read "yes" stringcmp not if
                blankline
                me @ "editzombie.muf:  Recycling action and zombie..." notify
                ( @rec zombie db # )
                actionName @ ActionDBtoZombieDB dup
                ok? if
                    ( Confirm we own it and is a zombie before recycling )
                    dup thing? over owner me @ dbcmp and if
                        recycle
                    else
                        me @ "editzombie.muf:  Skipping deletion of "
                             rot unparseobj strcat
                             " because you do not own it or it is not a thing."
                        strcat notify
                    then
                else
                    pop
                then
                ( @rec action )
                actionName @ recycle
                me @ "editzombie.muf:  DONE" notify
                else me @ "editzombie.muf:  Zombie deletion aborted." notify exit then
        else me @ "editzombie.muf:  That is not a zombie action!" notify then then
        pause
        exit
;

: renameZ
        blankline me @ "Rename Zombie" notify blankline
        anyZombies? if listZombies else me @ "editzombie.muf: No zombies to rename!" notify exit then
        blankline
        ( Get name of action )
        me @ "Enter the ACTION of the zombie you wish to rename:" notify
        do_read_allow_blanks strip .noisy_match actionName !
        actionName @ int 0 > if actionName @ ActionDBtoZombieDB int 0 > if
            ( Confirm we own it and is a zombie before renaming )
            actionName @ ActionDBtoZombieDB dup thing? swap owner me @ dbcmp and
            not if
                me @ "editzombie.muf:  The zombie is not a thing or you do not "
                     "own it and therefore cannot be renamed." strcat notify
                pause
                exit
            then
            ( get the DB# of zombie and display name )
            me @ "The current name of the zombie is: " actionName @ ActionDBtoZombieDB getName strcat notify
            ( find out what new name the user wants )
            me @ "Enter new name:" notify
            do_read_allow_blanks
            strip dup zombieName ! "" stringcmp not if me @ "editzombie.muf: Aborted renaming zombie." notify exit then
            ( @name db#=newname )
            actionName @ ActionDBtoZombieDB zombieName @ setname
            me @ "editzombie.muf:  Zombie renamed." notify
        else me @ "editzombie.muf:  That is not a zombie action!" notify then then
        pause
        exit
;

: renameA
        blankline me @ "Rename Zombie Action" notify blankline
        anyZombies? if listZombies else me @ "editzombie.muf: No zombie actions to rename!" notify exit then
        blankline
        ( Get name of action )
        me @ "Enter the ACTION you wish to rename:" notify
        ( get new name, after making sure it exists )
        do_read_allow_blanks strip .noisy_match actionName !
        actionName @ int 0 > if actionName @ ActionDBtoZombieDB int 0 > if
            me @ "The current action name is: " actionName @ name strcat notify
            me @ "Enter new name:" notify
            ( Yeah, so I didn't use the var like it's name suggests.  :)
            do_read_allow_blanks
            strip dup zombieName ! "" stringcmp not if me @ "editzombie.muf: Aborted renaming action." notify exit then
            zombieName @ actionExists? if me @ "editzombie.muf: New action name already exists!  Please choose another." notify exit then
            ( @name action=newname )
            actionName @ zombieName @ setname
            me @ "editzombie.muf:  Zombie action renamed." notify
        else me @ "editzombie.muf:  That is not a zombie action!" notify then then
        pause
        exit
;

: doTeleport ( s --  Given a zombie action name, verify it and teleport to the zombie's location )
    strip .noisy_match actionName !
    actionName @ int 0 > if actionName @ ActionDBtoZombieDB int 0 > if
        actionName @ ActionDBtoZombieDB location room? not if
            me @ "editzombie.muf:  Zombie is not in a room.  Cannot teleport." notify
        else
            me @ "editzombie.muf:  Teleporting..." notify
            me @ actionName @ ActionDBtoZombieDB location moveto
            pid kill
        then
    else me @ "editzombie.muf:  That is not a zombie action!" notify then then
;

: teleportToZ
    blankline me @ "Teleport to Zombie" notify blankline
    anyZombies? if listZombies else me @ "editzombie.muf: No zombies!" notify exit then
    blankline    
    ( Get name of action )
    me @ "Enter the ACTION of the zombie to teleport to:" notify
    ( get new name, after making sure it exists )
    do_read_allow_blanks
    
    dup strlen 0 = if
        pop
        me @ "editzombie.muf: Aborted." notify
    else
        doTeleport
    then

    pause
    exit
;

: mainMenu
BEGIN
clearstack
(display main menu)
        blankline
        blankline
        me @ "ZombieHammer v1.20  by Morticon@Spindizzy (2013)" notify
        me @ "------------------------------------------------" notify
        blankline
        me @ "  1.  Create Zombie" notify
        me @ "  2.  Delete Zombie" notify
        me @ "  3.  Rename Zombie" notify
        me @ "  4.  Rename Zombie Action" notify
        me @ "  5.  List Zombies You Own" notify
        me @ "  6.  Teleport to Zombie" notify
        blankline
        me @ "  7.  Note on Zombie properties" notify
        blankline
        me @ "Enter '1' through '7', or 'Q' to QUIT:" notify
(get choice from user)
	do_read
(branch to appropiate subprogram)
        dup "1" stringcmp not if createZ then dup "q" stringcmp not if me @ "editzombie.muf: Program ended." notify exit else
        dup "2" stringcmp not if deleteZ else
        dup "3" stringcmp not if renameZ else
        dup "4" stringcmp not if renameA else
        dup "5" stringcmp not if 
                blankline me @ "Zombies you own" notify blankline
                anyZombies? if listZombies else me @ "editzombie.muf: No zombies located!" notify then
                pause else
        dup "6" stringcmp not if teleportToZ else
        "7" stringcmp not if
          blankline
          blankline
          me @ "Editing Zombie properties (such as descs, etc) should be done by running" notify
          me @ "'editplayer' via the Zombie.  EXAMPLE:  If your zombie's controlling action" notify
          me @ "is 'zomb', then to run editplayer you would type 'zomb editplayer'.  Do not" notify
          me @ "forget to prepend 'zomb' to ALL input regarding the editplayer program while" notify
          me @ "it is being run under the zombie.  If you do not wish to use that program," notify
          me @ "you may manually @set the properties on the zombie as if it were any" notify
          me @ "object.  'ex me=/' to see sample properties to set on it such as sex," notify
          me @ "species, etc." notify
          blankline
          pause 
          blankline
          me @ "A word about how this program finds zombies:  It locates a zombie" notify
          me @ "by checking @succ strings of all actions on yourself for the" notify
          me @ "smatch string '*force*'.  In addition, your @succ string must be in the" notify
          me @ "format of '{force:#xxxxx,{&arg}}' for the program to work properly with" notify
          me @ "existing zombies and their associated action.  This also mean it is a" notify
          me @ " 'barebones' zombie as it does not use zomcont.  Maybe in a future" notify
          me @ "release that will be an option." notify
          blankline
          pause
          else

        then then then then then then then
REPEAT
;

( Program starts execution HERE )
: cmd-editzombie
        "me" match me !
        (Guest check)
        me @ "/@guest" getpropstr strlen if
                me @ "editzombie.muf:  Sorry, but guests cannot use this program." notify exit then

        (Zombie check.  If valid, check for one of two parameters )
        me @ player? if 
            dup "#help" stringcmp not if
                blankline
                me @ "ZombieHammer v1.20  by Morticon@Spindizzy (2013)" notify
                me @ "#help:" notify
                me @ "  This is an interactive program used to create/manipulate zombies." notify
                me @ "  To get the menu, run without any parameters.  Otherwise, see below:" notify
                blankline
                me @ "  #help      -  This screen." notify
                me @ "  #list      -  Quickly lists zombies you own." notify
                me @ "  #tel <act> - Teleports to zombie controlled by <act>" notify
                blankline
                exit then

            dup "#list" stringcmp not if
                blankline me @ "Zombies you own:" notify blankline
                anyZombies? if listZombies else me @ "editzombie.muf: No zombies located!" notify then
                blankline
                exit then

            4 strcut swap
            "#tel" stringcmp not if
                ( Zombie name is on stack )
                strip
                
                dup strlen 0 = if
                    pop
                    me @ "editzombie.muf: Please specify a zombie to teleport to." notify
                    exit
                then
                
                doTeleport
                exit then
            
            pop
            read_wants_blanks
            'mainMenu jmp then

        me @ "editzombie.muf:  Only players can use this program." notify
        exit
;
.
c
q
@set editzombie.muf=3
@set editzombie.muf=W
@set editzombie.muf=L

