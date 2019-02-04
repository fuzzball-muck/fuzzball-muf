@prog topowners.muf
1 500 d
i

$def TEMPDB "/./topowners"

lvar counterDB
lvar topName
lvar topNum
lvar shown

: addOne (s -- Adds one to the username given)
    TEMPDB "/" strcat swap strcat dup
    me @ swap getpropval
    1 +
    me @ rot rot setprop
;

: getName (s -- s  Given a prop, returns the name in the prop)
    dup "/" rinstr strcut swap pop
;

: eraseName (s -- Erases name s from the tempdb)
    me @ TEMPDB "/" strcat rot strcat remove_prop
;

: countOwners ( -- Fills in TEMPDB with all the owners )
    dbtop counterDB !
        BEGIN
                counterDB @ player? not counterDB @ ok? and if
                    counterDB @ owner name addOne
                then

                counterDB @ int 1 - dbref counterDB !

                counterDB @ int 0 =
        UNTIL

        ( Owner of room #0)
        0 dbref owner name addOne
;

: getTop ( -- Fills in topName and topNum with the current top
              one in the tempdb)

    me @ TEMPDB "/" strcat nextprop

    BEGIN
        dup me @ swap getpropval
        dup topNum @ > if 
            topNum !
            dup getName topName !
        else pop then

        me @ swap nextprop

        dup strlen not
    UNTIL
    pop
;

: displayResults (i --  Displays the top i owners)
    0 shown !

    BEGIN
        "" topName !
        0  topNum  !

        getTop

        me @ topName @ "," strcat topNum @ intostr strcat notify

        topName @ eraseName

        shown @ 1 + shown !

        dup shown @ =
    UNTIL

    pop
;

: main
    background

    atoi dup 0 = if
        pop
        me @ "Specify the length of the roster." notify
        exit
    then

    (remove the old temp db to start over again)
    me @ TEMPDB remove_prop

    me @ "X   Finding owners..." notify
    countOwners

    me @ "i   Displaying results..." notify
    displayResults

    (We're done with the DB, so start over next time)
    me @ TEMPDB remove_prop

    me @ "*Done*" notify
;
.
c
q
@set topowners.muf=3
@set topowners.muf=W
@set topowners.muf=!D