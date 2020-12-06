  
( cmd-@quota    v1.1    Jessy @ FurryMUCK    3/00
  
  Modified / Updated by HopeIslandCoder
  
  Cmd-@quota provides quota management for lib-quota and the emultated
  building commands that accompany it. It may also be used for quota
  management with the standard cmd-quota used on FurryMUCK and elsewhere.
  
  INSTALLATION:
  
  Port cmd-@quota and set it Wizard. Link a global action named '@quota'
  to it. Cmd-@quota requires lib-quota, which should be available on the
  MUCK or website where you obtained this program.
  
  USAGE:
   
    @quota ........................ Show your quota and ownership totals
    @quota global ................. Show global quota settings
    @quota global=<type>:<num> .... Set global quota for <type>
    @quota global=<type>: ......... Clear global quota for <type>
    @quota <player> ............... Show <player's> quota and ownership
    @quota <player>=<type>:<num> .. Set <player's> quota for <type>
    @quota <player>=<type>: ....... Clear <player's> quota for <type>
    @quota #exempt <player> ....... Exempt player from quota checks
    @quota #!exempt <player> ...... Remove <player's> exempt status
  
  To explictly set a player quota to 'unlimited', use -1 for <num>. This
  differes from simply clearing the player's quota in that the explicit
  'unlimited' setting will override global quotas.
  
  All forms except for the '@quota' typed without arguments are wiz-only.
)
 
lvar ourLimit 
lvar ourObject
lvar ourString
lvar ourType
 
(2345678901234567890123456789012345678901234567890123456789012345678901)
 
$include $lib/quota
$include $lib/reflist
 
$define NukeStack begin depth while pop repeat $enddef
  
: DoHelp  (  --  )                                (* show help screen *)
  {
    "Provides quota info and management utilities."
    " "
    "Player Options:"
    " "
    "  @quota ........................ Show your quota and ownership totals"
    " "
    "Wizard Options:"
    " "
    "  @quota global ................. Show global quota settings"
    "  @quota global=<type>:<num> .... Set global quota for <type>"
    "  @quota global=<type>: ......... Clear global quota for <type>"
    "  @quota <player> ............... Show <player's> quota and ownership"
    "  @quota <player>=<type>:<num> .. Set <player's> quota for <type>"
    "  @quota <player>=<type>: ....... Clear <player's> quota for <type>"
    "  @quota #exempt <player> ....... Exempt player from quota checks"
    "  @quota #!exempt <player> ...... Remove <player's> exempt status"
    " "
    "To explcitly set a player quota to 'unlimited', use -1 for <num>. "
    "This differs from simply clearing the player's quota in that "
    "an explicit 'unlimited' setting will override global quota limits."
    strcat strcat
  }tell
;
 
: DoPad  ( s i -- s' )              (* pad s to i chars, spaces right *)
  
  swap
  "                                                                   "
  strcat swap strcut pop
;  
 
: DoLeftPad  ( s i -- s' )           (* pad s to i chars, spaces left *)
  
  swap
  "                                                                   "
  swap strcat dup strlen rot - strcut swap pop
;
 
: DoExempt  (  --  )            (* exempt ourObject from quota checks *)
  
  me @ "W" flag? if
    ourObject @ pmatch
    dup #-1 dbcmp if
      "Player not found." Tell pop exit
    then
    dup #-2 dbcmp if
      "Ambiguous. I don't know who you mean!" Tell pop exit
    then
    #0 "@quota/exempt" 3 pick REF-add
    name " is now exempt from quota limits." strcat Tell
  else
    "Permission denied." Tell
  then
;
 
: DoNotExempt  (  --  )            (* remove ourObject's exempt status *)
  
  me @ "W" flag? if
    ourObject @ pmatch
    dup #-1 dbcmp if
      "Player not found." Tell pop exit
    then
    dup #-2 dbcmp if
      "Ambiguous. I don't know who you mean!" Tell pop exit
    then
    #0 "@quota/exempt" 3 pick REF-delete
    name " is now subject to quota limits." strcat Tell
  else
    "Permission denied." Tell
  then
;
 
: DoSetQuota (  --  )(* set ourObject's quota for ourType to ourLimit *)
  
  me @ "W" flag? not if "Permission denied." Tell exit then
                                   (* check syntax; continue if valid *)
  ourObject @ ourType @ and if
    ourObject @ "global" strcmp not       (* check: setting global quota? *)
    ourObject @ "#0"     strcmp not or if
      #0 ourObject !
    else
      ourObject @ pmatch     (* if not, find player to set quota for *)
      dup #-1 dbcmp if
        "Player not found." Tell pop exit
      then
      dup #-2 dbcmp if
        "Ambiguous. I don't know who you mean!" Tell pop exit
      then
      ourObject !
    then                                           (* get object type *)
    "rooms" ourType @ stringpfx if
      "rooms" ourType !
    else
    "exits" ourType @ stringpfx if
      "exits" ourType !
    else
    "actions" ourType @ stringpfx if
      "exits" ourType !
    else
    "things"  ourType @ stringpfx if
      "things" ourType !
    else
    "programs" ourType @ stringpfx if
      "programs" ourType !
    else                          (* notify if object type is invalid *)
      "Object type must be 'rooms', 'exits', 'things', or 'programs'." 
      "Type not found." 
      Tell Tell exit
    then then then then then
  
                                            (* check: limit entry ok? *)
    ourLimit @ if
      ourLimit @ number? not if
        "Sorry, the quota limit must be a number." Tell exit
      then
    else
      "" ourLimit !
    then
                                                (* make quota setting *)
    ourObject @ "@quota/" ourType @ strcat ourLimit @ setprop
     
                                 (* notify in global or player format *)
    ourLimit @ if
      ourLimit @ atoi 0 >= if
        ourObject @ #0 dbcmp if
          "Global $type limit set to $limit." 
        else
          "$name's quota limit for $type set to $limit."
        then
        ourType @        "$type"  subst
        ourLimit @       "$limit" subst
        ourObject @ name "$name"  subst Tell
      else
        ourObject @ #0 dbcmp if
          "Global $type limit set to 'unlimited'."
        else
          "$name's quota limit for $type set to 'unlimited'."
        then
        ourType @        "$type"  subst
        ourObject @ name "$name"  subst Tell
      then
    else
      ourObject @ #0 dbcmp if
        "Global $type limit cleared."
      else
        "$name's quota limit for $type cleared."
      then
      ourType @        "$type"  subst
      ourObject @ name "$name"  subst Tell
    then
  else
                     (* .... or, give usage not if syntax was invalid *)
    "Usage:   $command <player>=<object type>:<quota limit>"
    command @ "$command" subst Tell
    "Example: $command $name=rooms:5"
    command @ "$command" subst 
    me @ name "$name"    subst Tell
  then
;
  
: DoGlobalRoomQuota  (  -- s )            (* return global room quota *)
 
  ourObject @ if
    ourObject @ dbref? if
      ourObject @ Exempt? if
        "    ---" exit
      then
    then
  then
  #0 "@quota/rooms" getpropstr
  dup if
    dup atoi 0 < if
      pop "---"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
;
 
: DoGlobalExitQuota  (  -- s )            (* return global exit quota *)
 
  ourObject @ if
    ourObject @ dbref? if
      ourObject @ Exempt? if
        "    ---" exit
      then
    then
  then
  #0 "@quota/exits" getpropstr
  dup if
    dup atoi 0 < if
      pop "---"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
;
  
: DoGlobalThingQuota  (  -- s )         (* return global thing quota *)
 
  ourObject @ if
    ourObject @ dbref? if
      ourObject @ Exempt? if
        "    ---" exit
      then
    then
  then
  #0 "@quota/things" getpropstr
  dup if
    dup atoi 0 < if
      pop "---"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
;
  
: DoGlobalProgramQuota  (  -- s )      (* return global program quota *)
 
  ourObject @ if
    ourObject @ dbref? if
      ourObject @ Exempt? if
        "    ---" exit
      then
    then
  then
  #0 "@quota/programs" getpropstr
  dup if
    dup atoi 0 < if
      pop "unlimited"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
; 
  
: DoPlayerRoomQuota  (  -- s )       (* return ourObject's room quota *)
 
  ourObject @ Exempt? if " ---" exit then
  ourObject @ "@quota/rooms" getpropstr
  dup if
    dup atoi 0 < if
      pop "---"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
;
 
: DoPlayerExitQuota  (  -- s )       (* return ourObject's exit quota *)
 
  ourObject @ Exempt? if " ---" exit then
  ourObject @ "@quota/exits" getpropstr
  dup if
    dup atoi 0 < if
      pop "---"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
;
  
: DoPlayerThingQuota   (  -- s )    (* return ourObject's thing quota *)
 
  ourObject @ Exempt? if " ---" exit then
  ourObject @ "@quota/things" getpropstr
  dup if
    dup atoi 0 < if
      pop "---"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
;
  
: DoPlayerProgramQuota  (  -- s ) (* return ourObject's program quota *)
                             (* included in display, but not enforced *)
 
  ourObject @ Exempt? if " ---" exit then
  ourObject @ "@quota/programs" getpropstr
  dup if
    dup atoi 0 < if
      pop "unlimited"
    then  
  else
    pop "---"
  then
  7 DoLeftPad
; 
 
: DoShowGlobalQuota  (  --  )           (* show global quota settings *)
  
  " " Tell "Global Quota Settings:" Tell " " Tell
  
  "Rooms:    " DoGlobalRoomQuota    strcat Tell
  "Exits:    " DoGlobalExitQuota    strcat Tell
  "Things:   " DoGlobalThingQuota   strcat Tell
  "Programs: " DoGlobalProgramQuota strcat Tell
;
 
: DoShowPlayerQuota  (  --  )  
              (* show ourObject's quota settings and ownership totals *)
  
  ourObject @ .pmatch                (* find player; check permission *)
  dup #-1 dbcmp if
    "Player not found." Tell pop exit
  then
  dup me @ dbcmp not
  me @ "W" flag? not and if
    "Permission denied." Tell pop exit
  then
  dup #-2 dbcmp if
    "Ambiguous. I don't know who you mean!" Tell pop exit
  then
  ourObject !
   
                           (* format and display quota/ownership info *)
  " " Tell "Quota Settings for $name:" 
  ourObject @ name "$name" subst Tell " " Tell
  
  "            Quota         Owned" Tell
  "Rooms:    $quota          $owned"
  ourObject @ "@quota/rooms" getpropstr if
    DoPlayerRoomQuota
  else
    DoGlobalRoomQuota
  then
  "$quota" subst
  ourObject @ RoomsOwned intostr 4 DoLeftPad "$owned" subst Tell
   
  "Exits:    $quota          $owned"
  ourObject @ "@quota/exits" getpropstr if
    DoPlayerExitQuota
  else
    DoGlobalExitQuota
  then
  "$quota" subst
  ourObject @ ExitsOwned intostr 4 DoLeftPad "$owned" subst Tell
   
  "Things:   $quota          $owned"
  ourObject @ "@quota/things" getpropstr if
    DoPlayerThingQuota
  else
    DoGlobalThingQuota
  then
  "$quota" subst
  ourObject @ ThingsOwned intostr 4 DoLeftPad "$owned" subst Tell
   
  "Programs: $quota          $owned"
  ourObject @ "@quota/programs" getpropstr if
    DoPlayerProgramQuota
  else
    DoGlobalProgramQuota
  then
  "$quota" subst
  ourObject @ ProgramsOwned intostr 4 DoLeftPad "$owned" subst Tell
;
 
: DoShowMyQuota  (  --  )   (* show user's quota and ownership totals *)
  
  "me" ourObject ! DoShowPlayerQuota
;
 
: DoShowQuota  (  --  )      (* route to appropriate display function *)
  
  ourObject @ if
    ourObject @ "global" smatch
    ourObject @ "#0"     smatch or if
      DoShowGlobalQuota
    else
      DoShowPlayerQuota
    then
  else
    DoShowMyQuota
  then
;
 
: main
  
  dup if
    ourString !
    ourString @ ":" rinstr if
      ourString @ dup ":" rinstr strcut strip ourLimit !
      dup strlen 1 - strcut pop strip ourString !
    then
    ourString @ "=" rinstr if
      ourString @ dup "=" rinstr strcut strip ourType !
      dup strlen 1 - strcut pop strip ourString !
    then
    ourString @ " " rinstr if
      ourString @ dup " " rinstr strcut strip ourObject !
      dup strlen 1 - strcut pop strip ourString !
    else
      ourString @ ourObject !
    then
    "#help"    ourString @ stringpfx if DoHelp      exit then
    "#exempt"  ourString @ stringpfx if DoExempt    exit then
    "#!exempt" ourString @ stringpfx if DoNotExempt exit then
    ourType @ if
      DoSetQuota
    else
      DoShowQuota
    then
  else
    DoShowQuota
  then
;
