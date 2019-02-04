( /quote -dsend -S '/data/spindizzy/muf/lscat.muf )

@prog cmd-lscat.muf
1 5000 d
i
( Tiny, but complete list printer  - Morticon@SpinDizzy 2006)
  
: print-list ( d s -- Given dbref d and list s, output the list contents to the
                      user.  Does no security checks )
    var target
    var listProp
    listProp !
    target !
  
    ( Set up the for loop )
    1
    target @ listProp @ getpropstr atoi
    1
    FOR
        ( Print out each line to the user )
        intostr listProp @ "/" strcat swap strcat target @ swap getpropstr
        me @ swap notify
    REPEAT
;
  
: checkPermission ( d s -- i  Verifies me can access dbref d and list s.
                              Returns 1 if can, 0 if can't. )
    swap
    ( No point continuing if not valid )
    dup ok? not if pop pop 0 exit then
  
    ( If does not control, then say no permission )
    me @ swap controls not if pop pop 0 exit then
  
    ( If you are not a wizard and @ is seen in the prop, then no permission
      as that is likely a restricted prop )
    "@" instr if
        me @ "w" flag? not if 0 exit then
    then
  
    ( Everything passed.  Permission granted )
    1
;
  

: main ( s -- Prints out a list to the user, security permitting )
    "me" match me !

    "=" explode
    2 = not if
        me @ "You must specify a listname to print out.  Syntax: "
             command @ strcat " <obj>=<listname>" strcat
        notify
        exit
    then

    ( Syntax seems right, so parse it )
    strip match
    ( Get home, if given )
    dup #-3 dbcmp if pop me @ getlink then
    swap strip "#" strcat
    ( Now we have  d s )
    over ok? not if me @ "ERROR: Object given is not valid!" notify exit then

    ( Check for permission )
    over over checkPermission if
        ( Permission granted.  Check for prop existence.  If doesn't exist,
          say so and exit )
        over over getpropstr strlen not if
            me @ "ERROR: Invalid listname!" notify exit
        then
    
        ( Finally, show the contents )
        print-list
    else
        me @ "Permission denied." notify
    then
;
.
c
q
@set lscat.muf=W
@set lscat.muf=L
