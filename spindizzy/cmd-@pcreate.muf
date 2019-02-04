( /quote -dsend 'e:\spindizzy\muf\cmd-@pcreate.muf )
@edit #15091
1 2222 d
i


( Defines )
$def WHERETEMPLATE "/template"

( Variables )
lvar newUser
lvar emailAddress
lvar pcreateString
lvar templateDB


( ---- Taken from lib-propdirs    v1.1    Jessy @ FurryMUCK    5/97, 8/01  )
( ----    Library appears to be a security risk, so it is not included )
: move_dir-r   ( d1 s2 d2 s2 --   )        (* move dir/subdirs s1 on d1
                                              to dir/subdirs s2 on d2  *)
    begin
        4 pick 4 pick propdir? not if
            dup "*/" smatch if
                dup strlen 1 - strcut pop 
            then
            3 pick "*/" smatch if
                3 pick dup strlen 1 - strcut pop 3 put
            then
            4 pick 4 pick getprop setprop remove_prop break
        then
        4 pick 4 pick propdir? if
            4 pick 4 pick 4 pick 4 pick
            dup "*/" smatch not if
                "/" strcat 
            then
            3 pick "*/" smatch not if
                3 pick "/" strcat 3 put
            then
            4 pick 4 pick nextprop dup
            3 pick 6 pick subst 
            2 put 3 put
            move_dir-r
        else
            4 pick 4 pick getprop setprop remove_prop
        then
    repeat
;

: copy_dir_loop  ( d1 s1 d2 s2 --  )         (* move dir/subdirs s1 on d1
                                              to dir/subdirs s2 on d2  *)
    begin
        4 pick 4 pick propdir? not if
            dup "*/" smatch if
                dup strlen 1 - strcut pop 
            then
            3 pick "*/" smatch if
                3 pick dup strlen 1 - strcut pop 3 put
            then
            4 pick 4 pick over over
            dup pid intostr "/" strcat swap strcat rot rot
            getprop prog rot rot setprop
            getprop setprop remove_prop break
        then
        4 pick 4 pick propdir? if
            4 pick 4 pick 4 pick 4 pick
            dup "*/" smatch not if
                "/" strcat 
            then
            3 pick "*/" smatch not if
                3 pick "/" strcat 3 put
            then
            4 pick 4 pick nextprop dup
            3 pick 6 pick subst 
            2 put 3 put
            copy_dir_loop
        else
            4 pick 4 pick getprop setprop remove_prop
        then
    repeat
;

: copy_dir-r    ( d1 s1 d2 s2 --  )        (* copy dir/subdirs s1 on d1
                                              to dir/subdirs s2 on d2  *)
   
         (* function copies to dest and prog, deleting from source;
            then copies back from prog to source, deleting from prog.     
            This turns out to be more efficient than leaving dir on 
            source and recording info necessary to back out of subdirs *)
                 
    4 pick 4 pick
    6 rotate 6 rotate 6 rotate 6 rotate 
    copy_dir_loop
    prog pid intostr "/" strcat 3 pick strcat
    4 rotate 4 rotate move_dir-r
;

: copy_root  ( d1 d2 )                  (* copy all props on d1 to d2 *)
  
	over "/" nextprop
	begin
	  dup while
    3 pick over 4 pick over copy_dir-r
		3 pick swap nextprop
	repeat
	pop pop pop
;

( ------------------------------------- )


: syntax ( --   Outputs how to use program )
    me @ " " notify
    me @ "@pcreate drop-in v1.03 by Morticon@SpinDizzy 2004" notify
    me @
            "Template is: " templateDB @ name strcat "(#" strcat templateDB @ int intostr strcat ")" strcat notify
    me @ "Usage:  @pcreate NewUser=NewPassword email@host.com" notify
    me @ " " notify
    exit
;

: createChar ( --  Uses the lvars to create a character and copy template propdirs over )
    ( Final stupid check - make sure they aren't making a duplicate user )
    "*" newUser @ strcat match
    ok? if
        me @ "@pcreate: User already exists!  Aborting." notify
        pid kill
    then

    background
    ( @force the wiz to pcreate the character, then sleep 1 second for that to finish )
    me @ "@pcreate: Waiting for inserver @pcreate to complete..." notify
    me @ pcreateString @ force
    2 sleep

    ( Now, verify it actually made the character )
    "*" newUser @ strcat match dup newUser !
    ok? not if
        me @ "@pcreate: Error creating character!  Aborting." notify
        pid kill
    then

    ( Character made, so let's copy props from the template object )
    me @ "@pcreate: Character created.  Copying/Setting props..." notify
    templateDB @ newUser @ copy_root
    ( But erase /@/ on the new character because it's character specific )
    ( We don't need that propdir from the template user )
    newUser @ "/@" remove_prop

    ( Set the @email, @regby, and @regname props )
    newUser @ "/@email" emailAddress @ setprop
    newUser @ "/@regdby" me @ name setprop
    newUser @ "/@regname" newUser @ name setprop

    ( Finally, because the currency is set to 0 when we cleared out /@/, give
      them the standard amount to start out with )
    newUser @ "start_pennies" sysparm atoi addpennies

    me @ "@pcreate: Finished copying/setting props.  User has been created properly." notify
    exit
;

: fillVars ( s -- Takes the program arguments and fills in newUser, emailAddress, and pcreateString lvars )
    dup " " instr strcut 
    ( email address )
    strip emailAddress ! 
    ( What gets forced later )
    strip dup "!@pcreate " swap strcat pcreateString !
    ( ...and the user name, to verify inserver call succeeded )
    dup "=" instr dup 

    ( If they messed up the syntax, ie no =, then tell them the syntax and exit )
    not if syntax pid kill then

    ( Else, cut it up and fill in the user name )
    1 - strcut pop strip newUser !

    exit
;

: cmd-pcreate
        "me" match me !

        ( Not a mortal command )
        me @ "wizard" flag? not if 
            me @ 
                "Sorry, only wizards may use this command.  Please hang up and try again." 
            notify exit then

        ( Make sure /template was configured on action, and throw it in the lvar )
        trig WHERETEMPLATE getpropstr atoi dup dbref templateDB ! dup 0 > swap dbref ok? and not if
            me @ "@pcreate: /template on @pcreate action is not pointing to a template object." notify
            me @ "@pcreate:  Example:  @set @pcreate=/template:1234" notify
            exit
        then

        ( Make sure they provided the arguments.  If not, show 'em how )
        strip
        dup " " instr not if 'syntax jmp then
        dup "=" instr not if 'syntax jmp then

        ( Everything looks OK.  Let's do it! )
        fillVars
        createChar
  
        exit
;
.
c
q
@set cmd-@pcreate.muf=3
@set cmd-@pcreate.muf=W

