( /quote -dsend -0 '/data/spindizzy/muf/souvenir-new.muf )
@prog makeFakeSouvenir-new.muf
1 5000 d
i
(  Make Fake Souvenir NEW  - Morticon, morticon@spindizzy.org 2011
      Original by: Austin Dern, austin@spindizzy.org   
      Code based on fakemunchies.muf by Saurian@FurToonia.  
 
   This program creates fake objects with a specified name.  They are 
      given descriptions, scents, feels, and tastes which are either as 
      specified or else are default messages.  The fake object can also have
      a creation cost, so the owner can make money off of selling things.  The
      money is transferred to the thing which contains the action.

To use:
   
@action Vend = Vending Machine
@link Vend = #22092
  
Then set these properties on the action as desired to customize the souvenir:
souvenir/name:My Souvenir
souvenir/cost:10     [The cost of the item to create.  Can be 0 or higher]
souvenir/description:My souvenir description!
souvenir/feel:How my souvenir feels.
souvenir/scent:How my souvenir smells.
souvenir/taste:How my souvenir tastes.
souvenir/success:The souvenir appears in your hands! [success message]
)
  
lvar cost
lvar name
lvar description
lvar scent
lvar feel
lvar taste
lvar success
  
: buy  (Sees if they have enough pennies, confirms, then buys it )
  ( See if there are enough pennies )
  
  ( Make sure cost is positive )
  cost @ 0 < if "Make Fake Souvenirs: Cost is negative." .tell exit then
  
  ( Show the cost )
  cost @ if
    name @ " costs " strcat cost @ intostr strcat " " strcat
      cost @ 1 = if "penny" else "pennies" then
      sysparm strcat "." strcat .tell
  
    ( See if player has enough money and confirm )
    cost @ me @ pennies > if
      me @ "You do not have enough " "pennies" sysparm strcat
        " to buy " name @ strcat "." strcat .tell
      exit
    else
      "OK to buy " name @ strcat " (yes/no)?" strcat .tell
      read strip tolower
      "yes" strcmp if "Cancelled." .tell exit then
    then
  
    ( Item costs something, take the money away )
    me @ cost @ -1 * addpennies
    ( And give it to the trig object parent )
    trig location cost @ addpennies
  then
  
  me @ "_fake/" name @ strcat "/desc" strcat description @ setprop
  me @ "_fake/" name @ strcat "/scent" strcat scent @ setprop
  me @ "_fake/" name @ strcat "/feel" strcat feel @ setprop
  me @ "_fake/" name @ strcat "/taste" strcat taste @ setprop
  me @ "_fake/" name @ strcat "/show" strcat "yes" setprop
  
  success @ .tell
;

: main
    pop
    "me" match me !

    ( Make sure trig is on an object, for transferring money )
    trig location thing? not if "Make Fake Souvenirs: Action is not attached to a thing!" .tell exit then
  
    ( Get the fake object info )
  
    ( Cost )
    trig "souvenir/cost" getpropstr
    dup number? if atoi else 0 then cost !
    
    ( Name)
    trig "souvenir/name" getpropstr
    dup strlen not if pop "Something" then name !
  
    ( Description )
    trig "souvenir/description" getpropstr
    dup strlen not if pop "It looks like a souvenir." then description !
  
    ( Scent )
    trig "souvenir/scent" getpropstr
    dup strlen not if pop "It smells like a souvenir." then scent !
  
    ( Feel )
    trig "souvenir/feel" getpropstr
    dup strlen not if pop "It feels like a souvenir." then feel !
  
    ( Taste )
    trig "souvenir/taste" getpropstr
    dup strlen not if pop "It tastes like a souvenir." then taste !

    ( Success )
    trig "souvenir/success" getpropstr
    dup strlen not if pop name @ " is now yours!" strcat then success !
  
    ( Make sure they don't already have one )
    me @ "_fake/" name @ strcat propdir? if
        "You already have a " name @ strcat "!" strcat .tell
        exit
    then
  
    ( Go ahead and buy it )
    buy
;
.
c
q
@set makeFakeSouvenir-new.muf=3
@set makeFakeSouvenir-new.muf=W
@set makeFakeSouvenir-new.muf=L
@set makeFakeSouvenir-new.muf=V
@set makeFakeSouvenir-new.muf=_docs:@list #22092=1=24
