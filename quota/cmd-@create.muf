(*
 * @create command with quota support
 *
 * This overrides the @create command that comes with FB 7 series MUCKs.
 *
 * It replaces the weird object cost calculation baked into the C code
 * [that doesn't even work right] with a direct calculation that is simply
 * the sysparm object cost + amount to set object value.
 *
 * HopeIslandCoder 1/10/2019 - Public Domain
 *)
 
$include $lib/quota
 
: help ( -- )
  {
    "@CREATE <object> [=<cost>[=<regname>]]"
    "  "
    "  Creates a new object and places it in your inventory.  This costs at"
    "least ten pennies.  If <cost> is specified, you are charged that many"
    "pennies, and in return, the object is endowed with a value according"
    "to the formula: 10 + cost.  Usually the maximum value of an"
    "object is 100 pennies, which would cost 110 pennies to create. If a"
    "<regname> is specified, then the _reg/<regname> property on the player"
    "is set to the dbref of the new object.  This lets players refer to"
    "the object as $<regname> (ie: $mybutton) in @locks, @sets, et cetera."
    "Only a builder may use this command."
    "Also see: @CLONE"
  }tell
;
 
: main ( s -- )
  dup dup strlen not swap "#help" strcmp not or if
    pop help exit
  then
  
  me @ "things" Eligible? not if
    exit
  then
  
  (* Set up some variables to parse the command line into *)
  "" var! ObjectName
  0 var! Cost
  "" var! Registration
  
  (* Do we have cost and/or regname? *)
  dup "=" instring if
    "=" split
    
    (* We have cost, do we have regname? *)
    dup "=" instring if
      "=" split

      (* Would be nice if there was a prop-name validation primitive. *)
      dup ":" instring if
        pop pop "Registration names cannot contain a :" tell exit
      then
 
      Registration !
    then
    
    dup number? not if
      pop pop
      "Cost must be a number." tell exit
    then
    
    atoi Cost !
    
    (* Validate we have enough pennies *)
    me @ Exempt? not me @ pennies Cost @ "things" GetCost + < and if
      pop "You don't have enough $pennies to create this thing."
      "pennies" sysparm "$pennies" subst tell
      exit
    then
  then
  
  dup "thing" ext-name-ok? not if
    pop "That's a strange name for a thing!" tell exit
  then
  
  ObjectName !
  
  me @ ObjectName @ newobject
  
  dup Cost @ addpennies
  
  me @ Exempt? not if
    me @ Cost @ "things" GetCost + -1 * addpennies
  then
  
  dup
  ObjectName @ " created with number #" strcat swap intostr strcat "." strcat
  tell
  
  Registration @ strlen if
    dup Registration @ RegisterObject
  then
  
  pop
;