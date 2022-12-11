# -- aidle
#
# punish channel idlers
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# -- default chan
set aidle(chan) "#channel"

# -- max idle time (mins)
set aidle(mins) 10

# -- temporary channel ban time? (mins)
set aidle(duration) 5

# -- channel kickban reason
set aidle(reason) "Please do not idle on #channel"

# -- debug level (0-3) - [1]
set aidle(debug) 3

# -- lastlog mode
# - modes:
# 0:    off
# 1:    standalone
# 2:    integrated to Armour
set aidle(mode) 2


# ------------------------------------------------------------------------------------------------
proc aidle:check {} {
    variable aidle
    global botnick
    if {[botisop $aidle(chan)]} { utimer 60 aidle:check }
    foreach x [chanlist $aidle(chan)] {
        # -- don't punish me or anyone opped or voiced on common chans, or authenticated
        if {$x eq $botnick || [isvoice $x] || [isop $x]} { continue; }
        # -- only check this if Armour loaded
        if {[info commands db:get] ne ""} {
            if {[db:get user users curnick $x] != ""} { continue; }
        }
        if {[getchanidle $x $aidle(chan)] >= $aidle(mins)} {
            # -- punish
            set banmask "*!*@[lindex [split [getchanhost $x] @] 1]"
            aidle:debug 1 "aidle:unban: sending kickban in $aidle(chan) for $x (banmask: $banmask -- idle: [getchanidle $x $aidle(chan)])"
            putquick "MODE $aidle(chan) +b $banmask"
            putquick "KICK $aidle(chan) $x :$aidle(reason)"
            timer $aidle(duration) { aidle:unban [split $banmask] }
        }
    }
}

proc aidle:unban {ban} {
    variable aidle
    set ban [join $ban]
    if {![botisop $aidle(chan)]} {
        aidle:debug 0 "aidle:unban: cannot remove ban from $aidle(chan), not opped: $ban"
        # -- try again in 5 mins
        timer 5 { aidle:unban [split $ban] }
    } else {
        aidle:debug 0 "aidle:unban: removing ban from $aidle(chan): $ban"
        putquick "MODE $aidle(chan) -b $ban"
    }
}

# -- timer to check idle times
if {![string match *aidle:check* [utimers]]} {
  utimer 60 aidle:check
}

# -- debug proc
proc aidle:debug {lvl msg} {
    variable aidle
    if {$lvl <= $aidle(debug)} { putloglev d * $msg }
}


putlog "\[@\] Armour: loaded plugin: aidle (anti-idle)"

}
# -- end of namespace