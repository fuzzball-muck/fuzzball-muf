(* editroom.muf
 *
 * Simplified room editor designed to be simple and easy to use.  This is
 * not an exhaustive, handles-every-little-detail editor; rather it is designed
 * more for people who are new to MUCK building in order for them to get the
 * common basics working.
 *
 * Do note that this allows remote-editing of rooms controlled by the
 * player, and also allows teleporting to those rooms.  If either of those
 * are concerns of yours, consider that before installing this program.
 *
 * Otherwise, this program is secure and obeys standard MUCK rules as
 * far as I am aware.  Your mileage may, of course, vary but this has been
 * used by a fairly active builder user base with great success.
 *
 * By HopeIslandCoder
 * 2018
 * Public Domain
 *)
 
$def VERSION "Edit Room v1.04 by HopeIslandCoder"
$version 1.04
$author HopeIslandCoder
 
(* CONFIGURATION *)
 
(* Use $lib/quota ?  Comment out to turn off*)
$def USE_QUOTA  1
 
(* Obvious exits
 *
 * What is the PROP NAME and PROP VALUE that signifies that
 * obvious exits are turned on?  For most MUCKs, this will be _/sc
 * [the "@succ" property] and something akin to: @$obvexits
 *
 * However, if you have a custom look program, this may be a different
 * prop and value.
 *
 * To handle the case of obvious exits being default-on, you can set
 * an "off" value and have the "on" value be an empty string.  For most
 * MUCKs, the off value is an empty string,
 *)
$def OBVEXITS_PROP  "_/sc"
$def OBVEXITS_ON    "@$exits"
$def OBVEXITS_OFF   ""
 
(* END CONFIGURATION *)
 
$include $lib/editor
$include $lib/lmgr
$include $lib/findparent
$include $lib/tabtoolkit
 
$ifdef USE_QUOTA
$include $lib/quota
$else
(* If we we are not using quota, we need to define a few calls provided
 * by the quota library.  This is a little more efficient then riddling
 * the code with $ifdef checks in my opinion.
 *
 * CheckName comes straight from the quota library.
 *)
 
: CheckName  ( s -- i )    (* return true if s is a valid object name *)
  
  dup "#"    stringpfx if pop 0 exit then
  dup "="    instr     if pop 0 exit then
  dup "&"    instr     if pop 0 exit then
  dup "here" smatch    if pop 0 exit then
  dup "me"   smatch    if pop 0 exit then
  dup "home" smatch    if pop 0 exit then
  pop 1
;
 
(* This is a simplified, but functionally equivalent, version of
 * what is in the quota lib.
 *)
: GetCost ( s -- i ) (* Return cost of type 's' *)
  dup "exit" 4 strncmp not if
    pop "exit_cost" sysparm atoi
  else dup "room" 4 strncmp not if
    pop "room_cost" sysparm atoi
  else
    "Unknown GetCost type: " swap strcat abort
  then then
;
 
$def CheckCost GetCost swap pennies <=
$def CheckQuota pop pop 1
$def Exempt? "WIZARD" flag?
 
$endif
 
 
(* WORKFLOW NOTES
 *
 * How it should work: User starts program, program asks if creating new
 * room or editing current room.
 *
 * IF editing existing, check permission then fall into main loop.
 * IF creating new, enter create new room menu option and follow prompts.
 *
 * Note: Must support quota.
 *
 * Support:
 * - Create Room
 * - Set Description
 * - Set common flags [LINK_OK, ABODE, CHOWN_OK]
 * - Toggle obvious exits.
 * - Set parent room
 * - Quick-create new parent room
 * - Link yourself to room
 * - Teleport to new room.
 * - Create exits
 *   - Exit from current room to new room
 *   - Exit back from new room to current room
 *   - Exit to/from arbitrary DBREF
 *)
 
: help ( -- ) (* Display help banner *)
  
  VERSION 70 tt-tab-init
  "This is a simple room editing program." tt-tab-addline
  "-[Usage]--------------------------------------------------------------"
  tt-tab-addline
  command @ "         - Edit current room, or create a new room" strcat
  tt-tab-addline
  command @ " #help   - This message" strcat tt-tab-addline
  command @ " #create - Shortcut to create new room" strcat tt-tab-addline
  command @ " #new    - Same as #create" strcat tt-tab-addline
  command @ " #12345  - Replace 12345 with a DBREF - remote edit room"
  strcat tt-tab-addline
  command @ " here    - Shortcut to edit current room." strcat
  tt-tab-addline
  "" tt-tab-final-flush
;
 
: cb-yes-no ( s -- i ) (* Callback for yes / no questions *)
  strip tolower
  dup "y" 1 strncmp not if
    pop 1 exit
  else "n" 1 strncmp not if
    1 exit
  then then

  "Please answer 'y'es or 'n'o." tell 0
;
 
: cb-room-name-query ( s -- i ) (* Callback for checking valid room name *)
  CheckName dup not if
    "That is not a valid room name.  You probably have funky characters in it."
    tell
  then
;
 
: cb-exit-name-query ( s -- i ) (* Callback for checking valid exit name *)
  CheckName dup not if
    "That is not a valid exit name.  You probably have funky characters in it."
    tell
  then
;
 
: input-loop ( s i a -- s' ) (* Takes a stackrange of strings that are some
                              * kind of question to ask, and a function which
                              * is a callback to check the validity of the
                              * answer.  Loops until a valid answer is given
                              * then returns that valid answer.
                              *
                              * Callback should [ s -- i ] returning boolean
                              * Callbacks have to be defined above this
                              * function.
                              *)
  var! callback array_make
  begin
    dup { me @ }list array_notify
    read
    dup callback @ execute if
      swap pop
      exit
    then
    pop
  repeat
;
 
: createlink[ dbref:Source dbref:Dest -- ] (* Creates an exit in Source
                                            * that links to Dest, doing
                                            * all permission and quota
                                            * checking.

                                            *)
  me @ Source @ controls if
    (* Check quota / cost *)
    me @ Exempt? not if
      me @ "exits" CheckCost not if
        "You do not have enough " "pennies" sysparm strcat
        " to build an exit." strcat tell
        exit
      then
      
      me @ "exits" CheckQuota not if
        "You do not have enough quota to build an exit." tell
        exit
      then
    then
 
    (* Check permissions *)
    Dest @ "LINK_OK" flag? me @ Dest @ controls or not if
      "You cannot link from here to there - the destination is not LINK_OK "
      tell
      "or owned by you." tell
    else
      "What would you like to call your exit from:"
      Source @ name
      "to:"
      Dest @ name
      "Note that exits can have aliases using ;.  For example:"
      "Go [N]orth;n;north;go"
      "This will show up as 'Go [N]orth', but typing 'n', 'north', or 'go'"
      "will also work.  Type in your exit name below:"
      8 'cb-exit-name-query input-loop
 
      Source @ swap newexit dup exit? not if
        (* This should never happen, but if it does, we'll handle it *)
        pop
        "There was a problem making this exit.  Please try again, maybe "
        tell
        "avoiding special characters." tell
        exit
      then
 
      (* Deduct exit cost *)
      me @ Exempt? not if
        me @ "exit" GetCost -1 * addpennies
      then
 
      dup Dest @ setlink
      
      dup "_/sc"
      "Now, enter a message that the person going through this exit will see."
      tell
      read setprop
      
      dup "_/osc"
      "Now, enter a message that the people in the room the exit-user is "
      tell
      "LEAVING will see.  Their name will automatically be prefixed on the "
      tell
      "message.  So, this message:" tell
      "leaves to go north." tell
      "will show up as:" tell
      me @ name " leaves to go north." strcat tell
      "Enter a message now:" tell
      read setprop
      
      dup "_/odr"
      "Finally, enter a message that the people in the destination room will"
      tell
      "see when the exit-user arrives.  This message works just like the"
      tell
      "previous one -- the user's name will automatically be prefixed on "
      tell
      "the message." tell
      read setprop

      pop (* Don't need the exit dbref anymore *)
    then
  else
    "You are not permitted to make exits in that room." tell
  then
;
 
: createlinkset[ dbref:Source dbref:Dest -- ] (* Creates a set of links from the
                                               * first dbref to the second, and
                                               * optionally back again.
                                               *)
  (* First, create the link from Source to Dest.  Make sure Source is
   * controlled by me, and Dest is either LINK_OK or controlled.
   *
   * If I don't control Source, let's skip Source and see if we can
   * do the back link instead.
   *)
  Source @ Dest @ createlink
  "Would you like to link from:"
  Dest @ name
  "back to:"
  Source @ name
  "Enter 'y'es or 'n'o:"
  5 'cb-yes-no input-loop
  .yes? if
    Dest @ Source @ createlink
  then
;
 
: createroom ( -- d ) (* Creates a new room.  If for some reason we cannot
                       * create the room [user aborts, or quota reasons],
                       * we will return #-1.  Otherwise, return DBREF created.
                       *)
  (* Do fundamental checks *)
  me @ Exempt? not if
    me @ "rooms" CheckCost not if
      "You do not have enough " "pennies" sysparm strcat " to build a room."
      strcat tell
      #-1 exit
    then
 
    me @ "rooms" CheckQuota not if
      "You do not have enough quota to build another room." tell
      #-1 exit
    then
  then
  
  "Please pick a name for your room, or type '.abort' without the quotes to "
  "abort."
  2 'cb-room-name-query input-loop
  
  dup ".abort" strcmp not if
    "Aborting!" tell
    pop #-1 exit
  then
  
  me @ location findparent swap newroom
  
  (* Make sure it worked -- this should never fail *)
  dup room? not if
    pop
    "There was a problem creating your room.  Try running this program again."
    tell
    "Make sure your room name has no special characters in it." tell
    #-1 exit
  then
 
  me @ Exempt? not if
    me @ "room" GetCost -1 * addpennies
  then
 
  (* If you control the room you're in, let's offer to link it up. *)
  me @ me @ location controls if
    "Would you like to create a link from your current room to the new room?"
    "Please type 'y'es or 'n'o."
    2 'cb-yes-no input-loop
    
    .yes? if
      dup me @ location swap createlinkset
    then
  then
 
  (* Created room should be all that is left on the stack at this point *)
;
 
: set-description[ dbref:ToEdit -- ] (* Takes a DBREF and sets its description
                                      * with the list editor.
                                      *)
  "" var! ListName
  
  ToEdit @ "_/de" getpropstr strlen if
    "Current description:" tell
    " " tell
    ToEdit @ "_/de" "(LOOK)" 1 parseprop tell
    " " tell
    "Would you like to edit this description?  'Y'es or 'n'o."
    1 'cb-yes-no input-loop
  
    .yes? not if
      exit
    then

    (* Figure out the list name *)
    ToEdit @ "_/de" getpropstr "{list:" instring if
      ToEdit @ "_/de" getpropstr "{list:" split swap pop
      "," split pop (* Might have a comma, might not *)
      "}" split pop (* But will have a close-brace. *)
      ListName !
    else
      (* Blank list name means the property contains the list text. *)
      "" ListName !
    then
  else
    "You have no description yet.  Entering the editor." tell
  then
  
  (* Load the editor text -- this will either be whatever was in _/de
   * or it will be a list.
   *)
  ListName @ strlen not if
    ToEdit @ "_/de" getpropstr dup strlen not if
      pop 0
    else
      1 (* This makes our single line description into a stackrange *)
    then
  else
    ListName @ ToEdit @ lmgr-fullrange lmgr-getrange
  then
  
  editor (* Runs the editor *)
  
  "a" 1 strncmp not if
    (* Abort -- don't save it *)
    popn
    exit
  then
  
  ListName @ strlen if
    ToEdit @ ListName @ "#" strcat remove_prop (* Cause lmgr-deletelist doesn't
                                                * always work.
                                                *)
  else
    "desc" ListName !
    ToEdit @ "_/de" "{list:desc}" setprop
  then
 
  1 ListName @ ToEdit @ lmgr-insertrange
;  
 
: editexit[ dbref:Editing -- ] (* Edit a single exit *)
  begin
    "Exit Editor: Exit Ref #" Editing @ intostr strcat 75 tt-tab-init
    "1] Change Exit Name: " Editing @ name strcat tt-tab-addline
    "2] Change Exit Link: "
    Editing @ getlink dup #-1 dbcmp if
      pop "* UNLINKED *"
    else
      name
    then
    strcat tt-tab-addline
    "3] Set success message.  Currently:" tt-tab-addline
    "   " Editing @ "_/sc" getpropstr strcat tt-tab-addline-wrap
    "4] Set other-success message.  Currently:" tt-tab-addline
    "   " Editing @ "_/osc" getpropstr strcat tt-tab-addline-wrap
    "5] Set destination message.  Currently:" tt-tab-addline
    "   " Editing @ "_/odr" getpropstr strcat tt-tab-addline-wrap
    "Q] Finish editing this exit" tt-tab-addline
    "<Pick an Option or pick Q>" tt-tab-final-flush
    read
 
    dup "1" strcmp not if
      pop
      "Enter a new name for this exit.  Remember, with exits, you can provide"
      tell
      "aliases by using ;.  For instance, the exit name: [N]orth;n;north" tell
      "would work with 'n' or 'north'.  Enter the name below:" tell
      read
      dup CheckName not if
        pop 
        "That is not a valid exit name.  It may have unsupported special "
        tell
        "characters." tell
      else
        Editing @ swap setname
      then
    else dup "2" strcmp not if
      pop
      "Where do you want to link this exit?  Usually, you will use a DBREF"
      tell
      "number here, which starts with a #, such as: #12345" tell
      "To leave the exit unlinked, use the special DBREF #-1:" tell
      read
      
      (* #-1 is a special case we must handle.  If we check after we match,
       * then errors will cause us to unlink and that is weird behavior.
       *)
      dup "#-1" strcmp not if
        pop Editing @ #-1 setlink
      else
        match
        dup room? not if
          pop "You can only link exits to rooms." tell
        else dup dup "LINK_OK" flag? swap me @ swap controls or not if
          pop "You can only link to rooms you own or that are set LINK_OK."
          tell
        else
          (* Unlink it first is required *)
          Editing @ #-1 setlink
          Editing @ swap setlink
        then then
      then
    else dup "3" strcmp not if
      pop
      Editing @ "_/sc"
      "Enter a message that the person going through this exit will see."
      tell
      read setprop
    else dup "4" strcmp not if
      pop
      Editing @ "_/osc"
      "Now, enter a message that the people in the room the exit-user is "
      tell
      "LEAVING will see.  Their name will automatically be prefixed on the "
      tell
      "message.  So, this message:" tell
      "leaves to go north." tell
      "will show up as:" tell
      me @ name " leaves to go north." strcat tell
      "Enter a message now:" tell
      read setprop
    else dup "5" strcmp not if
      pop
      Editing @ "_/odr"
      "Finally, enter a message that the people in the destination room will"
      tell
      "see when the exit-user arrives.  This message works just like the"
      tell
      "previous one -- the user's name will automatically be prefixed on "
      tell
      "the message." tell
      read setprop
    else dup tolower "q" strcmp not if
      pop exit
    else
      "Try again?" tell
    then then then then then then
  repeat
;
 
: editexits[ dbref:ToEdit -- ] (* Enter the edit exits loop for a given
                                * room.
                                *)
  ToEdit @ room? me @ ToEdit @ controls and not if
    (* This should never happen, so we'll just kick out if it happens *)
    exit
  then
  
  begin
    "Exit Editor: Room Ref #" ToEdit @ intostr strcat 75 tt-tab-init
    "The following exits are in this room:" tt-tab-addline
    " " tt-tab-addline
 
    ToEdit @ exits #-1 dbcmp if
      " - None Created Yet -" tt-tab-addline
    else
      ToEdit @ exits
      begin
        dup #-1 dbcmp not while
        dup name ";" split
        " (Aliases: " swap strcat ")" strcat strcat (* a d s *)
       rot swap tt-tab-addline-wrap
        swap next
      repeat
      pop
    then
    " " tt-tab-addline
    "Options:" tt-tab-addline
    "1] Create New Exit" tt-tab-addline
    ToEdit @ exits #-1 dbcmp not if
      "2] Edit Exit" tt-tab-addline
      "3] Delete Exit" tt-tab-addline
    then
    "Q] Quit Back to Room Editor" tt-tab-addline
    
    "<Pick an Option or Q to Return>" tt-tab-final-flush
    
    read
    dup "1" strcmp not if
      pop
      "Where do you want this exit to go to?  This is typically a DBREF number."
      tell
      "Note that DBREFs must start with a # mark, such as #12345." tell
      "The target room must be owned by you or set LINK_OK." tell
      "Type it in now." tell
      read
      match
      dup room? not if
        pop "The editor only permits you to link to rooms."
      else dup dup "LINK_OK" flag? swap me @ swap controls or not if
        pop "The room you are linking to is neither LINK_OK nor owned by you."
        tell
      else
        ToEdit @ swap createlinkset
      then then
    else dup "2" strcmp not if
      pop
      "Please type the exit name you wish to edit.  This can be the full name,"
      tell
      "an alias of the exit, or even a DBREF number starting with #." tell
      ToEdit @ 
      read
      rmatch
      dup exit? not if
        pop "You may only edit exits." Tell
      else dup location ToEdit @ dbcmp not if
        pop "That exit is not in the current room." tell
      else
        editexit
      then then
    else dup "3" strcmp not if
      pop
      "Please type the exit name you wish to delete.  This can be the full"
      tell
      "name, an alias of the exit, or even a DBREF number starting with #."
      tell
      ToEdit @ 
      read
      rmatch
      dup exit? not if
        pop "You may only edit exits." tell
      else dup location ToEdit @ dbcmp not if
        pop "That exit is not in the current room." tell
      else
        recycle
      then then
    else dup tolower "q" strcmp not if
      pop exit
    else
      "Try again?" tell
    then then then then
  repeat
;
 
: editroom ( d -- ) (* Takes either a room DBREF to edit or #-1 to create a new
                     * room.
                     *)
  dup #-1 dbcmp if
    pop createroom dup room? not if
      (* CreateRoom will return #-1 if the process was aborted.
       * Just exit in that case, the person did not want to continue.
       *)
      exit
    then
  then
 
  (* Make sure they control it *)
  dup me @ swap controls not if
    pop "You do not have permission to edit this room." tell
    exit
  then
 
  (* DBREF on the stack is the one to edit.  Start the editor loop. *)
  var! ToEdit
  
  begin
    "Room Editor: Room Ref #" ToEdit @ intostr strcat 75 tt-tab-init
    "1) Set Room Name: " ToEdit @ name strcat tt-tab-addline-wrap
    "2) View or Set Room Description" tt-tab-addline
    "3) Toggle Obvious Exits List (Currently: "
    ToEdit @ OBVEXITS_PROP getpropstr OBVEXITS_ON strcmp not if
      "ON"
    else "OFF"
    then
    strcat ")" strcat
    tt-tab-addline
    
    (* If you are in #0, this will cause an error, so we will just
     * skip this line in the unlikely event you run this on #0.
     *)
    ToEdit @ location room? if
      "4) Set Parent Room: " ToEdit @ location name strcat tt-tab-addline
      " " tt-tab-addline
    then
 
    "5) Can others set this room as their home? (Currently: "
    ToEdit @ "ABODE" flag? if "YES" else "NO" then strcat ")" strcat
    tt-tab-addline
    "6) Are the contents of the room visible? (Currently: "
    ToEdit @ "DARK" flag? if "NO" else "YES" then strcat ")" strcat
    tt-tab-addline
    "7) Can others link exits to this room? (Currently: "
    ToEdit @ "LINK_OK" flag? if "YES" else "NO" then strcat ")" strcat
    tt-tab-addline
    "8) Can someone else take ownership of this room? (Currently: "
    ToEdit @ "CHOWN_OK" flag? if "YES" else "NO" then strcat ")" strcat
    tt-tab-addline
    " " tt-tab-addline
    "9) Configure Exits in this room" tt-tab-addline
    " " tt-tab-addline
    "C) Create New Room" tt-tab-addline
    me @ location ToEdit @ dbcmp not if
      "T) Teleport to Room" tt-tab-addline
    then
    "L) List all rooms that you own" tt-tab-addline
    "P) Quick-Create New Parent Room" tt-tab-addline
    "Q) Quit the Room Editor" tt-tab-addline
    "<Pick an Option>" tt-tab-final-flush
    read strip tolower
    
    dup "q" strcmp not if
      pop "Exiting!" tell exit
    else dup "t" strcmp not me @ location ToEdit @ dbcmp not and if
      me @ ToEdit @ moveto
      "Teleported!" tell
    else dup "1" strcmp not if
      pop
      "Enter a new name for your room:"
      1 'cb-room-name-query input-loop
      ToEdit @ swap setname
    else dup "2" strcmp not if
      pop
      ToEdit @ set-description
    else dup "3" strcmp not if
      pop
      ToEdit @ OBVEXITS_PROP getpropstr OBVEXITS_ON strcmp not if
        (* Turn it off, cause its on *)
        ToEdit @ OBVEXITS_PROP OBVEXITS_OFF setprop
      else
        ToEdit @ OBVEXITS_PROP OBVEXITS_ON setprop
      then
    else dup "4" strcmp not ToEdit @ location room? and if
      pop
      "Your parent room is currently: " ToEdit @ location name strcat Tell
      "With DB Reference number: #" ToEdit @ location intostr strcat Tell
      " " tell
      "Would you like to change it?  'Y'es or 'N'o."
      1 'cb-yes-no input-loop
  
      .yes? if
        "Enter a DB reference or $ reference for your new parent room:"
        Tell
        read match
        dup room? if
          dup dup me @ swap controls swap "ABODE" flag? or if
            ToEdit @ swap moveto (* Valid parent *)
          else
            pop
            "You do not control that parent room, nor is it set ABODE." tell
            "This means you cannot use it.  Sorry!" tell
          then
        else
          pop "That did not match a room, sorry." tell
        then
      then
    else dup "5" strcmp not if
      pop
      ToEdit @ "ABODE" flag? if
        ToEdit @ "!ABODE" set
      else
        ToEdit @ "ABODE" set
      then
    else dup "6" strcmp not if
      pop
      ToEdit @ "DARK" flag? if
        ToEdit @ "!DARK" set
      else
        ToEdit @ "DARK" set
      then
    else dup "7" strcmp not if
      pop
      ToEdit @ "LINK_OK" flag? if
        ToEdit @ "!LINK_OK" set
      else
        ToEdit @ "LINK_OK" set
      then
    else dup "8" strcmp not if
      pop
      ToEdit @ "CHOWN_OK" flag? if
        ToEdit @ "!CHOWN_OK" set
      else
        ToEdit @ "CHOWN_OK" set
      then
    else dup "9" strcmp not if
      pop ToEdit @ editexits
    else dup "c" strcmp not if
      pop createroom dup room? if
        (* Switch to editing the new room *)
        ToEdit !
      then
    else dup "p" strcmp not if
      pop
      "A parent room is, basically, a room that contains other rooms."
      tell
      "The purpose of doing this is to group rooms together; rooms that"
      tell
      "share a parent room are basically all in the same zone and certain"
      tell
      "programs like LC and WA can take advantage of this." tell
      " " tell
      "This quick-create feature will create a new parent room and then" tell
      "change the currently edited room to use the new parent." tell
      " " tell
      "Note that parent rooms are rarely described or used as functional" tell
      "rooms that you enter.  They are mostly an organizational structure."
      tell
      " " tell
      "Enter a parent room name or type '.abort' to abort." tell
      read
      dup ".abort" strcmp not if
        pop
      else me @ "rooms" CheckQuota not if
        "You do not have enough quota to build a new room." tell
      else me @ "rooms" CheckCost not if
        "You do not have enough "
        "pennies" sysparm strcat " to build a new room." strcat tell
      else
        me @ location findparent swap newroom
        ToEdit @ swap moveto
        
        me @ Exempt? not if
          me @ "rooms" GetCost -1 * addpennies
        then
      then then then
    else dup "l" strcmp not if
      pop
      "You have the following rooms:" tell
      " " tell
      me @ nextowned
      begin
        dup #-1 dbcmp not while
        dup room? if
          dup unparseobj tell
        then
        nextowned
      repeat
      pop
      " " tell
      "You can edit any room you want by taking the DBREF number" tell
      "(the number that starts with #, not including any letters after," tell
      " such as #12345) and running this program as follows:" tell
      " " tell
      command @ " #12345      <-- Replace number with the DBREF" strcat tell
      "<Press any key then enter to continue>" tell
      read pop
    else
      pop "Try again?" tell
    then then then then then then then then then then then then then then
  repeat
;
 
: main ( s -- ) (* Main - mostly just handles command line arguments *)
  (* Not a builder?  Kick 'em out *)
  me @ "BUILDER" flag? not if
    "Only players set with the BUILDER flag may use this program." tell
    exit
  then

  (* Default case, no arguments *)
  dup strlen not if
    pop "Do you want to edit the current room or create a new one?" tell
    "[1] Edit This Room" tell
    "[2] Create New Room" tell
    read
    dup "1" strcmp not if
      pop me @ location editroom
    else "2" strcmp not if
      #-1 editroom
    else
      "I don't know what you want, so exiting." tell
    then then
 
    exit
  then
 
  (* Wants help *)
  dup "#help" strcmp not if
    pop help exit
  then
 
  (* Wants to create *)
  dup dup "#create" strcmp not swap "#new" strcmp not or if
    pop #-1 editroom exit
  then
 
  (* Wants to edit *)
  match dup room? if
    editroom
  else
    pop
    (* Don't know what they want *)
    "Please either provide a room to edit, or #help for more information." tell
  then
;
