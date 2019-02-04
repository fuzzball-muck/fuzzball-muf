( /quote -dsend -S '/data/spindizzy/muf/chownall110.muf )
@prog ChownAll.muf
1 2222 d
i

( ChownAll v1.10 by Morticon@SpinDizzy 2006 )

( Used by wizzes to chown all objects of one person to another, save for actions on )
( the person themself. )
  
( Setup is easy:  Create an action named @chownall and link it to this program.  Help screen is )
( built-in )

$def CHOWNTAGPROP "/@/chowntag"

lvar chownFrom
lvar chownTo
lvar chownTag
lvar dbCount
lvar chownCount


: do_chown
    dbtop dbCount !
        BEGIN
                ( Is the object valid? )
                dbcount @ ok? if
                    ( Does the old owner own the object? )
                    dbCount @ owner chownFrom @ dbcmp if
                        ( If the object is not a player and not an action on the player, then do the chown )
                        ( Also update the home if it was set to old player, but otherwise notouch)
                        dbCount @ player? not
                        dbCount @ location chownFrom @ dbcmp dbCount @ exit? and not
                        and if
                            dbCount @ chownTo @ setown
                            chownCount @ 1 + chownCount !

                            ( Skip relinking on programs - not valid for them )
                            dbCount @ program? not if
                                dbCount @ getlink chownFrom @ dbcmp if
                                    dbCount @ chownTo @ setlink
                                then
                            then
    
                            ( If a chowntag is used, set it on this object )
                            chownTag @ strlen if
                                dbCount @ CHOWNTAGPROP chownTag @ setprop
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
    me @ "ChownAll v1.10   Morticon@SpinDizzy 2006" notify
    me @ "#help:" notify
    me @ "  This command, for wizzes only, chowns everything a player owns to" notify
    me @ "  another player, except for actions on the player themself." notify
    me @ " " notify
    me @ "  Syntax:  @chownall fromPlayer=toPlayer [chowntag]" notify
    me @ " " notify
    me @ "  Chowntag is optional and somewhat allows control for chowning" notify
    me @ "  everything to someone else easily in the future." notify
    me @ " " notify
    me @ "  A confirmation will be given before proceeding with the @chowns." notify
    me @ " " notify
    exit
;

: main
    "me" match me !
    "" chownTag !

    ( Not a mortal command )
    me @ "wizard" flag? not if 
        me @ 
          "Sorry, only wizards may use this command.  Please hang up and try again." 
        notify exit then


    ( Get the parameters and fill them in the appropiate lvars, or show a syntax diagram )
    0 dbCount !
    0 chownCount !

    "=" explode
    2 = not if 'syntax jmp then
    (OK, they entered two names. Turn them into dbrefs or quit if unable)
  
    ( First, grab who to chown from )
    strip tolower "*" swap strcat match dup player? if chownFrom !
        else me @ "Problem finding original object owner (ownerFrom).  Aborted." notify exit then

    ( Then, grab who to chown to and the optional chowntag, if present )
    strip dup " " rinstr dup if
        ( There is a chowntag, so extract that, then the name)
        strcut
        ( Process chowntag for problems )
        strip dup "*[/:\" ]*" smatch if
            ( Stop here.  Illegal character in chowntag found )
            me @ "Bad character(s) found in chowntag.  Use alphanumerics only, please." notify
            exit
        then
        ( Chowntag OK, so store it )
        tolower chownTag !
    else
        ( No chowntag )
        pop
    then

    ( Store chown to )
    strip tolower "*" swap strcat match dup player? if chownTo !
        else me @ "Problem finding new object owner (ownerTo).  Aborted." notify exit then

    ( Hey, you never know... )
    chownFrom @ chownTo @ dbcmp if
        me @ "That's the same character!  Silly!" notify exit
    then

    ( OK, names are usable.  Do a confirmation and then begin! )
    me @ " " notify
    me @ "                  !!! WARNING !!!" notify
    me @ "You are about to @chown essentially everything owned" notify
    me @ "by " chownFrom @ name strcat " to " strcat chownTo @ name strcat "!" strcat notify
    me @ "This also updates the homes of objects as needed between the players!" notify
    me @ " " notify
    chownTag @ strlen if
        me @ "ChownTag: " chownTag @ strcat notify
        me @ " " notify
    then
    me @ "CONFIRM (YES/no):" notify
    read
    "YES" strcmp not if
        me @ "[backgrounded] Processing..." notify
        background
        do_chown 
        me @ "Finished chowning " chownCount @ intostr strcat " objects." strcat notify
    else
        me @ "Aborted." notify exit
    then

    exit
;
.
c
q
@set chownall.muf=W
@set chownall.muf=3

