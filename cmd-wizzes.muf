(* cmd-wizzes.muf
 * Staff listing program
 * Just link an action to it and use #help for instructions
 *
 * By Cohote at Hope Island MUCK - Public Domain
 *)
 
$include $lib/tabtoolkit
 
: help
  {
    "========================================================================="
    "General Usage:"
    command @ "                  - List folks that will help you." strcat
    "-------------------------------------------------------------------------"
    "Staff Member Commands:"
    command @ " #onduty          - Go on-duty!" strcat
    command @ " #offduty         - Clock out." strcat
    command @ " #skills <skills> - Set your skills!" strcat
    "-------------------------------------------------------------------------"
    "Boss/Admin Commands:"
    command @ " #add <player>    - Add a new Staff Member." strcat
    command @ " #remove          - Remove a Staff Member." strcat
    "========================================================================="
  }tell
;
 
( This checks that the calling user is allowed to do admin funcs on this. )
: is-admin? ( -- b )
  ( Get the user's DB )
  me @
  ( See if the user is a wizard. )
  "w" flag?
  ( Get this MUF's owner's DB. )
  trigger @ owner
  ( Get this user's DB. )
  me @
  ( Compare the DB ref's )
  dbcmp
  ( Now compare the two cases.) 
  or
;
 
( Puts the DBRef and Prop onto the stack. )
: make-stafflist ( -- d1 s1 )
  trigger @ "/_staff/minimumwage"
;
 
( This will get the staff list and put it on the stack, ready for a reflist_* command. )
: get-stafflist-forref ( d2 -- d1 s1 d2 )  
  make-stafflist
  rot (d1 s1 d2)
;
 
( This checks to see if the calling player is a staff-member or not. )
: is-staff ( -- b )
  ( Get the user's DB )
  me @ ( d )
  ( Get the reflist, and then pop it all and see if the user's on the list. )
  get-stafflist-forref reflist_find
  ( Make sure the number's over 0. )
  0 >
;
 
( Adds a user to the staff list. )
: add-user ( s -- )
  ( Duplicate the string, convert the name into a dbref, and then see if that's a player. )
  dup pmatch dup player? if ( Found a player. Add them to the list. )
    swap pop ( Remove user's input. )
    dup name swap ( Read the top-most DBref# and get the name. )
    ( Put the object, prop, and person to add onto the stack, and add it to the list. )
    get-stafflist-forref reflist_add
    "Congrats on making " swap strcat " an employee! Now put them to work!" strcat tell
  else
    pop
    ( No player. Let them know. )
    "Could not find player by the name of '" strcat "'." strcat tell
  then
;
 
( Removes a user from the staff list. )
: remove-user ( s -- )
  ( Duplicate the string, convert the name into a dbref, and then see if that's a player. )
  dup pmatch dup player? if ( Found a player. Take them off the list. )
    swap pop ( Remove user's input. )
    dup name swap ( Read the top-most DBref# and get the name. )
    ( Put the object, prop, and person to add onto the stack, and remove it from the list. )
    get-stafflist-forref reflist_del
    "Sorry to hear you let " swap strcat " go!" strcat tell
  else
    pop
    ( No player. Let them know. )
    "Could not find player by the name of '" strcat "'. Are you sure they work for you?" strcat tell
  then
;
 
( Outputs the header to the user. Does no stack changes. )
: display-header ( -- )
  ( Put the DB# of this up, and the prop name, and then load up the list onto the stack. )
  trigger @ "header" array_get_proplist
  
  ( Show the default? )
  dup array_count not if
    {
      "                   Staff"
    }tell
  else
    ( Now loop through the list, outputting it. )
    foreach
      tell pop ( Output the line, and then drop the index off the stack. )
    repeat
  then
;
 
( Outputs the footer to the user. Does no stack changes. )
: display-footer ( -- )
  ( Put the DB# of this up, and the prop name, and then load up the list onto the stack. )
  trigger @ "footer" array_get_proplist
  ( Now loop through the list, outputting it. )
  foreach
    tell pop ( Output the line, and then drop the index off the stack. )
  repeat
;
 
( Adds a string to the stak that contains our root storage prop. )
: get-storage-prop ( -- s )
  "_staff/#" trigger @ intostr strcat "/" strcat
;
 
( Displays the list of staff! )
: display ( -- )
  (First, display the header.)
  display-header
  (Now, the contents!)
  (Get the reflist into an array on the stack.)
  make-stafflist array_get_reflist
  
  dup array_count not if
    pop "> No staff yet!" tell exit
  then
  
  "Name                 Status    Specialties" tell
  
  (Loop through each person. )
  foreach ([index dbref])
    (Duplicate the DBRef, get the name from it.)
    dup name
    (Trim the name, contatenate two spaces, and then output it.)
    19 tt-shave-to-len "  " strcat
    (Duplicate the DBref again, see if they're awake.)
    swap dup awake? if ([index string1 dbref])
      (We need to see if they're on duty. Generate our prop first..)
      dup get-storage-prop "offduty?" strcat
      getpropstr tolower
      (Compare if they're off duty.)
      "yes" strcmp not if
        ( Put the label on. )
        "Off Duty" 
      else
        "On Duty"
      then
    else
      (Just say they're napping!)
      "Sleeping"
    then
 
    (By here, we have [index string1 dbref string2] we need to: Do a little dance..)
    swap -rot  ([index string1 string2 dbref] ... [index dbref string1 string2])
    (Add our padding, and trim it, then cat the two strings.)
    8 tt-shave-to-len strcat 
    (Put our dbref back on top. So now we're back to: [index string1 dbref]) 
    swap
 
    (Now, to get their specialities.)
    dup get-storage-prop "skills" strcat
    (Get the propr string, add two spaces for padding.)
    getpropstr "  " swap strcat
    (.. Get down tonight!)
    swap -rot
    (Add the strings together, format it to 78 degrees.)
    strcat 78 tt-shave-to-len
    (Output it to player.)
    tell
 
    (Get rid of the unused items. The dbref should likey be gotten rid of above by NOT 'dup'ing it.)
    pop pop
  repeat
  ( And finally, a little foot-work here. )
  display-footer  
;
 
( Saves a prop on the player for a string of the player's object. )
: set-skills ( s -- )
  ( First make sure the player is a staff member.. )
  is-staff if
    ( Check if the string is null. )
    strip dup if ( Duplicate the string and then see if it's null. )
      ( Set the proper skillset. )
      me @ get-storage-prop "skills" strcat ( [ skilllist dbref prop ] )
      rot setprop ( Rotate so the skilllist is last, and then set the prop. )
      "Skills added!" tell
    else
      ( It's not null. Unset the prop. )
      me @ get-storage-prop "skills" strcat remove_prop
      pop ( remove the unneeded null. )
      "Skillset removed!" tell
    then
  else
      "We all know you don't have any useable skills, now." tell
  then   
;
 
( Take the truthfullness of the top item on the stack, and set's player's on-duty status. )
: set-duty-status ( x -- ) 
  if
    ( Since the prop is for OFF duty, we simply remove the property if they're ON duty. )
    me @ get-storage-prop "offduty?" strcat remove_prop
  else
    me @ get-storage-prop "offduty?" strcat "yes" setprop
  then
;
 
( The main function! )
: main ( s -- )
  ( Go through our options.. )
 
  ( #add - adds a staff member. )
  dup "#add " 5 strncmp not if
    is-admin? if
      " " split swap pop ( Get just the name.. )
      ( Call the 'add' function. )
      add-user
    else
      "Sadly, your soul has not been accepted by the devil yet. You can not do that." tell
    then
    exit
  then
 
  ( #remove - removes a staff member )
  dup "#remove " 8 strncmp not if
    is-admin? if
      " " split swap pop ( And, get just the name.. )
      ( Call the 'remove' function. )
      remove-user
    else
      "Sadly, your soul has not been accepted by the devil yet. You can not do that." tell
    then
    exit
  then
 
  ( #skills - sets a short skills message: 'Building, Char Development, and Pizza!' )
  dup "#skills " 8 strncmp not if
    " " split swap pop ( Now we ONLY have the message in the stack. Or null if they wanna clear it. )
    set-skills
    exit
  then
 
  ( #on & #onduty - Sets someone in the list "on duty")
  ( TODO: Allow a wiz to pass the name of someone on the list to 'force' them? )
  dup "#on" strcmp not if ( [s s s] -> [s] )
    ( Call the 'Duty' function. )
    1 set-duty-status
    exit
  then
  dup "#onduty" strcmp not if ( [s s s] -> [s]) 
    ( Call the 'Duty' function. )
    1 set-duty-status
    exit
  then
 
  ( #off & #offduty - Sets someone in the list "on duty")
  ( TODO: Allow a wiz to pass the name of someone on the list to 'force' them? )
  dup "#off" strcmp not if ( [s s s] -> [s] )
    ( Call the 'Duty' function. )
    0 set-duty-status
    exit
  then
  dup "#offduty" strcmp not if ( [s s s] -> [s]) 
    ( Call the 'Duty' function. )
    0 set-duty-status
    exit
  then
 
  ( If we got this far, and the first character is a "#", they plum fucked up. )
  "#" 1 strncmp not if
    ( Call help! )
    help exit
  then
 
  display
;
