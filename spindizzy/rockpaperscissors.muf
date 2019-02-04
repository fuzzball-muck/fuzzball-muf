( /quote -dsend 'muf\rockpaperscissors.muf )

@prog rockpaperscissors.muf
1 500 d
i
( Rock paper scissors! v1.00 by Morticon@SpinDizzy )
( INSTALL: Make an action on a thing and link it to this program.
           Action name is recommended to be 'rps;qrps' to allow for the
           'quiet' mode.  Quiet mode announces the result ONLY to the two
           people playing.  It might be useful for RPs or something.  At no
           time is the 'move submitted' message shown to anyone but the
           submitter. )
  
: resetGame
    trig "/rps/player" remove_prop
    trig "/rps/move" remove_prop
;
  
: parseArg  ( s -- i  Given a string 'rock', 'paper', 'scissors',
             return an integer representing it.  0 if invalid )
  
    strip
    dup "rock" stringcmp not if pop 1 exit then
    dup "paper" stringcmp not if pop 2 exit then
    "scissors" stringcmp not if 3 exit then

    ( No match )
    0
;
  
: toString  ( i -- s  Given an int, return a string like 'rock', ...
              opposite of parseArg )
  
    dup 1 = if pop "rock" exit then
    dup 2 = if pop "paper" exit then
    3 = if "scissors" exit then
  
    ""
;
  
: showHelp
    me @ " " notify
    me @ "Rock Paper Scissors! v1.00 by Morticon@SpinDizzy" notify
    me @ " " notify
    me @ "To play, type '" command @ strcat
        "' followed by 'rock', 'paper', or 'scissors'." strcat notify
    me @ " " notify
    me @ "This is a two player game.  For instance, player one would type" notify
    me @ "'" command @ strcat " rock' and player two would type '" strcat
        command @ strcat " paper'" strcat notify
    me @ "in any order, and the winner would be player two." notify
    me @ " " notify
;
  
: whoWon  ( i0 i1 -- i  GIven two rockpaperscissor ints, return 0 or 1 to
            indicate which won.  2 for a draw )
    ( Check for same - indicates draw )
    dup 3 pick = if pop pop 2 exit then
  
    ( Now, check for cases where i0 = 1 )
    2 pick 1 = if
        2 = if
            pop 1 exit
        else
            pop 0 exit
        then
    then
  
    ( Now, check for cases where i0 = 2 )
    2 pick 2 = if
        1 = if
            pop 0 exit
        else
            pop 1 exit
        then
    then
  
    ( Now, check for cases where i0 = 3 )
    2 pick 3 = if
        1 = if
            pop 1 exit
        else
            pop 0 exit
        then
    then
   
    ( Failsafe )
    pop pop 2
;
  
: main
    preempt
    "me" match me !

    dup strlen not if
        pop
        'showHelp jmp
    then

    ( Make sure program is installed right )
    trig location thing? not if
        me @ "ERROR:  Program not linked to an action on a THING." notify
        pop
        exit
    then
  
    ( Check to see if in the middle of a game.  If we are, and the other
      player is gone, reset and continue.  Also die if already put in
      move for game )
    trig "/rps/player" getprop dup dbref? if
        ( Already played )
        dup me @ dbcmp if
            pop me @ "ERROR: Move has already been submitted!" notify pop exit
        then
        ( Other guy was recycled or toaded? )
        dup dup thing? swap player? or not if
            pop resetGame
        else
            ( Other guy no longer in the room? )
            location trig location location dbcmp not if
                ( Other guy gone, Reset game)
                resetGame
            then
        then
    else 
        pop
    then
  
    ( parse the argument: rock, paper, or scissors)
    parseArg dup not if
        pop
        'showHelp jmp
    then
  
    ( We got their selection.  If they're the first, store it and exit,
      else compare and find the winner. )
    trig "/rps/player" getprop dbref? if
        dup
        ( Print out who did what action )
        "## "
  
        trig "/rps/player" getprop name strcat
        " shows their " strcat
        trig "/rps/move" getprop toString strcat
        "! " strcat
  
        me @ name strcat
        " shows their " strcat
        swap toString strcat
        "! " strcat
  
        ( Compare )
        "** " strcat
        trig "/rps/move" getprop swap rot rot swap
        whoWon dup if
            ( If tie )
            2 = if
                "TIE **"
            else
                ( Current program executor won )
                me @ name " won **" strcat
            then
        else
            pop
            ( Other guy won )
            trig "/rps/player" getprop name " won **" strcat
        then
        ( Get the actions + winner together )
        strcat
        ( Tell the room and reset the game, or do quiet mode )
        command @ 1 strcut pop "q" stringcmp not if
            ( Quiet mode - to both players only )
            "(Quietly) " swap strcat
            dup
            trig "/rps/player" getprop swap notify
            me @ swap notify
        else
            ( noisy mode )
            me @ location 0 rot notify_exclude
        then
        resetGame
    else
        ( Record their move )
        trig "/rps/player" me @ setprop
        trig "/rps/move" rot setprop
        me @ "Move submitted." notify
    then
;
.
c
q
@set rockpaperscissors.muf=2
@set rockpaperscissors.muf=L
@set rockpaperscissors.muf=!D
