(* hopemorph.muf
 *
 * Simplified editplayer / morpher as used for Hope Island MUCK.
 *
 * Prop-compatible with DescTools.muf in a limited fashion -- i.e. if you
 * have DescTools props, they will be read and you can use this program.
 * However, this program does not promise backwards compatibility.  It is
 * designed as a replacement for DescTools rather than a tool that coexists
 * with it.
 *
 * This did impose some wonky design choices on the prop structure, but
 * it works okay.  It isn't optimal but it works well enough.  And for
 * the moment, DescTools morph and this one are actually interoperable
 * if you run both of them, though that may not always be the case as the
 * tool evolves.
 *
 * By HopeIslandCoder
 * 2023
 * Public Domain
 *
 **************************************************************************
 * VERSION HISTORY
 *
 * v1.01 - 5/13/2023 - Bug fixes
 *                     When you edit global looktraps, it will now re-apply
 *                     your description [re-run morph].
 *                     Looktrap editor is now also friendly to people who
 *                     aren't using the morph program but want to use it to
 *                     set looktraps [it preserves their _/de prop and does
 *                     not do a 'full' morph]
 *)
 
$def VERSION "Hope Morph v1.01 by HopeIslandCoder"
$version 1.01
$author HopeIslandCoder
 
(*
 * Configuration -  there's a few things that may vary from MUCK to MUCK.
 *
 * Let's start with HAND props.  Natasha's hand command defaults to handable
 * unless you specifically set yourself not-handable.  Most hand
 * implementations actually work in the opposite direction.  These defs
 * allow you to control how this works.
 *)
$def IS_HAND_OK me @ "_hand/hand_ok" getpropstr strlen not
$def SET_HAND_OK me @ "_hand/hand_ok" remove_prop
$def SET_HAND_NOK me @ "_hand/hand_ok" "no" setprop
 
(*
 * FLIGHT might vary from MUCK to MUCK.  Some MUCKs might not even have
 * this, so I guess it would make sense to disable the option altogether,
 * but I'm writing this for Hope Island right now and so I will selfishly
 * not care about others MUCKs for now.  You're lucky you get this level
 * of config :]
 *)
$def IS_FLY_OK me @ "_fly?" getpropstr "yes" strcmp not
$def SET_FLY_OK me @ "_fly?" "yes" setprop
$def SET_FLY_NOK me @ "_fly?" remove_prop
 
(* Property for smell, touch, feel *)
$def SMELL_PROP "_prefs/smell"
$def FEEL_PROP "_prefs/feel"
$def TASTE_PROP "_prefs/taste"
 
(* What 'ride' messages do we support.  If you add to this list, you will
 * also need to edit 'which-ride-message'.  If there's a demand for it,
 * I will make 'which-ride-message' feed off this list... however I think
 * probably all MUCKs use this same list.
 *)
$def RIDE_MODES { "fly" "hand" "paw" "walk" "ride" }list
 
(* End configuration *)
 
$include $lib/editor
$include $lib/lmgr
$include $lib/tabtoolkit
 
(* We use this all over the place, make things a little easier *)
$def GLOBAL_ROOT "/_descs/prefs/global/"
 
(* WORKFLOW NOTES
 *
 * Purpose of this program is twofold; first, to provide a way for a user to
 * edit their basic settings.  Secondly, to allow morphing from description to
 * description.
 *
 * Character Settings
 * - Using color?
 * - Which type of 'ride' carry?
 * - Set default look traps
 * - Set items on person lookat-able
 * - Set hand okay
 * - Set can fly
 * - gender
 * - species
 * - disable look notify [enabled by default]
 * - set default description on connect
 * - set default description on disconnect
 * - toggle notify description on connect
 * - scent
 * - feel
 * - taste
 *
 * Descriptions
 *
 * - Add
 * - List
 * - Delete
 * - Edit
 * - Set current
 *
 * Descriptions have:
 * - the descriptive text
 * - per-description looktraps [override globals]
 * - gender
 * - species
 * - message to yourself when changing
 * - message to others when changing
 * - scent
 * - feel
 * - taste
 *
 * comamnd shortcuts:
 *
 * No arguments: enters editor
 * Argument: if #help, show help.  Else, try to load description.
 *
 * Support: #list, #add, #edit, #delete, #status
 *)
 
: help ( -- ) (* Display help banner *)
  VERSION 70 tt-tab-init
  "This is a program to set up your character and edit 'morphs'." tt-tab-addline
  "Morphs are what MUCKs like to call description changes or"
  tt-tab-addline
  "different sets of clothes/outfits/etc." tt-tab-addline
  "-[Usage]--------------------------------------------------------------"
  tt-tab-addline
 
  command @ 20 tt-shave-to-len "- Enter the editor" strcat tt-tab-addline
  command @ " <Descr>" strcat 20 tt-shave-to-len "- Change to description"
  strcat tt-tab-addline
  command @ " #status" strcat 20 tt-shave-to-len
  "- Current description information." strcat tt-tab-addline
  command @ " #list" strcat 20 tt-shave-to-len "- List descriptions" strcat
  tt-tab-addline
  command @ " #add" strcat 20 tt-shave-to-len
  "- Shortcut to add new description." strcat tt-tab-addline
  command @ " #delete" strcat 20 tt-shave-to-len
  "- Shortcut to delete description" strcat tt-tab-addline
  command @ " #edit" strcat 20 tt-shave-to-len
  "- Shortcut to edit description" strcat tt-tab-addline
  "-[Special]------------------------------------------------------------"
  tt-tab-addline
  "If you use the q-version of a command, for instance 'qmorph', it"
  tt-tab-addline
  "will run silently and not display messages to the room.  This is"
  tt-tab-addline
  "helpful if you show up somewhere in the wrong outfit and want to"
  tt-tab-addline
  "fix it without drawing attention, or possibly other RP purposes."
  tt-tab-addline
  "" tt-tab-final-flush
;
 
: cb-yes-no ( s -- i ) (* Callback for yes / no questions *)
  strip tolower
  dup "y" 1 strncmp not if
    pop 1 exit
  else "n" 1 strncmp not if
    1 exit
  then then

  "Please answer 'y'es or 'n'o." tell 0
;
 
: cb-get-desc-name ( s -- i ) (* Callback for entering description name *)
  dup ".abort" strcmp not if
    pop 1 exit
  then
  
  dup ".list" strcmp not if
    pop 1 exit
  then
  
  dup "prefs" strcmp not if
    pop
    "You can't have a description named 'prefs' because that is reserved."
    tell 0 exit
  then
  
  "^[a-zA-Z0-9_-]+$" 0 regexp array_count swap array_count or dup
  not if
    "Description names must only be letters, numbers, and _ or -." tell
    "You can use '.abort' to cancel the process." tell
  then
;
 
: cb-get-any-string ( s -- i ) (* Callback for fetching any non-empty string *)
  strip strlen dup not if
    "Please enter some text."
  then
;
 
: cb-get-prop-name ( s -- i ) (* Get a string that is valid for a prop name
                               * without tripping over a secure property that
                               * we shouldn't be reading/writing.
                               *)
  (* This lil regex is down below in the editor as well, so if you change
   * it here, change it there too.
   *)
  strip dup strlen not if
    pop "Property name can't be empty." tell 0
  else "[:/@~]" 0 regexp array_count swap array_count or if
    "You can use most characters, but you can't use reserved property " tell
    "characters, such as : / @ or ~" tell
    0
  else
    1
  then then
;
 
: cb-pick-ride-mode ( s -- i ) (* Callback for picking a ride mode *)
  tolower dup ".abort" strcmp not if ( special case )
    pop 1
  else RIDE_MODES swap array_findval array_count dup not if
    "Ride mode must be one of: " RIDE_MODES "," array_join strcat tell
  then then
;
 
: input-loop ( s i a -- s' ) (* Takes a stackrange of strings that are some
                              * kind of question to ask, and a function which
                              * is a callback to check the validity of the
                              * answer.  Loops until a valid answer is given
                              * then returns that valid answer.
                              *
                              * Callback should [ s -- i ] returning boolean
                              * Callbacks have to be defined above this
                              * function.
                              *)
  var! callback array_make
  begin
    dup { me @ }list array_notify
    read strip
    dup callback @ execute if
      swap pop
      exit
    then
    pop
  repeat
;
 
: which-ride-message ( -- s ) (* Looks at the RIDE/_mode prop and determines
                               * which kind of RIDE messages are being used
                               * by the player, returning them in human
                               * friendly form.
                               *)
  me @ "RIDE/_mode" getpropstr tolower
  dup dup strlen not swap "ride" strcmp not or if
    pop "carrying riders"
  else dup "fly" strcmp not if
    pop "flying with"
  else dup "hand" strcmp not if
    pop "holding hands"
  else dup "paw" strcmp not if
    pop "holding paws"
  else dup "walk" strcmp not if
    pop "walking with"
  else
    pop "custom setup"
  then then then then then
;
 
: which-morph ( -- s ) (* Which morph is currently set *)
  me @ "_descs/prefs/current" getpropstr
  dup strlen not if
    pop "not using morph program"
  then
;
 
: determine-list-name ( s -- s ) (* Given a string value, figure out if
                                  * it has an MPI list in it {list:...} or
                                  * not.  If it does, return the list name.
                                  * Otherwise, return empty ""
                                  *
                                  * I should probably put this in a library
                                  * because I copy/pasted this code from
                                  * my editroom :]
                                  *)
 
    dup "{list:" instring if
      "{list:" split swap pop
      "," split pop (* Might have a comma, might not *)
      "}" split pop (* But will have a close-brace. *)
    else
      pop ""
    then
;
 
: list-looktraps[ basepath -- ] (* Lists looktraps belonging to the given
                                 * basepath [see modify-looktraps]
                                 *)
  basepath @ GLOBAL_ROOT strcmp not if
    "> Note, this ONLY lists global looktraps!" tell
  else
    "> Note, this ONLY lists looktraps for the description you are working on!"
    tell
  then
 
  me @ basepath @ nextprop
  dup strlen not if
    pop ".... And it looks like you have none set yet!" tell
  else
    begin
      dup strlen while
      dup "/" rsplit swap pop tell
      me @ swap nextprop
    repeat
    pop
  then
;
 
: modify-looktraps[ basepath -- ] (* Edit looktraps.  'basepath' is
                                   * / for default look traps or
                                   * some description prop path and should
                                   * end in /
                                   *)
  "" var! LookTrapPath
  "" var! LookTrapName
  "" var! ListName
  
  (* Looktraps go into _details/[look trap name]:value *)
  begin
    "" 75 tt-tab-init
    "Description details are known as \"looktraps\" in MUCK terms.  They"
    tt-tab-addline
    "are viewed by typing 'look SomeName=Detail Name'.  Often, people will"
    tt-tab-addline
    "use these details to describe stuff like tattoos, gear being held,"
    tt-tab-addline
    "jewelery or other such things.  Use this tool to configure them!"
    tt-tab-addline
    " " tt-tab-addline
    
    basepath @ GLOBAL_ROOT strcmp not if
      "You are editing your global look traps.  These will be visible no matter"
      tt-tab-addline
      "which description you have on, unless you override it with a specific"
      tt-tab-addline
      "setting on an individual description." tt-tab-addline
    else
      "You are editing a specific description's looktraps.  These will override "
      "global looktraps and will only be visible when you wear this description."
      strcat
      tt-tab-addline-wrap
    then
 
    " " tt-tab-addline
    "1) Additional information and tips about using looktraps."
    tt-tab-addline
    "2) List looktraps" tt-tab-addline
    "3) Add or edit looktrap" tt-tab-addline
    "4) Delete looptrap" tt-tab-addline
    " " tt-tab-addline
    "B) Back to previous menu" tt-tab-addline
    "<Choose an Option>" tt-tab-final-flush
    read strip tolower
    
    dup "b" strcmp not if
      pop exit
    then
    
    atoi dup 1 = if
      pop
      "Look traps are really handy to put additional descriptive text in" tell
      "your description without overwhelming the reader with a wall of" tell
      "text.  The nitty-gritty details can go into looktraps and you can" tell
      "give your reader hints they should check them out.  Consider this" tell
      "example description:" tell
      " " tell
      "---------------------------------------------------------------------"
      tell
      "You see Ari the ocelot.  She's our model for this demonstration." tell
      "Normally, there'd be more details here in the main description." tell
      "However, we're just making a demo here.  So if you want to see her" tell
      "[jewelery] you will need to look at it.  Or you can see her [spots]" tell
      "because she's an ocelot." tell
      " " tell
      "You can type 'look Ari=detail' such as 'look Ari=jewelery' to see" tell
      "more detail." tell
      "---------------------------------------------------------------------"
      tell
      "<Press any key then enter to continue>" tell
      read pop
      "So notice a few things that were done to hint to the reader that" tell
      "you have details.  Square braces like [these] were put around" tell
      "things that can be looked at.  And the last couple lines of the" tell
      "description instruct the reader on how to read those details." tell
      " " tell
      "You will probably want to do the same with your description if you" tell
      "use look traps.  You can leave off the square brackets and make" tell
      "it more like a game to find looktraps if you prefer, however you" tell
      "should definitely hint that you are using look traps because" tell
      "people will usually not assume that you are.  Hopefully these" tell
      "tips are helpful to you!" tell
      "<Press any key then enter to continue>" tell
      read pop
    else dup 2 = if
      pop
      basepath @ list-looktraps
      "<Press any key then enter to continue>" tell
      read pop
 
    else dup 3 = if
      pop
      "First, enter the name of your looktrap.  This is what people will use "
      "to view the looktrap -- for instance, if you put 'jewerley' here, "
      "people will type: look " me @ name strcat "=jewelery" strcat
      "... to look at it.  You can have aliases if you want.  Aliases are"
      "separated by semicolon ; -- for example: jewelery;jewels;jewel"
      "In such a case, any of those three words will work for the same"
      "looktrap.  Enter a looktrap name below or type '.abort' to cancel."
      7 'cb-get-prop-name input-loop strip
      
      dup ".abort" strcmp not if
        pop "Aborting!" tell
      else
        dup LooktrapName !
        basepath @ swap strcat LooktrapPath !
        me @ LooktrapPath @ getpropstr
        
        strlen if
          "This looktrap is already set to:" tell
          me @ LooktrapPath @ "(LOOK)" 1 parseprop tell
          "...Do you want to change it?  (Y)es or (N)o"
          1 'cb-yes-no input-loop strip tolower
        else
          "y"  (* No need to ask if already set *)
        then
        
        "y" 1 strncmp not if
          me @ LooktrapPath @ getpropstr determine-list-name ListName !
          
          (* Load the description for the editor *)
          ListName @ strlen not if
            me @ LooktrapPath @ getpropstr dup strlen not if
              pop 0
            else
              1 (* Make our single line description into stackrange *)
            then
          else
            ListName @ me @ lmgr-fullrange lmgr-getrange
          then
          
          editor (* Run the editor *)
 
          "a" 1 strncmp not if
            (* Abort -- don't save *)
            popn
          else
            ListName @ strlen if
              me @ ListName @ "#" strcat remove_prop
            else
              "_looktrap_lists" LooktrapPath @ strcat ListName !
              me @ LooktrapPath @ "{list:" ListName @ strcat "}" strcat setprop
            then
            
            1 ListName @ me @ lmgr-insertrange
          then
        else
          "Aborting!" tell
        then
      then
    else dup 4 = if
      begin
        "Which looktrap do you want to delete?  You must type the full name of"
        tell
        "the look trap (sorry).  Type '.list' to list your looktraps or '.abort'"
        tell
        "to abort."
        tell
        read strip
        
        dup ".list" strcmp not if
          pop basepath @ list-looktraps
        else dup ".abort" strcmp not if
          pop "Aborting!" tell break
        else dup "[:/@~]" 0 regexp array_count swap array_count or if
          pop "Invalid looktrap name." tell
        else dup me @ swap basepath @ swap strcat getpropstr strlen not if
          pop "That doesn't seem to be a look trap set on you." tell
        else
          me @ swap basepath @ swap remove_prop
          "Done." tell break
        then then then then
      repeat
    else
      pop "Try again?" tell
    then then then then
  repeat
;
 
: list-descriptions ( -- ) (* List player's descriptions *)
  "" 75 tt-tab-init var! tt
  "" var! descname
  
  me @ "_descs/" nextprop
  begin
    dup strlen while
    dup dup strlen 1 midstr "#" strcmp not if
      (* This is a description -- add it.  First chop off _descs/ and the
       * trailing #
       *)
      dup dup 8 swap strlen 8 - midstr descname !
      tt @ descname @ tt-tab-addline
 
      me @ "_descs/" descname @ strcat "/species" strcat getpropstr strlen if
        "  Species: " me @ "_descs/" descname @ strcat "/species" 
        strcat getpropstr
        strcat tt-tab-addline
      then
 
      me @ "_descs/" descname @ strcat "/spec" strcat getpropstr strlen if
        "  Species: " me @ "_descs/" descname @ strcat "/spec" 
        strcat getpropstr
        strcat tt-tab-addline
      then
 
      me @ "_descs/" descname @ strcat "/sex" strcat getpropstr strlen if
        "  Sex: " me @ "_descs/" descname @ strcat "/sex" strcat getpropstr
        strcat tt-tab-addline
      then
 
      tt !
    then
    me @ swap nextprop
  repeat
  pop

  tt @ "counter" [] 1 = if
    tt @ "No descriptions set, yet!" tt-tab-addline tt !
  then
  
  tt @ "" tt-tab-final-flush
;
 
: set-senses[ basepath -- ] (* Sets the senses [smell/touch/taste]
                             * 'basepath' is where we will set the props.
                             * It should be "/" for global level, or it
                             * should be the path to the morph.
                             *)
  begin
    "" 75 tt-tab-init
    basepath @ GLOBAL_ROOT strcmp not if
      "You are editing your default sense settings.  These will be used if your"
      tt-tab-addline
      "description doesn't override it." tt-tab-addline
    else
      "You are editing a specific description's sense settings.  These"
      tt-tab-addline
      "override your defaults if you set them.  You can leave them unset"
      tt-tab-addline
      "to use the defaults." tt-tab-addline
    then
 
    " " tt-tab-addline
 
    "1) Set your scent message.  Currently:" me @ basepath @ SMELL_PROP strcat
    getpropstr dup not if
      pop " Unset" strcat tt-tab-addline
    else
      rot rot tt-tab-addline " " tt-tab-addline swap tt-tab-addline-wrap
      " " tt-tab-addline
    then
    
    "2) Set your feel message.  Currently:" me @ basepath @ FEEL_PROP strcat
    getpropstr dup not if
      pop " Unset" strcat tt-tab-addline
    else
      rot rot tt-tab-addline " " tt-tab-addline swap tt-tab-addline-wrap
      " " tt-tab-addline
    then
    
    "3) Set your taste message.  Currently:" me @ basepath @ TASTE_PROP strcat
    getpropstr dup not if
      pop " Unset" strcat tt-tab-addline
    else
      rot rot tt-tab-addline " " tt-tab-addline swap tt-tab-addline-wrap
      " " tt-tab-addline
    then
    
    " " tt-tab-addline
    "B) Back" tt-tab-addline
    "<Choose an Option>" tt-tab-final-flush
    
    read strip tolower
    
    dup "b" strcmp not if
      pop "Done!" tell exit
    then
    
    atoi dup 1 = if
      pop
      "Enter a scent message, or '.abort' to abort, or '.clear' to unset it."
      1 'cb-get-any-string input-loop strip
 
      dup ".abort" strcmp not if
        pop "Aborting!" tell
      else dup ".clear" strcmp not if
        pop "Clearing it!" me @ basepath @ SMELL_PROP strcat remove_prop
      else
        me @ swap basepath @ SMELL_PROP strcat swap setprop
        "Set!" tell
      then then
    else dup 2 = if
      pop
      "Enter a feel message, or '.abort' to abort, or '.clear' to unset it."
      1 'cb-get-any-string input-loop strip
 
      dup ".abort" strcmp not if
        pop "Aborting!" tell
      else dup ".clear" strcmp not if
        pop "Clearing it!" me @ basepath @ FEEL_PROP strcat remove_prop
      else
        me @ swap basepath @ FEEL_PROP strcat swap setprop
        "Set!" tell
      then then
    else dup 3 = if
      pop
      "Enter a taste message, or '.abort' to abort, or '.clear' to unset it."
      1 'cb-get-any-string input-loop strip
 
      dup ".abort" strcmp not if
        pop "Aborting!" tell
      else dup ".clear" strcmp not if
        pop "Clearing it!" me @ basepath @ TASTE_PROP strcat remove_prop
      else
        me @ swap basepath @ TASTE_PROP strcat swap setprop
        "Set!" tell
      then then
    else
      pop "Invalid option." tell
    then then then
  repeat
;
 
: add-or-edit-description[ str:descname -- ] (* The underlying engine for
                                              * editing or adding a new
                                              * description.  Take the
                                              * description name as a
                                              * parameter.
                                              *)
  "" var! ListName
  
  begin
    "" 75 tt-tab-init
    "1) Set override species (Currently: "
    me @ "_descs/" descname @ strcat "/spec" strcat getpropstr
    dup strlen not if
      pop "Using Default"
    then
    strcat ")" strcat tt-tab-addline
 
    "2) Set override gender (Currently: "
    me @ "_descs/" descname @ strcat "/sex" strcat getpropstr
    dup strlen not if
      pop "Using Default"
    then
    strcat ")" strcat tt-tab-addline
 
    "3) Set details specific to this description (\"Looktraps\")"
    tt-tab-addline
    
    "4) Set message to yourself when changing to this description."
    tt-tab-addline
    
    "5) Set message to show others when changing to this description."
    tt-tab-addline
 
    "6) Set smell, touch, and feel." tt-tab-addline

    "7) Set description text" tt-tab-addline
    " " tt-tab-addline
    "B) Back to previous menu" tt-tab-addline
    "<Choose an Option>" tt-tab-final-flush
    read strip tolower
    
    dup "b" strcmp not if
      pop exit
    then
    
    atoi dup 1 = if
      pop
      "You can change your species as part of the description change if you"
      "want.  Or you can leave this unset and it will use whatever species"
      "you set on the main screen.  Type '.abort' to do nothing, '.clear' "
      "to clear this setting and use the default, or whatever species you "
      "would like."
      5 'cb-get-any-string input-loop
      strip
      dup ".abort" strcmp not if
        pop "Aborting." tell
      else dup ".clear" strcmp not if
        pop me @ "_descs/" descname @ strcat "/spec" strcat remove_prop
        "Using default species." tell
      else
        me @ swap "_descs/" descname @ strcat "/spec" strcat swap setprop
        "Species set." tell
      then then
    else dup 2 = if
      pop
      "You can change your gender as part of the description change if you"
      "want.  Or you can leave this unset and it will use whatever gender"
      "you set on the main screen.  Type '.abort' to do nothing, '.clear' "
      "to clear this setting and use the default, or whatever gender you "
      "would like."
      5 'cb-get-any-string input-loop
      strip
      dup ".abort" strcmp not if
        pop "Aborting." tell
      else dup ".clear" strcmp not if
        pop me @ "_descs/" descname @ strcat "/sex" strcat remove_prop
        "Using default gender." tell
      else
        me @ swap "_descs/" descname @ strcat "/sex" strcat swap setprop
        "Gender set." tell
      then then
    else dup 3 = if
      pop "_descs/" descname @ strcat "/_details/" strcat modify-looktraps
    else dup 4 = if
      pop me @ "_descs/" descname @ strcat "/message" strcat getpropstr
      dup strlen if
        "Currently, when you change descriptions, you will see:" tell
        tell
        "Enter a new message, type '.abort' to abort, or '.clear' to clear it."
        1 'cb-get-any-string input-loop strip
        dup ".abort" strcmp not if
          pop "Aborting!" tell
        else dup ".clear" strcmp not if
          pop "Clearing!" tell
          me @ "_descs/" descname @ strcat "/message" strcat remove_prop
        else
          me @ swap "_descs/" descname @ strcat "/message" strcat swap
          setprop
          "Set!" tell
        then then
      else
        pop
        "Enter a message that will be seen by you when you change descriptions,"
        "or type '.abort' to abort."
        2 'cb-get-any-string input-loop strip
        dup ".abort" strcmp not if
          pop "Aborting!" tell
        else
          me @ swap "_descs/" descname @ strcat "/message" strcat swap
          setprop
          "Set!" tell
        then
      then
    else dup 5 = if
      pop me @ "_descs/" descname @ strcat "/omessage" strcat getpropstr
      dup strlen if
        "Currently, when you change descriptions, others will see:" tell
        me @ name " " strcat swap strcat tell
        "There's no need to put your name at the start of the message, it " tell
        "will be added for you." tell
        "Enter a new message, type '.abort' to abort, or '.clear' to clear it."
        1 'cb-get-any-string input-loop strip
        dup ".abort" strcmp not if
          pop "Aborting!" tell
        else dup ".clear" strcmp not if
          pop "Clearing!" tell
          me @ "_descs/" descname @ strcat "/omessage" strcat remove_prop
        else
          me @ swap "_descs/" descname @ strcat "/omessage" strcat swap
          setprop
          "Set!" tell
        then then
      else
        pop
        "Enter a message that will be seen by others when you change "
        "descriptions, or type '.abort' to abort.  Your name will be put "
        "as the first word of the message so you don't need to include that."
        3 'cb-get-any-string input-loop strip
        dup ".abort" strcmp not if
          pop "Aborting!" tell
        else
          me @ swap "_descs/" descname @ strcat "/omessage" strcat swap
          setprop
          "Set!" tell
        then
      then
    else dup 6 = if
      pop
      "_descs/" descname @ strcat "/" strcat set-senses
    else dup 7 = if
      pop
      "_descs/" descname @ strcat me @ lmgr-fullrange lmgr-getrange
      editor
      
      "a" 1 strncmp not if
        (* Abort, don't save *)
        popn
      else
        me @ "_descs/" descname @ strcat "#" strcat remove_prop
        1 "_descs/" descname @ strcat me @ lmgr-insertrange
      then
    else
        "Try again?" tell
    then then then then then then then
  repeat
;
 
: cleanup-description[ str:current -- ] (* Cleans up a description, removing
                                         * all its look traps and unsetting
                                         * any props that it set.
                                         *)
  (*
   * Method -- all these actions are taken ONLY if the description uses them.
   *
   * - unset species
   * - unset gender
   * - unset senses
   * - unset looktraps specific to description
   *)
  "_descs/" current @ strcat "/" strcat var! base

  me @ base @ "spec" strcat getpropstr strlen
  me @ base @ "species" strcat getpropstr strlen or if
    me @ "species" remove_prop
  then
  
  (* These are all handled the same *)
  { "sex" SMELL_PROP FEEL_PROP TASTE_PROP }list
  foreach
    dup me @ swap base @ swap strcat getpropstr strlen if
      me @ swap remove_prop
    else
      pop
    then
    pop
  repeat
  
  (* Delete looktraps *)
  me @ base @ "_details/" strcat nextprop
  begin
    dup strlen while
    dup base @ split swap pop
    me @ swap remove_prop
    me @ swap nextprop
  repeat
  pop
;
 
: setup-description[ str:base -- ] (* Sets up a description.  This copies
                                    * all the properties over.  The 'base'
                                    * parameter should be the PATH to the
                                    * description and not just the name.
                                    *
                                    * Reason is, this can also work with
                                    * the global settings.
                                    *
                                    * Base should end with /
                                    *)
  me @ base @ "spec" strcat getpropstr strlen if
    me @ "species" me @ base @ "spec" strcat getpropstr setprop
  then
  
  (* Copy these props straight over *)
  { "species" "sex" SMELL_PROP FEEL_PROP TASTE_PROP }list
  foreach
    dup me @ swap base @ swap strcat getpropstr dup strlen if
      ( @ "propname" "value" )
      me @ -rot setprop
    else
      pop pop
    then
    pop
  repeat
  
  (* Copy over looktraps *)
  me @ base @ "_details/" strcat nextprop
  begin
    dup strlen while
    dup dup  me @ swap getpropstr
    ( "path" "path" "value" )
    swap base @ split swap pop
    swap me @ -rot setprop
    me @ swap nextprop
  repeat
  pop
 
  (* Set up description -- only if we need to.  The old morpher 's MPI
   * will work with the new morpher, and if we preserve the old morpher's
   * MPI, both morphers will continue to work.
   *
   * Don't do this when setting up globals
   *)
  base @ GLOBAL_ROOT strcmp if
    me @ "_/de" getpropstr "{my-desc}" strcmp if
      me @ "_/de" "{null:{tell:>>> {name:me} looked at you!,#" me @ intostr
      strcat "}}{list:" strcat base @ "/" rsplit pop strcat "}" strcat setprop
    then
  then
;
 
: morph ( s b -- ) (* Changes to the given description, showing messages if
                    * desired.  If b is true, show messages.
                    *)
  (* Does the description exist? *)
  swap dup me @ swap "_descs/" swap strcat "#" strcat propdir? not if
    pop pop
    "It doesn't look like you have a description by that name.  Try again?"
    tell exit
  then
  
  swap
  
  if
    dup me @ swap "_descs/" swap strcat "/message" strcat getpropstr
    dup strlen if
      tell
    else
      pop
      dup "Your description is now: " swap strcat tell
    then
    
    dup me @ swap "_descs/" swap strcat "/omessage" strcat getpropstr
    dup strlen if
      me @ name " " strcat swap strcat otell
    else
      pop
    then
  else
    dup "(Silent Change) Your description is now: " swap strcat tell
  then
  
  (* What's our current description if any?  Let's clean it up if needed *)
  me @ "_descs/prefs/current" getpropstr dup strlen if
    cleanup-description
  else
    pop
  then
  
  (* set globals *)
  GLOBAL_ROOT setup-description
  
  (* And the description itself *)
  dup "_descs/" swap strcat "/" strcat setup-description
  
  me @ swap "_descs/prefs/current" swap setprop
  (* Done! *)
;
 
: add-description ( -- ) (* Add a description for this user *)
  begin
    "Enter a name for the new description.  This is used to change descriptions"
    "in case you want to have multiple outfits.  It can have letters, numbers, "
    "- or _.  \"normal\" or \"dressed\" are good to start with."
    " "
    "If you want to cancel, type '.abort'."
    5 'cb-get-desc-name input-loop
 
    dup ".list" strcmp not if pop list-descriptions
    else dup ".abort" strcmp not if pop exit
    else
      (* Make a stub description so it shows up in the list *)
      dup me @ swap "_descs/" swap strcat "#" strcat "0" setprop
      dup add-or-edit-description
      "Would you like to switch to your new description?"
      "Type 'y'es or 'n'o."
      2 'cb-yes-no input-loop
      "y" 1 strncmp not if
        0 morph
      else
        pop
      then
      exit
    then then
  repeat
;
 
: edit-description ( -- ) (* Edit a description for this user *)
  begin
    "Type the name of the description you want to edit.  You can type '.list'"
    "to list your descriptions.  Descriptions are case insensitive."
    " "
    "If you want to cancel, type '.abort'."
    4 'cb-get-desc-name input-loop
  
    dup ".list" strcmp not if pop list-descriptions
    else dup ".abort" strcmp not if pop exit
    else add-or-edit-description exit
    then then
  repeat
;
 
: delete-description ( -- ) (* Deletes a description *)
  begin
    "Type the name of the description you want to delete.  You can type '.list'"
    "to list your descriptions.  Descriptions are case insensitive."
    " "
    "If you want to cancel, type '.abort'."
    4 'cb-get-desc-name input-loop
  
    dup ".list" strcmp not if pop list-descriptions
    else dup ".abort" strcmp not if pop exit
    else dup me @ swap "_descs/" swap strcat remove_prop
         me @ swap "_descs/" swap strcat "#" strcat remove_prop
         "Deleted!" tell exit
    then then
  repeat
;
 
: set-description ( -- ) (* Sets a description *)
  begin
    "Type the name of the description you want to change to.  You can type '.list'"
    "to list your descriptions.  Descriptions are case insensitive."
    " "
    "If you want to cancel, type '.abort'."
    4 'cb-get-desc-name input-loop
  
    dup ".list" strcmp not if pop list-descriptions
    else dup ".abort" strcmp not if pop exit
    else 1 morph exit
    then then
  repeat
;
 
: gen-menu ( tt -- tt ) (* Takes initialized tab toolkit 'object' and adds
                         * all the menu items to it
                         *)
  "1)  Toggle Color (Currently: " me @ "c" flag? if "ON)" else "OFF)" then strcat
  tt-tab-addline
 
  "2)  Toggle Can Be Handed Items (Currently: "
  IS_HAND_OK if "YES)" else "NO)" then strcat tt-tab-addline
 
  "3)  Toggle Can Fly (Currently: " IS_FLY_OK if "YES)" else "NO)" then strcat
  tt-tab-addline
 
  "4)  Toggle display current description on connect (Currently: "
  me @ "_descs/prefs/show_on_connect" getpropstr "yes" strcmp not if
    "YES)"
  else
    "NO)"
  then
  strcat tt-tab-addline
  
  "5)  Set default species (Currently: "
  me @ GLOBAL_ROOT "/spec" strcat getpropstr
  dup strlen not if
    pop "Unset"
  then
  strcat ")" strcat tt-tab-addline
 
  "6)  Set default gender (Currently: "
  me @ GLOBAL_ROOT "/sex" strcat getpropstr
  dup strlen not if
    pop "Unset"
  then
  strcat ")" strcat tt-tab-addline
  
  "7)  Set Default Scent, Touch, or Feel" tt-tab-addline
 
  "8)  Set default description/morph that is set when you connect"
  tt-tab-addline
  
  "9)  Set default description/morph that is set when you disconnect"
  tt-tab-addline
 
  "10) Change RIDE messages (Currently: " which-ride-message strcat ")" strcat
  tt-tab-addline
  
  "11) Set 'doing' message for your entry on the WHO list." tt-tab-addline
  
  "12) Make items in your inventory lookat-able" tt-tab-addline
  
  "13) Set Detail Messages that work on all descriptions (\"Looktraps\")"
  tt-tab-addline
  
  " " tt-tab-addline
    
  "L) List your descriptions/morphs" tt-tab-addline
  "A) Add new description/morph" tt-tab-addline
  "E) Edit existing description/morph" tt-tab-addline
  "D) Delete description/morph" tt-tab-addline
  "S) Set current description/morph (Currently: " which-morph strcat ")" strcat
  tt-tab-addline
;
 
: editplayer ( -- ) (* Main editplayer loop *)
  begin
    "Character Editor" 75 tt-tab-init
    gen-menu
    "<Pick an Option or 'Q' to Quit>" tt-tab-final-flush
    read strip tolower
    
    dup "q" strcmp not if
      pop "Exiting!" tell exit
    else dup "l" strcmp not if
      pop list-descriptions
    else dup "a" strcmp not if
      pop add-description
    else dup "e" strcmp not if
      pop edit-description
    else dup "d" strcmp not if
      pop delete-description
    else dup "s" strcmp not if
      pop set-description
    else atoi dup 1 = if
      pop
      me @ "c" flag? if
        me @ "!c" set "You won't see color anymore." tell
      else
        me @ "c" set "You will now see colors." tell
      then
    else dup 2 = if
      pop
      IS_HAND_OK if
        SET_HAND_NOK "You can no longer be handed things." tell
      else
        SET_HAND_OK "You can now be handed things." tell
      then
    else dup 3 = if
      pop
      IS_FLY_OK if
        SET_FLY_NOK "I believe you can't fly." tell
      else
        SET_FLY_OK "I believe you can fly." tell
      then
    else dup 4 = if
      pop
      me @ "_descs/prefs/show_on_connect" getpropstr "yes" strcmp not if
        me @ "_descs/prefs/show_on_connect" remove_prop
        "Your description setting won't show when you connect." tell
      else
        me @ "_descs/prefs/show_on_connect" "yes" setprop
        "Your description will be shown when you connect." tell
      then
    else dup 5 = if
      pop
      "This sets your default species.  Your individual descriptions can"
      "override this setting if you want, but if your species is usually"
      "or always the same, you can just set this default and not worry"
      "about it.  Type '.abort' to do nothing or '.clear' to clear it."
      4 'cb-get-any-string input-loop
      strip
      dup ".abort" strcmp not if
        pop "Aborting." tell
      else dup ".clear" strcmp not if
        pop me @ "_descs/prefs/global/spec" remove_prop
        "Clearing default species." tell
      else
        me @ swap "_descs/prefs/global/spec" swap setprop
        "Species set." tell
      then then
      
      (* If there's no species set, let's go ahead and set it *)
      me @ "species" getpropstr strlen not if
        me @ "species"
        me @ "_descs/prefs/global/spec" getpropstr setprop
      then
    else dup 6 = if
      pop
      "This sets your default gender.  Your individual descriptions can"
      "override this setting if you want, but if your gender is usually"
      "or always the same, you can just set this default and not worry"
      "about it.  Type '.abort' to do nothing or '.clear' to clear it."
      4 'cb-get-any-string input-loop
      strip
      dup ".abort" strcmp not if
        pop "Aborting." tell
      else dup ".clear" strcmp not if
        pop me @ "_descs/prefs/global/sex" strcat remove_prop
        "Clearing default gender." tell
      else
        me @ swap "_descs/prefs/global/sex" swap setprop
        "Gender set." tell
      then then
      
      (* If there's no gender set, let's go ahead and set it *)
      me @ "sex" getpropstr strlen not if
        me @ "sex"
        me @ "_descs/prefs/global/sex" getpropstr setprop
      then
    else dup 7 = if
      pop GLOBAL_ROOT set-senses
    else dup 8 = if
      pop
      begin
        "It can be embarassing to be in the wrong description when you first"
        "connect!  Currently, it is: "
        me @ "_descs/prefs/desc_on_connect" getpropstr dup strlen not if
          pop "(Unset)"
        then
        strcat
        "Type the name of the description you'd like to set when you connect."
        "Or, type '.list' to see all your description names, '.clear' to"
        "clear the current setting, or '.abort' to abort with no change."
        5 'cb-get-any-string input-loop
        dup ".abort" strcmp not if
          pop "Aborting." tell break
        else dup ".clear" strcmp not if
          pop me @ "_descs/prefs/desc_on_connect" remove_prop
          "Clearing description on connect." tell break
        else dup ".list" strcmp not if
          pop
          list-descriptions
        else
          dup me @ swap "_descs/" swap strcat "#" strcat propdir? not if
            pop
            "That isn't a description you have set.  Type '.list' to list them!"
            tell
          else
            me @ swap "_descs/prefs/desc_on_connect" swap setprop
            "Set!" tell
            break
          then
        then then then
      repeat
    else dup 9 = if
      pop
      begin
        "If you like, you can have a description set when you disconnect."
        "This could be like a 'sleeping description', or you cna just make"
        "sure you're in a certain description when go offline.  It works well"
        "in tandem with the connection description."
        "It is currently set to: "
        me @ "_descs/prefs/desc_on_disconnect" getpropstr dup strlen not if
          pop "(Unset)"
        then
        strcat
        "Type the name of the description you'd like to set when you disconnect."
        "Or, type '.list' to see all your description names, '.clear' to clear"
        "the current setting, or '.abort' to abort with no change."
        8 'cb-get-any-string input-loop
        dup ".abort" strcmp not if
          pop "Aborting." tell break
        else dup ".clear" strcmp not if
          pop me @ "_descs/prefs/desc_on_disconnect" remove_prop
          "Clearing description on connect." tell break
        else dup ".list" strcmp not if
          pop
          list-descriptions
        else
          dup me @ swap "_descs/" swap strcat "#" strcat propdir? not if
            pop
            "That isn't a description you have set.  Type '.list' to list them!"
            tell
          else
            me @ swap "_descs/prefs/desc_on_disconnect" swap setprop
            "Set!" tell
            break
          then
        then then then
      repeat
    else dup 10 = if
      pop
      "RIDE is used to let you lead another character along with you.  There"
      "are several different sets of default messages you can use for RIDE."
      "Currently, you're using:" which-ride-message strcat
      "You may pick from one of: " RIDE_MODES ", " array_join strcat
      "Pick a mode, or '.abort' to leave the current setting."
      5 'cb-pick-ride-mode input-loop
      dup ".abort" strcmp not if
        pop "Aborting." tell
      else
        me @ swap "RIDE/_mode" swap setprop
        "Set!" tell
      then
    else dup 11 = if
      pop
      "Doing messages show up on the WHO listing.  Yours is set to:"
      me @ "_/do" getpropstr dup strlen not if
        pop "(Unset)"
      then
      "Type a message, or use '.abort' to abort."
      3 'cb-get-any-string input-loop
      dup ".abort" strcmp not if
        pop "Aborting!" tell
      else
        me @ swap "_/do" swap setprop "Set!" tell
      then
    else dup 12 = if
      pop
      "The 'lookat' command can allow people to look at the items you are"
      "carrying.  It is also possible to set this per inventory item if "
      "you wish -- see 'lookat #help' for instructions."
      " "
      "You are currently set to: "
      me @ "_remote_look?" getpropstr "yes" strcmp not if
        "let people see your items." strcat
      else
        "not let people see your items." strcat
      then
      " "
      "Do you want to let people see your inventory?  Type 'y'es or 'n'o."
      7 'cb-yes-no input-loop
      "y" 1 strncmp not if
        me @ "_remote_look?" "yes" setprop
        "People will be able to lookat items in your inventory." tell
      else
        me @ "_remote_look?" "no" setprop
        "People will not be able to lookat items in your inventory." tell
      then
    else dup 13 = if
      pop GLOBAL_ROOT "_details/" strcat modify-looktraps
      me @ "_descs/prefs/current" getpropstr dup strlen if
        "Applying your looktrap changes!" tell
        0 morph
      else
        pop
        (* This should just set looktraps *)
        GLOBAL_ROOT setup-description
      then
    else
      pop "Invalid option.  Try again!" tell
    then then then then then then then then then then then then then then
    then then then then then
  repeat
;
 
: main ( s -- )
  command @ "Queued event." strcmp not if
    dup "Connect" strcmp not if
      pop
      me @ "_descs/prefs/desc_on_connect" getpropstr dup strlen if
        0 morph
      else
        pop
      then
      me @ "_descs/prefs/show_on_connect" getpropstr "yes" strcmp not if
        "You description is currently: "
        me @ "_descs/prefs/current" getpropstr strcat tell
      then
      exit
    then
  
    dup "Disconnect" strcmp not if
      pop
      me @ "_descs/prefs/desc_on_disconnect" getpropstr dup strlen if
        0 morph
      else
        pop
      then
      exit
    then
  then
  
  (* If they haven't used this program yet, then let's set some reasonable
   * defaults.
   *)
  me @ "_descs/prefs/newmorph" getpropstr strlen not if
    me @ "species" getpropstr strlen
    me @ GLOBAL_ROOT "spec" strcat getpropstr strlen not and if
      me @ GLOBAL_ROOT "spec" strcat
      me @ "species" getpropstr setprop
    then
  
    me @ "sex" getpropstr strlen
    me @ GLOBAL_ROOT "sex" strcat getpropstr strlen not and if
      me @ GLOBAL_ROOT "sex" strcat
      me @ "sex" getpropstr setprop
    then
    
    me @ "_descs/prefs/newmorph" "yes" setprop
  then
  
  dup strlen not if
    pop editplayer exit
  else dup "#list" strcmp not if
    pop list-descriptions exit
  else dup "#help" strcmp not if
    pop help exit
  else dup "#edit" strcmp not if
    pop edit-description exit
  else dup "#delete" strcmp not if
    pop delete-description exit
  else dup "#add" strcmp not if
    pop add-description exit
  else dup "#status" strcmp not if
    pop
    "Morph Status" 70 tt-tab-init
    "Your current description: " me @ "_descs/prefs/current" getpropstr strcat
    tt-tab-addline
    "You may see a list of descriptions with: " command @ strcat " #list" strcat
    tt-tab-addline
    
    me @ "_descs/prefs/desc_on_connect" getpropstr dup strlen if
      swap " " tt-tab-addline
      swap
      "On connect, your description will be: " swap strcat tt-tab-addline
    else
      pop
    then
 
    me @ "_descs/prefs/desc_on_disconnect" getpropstr dup strlen if
      swap " " tt-tab-addline
      swap
      "On disconnect, your description will be: " swap strcat tt-tab-addline
    else
      pop
    then
    "" tt-tab-final-flush
  else
    command @ tolower "q" 1 strncmp morph
  then then then then then then then
;
