(*
 * @clone command with quota support
 *
 * This overrides the @clone command that comes with FB 7 series MUCKs.
 *
 * @clone appears to only be able to work with objects of type Thing, so
 * this works only with things.
 *
 * HopeIslandCoder 12/30/2018 - Public Domain
 *)
 
$include $lib/quota
 
: help ( -- )
  {
    "@CLONE <object> [=<regname>]"
    " "
    "  Clones the given object, including name, location, flags, and"
    "properties.  You must have control of the object, you may not clone"
    "rooms, exits, etc, and cloning may cost pennies.  If successful, the"
    "command prints the identifier of the new object.  Only a Builder may"
    "use this command."
    " "
    "Example:"
    "  @clone some_object"
  }tell
;
 
: main ( s -- )
  dup dup strlen not swap "#help" strcmp not or if
    pop help exit
  then
  
  me @ "BUILDER" flag? not if
    pop "You aren't a builder." tell exit
  then
  
  (* Check quota first *)
  me @ Exempt? not if
    me @ "things" CheckQuota not if
      pop "You are at or over your limit of objects." tell exit
    then
  
    me @ "things" CheckCost not if
      pop "You don't have enough $pennies." "pennies" sysparm "$pennies" subst
      tell exit
    then
  then
  
  "=" rsplit
  
  swap match dup thing? not if
    pop pop
    "You can only @clone objects." tell exit
  then
  
  dup me @ swap controls not if
    pop pop
    "You can only @clone objects you control." tell exit
  then
  
  copyobj dup
  "Clone of object created with DBREF: #" swap intostr strcat tell
  
  me @ Exempt? not if
    me @ "objects" GetCost -1 * addpennies
  then
  
  (* Do we need to register it? *)
  swap
  dup strlen if
    RegisterObject
  else
    pop pop
  then
;
