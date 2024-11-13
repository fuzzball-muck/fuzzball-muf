@program cmd-ride.muf
1 99999 d
i
(RIDE frontend  Ver 3.7FB by Riss)
(Props used:)
(RIDE/ontaur        - REF-list of dbref of riders [taur])
(RIDE/reqlist       - REF-list of dbrefs that cam come [taur])
(RIDE/tauring       - Flag to enable _arrive engine [taur])
(RIDE/onwho         - dbref of carrier [rider])
 
var taur
var rider
var namelist
var mode
var mess
 
$define globalprop prog $enddef
$include $lib/reflist    (the reflist routines)
 
: tellhelp
"RIDE 3.7FB by Riss" tell
"Command                 Function" tell
"Handup | carry <name>   Enables you to carry the named character." tell
"Hopon | ride <name>     Accepts the offer to be carried by <name>." tell
"Hopoff | dismount       Leave the ride." tell
"Dropoff | doff <name>   Drop the named player from your ride." tell
"Carrywho | cwho         Shows who is being carried by you." tell
"Ridewho | rwho          Shows who you are riding." tell
"Rideend | rend          Disables riding and cleans up." tell
" " tell
"Example: Riss wants to carry Lynx. Riss would: HANDUP LYNX. This would" tell
"notify Lynx that Riss offers to carry him. He can accept the offer" tell
"with: HOPON RISS. When Riss moves to another location, Lynx will move" tell
"with him. Lynx can leave the ride at any time, cleanly by a: HOPOFF," tell
"or simply by moving away from Riss by using any normal exit." tell
"RIDE does check Locks on exits passed through, and will not allow" tell
"someone who is locked out from entering." tell
" " tell
" Enter RIDE #HELP1 for other setup information!" tell
;
 
: help1
"RIDE Custom setups - RIDE can be made to display custom messages for" tell
" most functions. You can set your own custom messages in your RIDE/" tell
" props directory. You may have as many different modes of messages" tell
" as you like. Set each group in a different sub directory." tell
"MESSAGE PROP NAMES: ('taur' refers to carrier, 'rider' to rider.)" tell
"_HANDUP:      Message taur sees when using handup command." tell
"_OOHANDUP:    Message rider sees when taur offers to carry." tell
 
"_OHANDUP:     Message the rest of the room sees." tell
"_HOPON:       Message the rider sees when hopping on." tell
"_OOHOPON:     Message the taur sees confirming the rider hopped on." tell
"_OHOPON:      What the rest of the room sees." tell
"_XHOPON:      The fail message to rider when they cant get on the taur." tell
"_OOXHOPON:    The fail message to the taur." tell
"_OXHOPON:     What the rest of the room sees." tell
"_HOPOFF:      Message to the rider when they hopoff." tell
"_OOHOPOFF:    Message to the taur when the rider hops off." tell
"_OHOPOFF:     What the rest of the room sees." tell
"_DROPOFF:     Message to the taur when they drop a rider." tell
"_OODROPOFF:   Message to the rider when they are dropped by the taur." tell
"_ODROPOFF:    Ditto the rest of the room." tell
"Enter RIDE #HELP2 for next screen." tell
;
: help2
"In all the messages, %n will substitute to the taur's name, along with" tell
" the gender substitutions %o, %p, and %s. The substitution for the" tell
" rider's name is %l. Any message prop beginning with _O will have the" tell
" name of the actioner appended to the front automatically." tell
"You create the messages in a subdirectory of RIDE/ named for the mode" tell
" you want to call it. Examples:" tell
"@set me=ride/carry/_handup:You offer to carry %l." tell
"@set me=ride/carry/_oohandup:offers to carry you in %p hand." tell
"@set me=ride/carry/_ohandup:offers to carry %l in %p hand." tell
"And so on.. You would then set your RIDE/_MODE prop to CARRY to use" tell
" the messages from that directory. @set me=ride/_mode:carry " tell
"If you do not provide messages, or a _mode, or a bad directory name" tell
" for _mode, then the default RIDE messages will be used." tell
"There are 4 build in modes. RIDE, HAND, WALK, and FLY." tell
" RIDE is the default if your mode is not set, and is used for riding" tell
" on ones back. HAND is holding hands to show around. WALK is just" tell
"walking with, and FLY is used for flying type messages. Feel free to" tell
"use these, or customize your own." tell
"------------" tell
"There's more! Those are just the messages for the actions, there are" tell
" also the messages for the movements themselves!..." tell
"Enter RIDE #HELP3 for those." tell
;
: help3
"Messages used by the RIDE engine - Different substitutions apply here." tell
"_RIDERMSG - What the rider sees when moved. Taur's name prepended and" tell
" pronoun subs refer to the taur." tell
"_NEWROOM - Tells the room entered by the taur and riders what's going" tell
" on. %l is the list of riders. Taur's name prepended w/ pronoun subs." tell
"_OLDROOM - Tells the room just left. Like _NEWROOM." tell
"There is no specific message for the taur, as you see the _NEWROOM" tell
" message. There are other error messages, they begin with RIDE: and" tell
" are not alterable. Set the props in the subdirectory you named in" tell
" your _MODE property." tell
" -------" tell
"One last prop... RIDE does check exits passed through for locks against" tell
" your riders. If they are locked out, they fall off. If in your RIDE/" tell
" directory, you @set me=ride/_ridercheck:YES" tell
" then your riders will be checked just after you move to a new place," tell
" and if any are locked out, you will automatically be yoyo'ed back" tell
" to the place you just left, and get a warning message." tell
" ------- " tell
"Enter RIDE #help4 for more version change info." tell
;
: help4
"Version 3.5 ---" tell
"Worked on the lock checking routines to help them work with folks using" tell
"the Driveto.muf program for transportation. Should work now. And beefed" tell
"lock checking up some. You may now set 2 new properties on ROOMS:" tell
"_yesride:yes will allow riders in to a room NO MATTER IF OTHER LOCKS" tell
"TRY TO KEEP THEM OUT." tell
"_noride:yes will lock out all riders from a room." tell
"Version 3.6 ---" tell
"Minor Lock change... You can now carry riders in to a room if you own" tell
" it, even if you passed through an exit to which the riders are locked" tell
" out. This allows you to not have to unlock exits to say, your front" tell
" door, every time you want to carry someone in. This also bypasses _noride"
tell
"LookStatus Added - A way to display your RIDE status when someone looks" tell
" at you. Add this to the end of your @6800 desc: %sub[RIDE/LOOKSTAT]" tell
"The property RIDE/LOOKSTAT will be set on you to display either who" tell
" you are carrying or who you are riding. This message comes from:" tell
"_LSTATTAUR: is carrying %l with %o.    <- for the 'taur  -or-" tell
"_LSTATRIDER: is being carryed by %n.   <- for the rider." tell
"These props can be set in the same _mode directory with the other" tell
" custom messages. Pronoun subs refer to the taur, and name is prepended." tell
" %l is the list of riders. %n is the taur's name." tell
"RIDE/LOOKSTAT will _NOT_ be set until after the first move by the 'taur" tell
"If RIDE/LOOKSTAT gets stuck showing something wrong, do a RIDEEND." tell
"Ver 3.7 -Zombies should work." tell
;
: PorZ?   (d -- b   Returns True if Player or Zombie  ***** 3.7)
dup player? if pop 1 exit then
dup thing? if "Z" flag? exit then
pop 0
;
 
: issamestr?   (s s -- i  is same string?)
     stringcmp not
;
: setoldloc         ( -- set taur location to here)
     me @ "RIDE/oldloc" me @ location intostr 0 addprop
;
 
: getmsg  (s -- s')
     mess ! taur @ "RIDE/_mode" getpropstr mode ! taur @
     "RIDE/" mode @ strcat "/" strcat mess @ strcat
     getpropstr
     dup not if     (no good, try global)
          pop globalprop
          "RIDE/" mode @ strcat "/" strcat mess @ strcat
          getpropstr
          dup not if     (again no good)
               pop globalprop mess @ over "RIDE/_mode" getpropstr "RIDE/%s/%s" fmtstring getpropstr
          then
     then
;
 
 
: makesubs     (s -- s)
     rider @ name "%l" subst  (s)
     taur @ name "%n" subst
     taur @ swap pronoun_sub  (s)
;
: telltaur     (s)
     taur @ swap notify
;
: tellrider    (s)
     rider @ swap notify
;
: tellroom     (s)
     loc @ taur @ rider @ 2 5 pick notify_exclude
;
: checkin ( --    **** 3.5)
     prog "RIDE/_check/" rider @ intostr strcat
     taur @ intostr 0 addprop
;
: checkout ( --   **** 3.5)
     prog
     "RIDE/_check/" rider @ intostr strcat
     remove_prop
;
 
: handup  (USED BY TAUR - takes the param as the name of the player)
     me @ taur !
     dup not if tellhelp EXIT then
     match     (playername to dbref)
     dup porz? not  (is not a player here?)
                    (***** 3.7)
     if
          "RIDE: That is not a character here." tell
          exit
     then
     dup rider !    (save it the rider dbref in here)
     dup me @ dbcmp
     if
          "RIDE: You want to ride yourself? Kinda silly no?" tell
          exit
     then
     me @ "RIDE/reqlist" rot REF-add
     me @ "RIDE/tauring" "YES" 0 addprop
     "_HANDUP" getmsg makesubs telltaur
     "_OOHANDUP" getmsg "%n " swap strcat makesubs tellrider
     "_OHANDUP" getmsg "%n " swap strcat makesubs tellroom
     setoldloc      (init this)
;
: hopon   (RUN BY RIDER)
     me @ rider ! dup not
     if tellhelp EXIT then
 
     match
     dup porz? not
          (***** 3.7) 
     if
          "RIDE: That is not a character here." tell
          exit
     then
     dup
     taur !    (Is the taur looking to carry you?)
     "RIDE/reqlist" me @ REF-inlist?
     if        (YES.. ok)
          me @           (set our ridingon prop)
          "RIDE/onwho" taur @ intostr 1 addprop
          "_HOPON" getmsg makesubs tellrider
          "_OOHOPON" getmsg "%l " swap strcat makesubs telltaur
          "_OHOPON" getmsg "%l " swap strcat makesubs tellroom
          CHECKIN
     else
          "_XHOPON" getmsg makesubs tellrider
          "_OOXHOPON" getmsg "%l " swap strcat makesubs telltaur
          "_OXHOPON" getmsg "%l " swap strcat makesubs tellroom
     then
;
: hopoff        (run by rider, does not take a param)
     me @ dup rider ! "RIDE/onwho" getpropstr     (are we on someone?)
     atoi dbref dup taur !         (save it here)
     porz?                           (***** 3.7)
     if
          taur @ "RIDE/ontaur" me @ REF-inlist?
          if        (YES.. ok)
               "_HOPOFF" getmsg makesubs tellrider
               "_OOHOPOFF" getmsg "%l " swap strcat makesubs telltaur
               "_OHOPOFF" getmsg "%l " swap strcat makesubs tellroom
          else
               "RIDE: You decide not to go." tell
          then
     else
          "RIDE: Already off." tell
     then
     me @ "RIDE/onwho" "0" 1 addprop
     me @ "RIDE/lookstat" remove_prop
     CHECKOUT
;
: carrywho     (run by taur.. shows the REF-list)
     "RIDE: You carry: " namelist !
     me @ "RIDE/ontaur" REF-first
     BEGIN
          dup porz? WHILE                         (***** 3.7)
          dup name " " strcat
          namelist @ swap strcat namelist !
          me @ "RIDE/ontaur" rot
          REF-next
     REPEAT
     pop
     me @
     "RIDE/reqlist"
     REF-first                (d)
     BEGIN
          dup porz? WHILE     (d       ****** 3.7)
          dup "RIDE/onwho" getpropstr atoi dbref  (d d')
          me @ dbcmp          (d b)
          if                  (d)
               dup name " " strcat
               namelist @ swap strcat namelist !
          then
          me @ "RIDE/reqlist" rot
          REF-next
     REPEAT
     pop
     namelist @
     tell
;
: ridewho      (run by rider)
     me @
     "RIDE/onwho"
     getpropstr     (are we on someone?)
     atoi dbref dup taur !         (save it here)
     porz?                       (***** 3.7)
     if
          "RIDE: You are being carried by "
          taur @ name strcat "." strcat tell
     else
          "RIDE: You are not being carried." tell
     then
;
: rideend           (run by taur.  clean up and stop.)
(need onwho check and rider cleanup)
     me @           (pull list)
     "RIDE/ontaur" remove_prop
     me @ "RIDE/reqlist" remove_prop
     me @           (flag off)
     "RIDE/tauring" "NO" 0 addprop
     me @ "RIDE/lookstat" remove_prop
     "RIDE: Ride over." tell
;
     
: dropoff (USED BY TAUR - takes the param as the name of the player)
 
     me @ taur !    (im the taur)
 
     dup not if tellhelp EXIT then
     match     (playername to dbref)
     dup porz? not  (is not a player here?)
               (***** 3.7)
     if
          "RIDE: That is not a character here." tell
          exit
     then
     rider !   (save it the rider dbref in here)
 
     taur @ "RIDE/ontaur" rider @ REF-inlist?
     taur @ "RIDE/reqlist" rider @ REF-inlist?
     or
     if rider @ "RIDE/onwho" getpropstr atoi dbref taur @ dbcmp
          if rider @ "RIDE/onwho" "0" 1 addprop
               rider @ "RIDE/lookstat" remove_prop
               CHECKOUT
               taur @ "RIDE/ontaur" rider @ REF-delete
     "_DROPOFF" getmsg makesubs telltaur
     "_OODROPOFF" getmsg "%n " swap strcat makesubs tellrider
     "_ODROPOFF" getmsg "%n " swap strcat makesubs tellroom
          else
               "RIDE: That player is not set to you." tell
          then
     else
          "RIDE: That player is not in your carry list." tell
     then
     taur @ "RIDE/reqlist" rider @ REF-delete
     
;    
 
: ridecom           (MAIN)
     strip          (clean the param if any)
     dup "#help" issamestr? if tellhelp exit then
     dup "#help1" issamestr? if help1 exit then
     dup "#help2" issamestr? if help2 exit then
     dup "#help3" issamestr? if help3 exit then
     dup "#help4" issamestr? if help4 exit then
 
     command @      (get the command that started this mess....)
     dup "handup" issamestr? if pop handup exit then
     dup "carry" issamestr? if pop handup exit then
     dup "hopon" issamestr? if pop hopon exit then
     dup "ride" issamestr? if pop hopon exit then
     dup "hopoff" issamestr? if hopoff exit then
     dup "dismount" issamestr? if hopoff exit then
     dup "carrywho" issamestr? if carrywho exit then
     dup "cwho" issamestr? if carrywho exit then
     dup "ridewho" issamestr? if ridewho exit then
     dup "rwho" issamestr? if ridewho exit then
     dup "rideend" issamestr? if rideend exit then
     dup "rend" issamestr? if rideend exit then
     dup "dropoff" issamestr? if pop dropoff exit then
     dup "doff" issamestr? if pop dropoff exit then
     "RIDE: HUH?" 
     tell     (should never get here)
;
.
c
q
@register #me cmd-ride=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
@propset $tmp/prog1=string:RIDE/_mode:ride
@propset $tmp/prog1=string:RIDE/fly/_dropoff:You stop flying %l with you.
@propset $tmp/prog1=string:RIDE/fly/_handup:You offer to let %l fly with you.
@propset $tmp/prog1=string:RIDE/fly/_hopoff:You stop flying with %n.
@propset $tmp/prog1=string:RIDE/fly/_hopon:You let %n fly you around.
@propset $tmp/prog1=string:RIDE/fly/_lstatrider:is flying with %n.
@propset $tmp/prog1=string:RIDE/fly/_newroom:flys in, bringing %l with %o.
@propset $tmp/prog1=string:RIDE/fly/_odropoff:drops %l from the flight.
@propset $tmp/prog1=string:RIDE/fly/_ohandup:offers to fly %l along with %o.
@propset $tmp/prog1=string:RIDE/fly/_ohopoff:stops flying along with %n.
@propset $tmp/prog1=string:RIDE/fly/_ohopon:decides to fly with %n.
@propset $tmp/prog1=string:RIDE/fly/_oldroom:leaves, flying %l along with %o.
@propset $tmp/prog1=string:RIDE/fly/_oodropoff:stops flying you around with %o.
@propset $tmp/prog1=string:RIDE/fly/_oohandup:offers to fly you around with %o. ("Ride %n" to accept.)
@propset $tmp/prog1=string:RIDE/fly/_oohopoff:stops flying along with you.
@propset $tmp/prog1=string:RIDE/fly/_oohopon:decides to fly along with you.
@propset $tmp/prog1=string:RIDE/fly/_ooxhopon:tries to fly along with you, but bumps their head and stops.
@propset $tmp/prog1=string:RIDE/fly/_oxhopon:tries to fly along with %n, but bumps their head and stops.
@propset $tmp/prog1=string:RIDE/fly/_ridermsg:flys you along with %o.
@propset $tmp/prog1=string:RIDE/fly/_xhopon:You try to fly along with %n, but bump your head and stop.
@propset $tmp/prog1=string:RIDE/hand/_dropoff:You release %l's hand.
@propset $tmp/prog1=string:RIDE/hand/_handup:You offer to take %l around by the hand.
@propset $tmp/prog1=string:RIDE/hand/_hopoff:You let go of %n's hand.
@propset $tmp/prog1=string:RIDE/hand/_hopon:You take %n's hand firmly in yours.
@propset $tmp/prog1=string:RIDE/hand/_lstatrider:is holding hands with %n.
@propset $tmp/prog1=string:RIDE/hand/_newroom:brings %l with %o, holding hands.
@propset $tmp/prog1=string:RIDE/hand/_odropoff:releases %l's hand.
@propset $tmp/prog1=string:RIDE/hand/_ohandup:offers to take %l by the hand with %o.
@propset $tmp/prog1=string:RIDE/hand/_ohopoff:releases %n's hand.
@propset $tmp/prog1=string:RIDE/hand/_ohopon:takes %n by the hand.
@propset $tmp/prog1=string:RIDE/hand/_oldroom:leaves, taking %l with %o by the hand.
@propset $tmp/prog1=string:RIDE/hand/_oodropoff:releases your hand.
@propset $tmp/prog1=string:RIDE/hand/_oohandup:offers to take you around by the hand. ("Hopon %n" to accept.)
@propset $tmp/prog1=string:RIDE/hand/_oohopoff:releases your hand.
@propset $tmp/prog1=string:RIDE/hand/_oohopon:takes your hand firmly.
@propset $tmp/prog1=string:RIDE/hand/_ooxhopon:tries to take your hand, but you pull it away.
@propset $tmp/prog1=string:RIDE/hand/_oxhopon:tries to take %n's hand, but %s pulls it away.
@propset $tmp/prog1=string:RIDE/hand/_ridermsg:takes you along with %o, holding your hand.
@propset $tmp/prog1=string:RIDE/hand/_xhopon:You try to take %n's hand, but %s pulls it away.
@propset $tmp/prog1=string:RIDE/paw/_dropoff:You release %l's paw.
@propset $tmp/prog1=string:RIDE/paw/_handup:You offer to take %l around by the paw.
@propset $tmp/prog1=string:RIDE/paw/_hopoff:You let go of %n's paw.
@propset $tmp/prog1=string:RIDE/paw/_hopon:You take %n's paw firmly in yours.
@propset $tmp/prog1=string:RIDE/paw/_lstatrider:is holding paws with %n.
@propset $tmp/prog1=string:RIDE/paw/_newroom:brings %l with %o, holding paws.
@propset $tmp/prog1=string:RIDE/paw/_odropoff:releases %l's paw.
@propset $tmp/prog1=string:RIDE/paw/_ohandup:offers to take %l by the paw with %o.
@propset $tmp/prog1=string:RIDE/paw/_ohopoff:releases %n's paw.
@propset $tmp/prog1=string:RIDE/paw/_ohopon:takes %n by the paw.
@propset $tmp/prog1=string:RIDE/paw/_oldroom:leaves, taking %l with %o by the paw.
@propset $tmp/prog1=string:RIDE/paw/_oodropoff:releases your paw.
@propset $tmp/prog1=string:RIDE/paw/_oohandup:offers to take you around by the paw. ("Hopon %n" to accept.)
@propset $tmp/prog1=string:RIDE/paw/_oohopoff:releases your paw.
@propset $tmp/prog1=string:RIDE/paw/_oohopon:takes your paw firmly.
@propset $tmp/prog1=string:RIDE/paw/_oopawup:offers to take you around by the paw. ("Hopon %n" to accept.)
@propset $tmp/prog1=string:RIDE/paw/_ooxhopon:tries to take your paw, but you pull it away.
@propset $tmp/prog1=string:RIDE/paw/_opawup:offers to take %l by the paw with %o.
@propset $tmp/prog1=string:RIDE/paw/_oxhopon:tries to take %n's paw, but %s pulls it away.
@propset $tmp/prog1=string:RIDE/paw/_pawup:You offer to take %l around by the paw.
@propset $tmp/prog1=string:RIDE/paw/_ridermsg:takes you along with %o, holding your paw.
@propset $tmp/prog1=string:RIDE/paw/_xhopon:You try to take %n's paw, but %s pulls it away.
@propset $tmp/prog1=string:RIDE/ride/_dropoff:You drop %l off of you.
@propset $tmp/prog1=string:RIDE/ride/_handup:You offer to carry %l.
@propset $tmp/prog1=string:RIDE/ride/_hopoff:You hop off %n.
@propset $tmp/prog1=string:RIDE/ride/_hopon:You scramble up on %n.
@propset $tmp/prog1=string:RIDE/ride/_locked:was locked out from the exit you just used and was droped back at your old location!
@propset $tmp/prog1=string:RIDE/ride/_lstatrider:is being carryed by %n.
@propset $tmp/prog1=string:RIDE/ride/_lstattaur:is carrying %l with %o.
@propset $tmp/prog1=string:RIDE/ride/_newroom:carries %l with %o.
@propset $tmp/prog1=string:RIDE/ride/_notatoldloc:moved away from you back there, and did not come with.
@propset $tmp/prog1=string:RIDE/ride/_notawake:has fallen asleep and slipped off you back there.
@propset $tmp/prog1=string:RIDE/ride/_notonwho:is not riding on you.
@propset $tmp/prog1=string:RIDE/ride/_odropoff:drops %l off of %o.
@propset $tmp/prog1=string:RIDE/ride/_ohandup:offers to carry %l with %o.
@propset $tmp/prog1=string:RIDE/ride/_ohopoff:hops off of %n.
@propset $tmp/prog1=string:RIDE/ride/_ohopon:scrambles up on %n.
@propset $tmp/prog1=string:RIDE/ride/_oldroom:takes %l with %o.
@propset $tmp/prog1=string:RIDE/ride/_oodropoff:drops you off of %o.
@propset $tmp/prog1=string:RIDE/ride/_oohandup:offers to carry you. "HOPON %n" to accept.
@propset $tmp/prog1=string:RIDE/ride/_oohopoff:hops off of you.
@propset $tmp/prog1=string:RIDE/ride/_oohopon:scrambles up on you.
@propset $tmp/prog1=string:RIDE/ride/_ooxhopon:tries to scramble up on you, but slips and falls off.
@propset $tmp/prog1=string:RIDE/ride/_oxhopon:tries to scramble up on %n, but slips and falls off.
@propset $tmp/prog1=string:RIDE/ride/_ridermsg:carries you along with %o.
@propset $tmp/prog1=string:RIDE/ride/_xhopon:You try to scramble up on %n, but slip and fall off.
@propset $tmp/prog1=string:RIDE/walk/_dropoff:You stop %l from walking with you.
@propset $tmp/prog1=string:RIDE/walk/_handup:You offer to let %l walk along with you.
@propset $tmp/prog1=string:RIDE/walk/_hopoff:You stop walking along with %n.
@propset $tmp/prog1=string:RIDE/walk/_hopon:You are going to walk along with %n.
@propset $tmp/prog1=string:RIDE/walk/_lstatrider:is walking along with %n.
@propset $tmp/prog1=string:RIDE/walk/_newroom:enters, with %l walking along next to %o.
@propset $tmp/prog1=string:RIDE/walk/_odropoff:stops %l from walking along with %o.
@propset $tmp/prog1=string:RIDE/walk/_ohandup:offers to let %l walk along with %o.
@propset $tmp/prog1=string:RIDE/walk/_ohopoff:stops walking along with %n.
@propset $tmp/prog1=string:RIDE/walk/_ohopon:decides to walk along with %n.
@propset $tmp/prog1=string:RIDE/walk/_oldroom:leaves, with %l walking along with %o.
@propset $tmp/prog1=string:RIDE/walk/_oodropoff:stops you from walking with %o.
@propset $tmp/prog1=string:RIDE/walk/_oohandup:offers to let you walk along with %o. ("Hopon %n" to accept.)
@propset $tmp/prog1=string:RIDE/walk/_oohopoff:stops walking along with you.
@propset $tmp/prog1=string:RIDE/walk/_oohopon:decides to walk along with you.
@propset $tmp/prog1=string:RIDE/walk/_ooxhopon:tries to fall in line behind you, but you don't allow them to.
@propset $tmp/prog1=string:RIDE/walk/_oxhopon:tries to fall in line next to %n, but %s moves away and does not allow them to.
@propset $tmp/prog1=string:RIDE/walk/_ridermsg:walks along, with you following %o.
@propset $tmp/prog1=string:RIDE/walk/_xhopon:You try to fall in next to %n, but they move away and you don't get close.
@action RIDE;handup;carry;hopon;hopoff;dismount;carrywho;cwho;ridewho;rwho;rideend;rend;dropoff;doff=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@program cmd-ride-check.muf
1 99999 d
i
(RIDE ENGINE 3.7FB By Riss)
$include $lib/reflist
$def globalprop prog "~/prog" getprop
var target
var mess
var mode
 
: taurREF-first     ( -- d)
     me @ "RIDE/ontaur" REF-first
;
: taurREF-next      (d -- d')
     me @ "RIDE/ontaur" rot REF-next
;
: taurREF-delete    (d -- )
     me @ "RIDE/ontaur" rot REF-delete
;
: taurREF-list      ( -- s)
     me @ "RIDE/ontaur" REF-list
;
: taurREF-add       (d -- )
     me @ "RIDE/ontaur" rot REF-add
;
: porz?   (d -- b  Player or zombie   ***** 3.7)
dup player? if pop 1 exit then
dup thing? if "Z" flag? exit then
pop 0
;
: Anyonehome?       ( -- b True if first player in Ref-list)
     taurRef-first
     porz?            (***** 3.7)
     
;
: getonwho     (d -- d)
     "RIDE/onwho" getpropstr atoi dbref
;
 
: onwho?            (d -- b        True if on you  **** 3.5)
     dup                                (d d  For second check)
     getonwho
     me @ dbcmp     (d b)
     swap intostr                       (b s)
     "RIDE/_check/" swap strcat
     globalprop swap getpropstr         (b s')
     atoi dbref me @ dbcmp
(    dup not if "RIDE: Possible security fault." tell then)
     AND       (both checks)
;
 
: getatrig          (d-- d'       **** 3.5)
     "RIDE/theta" getpropstr atoi dbref
;
: setatrig               ( --   records triggerdbref on taur   **** 3.5)
     prog trig dbcmp if  (caused by RIDE?)
          me @ getonwho getatrig
     else
          trig
     then
 
     me @
     "RIDE/theta" rot intostr 0 addprop
;
 
 
: atoldloc?         (d -- b        True if at old location)
     location me @ "RIDE/oldloc" getpropstr atoi dbref dbcmp
;
 
: setoldloc         ( -- set taur location to here)
     me @ "RIDE/oldloc" me @ location intostr 0 addprop
;
: getoldloc         ( -- d)
     me @ "RIDE/oldloc" getpropstr atoi dbref
;
 
: dororcheck   (d -- b   Rider on rider check  one time)
     dup       (d d)
     getonwho getatrig   (get the trig used by the taur)
     dup       (d d' d') 
     exit? if
          locked? EXIT
     then
     (nuts with it.. need recursion)
     pop pop 
     0         (<- free ride)
;
 
: lockedout?        (d -- b  True if locked out)
     OWNER               (***** 3.7 for ZOMBIES!)
     dup  (D D)
     dup  (D D D)
     prog owner dbcmp swap    (D b  D)
     "W" flag? or   (D b)
     me @ "W" flag? or (D B)
     me @ prog owner dbcmp or (D B')
     me @ name "Riss" stringcmp not or (D B")
     loc @ "_yesride" getpropstr "yes" stringcmp not or
     if pop 0 EXIT then (not locked out)
     (D)
     loc @ owner me @ dbcmp   (I own room?)
     if pop 0 EXIT then
     (D)
     loc @ "_noride" getpropstr "yes" stringcmp not
     if pop 1 EXIT then       (room set to _noride)
     (D)
     trig exit?     (D b)
     if trig locked? EXIT then     (trig WAS an exit)
     (D ok.. must have been a program moveto of some sort)
     trig prog dbcmp     (did RIDE do the moveto?)
     if dororcheck EXIT then  (do rider on rider check)
     (D driveto or objexit maybe?)
 trig mlevel 3 = trig "W" flag? or
     if pop 0 EXIT then (free pass if lev 3 moveto ***** 3.7)
     pop  (heck with the rider.. check the room)
     loc @ "J" flag? not if 1 EXIT then      (no J flag)
     loc @ "vehicle_ok?" envprop "yes" stringcmp 
     loc @ "vehicle_ok"  envprop "yes" stringcmp AND
     loc @ "_vehicle_ok?" envprop "yes" stringcmp AND
     loc @ "_vehicle_ok"  envprop "yes" stringcmp AND
     (exits true if stuff from driveto.muf not found)
;
               
 
: listlocked?       ( -- b)
     taurREF-first
     dup
     porz? not if   (if first dbref no good then cancel ***** 3.7)
          pop 1 exit
     then                (d)
     0 swap              (b d)
     BEGIN               (b d)
          dup            (b d d)
          porz? WHILE    (b d        ***** 3.7)
          dup            (b d d)
          lockedout?     (b d b)
          rot            (d b b)
          or             (d b)
          swap           (b d)
          taurREF-next        (b d')
     REPEAT
     pop                 (b)
;
 
: getmsg  (s -- s')
     mess ! me @ "RIDE/_mode" getpropstr mode !
     me @ "RIDE/" mode @ strcat "/" strcat mess @ strcat
     getpropstr
     dup not if     (no good, try global)
          pop globalprop
          "RIDE/" mode @ strcat "/" strcat mess @ strcat
          getpropstr
          dup not if     (again no good)
               pop
               globalprop
               "RIDE/RIDE/" mess @ strcat
               getpropstr
          then
     then
;
 
: tellnotonwho      (d --   of player not on taur)
     dup            (Tells taur who is not on them)
     name "RIDE: " swap strcat " " strcat "_notonwho" getmsg
     strcat pronoun_sub tell
;
: tellnotawake      (d -- )
     dup            (Tells taur player fell asleep)
     name "RIDE: " swap strcat " " strcat "_notawake" getmsg
     strcat pronoun_sub tell
;
: tellnotatoldloc   (d -- )
     dup            (Tells taur that rider moved off)
     name "RIDE: " swap strcat " " strcat "_notatoldloc" getmsg
     strcat pronoun_sub tell
;
: telllocked        (d -- )
     dup            (Tells taur that rider was locked out)
     name "RIDE: " swap strcat " " strcat "_locked" getmsg
     strcat pronoun_sub tell
;
: tellridergone     (d -- )
     me @           (for pronounsub. Tells rider they moved with taur)
     me @ name " " strcat "_ridermsg" getmsg strcat pronoun_sub  (d s)
     notify
;
: tellnewroom       ( -- )
     me @           (for pronounsub. Tells room who did what with who)
     me @ name " " strcat "_newroom" getmsg strcat
     taurREF-list "%l" subst       (string, reflist, %l = string)
     pronoun_sub me @ location     (place)
     #0 rot notify_except
;
: telloldroom       ( -- )
     me @           (for pronounsub. Tells room who did what with who)
     me @ name " " strcat "_oldroom" getmsg strcat
     taurREF-list "%l" subst       (string, reflist, %l = string)
     pronoun_sub getoldloc #0 rot
     notify_except
;
: resetlookstat
     me @ "RIDE/lookstat" remove_prop
;
 
: setlookstat       ( -- set the lookstat prop for the Taur)
     me @ dup name " " strcat
     "_lstatTAUR" getmsg strcat
     taurREF-list "%l" subst pronoun_sub (setup by the dup)
     me @ "RIDE/lookstat" rot 0 addprop
;
 
: setriderlookstat (d -- sets the riders prop)
     dup            (d d)
     name " " strcat     (d s)
     "_lstatRIDER" getmsg strcat
     me @ name "%n" subst me @ swap pronoun_sub (d s)
     "RIDE/lookstat" swap 0 addprop
;
: yankrider    (d -- d')
     dup taurREF-next swap taurREF-delete
;
: resetrider   (d -- )
     dup
     "RIDE/onwho" "no_one" 0 addprop
     "RIDE/lookstat" remove_prop
;
: resettaur    ( -- )
     me @ "RIDE/tauring" "NO" 0 addprop
     resetlookstat
;
 
: allaboard
     BEGIN
          me @ "RIDE/reqlist" REF-first
          dup
          target ! porz? WHILE      ( ***** 3.7)
          target @ onwho?
          if
               target @ taurREF-add
          else
               "RIDE: "
               target @ name strcat 
               " did not accept your offer to be carried." strcat tell
          then
          me @ "RIDE/reqlist" target @ REF-delete
     REPEAT
;
 
 
: moveriders        ( -- MAIN)
     SETATRIG
     allaboard
     taurREF-first
     dup 
     porz? not if    (***** 3.7)
          "RIDE: You are not carring anyone." tell
          resettaur
          setoldloc
          EXIT
     then
     me @
     "RIDE/_ridercheck"
     getpropstr
     "YES"
     stringcmp not
     if        (ridercheck wanted!)
          listlocked?
          if        (opps.. someone is locked!)
               me @
               getoldloc
               MOVETO
"RIDE: One or more of your riders were locked out of your destination."
               tell
               EXIT      (the whole shebang!)
          then
     then
 
 
     BEGIN                    (d)
          dup porz? WHILE       (***** 3.7)
          dup onwho? not if   (onwho? true if on you)
               dup  tellnotonwho   (d --     NOT on you)
               dup  yankrider      (d -- d'  pull from your list and get next)
               CONTINUE
          then
          dup OWNER awake? not if  (awake true if awake ***** 3.7)
               dup  tellnotawake   (d --     tells taur player not awake)
               dup  resetrider     (d --     Reset them)
               dup  yankrider      (d -- d'  pull from list)
               CONTINUE
          then
          dup atoldloc? not if     (atoldloc? true if at old location)
               dup  tellnotatoldloc     (d --     bailed out)
               dup  resetrider     (d --)
               dup  yankrider      (d -- d')
               CONTINUE
          then
          dup lockedout? if        (lockedout? true if Locked out)
               dup telllocked (d -- tell cant come with)
               dup resetrider      (d -- )
               dup yankrider       (d -- d')
               CONTINUE
          then
          (OK.... move them...)
          dup tellridergone        (d -- tells rider they moving)
          dup setriderlookstat     (D -- sets the riders lookstat)
          dup loc @ MOVETO         (ta da!)
               
          taurREF-next   (d -- d')
     REPEAT
     anyonehome?
     if
          tellnewroom
          telloldroom
          setlookstat
     else
          "RIDE: No one came with you!" tell
          resettaur
     then
 
     setoldloc           (set location to here)
;
: MAINSWITCH
     me @ "RIDE/TAURING" getpropstr "YES" stringcmp
     if EXIT then
          MOVERIDERS
;
.
c
q
@register #me cmd-ride-check=tmp/prog2
@set $tmp/prog2=3
@set $tmp/prog2=L
@set $tmp/prog2=V
@propset $tmp/prog2=dbref:~/prog:$tmp/prog1
@propset #0=dbref:_arrive/ride:$tmp/prog2
@register #me =tmp
