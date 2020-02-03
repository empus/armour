# -- channel regular tracking system
#
# issues warning when someone unrecognised joins the channel
#
# Empus <empus@undernet.org>
#
# inspired by the douchebags that troll in #phat of Undernet
#
# how to track?
#
# we maintain an array of users inside the channel (adding and deleting as people join, part, kick or quit)
#
# format: trakka(nick,<nick>) <score>
# format: trakka(uhost,<user@host>) <score>
#
# format: trakka(xuser,<user>) <score>
#
# for a quick way to give initial scores to everyone already in the channel,
# load "trakka-tools.tcl" and do ".tcl trakka:init:load" in partyline
#

# -- this code gets loaded by the trakka.conf file, not directly
# -- each bot can use its own trakka.conf (renamed as needed)


# ---- the code!

# -- integration mode handling
if {$trakka(mode) == 1} {
	# -- standalone, set realname
	set realname $rname
	bind join - * trakka:raw:join
	bind pub - .ack trakka:bind:pub:ack
	proc trakka:bind:pub:ack {n uh h c a} {
		trakka:cmd:ack pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind just incase we changed modes during operation
	if {[lsearch [info commands] "trakka:bind:pub:ack"] != "-1"} {
		unbind pub - .ack trakka:bind:pub:ack
	}
	# -- load commands
	arm:loadcmds
}

# ---- binds
bind part - * trakka:raw:part
bind sign - * trakka:raw:signoff
bind nick - * trakka:raw:nick
bind kick - * trakka:raw:kick
bind raw - 354 trakka:raw:who
bind raw - 315 trakka:raw:endofwho
bind mode - "* +o" trakka:mode:addo
bind mode - "* +v" trakka:mode:addv

# -- netsplit handling
bind splt - * trakka:raw:split
bind rejn - * trakka:raw:rejn

# -- nickname channel join
proc trakka:raw:join {nick uhost hand chan} {
	global trakka botnick
	
	if {$nick == $botnick} { return; }
	if {$trakka(mode) == 0} { return; }
	
	trakka:debug 6 "takka:raw:join: started: nick: $nick uhost: $uhost chan: $chan"
	
	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]
		
	if {$chan != $trakka(chan)} { return; }
			
	# -- nickname
	if {[info exists trakka(nick,$nick)]} {
		# -- trakka nick based score
		trakka:debug 2 "trakka:raw:join: recognised nick trakka for: $nick!$uhost (score: $trakka(nick,$nick))"
	} else { set trakka(nick,$nick) 0 }
	
	# -- xuser
	set xuser ""
	if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
		if {[info exists trakka(xuser,$xuser)]} {
			# -- trakka xuser based score
			trakka:debug 2 "trakka:raw:join: recognised xuser trakka for: $nick!$uhost (score: $trakka(xuser,$xuser))"
		} else { set trakka(xuser,$xuser) 0; set trakka(uhost,$uhost) 0; }
	} else {
		# -- uhost (only do this if not umode +x)
		if {[info exists trakka(uhost,$uhost)]} {
			# -- trakka uhost based score
			trakka:debug 2 "trakka:raw:join: recognised uhost trakka for: $nick!$uhost (score: $trakka(uhost,$uhost))"
		} else { set trakka(uhost,$uhost) 0 }
	}
	
	# -- now, let's work out if we know them
	set nscore $trakka(nick,$nick)
	if {[info exists trakka(uhost,$uhost)]} { set uhscore $trakka(uhost,$uhost) } else { set uhscore 0 }
	if {$xuser != ""} { set xscore $trakka(xuser,$xuser) } else { set xscore 0 }
	set score [expr $nscore + $uhscore + $xscore]
	trakka:debug 1 "trakka:raw:join: total score for $nick!$uhost is: $score"
	
	# - if score is 0, we've never seen them
	if {$score == 0 && [onchan $nick $chan] && ![isop $nick $chan] && ![isvoice $nick $chan]} {
		# -- we've never seen this guy, send alert
		if {$xuser != ""} {
			trakka:debug 0 "trakka:raw:join: \002trakkalert\002: just so you know folks, i don't \002currently\002 trust $nick!$uhost: (xuser: $xuser)"
			if {$trakka(alertchan) != ""} { putnotc $trakka(alertchan) "\002trakkalert\002: just so you know folks, i don't \002currently\002 trust: $nick!$uhost (xuser: $xuser)" }
		} else {
			trakka:debug 0 "trakka:raw:join: \002trakkalert\002: just so you know folks, i don't \002currently\002 trust: $nick!$uhost"
			if {$trakka(alertchan) != ""} { putnotc $trakka(alertchan) "\002trakkalert\002: just so you know folks, i don't \002currently\002 trust: $nick!$uhost" }
		}
	}
	# -- increase trakka scores
	utimer $trakka(init) "trakka:score:incr [split $nick] $uhost $xuser"

}

# -- nickname channel join, from integrated script
proc trakka:int:join {nick uhost hand chan {white 0}} {
	global trakka botnick

	set nick [split $nick]
	
	if {$nick == $botnick} { return; }
	if {$trakka(mode) == 0} { return; }
	
	trakka:debug 6 "takka:int:join: started: nick: $nick uhost: $uhost chan: $chan"
	
	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]
		
	if {$chan != $trakka(chan)} { return; }
		
	# -- ensure they have at least 1 point if user is whitelisted
	if {$white} {		
		# -- nickname
		incr trakka(nick,$nick)
		trakka:debug 2 "trakka:int:join: increased nick trakka for: $nick!$uhost (score: $trakka(nick,$nick))"
	
		# -- xuser
		set xuser ""
		if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
			incr trakka(xuser,$xuser)
			trakka:debug 2 "trakka:int:join: increased xuser trakka for: $nick!$uhost (score: $trakka(xuser,$xuser))"
		} else {
			# -- uhost (only do this if not umode +x)
			incr trakka(uhost,$uhost)
			trakka:debug 2 "trakka:int:join: increased uhost trakka for: $nick!$uhost (score: $trakka(uhost,$uhost))"
		}
	}
	
	# -- now, let's sent them to the actual join processing procedure
	# - use a delay to allow for /whois blacklists, X automodes etc
	if {$hand == ""} { set hand 0 }
	utimer $trakka(delay) "trakka:raw:join $nick $uhost $hand $chan"

}

# -- ack
# - acknowledge a client, bump a point
proc trakka:cmd:ack {0 1 2 3 {4 ""}  {5 ""}} {
	global arm trakka
	set type $0

	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {$tell(mode) == 2} {
			if {![userdb:isValidchan $chan]} { return; }
			if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
		} else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick;
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $email(chan) }
		set source "$nick!$uh"; set stype "msg"; set starget $nick;
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; 
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $email(chan) }
		set source "$hand/$idx"; set stype "dcc"; set starget $idx;
	}
	
	set cmd "ack"
	
	# -- check for integration mode
	if {$trakka(mode) == 2} {
		# -- ensure user has required access for command
		if {![userdb:isAllowed $nick $cmd $type]} { return; }
		set user [userdb:uline:get user nick $nick]
		set level [userdb:uline:get level user $user]
	} else {
	  	# -- no Armour, no access level (standalone)
		set level 0
		if {![isop $nick $chan] && ![isvoice $nick $chan]} { return; }
	}

	# -- end default proc template
		
	if {$trakka(mode) == 0 || $trakka(chan) != $chan} { return; }
	
	set tnick [lindex $args 0]
	if {$tnick == ""} { trakka:reply $stype $starget "usage: ack <nick>"; return; }
	
	set tuh [getchanhost $tnick $chan]
	
	# -- nickname
	incr trakka(nick,$nick)
	trakka:debug 2 "trakka:cmd:ack: $nick!$uh acknowledged $tnick -- increased nick trakka for: $tnick!$tuh (score: $trakka(nick,$tnick))"
	# -- xuser
	set xuser ""
	set thost [lindex [split $tuh @] 1]
	if {[regexp -- $trakka(cfg.xhost) $thost -> xuser]} {
		incr trakka(xuser,$xuser)
		trakka:debug 2 "trakka:cmd:ack: $nick!$uh acknowledged $tnick -- increased xuser trakka for: $tnick!$tuh (score: $trakka(xuser,$xuser))"
	} else {
		# -- uhost (only do this if not umode +x)
		incr trakka(uhost,$tuh)
		trakka:debug 2 "trakka:cmd:ack: $nick!$uh acknowledged $tnick -- increased uhost trakka for: $tnick!$tuh (score: $trakka(uhost,$tuh))"
	}
	
	trakka:reply $type $target "done."

	# -- create log entry for command use (if integrated to Armour)
	if {$trakka(mode) == 2} { arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] $source "" "" "" }
	
	return;
	
}

# -- nickname change
proc trakka:raw:nick {nick uhost handle chan newnick} {
	global trakka
	
	if {$trakka(mode) == 0} { return; }
	
	trakka:debug 5 "takka:raw:nick: started: nick: $nick uhost: $uhost chan: $chan newnick: $newnick"
	
	if {$chan != $trakka(chan)} { return; }
	
	if {[info exists trakka(nick,$nick)]} {
		# -- adding new trakka nick based array
		# - give it a score of 1, no sense in copying score over for a temporary nick
		set trakka(nick,$newnick) 1
		trakka:debug 2 "trakka:raw:nick: adding new nick trakka of $newnick -- nickchange (by $nick!$uhost)"
	}		

}

# -- nickname signoff
proc trakka:raw:signoff {nick uhost handle chan {text ""}} {
	global trakka
	
	return;

	if {$trakka(mode) == 0} { return; }
	
	trakka:debug 5 "takka:raw:signoff: started: nick: $nick uhost: $uhost chan: $chan"

	if {$chan != $trakka(chan)} { return; }	

	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]
	
	# -- nickname
	if {[info exists trakka(nick,$nick)]} {
		# -- unset trakka nick based tracking array
		unset trakka(nick,$nick)
		trakka:debug 2 "trakka:raw:signoff: removed nick trakka for $nick!$uhost -- signoff"
	}
	
	# -- xuser
	if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
		if {[info exists trakka(xuser,$xuser)]} {
			# -- unset trakka xuser based score
			unset trakka(xuser,$xuser)
			trakka:debug 2 "trakka:raw:signoff: removed xuser trakka for $xuser ($nick!$uhost) -- signoff"
		}
	} else {
	
		# -- uhost (only do this if not umode +x)
		if {[info exists trakka(uhost,$uhost)]} {
			# -- unset trakka nick based tracking array
			unset trakka(uhost,$uhost)
			trakka:debug 2 "trakka:raw:signoff: removed uhost trakka for $nick!$uhost -- signoff"
		}
	
	}
}

# -- nickname kicked from chan
proc trakka:raw:kick {nick uhost handle chan vict reason} {
	global trakka
	
	return;
	
	if {$trakka(mode) == 0} { return; }
	
	trakka:debug 5 "takka:raw:kick: started: nick: $nick uhost: $uhost chan: $chan vict: $vict reason: $reason"
		
	if {$chan != $trakka(chan)} { return; }
	
	set victhost [getchanhost $vict $chan]
	set ident [lindex [split $victhost @] 0]
	set host [lindex [split $victhost @] 1]
	
	# -- nickname
	if {[info exists trakka(nick,$vict)]} {
		# -- unset trakka nick based tracking array
		unset trakka(nick,$vict)
		trakka:debug 2 "trakka:raw:kick: removed nick trakka for $vict!$uhost -- kicked"
	}
		
	# -- xuser
	if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
		if {[info exists trakka(xuser,$xuser)]} {
			# -- unset trakka xuser based score
			unset trakka(xuser,$xuser)
			trakka:debug 2 "trakka:raw:kick: removed xuser trakka for $xuser ($vict!$uhost) -- kicked"
		}
	} else {
	
		# -- uhost (only do this if not umode +x)
		if {[info exists trakka(uhost,$uhost)]} {
			# -- unset trakka uhost based tracking array
			unset trakka(uhost,$uhost)
			trakka:debug 2 "trakka:raw:kick: removed uhost trakka for $vict!$uhost -- kicked"
		}
	
	}
}

# -- nickname channel part
proc trakka:raw:part {nick uhost handle chan {text ""}} {
	global trakka
	
	return;

	if {$trakka(mode) == 0} { return; }
	
	trakka:debug 5 "takka:raw:part: started: nick: $nick uhost: $uhost chan: $chan"
		
	if {$chan != $trakka(chan)} { return; }
	
	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]
	
	# -- nickname
	if {[info exists trakka(nick,$nick)]} {
		# -- unset trakka nick tracking array
		unset trakka(nick,$nick)
		trakka:debug 2 "trakka:raw:part: removed nick trakka for $nick!$uhost -- parted"
	}
	
	# -- xuser
	if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
		if {[info exists trakka(xuser,$xuser)]} {
			# -- unset trakka xuser based score
			unset trakka(xuser,$xuser)
			trakka:debug 2 "trakka:raw:part: removed xuser trakka for $xuser ($nick!$uhost) -- parted"
		}
	} else {
		# -- uhost (only do this if not umode +x)
		if {[info exists trakka(uhost,$uhost)]} {
			# -- unset trakka uhost based tracking array
			unset trakka(uhost,$uhost)
			trakka:debug 2 "trakka:raw:part: removed uhost trakka for $nick!$uhost -- kicked"
		}
	}
}



# -- netsplit handling
proc trakka:raw:split {nick uhost hand chan} {
	# -- not sure we need netsplit trakking.  if they were here, we trust 'em
	return;
	if {$trakka(mode) == 0} { return; }
}

# -- netsplit rejoin handling
proc trakka:raw:rejn {nick uhost hand chan} {
	# -- not sure we need netsplit trakking.  if they were here, we trust 'em
	return;
	if {$trakka(mode) == 0} { return; }
}


# -- increment trakka scores after timer
proc trakka:score:incr {nick uhost {xuser ""}} {
	global trakka
	
	if {$trakka(mode) == 0} { return; }
	
	set nick [join $nick]
	
	trakka:debug 6 "takka:score:incr started: nick: $nick uhost: $uhost xuser: $xuser"
	
	# -- only if nick is still onchan
	if {![onchan $nick $trakka(chan)]} { return; }

	incr trakka(nick,$nick)
	incr trakka(uhost,$uhost)
	if {$xuser != "" && $xuser != -1} {
	  incr trakka(xuser,$xuser)
	  trakka:debug 2 "trakka:score:incr: increased scores for $nick!$uhost (xuser: $xuser)"
	} else {
		trakka:debug 2 "trakka:score:incr: increased scores for $nick!$uhost"
	}
}

# -- debug output
proc trakka:debug {lvl msg} {
	global trakka
	if {$trakka(debug) >= $lvl} { putloglev d * $msg }
}

# -- we need to save the trakka's in memory periodically
# - these are the people who stay put
proc trakka:save {} {
	global trakka
	
	if {$trakka(mode) == 0} { return; }
	
	set file $trakka(file)
	file delete $file
	set fd [open $file w]
	puts $fd "+---------------------------------------------------------------+"
	puts $fd "| trakka database						|"
	puts $fd "+---------------------------------------------------------------+"
	puts $fd "| type:value:score				   		|"
	puts $fd "+---------------------------------------------------------------+"
	set names [array names trakka]
	set sort [lsort $names]
	set count 0; set ncount 0; set uhcount 0; set xcount 0; set dcount 0;
	foreach entry $sort {
		set type [lindex [split $entry ,] 0]
		set value [lindex [split $entry ,] 1]
		# -- safety net
		if {![regexp -- {^(?:nick|uhost|xuser),} $entry]} { continue; }

		if {$trakka($type,$value) <= 0} {
			# -- delete trakka with empty score
			unset trakka($type,$value)
			incr dcount
			trakka:debug 3 "trakka:save: \002deleted trakka\002 trakka($type,$value)"
		} else {
			incr count
			switch -- $type {
				nick	{ incr ncount }
				uhost	{ incr uhcount }
				xuser	{ incr xcount }
			}
 			trakka:debug 3 "trakka:save: saving trakka entry: trakka($type,$value) (score: $trakka($type,$value))"
 			puts $fd "$type:$value:$trakka($type,$value)"
		
		}		
		
	}
	close $fd
	trakka:debug 0 "trakka:save: \002saved $count total trakka's\002 (nick: $ncount uhost: $uhcount xuser: $xcount)"
	trakka:debug 0 "trakka:save: \002deleted $dcount total trakka's\002"

	# -- save again in 10 mins	
	timer 10 trakka:save
}

# -- load the trakka db file
proc trakka:load {} {
	global trakka server
	
	if {$trakka(mode) == 0} { return; }
	
	if {$server != ""} {
		# -- already connected to server
		# - do we save instead? TODO
	}
	
	set file $trakka(file)
	if {[file exists $file]} {
		exec cp $file "$file.bak"
	} else { exec touch $file }
	
	set fd [open $file r]
	set data [read $fd]
	set lines [split $data \n]
	set count 0; set ncount 0; set uhcount 0; set xcount 0;
	foreach line $lines {
		if {[string index $line 0] == "+" || [string index $line 0] == "|" || $line == ""} { continue; }
		# -- safety net
		if {![regexp -- {^(?:nick|uhost|xuser):} $line]} { continue; }
		set theline [split $line :]
		lassign $theline type value score
		# -- only set if doesn't exist already
		if {![info exists trakka($type,$value)]} {
			set trakka($type,$value) $score
			incr count
			switch -- $type {
				nick	{ incr ncount }
				uhost	{ incr uhcount }
				xuser	{ incr xcount }
			}
			trakka:debug 3 "trakka:load: loaded trakka entry: trakka($type,$value) (score: $score)"
		}
		
	}
	close $fd
	trakka:debug 0 "trakka:load: \002loaded $count total trakka's\002 (nick: $ncount uhost: $uhcount xuser: $xcount)"
	
	# -- save again in 10 mins	
	timer 10 trakka:save	
}

proc trakka:killtimers {type match} {
	if {$type == "timer"} {
		foreach timer [timers] {
			lassign $timer mins proc id
			if {[string match $match $proc]} {
				killtimer $id
				trakka:debug 0 "killed timer: [lrange $timer 1 2]"
			}		
		}
	}
	if {$type == "utimer"} {
		foreach utimer [utimers] {
			lassign $utimer secs proc id
			if {[string match $match $proc]} {
				killutimer $id
				trakka:debug 0 "killed utimer: [lrange $utimer 1 2]"
			}	
		}	
	}
}

# -- subtract a point daily
proc trakka:cron:score {min hour day month weekday} {
	global trakka botnick
	
	if {$trakka(mode) == 0} { return; }
	
	# -- only run if I'm actually on the chan
	if {![onchan $botnick $trakka(chan)]} { 
		trakka:debug 0 "trakka:cron:score: \002not on $trakka(chan) so cannot run process cronjob!\002"
		return
	}
	
	set sub $trakka(subtract)
	set names [array names trakka]
	set sort [lsort $names]
	set count 0; set ncount 0; set uhcount 0; set xcount 0; set dcount 0;
	foreach entry $sort {
		# -- safety net
		if {![regexp -- {^(?:nick|uhost|xuser),} $entry]} { continue; }
		set type [lindex [split $entry ,] 0]
		set value [lindex [split $entry ,] 1]
		# -- subtract 1 from score
		incr trakka($type,$value) -$sub

		if {$trakka($type,$value) <= 0} {
			# -- delete trakka with empty score
			unset trakka($type,$value)
			incr dcount
			trakka:debug 3 "trakka:cron:score: \002daily trakka job deleted\002 trakka($type,$value)"
		} else {
			incr count
			switch -- $type {
				nick	{ incr ncount }
				uhost	{ incr uhcount }
				xuser	{ incr xcount }
			}
 			trakka:debug 3 "trakka:cron:score: daily trakka score subtracted -$sub from trakka($type,$value) (newscore: $trakka($type,$value))"
		
		}
	}
	trakka:debug 0 "trakka:cron:score: \002decremented $count total trakka's in daily cronjob\002 (nick: $ncount uhost: $uhcount xuser: $xcount)"
	trakka:debug 0 "trakka:cron:score: \002deleted $dcount totak trakka's in daily cronjob\002"
}

proc trakka:score:add {} {
	global trakka
	# -- hold a var for the endofwho
	set trakka(routinely) 1
	
	putquick "WHO $trakka(chan) %nuhiart,105"
}

proc trakka:raw:who {server cmd arg} {
	global trakka botnick
	
	if {$trakka(mode) == 0} { return; }
  
	set arg [split $arg]
  	lassign $arg mynick query ident ip host nick xuser rname
  	set rname [string trimleft $rname ":"] 
	set rname [join $rname]
	
  	trakka:debug 6 "trakka:raw:who: mynick: $mynick query: $query ident: $ident ip: $ip host: $host nick: $nick xuser: $xuser rname: $rname"
  	# -- safety nets
	if {$query != "105"} { return; }
	if {$nick == $botnick} { return; }

	set uhost "$ident@$host"
	set nuh "$nick!$uhost"
	set chan $trakka(chan)
	
	set names [array names trakka]
	set sort [lsort $names]
	foreach entry $sort {
		# -- safety net
		if {![regexp -- {^(?:nick|uhost|xuser),} $entry]} { continue; }
		set type [lindex [split $entry ,] 0]
		set value [lindex [split $entry ,] 1]
		switch -- $type {
			nick	{
				# -- nickname
				if {$value == $nick} {
					# -- entry match exists, add 1 point
					incr trakka($type,$value)
					incr trakka(count)
					incr trakka(ncount)
					trakka:debug 5 "trakka:raw:who: routine trakka increment (+1): trakka($type,$value) (newscore: $trakka($type,$value))"
				}
				}
			uhost	{
				# -- uhost
				if {$value == $uhost} {
					# -- entry match exists, add 1 point
					incr trakka($type,$value)
					incr trakka(count)
					incr trakka(uhcount)
					trakka:debug 5 "trakka:raw:who: routine trakka increment (+1): trakka($type,$value) (newscore: $trakka($type,$value))"
				}
			}
			xuser	{
				# -- xuser
				if {$value == $xuser} {
					# -- entry match exists, add 1 point
					incr trakka($type,$value)
					incr trakka(count)
					incr trakka(xcount)
					trakka:debug 5 "trakka:raw:who: routine trakka increment (+1): trakka($type,$value) (newscore: $trakka($type,$value))"
				}
			}
		}
		
	}
}

proc trakka:raw:endofwho {server cmd arg} {
	global trakka
	
	if {$trakka(mode) == 0} { return; }
	
	set arg [split $arg]
	lassign $arg mynick mask
	if {$mask != $trakka(chan) || ![info exists trakka(routinely)]} { return; }
  
  	# -- prime the counters if they don't already exist
	if {![info exists trakka(count)]} { set trakka(count) 0 }
  	if {![info exists trakka(ncount)]} { set trakka(ncount) 0 }
  	if {![info exists trakka(uhcount)]} { set trakka(uhcount) 0 }
  	if {![info exists trakka(xcount)]} { set trakka(xcount) 0 }
  	
	trakka:debug 0 "trakka:raw:endofwho: \002incremented $trakka(count) total trakka's in routine cycle\002 (nick: $trakka(ncount) uhost: $trakka(uhcount) xuser: $trakka(xcount))"

	unset trakka(count)
	unset trakka(ncount)
	unset trakka(uhcount)
	unset trakka(xcount)
	unset trakka(routinely)
	
	# -- start again
	timer $trakka(routine) trakka:score:add
}


# -- add a point if opped
proc trakka:mode:addo {nick uhost hand chan mode target} {
	global trakka
	
	if {$trakka(mode) == 0 || $trakka(chan) != $chan} { return; }
	if {[isbotnick $nick]} { return; }
	
	set host [lindex [split $uhost @] 1]
	
	# -- nickname
	incr trakka(nick,$nick)
	trakka:debug 2 "trakka:modeadd:o: client opped -- increased nick trakka for: $nick!$uhost (score: $trakka(nick,$nick))"
	# -- xuser
	set xuser ""
	if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
		incr trakka(xuser,$xuser)
		trakka:debug 2 "trakka:modeadd:o: client opped -- increased xuser trakka for: $nick!$uhost (score: $trakka(xuser,$xuser))"
	} else {
		# -- uhost (only do this if not umode +x)
		incr trakka(uhost,$uhost)
		trakka:debug 2 "trakka:modeadd:o: client opped -- increased uhost trakka for: $nick!$uhost (score: $trakka(uhost,$uhost))"
	}
}

# -- add a point if voiced
proc trakka:mode:addv {nick uhost hand chan mode target} {
	global trakka arm

	if {$trakka(mode) == 0 || $trakka(chan) != $chan} { return; }
	if {[isbotnick $nick]} { return; }

	# -- don't add score if chanmode +D (Armour mode: secure)
	if {[info exists arm(mode)]} {
		if {$arm(mode) == "secure"} { return; }
	}
	
	set host [lindex [split $uhost @] 1]
	
	# -- nickname
	incr trakka(nick,$nick)
	trakka:debug 2 "trakka:modeadd:o: client voiced -- increased nick trakka for: $nick!$uhost (score: $trakka(nick,$nick))"
	# -- xuser
	set xuser ""
	if {[regexp -- $trakka(cfg.xhost) $host -> xuser]} {
		incr trakka(xuser,$xuser)
		trakka:debug 2 "trakka:modeadd:o: client voiced -- increased xuser trakka for: $nick!$uhost (score: $trakka(xuser,$xuser))"
	} else {
		# -- uhost (only do this if not umode +x)
		incr trakka(uhost,$uhost)
		trakka:debug 2 "trakka:modeadd:o: client voiced -- increased uhost trakka for: $nick!$uhost (score: $trakka(uhost,$uhost))"
	}
}

# -- send text responses back to irc client
proc trakka:reply {type target msg} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	  dcc {
		if {[userdb:isInteger $target]} { putidx $target $msg; return; } \
		else { putidx [hand2idx $target] $msg; return; }
	  }
	}
	putquick "$med $target :$msg"
}

# -- build client score
# - mainly for 3rd party scripts
proc trakka:score {nick uhost xuser} {
	global trakka
	if {[info exists trakka(nick,$nick)]} { set nscore $trakka(nick,$nick) } else { set nscore 0 }
	if {[info exists trakka(uhost,$uhost)]} { set uhscore $trakka(uhost,$uhost) } else { set uhscore 0 }
	if {[info exists trakka(xuser,$xuser)]} { set xscore $trakka(xuser,$xuser) } else { set xscore 0 }
	set score [expr $nscore + $uhscore + $xscore]
	return $score
}



# -- kill all timers on load or rehash
trakka:killtimers timer "trakka:*"
trakka:killtimers utimer "trakka:*"

# -- load trakka's from file
trakka:load

# -- start timer to automatically add points periodically
timer $trakka(routine) trakka:score:add

putlog "\[@\] Armour: loaded plugin: trakka"

