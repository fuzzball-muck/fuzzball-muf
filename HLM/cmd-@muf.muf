@program cmd-@muf
1 99999 d
1 i
( cmd-@muf by Natasha@HLM
  Runs MUF code. A MUF version of @mpi.
 
  Copyright 2002 Natasha O'Brien. Copyright 2002 Here Lie Monsters.
  "@view $box/mit" for license information.
)
$author Natasha O'Brien
$note Runs MUF code you enter. A MUF version of @mpi.
$version 1.0
 
: rtn-pretty  ( arr -- str }  Return a prettily formatted string displaying all the contents of arr. )
    "" swap  ( str arr )
    dup dictionary? var! isDict  ( str arr )
 
    foreach  ( str ?key ?val )
        ( Format a special type? )
        dup string? if  ( str ?key strVal )
            "\\\"" "\"" subst
            "\"%s\"" fmtstring  ( str ?key strVal )
        then  ( str ?key ?val )
        dup dbref? if "%d" fmtstring then
        dup array? if rtn-pretty "{%s}" fmtstring then  ( str ?key ?val )
 
        swap isDict @ if
            ", %~:%~"
        else
            pop ", %~"
        then fmtstring  ( str -str )
 
        strcat  ( str )
    repeat  ( str )
    2 strcut swap pop
;
 
: main  ( str -- )
    0 var! debug
    striplead dup "#" stringpfx if  ( str )
        1 strcut swap pop  ( str )
        " " split swap  ( str strCommand )
        "debug" stringcmp if
            pop .showhelp exit  (  )
        else
            1 debug !  ( str )
        then  ( str )
    then  ( str )
 
    ( The user must be a player, and must have an Mlevel or be a Wizard {Quelled is OK}. )
    me @ player? me @ mlevel me @ "truewizard" flag? or and not if  ( str )
        "@muf is only available to users with a MUCKer bit." tell
        pop exit  (  )
    then  ( str )
 
    ( Make a new program and set its contents. )
    random intostr "@@muf.muf" strcat newprogram  ( str dbProg )
    swap var! programtext  ( dbProg )
    
    0 try  ( dbProg )
 
        dup programtext @  ( dbProg dbProg str )
        ": main %s ;" fmtstring 1 array_make program_setlines  ( dbProg )
 
        ( Program saved. Compile it. )
        dup 1 compile if  ( dbProg )
 
            ( Yay, compiled! Set it D if desired. )
            debug @ if dup "d" set then
 
            ( Run. )
            depth var! howDeep
            "" var! resultStr
            0 var! error
            0 try  ( dbProg )
                dup call  ( dbProg ... )
            catch  ( dbProg strErr )
                "Your program had an error: %s" fmtstring tell  ( dbProg )
                1 error !  ( dbProg )
            endcatch  ( dbProg [...] )
 
            error @ not if  ( dbProg ... )
                depth howDeep @ - array_make rtn-pretty  ( dbProg str )
                "Result: " swap strcat  ( dbProg strMsg )
                tell  ( dbProg )
            then  ( dbProg )
 
        else  ( dbProg )
            ( Boo, didn't compile. )
            "There were compile errors, shown above." tell
        then  ( dbProg )
 
    catch  ( dbProg strExc )
        "@muf encountered an error running your program: %s" fmtstring tell
    endcatch  ( dbProg )
 
    recycle  (  )
;
.
c
q
@register #me cmd-@muf=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
@set $tmp/prog1=W
lsedit $tmp/prog1=_help
.del 1 999
.i 1
@muf <MUF code>
@muf #debug <MUF code>
 
Runs the given MUF code. If #debug is given, the program is run with the 
Debug flag set, showing line by line debug output. To start a program with a 
dbref, include an empty comment before it, such as '@muf () #123 ...'.
.end
@action @muf=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
