( /quote -dsend -S '/data/spindizzy/muf/extrapose.muf )
@prog extrapose.muf
1 5000 d
i

( ExtraPose v 1.0 by Morticon@SpinDizzy)
( A VERY BASIC way to do custom pose and says for things like OOC chatter )
( Setup: Make an action and link to it, then type action #help )
( In future:  Many improvements needed! )
( Pose code inspired/based on Generic Pose v2 by Tygryss/JaXoN )
  
$include $lib/nu-ansi-free
  
$def PROP_ROOT "/_prefs/extrapose/"
$def NAME_IDENTIFIER "%n"
$def MESSAGE_IDENTIFIER "%m"
$def SAY_TEMPLATE_PROP { PROP_ROOT COMMAND @ "/sayTemplate" }cat
$def POSE_TEMPLATE_PROP { PROP_ROOT COMMAND @ "/poseTemplate" }cat
  
: get_say_template ( -- s  Returns the say template for the command )
    SAY_TEMPLATE_PROP

    trig swap getpropstr

( commented out for now since we don't want defaults
    dup strlen if
        ( Found template
        swap pop
        exit
    else
        ( Not set up yet.  Use a default
        2 popn
        { NAME_IDENTIFIER " says, \"" MESSAGE_IDENTIFIER "\"" }cat
    then )
;

: get_pose_template ( -- s  Returns the pose template for the command )
    POSE_TEMPLATE_PROP

    trig swap getpropstr
    
( commented out for now since we don't want defaults
    dup strlen if
        ( Found template
        swap pop
        exit
    else
        ( Not set up yet.  Use a default
        2 popn
        { NAME_IDENTIFIER " " MESSAGE_IDENTIFIER }cat
    then )
;

: make_message (d s -- s'  Given an originator d and the message s from the
                extrapose command line, return s', the formatted string to be
                sent to everyone )
    "DS" checkargs
    strip var! message
    var! target_dbref
    
    var new_name
    var new_message
    
    ( Check if they're posing )
    message @ ":" 1 strncmp not if
        ( They're trying to pose. Remove the : )
        message @ 1 strcut swap pop message !
        
        ( Check the special cases that make posing so fun! )
        
        ( Add the possessive if they're using it, and verify they
          really mean the possessive by checking for a space.
            example: ":'s " is possessive, but ":'site'" is not )
        message @ "'" 1 strncmp not
        message @ " " instr 3 = message @ strlen 2 = or and if
            ( Using the possessive.  Set everything up. )
            message @ 2 strcut
            
            ( Add possessive to end of name )
            swap
            target_dbref @ name swap strcat new_name !
            
            ( And add rest of message, minus the initial space )
            1 strcut swap pop new_message !
        else
            message @ strlen not if
                ( instr doesn't like null strings )
                " " message !
            then
            
            ( If not the possessive, see if they want punctuation right after
              the name by checking the first character of the message )
            ".,:!?-" message @ 1 strcut pop instr if
                ( Special character.  Take everything up to the first space )
                message @ dup " " instr strcut
                
                ( Check to see if there was no space in the string at all.
                  If so, then there is no message )
                over strlen if
                    ( There's a space, therefore a message )
                    target_dbref @ name rot strcat striptail new_name !
                    new_message !
                else
                    ( No message, just a name with the suffix )
                    swap pop
                    target_dbref @ name swap strcat new_name !
                    "" new_message !
                then
            else
                ( Totally normal pose! )
                target_dbref @ name new_name !
                message @ new_message !
            then
        then
        
        get_pose_template
    else
        ( They're trying to say something normally )
        target_dbref @ name new_name !
        message @ new_message !
        
        get_say_template
    then
    
    ( Add the name )
    new_name @ NAME_IDENTIFIER subst
    ( Then the message )
    new_message @ MESSAGE_IDENTIFIER subst
;

: helpScreen ( --  Displays help screen )
    me @ "ExtraPose v1.0  by Morticon@SpinDizzy 2010 (Inspired by Phoex@SpinDizzy)" notify
    me @ " " notify
    me @ "  For the user: ExtraPose allows custom poses and says to be set" notify
    me @ "                up for special situations, such as OOC chatter." notify
    me @ "                The only user option is to indicate you want a 'pose'" notify
    me @ "                instead of a 'say' by prefixing a : before your words." notify
    me @ "                  Example: " COMMAND @ strcat " :'s posing!" strcat notify
    me @ "                The : prefix works identical to the pose command." notify
    me @ "                Use of color is supported." notify
    me @ " " notify
    
    ( Exit now if they don't control the trigger, as the info would be of no
      use to them anyway )
    me @ trig controls not if
        exit
    then
    
    me @ " For the admin: The 'say' and 'pose' templates need to be configured per" notify
    me @ "                command.  In both, the string " NAME_IDENTIFIER strcat " specifies the player name" strcat notify
    me @ "                while " MESSAGE_IDENTIFIER strcat " specifies the message to 'say'." strcat notify
    me @ "                If one of the props is left unset, that type of pose/say is" notify
    me @ "                will not be allowed.  Use of color is supported." notify
    me @ " " notify
    me @ "                Example for OOC chatter:  [OOC] %n says, \"%m\"" notify
    me @ " " notify
    me @ "     Set one or both of these props on the action to make this command work: " notify
    me @ "        For says: " SAY_TEMPLATE_PROP strcat notify
    me @ "       For poses: " POSE_TEMPLATE_PROP strcat notify
    me @ " " notify
;

: main ( s -- Entry into program )
    "me" match me !

    strip

    dup strlen not if
        ( Empty string.  Give help. )
        pop
        helpScreen
    else
        dup "#help" stringcmp not if
            ( They want to see the help screen )
            pop
            helpScreen
        else
            ( Generate the message )
            me @ swap make_message
            ( Notify everyone if there's a message )
            dup strip strlen if
                me @ location #-1 rot ansi-notify-except
            else
                me @ "That type of pose or say is not supported or configured.  Try '"
                    COMMAND @ strcat " #help'." strcat notify
            then
        then
    then
;
.
c
q
@set extrapose.muf=3
@set extrapose.muf=L
@set extrapose.muf=V
@set extrapose.muf=!D
