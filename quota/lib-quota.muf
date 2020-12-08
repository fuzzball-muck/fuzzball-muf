( lib-quota    v1.1    Jessy @ FurryMUCK    3/00
  
  Modified by HopeIslandCoder - made the code leaner, added GetCost function,
  made costs based on sysparm instead of hard coded.
  
  Lib-quota is the library for a set of soft-coded building commands:
  cmd-@quota cmd-@action, cmd-@open, cmd-@create, cmd-@dig, and 
  cmd-@xdig. It is backwards compatible with the standard quota program
  used on FurryMUCK and elsewhere, but is -- in my opinion at least -- 
  easier to set up and administer and differs in design philosophy.
  Instead of one large do-everything program, softcoded emulations of
  the standard building commands are provided, each sharing code from
  lib-quota and incorporating quota control. Although this approach 
  leads to some duplication of code and uses a few more dbrefs, I
  believe that this separation pays off in ease-of-use and administrative
  flexibility.
 
 
  INSTALLATION:
  
  Port lib-quota. Set it Link_OK and Wizard. Register it as $lib/quota.
  Set the _def/ and _docs props, as follows:
   
@reg lib-quota=lib/quota
@set lib-quota=L
@set lib-quota=W
@set lib-quota=_docs:@list $lib/quota=1-93
  
  Lib-quota requires lib-reflist, which should be installed on any
  established MUCK.
  
  Once lib-quota is installed, the emulated building commands -- 
  cmd-@dig, cmd-@open, cmd-@action, and cmd-@create -- as well as the
  non-standard cmd-@xdig and quota management program, cmd-@quota, may
  be installed.
  
 
  PUBLIC FUNCTIONS:
  
  CheckCost  [ d s -- i ]  Returns true if d has enough pennies for object 
    of type s. Because @create allows custom costs, and because programs
    have no cost, the only valid values for s are 'room' and 'exit'.
  
  CheckName  [ s -- i ]  Returns true if s is a valid object name.
  
  CheckQuota  [ d s -- i ]  Returns true if user d has additional quota
    available for an object of type s, where is is 'rooms', 'exits',
    'things', or 'programs'.
  
  Exempt?  [ d -- i ]  Returns true if user d is exempt from quota checks,
    either because she is a non-quelled Wizard, or has been added to
    the exempt list via cmd-@quota.
  
  ExitsAllowed  [ d -- i ]  Returns the number of exits d can make.
   
  ExitsOwned  [ d -- i ]  Returns the number of exits owned by d.
  
  GetQuota  [ d s -- i ]  Returns d's quota for objects of type s. If
    quota for type s is unlimited, i will be -1.
  
  ProgramsOwned  [ d -- i ]  Returns the number of programs owned by d.
  
  RegisterObject  [ d s --  ]  Sets personal regname s for object d.
  
  RoomsAllowed  [ d -- i ]  Returns the number of rooms d can make.
  
  RoomsOwned  [ d -- i ]  Returns the number of rooms owned by d.
  
  ThingsAllowed  [ d -- i ]  Returns the number of things d can make.
  
  ThingsOwned  [ d -- i ]  Returns the number of things owned by d.
  
  GetCost [ s -- i ] Returns cost of object type s
  
  Eligible? [ d s -- i ] Returns if d is eligible to create an object of type s
                         Eligible means, has a BUILDER bit and player has
                         enough pennies and quota.  Error messages are
                         displayed as appropriate.
  
  All public functions must be called from a program set M3 or W. 
  Although program-related functions such as ProgramsOwned are provided
  here and in cmd-@quota, the programs in their current state do not
  restrict the number of programs a user can own or create.
  
  Lib-quota may be freely ported. Please comment any changes.
)
 
(2345678901234567890123456789012345678901234567890123456789012345678901)
 
$include $lib/reflist
 
: CheckMuckerPerm  (  --  )       (* kill process if not called by M3 *)
 
  caller mlevel 3 < if 
    pop me @ "Permission denied." notify pid kill 
  then
;
  
: Exempt?  ( d -- i ) (* return true if d is exempt from quota checks *)
  
  CheckMuckerPerm 
  dup "W" flag? 
  #0 "@quota/include_wizzes" getprop not and
  #0 "@quota/exempt" 4 rotate REF-inlist? or
;
public Exempt?
$libdef Exempt?
 
: ExitsOwned  ( d -- i )         (* return number of exits owned by d *)
  
  CheckMuckerPerm
  dup ok? not if pop 0 then
  dup player? if
    stats pop pop pop pop swap pop swap pop
  else
    pop 0
  then
;
public ExitsOwned
$libdef ExitsOwned
 
: ProgramsOwned  ( d -- i )      (* return number of rooms owned by d *)
  
  CheckMuckerPerm
  dup ok? not if pop 0 then
  dup player? if
    stats pop pop swap pop swap pop swap pop swap pop
  else
    pop 0
  then
;
public ProgramsOwned
$libdef ProgramsOwned
 
: RoomsOwned  ( d -- i )         (* return number of rooms owned by d *)
  
  CheckMuckerPerm
  dup ok? not if pop 0 then
  dup player? if
    stats pop pop pop pop pop swap pop
  else
    pop 0
  then
;
public RoomsOwned
$libdef RoomsOwned
 
: ThingsOwned  ( d -- i )        (* return number of rooms owned by d *)
  
  CheckMuckerPerm
  dup ok? not if pop 0 then
  dup player? if
    stats pop pop pop swap pop swap pop swap pop
  else
    pop 0
  then
;
public ThingsOwned
$libdef ThingsOwned
 
: GetQuota  ( d s -- i )               (* return d's quota for type s *)
                          (* return -1 if quota for type is unlimited
                           * Types are plural: rooms, things, exits, programs
                           *)

  CheckMuckerPerm
  
  over "@quota/" 3 pick strcat getpropstr dup if
    swap pop 
  else
    pop 
    #0 "@quota/" 3 pick strcat getpropstr
  then
  
  dup if
    swap pop atoi
  else
    pop pop -1
  then
;
public GetQuota
$libdef GetQuota
 
: ExitsAllowed  ( d -- i )       (* return number of exits d may make *)
  
  dup "exits" GetQuota swap ExitsOwned -
  dup 0 < if pop 0 then
;
public ExitsAllowed
$libdef ExitsAllowed
 
: RoomsAllowed  ( d -- i )       (* return number of rooms d may make *)
  
  dup "rooms" GetQuota swap RoomsOwned -
  dup 0 < if pop 0 then
;
public RoomsAllowed
$libdef RoomsAllowd
 
: ThingsAllowed  ( d -- i )     (* return number of things d may make *)
  
  dup "things" GetQuota swap ThingsOwned -
  dup 0 < if pop 0 then
;
public ThingsAllowed
$libdef ThingsAllowed
 
: CheckQuota  ( d s -- i )  
     (* return true if user has additional quota for type s available
      * This can be 'rooms', 'exits', or 'things'
      *)
  
  over Exempt? if
    pop pop 1 exit
  then
   
  dup "rooms" strcmp not if
    pop RoomsAllowed
  else dup "exits" strcmp not if
    pop ExitsAllowed
  else
    pop ThingsAllowed 
  then then
 
  dup 0 < if
    pop 0
  then
;
public CheckQuota
$libdef CheckQuota
 
: CheckName  ( s -- i )    (*
                            * This is for backwards compatibility.
                            * Use the primitive ext-name-ok? instead.
                            * return true if s is a valid object name
                            *)
  
  dup "#"    stringpfx if pop 0 exit then
  dup "="    instr     if pop 0 exit then
  dup "&"    instr     if pop 0 exit then
  dup "here" smatch    if pop 0 exit then
  dup "me"   smatch    if pop 0 exit then
  dup "home" smatch    if pop 0 exit then
  pop 1
;
public CheckName
$libdef CheckName
  
: RegisterObject  ( d s --   )          (* set personal regname for d *)
  
  me @ "_reg/" 3 pick strcat getprop dup if
    "Used to be registered as $prop: $object"
    swap unparseobj "$object" subst
    over "$prop" subst me @ swap notify
  else
    pop
  then
  
  me @ "_reg/" 3 pick strcat 4 pick setprop
  "Now registered as $prop: $object"
  swap "$prop" subst
  swap unparseobj "$object" subst me @ swap notify
;
public RegisterObject
$libdef RegisterObject
 
: GetCost ( s -- i ) (* Gets a cost in pennies for a given type *)
  dup "room" 4 strncmp not if
    pop "room_cost" sysparm atoi exit
  then
 
  dup dup "object" 6 strncmp not swap "thing" 5 strncmp not or if
    pop "object_cost" sysparm atoi exit
  then
 
  dup "exit" 4 strncmp not if
    pop "exit_cost" sysparm atoi exit
  then
  
  "Unknown object type for GetCost: " swap strcat abort
;
public GetCost
$libdef GetCost
 
: CheckCost  ( d s -- i ) 
          (* return true if d has enough pennies for object of type s
           * s can be exits, objects, things, or rooms
           *
           * Objects and things are the same thing -- I tend to forget
           * 'things' so this supports both.
           *)
  
  over Exempt? if
    pop pop 1 exit
  then
  
  GetCost swap pennies <=
;
public CheckCost
$libdef CheckCost
 
: Eligible? ( d s -- i ) (* Returns true if d is eligible to create something
                          * of type s.  It expects s to be 'things', 'exits',
                          * or 'rooms'
                          *)
  swap dup "BUILDER" flag? not if
    pop pop "This command is just for builders." tell 0 exit
  then
  
  dup Exempt? not if
    swap
    2 dupn CheckCost not if
      dup strlen 1 swap 1 - midstr (* Cut the s off the end *)
      "You don't have enough $pennies to create this " swap strcat "." strcat
      "pennies" sysparm "$pennies" subst tell
      pop 0 exit
    else 2 dupn CheckQuota not if
      dup strlen 1 swap 1 - midstr (* Cut the s off the end *)
      "You do not have enough quota to create this " swap strcat "." strcat
      tell pop 0 exit
    then then
  then
  
  pop pop
  1
;
public Eligible?
$libdef Eligible?