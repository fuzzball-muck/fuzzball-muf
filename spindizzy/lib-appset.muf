( /quote -dsend -S '/data/spindizzy/muf/lib-appset.muf )

@prog lib-appset.muf
1 50000 d
i
(
  lib-appset version 1.01
      Appset library.  This allows a uniform way for any program to access a
    registry of sorts for applications to store selected data.  It also allows
    creation of 'control panel' like programs that could go through and change
    the options without running the program.  It also allows read access to 
    certain props on rooms the caller does not own.
  
      Note that the application name, as used below, must be composed of
    alphanumeric and underscores only.  Some checking will be done to mostly
    enforce this.  Attribute names may additionally contain / to designate
    subattributes, just like in propdirs.
  
      Functions that do not have the word 'global' in them work on the
    character/zombie/object that is running [calling] the program.  Global
    functions behave as in appset-getGlobal.
  
    Public Functions [all functions have d, the player or object to access.
        If d != me, then the remote object needs to give explicit permission,
        or else it will throw an exception, the stack less d]:
  
 appset-unset?             ? -- i  Returns 1 if value, as returned by
                                   appset-getsetting and appset-getglobal,
                                   is unset.  0 if it is set.
  
 appset-remoteAccess?      d -- i  Returns 1 if cannot read from remote object
  
 appset-locked?            d -- i  Returns 1 if locked [cannot set attributes].
  
 appset-app?             d s -- i  Returns 1 if application name s exists
                                   on local object.
  
 appset-globalApp?       d s -- i  Returns 1 if application name exists
                                   somewhere up the environment tree.
                                   If prefixed with an @, only room #0
                                   is checked.
  
 appset-getAttribute  d s1 s2 -- ?  Given application name s1 and attribute
                                    s2, return the contents of the attribute
                                    on the local object.  If invalid, returns
                                    the equivalent of unset.
  
 appset-getAttributeDesc d s1 s2 -- s  Given application name s1 and attribute
                                      s2, return the human readable description
                                     of the attribute, or "" if no description.
  
 appset-getGlobal    d s1 s2 -- ?  Given application name s1 and attribute s2,
                                   return the attribute contents for the
                                   region/realm by going up the environment
                                   tree until the contents are found.  If
                                   application name is prefixed with a @,
                                   only room #0 is checked.  If invalid,
                                   returns the equivalent of unset.

 appset-getGlobalDesc d s1 s2 -- s  Given application name s1 and attribute s2,
                                    return the human readable attribute
                                    description for the region/realm by going
                                    up the environment tree until the attribute
                                    is found.  If application name is prefixed
                                    with a @, only room #0 is checked.  Returns
                                    "" if no description or if not found.

 appset-setAttribute  d s1 s2 ?? -- i Given application name s1 and attribute s2,
                                     set the contents of the attribute on the
                                     local object with ??.  Returns 1 if
                                     successful, 0 if not.
  
 appset-setAttributeDesc d s1 s2 s3 -- i  Given application name s1 and attribute
                                      s2, set the description of the attribute
                                      to s3.  Returns 1 if successful, 0 if not.
  
 appset-removeAttribute d s1 s2 -- i  Given application name s1 and attribute s2,
                                     erase the given attribute and all attributes
                                     underneath it on local object.  Returns 1
                                     if success, 0 if not.
  
 appset-dir?          d s1 s2 -- i  Given application name s1 and attribute s2,
                                    return 1 if attribute contains other
                                    attributes, 0 if not.

 appset-globalDir?    d s1 s2 -- i  Given application name s1 and attribute s2,
                                    return 1 if attribute for the region/realm
                                    contains other attributes, 0 if not.
                                    If application name is prefixed with a @,
                                    only room #0 is checked.
  
 appset-getAppList          d -- A  Returns an array of strings that list all
                                    the applications on the local object.
  
 appset-getGlobalAppList    d -- A  Returns an array of strings that list all
                                    all applications up the environment tree.
  
 appset-getAttributeList d s1 s2 -- A Returns an array of strings with attribute
                                    names for application s1 and attribute
                                    s2.  This will show all subattributes of s2.
                                    To show root-level attributes, set s2 to
                                    "".

 appset-getGlobalAttributeList d s1 s2 -- A  Returns array of strings with
                                    attribute names for application s1 and
                                    attribute s2.  This will show all
                                    subattributes of s2.  Set s2 to "" for root-
                                    level attributes, and prefix s1 with @ 
                                    to check room #0 only, otherwise checks up
                                    the environment.
  
 appset-getGlobalAppList     d -- A  Returns an array of strings of 
                                     application names present up the
                                     environment/region/area.
)
  
$lib-version 1.01
  
$def ROOTPROP "/_prefs/_appregistry/_/"
$def APPPROP "/_prefs/_appregistry/_/apps/"
$def APPPROPDESC "/_prefs/_appregistry/_/appdescs/"
$def LOCKPROP "/_prefs/_appregistry/locked"
$def REMOTEACCESS "/_prefs/_appregistry/remote_read"
$def REMOTEWRITE "/_prefs/_appregistry/remote_write"
$def DEFAULTAPPNAME "_"
  
lvar appset-me  ( My local version of me )
lvar appset-realMe  ( Who is actually calling the program )
  
( --Helpers-- )
  
: validAppName? ( s -- i Returns 1 if valid appname, 0 if not )
    "s" checkargs
    "*[./\\\* :!@]*" smatch not
;
  
: validAttributeName? ( s -- i Returns 1 if valid attribute name, 0 if not )
    "s" checkargs
    "*[.\\\* :!@]*" smatch not
;
  
: getAppNameFromProp (s -- s  Given full prop, return application name )
    APPPROP strlen strcut swap pop
    dup "/" instr dup if
        strcut pop
    else
        pop
    then
;
 
: getAttributeNameFromProp (s -- s Given full prop, return attribute name )
    APPPROP strlen strcut swap pop
    ( Prefix removed, now get rid of app name )
    dup "/" instr dup not if
        ( No attribute, so return blank )
        pop pop ""
    else
        strcut swap pop
    then
;
  
: defaultApplication ( s -- s  If string is blank, returns default
                       application name, else returns string )
    dup strlen not if pop DEFAULTAPPNAME exit then
;
  
: setupPublicCall ( d  -- Does important setup stuff when any public call
                          is made.  d is the dbref used when getting settings
                          and determining where to go up the env tree.  It must
                          be a player or thing.  If d != me, and if the object
                          does not allow remote access, this will throw an
                          exception. )
    var target
    target !

    "me" match appset-realMe !

    target @ appset-realMe @ dbcmp if
        ( They want themself, which is OK.  No checks needed. )
        target @ appset-me !
    else
        ( They want a remote object, so check for explicit permission. )
        ( If no permission given, throw exception! )
        target @ player? target @ thing? or not if
            "Target object is invalid or not a player or thing." abort
        then
  
        target @ REMOTEACCESS getpropstr "{y|yes}" smatch if
            ( They gave permission )
            target @ appset-me !
        else
            ( No permission!  Throw exception )
            "Target object has not granted permission for lib-appset." abort
        then
    then
;

: getSubProps  (d s -- A  Given dbref and prop, return array of strings
                           containing subprops of s )
    var dbObject
    var currProp

    currProp !
    dbObject !

    dbObject @ currProp @ nextprop dup currProp !

    strlen if
        ( There are props to process )
  
        ( Start array )
        {

        BEGIN
            currProp @ getAttributeNameFromProp

            ( Go to the next attribute name, if possible )
            dbObject @ currProp @ nextprop dup currProp !
            strlen not
        UNTIL
  
        ( Finish up the array and return it )
        }list
    else
        ( Invalid prop, return empty )
        { }list
    then
;
  
( --Publics-- )
  
: appset-unset? (? -- i Returns 1 if propval is unset or invalid, 0 otherwise )
    "?" checkargs
  
    dup int? if
        0 =
    else 
        dup string? if
            strlen not
        else
            pop 0
        then
    then
;
  
: appset-remoteAccess?  ( d -- i  Returns 1 if object remotely readable,
                                  0 if not)
    "D" checkargs

    1 TRY
        setupPublicCall
    CATCH
        pop
        0 exit
    ENDCATCH

    1
;
  
: appset-locked? ( d -- i  Returns 1 if attributes locked, 0 if not )
    "D" checkargs
    setupPublicCall

    appset-me @ LOCKPROP getpropstr "{y|yes}" smatch
    
    appset-me @ appset-realMe @ dbcmp not if
        appset-me @ REMOTEWRITE getpropstr "{y|yes}" smatch not or
    then
;
  
: appset-app? (d s -- i  Returns 1 if app exists )
    "Ds" checkargs
    swap
    setupPublicCall
    dup validAppName? not if pop 0 exit then
  
    appset-me @ APPPROP 3 rotate defaultApplication strcat propdir?
;
  
: appset-globalApp? (d s -- i  Returns 1 if global app exists )
    var checkZeroOnly
    var propString
  
    "Ds" checkargs
    swap
    setupPublicCall
      
    ( Determine if this is a room #0 only or not, then strip out @ )
    dup "@" instr 1 = if
        1 strcut swap pop
        1 checkZeroOnly !
    else
        0 checkZeroOnly !
    then

    dup validAppName? not if pop 0 exit then
  
    ( Assemble prop string and store it off )
    APPPROP 2 rotate defaultApplication strcat
    propString !

    ( If room #0 only, do that and exit, else go up the env tree till we hit
      zero, checking for the propdir along the way.  If found, stop early and
      return )
    checkZeroOnly @ if
        #0 propString @ propdir?
    else
        appset-me @ location
        BEGIN
            dup propString @ propdir?
  
            ( If prop is dir, we're done! )
            dup if
                pop pop 1 exit
            then
  
            pop
            location
            dup #0 dbcmp
        UNTIL
        pop
        ( Havn't found app yet, just try on #0 and exit )
        #0 propString @ propdir?
    then
;
  
: appset-getAttribute (d s1 s2 -- ?  Get contents of application s1 attribute s2 )
    "Dss" checkargs
    rot
    setupPublicCall
    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then
  
    appset-me @
    APPPROP 4 rotate defaultApplication strcat "/" strcat 3 rotate strcat
    getprop
;
  
: appset-getAttributeDesc (d s1 s2 -- s  Get desc of application s1 attribute s2 )
    "Dss" checkargs
    rot
    setupPublicCall
    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then
  
    appset-me @ 
    APPPROPDESC 4 rotate defaultApplication strcat "/" strcat 3 rotate strcat
    getpropstr
;

: appset-getGlobal (d s1 s2 -- ?  Get contents of application s1 attribute s2 
                                up env tree. App with @ prefix checks #0 only)
    var checkZeroOnly
    var propString
  
    "Dss" checkargs
    rot
    setupPublicCall
      
    ( Determine if this is a room #0 only or not, then strip out @ )
    2 pick "@" instr 1 = if
        swap 1 strcut swap pop swap
        1 checkZeroOnly !
    else
        0 checkZeroOnly !
    then

    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then
  
    ( Assemble prop string and store it off )
    APPPROP 3 rotate defaultApplication strcat "/" strcat 2 rotate strcat
    propString !

    ( If room #0 only, do that and exit, else go up the env tree till we hit
      zero, checking for the prop along the way.  If found, stop early and
      return )
    checkZeroOnly @ if
        #0 propString @ getprop
    else
        appset-me @ location
        BEGIN
            dup propString @ getprop
  
            ( If prop is set, we're done! )
            dup appset-unset? not if
                swap pop exit
            then
  
            pop
            location
            dup #0 dbcmp
        UNTIL
        pop
        ( Havn't found attribute yet, just try on #0 and exit )
        #0 propString @ getprop
    then
;
  
: appset-getGlobalDesc (d s1 s2 -- s  Get attribute description for app s1,
                                    attribute s2.  Prefix app with @ for
                                    room #0 only )
    var checkZeroOnly
    var propString
  
    "Dss" checkargs
    rot
    setupPublicCall
      
    ( Determine if this is a room #0 only or not, then strip out @ )
    2 pick "@" instr 1 = if
        swap 1 strcut swap pop swap
        1 checkZeroOnly !
    else
        0 checkZeroOnly !
    then

    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then
  
    ( Assemble prop string and store it off )
    APPPROPDESC 3 rotate defaultApplication strcat "/" strcat 2 rotate strcat
    propString !

    ( If room #0 only, do that and exit, else go up the env tree till we hit
      zero, checking for the prop along the way.  If found, stop early and
      return )
    checkZeroOnly @ if
        #0 propString @ getpropstr
    else
        appset-me @ location
        BEGIN
            dup propString @ getpropstr
  
            ( If prop desc is set, we're done! )
            dup strlen if
                swap pop exit
            then
  
            pop
            location
            dup #0 dbcmp
        UNTIL
        pop
        ( Havn't found attribute yet, just try on #0 and exit )
        #0 propString @ getpropstr
    then
;
  
: appset-setAttribute (d s1 s2 ?? -- i  Set ?? on attribute s2 for app s1.  Returns
                                    1 if success, 0 if failure )
    var target
    "Dss?" checkargs
    4 rotate
    dup target !
    setupPublicCall
  
    ( Locked - cannot set things )
    target @ appset-locked? if 3 popn 0 exit then
  
    3 pick validAppName? not if 3 popn 0 exit then
    2 pick validAttributeName? not if 3 popn 0 exit then
  
    appset-me @
    APPPROP 5 rotate defaultApplication strcat "/" strcat 4 rotate strcat 3 rotate
    setprop
    1
;
  
: appset-setAttributeDesc (d s1 s2 s3 -- Set app s1, attribute s2 description to s3)
    var target
    "Dsss" checkargs
    4 rotate
    dup target !
    setupPublicCall
  
    ( Locked - cannot set descs )
    target @ appset-locked? if 3 popn 0 exit then
  
    3 pick validAppName? not if 3 popn 0 exit then
    2 pick validAttributeName? not if 3 popn 0 exit then
  
    appset-me @
    APPPROPDESC 5 rotate defaultApplication strcat "/" strcat 4 rotate strcat 3 rotate
    setprop
    1
;
  
: appset-removeAttribute (d s1 s2 -- i Remove attribute s2 from app s1.  Return 1
                                    if success, 0 if not )
    var target
    "Dss" checkargs
    rot
    dup target !
    setupPublicCall
    ( Locked - cannot erase things )
    target @ appset-locked? if 2 popn 0 exit then

    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then

    ( Build the string )  
    APPPROPDESC 3 pick defaultApplication strcat "/" strcat over strcat
    dup
    APPPROP 5 rotate defaultApplication strcat "/" strcat 4 rotate strcat
    dup

    appset-me @ swap remove_prop
    appset-me @ swap "/" strcat remove_prop
    appset-me @ swap remove_prop
    appset-me @ swap "/" strcat remove_prop
    1
;
  
: appset-dir? (d s1 s2 -- i  Returns 1 if app s1 and attribute s2 is a propdir )
    "dss" checkargs
    rot
    setupPublicCall
    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then
  
    appset-me @
    APPPROP 4 rotate defaultApplication strcat "/" strcat 3 rotate strcat
    propdir?
;
  
: appset-globalDir? (d s1 s2 -- i  Returns 1 if global attribute is a propdir,
                                    0 if not)
    var checkZeroOnly
    var propString
  
    "Dss" checkargs
    rot
    setupPublicCall
      
    ( Determine if this is a room #0 only or not, then strip out @ )
    2 pick "@" instr 1 = if
        swap 1 strcut swap pop swap
        1 checkZeroOnly !
    else
        0 checkZeroOnly !
    then

    2 pick validAppName? not if 2 popn 0 exit then
    dup validAttributeName? not if 2 popn 0 exit then
  
    ( Assemble prop string and store it off )
    APPPROP 3 rotate defaultApplication strcat "/" strcat 2 rotate strcat
    propString !

    ( If room #0 only, do that and exit, else go up the env tree till we hit
      zero, checking for the prop along the way.  If found, stop early and
      return )
    checkZeroOnly @ if
        #0 propString @ propdir?
    else
        appset-me @ location
        BEGIN
            dup propString @ getprop
  
            ( If prop is set, we're done! )
            appset-unset? not if
                propString @ propdir? exit
            then
  
            location
            dup #0 dbcmp
        UNTIL
        pop
        ( Havn't found attribute yet, just try on #0 and exit )
        #0 propString @ propdir?
    then
;
  
: appset-getAppList (d -- A  Returns array of application names for local object)
    var currProp
    "D" checkargs
    setupPublicCall
  
    appset-me @ APPPROP nextprop dup currProp !
    strlen if
        ( There are applications, so put them into an array )
  
        ( Start array )
        {
  
        BEGIN
            currProp @ getAppNameFromProp

            ( Go to the next application name, if possible )
            appset-me @ currProp @ nextprop dup currProp !
            strlen not
        UNTIL
  
        ( Finish up the array and return it )
        }list
    else
        { }list
    then
;
  
: appset-getAttributeList (d s1 s2 -- A  Given app s1 and attribute s2, return
                                     an array of strings with all the attributes
                                     at that level. s2="" for top level for
                                     app )
    var currProp
    "Dss" checkargs
    rot
    setupPublicCall
    2 pick validAppName? not if 2 popn { }list exit then
    dup validAttributeName? not if 2 popn { }list exit then
  
    dup strlen not if
        ( Empty string, so make top level )
        pop
        APPPROP swap defaultApplication strcat "/" strcat
        currProp !
    else
        APPPROP 3 rotate defaultApplication strcat "/" strcat swap strcat "/" strcat
        currProp !
    then

    appset-me @ currProp @ getSubProps
;
  
: appset-getGlobalAttributeList (d s1 s2 -- A  Given app s1 and attribute s2, 
                                              return array of strings that
                                              list all subattributes.  Have
                                              s2 be "" for app root, and
                                              have s1 be prefixed with @ for
                                              room #0 only )
    var checkZeroOnly
    var propString
  
    "dss" checkargs
    rot
    setupPublicCall
      
    ( Determine if this is a room #0 only or not, then strip out @ )
    2 pick "@" instr 1 = if
        swap 1 strcut swap pop swap
        1 checkZeroOnly !
    else
        0 checkZeroOnly !
    then

    2 pick validAppName? not if 2 popn { }list exit then
    dup validAttributeName? not if 2 popn { }list exit then
  
    ( Assemble app prop string and store it off )
    APPPROP 3 rotate defaultApplication strcat "/" strcat swap strcat
    propString !

    ( If room #0 only, do that and exit, else go up the env tree till we hit
      zero, checking for the prop along the way.  If found, stop early and
      return )
    checkZeroOnly @ if
        #0 propString @ getSubProps
    else
        appset-me @ location
        BEGIN
            ( If prop is a directory, get the array and we're done )
            dup propString @ propdir? if
                propString @ getSubProps exit
            then
  
            location
            dup #0 dbcmp
        UNTIL
        pop
        ( Havn't found attribute yet, just try on #0 and exit )
        #0 propString @ getSubProps
    then
;
  
: appset-getGlobalAppList (d -- A  Returns a list of all application
                                        names up the env tree)
    var applicationSet  ( key value pair to prevent dupes )
    var currentRoom
    
    "D" checkargs
    setupPublicCall
  
    ( Init the variables )
    { }dict applicationSet !
    appset-me @ location currentRoom !
    
    ( On each room up the env, add all the applications to the dict, with
      key = value.  At the end, convert it into an array and return it )
  
    ( Room loop )
    BEGIN
        currentRoom @ APPPROP nextprop
        dup strlen if
            ( app loop on room )
            BEGIN
                ( Add app name to dict )
                dup getAppNameFromProp
                dup applicationSet @ swap array_insertitem applicationSet !

                currentRoom @ swap nextprop
                dup strlen not
            UNTIL
            pop
        else
            pop
        then

        currentRoom @ #0 dbcmp if
            break
        then

        currentRoom @ location currentRoom !
    ( This will be broken out of once room #0 has been processed )
    REPEAT

    ( Return the array of strings )
    applicationSet @ array_vals array_make
;
  
PUBLIC appset-unset?
PUBLIC appset-remoteAccess?
PUBLIC appset-locked?
PUBLIC appset-getAttribute
PUBLIC appset-getAttributeDesc
PUBLIC appset-getGlobal
PUBLIC appset-getGlobalDesc
PUBLIC appset-setAttribute
PUBLIC appset-setAttributeDesc
PUBLIC appset-removeAttribute
PUBLIC appset-dir?
PUBLIC appset-globalDir?
PUBLIC appset-app?
PUBLIC appset-globalApp?
PUBLIC appset-getAppList
PUBLIC appset-getAttributeList
PUBLIC appset-getGlobalAttributeList
PUBLIC appset-getGlobalAppList
.
c
q
@set lib-appset=/_defs/appset-unset?:"$lib/appset" match "appset-unset?" call
@set lib-appset=/_defs/appset-remoteAccess?:"$lib/appset" match "appset-remoteAccess?" call
@set lib-appset=/_defs/appset-locked?:"$lib/appset" match "appset-locked?" call
@set lib-appset=/_defs/appset-getAttribute:"$lib/appset" match "appset-getAttribute" call
@set lib-appset=/_defs/appset-getAttributeDesc:"$lib/appset" match "appset-getAttributeDesc" call
@set lib-appset=/_defs/appset-getGlobal:"$lib/appset" match "appset-getGlobal" call
@set lib-appset=/_defs/appset-getGlobalDesc:"$lib/appset" match "appset-getGlobalDesc" call
@set lib-appset=/_defs/appset-setAttribute:"$lib/appset" match "appset-setAttribute" call
@set lib-appset=/_defs/appset-setAttributeDesc:"$lib/appset" match "appset-setAttributeDesc" call
@set lib-appset=/_defs/appset-removeAttribute:"$lib/appset" match "appset-removeAttribute" call
@set lib-appset=/_defs/appset-dir?:"$lib/appset" match "appset-dir?" call
@set lib-appset=/_defs/appset-globalDir?:"$lib/appset" match "appset-globalDir?" call
@set lib-appset=/_defs/appset-app?:"$lib/appset" match "appset-app?" call
@set lib-appset=/_defs/appset-globalApp?:"$lib/appset" match "appset-globalApp?" call
@set lib-appset=/_defs/appset-getAppList:"$lib/appset" match "appset-getAppList" call
@set lib-appset=/_defs/appset-getAttributeList:"$lib/appset" match "appset-getAttributeList" call
@set lib-appset=/_defs/appset-getGlobalAttributeList:"$lib/appset" match "appset-getGlobalAttributeList" call
@set lib-appset=/_defs/appset-getGlobalAppList:"$lib/appset" match "appset-getGlobalAppList" call
@set lib-appset=/_lib-created:Morticon
@set lib-appset=/_lib-version:1.01
@reg lib-appset.muf=lib/appset
