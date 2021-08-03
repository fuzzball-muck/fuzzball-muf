( TabToolkit.lib -- Library for handling the fun little tab ASCII layouts )
( and other similar GUI-ish elements.                                     )
( =[c]2019 HopeIslandCoder=============================================== )
( LICENSE: PUBLIC DOMAIN                                                  )
(                                                                         )
( FUNCTIONS                                                               )
(                                                                         )
( tt-make-underline [ length -- string ]                                  )
( Makes an underline string "length" long.                                )
(                                                                         )
( tt-make-line [ length -- string ]                                       )
( Makes an dash string "length" long.                                     )
(                                                                         )
( tt-make-space [ length -- string ]                                      )
( Makes an space string "length" long.                                    )
(                                                                         )
( tt-shave-to-len [ string length -- string' ]                            )
( Either cuts the string down to length "length" or pads it as needed.    )
(                                                                         )
( tt-tab-init [ title width -- a ]                                        )
( Initializes a "tab window" -- basically makes the header portion.       )
( The title is what goes in the tab title, the width is the overall       )
( width of the tab box in characters [should be under 75 characters for   )
( total compatability].  Returns a dictionary that should be passed into  )
( all tab functions.  If the title is blank, it will just make a square.  )
(                                                                         )
( tt-tab-addline [ tab message -- d ]                                     )
( This adds a line to the tab window.  Note the line will be truncated if )
( it is too long.  The line will have 2 characters worth of space both    )
( before and after it, so the maximum length is "width-4".                )
(                                                                         )
( tt-tab-addline-wrap [ tab message -- d ]                                )
( This wraps a line to fit the tab window.  It will try to wrap the line  )
( as smartly as it can and use as many lines as it needs.                 )
(                                                                         )
( tt-tab-flush [ tab -- d ]                                               )
( "flushes" the tab to screen, therefore displaying it.  Whatever has     )
( been flushed will not be re-displayed if flushed again.                 )
(                                                                         )
( tt-tab-finalize [ tab message -- d ]                                    )
( Puts the closing "pane" on the bottom of the tab window.  Optionally    )
( embeds a message in the pane.                                           )
(                                                                         )
( tt-tab-final-flush [ tab message -- ]                                   )
( Runs tt-tab-finalize then tt-tab-flush, eating the tab in the process.  )
(                                                                         )
( tt-custom-init [ header prefix suffix inner-width min-height max-height )
(                  -- tab ]                                               )
( This allows Tab Toolkit to create a custom "user interface".  Header    )
( should be an array of strings containing the header banner that will be )
( rendered first.  Prefix / suffix will be prepended / appeneded to each  )
( line.  inner-width is the desired width between prefix and suffix.      )
( min-height and max-height are used to control the minimum and maximum   )
( size of the text area -- either of these can be 0 to disable the limit. )
(                                                                         )
( tt-custom-final-flush [ tab footer -- ]                                 )
( This finalizes [and consumes] a tab object.  'footer' should be an      )
( array of lines to go as a custom footer on the tab object.              )
( If you just want to flush, use tt-tab-flush.  If you just want to       )
( finalize, use array_notify to output your footer yourself.              )
 
: tt-make-underline ( i -- s' ) ( makes an underline i long)
  dup not if
    pop "" exit
  then
  ""
  begin
    "_" strcat
    swap 1 - dup while
    swap
  repeat
  pop
;
 
: tt-make-space ( i -- s' ) ( Makes a series of spaces i long )
  dup not if
    pop "" exit
  then
  ""
  begin
    " " strcat
    swap 1 - dup while
    swap
  repeat
  pop
;
 
: tt-make-line ( i -- s' ) ( Makes a series of dashes i long )
  dup not if
    pop "" exit
  then
  ""
  begin
    "-" strcat
    swap 1 - dup while
    swap
  repeat
  pop
;
 
: tt-shave-to-len[ string length -- s' ] ( Shaves 's' down to len i )
  string @ strlen length @ > if
    string @ length @ strcut pop exit
  then
  string @ length @ string @ strlen - tt-make-space strcat
;
 
: tt-tab-init[ title width -- d ] ( Initializes a standard tab window )
  {
        "width" width @ 4 -
        "prefix" "| "
        "suffix" " |"
        "min-height" 0
        "max-height" 0
        
        title @ strlen if
          "counter" 2
          0 "   _" title @ strlen 1 + tt-make-underline strcat
          1 " _/ " title @ strcat " \\" strcat
          dup strlen width @ swap - 1 - tt-make-underline strcat
          "header-size" 2
        else
          "counter" 1
          0 " " width @ 2 - tt-make-underline strcat
          "header-size" 1
        then
  }dict
;
 
: at-maximum? ( tab -- b ) ( Are we at maximum window size? )
  dup "max-height" [] dup
  rot "counter" [] <=
  and
;
 
: tt-tab-addline[ tab message -- d ] ( Adds a line to the tab window )
  tab @ "width" [] var! width
  tab @ "counter" [] var! counter
  
  ( Check max size )
  tab @ at-maximum? if
    ( Can't add another one -- just return the dict )
    tab @ exit
  then
  
  tab @ "prefix" [] message @ width @ tt-shave-to-len strcat
  tab @ "suffix" [] strcat
  tab @ counter @ array_insertitem
  counter @ 1 + swap "counter" array_setitem
;
 
: tt-tab-addline-wrap[ tab message -- d ] ( Adds a word-wrapped line to tab )
  var line
  var cur
  tab @ "width" [] var! width
  tab @ "counter" [] var! counter
  
  ( Message doesn't need wrapping )
  message @ strlen width @ <= if
    tab @ message @ tt-tab-addline exit
  then
  
  tab @ at-maximum? if
    tab @ exit ( Nothing to add )
  then
  
  "" line !
  "" cur !
  begin
    message @ strlen cur @ strlen or while
    
    cur @ strlen not if
      message @ " " split message ! cur !
    then
    
    cur @ strlen not if
      message @ " " instring if ( Two spaces in a row )
        " " cur !
      else
        message @ cur !
      then
    then
    
( Always include 1 more thingie for the space )
    line @ strlen cur @ strlen + 1 + width @ > if
      line @ strlen if
        tab @ line @ tt-tab-addline tab !
      then
      
      cur @ strlen width @ > if
        cur @ width @ strcut cur ! tab @ swap tt-tab-addline tab !
      else
        cur @ line ! "" cur !
      then
    else
      line @ strlen if
        line @ " " strcat cur @ strcat line ! "" cur !
      else
        cur @ line ! "" cur !
      then
    then
  repeat
  line @ strlen if
    tab @ line @ tt-tab-addline tab !
  then
  
  tab @
;
 
: tt-tab-flush[ tab -- d ] ( "flushes" the tab to screen )
  tab @ "counter" [] var! counter
  
  ( Do we need more lines? )
  tab @ "min-height" [] counter @ > if
    begin
      tab @ "min-height" []
      tab @ "counter" []
      > while
      tab @ "" tt-tab-addline tab !
    repeat
    
    tab @ "counter" [] counter !
  then
  
  0
  begin
    dup counter @ < while
    dup tab @ swap [] tell
    1 +
  repeat
  pop
  
  0 tab @ "counter" array_insertitem 
;
 
: tt-tab-finalize[ tab message -- d ] ( Puts the closing line on a tab window )
  tab @ "width" [] var! width
  tab @ "counter" [] var! counter
  
  message @ strlen not if
    " " width @ 2 + tt-make-line strcat
  else
    " -" message @ strcat dup strlen width @ swap -
    3 + tt-make-line strcat
  then
  
  tab @ counter @ array_insertitem
  counter @ 1 + swap "counter" array_setitem
;
 
: tt-tab-final-flush ( tab message -- ) ( Finalizes and flushes the tab )
  tt-tab-finalize tt-tab-flush pop
;
 
: tt-custom-init[ header prefix suffix innerWidth minHeight maxHeight ]
  ( Use header as a base array )
  header @ array_explode array_make_dict
  
  dup array_count swap "header-size" array_insertitem
  dup array_count 1 - swap "counter" array_insertitem
  innerWidth @ swap "width" array_insertitem
  prefix @ swap "prefix" array_insertitem
  suffix @ swap "suffix" array_insertitem
  
  ( Add header size to min and max height because otherwise the header
    will count against these numbers. )
  minHeight @ if
    dup "header-size" [] minHeight @ +
  else
    0
  then
  swap "min-height" array_insertitem

  maxHeight @ if
    dup "header-size" [] maxHeight @ +
  else
    0
  then
  swap "max-height" array_insertitem
;
 
: tt-custom-final-flush ( tab footer -- )
  ( Flush the array )
  swap tt-tab-flush pop
  
  ( Output the footer as is )
  { me @ }list array_notify
;
 
 
public tt-tab-final-flush
public tt-tab-finalize
public tt-tab-flush
public tt-tab-addline-wrap
public tt-tab-addline
public tt-tab-init
public tt-shave-to-len
public tt-make-space
public tt-make-underline
public tt-make-line
public tt-custom-init
public tt-custom-final-flush

$libdef tt-tab-final-flush
$libdef tt-tab-finalize
$libdef tt-tab-flush
$libdef tt-tab-addline-wrap
$libdef tt-tab-addline
$libdef tt-tab-init
$libdef tt-shave-to-len
$libdef tt-make-space
$libdef tt-make-underline
$libdef tt-make-line
$libdef tt-custom-init
$libdef tt-custom-final-flush
