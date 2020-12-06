(*
 * @chown - Quota Aware Version
 *
 * This is a quota-aware @chown that won't let you take ownership of
 * something if it would violate your quota.
 *
 * HopeIslandCoder - 12/30/2018 - Public Domain
 *)
 
$include $lib/quota
 
: help ( -- )
  {
  "@CHOWN <object> [=<player>]"
  " "
  "  Changes the ownership of <object> to <player>, or if no player is given,"
  "to yourself.  Any player is allowed to take possession of objects, rooms, and"
  "actions, provided the CHOWN_OK flag is set.  Mortals cannot take ownership of"
  "a room unless they are standing in it, and may not take ownership of an object"
  "unless they are holding it.  Wizards have absolute power over all ownership." tell
  "Also see: @CHLOCK"
  }tell
;
 
: main ( s -- )
  dup dup strlen not swap "#help" strcmp not or if
    pop help exit
  then
  
  (* Builders only *)
  me @ "BUILDER" flag? not if
    pop "Permission denied." tell exit
  then
  
  "=" rsplit
  
  dup strlen not if (* Chown to me -- no wizard check needed. *)
    pop me @
  else
    me @ "WIZARD" flag? not if
      pop pop (* Only wizards may chown to other people *)
      "Only wizards may change ownership between players." tell exit
    then
    
    pmatch dup player? not if
      pop pop "That did not match a player." tell exit
    then
  then
  
  swap
  
  (* Object match + error handling *)
  match dup #-1 dbcmp if
    pop pop "We could not find that object." tell exit
  else dup #-2 dbcmp if
    pop pop "That object name is ambiguous.  Try being more specific." tell exit
  else dup #-3 dbcmp if
    pop pop "We could not find that object." tell exit
  then then then
 
  (* Can't chown players *)
  dup player? if
    pop pop "Slavery is generally frowned upon." tell exit
  then
  
  (* If I'm a wizard, no need for further checking *)
  me @ "WIZARD" flag? if
    swap setown "Owner changed." tell exit
  then
  
  (* Otherwise, make sure:
   *
   * - The object is set C
   * - The object is in the same room as the player [or is the current room]
   * - Quota is good
   * - Chown lock passes
   *
   * The stack looks like: [ playerDB objectDB ]
   *)
  
  (* Check CHOWN flag *)
  dup "!CHOWN_OK" flag? if
    pop pop "That object is not set CHOWN_OK." tell exit
  then
  
  (* Check location -- Note we don't check location on exits *)
  dup dup room? swap me @ location dbcmp not and if
    pop pop "You can only @chown the room while you are in it." tell exit
  else dup dup thing? swap location me @ dbcmp not and if
    pop pop "You must be holding an object to @chown it." tell exit
  then then
  
  (* Check Quota *)
  dup room? if
    me @ "rooms" CheckQuota
  else dup thing? if
    me @ "objects" CheckQuota
  else dup exit? if
    me @ "exits" CheckQuota
  else
    (* This is probably a program.  We'll allow it to pass quota *)
    pop 1
  then then then
  
  not if
    pop pop
    "You do not have enough quota to take that object." tell exit
  then
  
  (* Check chown lock *)
  dup "_/chlk" getprop dup lock? if
    me @ swap testlock not if
      pop pop "That object has a chownlock; you cannot take posession." tell
      exit
    then
  else
    pop
  then
  
  (* We can set ownership *)
  swap setown
  
  "Owner changed." tell
;
