(*
 * @action command with quota support
 *
 * This overrides the @action command that comes with FB 7 series MUCKs.
 *
 * It also adds the popular one-step create-and-link feature.
 *
 * HopeIslandCoder 1/9/2019 - Public Domain
 *)
 
$include $lib/quota
 
: help ( -- )
  {
  "@action <name>=<source>[,<destination>] [=<regname>]"
  " "
  "Creates a new action and attaches it to the thing, room, or player specified."
  "If a <regname> is specified, then the _reg/<regname> property on the player is"
  "set to the dbref of the new object. This lets players refer to the object as"
  "$<regname> (ie: $mybutton) in @locks, @sets, etc. You may only attach actions" 
  "you control to things you control. Creating an action costs 1 penny. The"
  "action can then be linked with the command @LINK. "
  }tell
;
 
: main ( s -- )
  dup dup strlen not swap "#help" strcmp not or if
    pop help exit
  then
  
  me @ "exits" Eligible? not if
    exit
  then
  
  (* Set up some simple variables.
   *
   * We're going to do a straight forward linear parsing of the command
   * line and then create it all at the end.
   *)
  "" var! ActionName
  #-1 var! Source
  #-1 var! Destination
  "" var! Register
  
  dup "=" instring not if
    pop "Invalid syntax.  Check " command @ strcat " #help if you need."
    strcat tell exit
  then
  
  "=" split
  swap dup dup strlen not swap "exit" ext-name-ok? not or if
    pop pop "That's a strange name for an action!" tell exit
  then
  
  ActionName !
  
  (* We need to hack the registration bit off the end if we have it *)
  dup "=" instring if
    "=" rsplit
    
    (* Would be nice if there was a prop-name validation primitive. *)
    dup ":" instring if
      pop pop "Registration names cannot contain a :" tell exit
    then
    
    Register !
  then
  
  (* Now see if there's a destination *)
  dup "," instring if
    "," rsplit dup strlen if
      match dup #-1 = if
        pop pop "That is not a valid link target." tell exit
      else dup #-2 = if
        pop pop "I'm not sure what link target you want to use." tell exit
      else dup dup me @ swap controls swap "LINK_OK" flag? or not if
        pop pop "You are not allowed to link to that." tell exit
      then then then
      
      Destination !
    else
      pop
    then
  then
  
  (* Validate the source *)
  dup strlen not if
    pop "You must specify an action name and a source object." tell exit
  then
  
  match dup #-1 = if
    pop "That is not a valid source object name." tell exit
  else dup #-2 = if
    pop "I'm not sure which source object you mean." tell exit
  else dup exit? if
    pop "You can't attach an action to an action." tell exit
  else dup me @ swap controls not if
    pop "Permission denied. (you don't control the attachment point)" tell
    exit
  then then then then
  
  Source !
  
  (* Everything checks out ... let's do it all.
   *
   * Don't forget to deduct the pennies!
   *)
  Source @ ActionName @ newexit
  
  dup "Action created with number #" swap intostr strcat " and attached."
  strcat tell
  
  me @ Exempt? not if
    me @ "exits" GetCost -1 * addpennies
  then
  
  Destination @ #-1 != if
    dup Destination @ setlink
    "And linked to " Destination @ unparseobj strcat "." strcat tell
  then
  
  Register @ strlen if
    dup Register @ RegisterObject
  then
  
  pop
;