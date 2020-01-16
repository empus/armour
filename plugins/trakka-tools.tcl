bind raw - 354 trakka:raw:init:who
bind raw - 315 trakka:raw:init:endofwho

proc trakka:init:load {} {
	global trakka
	# -- hold a var for the endofwho
	set trakka(initload) 1
	
	putquick "WHO $trakka(chan) %nuhiart,106"
}

proc trakka:raw:init:who {server cmd arg} {
	global trakka botnick
	
	set arg [split $arg]
  	lassign $arg mynick query ident ip host nick xuser rname
  	
  	trakka:debug 6 "trakka:raw:init:who: mynick: $mynick query: $query ident: $ident ip: $ip host: $host nick: $nick xuser: $xuser rname: $rname"
  	
  	# -- safety nets
	if {$query != "106"} { return; }
	if {$nick == $botnick} { return; }

	# set rname [string trimleft $rname ":"] 
	# set rname [join $rname]
	set uhost "$ident@$host"
	# set nuh "$nick!$uhost"
	# set chan $trakka(chan)
	
	# -- add trakka's
	if {![info exists trakka(nick,$nick)]} { 
		set trakka(nick,$nick) 1
		incr trakka(count)
		incr trakka(ncount)
		trakka:debug 5 "trakka:raw:init:who: initial trakka add: trakka(nick,$nick) (newscore: $trakka(nick,$nick))"
	}
	if {![info exists trakka(uhost,$uhost)]} {
		set trakka(uhost,$uhost) 1
		incr trakka(count)
		incr trakka(uhcount)
		trakka:debug 5 "trakka:raw:init:who: initial trakka add: trakka(uhost,$uhost) (newscore: $trakka(uhost,$uhost))"
	}
	if {$xuser != 0 && ![info exists trakka(xuser,xuser)]} {
		set trakka(xuser,$xuser) 1
		incr trakka(count)
		incr trakka(xcount)
		trakka:debug 5 "trakka:raw:init:who: initial trakka add: trakka(xuser,$xuser) (newscore: $trakka(xuser,$xuser))"
	}

}

proc trakka:raw:init:endofwho {server cmd arg} {
	global trakka
	set arg [split $arg]
	lassign $arg mynick mask
	if {$mask != $trakka(chan) || ![info exists trakka(initload)]} { return; }
  
  	# -- prime the counters if they don't already exist
	if {![info exists trakka(count)]} { set trakka(count) 0 }
  	if {![info exists trakka(ncount)]} { set trakka(ncount) 0 }
  	if {![info exists trakka(uhcount)]} { set trakka(uhcount) 0 }
  	if {![info exists trakka(xcount)]} { set trakka(xcount) 0 }
  	
	trakka:debug 0 "trakka:raw:init:endofwho: \002added $trakka(count) total trakka's in initial load\002 (nick: $trakka(ncount) uhost: $trakka(uhcount) xuser: $trakka(xcount))"
	unset trakka(initload)
	unset trakka(count)
        unset trakka(ncount)
        unset trakka(uhcount)
        unset trakka(xcount)
}

# -- increase or decrease all score values
proc trakka:incr {incr} {
	global trakka
	set count 0; set ncount 0; set uhcount 0; set xcount 0; set deleted 0;
	
	foreach entry [array names trakka] {
		set line [split $entry ,]
		lassign $line type value
		if {$type != "nick" && $type != "uhost" && $type != "xuser"} { continue; }
		incr count
		set score $trakka($type,$value)
		set oldscore $score
		# -- apply increment
		incr score $incr
		if {$score <= 0} {
			# -- delete trakka
			unset trakka($type,$value)
			incr deleted
			trakka:debug 0 "trakka:incr deleted trakka array trakka($type,$value) (score: $oldscore -> $score)"
		} else {
		
			switch -- $type {
				nick	{ incr ncount }
				uhost	{ incr uhcount }
				xuser	{ incr xcount }
		}
		trakka:debug 0 "trakka:incr incremented trakka array trakka($type,$value) by a value of: $incr (score: $oldscore -> $score)" }
	}
	
	trakka:debug 0 "trakka:incr: \changed $count total trakka's\002 (nick: $ncount uhost: $uhcount xuser: $xcount -- deleted $deleted)"

}

putlog "\[@\] Armour: plugin loaded: trakka tools (init, incr)"