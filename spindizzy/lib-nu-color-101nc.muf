( /quote -dsend -S '/data/spindizzy/muf/lib-nu-color-101nc.muf )

@prog lib-nu-color.muf
1 5000 d
i
$include $lib/appset
$version 1.011

$def ANSIFREEPROP "/ansifree/"
$def NUCOLORPROP "/color/"
$def COLORAPP "color"
$def NUCOLORPREFIX "~`"
$def NUCOLORSUFFIX "`"
  
( General helpers )
lvar lnc_target

  
: lnc-getColor (s -- s'  Given a color s, return s', the color the user wants
                         to see instead.  s' might be equal to s )
    ( DISABLED FOR NOW.  DO NOT CALL.  Performance problem. )
    exit

    var inputColor
    inputColor !

    0 TRY
        lnc_target @ COLORAPP inputColor @ appset-getAttribute
  
        dup appset-unset? if
            ( App doesn't exist or no color defined, return input color )
            pop
            inputColor @
        then
    CATCH
        pop
        ( Target doesn't allow custom colors, so return what we're passed in )
        inputColor @
    ENDCATCH
;

( End general helpers )
  
( Begin nucolor parser )
  
: isNucolor?  ( s -- i  Given a string s, return 1 if beginning part of string
                        appears to be a nucolor command )
    dup NUCOLORPREFIX instr 1 = if
        ( Nucolor.  Now see if the attributes are in the right format and are
          terminated )
        2 strcut swap pop

        dup NUCOLORSUFFIX instr dup if
            ( It has a terminator, so all we have to do now is verify the
              attributes look about right )
            1 - strcut pop
            ( Verify only composed of alphas, _, ',' and that's it )
            "*[^a-zA-Z,_]*" smatch
            ( Return the result )
            not
        else
            ( Not nucolor )
            pop pop 0 exit
        then
    else
        ( Not nucolor )
        pop 0 exit
    then
;
  
: findNucolorCommand ( s i -- i'  Given string s, and offset i, return the
                                      location of the next 'valid' Nucolor
                                      command [the starting index], starting the
                                      search from i, or 0 if not found.  This
                                      does NOT check for invalid attributes. Note
                                      i is used with strcut, so i=0 checks
                                      the whole string, while i=1 checks after
                                      the first character, etc)
    var currentIndex
  
    dup currentIndex !

    strcut swap pop
    BEGIN
        dup NUCOLORPREFIX instr dup if
            ( Update the index in case if it is a real nucolor command )
            dup currentIndex @ + currentIndex !

            ( Found what might be a nucolor command.  Let's see if its real )
            1 - strcut swap pop
            dup isNucolor? if
                ( We found the next valid command, so clean up and return
                  the index )
                pop
                currentIndex @
                exit
            else
                ( Not nucolor after all!  Advance two characters and loop
                  around to look again )
                currentIndex @ 1 + currentIndex !
                2 strcut swap pop
            then
        else
            ( Not even a hint of a nucolor command )
            pop pop
            0
            exit
        then
    REPEAT (manually exit)    
;
  
: nucolorToTextattr  (s -- s'  Given an entire valid nucolor command [ex: ~`red`]
                               return the string to be used by texattr to
                               colorize )
    var textattrOutput

    NUCOLORPREFIX strlen strcut swap pop

    dup NUCOLORSUFFIX strcmp if
        "" textattrOutput !
        dup NUCOLORSUFFIX instr 1 - strcut pop
        "," explode
        1 swap 1 FOR
            pop
            (do initial color translation.  If invalid, drop color and continue)
            prog NUCOLORPROP rot strcat getpropstr dup if
                ( Now lookup the user translation, if any )
                ( lnc-getColor  --Disabled)
                ( put it on the output )
                "," strcat textattrOutput @ swap strcat textattrOutput !
            else
                ( Invalid )
                pop
            then
        REPEAT
        
        ( Strip off the last character, which is a ',' )
        textattrOutput @ strlen if
            textattrOutput @ dup strlen 1 - strcut pop
        else
            textattrOutput @
        then
    else
        ( Special case of input being ~`` )
        pop
        "reset"
    then
;
  
: strcutNucolorCommand ( s -- s1 s2  Given a string beginning with a valid
                                     Nucolor command, return s1 the Nucolor
                                     command and s2 the remainder of the string.
                                     Kind of like strcut )
    NUCOLORPREFIX strlen strcut dup NUCOLORSUFFIX instr strcut -3 rotate strcat swap
;
  
: parseNucolor  ( s -- s'  Given a string s, return the ansified version of it,
                           with the ansi commands being in nucolor format )
    var finalString
    var stringIndex
  
    "" finalString !
    0 stringIndex !
  
    BEGIN
        dup 0 findNucolorCommand dup if
            ( Place the text before the nucolor command into the
              final string )
            1 - strcut
            swap
            finalString @ swap strcat finalString !
  
            ( Now, because this is a simplistic parser, there are two
              possibilities:  There is only one nucolor command, so the
              rest of the string is ansified, or there is a second nucolor
              command down the string where we stop at. )
                
            ( Find if there is a valid command down the string )
            dup 2 findNucolorCommand dup if
                ( We will do the color changes up to the next valid command )
                1 - strcut swap
                ( Extract the nucolor command, and call the colorizer! )
                strcutNucolorCommand swap nucolorToTextattr textattr
            else
                ( We will do the color changes for the remainder of the string )
                pop
                ( Extract the nucolor command, and call the colorizer! )
                strcutNucolorCommand swap nucolorToTextattr textattr
                ( Represents the remainder of the string )
                "" swap
            then
  
            ( We have a colored string, so append it to the output )
            finalString @ swap strcat finalString !
        else
            ( No more left, just append the string and exit )
            pop
            finalString @ swap strcat finalString !
            break
        then
    REPEAT ( break out manually )
  
    ( Returns the ansified string )
    finalString @
;
  
( End nucolor parser )
  
  
( Begin lib-ansi-free emulation )
  
: ansifree? (s -- i  Given a string, return 1 if beginning part of string is in
                     lib-ansi-free format )
    
    dup "\~\&[0-9][0-9][0-9]*" smatch
    swap "\~\&[RBC]*" smatch
    or
;
  
: ansifreeAnywhere? (s -- Given a string, return 1 if any part of string
                  is in lib-ansi-free format )
    
    dup "*\~\&[0-9][0-9][0-9]*" smatch
    swap "*\~\&[RBC]*" smatch
    or
;
   
: findValidAnsiFreeCommand  ( s i -- i'  Given a string, and an offset i,
                              return the location of the next valid ansifree
                              command within the string [the starting character
                              index].  Return 0 if none found )
    var currentIndex
  
    dup currentIndex !

    strcut swap pop
    BEGIN
        dup "~&" instr dup if
            ( Update the index in case if it is a real ansifree command )
            dup currentIndex @ + currentIndex !
            1 - strcut swap pop
            dup ansifree? if
                ( We found the next valid command, so clean up and return
                  the index )
                pop
                currentIndex @
                exit
            else
                ( Not ansifree after all!  Advance two characters and loop
                  around to look again )
                currentIndex @ 1 + currentIndex !
                2 strcut swap pop
            then
        else
            pop pop
            ( Not even a hint of ansifree found.  Just exit now )
            0 exit
        then
    REPEAT  (manually exit)
;
  
: ansiFreeToTextattr ( s -- s'  Given just the ansifree command [ex: "~&123"],
                                return the string used by the textattr prim to
                                set colors [ex: "bg_black, red"]. )
    var output
    "" output !

    dup "\~\&[0-9][0-9][0-9]" smatch if
        ( This is a real color command. )
  
        ( Get rid of the ~& )
        2 strcut swap pop
        ( Process each of the three fields in turn, appending the color
          to the output string )
        ( Convert into three numbers )
        1 strcut 1 strcut
        ( "~&123"  becomes  "1"  "2"  "3" )
  
        ( Handle first digit )
        rot
        prog ANSIFREEPROP "0/" strcat rot strcat getpropstr
        ( lnc-getColor   --Disabled)
        "," strcat output !
  
        ( Handle second digit )
        swap
        prog ANSIFREEPROP "1/" strcat rot strcat getpropstr
        ( lnc-getColor   --Disabled)
        "," strcat output @ swap strcat output !
  
        ( Handle third digit )
        prog ANSIFREEPROP "2/" strcat rot strcat getpropstr
        ( lnc-getColor   --Disabled)
        output @ swap strcat output !
    else
        dup "\~\&\[RBC]" smatch if
            ( Only R is supported, which is for reset )
            pop "reset" output !
        else
            ( Not ansifree? )
            pop "reset" output !
        then
    then

    ( Return the result )
    output @
;
  
: strcutAnsiFreeCommand  ( s -- s1 s2  Given s, return s1, the ansifree command,
                           and s2, the rest of the string.
                           ex: s="~&123Hello"  s1="~&123"  s2="Hello")
    dup "\~\&[0-9][0-9][0-9]*" smatch if
        ( Typical ansifree command ~&123 )
        5 strcut
    else
        dup "\~\&[RBC]*" smatch if
            3 strcut
        else
            ( Not ansifree??? )
            "" swap
        then
    then
;
  
: parseAnsiFree (s -- s'  Given a string with ONLY lib-ansifree type syntax,
                          return s', the ansified version )
    var finalString
    var stringIndex
  
    "" finalString !
    0 stringIndex !
  
    ( Note that Bell and Clear Screen are NOT supported, so take them out )
    "" "~&B" subst
    "" "~&C" subst
  
    BEGIN
        dup 0 findValidAnsiFreeCommand dup if
            ( Place the text before the ansifree command into the
              final string )
            1 - strcut
            swap
            finalString @ swap strcat finalString !
  
            ( Now, because this is a simplistic parser, there are two
              possibilities:  There is only one ansifree command, so the
              rest of the string is ansified, or there is a second ansifree
              command down the string where we stop at. )
                
            ( Find if there is a valid command down the string )
            dup 2 findValidAnsiFreeCommand dup if
                ( We will do the color changes up to the next valid command )
                1 - strcut swap
                ( Extract the ansifree command, and call the colorizer! )
                strcutAnsiFreeCommand swap ansiFreeToTextattr textattr
            else
                ( We will do the color changes for the remainder of the string )
                pop
                ( Extract the ansifree command, and call the colorizer! )
                strcutAnsiFreeCommand swap ansiFreeToTextattr textattr
                ( Represents the remainder of the string )
                "" swap
            then
  
            ( We have a colored string, so append it to the output )
            finalString @ swap strcat finalString !
        else
            ( No more left, just append the string and exit )
            pop
            finalString @ swap strcat finalString !
            break
        then
    REPEAT ( break out manually )
  
    ( Returns the ansified string )
    finalString @
;
  
( End lib-ansi-free emulation )
  
: whatParser ( s -- i  Returns 1 if nucolor, 2 if ansifree, or 0 if no parser
                       needed )
    dup 0 findNucolorCommand if
        pop
        1
    else
        ansifreeAnywhere? if
            2
        else
            0
        then
    then
;
  
: lnc-color-codes?  ( s -- i  Given a string, return nonzero if valid color
                     codes are embedded in it, 0 if plain text [no color] )
    whatParser
;

: lnc-parse (d s -- s'  Given a target d and string s, returns the
                           colorized/ansified string s'.  s may be in
                           lib-ansi-free XOR nucolor format.  d must
                           be a thing or player, or else default colors
                           are used.  If a object or player isn't set to
                           allow appset to access their props remotely,
                           they will also get default colors. )
    "Ds" checkargs

    swap lnc_target !
  
    dup whatParser
  
    dup 1 = if pop parseNucolor exit then
    2 = if parseAnsiFree exit then
    ( Neither, so return the string that came in )
;
  
: lnc-parse-me ( s -- s'  Like lnc-parse, but automatically uses 'me' as
                          the target.)
    "s" checkargs
    me @ swap lnc-parse
;
  
: lnc-td ( -- Test driver for all but the simple public user functions )
    var stacklen
    depth stacklen !
  
    "me" match lnc_target !
  
    ( Common )
    (me @ "Testing lnc-getColor..." notify
    lnc_target @ COLORAPP "blue" appset-removeAttribute pop
    "blue" lnc-getColor "blue" strcmp if me @ "FAIL: lnc-getColor with no props." notify exit then
    lnc_target @ COLORAPP "blue" "portia" appset-setAttribute pop
    "blue" lnc-getColor "portia" strcmp if me @ "FAIL: lnc-getColor with props." notify exit then
    lnc_target @ COLORAPP "blue" appset-removeAttribute pop )
    
    ( Nucolor )
    me @ "Testing isNucolor?..." notify
    "~`r`Hello" isNucolor? not if me @ "FAIL: isNucolor? should be 1" notify exit then
    "~`haha" isNucolor? if me @ "FAIL: isNucolor? should be 0." notify exit then
    "Not at all" isNucolor? if me @ "FAIL: isNucolor? should be 0. (2)" notify exit then
    "~`haha!`None" isNucolor? if me @ "FAIL: isNucolor? should be 0. (3)" notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for isNucolor?" notify exit then

    me @ "Testing findNucolorCommand..." notify  
    "Simple" 1 findNucolorCommand if me @ "FAIL: findNucolorCommand did not return 0." notify exit then  
    "Simple" 3 findNucolorCommand if me @ "FAIL: findNucolorCommand did not return 0. (2)" notify exit then  
    "~`r`Simple" 0 findNucolorCommand 1 = not if me @ "FAIL: findNucolorCommand did not return 1." notify exit then
    "~`red`Simple" 2 findNucolorCommand 0 = not if me @ "FAIL: findNucolorCommand did not return 0. (3)" notify exit then
    "Har~`blue`er" 1 findNucolorCommand 4 = not if me @ "FAIL: findNucolorCommand did not return 4." notify exit then
    "Dif~`blue`ic~`green,y`ult" 1 findNucolorCommand 4 = not if me @ "FAIL: findNucolorCommand did not return 4. (2)" notify exit then
    "Dif~`blue`ic~`green,y`ult" 5 findNucolorCommand 13 = not if me @ "FAIL: findNucolorCommand did not return 13." notify exit then
    "a~`~`!!`ic~`green,y`ult" 1 findNucolorCommand 11 = not if me @ "FAIL: findNucolorCommand did not return 11." notify exit then
    "a~`~`!!`ic~`green,,,,,`ult" 1 findNucolorCommand 11 = not if me @ "FAIL: findNucolorCommand did not return 11. (2)" notify exit then
    "Hi~``Bye" 1 findNucolorCommand 3 = not if me @ "FAIL: findNucolorCommand did not return 3." notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for findNucolorCommand" notify exit then

    me @ "Testing strcutNucolorCommand..." notify
    "~`valid`Hello" strcutNucolorCommand "Hello" strcmp swap "~`valid`" strcmp or if me @ "FAIL: strcutNucolorCommand" notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for strcutNucolorCommand" notify exit then

    me @ "Testing nucolorToTextattr..." notify
    "~`r,blue,g`" nucolorToTextattr "red,blue,green" strcmp if me @ "FAIL: nucolorToTextattr returned bad value." notify exit then
    "~`r`" nucolorToTextattr "red" strcmp if me @ "FAIL: nucolorToTextattr returned bad value. (2)" notify exit then
    "~`r,,,,,,`" nucolorToTextattr "red" strcmp if me @ "FAIL: nucolorToTextattr returned bad value. (3)" notify exit then
    "~`r,blue,,,,g`" nucolorToTextattr "red,blue,green" strcmp if me @ "FAIL: nucolorToTextattr returned bad value. (3)" notify exit then
    "~`,,,,r,blue,,,,g`" nucolorToTextattr "red,blue,green" strcmp if me @ "FAIL: nucolorToTextattr returned bad value. (4)" notify exit then
    "~``" nucolorToTextattr "reset" strcmp if me @ "FAIL: nucolorToTextattr did not return reset string." notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for nucolorToTextattr" notify exit then    

    me @ "Testing parseNucolor..." notify
    me @ "~`r`Red" parseNucolor notify
    me @ "Normal" parseNucolor notify
    me @ "~`r`Red ~``Normal" parseNucolor notify
    me @ "~`bgr,black`Black Text~`bold,g`Green Text~`b` Blue text. ~``Normal" parseNucolor notify
    me @ "~`bgr,black`Black Text~`bold,g`Green Text~`b` Blue ~`!fake!`text. ~``Normal" parseNucolor notify
    me @ "~`r`R~`o`O~`y`Y~`g`G~`b`B" parseNucolor notify
    depth stacklen @ = not if me @ "FAIL: stacksize for parseNucolor" notify exit then    

    ( Ansi free )
    me @ "Testing ansifree?..." notify
    "~&123Blahblah" ansifree? not if me @ "FAIL: ansifree? returned false when should be true." notify exit then
    "~&12Blahblah" ansifree? if me @ "FAIL: ansifree? returned true when should be false." notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for ansifree?" notify exit then    

    me @ "Testing ansifreeAnywhere?..." notify
    "~&123Blahblah" ansifreeAnywhere? not if me @ "FAIL: ansifreeAnywhere? returned false when should be true." notify exit then
    "~&12Blahblah" ansifreeAnywhere? if me @ "FAIL: ansifreeAnywhere? returned true when should be false." notify exit then
    "Hello~&123Blahblah" ansifreeAnywhere? not if me @ "FAIL: ansifreeAnywhere? returned false when should be true. (2)" notify exit then
    "HiHiBlahblah" ansifreeAnywhere? if me @ "FAIL: ansifreeAnywhere? returned true when should be false. (2)" notify exit then
    "HiHi~&12Blahblah" ansifreeAnywhere? if me @ "FAIL: ansifreeAnywhere? returned true when should be false. (3)" notify exit then
    "Hello~&RBlahblah" ansifreeAnywhere? not if me @ "FAIL: ansifreeAnywhere? returned false when should be true. (3)" notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for ansifreeAnywhere?" notify exit then    

    me @ "Testing findValidAnsiFreeCommand..." notify
    "Simple" 1 findValidAnsiFreeCommand if me @ "FAIL: findValidAnsiFreeCommand did not return 0." notify exit then  
    "Simple" 3 findValidAnsiFreeCommand if me @ "FAIL: findValidAnsiFreeCommand did not return 0. (2)" notify exit then
    "~&231Simple" 0 findValidAnsiFreeCommand 1 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 1." notify exit then
    "~&000Simple" 2 findValidAnsiFreeCommand 0 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 0. (3)" notify exit then
    "Har~&543er" 1 findValidAnsiFreeCommand 4 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 4." notify exit then
    "Dif~&666ic~&999ult" 1 findValidAnsiFreeCommand 4 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 4. (2)" notify exit then
    "Dif~&666ic~&999ult" 5 findValidAnsiFreeCommand 11 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 11." notify exit then
    "a~&~&!!`ic~&412ult" 1 findValidAnsiFreeCommand 11 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 11. (2)" notify exit then
    "Hi~&BBye" 1 findValidAnsiFreeCommand 3 = not if me @ "FAIL: findValidAnsiFreeCommand did not return 3." notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for findValidAnsiFreeCommand" notify exit then    

    me @ "Testing ansiFreeToTextattr..." notify
    "~&123" ansiFreeToTextattr "bold,green,bg_yellow" strcmp if me @ "FAIL: ansiFreetoTextattr gave wrong value." exit notify then
    "~&R" ansiFreeToTextattr "reset" strcmp if me @ "FAIL: ansiFreetoTextattr did not give reset value." exit notify then
    depth stacklen @ = not if me @ "FAIL: stacksize for ansiFreeToTextattr" notify exit then    

    me @ "Testing strcutAnsiFreeCommand..." notify
    "~&987Hello" strcutAnsiFreeCommand "Hello" strcmp swap "~&987" strcmp or if me @ "FAIL: strcutAnsiFreeCommand did not give correct output." notify exit then
    "~&RHello" strcutAnsiFreeCommand "Hello" strcmp swap "~&R" strcmp or if me @ "FAIL: strcutAnsiFreeCommand did not give correct output. (2)" notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for strcutAnsiFreeCommand" notify exit then    

    (parseAnsiFree)
    me @ "Testing parseAnsiFree..." notify
    me @ "No ansi" parseAnsiFree notify
    me @ "~&110Red" parseAnsiFree notify
    me @ "~&110Red ~&120Green" parseAnsiFree notify
    me @ "~&110Red ~&120Green ~&Rnormal" parseAnsiFree notify
    depth stacklen @ = not if me @ "FAIL: stacksize for parseAnsiFree" notify exit then

    (More common)
    me @ "Testing whatParser..." notify
    "None" whatParser 0 = not if me @ "FAIL: whatParser should return 0." notify exit then
    "Blahblah~`r`Nucolor" whatParser 1 = not if me @ "FAIL: whatParser should return 1." notify exit then
    "Blahblah~&123Nucolor" whatParser 2 = not if me @ "FAIL: whatParser should return 2." notify exit then
    depth stacklen @ = not if me @ "FAIL: stacksize for whatParser" notify exit then

    (me @ "Testing lnc-getColor remote..." notify
    #1 lnc_target !
    "blue" lnc-getColor "blue" strcmp if me @ "FAIL: lnc-getColor remote with no props." notify exit then
    lnc_target @ "/_prefs/_appregistry/remote_read" "yes" setprop
    lnc_target @ "/_prefs/_appregistry/remote_write" "yes" setprop
    lnc_target @ COLORAPP "blue" "portia" appset-setAttribute pop
    "blue" lnc-getColor "portia" strcmp if me @ "FAIL: lnc-getColor remote with props." notify exit then
    lnc_target @ COLORAPP "blue" appset-removeAttribute pop
    lnc_target @ "/_prefs/_appregistry/remote_read" remove_prop
    lnc_target @ "/_prefs/_appregistry/remote_write" remove_prop
    depth stacklen @ = not if me @ "FAIL: stacksize for lnc-getColor remote" notify exit then )

    me @ "TESTS PASSED." notify
;
  
: main (s -- Provides a quick way to play with color )
    dup
    strlen not if me @ "lib-nu-color: To use this test driver, supply some "
                       "string as an argument with color codes.  The " strcat
                       "colorized result will then be printed out.  Or, " strcat
                       "enter 'td' to run the test driver." strcat
                  notify pop exit
    then

    dup "td" strcmp not if
        me @ "Test driver disabled on SpinDizzy." notify exit
        pop
        lnc-td
        exit
    then

    me @ swap lnc-parse-me notify
    depth 0 = not if me @ "lib-nu-color:  Memory leak found!" notify then
;
  
PUBLIC lnc-color-codes?
PUBLIC lnc-parse
PUBLIC lnc-parse-me
( PUBLIC lnc-getColor )
.
c
q
@set lib-nu-color.muf=3
@set lib-nu-color.muf=W
@set lib-nu-color.muf=L
@set lib-nu-color.muf=V
@set lib-nu-color.muf=/_defs/lnc-color-codes?:"$lib/nu-color" match "lnc-color-codes?" call
@set lib-nu-color.muf=/_defs/lnc-parse:"$lib/nu-color" match "lnc-parse" call
@set lib-nu-color.muf=/_defs/lnc-parse-me:"$lib/nu-color" match "lnc-parse-me" call
#REM @set lib-nu-color.muf=/_defs/lnc-getColor:"$lib/nu-color" match "lnc-getColor" call

@set lib-nu-color.muf=/ansifree/0/0:reset
@set lib-nu-color.muf=/ansifree/0/1:bold
@set lib-nu-color.muf=/ansifree/0/2:reverse
@set lib-nu-color.muf=/ansifree/0/3:reset
@set lib-nu-color.muf=/ansifree/0/4:reset
@set lib-nu-color.muf=/ansifree/0/5:flash
@set lib-nu-color.muf=/ansifree/0/6:reset
@set lib-nu-color.muf=/ansifree/0/7:dim
@set lib-nu-color.muf=/ansifree/0/8:reverse
@set lib-nu-color.muf=/ansifree/0/9:reset
@set lib-nu-color.muf=/ansifree/1/0:black
@set lib-nu-color.muf=/ansifree/1/1:red
@set lib-nu-color.muf=/ansifree/1/2:green
@set lib-nu-color.muf=/ansifree/1/3:yellow
@set lib-nu-color.muf=/ansifree/1/4:blue
@set lib-nu-color.muf=/ansifree/1/5:magenta
@set lib-nu-color.muf=/ansifree/1/6:cyan
@set lib-nu-color.muf=/ansifree/1/7:white
@set lib-nu-color.muf=/ansifree/1/8:black
@set lib-nu-color.muf=/ansifree/1/9:black
@set lib-nu-color.muf=/ansifree/2/0:bg_black
@set lib-nu-color.muf=/ansifree/2/1:bg_red
@set lib-nu-color.muf=/ansifree/2/2:bg_green
@set lib-nu-color.muf=/ansifree/2/3:bg_yellow
@set lib-nu-color.muf=/ansifree/2/4:bg_blue
@set lib-nu-color.muf=/ansifree/2/5:bg_magenta
@set lib-nu-color.muf=/ansifree/2/6:bg_cyan
@set lib-nu-color.muf=/ansifree/2/7:bg_white
@set lib-nu-color.muf=/ansifree/2/8:bg_black
@set lib-nu-color.muf=/ansifree/2/9:bg_black

@set lib-nu-color.muf=/color/black:black
@set lib-nu-color.muf=/color/red:red
@set lib-nu-color.muf=/color/yellow:yellow
@set lib-nu-color.muf=/color/green:green
@set lib-nu-color.muf=/color/cyan:cyan
@set lib-nu-color.muf=/color/blue:blue
@set lib-nu-color.muf=/color/magenta:magenta
@set lib-nu-color.muf=/color/white:white
@set lib-nu-color.muf=/color/bg_black:bg_black
@set lib-nu-color.muf=/color/bg_red:bg_red
@set lib-nu-color.muf=/color/bg_yellow:bg_yellow
@set lib-nu-color.muf=/color/bg_green:bg_green
@set lib-nu-color.muf=/color/bg_cyan:bg_cyan
@set lib-nu-color.muf=/color/bg_blue:bg_blue
@set lib-nu-color.muf=/color/bg_magenta:bg_magenta
@set lib-nu-color.muf=/color/bg_white:bg_white
@set lib-nu-color.muf=/color/reset:reset
@set lib-nu-color.muf=/color/bold:bold
@set lib-nu-color.muf=/color/dim:dim
@set lib-nu-color.muf=/color/uline:uline
@set lib-nu-color.muf=/color/flash:flash
@set lib-nu-color.muf=/color/reverse:reverse
@set lib-nu-color.muf=/color/bk:black
@set lib-nu-color.muf=/color/r:red
@set lib-nu-color.muf=/color/y:yellow
@set lib-nu-color.muf=/color/g:green
@set lib-nu-color.muf=/color/c:cyan
@set lib-nu-color.muf=/color/b:blue
@set lib-nu-color.muf=/color/m:magenta
@set lib-nu-color.muf=/color/w:white
@set lib-nu-color.muf=/color/bgbk:bg_black
@set lib-nu-color.muf=/color/bgr:bg_red
@set lib-nu-color.muf=/color/bgy:bg_yellow
@set lib-nu-color.muf=/color/bgg:bg_green
@set lib-nu-color.muf=/color/bgc:bg_cyan
@set lib-nu-color.muf=/color/bgb:bg_blue
@set lib-nu-color.muf=/color/bgm:bg_magenta
@set lib-nu-color.muf=/color/bgw:bg_white
@set lib-nu-color.muf=/color/dark:dim
@set lib-nu-color.muf=/color/underline:uline
@set lib-nu-color.muf=/color/blink:flash
@set lib-nu-color.muf=/_lib-created:Morticon
@set lib-nu-color.muf=/_lib-version:1.01
@reg lib-nu-color.muf=lib/nu-color
