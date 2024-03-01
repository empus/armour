# optional script used to give all existing channel users a trakka score
# useful to avoid a lot of noise when trakka is first enabled
#
# load the script into eggdrop
#
#         source ./armour/plugins/trakka/trakka-tools.tcl
#
# then in partyline, use:
#
#         .tcl trakka:init:load
#
# all users will receive a single score of 1.  to increase scores, use the below as many times
# as required:
#
#         .tcl trakka:incr <num>
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

bind raw - 354 arm::trakka:raw:init:who
bind raw - 315 arm::trakka:raw:init:endofwho

proc trakka:init:load {} {
    variable trakka
    set trakka(initload) 1; # -- hold a var for the endofwho
    # -- loop over each registered chan where trakka is enabled
    db:connect
    set cids [db:get cid settings setting "trakka" value "on"]
    foreach cid $cids {
        set chan [db:get chan channels id $cid]    
        putquick "WHO $chan c%cnuhiart,106"
    }
    db:close
}

proc trakka:raw:init:who {server cmd arg} {
    global botnick
    variable trakka
    
    set arg [split $arg]
    lassign $arg mynick query chan ident ip host nick xuser rname
    set rname [string trimleft $rname ":"] 
    set rname [join $rname]
    
    debug 5 "trakka:raw:init: who: -- query: $query -- chan: $chan -- ident: $ident -- ip: \
        $ip -- host: $host -- nick: $nick -- xuser: $xuser -- rname: $rname"
    
    # -- safety nets
    if {$query ne "106"} { return; }
    if {$nick eq $botnick} { return; }

    # set rname [string trimleft $rname ":"] 
    # set rname [join $rname]
    set uhost "$ident@$host"
    # set nuh "$nick!$uhost"
    # set chan $trakka(chan)
    
    # -- add trakka's
    if {![info exists trakka(nick,$chan,$nick)]} { 
        set trakka(nick,$chan,$nick) 1
        incr trakka(count)
        incr trakka(ncount)
        debug 1 "trakka:raw:init:who: initial trakka add: trakka(nick,$chan,$nick) (newscore: $trakka(nick,$chan,$nick))"
    }
    if {![info exists trakka(uhost,$chan,$uhost)]} {
        set trakka(uhost,$chan,$uhost) 1
        incr trakka(count)
        incr trakka(uhcount)
        debug 1 "trakka:raw:init:who: initial trakka add: trakka(uhost,$chan,$uhost) (newscore: $trakka(uhost,$chan,$uhost))"
    }
    if {$xuser ne 0 && ![info exists trakka(xuser,$chan,xuser)]} {
        set trakka(xuser,$chan,$xuser) 1
        incr trakka(count)
        incr trakka(xcount)
        debug 1 "trakka:raw:init:who: initial trakka add: trakka(xuser,$chan,$xuser) (newscore: $trakka(xuser,$chan,$xuser))"
    }

}

proc trakka:raw:init:endofwho {server cmd arg} {
    variable trakka
    set arg [split $arg]
    lassign $arg mynick mask
    if {![info exists trakka(initload)]} { return; }
  
    # -- prime the counters if they don't already exist
    if {![info exists trakka(count)]} { set trakka(count) 0 }
    if {![info exists trakka(ncount)]} { set trakka(ncount) 0 }
    if {![info exists trakka(uhcount)]} { set trakka(uhcount) 0 }
    if {![info exists trakka(xcount)]} { set trakka(xcount) 0 }
    
    debug 0 "trakka:raw:init:endofwho: \002added $trakka(count) total trakka's in initial load\002 \
        (nick: $trakka(ncount) -- uhost: $trakka(uhcount) xuser: -- $trakka(xcount))"
    unset trakka(initload)
    unset trakka(count)
    unset trakka(ncount)
    unset trakka(uhcount)
    unset trakka(xcount)
}

# -- increase or decrease all score values
proc trakka:incr {{incr 1}} {
    variable trakka
    set count 0; set ncount 0; set uhcount 0; set xcount 0; set deleted 0;
    foreach entry [array names trakka] {
        set line [split $entry ,]
        lassign $line type chan value
        if {$type ne "nick" && $type ne "uhost" && $type ne "xuser"} { continue; }
        incr count
        set score $trakka($type,$chan,$value)
        set oldscore $score
        # -- apply increment
        incr score $incr
        if {$score <= 0} {
            # -- delete trakka
            unset trakka($type,$chan,$value)
            incr deleted
            debug 0 "trakka:incr deleted trakka array trakka($type,$chan,$value) (score: $oldscore -> $score)"
        } else {
            switch -- $type {
                nick    { incr ncount }
                uhost    { incr uhcount }
                xuser    { incr xcount }
        }
        debug 0 "trakka:incr incremented trakka array trakka($type,$chan,$value) by a value of: $incr (score: $oldscore -> $score)" }
    }
    debug 0 "trakka:incr: \changed $count total trakka's\002 (nick: $ncount uhost: $uhcount xuser: $xcount -- deleted $deleted)"
}

putlog "\[@\] Armour: plugin loaded: trakka tools (init, incr)"

}
# -- end of namespace