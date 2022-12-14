# ------------------------------------------------------------------------------------------------
# Channel regular tracking and scoring system
# ------------------------------------------------------------------------------------------------
#
# Issues warning when someone unrecognised joins the channel
#
# Empus <empus@undernet.org>
#
# ------------------------------------------------------------------------------------------------
#
# How to track?
#
# - Maintain scores for people inside the channel
# - Subtract scores when users are kicked
# - Routinely (daily) subtract points
# - Add a point via 'ack' command
# - Add a point when clients are opped
# - Add a point when clients are voiced (except when in secure mode)
# - Delete points when G-Lined from network
# - Optionally kickban after N time if user still has no score and is not opped opped or voiced
#
# ------------------------------------------------------------------------------------------------
#
# Format:
#  trakka(nick,<chan>,<nick>) <score>
#  trakka(uhost,<chan>,<user@host>) <score>
#  trakka(xuser,<chan>,<account>) <score>
#
# ------------------------------------------------------------------------------------------------
#
# For a quick way to give initial scores to everyone already in the channel,
# Load "trakka-tools.tcl" and do ".tcl arm::trakka:init:load" in partyline (only do this *once*)
#
# ------------------------------------------------------------------------------------------------
#
# TODO: 
#        - avoid double /WHO by merging to arm::raw:join and sharing with existing scan /WHO
#        - give trakka a arm-**.tcl name for autobuild
#        - create trakka doc/README.trakka (with above text)
#        - attempt to auto remove scores when a user is manually blacklisted (cmds: add, black)
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# ---- binds
#bind join - * { arm::coroexec arm::trakka:raw:join }; # -- take an integrated join from arm::scan:continue
bind nick - * { arm::coroexec arm::trakka:raw:nick }
bind kick - * { arm::coroexec arm::trakka:raw:kick }
bind sign - * { arm::coroexec arm::userdb:signoff }
bind raw - 354 { arm::coroexec arm::trakka:raw:who }
bind raw - 315 { arm::coroexec arm::trakka:raw:endofwho }
bind mode - "* +o" { arm::coroexec arm::trakka:mode:addo }
bind mode - "* +v" { arm::coroexec arm::trakka:mode:addv }

# -- subtract points daily at midnight
bind cron - "0 0 * * *" arm::trakka:cron:score


# -- nickname channel join, from integrated script
proc trakka:int:join {nick uhost hand chan {white 0}} {
    utimer 2 [arm::trakka:int:joindelay $nick $uhost $chan $chan $white]
}
proc trakka:int:joindelay {nick uhost hand chan {white 0}} {
    global botnick
    variable trakka
    variable dbchans;  # -- dict to store channel db data
    variable nickdata; # -- dict: stores data against a nickname
                       #           nick
                       #           ident
                       #           host
                       #           ip
                       #           uhost
                       #           rname
                       #           account
                       #           signon
                       #           idle
                       #           idle_ts
                       #           isoper
                       #           chanlist
                       #           chanlist_ts
    
    if {$nick eq $botnick} { return; }
    if {![onchan $nick $chan]} { return; }
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for this chan
    
    set nick [split $nick]
    set lnick [string tolower $nick]
    
    debug 3 "takka:int:join: started: nick: -- $nick -- uhost: $uhost -- chan: $chan"
    
    lassign [split $uhost @] ident host

    # -- xuser
    set xuser 0; set doaccount 0;
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    # -- use umode +x, otherwise check for dictionary data (nickdata dict) from a previous join
    if {[regexp -- {([^\.]+)\.$xregex} $host -> xuser]} {
        set doaccount 1
    } else {
        if {![dict exists $nickdata $lnick account]} {
            set xuser 0
        } else {
            set xuser [dict get $nickdata $lnick account]
        }
        if {$xuser ne 0} {
            set doaccount 1
        } 
    }
        
    # -- ensure they have at least 1 point if user is whitelisted
    if {$white} {        
        # -- nickname
        incr trakka(nick,$chan,$nick)
        debug 2 "trakka:int:join: increased nick trakka in $chan for: $nick!$uhost (score: $trakka(nick,$chan,$nick))"
    
        if {$doaccount && $xuser ne 0} {
            incr trakka(xuser,$chan,$xuser)
            debug 2 "trakka:int:join: increased xuser trakka in $chan for: $nick!$uhost (score: $trakka(xuser,$chan,$xuser))"        
        }
        
        # -- uhost (only do this if not umode +x)
        incr trakka(uhost,$chan,$uhost)
        debug 2 "trakka:int:join: increased uhost trakka in $chan for: $nick!$uhost (score: $trakka(uhost,$chan,$uhost))"

    }

    # -- nickname
    if {[info exists trakka(nick,$chan,$nick)]} {
        # -- trakka nick based score
        debug 2 "trakka:raw:join: recognised nick trakka in $chan for: $nick!$uhost (score: $trakka(nick,$chan,$nick))"
    } else { set trakka(nick,$chan,$nick) 0 }
    
    # -- xuser
    if {$doaccount && $xuser ne 0} {
        if {[info exists trakka(xuser,$chan,$xuser)]} {
            # -- trakka xuser based score
            debug 2 "trakka:raw:join: recognised xuser trakka in $chan for: $nick!$uhost (score: $trakka(xuser,$chan,$xuser))"
        } else { set trakka(xuser,$chan,$xuser) 0; }
    }
    
    # -- uhost
    if {[info exists trakka(uhost,$chan,$uhost)]} {
        # -- trakka uhost based score
        debug 2 "trakka:raw:join: recognised uhost trakka in $chan for: $nick!$uhost (score: $trakka(uhost,$chan,$uhost))"
    } else { set trakka(uhost,$chan,$uhost) 0 }
    
    # -- now, let's work out if we know them
    set nscore $trakka(nick,$chan,$nick)
    if {[info exists trakka(uhost,$chan,$uhost)]} { set uhscore $trakka(uhost,$chan,$uhost) } else { set uhscore 0 }
    if {[info exists trakka(xuser,$chan,$xuser)] && $xuser ne "" & $xuser ne 0} { set xscore $trakka(xuser,$chan,$xuser) } else { set xscore 0 }
    set score [expr $nscore + $uhscore + $xscore]
    
    
    # -- if score is 0, we've never seen them
    # -- only continue if they were not already recently banned
    set mask [getmask $nick $xuser]
    set ischanban [ischanban $chan $mask]
    debug 1 "trakka:raw:join: total score for $nick!$uhost is: $score (mask: $mask -- ischanban: $ischanban)"
    if {$score eq 0 && $ischanban eq 0} {
        
        if {![onchan $nick $chan] || [isop $nick $chan] || [isvoice $nick $chan]} { return; }; # -- halt if not in chan, opped, or voiced

        # -- we've never seen this guy, send alert
        if {$xuser ne "" && $xuser ne 0} { set xtra "(\002account:\002 $xuser) " } else { set xtra "" }
        debug 0 "trakka:raw:join: \002trakkalert\002: client \002currently\002 unknown: $nick!$uhost $xtra"
        set alertchan [cfg:get trakka:alertchan $chan]
        if {$alertchan eq ""} { set alertchan "@$chan" }; # -- default to opnotice of the chan, but allow other chans to be set
        set kbenable 0; if {[cfg:get trakka:kb:enable] eq 1} { set kbenable 1; append xtra "-- mode or ack client to resolve" }
        putnotc $alertchan "\002trakkalert\002: client \002currently\002 unknown: $nick!$uhost $xtra"

        # -- increase trakka scores
        utimer [cfg:get trakka:init $chan] "arm::trakka:score:incr $chan [split $nick] $uhost $xuser"
    
        # -- check whether to kickban
        if {$kbenable} {
            utimer [cfg:get trakka:kb:wait $chan] "arm::trakka:kb $chan [split $nick] $uhost $xuser"
        }
    }    
}

# -- kickban user if not opped, voiced, or with score
proc trakka:kb {chan nick uhost xuser} {
    variable trakka
    variable nickdata
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka has since been disabled for chan
    if {[cfg:get trakka:init] <= [cfg:get trakka:kb:wait]} {
        # -- this is misconfiguration
        debug 0 "\002trakka:db\002 ERROR! trakka:init should be a smaller value than trakka:db:wait"
        return;
    }
    set lchan [string tolower $chan]
    set score [trakka:score $chan $nick $uhost $xuser]
    lassign [split $uhost @] ident host
    set mask [getmask $nick $xuser]
    set ischanban [ischanban $chan $mask]
    # -- begin if user has no score and they weren't recently banned already
    if {$score eq 0 && $ischanban eq 0} {
        
        if {![onchan $nick $chan] || [isop $nick $chan]} { return; }; # -- do not continue if not in chan or opped
        
        if {[get:val chan:mode $chan] ne "secure" && ![isvoice $nick $chan]} {
            # -- kickban the client

            # -- remove them!
            kickban $nick $ident $host $chan [cfg:get ban:time $chan] [cfg:get trakka:kb:reason $chan]
            
            # -- kill any increase timers
            foreach utimer [utimers] {
                lassign $utimer secs proc id
                debug 0 "trakka:kb: nick: $nick -- xuser: $xuser -- chan: $chan (timer secs: $secs -- id $id -- proc: $proc)"
                if {[string match "arm::trakka:score:incr $chan $nick *" $proc]} {
                    killutimer $id
                    debug 0 "trakka:kb: killed arm::trakka:score:incr utimer: [lrange $utimer 1 2]"
                }
            }
        }
    }
}

# -- ack
# - acknowledge a client, bump a point
proc trakka:cmd:ack {0 1 2 3 {4 ""}    {5 ""}} {
    variable trakka
    variable nickdata

    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "ack"

    lassign [db:get user,id users curnick $nick] user uid
    # -- ensure user has required access for command
    # -- check for channel
    set first [lindex $arg 0]; 
    if {[string index $first 0] eq "#"} {
        set chan $first; set tnick [lindex $arg 1];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set tnick [lindex $arg 0]
    }
    if {![trakka:isEnabled $chan]} {return; }; # -- trakka not enabled for chan
    if {![userdb:isAllowed $nick $cmd $chan $type]} {
        # -- opped clients can ack
        if {![isop $nick $chan]} {
            return;
        }
    }

    set cid [db:get id channels chan $chan]
    if {$uid eq ""} { set uid 0; }; # -- safety net if not logged in but still allowed
    
    #set level [db:get level levels uid $uid cid $cid]
    
    set ltnick [string tolower $tnick]
    if {$tnick eq ""} { reply $stype $starget "usage: ack ?chan? <nick>"; return; }
    
    set tuh [getchanhost $tnick $chan]
    
    # -- nickname
    incr trakka(nick,$chan,$tnick)
    debug 2 "trakka:cmd:ack: $nick!$uh acknowledged $tnick -- increased nick trakka in $chan for: $tnick!$tuh (score: $trakka(nick,$chan,$tnick))"
    # -- xuser
    set xuser 0; set doaccount 0;
    set thost [lindex [split $tuh @] 1]
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    # -- try umode +X, otherwise check dictionary data (nickdata dict) from a previous join
    if {[regexp -- {([^\.]+)\.$xregex} $thost -> xuser]} {
        set doaccount 1
    } else {
        # -- check dict
        if {![dict exists $nickdata $ltnick account]} {
            set xuser 0
        } else {
            set xuser [dict get $nickdata $ltnick account]
        }
        if {$xuser ne 0} {
            set doaccount 1
        } 
    }
    if {$doaccount && $xuser ne 0} {
        incr trakka(xuser,$chan,$xuser)
        debug 2 "trakka:cmd:ack: $nick!$uh acknowledged $tnick -- increased xuser trakka in $chan for: $tnick!$tuh (score: $trakka(xuser,$chan,$xuser))"
    }
    
    # -- uhost (only do this if not umode +x)
    incr trakka(uhost,$chan,$tuh)
    debug 2 "trakka:cmd:ack: $nick!$uh acknowledged $tnick -- increased uhost trakka in $chan for: $tnick!$tuh (score: $trakka(uhost,$chan,$tuh))"
    
    reply $type $target "done."

    # -- create log entry for command use (if integrated to Armour)
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    return;
}

# -- nudge
# - kickban a client out of the channel, using precanned kick message
proc trakka:cmd:nudge {0 1 2 3 {4 ""} {5 ""}} {
    variable trakka
    variable nickdata

    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "nudge"

    lassign [db:get user,id users curnick $nick] user uid
    # -- ensure user has required access for command
    # -- check for channel
    set first [lindex $arg 0]; 
    if {[string index $first 0] eq "#"} {
        set chan $first; set tnick [lindex $arg 1];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set tnick [lindex $arg 0]
    }
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }

    set cid [db:get id channels chan $chan]
    if {$uid eq ""} { return; }
    
    #set level [db:get level levels uid $uid cid $cid]
    
    set ltnick [string tolower $tnick]
    if {$tnick eq ""} { reply $stype $starget "usage: nudge ?chan? <nick>"; return; }
    
    set tuh [getchanhost $tnick $chan]
    
    # -- xuser
    set xuser 0; set doaccount 0;
    set thost [lindex [split $tuh @] 1]
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    # -- try umode +x, otherwise check dictionary data (nickdata dict) from a previous join
    if {[regexp -- {([^\.]+)\.$xregex} $thost -> xuser]} {
        set doaccount 1
    } else {
        # -- check dict
        if {![dict exists $nickdata $ltnick account]} {
            set xuser 0
        } else {
            set xuser [dict get $nickdata $ltnick account]
        }
    }

    set mask [getmask $tnick $xuser]; # -- build the mask

    # -- send the kickban!
    set reason [cfg:get trakka:nudge:reason $chan]
    set duration [cfg:get trakka:nudge:time $chan]
    # -- use the nick as 0 to force the ident as hostmask
    kickban 0 $mask 0 $chan $duration $reason    
    
    # -- create log entry for command use (if integrated to Armour)
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    return;
}

# -- score
# - display a user's trakka score
proc trakka:cmd:score {0 1 2 3 {4 ""} {5 ""}} {
    variable trakka
    variable nickdata

    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "score"

    lassign [db:get user,id users curnick $nick] user uid
    # -- ensure user has required access for command
    # -- check for channel
    set first [lindex $arg 0]; 
    if {[string index $first 0] eq "#"} {
        set chan $first; set tnick [lindex $arg 1];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set tnick [lindex $arg 0]
    }
    if {![trakka:isEnabled $chan]} {return; }; # -- trakka not enabled for chan

    set cid [db:get id channels chan $chan]
    if {$uid eq ""} { return; }
    
    #set level [db:get level levels uid $uid cid $cid]
    
    set tuh [getchanhost $tnick]
    if {$tnick eq ""} { reply $stype $starget "usage: score <nick>"; return; }
    set ltnick [string tolower $tnick]

    # -- xuser
    set xuser 0;
    set thost [lindex [split $tuh @] 1]
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    # -- try umode +X, otherwise check dictionary data (nickdata dict) from a previous join
    if {[regexp -- {([^\.]+)\.$xregex} $thost -> txuser]} {
        # -- var created
    } else {
        # -- check dict
        if {![dict exists $nickdata $ltnick account]} {
            set txuser 0
        } else {
            set txuser [dict get $nickdata $ltnick account]
        }
    }
    
    set score [trakka:score $chan $tnick $tuh $txuser]
    debug 2 "trakka:cmd:score: $nick!$uh requested score for $tnick -- (score: $score)"
    
    reply $type $target "\002score:\002 $score (\002nick:\002 $tnick)"

    # -- create log entry for command use (if integrated to Armour)
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    return;
}

# -- nickname change
proc trakka:raw:nick {nick uhost handle chan newnick} {
    variable trakka
        
    debug 2 "takka:raw:nick: started: nick: $nick -- uhost: $uhost -- chan: $chan -- newnick: $newnick"
    
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan
    
    if {[info exists trakka(nick,$chan,$nick)]} {
        # -- adding new trakka nick based array
        # - give it a score of 1, no sense in copying score over for a temporary nick
        set trakka(nick,$chan,$newnick) 1
        debug 2 "trakka:raw:nick: adding new nick trakka of $newnick in $chan -- nickchange (by $nick!$uhost)"
    }        

}

# -- nickname kicked from chan
proc trakka:raw:kick {nick uhost handle chan vict reason} {
    variable trakka
    variable nickdata

    # -- should we even remove tracking for a nick when they are kicked?
    #    we will subtract a point, and delete if it reaches zero
    #    TODO: review this approach
    
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan
    
    debug 5 "takka:raw:kick: started: nick: $nick -- chan: $chan -- vict: $vict -- reason: $reason"
    
    set victhost [getchanhost $vict $chan]
    set lvict [string tolower $vict]
    set ident [lindex [split $victhost @] 0]
    set host [lindex [split $victhost @] 1]
    
    # -- nickname
    if {[info exists trakka(nick,$chan,$vict)]} {
        # -- unset trakka nick based tracking array
        incr -$trakka(nick,$chan,$vict)
        if {$trakka(nick,$chan,$vict) <= 0} {
            unset trakka(nick,$chan,$vict)
            debug 2 "trakka:raw:kick: removed nick trakka in $chan for $vict!$victhost -- kicked"
        }
    }
        
    # -- xuser
    set xuser 0;
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    if {[regexp -- {([^\.]+)\.$xregex} $host -> xuser]} {
        # -- var created
    } else {
        # -- check dict
        if {![dict exists $nickdata $lvict account]} {
            set xuser 0
        } else {
            set xuser [dict get $nickdata $lvict account]
        }    
    }
    if {[info exists trakka(xuser,$chan,$xuser)] && $xuser ne 0} {
        # -- unset trakka xuser based score
        incr -$trakka(xuser,$chan,$xuser)
        if {$trakka(xuser,$chan,$xuser) <= 0} {
            unset trakka(xuser,$chan,$xuser)
            debug 2 "trakka:raw:kick: removed xuser trakka in $chan for $xuser ($vict!$victhost) -- kicked"
        }
    } 
    
    # -- uhost
    if {[info exists trakka(uhost,$chan,$victhost)]} {
        # -- unset trakka uhost based tracking array
        incr -$trakka(uhost,$chan,$victhost)
        if {$trakka(uhost,$chan,$victhost) <= 0} {
            unset trakka(uhost,$chan,$victhost)
            debug 2 "trakka:raw:kick: removed uhost trakka in $chan for $vict!$victhost -- kicked"
        }
    }
}

# -- quit handling (for G-Lines)
proc trakka:raw:quit {nick uhost hand chan reason} {
    set host [lindex [split $uhost @] 1]
    # -- those who get glined should have scores deleted
    if {[cfg:get gline:auto $chan]} {
        debug 4 "raw:quit: G-Line $chan: $nick!$uhost (reason: $reason)"
        # -- only if matches configured mask
        if {[string match [cfg:get gline:mask $chan] $reason]} {
            # -- nickname
            if {[info exists trakka(nick,$chan,$vict)]} {
                unset trakka(nick,$chan,$vict)
                debug 2 "trakka:raw:quit: removed nick trakka in $chan for $nick!$uhost -- \002G-Lined\002"

            }
            # -- xuser
            set xregex [cfg:get xhost:ext *]
            regsub -all {\.} $xregex "\\." xregex
            if {[regexp -- {([^\.]+)\.$xregex} $host -> xuser]} {
                if {[info exists trakka(xuser,$chan,$xuser)]} {
                    unset trakka(xuser,$chan,$xuser)
                    debug 2 "trakka:raw:quit: removed xuser trakka in $chan for $xuser ($nick!$uhost) -- \002G-Lined\002"

                }
            } 
            # -- uhost
            if {[info exists trakka(uhost,$chan,$uhost)]} {
                unset trakka(uhost,$chan,$uhost)
                debug 2 "trakka:raw:quit: removed uhost trakka in $chan for $nick!$uhost -- \002G-Lined\002"

            }        
        }
    }
}


# -- increment trakka scores after timer
proc trakka:score:incr {chan nick uhost {xuser ""}} {
    variable trakka
    
    if {![onchan $nick $chan]} { return; }; # -- only if nick is still onchan
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan
    
    set nick [join $nick]
    
    debug 3 "takka:score:incr started: nick: $nick -- uhost: $uhost -- xuser: $xuser"

    incr trakka(nick,$chan,$nick)
    incr trakka(uhost,$chan,$uhost)
    if {$xuser ne "" && $xuser ne -1 && $xuser ne 0} {
        incr trakka(xuser,$chan,$xuser)
        debug 2 "trakka:score:incr: increased scores in $chan for $nick!$uhost (xuser: $xuser)"
    } else {
        debug 2 "trakka:score:incr: increased scores in $chan for $nick!$uhost"
    }
}

# -- load the trakka db file
proc trakka:load {} {
    variable trakka
    variable dbchans
    
    foreach key [array names trakka] {
        unset trakka($key); # -- flush all trakka counters
    }
    
    set count 0; set ncount 0; set uhcount 0; set xcount 0;
    db:connect
    set rows [db:query "SELECT cid,type,value,score FROM trakka"]
    foreach row $rows {
        lassign $row cid type value score
        if {$type eq "xuser" && $value eq 0} { continue; }; # -- safety net
        set chan [dict get $dbchans $cid chan]
        set trakka($type,$chan,$value) $score

        # -- safety net
        if {$score <= 0} {
            # -- delete trakka with empty score
            unset trakka($type,$chan,$value)
            db:query "DELETE FROM trakka WHERE cid=$cid AND type='$type' AND value='$value'"
            debug 3 "trakka:load: \002zero score trakka deleted\002 trakka($type,$chan,$value)"
            continue;
        }

        incr count
        switch -- $type {
            nick    { incr ncount }
            uhost    { incr uhcount }
            xuser    { incr xcount }
        }
        debug 5 "trakka:load: loaded trakka entry: trakka($type,$chan,$value) (score: $score)"
    }
    db:close
    debug 0 "trakka:load: \002loaded $count total trakkas\002 (nick: $ncount -- uhost: $uhcount -- xuser: $xcount)"    
}

proc trakka:save {} {
    variable trakka
    variable dbchans
    
    set count(total) 0
    db:connect
    foreach entry [array names trakka] {
        lassign [split $entry ,] type chan value
        if {$type eq "xuser" && $value eq 0} { continue; }; # -- safety net
        set lchan [string tolower $chan]
        set cid [dict keys [dict filter $dbchans script {id dictData} {
            expr {[dict get $dictData chan] eq $lchan}
        }]]

        if {$cid eq ""} {
            # -- this should only happen if a channel has since been purged
            debug 0 "traka:save: \002(error!)\002 no such channel ID for chan: $chan"
            unset trakka($entry)
            continue;
        }

        if {$trakka($type,$chan,$value) <= 0} {
            # -- delete trakka with empty score
            unset trakka($type,$chan,$value)
            debug 3 "trakka:save: \002zero score trakka deleted\002 trakka($type,$chan,$value)"
            continue;
        }

        if {![info exists count($chan)]} { set count($chan) 0 }
        set row [db:query "SELECT score FROM trakka WHERE cid=$cid AND type='$type' AND value='$value'"]
        if {$row eq ""} {
            # -- INSERT
            db:query "INSERT INTO trakka (cid,type,value,score) VALUES ($cid,'$type','$value','$trakka($entry)')"
        } else {
            # -- UPDATE
            db:query "UPDATE trakka SET score='$trakka($entry)' WHERE cid=$cid AND type='$type' AND value='$value'"
        }
        incr count($chan)
        incr count(total)
    }
    db:close
    set tchan 0
    foreach ctype [array names count] {
        if {$ctype ne "total"} { debug 0 "\002trakka:save:\002 saved $count($ctype) trakka entries for chan: $ctype"; incr tchan }
    }
    if {$tchan > 1} { debug 0 "\002trakka:save:\002 saved $count(total) total trakka entries." }
    
    timer [cfg:get trakka:autosave *] arm::trakka:save; # -- restart the timer
}


proc trakka:killtimers {type match } {
    if {$type eq "timer"} {
        foreach timer [timers] {
            lassign $timer mins proc id
            if {[string match $match $proc]} {
                killtimer $id
                debug 0 "trakka:killtimers: killed timer: [lrange $timer 1 2]"
            }        
        }
    }
    if {$type eq "utimer"} {
        foreach utimer [utimers] {
            lassign $utimer secs proc id
            if {[string match $match $proc]} {
                killutimer $id
                debug 0 "trakka:killtimers: killed utimer: [lrange $utimer 1 2]"
            }    
        }    
    }
}

# -- subtract a point daily
proc trakka:cron:score {min hour day month weekday} {
    variable trakka
    
    # -- loop over each registered chan where trakka is enabled
    db:connect
    set cids [db:get cid settings setting "trakka" value "on"]
    foreach cid $cids {
        set chan [db:get chan channels id $cid]        
        set sub [cfg:get trakka:subtract $chan]
        set names [array names trakka]
        set sort [lsort $names]
        set count 0; set ncount 0; set uhcount 0; set xcount 0; set dcount 0;
        foreach entry $sort {
            # -- safety net
            if {![regexp -- {^(?:nick|uhost|xuser),} $entry]} { continue; }
            lassign [split $entry ,] type chan value

            incr count; set sub 0
            if {$type eq "nick"} {
                if {![onchan $value $chan]} { incr ncount; set sub 1 }; # -- only subtract nick trakka if not on chan
            } elseif {$type eq "uhost"} {
                incr uhcount; set sub 1
            } elseif {$type eq "xuser"} {
                incr xcount; set sub 1
            }
            if {$sub} { incr trakka($type,$chan,$value) -$sub }; # -- subtract 1 point

            debug 3 "trakka:cron:score: daily trakka score subtracted -$sub from trakka($type,$chan,$value) (newscore: $trakka($type,$chan,$value))"

            if {$trakka($type,$chan,$value) <= 0} {
                # -- delete trakka with empty score
                unset trakka($type,$chan,$value)
                incr dcount
                debug 3 "trakka:cron:score: \002daily trakka job deleted\002 trakka($type,$chan,$value)"
            }
        }
        debug 0 "trakka:cron:score: \002decremented $count total $chan trakka's in daily cronjob\002 (nick: $ncount -- uhost: $uhcount -- xuser: $xcount)"
        debug 0 "trakka:cron:score: \002deleted $dcount total $chan trakka's in daily cronjob\002"
    }
    db:close
}

proc trakka:score:add {} {
    variable trakka
    # -- hold a var for the endofwho
    set trakka(routinely) 1
        
    set thelist [list]
    foreach entry [array names trakka] {
        lassign [split $entry ,] type chan value
        debug 0 "\002trakka:score:add\002: entry: type: $type -- chan: $chan -- value: $value"
        if {[validchan $chan]} {
            if {$chan ni $thelist && [botonchan $chan]} { lappend thelist $chan }
        }
    }
    set thelist [join $thelist ,]
    debug 0 "\002trakka:score:add\002: thelist: $thelist"
    if {$thelist ne ""} { putquick "WHO $thelist c%cnuhiart,105" }
}

proc trakka:raw:who {server cmd arg} {
    global botnick
    variable trakka

    set arg [split $arg]
    lassign $arg mynick query chan ident ip host nick xuser rname
    set rname [string trimleft $rname ":"] 
    set rname [join $rname]
    
    # -- safety nets
    if {$query ne "105"} { return; }; # -- we presume this only responded because trakka is enabled for chan
    if {$nick eq $botnick} { return; }
    
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan
  
    debug 3 "trakka:raw:who: query: $query -- chan: $chan -- ident: $ident -- ip: \
        $ip -- host: $host -- nick: $nick -- xuser: $xuser -- rname: $rname"
        
    set uhost "$ident@$host"
    set nuh "$nick!$uhost"
    
    set names [array names trakka]
    set sort [lsort $names]
    foreach entry $sort {
        # -- safety net
        if {![regexp -- {^(?:nick|uhost|xuser),} $entry]} { continue; }
        lassign [split $entry ,] type chan value
        set add 0
        switch -- $type {
            nick {
                # -- nickname
                if {$value eq $nick} {
                    set add 1
                    incr trakka(ncount)
                }
            }
            uhost {
                # -- uhost
                if {$value eq $uhost} {
                    set add 1
                    incr trakka(uhcount)
                }
            }
            xuser {
                # -- xuser
                if {$value eq $xuser && $value ne 0} {
                    set add 1
                    incr trakka(xcount)
                }
            }
        }
        if {$add} {
            # -- entry match exists, add 1 point
            incr trakka(count)
            incr trakka($type,$chan,$value); # -- do the actual score increase
            debug 2 "trakka:raw:who: routine trakka increment (+1): trakka($type,$chan,$value) (newscore: $trakka($type,$chan,$value))"
        }
    }
}

proc trakka:raw:endofwho {server cmd arg} {
    variable trakka
        
    set arg [split $arg]
    lassign $arg mynick mask

    if {![info exists trakka(routinely)]} { return; }

    # -- prime the counters if they don't already exist
    if {![info exists trakka(count)]} { set trakka(count) 0 }
    if {![info exists trakka(ncount)]} { set trakka(ncount) 0 }
    if {![info exists trakka(uhcount)]} { set trakka(uhcount) 0 }
    if {![info exists trakka(xcount)]} { set trakka(xcount) 0 }
    
    debug 0 "trakka:raw:endofwho: \002incremented $trakka(count) total trakka's in routine cycle\002 (nick: $trakka(ncount) uhost: $trakka(uhcount) xuser: $trakka(xcount))"

    unset trakka(count)
    unset trakka(ncount)
    unset trakka(uhcount)
    unset trakka(xcount)
    unset trakka(routinely)
    
    # -- start again
    timer [cfg:get trakka:routine *] arm::trakka:score:add
}


# -- add a point if opped
proc trakka:mode:addo {nick uhost hand chan mode target} {
    variable trakka
    variable nickdata
    
    if {[isbotnick $target]} { return; }    
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan

    set tuhost [getchanhost $target]
    set thost [lindex [split $tuhost @] 1]
    set ltarget [string tolower $target]
    
    # -- nickname
    incr trakka(nick,$chan,$target)
    debug 2 "trakka:mode:addo: client opped -- increased nick trakka in $chan for: $target!$tuhost (nick score: $trakka(nick,$chan,$target))"

    # -- xuser
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    # -- try umode +x, otherwise check dictionary data (nickdata dict) from a previous join
    if {[regexp -- {([^\.]+)\.$xregex} $thost -> xuser]} {
        # -- var created
    } else {
        # -- check dict
        if {![dict exists $nickdata $ltarget account]} {
            set xuser 0
        } else {
            set xuser [dict get $nickdata $ltarget account]
        }
    }
    if {$xuser ne 0} {        
        incr trakka(xuser,$chan,$xuser)
        debug 2 "trakka:mode:addo: client opped -- increased xuser trakka in $chan for: $target!$tuhost (xuser score: $trakka(xuser,$chan,$xuser))"
    } 
    
    # -- uhost
    incr trakka(uhost,$chan,$tuhost)
    debug 2 "trakka:mode:addo: client opped -- increased uhost trakka in $chan for: $target!$tuhost (uhost score: $trakka(uhost,$chan,$tuhost))"

}

# -- add a point if voiced
proc trakka:mode:addv {nick uhost hand chan mode target} {
    variable trakka
    variable nickdata

    if {[isbotnick $target]} { return; }
    if {![trakka:isEnabled $chan]} { return; }; # -- trakka not enabled for chan

    # -- don't add score if chanmode +D (Armour mode: secure)
    if {[get:val chan:mode $chan] eq "secure"} { return; }
    
    set tuhost [getchanhost $target]
    set thost [lindex [split $tuhost @] 1]
    set ltarget [string tolower $target]
    
    # -- nickname
    incr trakka(nick,$chan,$target)
    debug 2 "trakka:mode:addv: client voiced -- increased nick trakka in $chan for: $target!$tuhost (nick score: $trakka(nick,$chan,$target))"

    # -- xuser
    set xregex [cfg:get xhost:ext *]
    regsub -all {\.} $xregex "\\." xregex
    # -- try umode +x, otherwise check dictionary data (nickdata dict) from a previous join
    if {[regexp -- {([^\.]+)\.$xregex} $thost -> xuser]} {
        # -- var created
    } else {
        # -- check dict
        if {![dict exists $nickdata $ltarget account]} {
            set xuser 0
        } else {
            set xuser [dict get $nickdata $ltarget account]
        }
    }
    if {$xuser ne 0} {
        incr trakka(xuser,$chan,$xuser)
        debug 2 "trakka:mode:addv: client voiced -- increased xuser trakka in $chan for: $target!$tuhost (xuser score: $trakka(xuser,$chan,$xuser))"
    } 
    
    # -- uhost (only do this if not umode +x)
    incr trakka(uhost,$chan,$tuhost)
    debug 2 "trakka:modea:ddv: client voiced -- increased uhost trakka in $chan for: $target!$tuhost (uhost score: $trakka(uhost,$chan,$tuhost))"

}


# -- check if trakka is enabled on a channel
proc trakka:isEnabled {chan} {
    set cid [db:get id channels chan $chan]
    if {$cid eq ""} { return 0; }
    set enabled [db:get value settings setting trakka cid $cid]
    if {$enabled eq "" || $enabled eq 0 || $enabled eq "off"} { return 0; }
    return 1; # -- must be enabled!
}

# -- build client score
# - mainly for 3rd party scripts
proc trakka:score {chan nick uhost xuser} {
    variable trakka
    if {[info exists trakka(nick,$chan,$nick)]} { set nscore $trakka(nick,$chan,$nick) } else { set nscore 0 }
    if {[info exists trakka(uhost,$chan,$uhost)]} { set uhscore $trakka(uhost,$chan,$uhost) } else { set uhscore 0 }
    if {[info exists trakka(xuser,$chan,$xuser)] && $xuser ne 0} { set xscore $trakka(xuser,$chan,$xuser) } \
    else { set xscore 0 }
    set score [expr $nscore + $uhscore + $xscore]
    return $score
}

    
# -- kill all timers on load or rehash
trakka:killtimers timer "arm::trakka:*"
trakka:killtimers utimer "arm::trakka:*"

# -- load trakka's from file
trakka:load

# -- start timer to automatically add points periodically
timer [cfg:get trakka:routine *] arm::trakka:score:add

# -- start the autosave timer
timer [cfg:get trakka:autosave *] arm::trakka:save

# -- ensure trakka sees the joins
if {[cfg:get integrate:procs] eq ""} { set cfg(integrate:procs) "trakka:int:join"} else {
    if {[lsearch [cfg:get integrate:procs] "trakka:int:join"] eq "-1"} {
        append cfg(integrate:procs) " trakka:int:join"
    }
}

putlog "\[@\] Armour: loaded trakka support"

}
# -- end of namespace