@program sys-macros
def no? "{0|n*}" smatch
def showhelp prog "_help" array_get_proplist me @ 1 array_make array_notify
def yes? "{1|y*}" smatch
q
@recycle sys-macros
