( ObvExits.muf     by Gyroplast   10/17/00     v2.15
  Shows exits in a room beneath the description.
 
  Wizards are encouraged to register this program as $obvexits, since
  this is an inofficial established standard.
  To show exits in your room, set it's SUCC to @$obvexits, ex.:
    @succ here=@$obvexits
 
  ** DETAILED HELP AVAILABLE BY RUNNING THE PROGRAM FROM AN ACTION **
 
  If you dont want an exit to show up in the list, set it DARK or set
  the _invisible property to 'yes'. ex:  @set <exit>=_invisible:yes
 
  To show an exit regardless of where it's linked to, set the
  _visible property to 'yes'. ex:  @set <exit>=_visible:yes
 
  If you'd like a different prefix than "Exits: ", set it into the
  _obvexits/prefix property on the room. "Exits: " is default.
    ex: @set <room>=_obvexits/prefix:Obvious Exits:
 
  The string added between the exits can be set by changing the
  _obvexits/delimiter property. If it's not set, the default define below
  will be used. 
  
  The program will look thru the whole environment for any settings.
)
 
$def USEANSI                   ($undef this if you dont want ANSI )
 
$def HEADER "ObvExits v2.15 by Gyroplast@FuzzyLogic"
 
$ifdef USEANSI
$include $lib/ansi
 
  $def PFX_DEF_COLOR "160"     ( Default color for "Exits: " prefix )
  $def EXT_DEF_COLOR "140"     ( Default color for exits themselves )
  $def PRG_DEF_COLOR "060"     ( Default color for program actions )
  $def DRK_DEF_COLOR "200"     ( Default color for invisible exits )
  $def DLM_DEF_COLOR "160"     ( Default color for exit delimiter )
  $def UNL_DEF_COLOR "510"     ( Default color for unlinked exits )
  $def RST           "~&R"     ( ANSI reset code )
  
  $def HEADER "ObvExits v2.15 by Gyroplast@FuzzyLogic  [ ANSI ENABLED ]"
$endif
 
$def ScreenWidth 76            ( needed for line wrapping function )
$def DefaultPrefix    "Exits:" ( string prefixing the exitlist )
$def DefaultDelimiter "  -  "  ( string catted between exits )
LVAR ListString                ( string containing exitlist )
LVAR ListLength                ( needed for line wrapping function )
(   ExitVisible?
    This function is pretty much the heart of the program. If you dont like
    how the determination of visibility is handled, or you need other/more
    _visible properties on your muck, you should edit this function
    accordingly. It's kept rather linear for this purpose.
)
: ExitVisible? ( [ d -- b ] - Is exit d shown in the list? )
  ( 1. Wizzes and owners _always_ see exits, if their debug prop is set. )
  me @ "W" flag?       ( is wizzard.. )
  over owner me @ owner dbcmp OR   ( .. OR owner? )
  me @ "_obvexits/debug" getpropstr ( ..AND has debug flag set? )
  "y" stringpfx 1 = AND   
  if
    pop 1 exit                      ( show da dark stuph! )
  then
 
  ( 2. Exits set DARK are invisible, regardless of props. )
  dup "D" flag? if
    pop 0 exit
  then
 
  ( 3. Check for properties. )
  ( These properties are to be used to force display of an exit before )
  ( the 'sanity' routines rule them out later. Used for program links. )
 
  dup 
  "_visible?" getpropstr 
  "y" stringpfx 1 = if      ( '_visible?' set to 'yes' ?)
    pop 1 exit
  then
 
  dup 
  "_visible" getpropstr 
  "y" stringpfx 1 = if      ( '_visible' set to 'yes' ?)
    pop 1 exit
  then
 
  dup 
  "visible" getpropstr 
  "y" stringpfx 1 = if      ( 'visible' set to 'yes' ?)
    pop 1 exit
  then
  
 
  ( 4. We dont need to show unlinked exits, do we. Of course not.  )
  (    Only links to rooms will be shown unless a property is set. )
  (    This might cause major confusion to unsuspecting people!    )
  dup getlink room? not if
    pop 0 exit
  then 
 
  pop 1                     ( exit is by default visible )
;
 
: GetExitName  ( [ d -- s ] - Return first name part of exit d )
$ifdef USEANSI
  dup
$endif
 
  name
  dup ";" instr dup if
    1 - strcut
  then
  pop
 
$ifdef USEANSI
 
  over "d" flag? if              ( Check is exit is dark )
    RST strcat                   ( Append reset code )
    swap "_obvexits/color/dark"  ( get custom DARK EXIT color.. )
    envpropstr                   ( ..from the exit down the environment )
    dup not if                   
      pop DRK_DEF_COLOR          ( nothing found, use default )
    then
    swap pop                     ( cleanup )
    "~&" swap strcat             ( prepend ansi code )
    swap strcat                  ( prepend complete ansi color code to name )
    exit                         ( we're done here )
  then
 
  over getlink program? if       ( Repeat above procedure for exit->prog )
    RST strcat
    swap "_obvexits/color/program"
    envpropstr
    dup not if
      pop PRG_DEF_COLOR
    then
    swap pop
    "~&" swap strcat
    swap strcat
    exit
  then
  
  over getlink #-1 dbcmp if 
    RST strcat
    swap "_obvexits/color/unlinked"
    envpropstr
    dup not if
      pop UNL_DEF_COLOR
    then
    swap pop
    "~&" swap strcat
    swap strcat
    exit
  then
 
  RST strcat                   ( finally ansify any other exit with defaults )
  swap "_obvexits/color/normal"
  envpropstr
  dup not if
    pop EXT_DEF_COLOR
  then
  swap pop
  "~&" swap strcat
  swap strcat
$endif
;
 
: GetDelimiter ( [  -- s ] - Return exit delimiter )
  trigger @ "_obvexits/delimiter" envpropstr
  dup not if
    pop DefaultDelimiter
  then
  swap pop
 
$ifdef USEANSI
  RST strcat
  
  trigger @ "_obvexits/color/delimiter"
  envpropstr
  dup not if
    pop DLM_DEF_COLOR
  then
  swap pop
  "~&" swap strcat
  swap strcat
$endif
;
 
: GetPrefix  ( [  -- s ] - Return ObvExits listprefix )
  trigger @ 
  "_obvexits/prefix" envpropstr
 
  dup not if
    pop DefaultPrefix
  then
  swap pop
 
$ifdef USEANSI
  RST strcat
  
  trigger @ "_obvexits/color/prefix"
  envpropstr
  dup not if
    pop PFX_DEF_COLOR
  then
  swap pop
  "~&" swap strcat
  swap strcat
$endif
;
 
: ListEmpty?  ( [  -- b ] - Check if no exits have been added to the list )
  GetPrefix " " strcat    ( create a string equal to an empty list )
  ListString @ strcmp     ( compare it with our current list )
  not                     ( invert returned 0 -> 1 if no difference )
;
 
: NewLine  ( [  --  ] - Start new line in ListString )
  ListString @    ( get list and add a newline )
  "\r" strcat
  ( now indend the new line, ie. get length of prefix and add 'strlen' spaces )
  "                                                                         "
  GetPrefix strlen 1 +
$ifdef USEANSI
  8 - 
$endif 
  dup ListLength !        ( store length of padding in listlength )
  strcut pop
  strcat
  ListString !
;
 
: ExceedWidth?  ( [ s -- b ] - Does ListString + s exceed ScreenWidth? )
  strlen 1 +                 ( get effective length of exit name )
$ifdef USEANSI
  8 -
$endif 
  dup 
  ListLength @ +             ( add to listlength and keep a copy for later )
  ListLength !               ( store updated listlength )
  
  ScreenWidth > if           ( see if exit alone is longer than allowed )
    0 exit                   ( return 0 if it is to avoid endless loop )
  then
 
  ListLength @ ScreenWidth >   ( final comparison )
;
 
: AddToList  ( [ s --  ] - Add exitname s to liststring )
  dup ExceedWidth? if     ( does the list exceed max width with new exit? )
    NewLine               ( yup, it does. Start new line. )
    ListString @          ( Get the liststring )
    swap strcat           ( Add exit to the list in the new line w/o delimiter )
  else
    ListString @          ( nope, does not exceed maxwidth )
    ListEmpty? not if     ( only cat delimiter if list is not empty )
      GetDelimiter strcat ( cat delimiter )
                          ( Add effective delimiter length to listlength )
      ListLength @        ( fetch old length )  
      GetDelimiter        ( retrieve delimiter and substract length of ansi )
      strlen 1 +          ( add effective delimiter length to listlength )
 $ifdef USEANSI
   8 - 
 $endif 
      +
      ListLength !        ( store listlength )
    then
    swap strcat           ( cat exit )
  then
 
  ListString !            ( store edited list anew )
;
 
: BuildList-loop  ( [  --  ] - Main function for list assembly )
  GetPrefix " " strcat      ( get optional custom prefix, add space )
  dup ListString !          ( initialize liststring )
  strlen 1 +
$ifdef USEANSI
  8 -
$endif 
  ListLength !              ( init listlength with length of prefix - ansi )
 
  trigger @ exits       ( get first exit in current room )
  BEGIN
    dup #-1 dbcmp not while ( while we can get valid exits... )
 
    dup ExitVisible? if     ( ...check if the exit to be shown. )
      dup                   ( Keep a copy of the dbref for 'next' )
      GetExitName           ( self explanatory.. )
      AddToList             ( also self explanatory.. isnt this simple? ;)
    then
    next                    ( get next exit's dbref )
  REPEAT
  pop                       ( pop off the #-1 )
  ListEmpty? if             ( if no exits have been added... )
    "None" AddToList        ( ...tell us their are no obvious exits. )
  then
 
  ListString @
  me @ swap                 ( Finally! Print out the freakin' list! )
$ifdef USEANSI
  ansi_notify
$else
  notify
$endif
;
: Underline  ( [ s -- s' ] - Generate a line as long as s )
  strlen 1 +
  "---------------------------------------------------------------------"
  swap strcut pop
;
: ShowGeneralHelp  ( helpscreen one )
  HEADER dup tell
  Underline tell
  " " tell
  "          GENERAL HELP AND USAGE" tell
  " " tell
  "   This is a highly customizable, intelligent and hopefully fool" tell
  "   proof implementation of the well known ObviousExits concept," tell
  "   supporting ANSI optionally." tell
  " " tell
  "   To enable ObvExits in your room(s), @succ <room>=@$obvexits" tell
  "   To disable it again, just type @succ <room>=" tell
  " " tell
  "   You can find out more about general customization in #help2" tell
  " " tell
;
: ShowHelp2
  HEADER dup tell
  Underline tell
  " " tell
  "          CUSTOMIZING THE APPEARANCE OF THE EXIT LIST" tell
  " " tell
  "   The exit list shown to the looker is split into three parts." tell
  "   1) The prefix (default: \"Exits: \")" tell
  "   2) The exits themselves" tell
  "   3) The exit delimiter shown between the exits (default: \"  -  \")" tell
  " " tell
  "   You can customize 1) and 3) to your liking. For reference:" tell
  "     Prefix:     _obvexits/prefix" tell
  "     Delimiter:  _obvexits/delimiter" tell
  " " tell
  "   Simply set these properties to whatever you want them to be." tell
  "   The name of the exits shown is determined by the name of the" tell
  "   action attached to the room. The first name will be used, so" tell
  "   \"<O>ut;out;o\" will be shown as just \"<O>ut\"." tell
  " " tell
  "   You can set these props anywhere in your environment, the program" tell
  "   will look for them down from the room the looker is in." tell
  "   That way it's trivial to use custom strings for a whole area." tell
  " " tell
  "   To make an exit visible if it's not by default, set the _visible?" tell
  "   property on it to 'yes'." tell
  " " tell
  "   For information on how to change colors, see #help3." tell
  " " tell
;
: ShowHelp3
  HEADER dup tell
  Underline tell
  " " tell
  "          CUSTOMIZING COLORS (OR: THE ART OF USING ANSI)" tell
  " " tell
  "   If you do not like the built-in ANSI color defaults (shame on you!)," tell
  "   you can of course change them, even give every single exit a different" tell
  "   color if you please. To do that, a couple properties are available" tell
  "   to be set somewhere in the environment down from the exit itself." tell
  " " tell
  "   Prefix         :  _obvexits/color/prefix" tell
  "   Delimiter      :  _obvexits/color/delimiter" tell
  "   Normal Exits   :  _obvexits/color/normal" tell
  "   Dark Exit      :  _obvexits/color/dark" tell
  "   Program Action :  _obvexits/color/programs" tell
  "   Unlinked Exit  :  _obvexits/color/unlinked" tell
  " " tell
  "   These properties take a 3 digit ansi color code like 010 for dark red." tell
  " " tell
  "   Only wizzes or exit owners see DARK/unlinked exits, if they set the" tell
  "   _obvexits/debug flag on them to 'yes'. (@set me=_obvexits/debug:yes)" tell
  " " tell
;
: main
  dup not trigger @ exit? not AND if 
    BuildList-loop exit 
  then
  
  dup "#help" stringcmp not if
    pop ShowGeneralHelp exit
  then
  
  dup "#help2" stringcmp not if
    pop ShowHelp2 exit
  then
 
  dup "#help3" stringcmp not if
    pop ShowHelp3 exit
  then
  
  ShowGeneralHelp
;