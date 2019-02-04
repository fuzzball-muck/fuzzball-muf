( /quote -S -dsend '/data/spindizzy/muf/will100.muf )

@prog will.muf
1 999 d
i
( @will v1.00 by Morticon@SpinDizzy )
$include $lib/strings
$include $lib/edit
$include $lib/lmgr
$include $lib/editor
$def LMGRgetcount lmgr-getcount
$def LMGRgetrange lmgr-getrange
$def LMGRputrange lmgr-putrange
$def LMGRdeleterange lmgr-deleterange

$def WILLPROP "/@/will"

: sysMessage ( s --   Prefixes command name to string and outputs completed string to user )
        me @ swap COMMAND @ ": " strcat swap strcat notify
;

: blankline ( -- )
        me @ " " notify exit
;

: isWizard? ( -- i  Returns true if me is a wizard )
    me @ "wizard" flag?
;

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

: passwordCheck ( -- Prompts user for password.  If password is incorrect, exits
                     program )
    "Enter your current password to continue:" sysMessage
    me @ read checkpassword not if
        "Incorrect password entered.  Program exited." sysMessage
        pid kill
    then
;

: editWill ( -- Creates/Edits the player's will )
    me @ "- Edit My Will -" notify
    blankline

    passwordCheck
    
    "Please enter or edit your will below using lsedit.  Type '.end' to save." sysMessage
    
    me @ intostr "=" strcat WILLPROP strcat cmd-lsedit
    
    "Done" sysMessage
;

: viewPlayerWill (d -- Show's the given player dbref's will )
   "P" checkargs
   var! target

   target @ WILLPROP "#" strcat propdir? not if
        "No will found for " target @ name strcat sysMessage
   else
        me @ "The contents of " target @ name strcat "'s will: " strcat notify
        blankline

        WILLPROP target @ LMGR-FullRange LMGR-GetBRange
        dup if
            BEGIN
                swap me @ swap notify
                1 - dup not
            UNTIL pop
        else pop then
   then
   blankline
;

: viewWill ( -- Shows the player's will)
    me @ "- View My Will -" notify
    blankline

    passwordCheck

    me @ viewPlayerWill
;

: eraseWill ( -- Erases the player's will)
    me @ "- Erase My Will -" notify
    blankline
    
    passwordCheck
    
    me @ willprop "#" strcat remove_prop
    
    "Your will has been deleted." sysMessage
;

: help ( -- Shows help )
    me @ command @ " v1.00 by Morticon@SpinDizzy 2016" strcat notify
    me @ "  Purpose: Informs the wizards about what to do with your stuff if you're purged." notify
    blankline
    me @ "  In the event a character is to be purged or erased, wizards often have a" notify
    me @ "difficult time determining what should be done with the character's things" notify
    me @ "and rooms.  This command allows you to make a note that the wizards can read," notify
    me @ "should your character be scheduled for deletion, to help them decide what" notify
    me @ "to do with your stuff." notify
    blankline
    me @ "  You can put any instructions you'd like in here, such as giving your stuff" notify
    me @ "to a certain person, or delivering a message to a few people.  The wizards" notify
    me @ "will try their best to honor requests." notify
    blankline
    blankline
    me @ "Commands:" notify
    me @ "  " COMMAND @ strcat " #edit   -  Create or edit your will." strcat notify
    me @ "  " COMMAND @ strcat " #view   -  View your will." strcat notify
    me @ "  " COMMAND @ strcat " #delete -  Removes your will." strcat notify
    isWizard? if
        me @ "  " COMMAND @ strcat " <player>-  Views specified player's will (WIZBIT ONLY)" strcat notify
    then
    blankline
;

: main ( s -- Starts the program, parses input )
    "me" match me !
    
    me @ player? not if
        "Only players can use this command." sysMessage
        exit
    then
    
    strip tolower var! argument
    
    ( #edit )
    argument @ "#e" instr 1 = if
        editWill
        exit
    then
    
    ( #view )
    argument @ "#v" instr 1 = if
        viewWill
        exit
    then
    
    ( #delete )
    argument @ "#delete" strcmp not if
        eraseWill
        exit
    then
    
    ( As a wizard, view another Player's will )
    argument @ strlen isWizard? and if
        argument @ pmatch dup player? if
            viewPlayerWill
        else
            pop
            "Player not found." sysMessage
        then
        
        exit
    then
    
    help
;
.
c
q
@set will.muf=3
@set will.muf=W
