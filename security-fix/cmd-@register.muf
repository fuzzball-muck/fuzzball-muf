@program cmd-@register.muf
1 100000 d
i
$define .tell me @ swap notify $enddef
$define sls striplead $enddef
$define sts striptail $enddef
$define strip sls sts $enddef
    
lvar regobj
lvar regprop
    
: split
    swap over over swap
    instr dup not if
        pop swap pop ""
    else
        1 - strcut rot
        strlen strcut
        swap pop
    then
;
    
 
( Determines if I'm allowed to set prop 's'.  Only wizards can set
  wizard props. )
: allowed_prop? ( s -- b )
    me @ "WIZARD" flag? if
        pop 1 exit ( Wizards can set anything )
    then
    
    ( We cannot start with @ or ~, and we cannot have /@ or /~ in the
      prop string )
    dup dup "~" stringpfx swap "@" stringpfx or if
        pop 0 exit
    then
    
    dup dup "/~" instring swap "/@" instring or if
        pop 0 exit
    then
    
    pop 1
;
  
( returns #-1 if prop not found.  #-2 if has bad value. )
: get_propref (d s -- d)
    over over
    getprop
    
    (* Note: What this used to do, is the prop was a string or an
     * integer and not a 'ref', it would try to 'atoi dbref' it,
     * and if the value of the string/integer returned a ref, it would
     * re-store it as a ref thus destroying original data.
     *
     * My options were to either have it do an atoi dbref and return
     * the ref which would non-destructively mimic the old behavior,
     * or have it return #-2 for all strings and integers.
     *
     * I chose to do the latter because that seems more true to the
     * spirit and security of the program.  Parsing random strings and
     * integers into ref's just doesn't make sense to me and seems like
     * a legacy relic.
     *
     * Of course, that decision may break @register's expected behavior
     * on some MUCKs that have registrations improperly configured, so
     * that is why there is this lengthly explanation.  For those MUCKs,
     * it is recommmended that you re-register your broken props rather
     * than modify this code.
     *)
    dup if
        dup dbref? not if pop #-2 then
    else
        pop #-1
    then
    rot rot pop pop
;
  
  
( makes user readable string rep of registered prop )
: pretty_propref (d s -- s)
    over over get_propref
    dup if
        dup ok? if
            dup unparseobj
            over "_version" getpropstr
            dup if
                "     Ver. " swap strcat strcat
            else pop
            then
            swap "_lib-version" getpropstr
            dup if
                "     Lib.ver. " swap strcat strcat
            else pop
            then
        else pop "<garbage>"
        then
        over ": " strcat swap strcat
        regprop @ strlen strcut swap pop
    else pop ""
    then
    rot rot pop pop
;
  
  
: list-props ( d s -- )
    begin
        dup while
        dup strlen 1 - strcut
        dup "/" strcmp if
            strcat break
        else pop
        then
    repeat
    "/" strcat over swap nextprop
        
    begin
        dup while

        ( Don't show @ props -- but do show ~ props )
        dup dup "@" stringpfx swap "/@" instring or if
          over swap nextprop continue
        then

        over over pretty_propref
        dup if
            "  " swap strcat .tell
        else
            pop
        then
        over over propdir? if
            dup regprop @ strlen strcut swap pop
            "    " swap strcat
            "/ (directory)" strcat .tell
        then
        over swap nextprop
    repeat
    pop pop
;
    
: do-help
"Syntaxes:"
"  The following prefixes set what the target object and the target propdir"
"   are.  The default target propdir is \"_reg/\" and the default target"
"   object is #0."
"      #me"
"          Sets target object to you, and propdir to the default \"_reg/\"."
"      #prop <targobj>:<propdir>"
"          Sets target object to <targobj> and propdir to <propdir>."
"  The following are the command syntaxes"
"      @register [<prefix>]"
"          List all registered objects in the target propdir on target object."
"      @register [<prefix>] <subpropdir>"
"          List all registered objects in <subpropdir> in the target propdir."
"      @register [<prefix>] <object> = <name>"
"          Register <name> to <object> in the propdir on the target object."
"Example: @register #prop here:_disconnect gen-sweeproom=cleanup"
"  This registers the program gen-sweeproom as 'cleanup' in the _disconnect"
"   propdir on the current room."
    18
    begin
         dup while
         dup 1 + rotate .tell
         1 -
    repeat
;
    
: cmd-@register
    "me" match me !
    dup "#help" stringcmp not if
        do-help exit
    then
    sls dup tolower "#me" 3 strncmp not if
        " " split swap pop
        me @ regobj !
        "_reg/" regprop !
    else
        dup tolower "#prop" 5 strncmp not if
            " " split swap pop
            " " split swap
            ":" split
            (rest obj prop)
            swap dup not if pop "me" then
            dup "@" strcmp not if pop "#0" then
            match dup not if
                me @ "I don't see that target object here." notify
                pop pop pop exit
            then
            dup #-2 dbcmp if
                me @ "I don't know which target object you mean." notify
                pop pop pop exit
            then
            me @ over owner dbcmp
            me @ "wizard" flag? or not if
                me @ "Permission Denied." notify
                pop pop pop exit
            then
            regobj !
            (rest prop)
 
            dup not if
                (if no propdir selected, error out)
                me @ "You have to specify a propdir." notify
                pop pop exit
            then
            dup dup strlen 1 - strcut swap pop
            "/" strcmp if "/" strcat then (if doesn't end in /, append /)
            regprop !
        else
            me @ "w" flag? not
            over "=" instr and if
                me @ "Permission denied." notify
                pop exit
            then
            #0 regobj !
            "_reg/" regprop !
        then
    then
    
    dup "=" instr not if
        regobj @ dup #0 dbcmp swap me @ dbcmp or not if
            "You need to specify a value to set with @reg #prop" .tell
            pop exit
        then
        "Registered objects on "
        regobj @ unparseobj strcat
        ":" strcat .tell
        regobj @ regprop @ rot strcat list-props
        "Done." .tell exit
    then
    "=" split strip
    dup not if "You must specify a registration name." .tell exit then
    swap strip
    dup not if
        pop  (Nothing to register; remove $regname)
        " " split if
            pop pop "You cannot have spaces in the registration name." .tell exit
        then
        regobj @ regprop @ 3 pick strcat 
        
        dup allowed_prop? not if
            "You are not allowed to remove that property." .tell pop pop exit
        then
        
        pretty_propref
        dup if
            "Used to be registered as "
            regprop @ strcat swap strcat
            .tell
        else pop "No entry to remove." .tell exit
        then
  
        regobj @ regprop @ 3 pick strcat remove_prop
  
        "Registry entry " regprop @ strcat swap strcat
        " on " strcat regobj @ unparseobj " removed." strcat strcat
        .tell
    else
        match dup not if
            "I don't see that object here." .tell pop exit
        then
        dup #-2 dbcmp if
            "I don't know which object you mean." .tell pop exit
        then
        
        swap " " split if
            pop pop "You cannot have spaces in the registration name." .tell exit
        then
        regobj @ regprop @ 3 pick strcat pretty_propref
        dup if
            "Used to be registered as "
            regprop @ strcat swap strcat
            .tell
        else pop
        then
      
        regobj @ regprop @ 3 pick strcat
        
        dup allowed_prop? not if
            "You are not allowed to set that property." .tell pop pop exit
        then
        
        4 pick setprop
      
        regobj @ regprop @ 3 pick strcat
        pretty_propref "Now registered as "
        regprop @ strcat swap strcat
        " on " strcat regobj @ unparseobj strcat
        .tell
    then
;
.
c
q
