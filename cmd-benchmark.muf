@program cmd-benchmark
1 99999 d
1 i
lvar runsecs
: bench ( int:runsecs -- int:ips )
    runsecs !
    
    (sync to the second.)
    systime
    begin
        dup systime = while
    repeat
    pop
    
    systime 0
    begin
        systime 3 pick -
    runsecs @ < while
        1 +
    repeat
    swap pop
    
    11 * runsecs @ /
;
  
: main
    preempt
    5 begin
        dup 0 > while 1 -
        1 bench 1000 / intostr "K preempt ips" strcat tell
        0 sleep
    repeat
    pop
;
.
c
q
@register #me cmd-benchmark=tmp/prog1
@set $tmp/prog1=3
@set $tmp/prog1=W
@action benchmark=#0=tmp/exit1
@link $tmp/exit1=$tmp/prog1
@register #me =tmp
