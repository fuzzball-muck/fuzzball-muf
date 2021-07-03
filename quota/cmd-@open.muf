(*
 * @open command with quota support
 *
 * This overrides the @open command that comes with the FB 7 series MUCKs.
 *
 * It also adds the popular return-link or backlink feature.
 * It does not support the odd Fuzzball multi-link feature; I am not
 * honestly sure how that is supposed to work, since setlink only allows
 * you to link an exit to one target.
 *
 * HopeIslandCoder 1/11/2019 - Public Domain
 *)
 
$include $lib/quota
 
: help ( -- )
  {
    "@open <exit> [=<dest object> [,<backlink name> [=<regname>]]]"
    " "
    "Opens an exit in the current room, optionally attempting to link it "
    "simultaneously. If a <regname> is specified, then the _reg/<regname> "
    "property on the player is set to the dbref of the new object. This lets "
    "players refer to the object as $<regname> (ie: $mybutton) in @locks, "
    "@sets, etc. Opening an exit costs a penny, and an extra penny to link it, "
    "and you must control the room where it is being opened."
  }tell
;
 
: main ( s -- )
  dup dup strlen not swap "#help" strcmp not or if
    pop help exit
  then
  
  me @ "exits" Eligible? not if
    pop exit
  then
  
  (* Are we allowed to make a link in here? *)
  me @ me @ location controls not if
    "Permission denied." tell exit
  then
  
  (* Set up some variables *)
  "" var! ExitName
  #-1 var! Destination
  "" var! Backlink
  "" var! Register
  
  dup "=" instring if
    "=" split
    
    (* Do we have a regname? *)
    dup "=" instring if
      "=" rsplit
      
      dup ":" instring if
        pop pop "Registration names cannot contain a :" tell exit
      then
      
      Register !
    then
    
    (* Do we have a backlink? *)
    dup "," instring if
      "," split
      
      dup "exit" ext-name-ok? not if
        pop pop "That's a strange name for a back link exit!" tell exit
      then
      
      Backlink !
    then
    
    match dup #-1 = if
      pop pop "That is not a valid link target." tell exit
    else dup #-2 = if
      pop pop "I'm not sure what link target you want to use." tell
      exit
    else dup dup me @ swap controls swap "LINK_OK" flag? or not if
      pop pop "You are not allowed to link to that." tell exit
    then then then
    
    Destination !
  then
  
  dup "exit" ext-name-ok? not if
    pop "That's a strange name for an exit!" tell exit
  then
  
  ExitName !
  
  me @ location ExitName @ newexit
  
  me @ Exempt? not if
    me @ "exits" GetCost -1 * addpennies
  then
  
  dup
  "Exit opened with number #" swap intostr strcat "." strcat tell
  
  Destination @ #-1 != if
    dup Destination @ setlink
    "Linked to " Destination @ unparseobj strcat "." strcat tell
  then
  
  Register @ strlen if
    dup Register @ RegisterObject
  then
  
  (* Do the backlink last in case we don't have enough quota *)
  Backlink @ strlen if
    me @ "exits" Eligible? not if
      pop "Could not create back link." tell exit
    then
  
    me @ Destination @ controls not if
      pop "You do not have permission to make the backlink." tell exit
    then
    
    Destination @ Backlink @ newexit
    
    dup
    "Back-link exit created with number #" swap intostr strcat "." strcat tell
    
    me @ Exempt? not if
      me @ "exits" GetCost -1 * addpennies
    then
    
    me @ location setlink
  then
  
  pop
;
