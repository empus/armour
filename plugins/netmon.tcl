# ------------------------------------------------------------------------------------------------
# Undernet Network Monitor Utility Bot
# ------------------------------------------------------------------------------------------------
#
# -- automatic rbl management via gline monitoring
# -- automatic rbl insertion on configured D patterns
# -- automatic dnsbl entries
#
# Empus <empus@undernet.org>
#
# ------------------------------------------------------------------------------------------------
namespace eval nm {
# ------------------------------------------------------------------------------------------------

# -- debug level (0-3)
set nm(debug) "3"

# -- version
set nm(version) "v0.3 (rev: 20220119)"

# ---- oper configuration
set cfg(oper:user) "netmon"; # -- user
set cfg(oper:pass) "";       # -- password

# ---- autorbl configuration

# -- euworld.* manual oper gline match regex
set cfg(gline:regex) {^(?:compromised\s(?:hosts?|netblock|network|net|machines?|servers?|box)|clean\sand\sssecure\sthis\scomputer|floodbots/trojans)}

# -- dronescan.* D g-line regex match
set cfg(gline:ddd) {^\([^\)]+\)\sYou\swere\sidentified\sas\sa\sdrone}

# -- dronescan.* E g-line flood match
set cfg(gline:flood) {^Host\sused\sfor\sflooding}

# -- report channel
set cfg(chan) "#armour-dev"

# -- IRCBL (ircbl.org) RBL settings
set cfg(ircbl) 1;                                   # -- ircbl.org add & remove entries based on gline/remgline?
set cfg(ircbl:rbl) "unet.rbl.ircbl.org";            # -- ircbl.org rbl for looukps (i.e., 1.0.0.127.unet.rbl.ircbl.org)
set cfg(ircbl:net) "undernet";                      # -- ircbl.org network (undernet|dalnet|quakenet) for entry removals
set cfg(ircbl:key) "BcGVHjkRF754656d7Hh9vjGTrE";    # -- ircbl.org key
set cfg(ircbl:type) 14;                             # -- ircbl.org addition type
set cfg(ircbl:noselfrem) 1;                         # -- ircbl.org use noselfrem_until_ts with gline expiry in API adds? (0|1)
set cfg(ircbl:add:comment) "IRC drone detected";    # -- ircbl.org generic manual add comment (G-lines will use g-line message)
set cfg(ircbl:patterns) "552 553";                  # -- ircbl.org automatic add ircbl from D (space delimited)
set cfg(ircbl:url:add) "https://ircbl.org/addrbl";  # -- ircbl.org addition address
set cfg(ircbl:url:del) "https://ircbl.org/delrbl";  # -- ircbl.org removal address

# -- DNSBL auto pattern whitelist
# -- do not auto insert any IPs matching in this list
array set whitelist {
    10.0.0.1    {example whitelist reason}
    10.0.0.2    {another whitelist reason}
}


# ---- dronestats configuration

# -- DDD Network Service (dronescan.undernet.org)
set cfg(ddd:nick) "D";                          # -- DDD service nick
set cfg(ddd:uhost) "dronescan@undernet.org";    # -- DDD service userhost
set cfg(ddd:chan) "#ddd.console";               # -- DDD regex console chan
set cfg(rbl:chan) "#ddd.rbl";                   # -- DDD dnsbl console chan

# -- noadd? (don't actually submit to ircbl)
# -- used for testing
set cfg(noexec) 0


# ------------------------------------------------------------------------------------------------
# end of config
# ------------------------------------------------------------------------------------------------

# -- prerequisites (Tcllibc)
package require Tcl 8.6
#package require json
package require http 2
package require tls 1.7

# -- startup
bind pubm -|- * { nm::coroexec pubm:ddd }
bind pub -|- .stats { nm::coroexec pub:stats }
bind pub -|- .add { nm::coroexec pub:add }
bind pub -|- .view { nm::coroexec pub:view }
bind pub -|- .rem { nm::coroexec pub:rem }
bind evnt - init-server { nm::coroexec init:server }
bind raw - "NOTICE" { nm::coroexec raw:snotice }


# ---- statistical counters (in memory)
#       - total glines seen
#       - processed added glines
#       - processed euworld gline
#       - processed removed glines
#       - seen D regex glines
#       - seen E regex glines
#       - glines not matched to patterns
#       - removed from ircbl
#       - added to ircbl
foreach t {gline addgline ewgline remgline dddgline floodgline nomatch remrbl addrbl} {
    if {![info exists nm(count,$t)]} { set nm(count,$t) 0 }
}


# ---- procedures

# -- server connection
proc init:server {type} {
    global botnick
    variable cfg
    #putquick "OPER $cfg(oper:user) $cfg(oper:pass)"
    putquick "MODE $botnick +s 47103"
    putquick "AWAY :inside the matrix."
    return 0;
}

proc pub:view {nick uhost hand chan text} {
    variable nm
    variable cfg
    set start [clock clicks]
    set ip [lindex $text 0]
    if {$ip eq ""} {
        putquick "PRIVMSG $chan :usage: .view <ip>"
        return;
    }

    if {![isValidIP $ip]} {
        # -- not valid
        # -- TODO: DNS resolver if host given
        debug 0 "pub:add: not processing addition (invalid IP): $ip"
        putquick "PRIVMSG $chan :error: $ip is not a valid IP address."
        return;
    }
    
    set response [ircbl:lookup $ip]
    set time [runtime $start]
    if {$response eq "error"} { set response "\002not\002 found." } else { set response "\002match:\002 $response" }
    putquick "PRIVMSG $chan :$response ($time)"
    return;
}


proc pub:add {nick uhost hand chan text} {
    variable nm
    variable cfg
    set start [clock clicks]
    set ip [lindex $text 0]
    if {$ip eq ""} {
        putquick "PRIVMSG $chan :usage: .add <ip>"
        return;
    }

    if {![isValidIP $ip]} {
        # -- not valid
        # -- TODO: DNS resolver if host given
        debug 0 "pub:add: not processing addition (invalid IP): $ip"
        putquick "PRIVMSG $chan :error: $ip is not a valid IP address."
        return 0;
    }

    set response [ircbl:lookup $ip]
    if {$response ne "error"} {
        # -- ircbl entry already exists
        set time [runtime $start]
        debug 0 "pub:add: ircbl entry already exists (ip: $ip -- time: $time)"
        putquick "PRIVMSG $chan :ircbl entry already exists (ip: $ip -- time: $time)"
        return;        
    }

    # -- entry not found; add it
    lassign [ircbl:query add $ip $cfg(ircbl:type)] succeed response

    set time [runtime $start]
    if {$succeed} {
        putquick "PRIVMSG $chan :done. ($time)"        
    } else {
        putquick "PRIVMSG $chan :\002error:\002 $response ($time)"
    }
    return;
}


proc pub:rem {nick uhost hand chan text} {
    variable nm
    variable cfg
    set start [clock clicks]
    set ip [lindex $text 0]
    if {$ip eq ""} {
        putquick "PRIVMSG $chan :usage: .rem <ip>"
        return;
    }
    
    if {![isValidIP $ip]} {
        # -- not valid
        # -- TODO: DNS resolver if host given; 
        debug 0 "pub:add: not processing addition (invalid IP): $ip"
        putquick "PRIVMSG $chan :error: $ip is not a valid IP address."
        return 0;
    }

    set response [ircbl:lookup $ip]
    if {$response eq "error"} {
        # -- ircbl entry does not exist
        set time [runtime $start]
        debug 0 "pub:add: ircbl entry not found (ip: $ip -- time: $time)"
        putquick "PRIVMSG $chan :ircbl entry not found (ip: $ip -- time: $time)"
        return;        
    }

    # -- entry found; remove it
    lassign [ircbl:query rem $ip $cfg(ircbl:type)] succeed response

    set time [runtime $start]
    if {$succeed} {
        putquick "PRIVMSG $chan :done. ($time)"        
    } else {
        putquick "PRIVMSG $chan :error: $response ($time)"
    }
    return;
}


# -- stats recall
proc pub:stats {nick uhost hand chan text} {
    global uptime
    variable nm
    variable cfg

    if {$chan ne $cfg(chan)} { return; };  # -- not sent to command chan
    set utime [expr [unixtime] - $uptime]; # -- bot uptime in seconds
    
    # -- percentages
    if {$nm(count,addgline) ne 0} { set pc(add) "[format %.2f [expr $nm(count,addgline).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(add) "0%" }
    if {$nm(count,addrbl) ne 0} { set pc(addrbl) "[format %.2f [expr $nm(count,addrbl).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(addrbl) "0%" }
    if {$nm(count,remgline) ne 0} { set pc(rem) "[format %.2f [expr $nm(count,remgline).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(rem) "0%" }
    if {$nm(count,nomatch) ne 0} { set pc(nomatch) "[format %.2f [expr $nm(count,nomatch).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(nomatch) "0%" }
    if {$nm(count,dddgline) ne 0} { set pc(ddd) "[format %.2f [expr $nm(count,dddgline).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(ddd) "0%" }
    if {$nm(count,floodgline) ne 0} { set pc(flood) "[format %.2f [expr $nm(count,floodgline).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(flood) "0%" }
    if {$nm(count,ewgline) ne 0} { set pc(euworld) "[format %.2f [expr $nm(count,ewgline).00 / $nm(count,gline).00 * 100.00]]%" } else { set pc(euworld) "0%" }
    
    # -- per hour
    set hours [expr $utime / 60.00 / 60.00]
    if {$hours ne 0} { set ph(gline) "[format %.2f [expr $nm(count,gline).00 / $hours]] p/hr" } else { set ph(gline) "0 p/hr" }
    if {$hours ne 0} { set ph(add) "[format %.2f [expr $nm(count,addgline).00 / $hours]] p/hr" } else { set ph(add) "0 p/hr" }
    if {$hours ne 0} { set ph(addrbl) "[format %.2f [expr $nm(count,addrbl).00 / $hours]] p/hr" } else { set ph(addrbl) "0 p/hr" }
    if {$hours ne 0} { set ph(rem) "[format %.2f [expr $nm(count,remgline).00 / $hours]] p/hr" } else { set ph(rem) "0 p/hr" }
    if {$hours ne 0} { set ph(nomatch) "[format %.2f [expr $nm(count,nomatch).00 / $hours]] p/hr" } else { set ph(nomatch) "0 p/hr" }
    if {$hours ne 0} { set ph(ddd) "[format %.2f [expr $nm(count,dddgline).00 / $hours]] p/hr" } else { set ph(ddd) "0 p/hr" }
    if {$hours ne 0} { set ph(flood) "[format %.2f [expr $nm(count,floodgline).00 / $hours]] p/hr" } else { set ph(flood) "0 p/hr" }
    if {$hours ne 0} { set ph(euworld) "[format %.2f [expr $nm(count,ewgline).00 / $hours]] p/hr" } else { set ph(euworld) "0 p/hr" }
    
    putquick "PRIVMSG $chan :\002\[\002stats\002\]\002 uptime: [timeago $uptime] \002--\002 total glines: $nm(count,gline) (100% & $ph(gline)) \002--\002 total added: $nm(count,addrbl) ($pc(addrbl) & $ph(addrbl)) \002--\002 total removed: $nm(count,remgline) ($pc(rem) & $ph(rem)) "
    putquick "PRIVMSG $chan :\002\[\002stats\002\]\002 total D: $nm(count,dddgline) ($pc(ddd) & $ph(ddd)) \002--\002 total E: $nm(count,floodgline) ($pc(flood) & $ph(flood)) \002--\002 total euworld: $nm(count,ewgline) ($pc(euworld) & $ph(euworld)) \002--\002 total no match: $nm(count,nomatch) ($pc(nomatch) & $ph(nomatch))"
    return;
}

# -- beware: MUST use 'return 0;' when exiting this raw procedure
proc raw:snotice {nick junk text} {
    global server
    variable nm
    variable cfg

    set start [clock clicks]
 
    # -- ignore if not my server
    set svr [lindex [split $server :] 0]
    if {$nick ne $svr} { return 0; }
 
    set isircbl $cfg(ircbl)
    if {$cfg(noexec)} { set addrbl 0 } else { set addrbl 1 }; # -- debug disablement option
    set remrbl 0; # -- manually disable removals
    set isgline 0
    set isremgline 0

    # -- new gline
    # Notice -- uworld.eu.undernet.org adding global GLINE for *@116.18.58.100, expiring at 1271994745: [3] compromised host
    # -- D gline
    # Notice -- dronescan.undernet.org adding global GLINE for *@178.217.184.147, expiring at 1337404687: AUTO [1] DNSBL listed. TORs are forbidden on this network. Your IP is 178.217.184.147
    # -- removal
    # Notice -- uworld.eu.undernet.org modifying global GLINE for *@95.154.57.116: globally deactivating G-line
    
    # -- only proceed if valid euworld gline/remgline
    if {[regexp -- {Notice\s--\s([^\s]+)\sadding\sglobal\sGLINE\sfor\s([^,]+),\sexpiring\sat\s([^:]+):\s(?:AUTO\s)?\[(\d+)\]\s(.+)} $text -> srcserver mask expire hits reason]} { set isgline 1; } \
    elseif {[regexp -- {Notice\s--\s([^\s]+)\smodifying\sglobal\sGLINE\sfor\s([^,]+):\s(globally\sdeactivating\sG-line)} $text -> srcserver mask reason]} { set isremgline 1; } \
    else { 
        debug 3 "raw:snotice: not valid snotice: $text"
        return 0; 
    }

    if {$isgline} { 
        debug 3 "raw:snotice: gline found: server: $srcserver mask: $mask expire: $expire hits: $hits reason: $reason"; 
        set user "euworld"; set nuh "euworld!euworld@undernet.org";
        incr nm(count,gline)
    }

    if {$isremgline} { 
        debug 3 "raw:snotice: gline removal found: server: $srcserver mask: $mask reason: $reason"; 
        set user "euworld"; set nuh "euworld!euworld@undernet.org";
        incr nm(count,remgline) 
    }
 
    # -- tidy weird \} char on end of reason
    set reason [string trimright $reason "\}"]
 
    # -- if new G-line, ensure reason is a match
    if {$isgline} {
        set noselfrem_until_ts $expire
        if {[regexp -nocase $cfg(gline:regex) $reason]} {
            # -- euworld.* manual G-Line
            set comment "euworld G-Line: $reason"
            set user "euworld"; set nuh "euworld!euworld@undernet.org"; set count "ewgline"
            incr nm(count,ewgline)
        } elseif {[regexp -nocase $cfg(gline:ddd) $reason]} {
            # -- dronescan.* D regex G-Line
            set comment "D G-Line: $reason"
            set user "dronescan"; set nuh "D!dronescan@undernet.org"; set count "dddgline"
            incr nm(count,dddgline)
            return 0; # -- manually disable these RBL additions
        } elseif {[regexp -nocase $cfg(gline:flood) $reason]} {
            # -- dronescan.* E flood G-Line
            set comment "E G-LineG: $reason"
            set user "dronescan"; set nuh "E!dronescan@undernet.org"; set count "floodgline"
            incr nm(count,floodgline)
            return 0; # -- manually disable these RBL additions
        } else {
            # -- no G-Line reason match
            debug 3 "raw:snotice: no gline reason match: mask: $mask reason: $reason"
            incr nm(count,nomatch)
            return 0;         
        }
    }
    
    set ip [lindex [split $mask @] 1]
    
    # -- ensure it actually is a single IPv4 address (numeric)
    if {![isValidIP $ip]} {
        # -- TODO: support
        debug 1 "raw:snotice: not processing auto gline nm entry (\002invalid singule IP address\002): $ip"
        return 0;
    }

    if {$isgline} {
        # -- check if entry already exists in ircbl
        if {$isircbl} {
            # -- ircbl additions enabled
            set response [ircbl:lookup $ip]
            
            if {$response ne "error"} {
                debug 0 "\002raw:snotice: ircbl entry already exists (ip: $ip)";
                return 0;
            }
            # -- entry not found; add it
            debug 0 "\002raw:snotice: ircbl entry does not exist... adding it! (ip: $ip)";
            exec echo "[unixtime] gline $ip" >> "[pwd]/tmp/addrbl.log"; # -- log glines to file
            if {$addrbl} {
                lassign [ircbl:query add $ip $cfg(ircbl:type) $comment $noselfrem_until_ts] succeed response
                set time [runtime $start]
                incr nm(count,$count)
                if {$succeed} {
                    debug 0 "\002raw:snotice: G-Lined IP \002successfully added\002 to ircbl (ip: $ip -- type: $cfg(ircbl:type) -- time: $time)";
                    incr nm(count,addrbl)
                    incr nm(count,addgline)
                } else {
                    debug 0 "\002raw:snotice: G-Lined IP \002failed\002 to add to ircbl (ip: $ip -- type: $cfg(ircbl:type) -- time: $time)";
                }
            } else { debug 0 "\002raw:snotice: G-Lined IP \002not added\002 to ircbl due to cfg(noexec) (ip: $ip)"; }
        }
    } elseif {$isremgline} {        
        # -- remove from ircbl?
        if {$isircbl} {
            set response [ircbl:lookup $ip]
            if {$response eq "error"} {
                # -- ircbl entry does not exist
                set time [runtime $start]
                debug 3 "raw:snotice: removed G-Line IP not found in ircbl... halting (ip: $ip -- time: $time)"
                return 0;
            }
            exec echo "[unixtime] $count $ip" >> "[pwd]/tmp/remrbl.log"; # -- log ddd additions to file
            if {$remrbl} {
                # -- entry found; remove it
                lassign [ircbl:query rem $ip $cfg(ircbl:type)] succeed response
                set time [runtime $start]
                incr nm(count,remgline)
                if {$succeed} {
                    debug 0 "\002raw:snotice: G-Lined IP \002successfully removed\002 from ircbl (ip: $ip -- time: $time)";
                    incr nm(count,remrbl)     
                } else {
                    debug 0 "\002raw:snotice: G-Lined IP \002failed to remove\002 from ircbl (ip: $ip -- time: $time)";
                }
            } else { debug 0 "\002raw:snotice: G-Lined IP \002not removed\002 from ircbl due to coded disablement (ip: $ip)"; }
        }
    }
    # -- must use 'return 0' because of RAW bind
    return 0
}


putlog "\[@\] automatic dnsbl gline insertion procedures loaded."


# -- public parser
# -- reads data from D console chan
proc pubm:ddd {nick uhost hand chan text} {
    variable nm
    variable cfg
    variable whitelist
    set start [clock clicks]

    if {$nick ne $cfg(ddd:nick) || $uhost ne $cfg(ddd:uhost) || $chan ne $cfg(ddd:chan)} { return; }

    set timestamp [clock seconds]
    lassign $text pattern server action numeric nick uhost ip 

    # - remove [ and ] from pattern (and 'P')
    set pattern [lindex [split $pattern "\["] 1]
    set pattern [lindex [split $pattern "\]"] 0]

    # -- remove ( and ) from server
    set server [lindex [split $server "\("] 1]
    set server [lindex [split $server "\)"] 0]

    set ident [lindex [split $uhost "@"] 0]
    set host [lindex [split $uhost "@"] 1]
    set rname [lrange $text 8 end]
    
    set error ""
    
    # -- add automatic ircbl entry?
    if $cfg(ircbl) {
        if {$pattern in $cfg(ircbl:patterns)} {
            # -- check for whitelist
            if {[info exists whitelist($ip)]} {
                # -- whitelist found
                debug 0 "pubm:ddd: whitelisted $ip found, NOT added to ircbl (D pattern: $pattern -- rbl type: $cfg(ircbl:type) -- $nick!$ident@$host -- exception: [lindex $whitelist($ip) 0] -- comment: [lindex $whitelist($ip) 1])"
                return;
            }
            # -- no whitelist entry, submit to ircbl (unless noexec is enabled)
            exec echo "[unixtime] ddd $ip" >> "[pwd]/tmp/addrbl.log"; # -- log ddd additions to file
            if {!$nm(noexec)} {
                lassign [ircbl:query rem $ip $cfg(ircbl:type)] succeed response
                set time [runtime $start]
                if {$succeed} {
                    debug 0 "pubm:ddd: added $ip to ircbl (D pattern: $pattern rbl type: $cfg(ircbl:type) -- $nick!$userid@$host -- time: $time)"
                } else {
                    debug 0 "pubm:ddd: \002failure\002 to add $ip to ircbl (D pattern: $pattern rbl type: $cfg(ircbl:type) -- $nick!$userid@$host-- time: $time)"
                }
            }
            break;
        }
    }
    # -- end auto ircbl entry
}

putlog "\[@\] automatic DDD regex insertion procedures loaded."


# ------------------------------------------------------------------------------------------------
# SUPPORT FUNCTIONS
# ------------------------------------------------------------------------------------------------

# -- ensure tmp directory exists 
if {![file exists tmp]} { exec mkdir tmp }

# -- debug output
proc debug {level string} {
    variable nm
    if {$level <= $nm(debug)} { putloglev $nm(debug) * $string }
}

# -- calculate runtime
proc runtime {{start ""}} {
    if {$start eq ""} { return "unknown" }; # -- start time not known
    set end [clock clicks]
    return "[expr ($end-$start)/1000/1000.0] sec"
}

# -- ensure IP is valid
proc isValidIP {ip} {
    if {[regexp -- {^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$} $ip]} { 
        # -- IPv4
        return 1 
    } elseif {[regexp -nocase {^(?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}$} [ip::normalize$ip]]} {
        # -- IPv6
        return 1;
    };
    return 0; # -- invalid IP
}

# -- reverse IP for DNSBL lookups
proc revip {ip} {
    # -- reverse the IP
    if {[regexp {^([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})$} $ip -> a b c d]} {
        # -- IPv4
       return "$d.$c.$b.$a"
    } elseif {[regexp -nocase {^(?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}$} [ip::normalize $ip]]} {
        # -- IPv6
        set expanded [string map {: ""} [ip::normalize $ip]]
        set i [string length $expanded]
           while {$i > 0} {append res "[string index $expanded [incr i -1]]." }
        set res [string trimright $res .]
        return $res
    } else {
        return; # -- not a valid IP
    }
}

# -- coroutine execution
# -- we can put debug stuff here later, very generic for now
proc coroexec {args} {
    coroutine coro_[incr ::coroidx] {*}$args
}

# -- timeago proc
proc timeago {lasttime} {
  set utime [clock seconds]
  if {$lasttime >= $utime} {
   set totalyear [expr $lasttime - $utime]
  } {
   set totalyear [expr $utime - $lasttime]
  }

  if {$totalyear >= 31536000} {
    set yearsfull [expr $totalyear/31536000]
    set years [expr int($yearsfull)]
    set yearssub [expr 31536000*$years]
    set totalday [expr $totalyear - $yearssub]
  }

  if {$totalyear < 31536000} {
    set totalday $totalyear
    set years 0
  }

  if {$totalday >= 86400} {
    set daysfull [expr $totalday/86400]
    set days [expr int($daysfull)]
    set dayssub [expr 86400*$days]
    set totalhour [expr $totalday - $dayssub]
  }

  if {$totalday < 86400} {
    set totalhour $totalday
    set days 0
  }

  if {$totalhour >= 3600} {
    set hoursfull [expr $totalhour/3600]
    set hours [expr int($hoursfull)]
    set hourssub [expr 3600*$hours]
    set totalmin [expr $totalhour - $hourssub]
    if {$hours < 10} { set hours "0$hours"; }
  }
  if {$totalhour < 3600} {
    set totalmin $totalhour
    set hours 00
  }
  if {$totalmin >= 60} {
    set minsfull [expr $totalmin/60]
    set mins [expr int($minsfull)]
    set minssub [expr 60*$mins]
    set secs [expr $totalmin - $minssub]
    if {$mins < 10} { set mins "0$mins"; }
    if {$secs < 10} { set secs "0$secs"; }
  }
  if {$totalmin < 60} {
    set minsfull [expr $totalmin/60]
    set mins [expr int($minsfull)]
    set minssub [expr 60*$mins]
    set secs [expr $totalmin - $minssub]
    if {$mins < 10} { set mins "0$mins"; }
    if {$secs < 10} { set secs "0$secs"; }
  }
  if {$totalmin < 60} {
    set secs $totalmin
    set mins 00
    if {$secs < 10} { set secs "0$secs"; }
  }
  if {($days > 1) || ($days eq 0)} { set output "$days days, $hours:$mins:$secs"; }
  if {$days eq 1} { set output "$days day, $hours:$mins:$secs"; }
  #if {$days eq 0} { set output "$hours:$mins:$secs"; }
  return $output;
}


# ------------------------------------------------------------------------------------------------
# IRCBL
# ------------------------------------------------------------------------------------------------

# -- prerequisites (Tcllibc)
package require Tcl 8.6
#package require json
package require http 2
package require tls 1.7

proc ircbl:lookup {ip} {
    variable cfg
    set rip [revip $ip]; # -- reverse IP
    set lookup "$rip.$cfg(ircbl:rbl)"
    set response [dns:lookup $lookup]
    debug 0 "ircbl:lookup: response: $response ($lookup)"
    return $response
    #if {$response eq "error"} { return "0 error" } else { return "1 $response" }; # -- 1 indicates a match
}

# -- generic query
proc ircbl:query {cmd ip {type ""} {comment ""} {noselfrem_ts ""}} {
    variable cfg
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]
    
    set ip [join $ip "\n"]
    if {$type eq ""} { set type $cfg(ircbl:type) }; # -- add default entry type
    
    if {$cmd eq "add"} {
        # -- adding an entry
        if {$comment eq ""} { set comment $cfg(ircbl:add:comment) }
        set query [http::formatQuery key $cfg(ircbl:key) ip $ip bl_type $cfg(ircbl:type) \ 
            comment $comment noselfrem_until_ts $noselfrem_ts]
    } elseif {$cmd eq "del"} {
        set query [http::formatQuery key $cfg(ircbl:key) ip $ip bl_type $cfg(ircbl:type) \ 
            network $cfg(ircbl:net) noselfrem_until_ts $noselfrem_ts]
    } else {
        # -- invalid cmd
        debug 0 "\002ircbl:query:\002 error: no such command: $cmd"
        return "0 [list "no such command"]";
    }

    #catch {set tok [http::geturl $cfg(ircbl:url:$cmd) -query $query -keepalive 1]} error
    coroexec http::geturl $cfg(ircbl:url:$cmd) -query $query -keepalive 1 -timeout 3000 -command [info coroutine]
    set tok [yield]

    set error ""; # -- TODO: fix generic error handler
    #debug 0 "ircbl: checking for errors...(error: $error)"
    #if {[string match -nocase "*couldn't open socket*" $error]} {
    #    debug 0 "\002ircbl:query:\002 could not open socket to: $cfg(ircbl:url:$cmd) *]"
    #    http::cleanup $tok
    #    return "0 [list "could not open socket"]";
    #} 

    set ncode [http::ncode $tok]
    set status [http::status $tok]

    if {$status eq "timeout"} { 
        debug 0 "\002ircbl:query:\002 connection to $cfg(ircbl:url:$cmd *) has timed out."
        http::cleanup $tok
        return "0 [list "connect timeout"]";
    } elseif {$status eq "error"} {
        debug 0 "\002ircbl:query:\002 connection to $cfg(ircbl:url:$cmd *) has error."
        http::cleanup $tok
        return "0 [list "connect error"]";
    }
    
    set token $tok
    set data [http::data $tok]
    set success 0

    regsub -all { <br>} $data {} data; # -- strip ' <br>'

    #debug 4 "\002ircbl:query:\002 type: $type -- data: $data"
        
    if {$cmd eq "add"} {
        if {[string match -nocase "Success: * ips. bl_type: $type *" $data]} {
            # -- successful add!
            set response "done."
            debug 0 "\002ircbl:query:\002 add success: ip=$ip, bl_type=$type, comment='$comment'"
            set success 1
        } elseif {[string match -nocase "*error: ip already covered by an existing RBL listing*" $data]} {
            # -- failed add!
            set response "\002(\002error\002)\002 add failure (\002entry already exists\002)."
            debug 0 "\002ircbl:query:\002 add failure (already exists): ip=$ip, bl_type=$type, comment='$comment'"            
        } 
    
    } elseif {$cmd eq "del"} {
        if {[string match -nocase "Deleted * entries and deactivated * entries*" $data]} {
            # -- successful del!
            set response "done."
            debug 0 "\002ircbl:query:\002 del success: ip=$ip, bl_type=$type, comment='$comment'"
            set success 1
        } elseif {[string match -nocase "*: entry was added by someone else: *" $data]} {
            # -- failed del!
            set response "\002(\002error\002)\002 del failure (\002entry added by another user\002)."
            debug 0 "\002ircbl:query:\002 del failure (added by other user): ip=$ip, bl_type=$type"
        } elseif {[string match -nocase "*error: ip not listed: *" $data]} {
            # -- failed del!
            set response "\002(\002error\002)\002 del failure (\002not found\002)."
            debug 0 "\002ircbl:query:\002 del failure (IP not listed): ip=$ip, bl_type=$type"
        } 
    }
    http::cleanup $tok
    
    if {![info exists response]} {
        set response "\002(\002info\002)\002 unknown response: $data"
        debug 0 "\002(\002info\002)\002 unknown response: $data "
    }
    
    if {$success} { return "1 [list $response]" } else { return "0 [list $response]" }
}

putlog "\[@\] IRCBL support functions loaded."

# ------------------------------------------------------------------------------------------------
# DNS RESOLVER
# ------------------------------------------------------------------------------------------------
proc dns:lookup {host {type ""}} {
    set start [clock clicks]
    
    if {[string toupper $type] eq ""} { set type "A" }; # -- force uppercase

    # -- perform lookup
    debug 3 "arm:dns:lookup: lookup: $host -type $type"
    # -- force 1sec timeout and Cloudflare DNS
    # -- TODO: make timeout and NS configurable
    set tok [::dns::resolve $host -type $type -timeout 1000 -server 1.1.1.1 -command [info coroutine]]
    yield

    # -- get status (ok, error, timeout, eof)
    set status [::dns::status $tok]
    set error [::dns::error $tok]
    set iserror 0

    debug 3 "dns:lookup: yielded! tok: $tok -- status: $status -- error: $error"
    
    if {$status eq "error"} {
        set what "failure"; set iserror 1
    } elseif {$status eq "eof"} {
        set what "eof"; set iserror 1
    } elseif {$status eq "timeout"} {
        set what "timeout"; set iserror 1
    }

    debug 3 "dns:lookup: iserror: $iserror"

    if {$iserror} {
        # -- return error
        debug 3 "dns:lookup: dns resolution $what for $host took [runtime $start]"
        ::dns::cleanup $tok
        return "error"
    }

    # -- fetch entire result
    set result [join [::dns::result $tok]]
    
    #  name google.com type TXT class IN ttl 2779 rdlength 82 rdata {v=spf1 include:_netblocks.google.com ip4:216.73.93.70/31 ip4:216.73.93.72/31 ~all}
    set typ [lindex $result 3]
    set class [lindex $result 5]
    set ttl [lindex $result 7]
    set resolve [lindex $result 11]

    # -- cleanup token
    ::dns::cleanup $tok
    
    #debug 3 "arm:dns:lookup: result: $result"
    #debug 3 "arm:dns:lookup: resolve: $resolve"
    debug 3 "arm:dns:lookup: dns resolution success for $host took [runtime $start]"
    
    if {$type eq "*"} { return $result } else { return $resolve }
}
putlog "\[@\] custom DNS resolver loaded."
# ------------------------------------------------------------------------------------------------

putlog "\[@\] netmon $nm(version) loaded."

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------