READ THIS:  Go to the last line of this file and change 1234 to the dbref of a player that you wish the mail to be from when an invalid password attempt is sent to a user.
Change SOME_ADMIN to people's name(s) to p #mail extra (A wiz perhaps?) separated by spaces.  Otherwise, erase it to page #mail no one additional.
Finally, change 3 to a number of invalid attempts to ignore before logging  (This prevents the occansional mistyped password by an authorized user being logged).


@prog su.muf
1 999 d
i
( su.muf v1.11  by Kulan of Spindizzy 2004 )
lvar user
lvar passwd
  
: invalid
        me @ "su.muf: Either that player does not exist, or has a different password." notify

        ( If code 2 came from switcharoo, then log the attempt to the target player if exceeded attempt limit )
        2 = if me @ "/@/invalidsu" getpropval prog "/logafter" getpropstr atoi >= if
           prog "/mailfrom" getpropstr atoi dbref "page #mail " user @ name strcat " " strcat prog "/alsomail" getpropstr  strcat "=: <<>> Player " strcat me @ name strcat " attemped to use the " strcat trig name strcat " command with an invalid password for account " strcat user @ name strcat " <<>>" strcat force
           me @ "su.muf: Invalid password attempt logged." notify
           me @ "/@/invalidsu" remove_prop
        else me @ "/@/invalidsu" getpropval 1 + me @ "/@/invalidsu" "" 4 rotate addprop then then
        exit
;
  
( From Fek's fek-guest.  Certainly had a lot of comments for a Fek program :)
: my-descriptor ( - i ; returns topmost descriptor from list )
  ME @ descriptors over over ( ix..i1 i i1 i )
  2 + -1 * rotate ( i1 ix..i1 i )
  begin dup while 1 - swap pop repeat pop ( i1 )
;
  
: switcharoo
        user @ .pmatch user !
        ( If they entered a nonextistant player, abort now by going to 'invalid )
        user @ int 1 < if 1 'invalid jmp then
  
        ( Otherwise, try and make the switch! )
        user @ passwd @ checkpassword if me @ "/@/invalidsu" remove_prop my-descriptor user @ passwd @ descr_setuser exit then
        ( Wrong Password? )
        2 'invalid jmp
;
  
: cmd-connect
        "me" match me !
        ( Guest check )
        me @ "/@guest" getpropstr strlen if me @ "Guests may not use this program." notify exit then
        ( Player check )
        me @ player? if
        ( If they don't enter exactly two params, assume they want help or are silly.  Otherwise, try and switch the user )
          " " explode 2 = if
            tolower user !
            passwd !
            'switcharoo jmp
          then
          me @ " " notify
          me @ "su.muf v1.11 by Kulan of Spindizzy 2004" notify
          me @ "#HELP" notify
          me @ " " notify
          me @ "What it does:   Switches your connection to another user." notify
          me @ "How to use it:  " command @ strcat " user password" strcat notify
          me @ "  Where user is the username, and password is the password of the desired user." notify
          me @ "  Please note multiple incorrect password attempts are logged!" notify
          me @ " " notify
          exit
        then me @ "su.muf: Object using program does not have the P flag.  Cannot run." notify
        exit
;
.
c
q
@set su.muf=3
@set su.muf=W
@set su.muf=L
//@action su=#0
//@link su=su.muf
//@set su.muf=!L
//@set su.muf=/mailfrom:1234
//@set su.muf=/alsomail:SOME_ADMIN
//@set su.muf=/logafter:3
