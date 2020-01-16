# -- remind.tcl
# origin code and concept from Elven <elven@elven.de>
#


# -- default channel
# - overridden if in integrated mode
set tell(chan) "#channel"

# -- debug level (0-3) - [1]
set tell(debug) 3

# -- tell mode
# - modes:
# 0:	off
# 1:	standalone
# 2:	integrated to Armour
set tell(mode) 2



# -----------------------------------------------------------------------------
# command			plugin		level req.	binds
# -----------------------------------------------------------------------------
set addcmd(tell)	{	tell		1		pub msg dcc	}


# ---- binds
# -- integration mode handling
if {$tell(mode) == 1} {
	bind pub - .tell tell:bind:pub:tell
	proc tell:bind:pub:tell {n uh h c a} {
		tell:cmd:tell pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind in case we changed mode during operation
	catch { unbind pub - .tell tell:pub:tell }
	# -- load commands
	arm:loadcmds
}

# -- binds
bind pubm - * tell:msgm:*
bind join - * tell:join:*
bind nick - * tell:nick:*
bind ctcp - "ACTION" tell:act:*

# -- the main command
proc tell:cmd:tell {0 1 2 3 {4 ""}  {5 ""}} {
	global arm tell remind
	set type $0

	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {$tell(mode) == 2} { if {![userdb:isValidchan $chan]} { return; } }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick;
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $tell(chan) }
		set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; 
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $tell(chan) }
		set source "$hand/$idx"
	}
	
	set cmd "tell"
	
	# -- check for integration mode
	if {$tell(mode) == 2} {
		# -- ensure user has required access for command
		if {![userdb:isAllowed $nick $cmd $type]} { return; }
		set user [userdb:uline:get user nick $nick]
		set level [userdb:uline:get level user $user]
	} else {
	  	# -- no Armour, no access level
		set level 0
		if {![isop $nick $chan] && ![isvoice $nick $chan]} { return; }
	}

	# -- end default proc template
	
	#set args [join $args]
	
	set delayed 0
	set timed 0
	set priv 0

	if {[regexp {^(?:([^\s]+) (?:at|in)|at|in) (.+?)(?: (that|to|about) (.+?))$} $args {} to time prefix what]} {
	
		tell:debug 3 "tell:cmd:tell: \002regexp\002 to: $to time: $time prefix: $prefix what: $what"

		if {[regexp -- {^(.+?)(?:, )?in private$} $what -> what]} { set priv 1 }
				
		set delay [tell:timedesc2int $time]
		
		if {$delay < 0} {
			if {0 != [ catch {clock scan $time} delay ]} {
				tell:reply $type $target "error: invalid time specification."
				#tell:reply $type $target "invalid time specification. Its in general TCL clock scan syntax. Refer to http://www.tcl.tk/man/tcl8.5/TclCmd/clock.htm#M46 for more information."
				return
			}
			if {![string is integer $delay]} {
				tell:reply $type $target "error: invalid time specification."
				#tell:reply $type $target "invalid time specification. use '.remind' for help."
				return
			}
			set delay [expr $delay - [unixtime]]
			if {$delay < 1} { 
				tell:reply $type $target "error: that time specification has already expired."
				return
			}
			if {$delay > 60*60*24*3000} {
				tell:reply $type $target "error: be reasonable."
				return
			}
		}
		set timed 1
	} elseif {[regexp {^(.+?)(?: (that|to|about) (.+?))$} $args -> to prefix what]} {
		# -- delayed tell: wait for join or chatter
		if {[regexp -- {^(.+?)(?:, )?in private$} $what -> what]} { set priv 1 }
		set delayed 1
		tell:debug 3 "tell:cmd:tell adding tell to: $to prefix: $prefix timed: $timed delayed: $delayed priv: $priv what: $what"
	} else {
		# -- return syntax
		tell:reply $type $target "usage: tell <who> ?<when>? (that|to|about) <something>"
		return;
	}
	
	if {$to == ""} { set to "me" }
	if {$to == "me" || $to == $nick} { set tx $nick } else { set tx $to }
	if {$to == "me"} {
		# -- replace 'I' with 'you'
		regsub -all {I } $what {you } what
	} else {
		# -- attempt other fixes
		regsub -all {I am } $what {they are } what
		regsub -all {I was } $what {they were } what
		regsub -all {I will } $what {they will } what
		regsub -all {I won't } $what {they won't } what
		regsub -all {I can't } $what {they can't } what
		regsub -all {I cannot } $what {they cannot } what
		regsub -all {he is } $what {you are } what
		regsub -all {she is } $what {you are } what
		regsub -all {he has } $what {you have } what
		regsub -all {she has } $what {you have } what
		regsub -all {his } $what {your } what
		regsub -all {her } $what {your } what
		regsub -all {he's } $what {you're } what
		regsub -all {she's } $what {you're } what
		regsub -all {he } $what {you } what
		regsub -all {she } $what {you } what
		regsub -all {I } $what {they } what
	}

	if {$priv} { 
		# -- private
		set out $tx; set med "priv" 
	} else { 
		set out $target
		set med $chan
	}
	
	if {$to == "me" || $to == $nick} { set who "you" } else { set who $nick }
	
	tell:debug 2 "tell:cmd:tell: adding tell: out: [join $out] med: $med who: $who timed: $timed what: $what"
	
	if {$timed} {
		# -- timed response		
		utimer $delay [list putmsg $out [string trim "[join $tx]: $who asked me to tell you $prefix $what"]]
	} else {
		# -- response delayed until join or chatter
		set string "[join $tx]: $who asked me to tell you $prefix $what"
		set remind([string tolower [join $tx]]) [list $med $string]
	}
	tell:reply $type $target "okay, will do."
	return
}


# -- nickname speaking
proc tell:msgm:* {nick uhost hand chan text} {
	global tell remind
	if {[info exists remind([string tolower $nick])]} {
		# -- delayed tell exists
		lassign $remind([string tolower $nick]) med string
		if {$med == "priv"} { set target $nick } else { set target $med }
		# -- fix case from nick
		regsub -- {^([^:]+):} $string "$nick:" string
		putmsg $target $string
		unset remind([string tolower $nick])
	}
}

# -- nickname speaking (doing action) -- /me
proc tell:act:* {nick uhost hand dest keyword text} {
	global tell remind
	if {[info exists remind([string tolower $nick])]} {
		# -- delayed tell exists
		lassign $remind([string tolower $nick]) med string
		if {$med == "priv"} { set target $nick } else { set target $med }
		# -- fix case from nick
		regsub -- {^([^:]+):} $string "$nick:" string
		putmsg $target $string
		unset remind([string tolower $nick])
	}
}

# -- nick change
proc tell:nick:* {nick uhost handle chan newnick} {
	global tell remind
	if {[info exists remind([string tolower $nick])]} {
		set remind($newnick) $remind([string tolower $nick])
		unset remind([string tolower $nick])
	}
}

# -- nickname joining chan
proc tell:join:* {nick uhost hand chan} {
	global tell remind
	if {[info exists remind([string tolower $nick])]} {
		# -- delayed tell exists
		lassign $remind([string tolower $nick]) med string
		if {$med == "priv"} { set target $nick } else { set target $med }
		# -- fix case from nick
		regsub -- {^([^:]+):} $string "$nick:" string
		putmsg $target $string
		unset remind([string tolower $nick])
	}	
}
  

# -- converts a timedesc timestamp into an integer value
# possible units:
#  d(ay(s)), m(inute(s)), h(our(s)), s(econd(s))
#
# examples:
#  1m3s to 63 (seconds)
#  4 hours 50 minutes 1 second
#
# returns:
#    -1 on parse failure
#  > -1 on success
proc tell:timedesc2int str {
	if {![regexp {^(?:(\d+) ?d(?:ays?)?)? ?(?:(\d+) ?h(?:ours?)?)? ?(?:(\d+) ?m(?:inutes?)?)? ?(?:(\d+) ?s(?:econds?)?)?$} $str "" days hours minutes seconds]} {
		return -1
	}
	if {$days == "" && $hours == "" && $minutes == "" && $seconds == ""} {
		return -1
	}
	if {$seconds == ""} { set seconds 0 }
	if {$minutes == ""} { set minutes 0 }
	if {$hours   == ""} { set hours   0 }
	if {$days    == ""} { set days    0 }
	return [expr $seconds + $minutes * 60 + $hours * 3600 + $days * 3600 * 24]
}

# -- converts an integer to a timedesc timestamp
# - ie.  128 -> 2m8s
proc tell:int2timedesc int {
	# Highest field: days
	while {$int - 3600*24 > 3600*24} {
		incr int [expr -(3600*24)]
	}
}

# -- debug proc
proc tell:debug {lvl msg} {
	global tell
	if {$lvl <= $tell(debug)} { putloglev d * $msg }
}

# -- send text responses back to irc client
proc tell:reply {type target msg} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	}
	putquick "$med $target :$msg"
}

#catch { unset remind }

putlog "\[@\] Armour: loaded plugin: tell"
