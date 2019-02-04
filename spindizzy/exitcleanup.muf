( /quote -dsend -S '/data/spindizzy/muf/exitcleanup.muf )
@prog exitcleanup.muf
1 2222 d
i
( ExitCleanup v1.00 by Morticon@SpinDizzy 2013 )

( Used by wizzes to find and remove unlinked exits, which are a security
  concern )
  
( Setup is easy:  Create an action named @exitcleanup and link it to this program.)

lvar exitFrom
lvar dbCount
lvar exitRecycleCount

: do_check
    dbtop dbCount !
        BEGIN
                ( Is the object valid? )
                dbcount @ ok? if
                    ( Is it owned by the player? )
                    dbcount @ owner exitFrom @ = if
                        ( Is it an action/exit )
                        dbcount @ exit? if
                            ( Is it unlinked? )
                            dbcount @ getlink #-1 = if
                                ( Unlinked.  Recycle )
                                me @ "Recycling: " dbcount @ unparseobj strcat notify
                                dbcount @ recycle
                                exitRecycleCount ++
                            then
                        then
                    then
                then
        
                dbCount @ int 1 - dbref dbCount !
        
                dbCount @ int 0 =
        UNTIL
;

: syntax
    me @ " " notify
    me @ "ExitCleanup v1.00   Morticon@SpinDizzy 2013" notify
    me @ "#help:" notify
    me @ "  This command, for wizards only, @recycles unlinked exits owned by a" notify
    me @ "  player, except for actions located on the player." notify
    me @ " " notify
    me @ "  Syntax:  @exitcleanup <player>" notify
    me @ " " notify
    me @ "  A confirmation will be given before proceeding." notify
    me @ " " notify
    exit
;

: main
    "me" match me !

    ( Not a mortal command )
    me @ "wizard" flag? not if 
        me @ 
          "Sorry, only wizards may use this command.  Please hang up and try again." 
        notify exit then

    strip

    ( Get the parameters and fill them in the appropiate lvars, or show a syntax diagram )
    0 dbCount !
    0 exitRecycleCount !

    dup strlen not if pop 'syntax jmp then
  
    ( First, grab who to check )
    tolower "*" swap strcat match dup player? if exitFrom !
        else me @ "Problem finding owner.  Aborted." notify exit then

    ( OK, name is usable.  Do a confirmation and then begin! )
    me @ " " notify
    me @ "                  !!! WARNING !!!" notify
    me @ "You are about to check all exits owned by " exitFrom @ name strcat notify
    me @ "The program will @recycle any that are unlinked." notify
    me @ "This cannot be undone!" notify
    me @ " " notify
    me @ "CONFIRM (YES/no):" notify
    read
    "YES" strcmp not if
        me @ "[backgrounded] Processing..." notify
        background
        do_check
        me @ "Finished recycling " exitRecycleCount @ intostr strcat " exits." strcat notify
    else
        me @ "Aborted." notify exit
    then

    exit
;
.
c
q
@set exitcleanup.muf=W
@set exitcleanup.muf=3

