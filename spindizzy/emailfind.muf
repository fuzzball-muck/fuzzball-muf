@prog emailfind.muf
1 2000 d
i

$include $lib/strings

lvar searchstring
lvar counter

: cmd-emailfind
        searchstring !
        ( make sure they are a wiz first! )
        "me" match me !
        me @ "wizard" flag? not if me @ "Sorry, only wizards may use this command." notify exit then

        ( If they enter one character or less as a parameter, print usage information )
        searchstring @ strlen 2 < if 
                me @ "emailfind - Finds a user's email address.  Used as a sitescan workaround." notify
                me @ "usage:   emailfind <string>" notify
                me @ "  This will look for <string> in all email addresses" notify
                me @ "  and print out whoever matches with their email address." notify
        exit then

        ( Do the search!  Basically, looks through all DB #s who are of type player, and runs smatch against their /@email prop with the search string )
        dbtop counter !
        me @ "Searching for players who have an email address containing '" searchstring @ strcat "' ..." strcat notify
        "*" searchstring @ strcat "*" strcat searchstring !
        me @ " " notify
        me @ "Name                 | Email                          | Lasthost" notify
        me @ "---------------------|--------------------------------|---------------------" notify
        background
        BEGIN
                counter @ player? if
                        ( Used to avoid a smatch error with null strings )
                        counter @ "/@email" getpropstr dup strlen 2 < if pop "    " then
                        searchstring @ smatch if
                        ( Found someone!  Print their name, email address, and last host )
                          me @
                                counter @ name 20 strcut pop 20 STRleft " | " strcat counter @ "/@email" getpropstr 30 strcut pop 30 STRleft strcat " | " strcat counter @ "/@/host" getpropstr 20 strcut pop strcat
                          notify
                        then
                then
        
                counter @ int 1 - dbref counter !
        
                counter @ int 0 =
        UNTIL
        me @ " " notify
        me @ "Done." notify
;
.
c
q
@set emailfind.muf=W
@set emailfind.muf=3

