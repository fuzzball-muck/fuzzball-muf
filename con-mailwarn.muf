@program con-mailwarn
1 99999 d
1 i
$version 1.2
 
$include $lib/props
 
$define maildir "_page/mail#" $enddef
  
: mail-warn
  maildir me @ over .locate-prop
  dup ok? if
    me @ over controls not if pop me @ then
    swap getpropstr atoi
  else
    pop pop 0
  then
  dup if
    dup 1 > if
      intostr " page-mail messages" strcat
    else pop "a page-mail message"
    then
  else pop exit
  then
  "You sense that you have " swap strcat
  " waiting." strcat
  tell
  "You can read your page-mail with 'page #mail'" tell
;
.
c
q
@register #prop #0:_connect con-mailwarn=mailwarn
@register #me con-mailwarn=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=V
@register #me =tmp
