( /quote -dsend -S '/data/spindizzy/muf/passwd.muf )
@prog passwd.muf
1 999 d
i
( passwd.muf v1.03 -  A kinder, gentler password change utility )
(  By:  Morticon@SpinDizzy  )
  
(  This program is for WIZARD INSTALLATION ONLY  )
(  Simply make an action of @password;@pass;password;passwd;pass etc, EXCEPT for @pa )
(  @pa is what it @forces the user to run to cause the password to change, as there is no )
(   MUF equivalent.  )
( Changelog:  1.03 - make old/new password comparison case sensitive )
  

( Defines: )
(  passwordcmd  - The command the user is forced to run to actually change the password  )
( minpasswordlength - The minimum number of characters for a new password required )
$def passwordcmd "@pa"
$def minpasswordlength 4

( ---Program starts HERE--- )
lvar oldpassword
lvar newpassword
lvar input


: chpasswd ( --   Uses oldpassword and newpassword variables and @forces the user to change their password if it is correct )
        ( Makes sure neither password has a space in it )
        newpassword @ " " instr if me @ "password: NEW password cannot have spaces in it." notify exit then

        ( Makes sure the passwords aren't the same )
        oldpassword @ newpassword @ strcmp not if me @ "password: NEW and OLD passwords are the same!" notify exit then

        ( Makes sure old password is correct )
        me @ oldpassword @ checkpassword not if me @ "password:  Sorry, the OLD password entered is incorrect." notify exit then

        ( Makes sure the new password meets criteria )
           (For length)
        newpassword @ strlen minpasswordlength < if me @ "password: NEW password must be of " minpasswordlength intostr strcat " characters or more.  Password not changed." strcat notify exit then
           (Is not the character name)
         me @ name newpassword @ instring if me @ "password: NEW password cannot be a part of your character name.  Password not changed." notify exit then
           (Is not their species)
        me @ "/species" getpropstr newpassword @ instring if me @ "password: NEW password cannot be a part of your species.  Password not changed." notify exit then
           (...is not their gender)
        me @ "/sex" getpropstr newpassword @ instring if me @ "password: NEW password cannot be part of your gender.  Password not changed." notify exit then
           (and... is not a silly password, like 'password')
        newpassword @ "password" stringcmp not newpassword @ "qwerty" stringcmp not newpassword @ "god" stringcmp not newpassword @ "love" stringcmp not newpassword @ "sex" stringcmp not or or or or if
                me @ "password: You cannot use any of the obvious passwords.  Password not changed." notify exit then


        ( Everything passes.  Make the change )
        me @ passwordcmd " " strcat oldpassword @ strcat "=" strcat newpassword @ strcat force
        exit
;

: passwd-prompt ( -- The interactive UI for the password )
        me @ " " notify
        me @ "Password Change Utility v1.03 - Morticon@SpinDizzy   2011" notify
        me @ " " notify
        ( Old password )
        me @ "password: Changing password for " me @ name strcat notify
        me @ "Please enter your current (OLD) password:" notify
        read strip oldpassword !
        me @ " " notify
        me @ oldpassword @ checkpassword not if me @ "password:  Sorry, the OLD password entered is incorrect." notify exit then

        ( New password )
        me @ "Please enter the desired NEW password:" notify
        read strip newpassword !
        me @ " " notify
        me @ "Please *REenter* the desired NEW password:" notify
        read newpassword @ strcmp if me @ " " notify me @ "password: NEW passwords do not match." notify exit then

        ( Attempt to make the change )
        me @ " " notify
        'chpasswd jmp
        me @ " " notify
;

: cmd-passwd
        "me" match me !
        me @ " " notify
        ( Make sure the forced command is not a valid action.  If it is, then it's a potential security issue )
        passwordcmd match ok? if me @ "password: Object '" passwordcmd strcat "' exists here or in the environment and thus presents a security hazard.  Password cannot be changed here.  Please try a different room or see a wizard for assistance." strcat notify exit then
        ( Don't let guests use the program )
        me @ "/@guest" getpropstr strlen if me @ "Guests may not use this program." notify exit then

        ( Parse commandline, if valid )
        "=" explode
        2 = not if 'passwd-prompt jmp then
        strip oldpassword ! strip newpassword !
        ( Have the passwords, so make the change )
        'chpasswd jmp
        exit
;
.
c
q
@set passwd.muf=3
@set passwd.muf=W

