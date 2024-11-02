@program cmd-programs
1 99999 d
1 i
( cmd-programs.muf by Natasha@HLM
  A Fuzzball 6 program lister.
 
  Copyright 2003 Natasha O'Brien. Copyright 2003 Here Lie Monsters.
  "@view $box/mit" for license information.
)
 
$include $lib/strings
 
: main  ( str -- )
    STRparse pop  ( strX strY )
 
    var! vsearch  ( strX )
    #-1 var! vowner
    "FV" var! vflags  ( strX )
 
    dup if  ( strX )
        case
            "help" stringcmp not when .showhelp exit end
            "mine" stringcmp not when
                me @ vowner !
                "F" vflags !
            end
            default
              "I don't know what you mean by '#%s'. 'programs #help' for help." fmtstring tell  (  )
              exit
            end
        endcase
    else pop then  (  )
 
    " Dbref Name                     Author               Owner      Modified @view" "bold" textattr tell
 
    background  (  )
    #-1 begin  ( dbStart )
        vowner @ "*" vflags @ findnext  ( db )
        dup ok?  ( db boolOK? )
    while  ( db )
        dup  ( db db )
        dup "_note" getpropstr dup if "\r       " swap strcat then  ( db db strNote )
 
        ( Wait, are we really listing this object? )
        vsearch @ if
            over over "%s%D" fmtstring vsearch @ instring not if  ( db db strNote )
                pop pop continue  ( db )
            then  ( db db strNote )
        then swap  ( db strNote db )
 
        dup "_docs" getpropstr if "\[[1;32myes\[[0m" else "\[[1;31mno\[[0m" then swap  ( db strNote strDocs db )
        dup timestamps pop pop swap pop "%D" swap timefmt swap  ( db strNote strDocs strModified db )
        dup owner swap  ( db strNote strDocs strModified dbOwner db )
        dup "_author" getpropstr swap  ( db strNote strDocs strModified dbOwner strAuthor db )
        dup  ( db strNote strDocs strModified dbOwner strAuthor db db )
        "%6.6d %-24.24D %-20.20s %-10.10D %8.8s %-4.4s%s" fmtstring tell
    repeat pop  (  )
 
    "Done." tell
;
.
c
q
@register #me cmd-programs=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
lsedit $tmp/prog1=_help
.del 1 $
programs
programs <search>
programs #mine <search>

Lists @listable MUF programs on the MUCK (that is, programs set Viewable).
The 'Author' and 'Description' fields are taken from the programs' $author
and $note directives (that is, the _author and _note properties). If running
@view on the program would show documentation (its _docs property is set),
the @view field reads 'yes'. If <search> is given, only programs containing
<search> in their names or descriptions ($note) will be listed.

If '#mine' is given, programs lists programs you own, @listable or not,
instead of the MUCK's Viewable programs.
.end
@action programs;plib;proglib=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
