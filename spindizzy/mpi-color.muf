( /quote -dsend -S '/data/spindizzy/muf/mpi-color.muf )
@prog mpi-color.muf
1 6000 d
i
$include $lib/nu-color
  
: mpi-color
    lnc-parse-me
;
.
c
q
@reg mpi-color.muf=mpi-color
