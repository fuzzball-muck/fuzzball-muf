@prog lib-ansi-fb6.muf
1 9999 d
i
( lib-ansi-fb6.muf by Wog
  For FuzzBall Version 6 to simulate tidle ansi-color.

 NOTE: Tidle ansi color is primarily for backwards compatibility
  if you don't care about backwards compatibility with 
  pre-fuzzball 6 lib-ansi systems you should see 'man textattr' or
  'mpi attr'.
  
Info about tidle ansi escapes:
 Color can be changed with an escape of the form: ~&<A><F><B>
<A> is the attribute, one of:
   1 => bold
   2 => reverse
   3 => bold and reverse
   4 => underline [ in theory ]
   5 => flash
   8 => also reverse
   - => no change from what it was before

<F> is the foreground, one of:
   0 => black
   1 => red
   2 => green
   3 => yellow
   4 => blue
   5 => magenta
   6 => cyan
   7 => white
   - => no change from what it was before

<B> is the background, one of:
   0 => black
   1 => red
   2 => green
   3 => yellow
   4 => blue
   5 => magenta
   6 => cyan
   7 => white
   - => no change from what it was before.
 Other codes supported:
  ~&R -- to reset colors...

 Other notes:
  \~& or ~&~& will put a literal ~& without doing ansi codes...

 Semi-bugs:
  ansi-strcut will NOT preserve \~& exactly; in the results they
  will be replaced with ~&~&, except when ansi_strcut is returning
  anot string for either of it's return values.

 NOTE:
   ansi_version will return '200' for this library.

--- Change History ----------------------------------
v 1.0  02/24/00
    Assignment of version number to programs.
v 1.01 02/25/00
    Modified _defs/ansi-codecheck to deal with - in escape codes.
v 1.02 03/31/00
    Enhanced setup script a bit.
v 2.0 May 20 2000
    Used ANSI codes directly, rather then textattr, so - works
    as expected. Actaully wrote own ansi_strcut routine, fixing
	problems that would be suffered with old one. Also added public
	routines for any program that might try calling lib-ansi directly.
    [as in "$lib/ansi" match "ansi-tell" call], rather than
    using this libraries _defs. 
v 2.0a Apr 12 2001
    Added some nice _defs and used Natty's ansi-strcut routine from
    lib-ansi-burn. [Which works, I hope.]
--- Distrubution Information ------------------------
Copyright {C} Charles "Wog" Reiss <car@cs.brown.edu>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or {at your option} any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

For a copy of the GPL:
   a> see: http://www.gnu.org/copyleft/gpl.html
   b> write to: the Free Software Foundation, Inc., 
     59 Temple Place - Suite 330, Boston, MA  02111-1307, USA
GNU Public License Version 2 or at your option any later version. 
)

(For the benefit of those reading this code who aren't aware of this, 
  in FB6 \[ represents the escape charactor in strings. 
  That's ASCII code 27 decimal, and this convient table is provided if
  you want it in another base. <;
  [Yes! I do have too much time!]
Base      Number  Base      Number  Base      Number
  2        11011    3         1000    4          123
  5          102    6           43    7           36
  8           33    9           30   10           27
 11           25   12           23   13           21
 14           1D   15           1C   16           1B
 17           1A   18           19   19           18
 20           17   21           16   22           15
 23           14   24           13   25           12
 26           11   27           10   28            R
 29            R   30            R   31            R
 32            R   33            R   34            R
 35            R   36            R
)

(Protect strings should be 2 chars long since ~& is for ansi_strcut.)
$def PROTECT_STR "\[\["
                 

( s   -- s'  )
$define _protect
  PROTECT_STR "\\~&" subst
  PROTECT_STR "~&~&" subst
$enddef

( s'  -- s'' )
$define _end_protect
  "~&" PROTECT_STR subst
$enddef

( s' -- s  ) ( * almost; \~& will be replaced with ~&~&. )
$define _cut_end_protect
  "~&~&" PROTECT_STR subst
$enddef

( This can be changed if you don't want black on white to be the default
  color. )
$def RESET_CODE "\[[0;37;40m"

: tCodeData ( s -- s )
(Generate like:
  070 -> "\[[0;37;40m"
  --- -> ""
  8-- -> "\[[8m"
)
  dup  "---" strcmp not if pop "" exit then
  ( ^^ Special Case ^^ )
  "\[["
( We add 1 to the string so - turns into -1, not 0, for us
   to not touch in the case statment. )
  swap 
  ("\[[" AFB)
  1 strcut
  ( "\[[" A FB )
  over "-" strcmp not if (Attribute)
  ( "\[[" A FB )
    swap pop
  else
    rot rot
  ( FB "\[[" A )
	strcat ";" strcat swap 
  then
  ( "\[[..." FB )
  1 strcut
  ( ... F B )
  over "-" strcmp not if (Forground)
    swap pop ( "\[[" B )
  else
    rot "3" strcat rot strcat ";" strcat swap
  then
  ("\[[" B)
  
  dup "-" strcmp not if
    pop
	dup strlen 1 - strcut pop
  else
    swap "4" strcat swap strcat
  then
  "m" strcat
;

lvar data
lvar oddness
lvar append
: t_ansify ( s -- s )
  "" data !
  _protect
  dup "~&" instr not if
    _end_protect exit
  then
  RESET_CODE "~&R" subst
  RESET_CODE "~&r" subst
  dup "~&" instr 1 = oddness !
  "~&" explode
  oddness @ not if
     swap append ! 1 - 
  else
     "" append !
  then
  begin 
    dup while
    dup 1 + rotate
    dup if
      dup "[-0-9][-0-9][-0-9]*" smatch if
        3 strcut swap tCodeData 
	    swap strcat 
      then
    then
    data @ strcat data !
    1 -
  repeat
  pop
  append @ data @ strcat
  _end_protect
;

: ansify ( s -- s' ) 
  t_ansify
;
PUBLIC ansify

: ansi-strip ( s -- s' )
  _protect
  "" "~&R" subst
  "" "~&r" subst
  dup "~&" instr not if _end_protect exit then
  "" data !
  "~&" explode
  begin
    dup while
    dup 1 + rotate
    dup if
      dup "[-0-9][-0-9][-0-9]*" smatch if ( We allow up to nine, just because. )
        3 strcut swap pop
      then
    then
    data @ strcat data !
    1 -
  repeat
  pop
  data @ _end_protect
;
PUBLIC ansi-strip

(Returns length of ansi code following ~&. 
 As in you can give it 06-Cyan!
 Or RResetted.., etc. as an argument.
)
: code-length ( s -- i )
  dup 1 strcut pop "R" stringcmp not if pop 3 exit then
  3 strcut pop
  "[-0-9][-0-9][-0-9]" smatch if 5 else 0 exit then
;


lvar stringprime
( This is taken's from Natty's lib-ansi-burn, a GPL library. )
: ansi-strcut ( s i -- s' -s }  Strcuts, dancing around ~&AFB codes; -s=the end of s, s-=the startish part )
  swap  ( i s )
 
  ( Protect protected ansi. )
  _protect
 
  ( I worked this like an abacus, character by character, but it was stupidslow; now 
it skips ahead with instr to the next instance of ~&, and should be faster. 
Hopefully. )
  "" stringprime !
  begin over over and while  ( i s }  While there are still chars left in i, )
    dup "~&" instr dup if  ( i s i' }  i' = Where's the next ~&? )
      dup 4 pick <  ( i s i' b }  b = Is the next ~& after the place we should cut? )
    else 0 then  ( i s i' b }  b = Do I haveta cut? )
 
    if  ( i s i' )
      1 - strcut  ( i s- -s )
      rot 3 pick strlen - -3 rotate  ( i s- -s }  Reduce i by 's- strlen'. )
      stringprime @ rot strcat stringprime !  ( i -s )
      3 strcut over tolower "~&r" strcmp if  ( i -s- -s } -s- is the ansi code. )
        2 strcut -3 rotate strcat
      else swap then ( i -s -s- )
      stringprime @ swap strcat stringprime !  ( i -s )
    else
      pop swap strcut  ( s- -s )
      stringprime @ rot strcat stringprime !  ( -s )
      0 swap  ( i -s )
    then
  repeat  ( i -s )
 
  swap pop  ( -s )
  _cut_end_protect
  stringprime @
  _cut_end_protect
  swap  ( s- -s )
;
PUBLIC ansi-strcut

: ansi-codecheck "{r|R|[-0-9][-0-9][-0-9]}" smatch ;
PUBLIC ansi-codecheck
: ansify_string ansify ;
PUBLIC ansify_string
: ansi-notify ansify \notify ;
PUBLIC ansi-notify
: ansi-notify-except ansify 1 swap \notify_exclude ;
PUBLIC ansi-notify-except
: ansi-notify-exclude ansify \notify_exclude ;
PUBLIC ansi-notify-exclude
: ansi-tell ansify tell ;
PUBLIC ansi-tell
: ansi-otell ansify otell ;
PUBLIC ansi-otell
: ansi-strlen ansi-strip \strlen ;
PUBLIC ansi-strlen
: ansi-connotify ansify \connotify ;

lvar setup_tmp
: setup ( -- )
  "me" match me !
  me @ "W" flag? not if
    "Only wizards can setup this library!" tell
    exit
  then
  "** Setting up lib-ansi! **" tell
  prog "S" set
  prog "H" set
  prog "L" set
  "%% Setup program SETUID, HARDUID, and LINK_OK" tell
  prog "_defs/lib-ansi" "#" prog int intostr strcat setprop
  prog "_defs/doAnsify" "lib-ansi \"ansify\" call" setprop
  prog "_defs/ansify_string" "doAnsify" setprop
  prog "_defs/ansi-codecheck" "\"{r|R|[-0-9][-0-9][-0-9]}\" smatch" setprop
  prog "_defs/ansi_codecheck" "ansi-codecheck" setprop
  prog "_defs/ansi_protect" "\"\\~&\" \"~&\" subst" setprop
  prog "_defs/ansi-strip" "lib-ansi \"ansi-strip\" call" setprop
  prog "_defs/ansi_strip" "lib-ansi \"ansi-strip\" call" setprop
  prog "_defs/ansi-version" "200" setprop (Emulate lib-ansi-free with extra feeps!)
  prog "_defs/ansi_version" "ansi-version" setprop
  prog "_defs/ansi-strlen" "ansi-strip \\strlen" setprop
  prog "_defs/ansi_strlen" "ansi-strip \\strlen" setprop
  prog "_defs/ansi_notify" "doAnsify \\notify" setprop
  prog "_defs/ansi-notify" "doAnsify \\notify" setprop
  prog "_defs/ansi_notify_except" "doAnsify 1 swap \\notify_exclude" setprop
  prog "_defs/ansi_notify_exclude" "doAnsify \\notify_exclude" setprop
  prog "_defs/ansi-notify-except" "doAnsify 1 swap \\notify_exclude" setprop
  prog "_defs/ansi-notify-exclude" "doAnsify \\notify_exclude" setprop
  prog "_defs/ansi_notify-except" "doAnsify 1 swap \\notify_exclude" setprop
  prog "_defs/ansi_notify-exclude" "doAnsify \\notify_exclude" setprop
  prog "_defs/ansi_otell" "doAnsify loc @ me @ rot 1 swap \\notify_exclude" setprop
  prog "_defs/ansi-otell" "doAnsify loc @ me @ rot 1 swap \\notify_exclude" setprop
  prog "_defs/ansi-tell" "doAnsify me @ swap \\notify" setprop
  prog "_defs/ansi_tell" "doAnsify me @ swap \\notify" setprop
  prog "_defs/ansi-strcut" "lib-ansi \"ansi-strcut\" call" setprop
  prog "_defs/ansi_strcut" "lib-ansi \"ansi-strcut\" call" setprop
  prog "_defs/ansi?" "owner \"C\" flag?" setprop
  
  "%% Setup _defs." tell
  "%% Registering library!" tell
  
  "@register" match 
  dup ok? not if
    pop #0 "_reg/lib/ansi" prog setprop
  else (Prefer @register messages of any changes, etc.)
    getlink "#" prog int intostr strcat "=lib/ansi" strcat swap call  
  then
  
  "%% Done!" tell
;
.
c
ansi_tell kill
ansi_otell kill
def ansi_tell ( s -- ) me @ swap "$lib/ansi" match "ansify" call \notify
def ansi_otell ( s -- ) loc @ me @ rot "$lib/ansi" match "ansify" call \notify_except
q
@set lib-ansi-fb6.muf=W
@mpi {muf:lib-ansi-fb6.muf,}
whis me=Uncompiling all programs, so they will adapt to new calling interface, hopefully.
@uncompile