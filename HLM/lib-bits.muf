@program lib-bits
1 99999 d
i
( lib-bits.muf by Natasha@HLM

  These are general code parts written by Wind@SMT for inclusion in
  multiple MUF programs. This library is made available under the
  common BSD license.


  rtn-padleft
  rtn-padright
  rtn-padcenter  { str int -- str' }
  Pads str to int chars long, with the given justification.

  rtn-substpct  { str strNew strOld intPos -- str' }
  Returns str with a percent-phrase with token strOld replaced by
  strNew. A percent-phrase is a string like '%x   %'; 'x' is the
  token in that percent-phrase. strNew is padded to the length of
  the percent-phrase, such that {str strlen == str' strlen},
  depending on intPos:

    intPos  justification
        -1  left
         0  center
         1  right

  rtn-1explode  { str strDelim -- str- -str }
  Cuts str at the first strDelim. Like 'explode', only it works on
  the first instance of strDelim rather than all of them.

  rtn-substfirst  { str strNew strOld -- str' }
  Returns str with the first instance of strOld replaced with strNew.

  rtn-dohelp  { str -- }
  Displays help on the calling program in lsedit list str.

  rtn-match  { str -- db }
  Does a complex version of the "match" primitive: handles #123 and
  *name syntax. Replacement for Squirrelly's .wizmatch.

  rtn-dispatch  { strCommands -- bool }
  Dispatches to a word of the calling program, based on the "command"
  variable {that is, the "do-<cmd>" word where <cmd> is what's in the
 "command" variable}. Returns true if the "command" variable *was not*
  a valid command, based on strCommands, a space-padded and -delimited
  list of valid words in the calling program. Note that your program
  is calling itself, which means "caller" will still be the trigger or
  program that invoked your program originally, however you still need
  to declare all your "do-<cmd>" words "PUBLIC."

  rtn-ref-foreach  { db str addy -- ? }
  Executes addy for each db in the given reflist on top of the stack.
  The current db will be in 'db's place in the stack {ie, the code
  '"foo" #42 "_reflist" 'doowop rtn-ref-foreach' will run the doowop
  word with '"foo" #xx' on the stack for each #xx in the reflist}.

  rtn-othersort  { ?n..?1 intN addy -- ?n'..?1' intN }
  Sorts the given list using values given by the given function, "addy".
  This parameter should be the address {enter "'wordname" to put the address
  of the word "wordname" on the stack} of a word that will accept a value
  of whatever type is in the passed list, and that returns a string. The list
  will be returned sorted by the strings that "addy" returns.

  An example {with curly braces instead of parens in the necessary places}:

    : rtn-byname  { db -- str }  Returns the name of the given dbref. }
        name  { str }
    ;
    : main
        #123 #456 #789 3  { dbN..db1 intN }
        'rtn-byname  { dbN..db1 intN addy }
        .othersort  { dbN..db1 intN }  At this point, the list is sorted by
                                       the names of the given objects. }
    ;


  rtn-commas  { arr -- str }
  Comma-izes the given array of dbrefs, into a string like "Foo, Bar and Baz".

  rtn-rtimestr  { int -- str }
  Given an interval {number of seconds}, make a human-readable string of how
  long ago that was. Algorithm taken from SC-Track Roundup's Date.py:Interval
  object.


  Version history
  1.0, 30 Aug 2002: Possibly something like the first version.
  2.0, 26 Jan 2019: Required Fuzzball 6.
                    Reimplemented rtn-othersort using arrays.
                    Reimplemented rtn-pad* using fmtstring {as modern
                    $lib/strings does anyway}.
                    Removed str-good & str-bad stoplight words.
                    Finds ourselves whether rtn-dohelp can parse MPI
                    rather than having to be configured.
                    Made $lib/case optional, as Fuzzball 7 provides
                    those words without a library.
)
$author Natasha Snunkmeox <natmeox@neologasm.org>
$version 2.0
$lib-version 2.0
$note Common code helpers for hlm-suite programs.


( Fuzzball 7 has case primitives, so the library is not required. )
$iflib $lib/case
    $include $lib/case
$endif

: rtn-padleft  ( str int -- str' )
    dup 3 pick strlen < if  ( str int )
        strcut pop  ( str' )
    else
        "%-*s" fmtstring  ( str' )
    then  ( str' )
;
: rtn-padright  ( str int -- str' )
    dup 3 pick strlen < if  ( str int )
        strcut pop  ( str' )
    else
        "%*s" fmtstring  ( str' )
    then  ( str' )
;
: rtn-padcenter  ( str int -- str' )
    dup 3 pick strlen < if  ( str int )
        strcut pop  ( str' )
    else
        "%|*s" fmtstring  ( str' )
    then  ( str' )
;

: rtn-cookpct  ( str str%A -- str' intLength }  'Cook' str%A out of str. This is used for variable-width substitutions.
    For example: "foo %n   % bar" "%n" rtn-cookpct
    returns:     "foo %n bar" 6
    because '%n   %' is six characters long. )

    over swap instr  ( str int%A )
    ( If the %A wasn't in str, we're already done: the original str and 0 for intLength. )
    dup if  ( str int%A )
        1 + strcut  ( str- -str )
        dup "%" instr strcut swap  ( str- -str -str- }  From the example, str- is 'foo %n', -str is ' bar', and -str- is '   %'. )
        strlen 2 +  ( str- -str intLength }  2 == "%n" strlen )
        -3 rotate strcat swap  ( str' intLength )
    then  ( str' intLength )
;

( strpad  { str int -- str' }  Returns str, right-padded with spaces to int chars long. )
: rtn-substpct  ( str strNew strOld intPos -- str' }  Plugs strNew into str where '%strOld  ..  %' is. )
    -4 rotate  ( intPos str strNew strOld )
    "%" swap strcat  ( intPos str strNew strOld )
    rot over  ( intPos strNew strOld str strOld )
    rtn-cookpct  ( intPos strNew strOld strTemplate intLength )
    4 rotate swap  ( intPos strOld strTemplate strNew intLength )

    5 pick -1 = if  ( intPos strOld strTemplate strNew intLength )
        5 rotate pop  ( strOld strTemplate strNew intLength )
        rtn-padleft  ( strOld strTemplate strNew )
    else  ( intPos strOld strTemplate strNew intLength )
        5 rotate if  ( strOld strTemplate strNew intLength )
            rtn-padright  ( strOld strTemplate strNew )
        else  ( strOld strTemplate strNew intLength )
            rtn-padcenter  ( strOld strTemplate strNew )
        then
    then  ( strOld strTemplate strNew )

    rot  ( strTemplate strNew' strOld )
    subst  ( str' )
;

: rtn-1explode  ( str strDelim -- str- -str )
    over over instr  ( str strDelim intFirstDelim )

    ( There's a space, right? )
    dup if  ( str strDelim intFirstDelim )
        ( Yup; snap and strip. )
        swap strlen  ( str intFirstDelim intDelim )
        dup -4 rotate -  ( intDelim str intCut )
        strcut  ( intDelim str- -str )
        rot strcut swap pop  ( str- -str )
    else
        ( No; str- is all of str, and -str is a null string. )
        pop pop ""  ( str- -str )
    then  ( str- -str )
;

: rtn-substfirst  ( str strNew strOld -- str' }  Returns str with the first instance of strOld replaced with strNew. )
    rot  ( strNew strOld str )
    dup 3 pick instr  ( strNew strOld str intFirstOld )
    1 - strcut  ( strNew strOld str- -str )
    rot strlen strcut  ( strNew str- strOld -str )
    swap pop  ( strNew str- -str )
    rot swap strcat strcat  ( str' )
;

lvar v_reflist
lvar v_addy
: rtn-ref-foreach  ( db str addy -- ? )
    v_addy !  ( db str )
    getpropstr v_reflist !  (  )
    begin v_reflist @ dup while  ( [?] strReflist )
        " " rtn-1explode v_reflist !  ( [?] strRef )
        1 strcut swap pop atoi dbref  ( [?] db )
        v_addy @ execute  ( ? )
    repeat pop  ( ? )
;

lvar v_dir
lvar v_loadprop
: loadprop-parse  ( db str -- str )  "(#help)" 1 parseprop ;
: loadprop-get    ( db str -- str )  getpropstr ;
: rtn-dohelp  ( str -- }  Displays help on the calling program in lsedit list str. )
    prog mlevel 3 >= if 'loadprop-parse else 'loadprop-get then v_loadprop !

    "#" strcat dup "/" strcat v_dir !  ( strProp )
    caller swap getpropstr atoi 1  ( intLines intCur )
    begin over over >= while  ( intLines intCur )
        caller v_dir @ 3 pick intostr strcat  ( intLines intCur dbClr strLineProp )
        v_loadprop @ execute  ( intLines intCur strLine )
        tell  ( intLines intCur )
    1 + repeat pop pop  (  )
;

: rtn-match  ( str -- db }  Turns str into a dbref. )
    ( The smatch bits are Squirrelly's, honestly. )
    dup if
        dup "#[-0-9]*" smatch if
            1 strcut swap pop  ( -str )
            atoi dbref  ( db )
        else dup "\\*?*" smatch if
            1 strcut swap pop  ( -str )
            .pmatch  ( db )
        else match then then  ( db )
    else pop loc @ then  ( db )
;

: rtn-dispatch  ( strCommands -- [db] strCmd }  Makes the stack ready to "call" the word "do-<cmd>" where <cmd> is the normalized form of the "command" variable. If the normalized "command" is not in strCommands, a space-padded and -delimited list of acceptable commands, returns an empty {false} string and no db. )
    command @ strip tolower  ( strCommands strCmd )
    swap " " 3 pick strcat " " strcat  ( strCmd strCommands strCmd' )
    instr if  ( strCmd )
        caller "do-" rot strcat  ( db strCmd )
    else pop "" then  ( [db] strCmd )
;

lvar v_addy
: rtn-othersort  ( ?n..?1 intN addy -- ?n'..?1' intN }  Sorts the given stackrange by the results of running `addy` on each item and returns them in the new order. )
    v_addy !
    array_make  ( ary )

    -1 swap foreach rot pop  ( ... intN ?val )
        { swap  ( ... intN marker ?val )
        "value" swap  ( ... intN marker strValue ?val )
        "key" over  ( ... intN marker strValue ?val strKey ?val )
        v_addy @ execute  ( ... intN marker strValue ?val strKey ?Key )
        }dict  ( ... intN dict1 )
        swap  ( ... dict1 intN )
    repeat 1 +  ( dictN..dict1 intN )
    array_make  ( aryDicts )

    SORTTYPE_CASE_ASCEND "key" array_sort_indexed  ( arrSorted )

    -1 swap foreach  ( ... intCount intIndex dict )
        rot pop  ( ... intCount' dict }  This iteration's index is the new total count. )
        "value" array_getitem  ( ... intCount' ?val )
        swap  ( ... ?val intCount' )
    repeat 1 +  ( ?n'..?1' intN )
;

: rtn-commas  ( arr -- db )
    dup array_count 1 = if  ( arr )
        dup array_first array_getitem name  ( str )
    else  ( arr )
        dup array_last
        over over array_getitem
        -3 rotate array_delitem  ( dbLast arr )
        "" swap foreach swap pop  ( dbLast str db )
            ", " swap name strcat strcat  ( dbLast str )
        repeat  ( dbLast str )
        " and " strcat swap name strcat  ( str )
    then  ( str )
;

: rtn-rtimestr  ( int -- str )
    dup case  ( intSince )
        63072000 (730 days) >= when 31536000 (365 days) / "%i years ago"  fmtstring end
        31536000 (365 days) >= when pop "A year ago" end
        5184000  ( 60 days) >= when 2592000  ( 30 days) / "%i months ago" fmtstring end
        2505600  ( 29 days) >= when pop "A month ago" end
        1209600  ( 14 days) >= when 604800   (  7 days) / "%i weeks ago"  fmtstring end
        604800   (  7 days) >= when pop "A week ago" end
        172800   (  2 days) >= when 86400    (  1 day ) / "%i days ago"   fmtstring end
        46800    (13 hours) >= when pop "Yesterday" end
        7200     ( 2 hours) >= when 3600    ( 2 hours) / "%i hours ago"  fmtstring end
        6300  (1 3/4 hours) >= when pop "1 3/4 hours ago" end
        5400  (1 1/2 hours) >= when pop "1 1/2 hours ago" end
        4500  (1 1/4 hours) >= when pop "1 1/4 hours ago" end
        3600     ( 1 hour ) >= when pop "An hour ago" end
        2700  ( 45 minutes) >= when pop "3/4 hour ago" end
        1800  ( 30 minutes) >= when pop "1/2 an hour ago" end
        900   ( 15 minutes) >= when pop "1/4 hour ago" end
        120   (  2 minutes) >= when 60 / "%i minutes ago" fmtstring end
        ( Where Roundup would say '1 minute ago' we go ahead and say 'Just now.' )
        default pop pop "Just now" end
    endcase  ( str )
;

: main 1 pop ;
PUBLIC rtn-padleft
PUBLIC rtn-padright
PUBLIC rtn-padcenter
PUBLIC rtn-substpct
PUBLIC rtn-1explode
PUBLIC rtn-substfirst
PUBLIC rtn-dohelp
PUBLIC rtn-dispatch
PUBLIC rtn-match
PUBLIC rtn-othersort
PUBLIC rtn-commas
PUBLIC rtn-rtimestr

$libdef rtn-padleft
$libdef rtn-padright
$libdef rtn-padcenter
$libdef rtn-substpct
$libdef rtn-1explode
$libdef rtn-substfirst
$libdef rtn-dohelp
$libdef rtn-dispatch
$libdef rtn-match
$libdef rtn-othersort
$libdef rtn-commas
$libdef rtn-rtimestr
.
c
q
@register lib-bits=lib/bits
@register #me lib-bits=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=L
@set $tmp/prog1=V
@register #me =tmp
