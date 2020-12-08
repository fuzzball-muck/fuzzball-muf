@program lib-mesg
1 99999 d
1 i
( **** Message Object -- MSG- ****
  A message is a set of elements with a count and an information string,
    stored in properties.
  
  base is a string containing the name of the message.
  itemnum is the number of an item within a message.
  itemstr is a single item's string.
  infostr is the messages information string.
  {strrange} is a string range that is all the elements of the message
    with an integer count.
  
    MSG-destroy [base dbref -- ]
      Clears and removes the message.
  
    MSG-create  [{strrange} infostr base dbref -- ]
      Create a new message with the given items and info string on
      the given object with the given name.
  
    MSG-count   [base dbref -- count]
      Returns how many items are in the given message.
  
    MSG-info    [base dbref -- infostr]
      Returns the information string for the given message.
  
    MSG-setinfo [infostr base dbref -- ]
      Sets the information string on an existing message.
  
    MSG-message [base dbref -- {strrange}]
      Returns the items of a message as a range on the stack.
  
    MSG-item    [itemnum base dbref -- itemstr]
      Returns the given message item from the message.
  
    MSG-setitem [itemstr itemnum base dbref -- ]
      Sets the specified message item to the given string.
  
    MSG-insitem [itemstr itemnum base dbref -- ]
      Inserts a new message item into the message at the given point.
  
    MSG-append  [itemstr base dbref -- ]
      Appends a message item to the given message.
  
    MSG-delitem [itemnum base dbref -- ]
      Deletes the specified message item from the given message.
  
  
Message data type:
  Base#         Count of Message Items
  Base#/X       Message Items
  Base#/i       Info String
)
 
$doccmd @list __PROG__=!@1-50
 
$include $lib/lmgr
$include $lib/props
 
: MSG-destroy (base dbref -- )
    over over swap "#/i" strcat remove_prop
    LMGR-deletelist
;
 
: MSG-setinfo (infostr base dbref -- )
    swap
    "#" strcat
    "/i" strcat rot setpropstr
;
 
: MSG-create ({strrange} infostr base dbref -- )
    over over MSG-destroy
    rot 3 pick 3 pick MSG-setinfo
    ({strrange} base dbref)
    1 rot rot
    LMGR-putrange
;
 
: MSG-count (base dbref -- count)
    LMGR-getcount
;
 
: MSG-message (base dbref -- {strrange})
    LMGR-getlist
;
 
: safeclear (d s -- )
    over over propdir? if
        over over "" -1 addprop
        "" 0 addprop
    else
        remove_prop
    then
;
 
: MSG-clearoldinfo (base dbref -- )
    swap
    over over
    "#/i" strcat safeclear
;
 
: MSG-oldinfo (base dbref -- infostr)
    swap "/i" strcat getpropstr
;
 
: MSG-newinfo (base dbref -- infostr)
    swap "#/i" strcat getpropstr
;
 
: convert-info (base dbref value -- )
    3 pick 3 pick MSG-clearoldinfo
    rot rot MSG-setinfo
;
 
: MSG-info (base dbref -- infostr)
    over over MSG-newinfo
    dup if rot rot pop pop exit then
    pop over over MSG-oldinfo
    dup if dup -4 rotate convert-info exit then
    pop pop pop ""
;
 
: MSG-item (itemnum base dbref -- itemstr)
    LMGR-getelem
;
 
: MSG-setitem (itemstr itemnum base dbref -- )
    LMGR-putelem
;
 
: MSG-insitem (itemstr itemnum base dbref -- )
    1 -4 rotate LMGR-insertrange
;
 
: MSG-append (itemstr base dbref -- )
    over over LMGR-getcount 1 +
    rot rot LMGR-putelem
;
 
: MSG-delitem (itemnum base dbref -- )
    1 -4 rotate LMGR-deleterange
;
 
public MSG-append	$libdef MSG-append
public MSG-count	$libdef MSG-count
public MSG-create	$libdef MSG-create
public MSG-delitem	$libdef MSG-delitem
public MSG-destroy	$libdef MSG-destroy
public MSG-info		$libdef MSG-info
public MSG-insitem	$libdef MSG-insitem
public MSG-item		$libdef MSG-item
public MSG-message	$libdef MSG-message
public MSG-setinfo	$libdef MSG-setinfo
public MSG-setitem	$libdef MSG-setitem
.
c
q
@register lib-mesg=lib/mesg
@register #me lib-mesg=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=B
@set $tmp/prog1=H
@set $tmp/prog1=L
@set $tmp/prog1=S
@set $tmp/prog1=V
@register #me =tmp
