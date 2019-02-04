@prog StarDrive.muf
1 2000 d
i
( New version by Morticon@SpinDizzy.  While the essentials of the
  program are the same, more security is present.
  Non-owners of a vehicle can only use a restricted set of
  commands, as determined by the wizards.  The owners of the
  vehicle may use any command as usual.  Also, the program
  is more vigilent with respect to the X flag and @flock.
  You will need to set the vehicle Xforcible, and
  '@flock vehiclename=me')
  
( Wiz setup.  All props are on room #0. ':' is allowed by all, everything else
     must be on at least one of these lists.  Vehicle owner is not subject
     to any restriction, so this is for non-owners using someone else's
     vehicle.  Exits leading to other rooms are always allowed and do not
     need to be on any of these lists.
  Put approved program db #s in:
    /_force/safeprogs.  Example: /_force/safeprogs/say:1234
  Put approved action db #s in:
    /_force/safeactions.  Example:  /_force/safeactions/farglobals:78
  Put approved inserver commands in this lsedit list:
    /_force/safecommands  Example: 'lsedit #0=/_force/safecommands'  'help'  '.end'
)
  
( StarDrive.MUF by Slipstream@FurryMUCK
  This is a simple program, designed to take the place of the
  complicated MPI code now required to move ships around
  in FurrySpace.  Thusly, this program has been written to
  alleviate the situation.
 
  It uses one property, on the action:  _object:******
  Replace '******' with the dbref# of the object to be pushed
  by the program.  Do not put the '#' in front of the dbref#.
 
 To Install, merely create an action on your bridge/control room,
 and trigger the action.  It will automatically run the setup routine.
 
 The owner of the object MUST be the owner of the action.
)
 
: setup
  trig owner me @ dbcmp 0 = IF
    me @ "You do not own this action!" NOTIFY EXIT THEN
  me @ "What is the dbref# of your vehicle object." NOTIFY
  me @ "Do NOT put the '#' in front!" NOTIFY
  me @ "Dbref> " NOTIFY READ
  atoi dbref
  ( Error check )
  dup #0 dbcmp IF
    me @ "That is an invalid dbref#!" NOTIFY EXIT THEN
  dup thing? 0 = IF
    me @ "That is not an object!" NOTIFY EXIT THEN
  dup owner me @ dbcmp 0 = IF
    me @ "You do not own that object!" NOTIFY EXIT THEN
  ( Set the info on the trigger )
  trig "_object" rot intostr setprop
  me @ "The property _object on the trigger has been set." NOTIFY
;
  
: clearExplode  ( s1...si i -- POPs the remainder of an explode, assuming i is counting the elements LEFT )
    dup not if pop exit then

    BEGIN
        swap pop
        1 -
        dup not if pop break then
    REPEAT
;
    
: remote_exit_match ( d s -- d'  Like rmatch, only you can pick where it starts from rather than just
                      the owner of the pid.  Finds an exit that can be taken from d.  Must be exact match.
                      Returns a valid db or #-1 for everything else )
    strip
    tolower
    ( Can't match exits with ; in them )
    dup ";" instr if pop pop -1 dbref exit then
  
    ( Main loop... goes up the env tree )
    BEGIN
        ( Sub loop.  Examines each exit in the tree location to see if it's a valid action )
        2 pick exits
        BEGIN
            dup ok? if
                ( There are a few possibilities for where the exit name is, so check each name)
                dup name tolower
                ( Loop to check all names in exit )
                ";" explode
                BEGIN
                    1 -  (We took one off)
                    swap
                    2 pick 6 + pick  ( Get the string we're searching for )
                    stringcmp not if
                        ( Found it! )
                        clearExplode
                        1
                        break
                    then
                    ( Are we out of strings? )
                    dup not if
                        0  (Means not found)
                        break
                    then 
                REPEAT
                if swap pop swap pop exit then  ( We found the exit, just exit and return it )
                next
            else
                break  (No match, empty room/object   Proceed up the tree )
            then
            dup ok? while
        REPEAT
        pop
  
        ( If we just did room #0, then we can't go any further )
        2 pick 0 dbref dbcmp if
            pop pop
            -1 dbref exit
        then
  
        ( Go up a room )
        swap location swap
    REPEAT

    "Programming error exists in remote_exit_match" abort
;
  
: validCommand (d s -- i  Given a command string destined for a object, returns 1 if OK, 0 if security risk.
                          'me' must be set to the character trying the command, usually not an issue)
    swap dup rot
    ( Owners can use any command )
    swap owner me @ dbcmp if pop 1 exit then

    strip

    ( Always allow commands that start with :, to cover all poses with ease )
    dup ":" instr 1 = if pop pop 1 exit then
    

    ( find out which part of the string is a valid object/command.  The rest is assumed to be parameters )
    ( Do this by removing the last part of the passed string one word at a time till it finds an object )
    ( It is possible no object will be found )
    BEGIN
        ( Valid object? )
        dup rot swap remote_exit_match dup ok? if
            swap pop break
        else
            pop
        then
        ( Object wasn't valid, remove another chunk )
        dup " " rinstr dup if
            strcut pop striptail
        else
            pop pop -1 dbref break
        then
    REPEAT

    dup ok? if
        dup exit? if
            ( If the command is an exit that links to a nonprogram, then it is always OK )
            dup getlink dup program? not if
                pop pop 1 exit
            else
                ( Else, see if it is on the list of 'approved' programs )
                0 dbref "/_force/safeprogs/" nextprop dup strlen if
                    BEGIN
                        ( A match? )
                        dup 0 dbref swap getpropstr atoi dbref 3 pick dbcmp if
                            pop pop pop 1 exit
                        then
  
                        0 dbref swap nextprop dup
                        strlen not
                    UNTIL
                then
                pop pop

                ( Else, see if it is an approved action dbref )
                0 dbref "/_force/safeactions/" nextprop dup strlen if
                    BEGIN
                        ( A match? )
                        dup 0 dbref swap getpropstr atoi dbref 3 pick dbcmp if
                            pop pop 1 exit
                        then
  
                        0 dbref swap nextprop dup
                        strlen not
                    UNTIL
                then
                ( It wasn't approved, so this is a possible security risk )
                pop pop 0 exit
            then
        else
            ( Not an exit.  Nothing else can cause a command to occur, so say 0 to be safe )
            pop 0 exit
        then
    else
        pop
        (Not an exit.  See if it is an approved internal command)
        0 dbref "/_force/safecommands#/" nextprop dup strlen if
            BEGIN
                ( A match? )
                dup 0 dbref swap getpropstr 3 pick strip strcmp not if
                    pop pop 1 exit
                then
  
                0 dbref swap nextprop dup
                strlen not
            UNTIL
            pop pop
        then
    then
    0
;
: moveship ( s -- )
  trig "_object" getpropstr atoi dbref
  dup owner trig owner dbcmp 0 = IF
    me @ "ERROR: Object and Trigger owners do not match!" NOTIFY EXIT THEN
  dup thing? 0 = IF
    me @ "ERROR: Object specified is not an Object!" NOTIFY EXIT THEN
  dup "xforcible" flag? not IF
    me @ "ERROR: Object specified is not set Xforcible!" NOTIFY EXIT THEN
  dup "dark" flag? IF
    me @ "ERROR: Object may not be set DARK!" NOTIFY EXIT THEN
  dup "/@/flk" getprop dup lock? not IF
    me @ "ERROR: Vehicle is not @flock-ed to its owner." NOTIFY EXIT THEN
  2 pick owner swap testlock not IF
    me @ "ERROR: Vehicle is @flock-ed but not to its owner!" NOTIFY EXIT THEN

  dup rot dup rot swap validCommand if
      FORCE
  else
      me @ "ERROR: The command given to the vehicle is invalid or restricted to the owner." notify
  then
;
 
: main
  trig "_object" getpropstr "" stringcmp 0 = IF
    setup EXIT THEN
  dup "" stringcmp 0 = IF EXIT THEN
  moveship
;
.
c
q
@set StarDrive.muf=3
@set StarDrive.muf=W
@set StarDrive.muf=L
@set StarDrive.muf=D
