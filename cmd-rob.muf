@program cmd-rob
1 99999 d
1 i
(*
 * cmd-rob.muf
 *
 * MUF implementation of the FuzzBall 'rob' command that existed until
 * its removal in fb7.  This is generally considered a troublemaker
 * command and of little value to most MUCKs.  However, if you are using
 * it on your MUCK and wish to have 'legacy' rob support, you can install
 * this program for a faithful recreation.
 *)
 
: help ( -- )
  {
    "ROB <player>"
    "  Attempts to steal one penny from <player>. The only thing you can rob"
    "are pennies."
    " "
    "  When you rob someone, you succeed or fail to use them.  You can protect"
    "yourself from being robbed by entering '@lock me=me'. If you lock yourself"
    "to yourself, you can rob yourself and set off your @success and @osuccess"
    "messages."
  }tell
;
 
: main ( s -- )
  dup strlen not if
    pop help exit
  then
  
  (* Only players may be robbed. *)
  match dup player? not if
    dup #-2 = if
      pop "I don't know which one you mean." tell exit
    else #-1 = if
      "I don't know who you want to rob." tell exit
    else
      "Sorry, you can only rob other players." tell exit
    then then
  then
  
  (* Only wizards may tele-rob *)
  dup location me @ location = me @ "WIZARD" flag? or not if
    pop "I don't see that here." tell exit
  then
  
  (* Don't try to bleed a stone *)
  dup pennies 1 < if
    dup name " has no " "pennies" sysparm "." strcat strcat strcat tell
    me @ name " tried to rob you, but you have no " "pennies" sysparm
    " to take." strcat strcat strcat notify
    exit
  then
  
  (* Am I locked against? *)
  dup me @ swap locked? if
    (* Display failure messages - fail and ofail.  If there is no fail
     * message, display a default.
     *)
    dup "_/fl" getpropstr strlen if
      dup "_/fl" "(Fail)" 1 parseprop tell
    else
      "Your conscience tells you not to." tell
    then
    
    dup "_/ofl" getpropstr strlen if
      dup "_/ofl" "(OFail)" 0 parseprop
      
      (* Prepend name if needed *)
      dup me @ name stringpfx not if
        me @ name " " strcat swap strcat
      then
      
      otell
    then
    
    pop exit
  then
  
  (* Qpla! *)
  me @ 1 addpennies
  dup -1 addpennies
  
  (* While it would be nice to put this in a function, the logic for
   * fail vs. success messages is juuuust different enougn to make it
   * annoying.  Sorry for the copy-pasta.
   *)
  dup "_/sc" getpropstr strlen if
    dup "_/sc" "(Succ)" 1 parseprop tell
  then
  
  dup "_/osc" getpropstr strlen if
    dup "_/osc" "(OSucc)" 0 parseprop
    
    (* Prepend name if needed *)
    dup me @ name stringpfx not if
      me @ name " " strcat swap strcat
    then
    
    otell
  then
  
  "You stole a " "penny" sysparm "." strcat strcat tell
  me @ name " stole one of your " "pennies" sysparm "!" strcat strcat strcat
  notify
;
.
c
q
