@program cmd-kill
1 100000 d
1 i
(*
 * cmd-kill.muf
 *
 * MUF implementation of the FuzzBall 'kill' command that existed until
 * its removal in fb7.  This is generally considered a completely useless
 * command, as it [usually] requires both participants to opt-in and the
 * result is to pay pennies to sweep someone.
 *
 * It is very rare to find anyone opting in to this program, and even
 * more rare to find somone using it to sweep someone else.  RP MUCKs
 * generally have a "real" combat system in place instead.
 *
 * Anyway, this is a MUF implementation for any MUCK that still wants to
 * use this old system.
 *)
 
(* These defines mimic the tune parameters that are now gone.  Feel free
 * to season them to taste -- the defaults are what are used on most MUCKs.
 *)
 
(* TP_RESTRICT_KILL - This requires both participants to have the KILL_OK flag
 * set.
 *)
$def TP_RESTRICT_KILL 1
 
(* The minimum cost to attempt to kill someone *)
$def TP_KILL_MIN_COST 10
 
(* If the player pays this much, they will 100% succeed in the kill. *)
$def TP_KILL_BASE_COST 100
 
(* The player being killed gets this much money as what the messaging
 * refers to as the "insurance policy".  They don't get this money if
 * they already have max_pennies.
 *)
$def TP_KILL_BONUS 50
 
(* END CONFIGURATION *)
 
: help ( -- )
  {
    "  KILL <player> [=<cost>]"
    " "
    "  A successful kill sends the player home, sends all objects in the"
    "player's inventory to their respective homes.  The probability of"
    "killing the player is <cost> percent.  Spending 100 pennies always"
    "works except against Wizards who cannot be killed.  Players cannot"
    "be killed in rooms which have the HAVEN flag set.  On systems where"
    "the KILL_OK flag is used, you cannot kill someone unless both you"
    "and they are set Kill_OK."
  }tell
;
 
: main ( s -- )
  dup strlen not if
    pop help exit
  then
  
  (* Haven check first *)
  me @ location "HAVEN" flag? if
    pop "You can't kill anyone here!" tell exit
  then
  
  TP_RESTRICT_KILL me @ "KILL_OK" flag? not and if
    pop "You have to be set KILL_OK to kill someone." tell exit
  then
  
  (* Parse out cost, if available *)
  dup "=" instring if
    "=" rsplit atoi
  else
    TP_KILL_MIN_COST
  then
  
  var! Cost
  
  (* Only players may be killed. *)
  match dup player? not if
    dup #-2 = if
      pop "I don't know which one you mean." tell exit
    else #-1 = if
      "I don't know who you want to kill." tell
      
      (* This is, technically, not in the original C code.  Also, it is
       * unlikely this line of code will ever be used.  So consider it
       * my personal easter egg.
       *)
      me @ name " looks around with murderous intent." strcat otell
      exit
    else
      "Sorry, you can only kill other players." tell exit
    then then
  then
  
  (* Only wizards may tele-murder *)
  dup location me @ location = me @ "WIZARD" flag? or not if
    pop "I don't see that here." tell exit
  then
  
  dup "KILL_OK" flag? not TP_RESTRICT_KILL and if
    (* It is trivial to parse pronouns, but the original C code didn't
     * do it, so I'm not going to do it either.  It's a faithful recreation,
     * says the guy that put an easter egg in up about 10 lines ago.
     *)
    pop "They don't want to be killed." tell exit
  then
  
  (* Round up to minimum cost -- this is done silently in the C version
   * as well.
   *)
  Cost @ TP_KILL_MIN_COST < if
    TP_KILL_MIN_COST Cost !
  then
  
  (* Make sure they can pay for it. *)
  me @ pennies Cost @ < if
    pop "You don't have enough " "pennies" sysparm "." strcat strcat tell
    exit
  then
  
  (* Pay to play *)
  me @ Cost @ -1 * addpennies
  
  (* Can't kill wizards, ever. *)
  dup "WIZARD" flag? random TP_KILL_BASE_COST % Cost @ >= or if
    "Your murder attempt failed." tell
    me @ name " tried to kill you!" strcat notify
    exit
  then
  
  (* Do messaging *)
  dup "_/dr" getpropstr strlen if
    dup "_/dr" "(Drop)" 1 parseprop tell
  else
    dup name "You killed " swap strcat "!" strcat tell (* You bastard! *)
  then
  
  dup "_/odr" getpropstr strlen if
    dup "_/odr" "(ODrop)" 0 parseprop
    
    (* Prepend name, if needed *)
    dup me @ name stringpfx not if
      me @ name " " strcat swap strcat
    then
    
    otell
  else
    dup name me @ name " killed " strcat swap strcat "!" strcat otell
  then
  
  (* Pay insurance *)
  dup pennies "max_pennies" sysparm atoi < if
    (* Yes, the C code doesn't take into account an insurance policy of
     * 0 or even negative if you really want to be a jerk!
     *)
    dup
    "Your insurance policy pays " TP_KILL_BONUS intostr strcat
    " " strcat "pennies" sysparm strcat "." strcat notify
    dup TP_KILL_BONUS addpennies
  else
    dup "Your insurance policy has been revoked." notify
  then
  
  (* Sweep the player's contents home *)
  me @ contents
  begin
    dup thing? while
    dup #-3 moveto
    next
  repeat
  pop
  
  (* And lastly sweep the player *)
  #-3 moveto
;
.
c
q
