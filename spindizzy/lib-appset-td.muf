( /quote -dsend -S '/data/spindizzy/muf/lib-appset-td.muf )

@prog appset-td.muf
1 5000 d
i
( Test driver for lib-appset.  Not to be taken orally.  Not for the other use. )

( To test:
* appset-unset?
* appset-locked?
* appset-getAttribute
* appset-getAttributeDesc
* appset-getGlobal
* appset-getGlobalDesc
* appset-setAttribute
* appset-setAttributeDesc
* appset-removeAttribute
* appset-dir?
* appset-globalDir?
* appset-app?
* appset-globalApp?
* appset-getAppList
* appset-getAttributeList
* appset-getGlobalAttributeList
* appset-getGlobalAppList
* appset-remoteAccess?
* Remote access
)

$include $lib/appset

$def ROOTPROP "/_prefs/_appregistry/_/"
$def APPPROP "/_prefs/_appregistry/_/apps/"
$def APPPROPDESC "/_prefs/_appregistry/_/appdescs/"
$def LOCKPROP "/_prefs/_appregistry/locked"
$def REMOTEACCESS "/_prefs/_appregistry/remote_read"
$def REMOTEWRITE "/_prefs/_appregistry/remote_write"
$def DEFAULTAPPNAME "_"


lvar stacksize

: main
    var target
    "*test" match target !

    pop
    ( Verify in the correct room and stuff )
    "me" match me !
    me @ location #0 dbcmp if me @ "Can't run in room #0" notify exit then
    me @ location location #0 dbcmp if me @ "Must be two rooms below #0" notify exit then
    target @ player? not if me @ "'test' player must exist!" notify exit then

    ( RESET ALL PROPS! )
    me @ location APPPROP remove_prop
    me @ location "/_prefs/_appregistry/_/apps" remove_prop
    me @ location APPPROPDESC remove_prop
    me @ location "/_prefs/_appregistry/_/appdescs" remove_prop
    me @ location location APPPROP remove_prop
    me @ location location "/_prefs/_appregistry/_/apps" remove_prop
    me @ location location APPPROPDESC remove_prop
    me @ location location "/_prefs/_appregistry/_/appdescs" remove_prop
    #0 APPPROP remove_prop
    #0 "/_prefs/_appregistry/_/apps" remove_prop
    #0 APPPROPDESC remove_prop
    #0 "/_prefs/_appregistry/_/appdescs" remove_prop
    me @ LOCKPROP remove_prop

    target @ APPPROP remove_prop
    target @ "/_prefs/_appregistry/_/apps" remove_prop
    target @ APPPROPDESC remove_prop
    target @ "/_prefs/_appregistry/_/appdescs" remove_prop
    target @ LOCKPROP remove_prop
    target @ REMOTEACCESS remove_prop
    target @ REMOTEWRITE remove_prop

    ( remember stack size )
    depth stacksize !

    ( Set some stuff on myself and try and get it )
    me @ "Testing get/set local..." notify
    me @ "one" "a" "Hello" appset-setAttribute not if me @ "FAIL: appset-setAttribute failed." notify exit then
    me @ "one" "a" "Test prop" appset-setAttributeDesc not if me @ "FAIL: appset-setAttributeDesc failed." notify exit then
    me @ APPPROP "one/b" strcat 5 setprop
    me @ APPPROP "one/c" strcat #1 setprop

    me @ "one" "a" appset-getAttribute appset-unset? if me @ "FAIL: Thought string was unset!" notify exit then
    me @ "one" "b" appset-getAttribute appset-unset? if me @ "FAIL: Thought int was unset!" notify exit then
    me @ "one" "c" appset-getAttribute appset-unset? if me @ "FAIL: Thought dbref was unset!" notify exit then
    me @ "one" "f" appset-getAttribute appset-unset? not if me @ "FAIL: Thought bad prop was set!" notify exit then

    me @ "one" "a" appset-getAttribute "Hello" strcmp if me @ "FAIL: Did not get local setting back." notify exit then
    me @ "one" "a" appset-getAttributeDesc "Test prop" strcmp if me @ "FAIL: Did not get local prop desc." notify exit then
    me @ "one" "b" appset-getAttributeDesc strlen if me @ "FAIL: Wierd local prop desc problem." notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Now test out the lock feature )
    me @ "Testing lock feature..." notify
    me @ appset-locked? if me @ "FAIL: appset-locked thought we were locked." notify exit then
    me @ LOCKPROP "yes" setprop
    me @ appset-locked? not if me @ "FAIL:  appset-locked?" notify exit then
    me @ "one" "a" "Hi" appset-setAttribute if me @ "FAIL: appset-setAttribute failed locked." notify exit then
    me @ "one" "a" "Set Prop" appset-setAttributeDesc if me @ "FAIL: appset-setAttributeDesc failed locked." notify exit then
    me @ "one" "a" appset-getAttribute "Hello" strcmp if me @ "FAIL: Did not get local setting back locked." notify exit then
    me @ "one" "a" appset-getAttributeDesc "Test prop" strcmp if me @ "FAIL: Did not get local prop desc locked." notify exit then
    me @ "one" "a" appset-removeAttribute if me @ "FAIL: Able to remove prop while locked." notify exit then
    me @ "one" "a" appset-getAttribute "Hello" strcmp if me @ "FAIL: Did not get local setting back locked (2)." notify exit then
    me @ "one" "a" appset-getAttributeDesc "Test prop" strcmp if me @ "FAIL: Did not get local prop desc locked (2)." notify exit then
    me @ LOCKPROP remove_prop
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Test isapp and isdir )
    me @ "Testing isapp and isdir..." notify
    me @ "one" appset-app? not if me @ "FAIL: appset-app?  should have returned true." notify exit then
    me @ "nopenope" appset-app? if me @ "FAIL: appset-app? should have returned false." notify exit then
    me @ "" "a/b/c" "Directory" appset-setAttribute pop
    me @ "" "a/b" appset-dir? not if me @ "FAIL: appset-dir?  should have returned true." notify exit then
    me @ "one" "a" appset-dir? if me @ "FAIL: appset-dir?  should have returned false." notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Test applist and attribute list )
    me @ "Testing applist and attribute list..." notify
    me @ appset-getAppList array_vals 2 = not if me @ "FAIL: appset-getAppList had bad count." notify exit then
    "one" strcmp not swap "_" strcmp not and not if me @ "FAIL: appset-getAppList had bad app list." notify exit then
    me @ "one" "" appset-getAttributeList array_vals 3 = not if me @ "FAIL: appset-getAttributeList had bad count." notify exit then
    "c" strcmp not swap "b" strcmp not rot "a" strcmp not and and not if me @ "FAIL: appset-getAttributeList had bad attr list!" notify exit then
    me @ "" "a" appset-getAttributeList array_vals 1 = not if me @ "FAIL: appset-getAttributeList has bad count (2)." notify exit then
    "a/b" strcmp if me @ "FAIL: appset-getAttributeList has bad attr list (2)!" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Now, set up the global attributes for testing )
    me @ location APPPROP "oneglob/b" strcat 5 setprop
    me @ location APPPROPDESC "oneglob/b" strcat "five" setprop

    me @ location location APPPROP "oneglob/b" strcat 2 setprop
    me @ location location APPPROPDESC "oneglob/b" strcat "two" setprop

    me @ location location APPPROP "midway/z" strcat 4 setprop
    me @ location location APPPROP "midway/g" strcat 89 setprop
    me @ location location APPPROP "midway/z/subprop" strcat 9 setprop
    me @ location location APPPROPDESC "midway/z" strcat "four" setprop

    me @ location location APPPROP "oneglob/a" strcat 8 setprop
    me @ location location APPPROPDESC "oneglob/a" strcat "eight" setprop

    #0 APPPROP "oneglob/b" strcat 10 setprop
    #0 APPPROP "oneglob/b/other" strcat 20 setprop
    #0 APPPROPDESC "oneglob/b" strcat "ten" setprop

    #0 APPPROP "onlyglob/f" strcat 12 setprop
    #0 APPPROP "onlyglob/f/subprop" strcat 18 setprop
    #0 APPPROPDESC "onlyglob/f" strcat "twelve" setprop

    ( Try and get global attributes and descriptions )
    me @ "Testing getGlobal and getGlobalDesc..." notify
    me @ "oneglob" "b" appset-getGlobal 5 = not if me @ "FAIL: appset-getGlobal returned wrong value!" notify exit then
    me @ "oneglob" "b" appset-getGlobalDesc "five" strcmp if me @ "FAIL: appset-getGlobalDesc returned wrong value!" notify exit then
    me @ "@oneglob" "b" appset-getGlobal 10 = not if me @ "FAIL: appset-getGlobal #0 returned wrong value!" notify exit then
    me @ "@oneglob" "b" appset-getGlobalDesc "ten" strcmp if me @ "FAIL: appset-getGlobalDesc #0 returned wrong value!" notify exit then
    me @ "oneglob" "a" appset-getGlobal 8 = not if me @ "FAIL: appset-getGlobal returned wrong value! (1)" notify exit then
    me @ "oneglob" "a" appset-getGlobalDesc "eight" strcmp if me @ "FAIL: appset-getGlobalDesc returned wrong value! (1)" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Test globalApp? and globalDir? )
    me @ "Testing isGlobalApp? and isGlobalDir?..." notify
    me @ "oneglob" appset-globalApp? not if me @ "FAIL: appset-globalApp? returned false when should be true. (1)" notify exit then
    me @ "midway" appset-globalApp? not if me @ "FAIL: appset-globalApp? returned false when should be true. (2)" notify exit then
    me @ "@oneglob" appset-globalApp? not if me @ "FAIL: appset-globalApp? returned false when should be true. (3)" notify exit then
    me @ "onlyglob" appset-globalApp? not if me @ "FAIL: appset-globalApp? returned false when should be true. (4)" notify exit then
    me @ "@onlyglob" appset-globalApp? not if me @ "FAIL: appset-globalApp? returned false when should be true. (5)" notify exit then
    me @ "badapp" appset-globalApp? if me @ "FAIL: appset-globalApp? returned true when should be false. (1)" notify exit then
    me @ "@badapp" appset-globalApp? if me @ "FAIL: appset-globalApp? returned true when should be false. (2)" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Try to remove a setting )
    me @ "Testing removing a setting..." notify
    me @ "one" "a" appset-removeAttribute not if me @ "FAIL: Unable to remove prop." notify exit then
    me @ "one" "a" appset-getAttribute appset-unset? not if me @ "FAIL: Failed to remove prop!" notify exit then
    me @ "one" "a" appset-getAttributeDesc appset-unset? not if me @ "FAIL: Failed to remove prop desc!" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Test is global dir )
    me @ "Testing global propdir check..." notify
    me @ "oneglob" "b" appset-globalDir? if me @ "FAIL: Thought global dir when wasn't!" notify exit then
    me @ "oneglob" "a" appset-globalDir? if me @ "FAIL: Thought global dir when wasn't! (2)" notify exit then
    me @ "midway" "z" appset-globalDir? not if me @ "FAIL: Thought wasn't global dir when it was!" notify exit then
    me @ "onlyglob" "f" appset-globalDir? not if me @ "FAIL: Thought wasn't global dir when it was! (2)" notify exit then
    me @ "@oneglob" "b" appset-globalDir? not if me @ "FAIL: Thought wasn't global dir when it was! (3)" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Test global lists )
    me @ "Testing global lists..." notify
    me @ appset-getGlobalAppList array_vals 3 = not if me @ "FAIL: getGlobalAppList doesn't have right amount of apps!" notify exit then
    "onlyglob" strcmp swap "oneglob" strcmp and swap "midway" strcmp and if me @ "FAIL: global applist returned invalid!" notify exit then
    me @ "midway" "" appset-getGlobalAttributeList array_vals 2 = not if me @ "FAIL: getGlobalAttributeList doesn't have right amount of attributes!" notify exit then
    "z" strcmp swap "g" strcmp and if me @ "FAIL: global attribute list invalid!" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then
  
    ( Test remote access ability )
    me @ "Testing remote target..." notify
    target @ appset-remoteAccess? if me @ "FAIL: Said remote access when not allowed." notify exit then
    0 TRY
        target @ "remoteApp" "prop" "nono" appset-setAttribute
    CATCH
        pop
        0
    ENDCATCH
    if me @ "FAIL: Could set an attribute remotely when not allowed." notify exit then

    0 TRY
        target @ "remoteApp" "prop" appset-getAttribute appset-unset? not if me @ "FAIL: Able to get remote attribute value when should be empty!" notify exit then
    CATCH
        pop
    ENDCATCH
    target @ REMOTEACCESS "yes" setprop
    target @ appset-remoteAccess? not if me @ "FAIL: Said no remote access when allowed." notify exit then
    target @ "remoteApp" "prop" "ha!" appset-setAttribute if me @ "FAIL: Set attribute remotely when not writeable!" notify exit then
    target @ "remoteApp" "prop" appset-getAttribute appset-unset? not if me @ "FAIL: Able to get remote attribute value when should be empty! (2)" notify exit then
    target @ REMOTEWRITE "yes" setprop
    target @ "remoteApp" "prop" "rem!" appset-setAttribute not if me @ "FAIL: Could not set attribute remotely!" notify exit then
    target @ "remoteApp" "prop" appset-getAttribute "rem!" strcmp if me @ "FAIL: Did not get correct attribute remotely!" notify exit then
    target @ REMOTEACCESS remove_prop
    0 TRY
        target @ "remoteApp" "prop" appset-removeAttribute
    CATCH
        pop
        0
    ENDCATCH
    if me @ "FAIL: Was able to remove an object with no access!" notify exit then
    0 TRY
        target @ "remoteApp" "prop" appset-getAttribute appset-unset? if me @ "FAIL: Able to get remote attribute value when should be empty! (3)" notify exit then
    CATCH
        pop
    ENDCATCH
    target @ REMOTEACCESS "y" setprop
    target @ REMOTEWRITE remove_prop
    0 TRY
        target @ "remoteApp" "prop" appset-removeAttribute
    CATCH
        pop
        0
    ENDCATCH
    if me @ "FAIL: Was able to remove an object with no access! (2)" notify exit then
    target @ "remoteApp" "prop" appset-getAttribute appset-unset? if me @ "FAIL: Able to get delete remote attribute value no write permission!" notify exit then
    target @ REMOTEWRITE "y" setprop
    target @ "remoteApp" "prop" appset-removeAttribute not if me @ "FAIL: Unable to remove remote attribute when we have permission!" notify exit then
    target @ "remoteApp" "prop" appset-getAttribute appset-unset? not if me @ "FAIL: Attribute is not removed, even with write permission!" notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then

    ( Test invalid app and attribute names )
    me @ "Testing invalid names..." notify
    me @ "@testing" "blah" "bad data" appset-setAttribute if me @ "FAIL: Should have failed on bad appname" notify exit then
    me @ "testing" "Hi:" "bad data" appset-setAttribute if me @ "FAIL: Should have failed on bad attr name." notify exit then
    depth stacksize @ = not if me @ "Stacksize fail." notify exit then
    
    me @ "TEST COMPLETE.  NO PROBLEMS FOUND." notify

    ( RESET ALL PROPS! )
    me @ location APPPROP remove_prop
    me @ location "/_prefs/_appregistry/_/apps" remove_prop
    me @ location APPPROPDESC remove_prop
    me @ location "/_prefs/_appregistry/_/appdescs" remove_prop
    me @ location location APPPROP remove_prop
    me @ location location "/_prefs/_appregistry/_/apps" remove_prop
    me @ location location APPPROPDESC remove_prop
    me @ location location "/_prefs/_appregistry/_/appdescs" remove_prop
    #0 APPPROP remove_prop
    #0 "/_prefs/_appregistry/_/apps" remove_prop
    #0 APPPROPDESC remove_prop
    #0 "/_prefs/_appregistry/_/appdescs" remove_prop
    me @ LOCKPROP remove_prop
;
.
c
q
