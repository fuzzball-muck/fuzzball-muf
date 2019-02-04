( /quote -S -dsend '/data/spindizzy/muf/pie.muf )
@prog pie.muf
1 2222 d
i
lvar minTime
lvar maxTime
lvar pieNum
lvar secsElapsed
lvar maxSecs
  
: randTime (i0 i1 -- i2  Given min [i0] and max [i1] values, return a random number between them [i2])
    2 pick - random swap % +
;
  
: doSleep (i0 -- i1  Sleep for i0 seconds or until it would reach maxSecs.  Returns negative if max has not been reached, 0 if exactly reached, or > 0 if excess seconds )
    dup secsElapsed @ + maxSecs @ <= if
        ( We're at or below the max )
        dup sleep
        secsElapsed @ + maxSecs @ - exit
    else
        ( We're over the max, so only sleep a partial amount and return remainder )
        dup
        secsElapsed @ + maxSecs @ - over swap - sleep
        secsElapsed @ + maxSecs @ - exit
    then
;
  
: main ( -- )
    background
    pop
    trig location location 0
        ">> " me @ name strcat " starts eating..." strcat
    notify_exclude

    ( Read total time from /pie/total and init vars )
    trig "/pie/total" getpropstr atoi maxSecs !
    0 secsElapsed !
    0 pieNum !
  
    ( Read default minmax )
    ( Format: /pie/0/min      /pie/0/max )
    trig "/pie/0/min" getpropstr atoi minTime !
    trig "/pie/0/max" getpropstr atoi maxTime !
  
    BEGIN
        ( pieNum++ )
        pieNum @ 1 + pieNum !
  
        ( Read in new minmax, if any )
        trig "/pie/" pieNum @ intostr strcat "/min" strcat getpropstr atoi if
            trig "/pie/" pieNum @ intostr strcat "/min" strcat getpropstr atoi minTime !
            trig "/pie/" pieNum @ intostr strcat "/max" strcat getpropstr atoi maxTime !
        then
  
        ( Call randTime )
        minTime @ maxTime @ randTime
        ( doSleep )
        dup
        doSleep
        ( If doSleep <= 0, tell room they ate pie # X )
        dup 0 <= if
            ( Update seconds count )
            swap secsElapsed @ + secsElapsed !
  
            ( Tell the room what pie they ate )
            trig location location 0
                ">> " me @ name strcat " has gobbled down pie #" strcat pieNum @ intostr strcat "!" strcat
            notify_exclude
            ( Stop if exactly hit time )
            0 = if 1 break then
        else
            ( else exit, leave returncode on stack )
            2 break
        then
    REPEAT
  
    ( if rc = 1, sound buzzer and print pieNum )
    1 = if
        trig location location 0
            "## The buzzer sounds!  " me @ name strcat " ate " strcat pieNum @ intostr strcat " pies!" strcat
        notify_exclude
    else
        ( else rc = 2, sound buzzer, and print pieNum.5 )
        ( Make the fractional amount )
        2 pick swap - intostr "/" strcat swap intostr strcat
  
        trig location location 0
            "## The buzzer sounds!  " me @ name strcat " ate " strcat pieNum @ 1 - intostr strcat " " strcat 4 rotate strcat " pies!" strcat
        notify_exclude
    then
;
.
c
q
