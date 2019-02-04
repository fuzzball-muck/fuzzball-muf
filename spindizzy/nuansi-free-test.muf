( /quote -dsend -S '/data/spindizzy/muf/nuansi-free-test.muf )

@prog nu-ansi-free-test.muf
1 5000 d
i
$include $lib/nu-ansi-free

: main
    pop
    var notify_string
    "~`r`RED~``, ~`y`YELLOW~``, and ~`g`GREEN~`` too!" notify_string !

    me @ "Testing ansi-notify-except..." notify
    me @ location me @ notify_string @ ansi-notify-except
    1 sleep
    me @ "Testing ansi-notify..." notify
    me @ "NOTIFY ME: " notify_string @ strcat ansi_notify
    1 sleep
    me @ "Testing ansi-tell..." notify
    "TELL: " notify_string @ strcat ansi-tell
    1 sleep
    me @ "Testing ansi-otell (need a second object to listen)..." notify
    "OTELL: " notify_string @ strcat ansi-otell
    1 sleep
    me @ "Testing ansi-connotify..." notify
    me @ firstdescr descrcon "CONNOTIFY: " notify_string @ strcat ansi-connotify
    1 sleep
    me @ "Testing ansi-notify-exclude with nothing excluded..." notify
    me @ location 0 "EXCLUDE: " notify_string @ strcat ansi-notify-exclude
    1 sleep
    me @ "Testing ansi-notify-exclude with nothing excluded (NO ANSI)..." notify
    me @ location 0 "EXCLUDE: NO ANSI" ansi-notify-exclude
    1 sleep
    me @ "Testing ansi-notify-exclude with no env notify..." notify
    me @ location dup me @ 2 "EXCLUDE (no env): " notify_string @ strcat ansi-notify-exclude
    1 sleep

    depth if me @ "STUFF STILL ON STACK!" notify else me @ "DONE." notify then
;
.
c
q
