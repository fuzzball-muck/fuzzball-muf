NOTE: You may want to delete the 'stats' lines if you just want the warning without recording who is unencrypted.  Also update the warning lines at the bottom.


( /quote -dsend -S '/data/spindizzy/muf/sslcheck5.muf )
@prog sslcheck.muf
1 5000 d
i
( v5 - Notes who is not encrypted )
( v4 - Customized error message plus random sleep )
( v3 - No longer allows opt-out )
( v2 - adds support for websockets )

: main
    pop
    
    descr 0 >= if
        descr descrsecure? if
            ( Exit early if definitely encrypted )
            prog "/stats/ssl/" me @ intostr strcat me @ name setprop
            exit
        then
	else
        ( Autostart/listener not supported )
        exit
    then
    
    background
    random 20 % sleep
    
    me @ awake? not if
        ( Exit early if player disconnected before sleep completed )
        exit
    then
    
    descr 0 >= if
        descr descrsecure? not if
              prog "/notice" array_get_proplist
              { me @ }list
            array_notify
            
            prog "/stats/plain/" me @ intostr strcat me @ name setprop
        then
    then
;
.
c
q
@set sslcheck.muf=W
@set sslcheck.muf=L
lsedit sslcheck.muf=notice
.del 1 500
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
##                     WE ARE GOING SSL-ONLY ON 03/15/19
  
##   WARNING: Your connection is not encrypted.
##   SpinDizzy will stop supporting unencrypted connections on 03/15/19.
##   Please see  https://wiki.spindizzy.org/SSL_Help  to help fix your client.
  
##
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
.end
