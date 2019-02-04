( /quote -dsend -S '/data/spindizzy/muf/lib-nuansi-free-101nc.muf )

ansi-notify, ansi-connotify:
    color on, off

notify-except

notify exclude:
Need to fix listening player (?)

No ansi codes (use inserver version)

This always assumes at least one is excluded
*    One in room total
*    Two in room.  No zombies (color on, off)
    Two in room.  Zombies and objects (none listening)  (color on, off)
    Two in room.  Zombies (listening) and objects.  (mono, color, flag on and off)
    Two in vehicle/inventory.
*    Test going up env (two in room, zombie and obj)
    
One in room, no exclude.

@prog lib-nu-ansi-free.muf
1 1000 d
i
$include $lib/appset
$include $lib/nu-color

$version 1.011

$def COLORAPP "color"
$def COLORATTR "colorsetting"
$def COLORSETTING "color"
$def MONOSETTING "mono"

( --- Helpers --- )
  
: notifyEnv (d s -- Given a room, notify the room itself and its parents
                     with string s )
    var string
    var current_room

    string !
    current_room !

    BEGIN
        current_room @ string @ notify
        current_room @ #0 dbcmp if break then
        current_room @ location current_room !    
    REPEAT
;

: zombie? (d -- i  Returns 1 if dbref is a zombie )
    "Zombie" flag?
;
  
: isThing?  (d -- i Returns 1 if not a zombie or player )
    dup player? swap zombie? or not
;
  
: zombieOwnerInRoom? ( d -- i Given zombie d, return 1 if owner also in room )
    dup owner location swap location dbcmp
;

: isListener?  (d s -- i  Returns 1 if dbref has listeners in dir s on it )
    dup 3 pick swap
  
    ( Check top level prop )
    getprop dup int? if
        0 = not
    else
        pop 1
    then

    ( Now see if it's a propdir )
    rot rot
    propdir?

    ( It's a listener if it's a valid prop OR a propdir )
    or
;

: listener? (d -- i Returns 1 if dbref is a listener )
    dup "/_listen" isListener?
    over "/~listen" isListener?
    rot "/~olisten" isListener?
    or or
;

: zombieListener? ( d -- i  Returns 1 if object is zombie and a listener )
    dup zombie? swap listener? and
;

: dbrefsString  ( d1 ... di i -- s  Given a list of dbrefs, return s, the
                   dbrefs concatted in a string for searching purposes.  A
                   little hokey, but better than trying to search through an
                   array )
    var the_string
    "" the_string !

    dup if
        BEGIN
            swap intostr " " strcat the_string @ swap strcat the_string !
            --
            ( Should we exit? )
            dup not
        UNTIL
    then    
    pop

    the_string @
;

: dbrefInList? ( s d -- i  Given a string from dbrefsString and a dbref
                            to check, return 1 if d is in s )
    intostr " " strcat
    instr
;

: notify_include ( d a s -- In the room d, notifies everyone listed
                   in array a with string s )
    "D?s" checkargs
  
    var notify_string
    var dbrefs_include
    var final_exclude_list
    var room
  
    ( Exit early if we aren't notifying anyone )
    over array_count not if
        3 popn exit
    then
  
    notify_string !
    dbrefs_include !
    room !
  
    ( Get room contents and do a set diff, to build the exclude list )
    dbrefs_include @ room @ contents_array array_diff final_exclude_list !
  
    ( See if we're supposed to exclude the room itself, as well )
    dbrefs_include @ room @ array_findval array_count not if
        ( They want to exclude the room )
        room @ final_exclude_list @ array_appenditem final_exclude_list !
    then
  
    ( Now, use the exclude list to notify everyone, which is used inverse
      to the typical notify_exclude usage )
  
    room @ final_exclude_list @ array_vals notify_string @ notify_exclude
;

: colorRule ( d -- i  Given a player, returns 0 if default [mono] rule for
              listening zombies, or 1 if color rule is desired )

    ( Get the string and verify it's a string and set )
    COLORAPP COLORATTR
    3 try
        appset-getAttribute
    catch
        ( Did not have permission remotely, so use default of 0 )
        pop
        0 exit
    endcatch


    dup appset-unset? if pop 0 exit then
    dup string? not if pop 0 exit then

    ( They provided something.  See what setting they want )
    dup MONOSETTING instring if
        ( mono desired )
        pop 0 exit
    then

    COLORSETTING instring if
        ( color desired )
        1 exit
    then

    ( Don't recognize the string )
    0
;


( --- Public --- )

: ansify_string ( s -- s'  Changes ansi codes within s into true ansi string s')
    lnc-parse-me
;

: ansi-strip ( s -- s' Removes all color/ansi codes from s, returning it as s')
    ansify_string ansi_strip
;

: ansi?  ( d -- i Returns 1 if dbref D has ansi color enabled )
    ( Only players can have ansi on )
    dup player? if
        "C" flag?
    else
        ( Not a player, always return 0 )
        pop 0
    then
;

: ansi-notify ( d s --  ansi equivalent of 'notify' prim <man notify> )
    over ansi? if
        over swap lnc-parse
    else
        ansi-strip
    then

    notify
;

: ansi-notify-exclude ( d dn ... d1 n s --  Works like notify_exclude,
                        only for color coded strings )
    var message
    var mono_message
    var color_message
    var room
    var list_to_notify (a dictionary of arrays,
                        key is owner of contained objects )
    var listening_zombies  (A dictionary of intbools.
                            Key is owner of objects.
                            1 if listening zombies for owner of objects )
    var thing_list_to_notify ( Non player/zombie means no color ever )
    var notify_room  ( True to notify the room itself and it's env )
    var exclude_list ( Don't notify those in this list )
    var current_object ( position in the list of items in the room )
    ( These two are used while doing the notifies )
    var current_owner
    var current_listening_zombie


    ( Let's save some CPU!  If there's no ansi codes at all in
      the text, just use the inserver version )
    dup lnc-color-codes? not if notify_exclude exit then

    dup dup message !
    ansi-strip mono_message !
    lnc-parse-me color_message !
    dup ++ ++ rotate room !
    { }dict list_to_notify !
    { }list thing_list_to_notify !
    { }dict listening_zombies !
    dbrefsString exclude_list !

    ( modes: mono [default]  color )

    ( See if the room is to be excluded )
    exclude_list @ room @ dbrefInList? not notify_room !

    ( Get room contents )
    room @ contents dup current_object !

    ( Just stop here if there's no one in the room )
    ok? if
        BEGIN
            ( Get next item and process it if it's not to be excluded )
            exclude_list @ current_object @ dbrefInList? not if
                ( If it's a thing, stick it in the big thing list, otherwise
                  do more advanced processing )
                current_object @ isThing? if
                    current_object @ thing_list_to_notify @ array_appenditem
                        thing_list_to_notify !
                else
                    ( If listening zombie, update zombie listener status for
                      that owner )
                    current_object @ zombieListener? if
                        1 listening_zombies @ current_object @ owner int
                        array_setitem listening_zombies !
                    then

                    ( Since this is either a player or a player's zombie,
                      stick it in the notify list for that player )
                    list_to_notify @ current_object @ owner int array_getitem

                    dup array? not if
                        ( This owner has never been encountered, so initialize
                          the array )
                        pop
                        { }list
                    then

                    current_object @ swap array_appenditem

                    ( and put it back in, with the newly added dbref )
                    list_to_notify @ current_object @ owner int array_setitem
                        list_to_notify !
                then
            then

            ( Advance to the next object )
            current_object @ next dup current_object !
        ok? not
        UNTIL

        ( Now we have everyone stored off into dictionaries and lists,
          so we will now go through them and start notifying objects.
          First we will notify the things, then the groups of
          players/zombies.  Finally, the env is notified if needed. )

        room @ thing_list_to_notify @ mono_message @ notify_include
        
        list_to_notify @ array_first if
            BEGIN
                dbref current_owner !

                listening_zombies @ current_owner @ int
                    array_getitem current_listening_zombie !

                ( Determine the color rule and apply )
                current_listening_zombie @ if
                    ( Listening zombie found.  Check and apply rule )
                    current_owner @ colorRule if
                        ( They want color anyway, if they have it on )
                        current_owner @ ansi? if
                            ( They have ansi. Colorify )
                            ( current_owner @ message @ lnc-parse )
                            color_message @
                        else
                            ( No ansi, just use mono string )
                            mono_message @
                        then                       
                    else
                        ( They want mono )
                        mono_message @
                    then
                else
                    ( No listening zombies found.  Apply color rule based on
                      if owner has color )
                    current_owner @ ansi? if
                        ( They have ansi. Colorify )
                        ( current_owner @ message @ lnc-parse )
                        color_message @
                    else
                        ( No ansi, just use mono string )
                        mono_message @
                    then
                then
  
                ( We have the string, so notify them )
                ( The rotate puts the string from above out in front )
                room @ list_to_notify @ current_owner @ int array_getitem
                    rot notify_include

            ( Advance to next owner if possible. )
            list_to_notify @ current_owner @ int array_next not
            UNTIL
            pop
        else
            pop
        then
    then

    ( Notify room env )
    notify_room @ if
        room @ mono_message @ notifyEnv
    then
;

: ansi-version ( -- i ; returns version number as 3-digit integer )
138  (Fake it out, since we're emulating)
;

( Stolen from lib-ansi-free )
: ansi-value ( s -- s ; turns stuff like "blue" or "lightgreen" into )
             (          colour values like "04" and "12". )
dup "BLACK" stringcmp 0 = if "0" else
dup "RED" stringcmp 0 = if "1" else
dup "GREEN" stringcmp 0 = if "2" else
dup "YELLOW" stringcmp 0 = if "3" else
dup "BLUE" stringcmp 0 = if "4" else
dup "MAGENTA" stringcmp 0 = if "5" else
dup "CYAN" stringcmp 0 = if "6" else
dup "LIGHTGREY" stringcmp 0 = over "LIGHTGRAY" stringcmp 0 = or if "7" else
dup "DARKGREY" stringcmp 0 = over "DARKGRAY" stringcmp 0 = or if "10" else
dup "LIGHTRED" stringcmp 0 = if "11" else
dup "LIGHTGREEN" stringcmp 0 = if "12" else
dup "LIGHTYELLOW" stringcmp 0 = if "13" else
dup "LIGHTBLUE" stringcmp 0 = if "14" else
dup "LIGHTMAGENTA" stringcmp 0 = if "15" else
dup "LIGHTCYAN" stringcmp 0 = if "16" else
dup "DARK" stringcmp 0 = if "17" else
""
then then then then then then then then
then then then then then then then then
swap pop
; 

( Stolen from lib-ansi-free )
: ansi-codecheck
"[0-9][0-7][0-7]" smatch
;

: ansi-tell ( s -- ; like .tell, but with ANSI support )
    me @ swap ansi-notify
;

: ansi-notify-except ( d d s -- ; like notify_except, but with ANSI. )
    1 swap ansi-notify-exclude
;
 
: ansi-otell ( s -- ; like .otell )
    me @ location me @ rot ansi-notify-except
;
 
: ansi-connotify ( i s -- ; like connotify, but with ANSI support. )
    over condbref dup ansi? if
        swap lnc-parse connotify 
    else
        pop ansi-strip connotify
    then
;

: ansi-strlen ( s -- i  Returns the length of s, minus color/ansi codes )
    ansify_string ansi_strlen
;

: ansi-strcut (s i -- s1 s2  Works like strcut, only removes all
               color/ansi codes)
    ansify_string ansi_strcut
;

: ansi_notify
    ansi-notify
;

PUBLIC ansi-notify
PUBLIC ansi-version
PUBLIC ansi-value
PUBLIC ansi?
PUBLIC ansi-connotify
PUBLIC ansi-notify-except
PUBLIC ansi-notify-exclude
PUBLIC ansi-tell
PUBLIC ansi-otell
PUBLIC ansi-strip
PUBLIC ansi-strlen
PUBLIC ansi-strcut
PUBLIC ansify_string
PUBLIC ansi-codecheck
PUBLIC ansi_notify
.
c
q

@set lib-nu-ansi-free.muf=/_defs/ansi-notify:"$lib/nu-ansi-free" match "ansi-notify" call
@set lib-nu-ansi-free.muf=/_defs/ansi-version:"$lib/nu-ansi-free" match "ansi-version" call
@set lib-nu-ansi-free.muf=/_defs/ansi-value:"$lib/nu-ansi-free" match "ansi-value" call
@set lib-nu-ansi-free.muf=/_defs/ansi?:"$lib/nu-ansi-free" match "ansi?" call
@set lib-nu-ansi-free.muf=/_defs/ansi-connotify:"$lib/nu-ansi-free" match "ansi-connotify" call
@set lib-nu-ansi-free.muf=/_defs/ansi-notify-except:"$lib/nu-ansi-free" match "ansi-notify-except" call
@set lib-nu-ansi-free.muf=/_defs/ansi-notify-exclude:"$lib/nu-ansi-free" match "ansi-notify-exclude" call
@set lib-nu-ansi-free.muf=/_defs/ansi-tell:"$lib/nu-ansi-free" match "ansi-tell" call
@set lib-nu-ansi-free.muf=/_defs/ansi-otell:"$lib/nu-ansi-free" match "ansi-otell" call
@set lib-nu-ansi-free.muf=/_defs/ansi-strip:"$lib/nu-ansi-free" match "ansi-strip" call
@set lib-nu-ansi-free.muf=/_defs/ansi-strlen:"$lib/nu-ansi-free" match "ansi-strlen" call
@set lib-nu-ansi-free.muf=/_defs/ansi-strcut:"$lib/nu-ansi-free" match "ansi-strcut" call
@set lib-nu-ansi-free.muf=/_defs/ansify_string:"$lib/nu-ansi-free" match "ansify_string" call
@set lib-nu-ansi-free.muf=/_defs/ansi-codecheck:"$lib/nu-ansi-free" match "ansi-codecheck" call
@set lib-nu-ansi-free.muf=/_defs/ansi_notify:"$lib/nu-ansi-free" match "ansi_notify" call
@set lib-nu-ansi-free.muf=/_lib-created:Morticon
@set lib-nu-ansi-free.muf=/_lib-version:1.00
@set lib-nu-ansi-free.muf=L
@set lib-nu-ansi-free.muf=W
@set lib-nu-ansi-free.muf=V
@reg lib-nu-ansi-free.muf=lib/nu-ansi-free
