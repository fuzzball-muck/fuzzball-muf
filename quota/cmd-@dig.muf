(*
 * @dig command with quota support
 *
 * This overrides the @dig command that comes with FB 7 series MUCKs.
 *
 * HopeIslandCoder 1/11/2019 - Public Domain
 *)
 
$include $lib/quota
$include $lib/findparent
 
: help ( -- )
  {
    "@DIG <room> [=<parent> [=<regname>]]"
    " "
    "  Creates a new room, sets its parent, and gives it a personal registered"
    "name.  If no parent is given, it defaults to the first ABODE room down the"
    "environment tree from the current room.  If it fails to find one, it sets"
    "the parent to the global environment, which is typically room #0.  If no"
    "<regname> is given, then it doesn't register the object.  If one is given,"
    "then the object's dbref is recorded in the player's _reg/<regname> property,"
    "so that they can refer to the object later as $<regname>.  Digging a room"
    "costs 10 pennies, and you must be able to link to the parent room if"
    "specified.  Only a builder may use this command."
  }tell
;
 
: main ( s -- )
  dup dup strlen not swap "#help" strcmp not or if
    pop help exit
  then
  
  me @ "rooms" Eligible? not if
    pop exit
  then
  
  (* Set up some variables to parse command line into *)
  "" var! RoomName
  #-1 var! Parent
  "" var! Register
  
  (* Start parsing our command line. Split off parent and/or register *)
  dup "=" instring if
    "=" split
    
    dup "=" instring if
      "=" split
      
      (* Since we don't have a prop-name validation primitive ... *)
      dup ":" instring if
        pop pop "Registration names cannot contain a :" tell exit
      then
      
      Register !
    then
    
    match dup #-1 = if
      pop pop "I could not find the parent room you wish to use." tell exit
    else dup #-2 = if
      pop pop "I don't know which parent room you wish to use." tell exit
    else dup room? not if
      pop pop "The parent room must be a room." tell exit
    else dup dup me @ swap controls swap "ABODE" flag? or not if
      pop pop "You do not have permission to use that parent room." tell exit
    then then then then
    
    Parent !
  else
    (* If parent wasn't provided, we need to look it up *)
    me @ location findparent Parent !
  then
  
  dup "room" ext-name-ok? not if
    pop "That's a strange name for a room!" tell exit
  then
  
  RoomName !
  
  (* Create the room *)
  Parent @ RoomName @ newroom
  
  (* Deduct money *)
  me @ Exempt? not if
    me @ "rooms" GetCost -1 * addpennies
  then
  
  (* Display messages *)
  dup
  RoomName @ " created with room number #" strcat swap intostr strcat "." strcat
  tell
  dup
  "Parent set to " swap location unparseobj strcat "." strcat tell
  
  Register @ strlen if
    dup Register @ RegisterObject
  then
  
  pop
;
