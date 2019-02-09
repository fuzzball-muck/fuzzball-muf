( Verbatim. cmd-quote replacement. Preserves blank lines, allows quoting to 
a person or group. Allows for color, if the local server supports or
$lib/ansi is present.
 
Given as a gift to SpinDizzy from Winter's Oasis.
 
Relink your old quote action to it, and set it W. This is needed for the
    pmatch functionality.

Set PAGE to the DBREF of the page program, or a regname that matches.

And now for the boring legal stuff...

  Copyright [c] 2011, Kelketek of Winter's Oasis
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of Kelketek nor Winter's Oasis nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL KELKETEK OR WINTER'S OASIS BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  [INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION] HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  [INCLUDING NEGLIGENCE OR OTHERWISE] ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

)

$include $lib/case
$version 1.0
$author "Kelketek of Winter's Oasis."

$def PAGE "$cmd/page" match
$def IGNOREPROP { swap "ignore#" swap intostr }cat
$def VERBATIMDIR "_verbatim"
$def LASTGROUP VERBATIMDIR "/lastgroup" strcat
$def MAX_QUOTE_LINES 256 ( MAximum lines for a quote. Change as needed for your server. Set to INF if unneeded. )
$def TRUE 1
$def FALSE 0 ( These are not included on standard MUCK installations. Can't depend on them to be there. )

lvar color_on

( The following definitions exist to add support for color depending on platform. )

$def vnotify notify
$def vnotify_exclude notify_exclude
$def vtell me @ swap notify
$def votell loc @ me @ 1 4 rotate notify_exclude

( $echo Checking for native support of ANSI colors... )
$ifdef __neon ( Should include ProtoMUCK and NeonMUCK )
    $define vnotify
        color_on @ if
            ansi_notify
        else
            notify
        then
    $enddef
    $define vnotify_exclude
        color_on @ if
            ansi_notify_exclude
        else
            notify_exclude
        then
    $enddef
    $def vtell me @ swap vnotify
    $def votell loc @ me @ 1 4 rotate vnotify_exclude
    $def COLOR_SUPPORT TRUE
    ( $echo ...Server supports. )
$else
    ( $echo ...Server does not natively support color. )
$endif

$iflib $lib/ansi ( All the standard color libs that I could find used this regname. )
    $include $lib/ansi
    $define vnotify
        color_on @ if
            ansi-notify
        else
            notify
        then
    $enddef
    $define vnotify_exclude
        color_on @ if
            ansi-notify-exclude
        else
            notify_exclude
        then
    $enddef
    $def vtell me @ swap vnotify
    $def votell loc @ me @ 1 4 rotate vnotify_exclude
    $ifdef COLOR_SUPPORT
        ( $echo ...Color supported by server, but $lib/ansi is present. Using this instead. )
    $else
        ( $echo ...$lib/ansi detected. Color support enabled. )
    $endif
    $def COLOR_SUPPORT TRUE
$endif
$ifdef COLOR_SUPPORT
    ( $echo ...Color support enabled! )
$else
    ( $echo ...$lib/ansi not found. Verbatim will compile, but will not support color. )
$endif 

( $echo Checking for Lib-Antiflood... )
$iflib $lib/antiflood
    $include $lib/antiflood
    ( $echo ...Lib-antiflood found. Enabling anti-flood technology. )
$else
    ( $echo ...Lib-Antiflood not present. Verbatim will compile, but will not throttle users. )
$endif

lvar target_list
lvar arg
lvar targetstr

: targets_string ( @ -- ) ( Properly lists names. )
    var! targets
    targets @ array_count case
       1 = when { targets @ array_vals pop }cat end
       2 = when { targets @ array_vals pop " and " swap }cat end
       default
           pop targets @ array_count 2 - targets @ swap array_cut var! tail var! head ( Separate the last two items )
           {
               {
                   head @ foreach
                       swap pop name "," strcat
                   repeat
               }list " " array_join " "
           { tail @ array_vals pop " and " swap }cat
           }list "" array_join
       end
    endcase
;

: telltarget[ str:line ] ( Does the actual telling. )
    var target
    target_list @ not if
       line @ dup vtell votell exit
    then

    target_list @ foreach
       swap pop target !
       target @ me @ dbcmp not if
           target @ line @ vnotify
       then
    repeat
    line @ vtell
;

: targeter[ str:item -- (d) ] ( Validates a target )
    var target
    item @ "" strcmp not if
        exit
    then
    item @ match target !
    target @ ok? not if
        item @ part_pmatch target !
    then
    target @ ok? if
        target @ player? not if
            { target @ " is not a valid target for quote." }cat vtell exit
        then
    else
        { item @ " not found, invalid or ambiguous." }cat vtell exit
    then
    target @ "HAVEN" flag? if
        { target @ " is set HAVEN and will not be disturbed." }cat vtell exit
    then
    target @ awake? not if
        { target @ " is asleep." }cat vtell exit
    then
    $ifdef PAGE
        PAGE target @ IGNOREPROP me @ reflist_find if
            { target @ " is ignoring you." }cat vtell exit
        then
    $endif
    target @
;

: get_targets ( s -- @ )
    var! arg
    arg @ strip "" strcmp not if
        TRUE exit ( Send to the room by default. )
    then
    arg @ " " explode array_make var! targets
    { ( Sanitize options. )
        var checkarg
        targets @ foreach
            swap pop checkarg !
            checkarg @ "^#(r|help|ansi|noansi)" REG_ICASE regexp not swap not and if
                checkarg @ ( Not one of the options. Interpret as literal. )
            then
        repeat
    }list targets !
    targets @ array_count 0 = if
        TRUE exit ( These were all options-- send to the room. )
    then
    me @ owner me @ dbcmp not if
        "Only players are permitted to post to remote targets." vtell
        FALSE exit
    then
    { 
        targets @ foreach
            swap pop targeter ( Return only valid targets )
        repeat
    }list { }list array_union ( Remove duplicates )
    target_list !
    target_list @ array_count 0 = if
        "No targets found!" vtell FALSE exit
    then
    target_list @ targets_string targetstr !
    TRUE
;

$iflib $lib/antiflood
    : antiflood ( Queries the anti-flood lib and returns true if player is limited. )
        checkflood if
            { "Flood control active. Please try again in " rot intostr " seconds." }cat vtell
            TRUE
        else
            FALSE
        then
    ;
$endif

: main
    $ifdef ANTIFLOOD_SUPPORT
        antiflood if
            exit
        then
    $endif
    { }list var! buffer
    target_list @ if
        { "Pasting to " targetstr @ "." strcat }cat vtell
    then
    "Enter the text you want to paste now. Type '.end' when you are finished, or '.abort' to cancel." vtell
    read_wants_blanks
    begin
        read
        case
            ".end" stringcmp not when TRUE end
            ".abort" stringcmp not when depth popn "Aborted." vtell exit end
            "" stringcmp not when "\r" FALSE end
            default buffer @ array_count MAX_QUOTE_LINES >= if
                pop "Maximum length reached! Use .end or .abort!" vtell
            else
                buffer @ array_appenditem buffer ! 
            then FALSE end
        endcase
    until

    ( One final check for problems. Someone could ignore 
      you while you're writing. )
    target_list @ if
         target_list @ " " array_join 
         get_targets not if
              "No targets found!" vtell exit
         then
    then

    { "<Verbatim start: " me @ name target_list @ if " to " targetstr @ then ">" }cat telltarget
    buffer @ foreach
        swap pop
        telltarget
    repeat
    { "<Verbatim end:   " me @ name target_list @ if " to " targetstr @ then ">" }cat telltarget
    target_list @ dup if
        foreach
            swap pop LASTGROUP me @ target_list @ array_appenditem array_put_reflist
        repeat
    else
        pop
    then
;
 
: do-help ( Shows the help screen )
{
    " "
    { "~Verbatim " prog "_Version" getpropstr " by Kelketek of Winter's Oasis~" }cat
    " "
    "     Verbatim provides paste/quote functionality to users who need to relay an"
    "amount of text over several lines to a room or a specific player. The syntax"
    "is as follows:"
    " "
    "%c person" command @ "%c" subst
    " "
    "    Where person is the player you wish to send text to. If no person is"
    "specified, the quote goes to the room. You can specify multiple people."
    " "
    "    Verbatim supports page #ignore on remote pastes. Pastes in-room always"
    "show."
    " "
    "    To reply to a group paste, use:"
    " "
    "%c #R" command @ "%c" subst
    " "
    $ifdef COLOR_SUPPORT
        "    You can enable ANSI interpolation with:"
        "%c #ansi" command @ "%c" subst
        "...or disable it with..."
        "%c #noansi" command @ "%c" subst
        " "
        "    If you control the action that is linked to this program, you can use:"
        "%c #defaultansi" command @ "%c" subst
        "...or..."
        "%c #defaultnoansi" command @ "%c" subst
        "...to mark ansi color on or off by default."
        " "
        { "ANSI is currently set to: " color_on @ if "ON" else "OFF" then }cat
        " "
    $endif
    "Done." }list
 
    foreach
         swap pop vtell
    repeat
 
;

: reply
    var grouplist
    me @ LASTGROUP array_get_reflist dup not if
        "No reply group recorded!" vtell exit
    then grouplist !

    grouplist @ me @ array_findval foreach
        swap pop grouplist @ swap array_delitem
    repeat
    grouplist !

    grouplist @ " " array_join arg !
    arg @ get_targets if
        main
    then
;
    
: color_prep ( -- ) ( Checks to see if color is set to be on by default )
    trigger @ VERBATIMDIR "/color_default" strcat getprop color_on !
;

: set_color_default[ int:option -- ]
    $ifndef COLOR_SUPPORT
        "Sorry, this MUCK does not support ANSI interpolation." vtell exit
    $else
    me @ trigger @ controls if
        trigger @ VERBATIMDIR "/color_default" strcat option @ setprop
        "Default set." vtell
    else
        "Permission denied." vtell
    then
    $endif
;

: optioncheck ( s -- )
    ( A bit of security first. )
    "me" match me !
    me @ location loc !
        color_prep ( Get the local color policy )
    arg !
    arg @ "#ansi" instring if
        TRUE color_on !
    then
    arg @ "#noansi" instring if
        FALSE color_on !
    then
    arg @ case
        "#defaultansi" instring when
            TRUE set_color_default exit
        end
        "#defaultnoansi" instring when
            FALSE set_color_default exit
        end
        "*#help*" smatch when
            do-help exit
        end
        "*#r*" smatch when
            reply exit
        end
        get_targets when
            main exit
        end
        default pop end
    endcase
;
