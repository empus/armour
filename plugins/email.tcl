# -- emailbot
#
# email notifications
#


# -- default channel
# - overridden if in integrated mode
set email(chan) "#channel"


# -- debug level (0-3) - [1]
set email(debug) 3


# -- email mode
# - modes:
# 0:	off
# 1:	standalone
# 2:	integrated to Armour
set email(mode) 2


# -- setup email notification user directory
#
# lvl req. to send email to user can be:
#	- level:	standard access level
#	- o:		opped user
#	- v:		voiced user
#	- *:		anyone
#	- +<flag>:	eggdrop flags
#	- #chan:	in #chan (ensure a channel is encapsulated in "#quotemarks")
#
# device of * denotes email to all devices
#
# -------------------------------------------------------------------------------------------------------------------------------
#	handle				address								lvl req.
# -------------------------------------------------------------------------------------------------------------------------------
set emailadd(empus)		{	empus@undernet.org						"#channel	"	}
set emailadd(empfoo)		{	mail@empus.net							400			}


# ---------------------------------------------------------------------------------------
# command			plugin			level req.	binds
# ---------------------------------------------------------------------------------------
set addcmd(email)		{	email		0		pub msg dcc	}


# ---- binds
# -- integration mode handling
if {$email(mode) == 1} {
	bind pub - .email email:bind:pub:email
	proc email:bind:pub:email {n uh h c a} {
		email:cmd:email pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind in case we changed mode during operation
	catch { unbind pub - .email email:pub:email }
	# -- load commands
	arm:loadcmds
}


package require http
package require tls
::http::register https 443 ::tls::socket


proc email:cmd:email {0 1 2 3 {4 ""}  {5 ""}} {
	global arm email
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {$email(mode) == 2} { if {![userdb:isValidchan $chan]} { return; } }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick;
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $email(chan) }
		set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; 
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $email(chan) }
		set source "$hand/$idx"
	}
	
	set cmd "email"
	
	# -- check for integration mode
	if {$email(mode) == 2} {
		# -- ensure user has required access for command
		if {![userdb:isAllowed $nick $cmd $type]} { return; }
		set user [userdb:uline:get user nick $nick]
		set level [userdb:uline:get level user $user]
	} else {
	  	# -- no Armour, no access level
		set level 0
	}

	# -- end default proc template
	
	if {$level == 0 && ![isop $nick $chan] && ![isvoice $nick $chan]} { return; }

	set args [join $args]
	
	# -- syntax: <to> <message>
	if {$hand == "" || $hand == 0 || $hand == "*"} { set from $nick; set fromnuh "$nick![getchanhost $nick]" } else { set from $hand; set fromnuh $hand }
	set to [lindex $args 0]
	set text [lrange $args 1 end]
	
	if {$from == "" || $to == "" || $text == ""} { email:reply $type $target "syntax: email <to> <message>"; return; }
	
	email:debug 1 "email:pub:email: $nick!$uh requesting email from $from to $to (message: $text)"
	
	# -- ensure user is in email directory (we do a scan to avoid case sensitivity issues)
	set match 0
  	foreach entry [array names email] {
  		set line [split $entry ,]
  		lassign $line bit user
  		if {$bit != "address"} { continue; }
		if {[string tolower $user] == [string tolower $to]} { set dest $email(address,$user); set match 1; set to $user; break; }
  	}
  	if {!$match} {
  		# -- no such user
    		email:debug 1 "email:pub:email: failed to send email to $to (no such user)"
    		email:reply $type $target "error: no such user $to"
    		return;
  	}
  	
  	set req $email(acl,$user)
  	set handle $user
	set reject 0
	
	if {[regexp -- {^\d+$} $req]} {
		# -- level acl
		if {$level < $req} { set reject 1; email:debug 2 "email:pub:email: \002error:\002 acl rejected -- level $level < required $req" }
	} elseif {[string index $req 0] == "#"} {
		# -- in channel
		if {![onchan $nick $req] && ![handonchan $hand $req]} { set reject 1; email:debug 2 "email:pub:email: \002error:\002 acl rejected -- not in channel $req" }
	} elseif {$req == "o"} {
		# -- op required
		if {![isop $nick $chan]} { set reject 1; email:debug 2 "email:pub:email: \002error:\002 acl rejected -- not opped" }
	} elseif {$req == "v"} {
		# -- voice required
		if {![isvoice $nick $chan]} { set reject 1; email:debug 2 "email:pub:email: \002error:\002 acl rejected -- not voiced" }
	} elseif {[regexp -- {^\+\[A-Za-z]+} $req]} {
		# -- eggdrop flag used
		if {![matchattr $hand $chan $req]} { set reject 1; email:debug 2 "email:pub:email: \002error:\002 acl rejected -- missing flag $req" }
	} else {
		# -- malformed acl configured
		set reject 1
		email:debug 2 "email:pub:email: \002error:\002 acl rejected -- malformed acl ($req)"
	}
	
	email:debug 3 "req: $req handle: $handle reject: $reject"

	if {$reject} {
		# -- ACL error
		email:debug 0 "email:pub:email: acl rejected email send from $from to $to (acl required: $req)"
		email:reply $type $target "error: malformed acl configured for handle $handle (acl: $req)"
		return;
	}
	
	# -- ensure message length not >160
	set length [string length $text]
	if {$length > 160} {
	  email:reply $type $target "error: message too long ($length chars) -- must not exceed 160 chars."
	  return;  
	}
	
	# -- send the message!
	
	if {$type == "pub"} { set subject "-- From: $fromnuh in $chan" } else { set subject "-- From: $fromnuh" }
	
	catch {set response [exec echo "$text" | mail -s $subject $email(address,$user)]} error
	
	# -- check for errors
	email:debug 1 "email:pub:email: checking for errors...(error: $error)"
	

	# -- notification successfully sent
	email:reply $type $target "email sent."	     
	email:debug 1 "email:pub:email: message sent."
	
	return;

}


# -- debug proc
proc email:debug {lvl msg} {
	global email
	if {$lvl <= $email(debug)} { putloglev d * $msg }
}

# -- send text responses back to irc client
proc email:reply {type target msg} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	}
	putquick "$med $target :$msg"
}

proc email:load {} {
	global email emailadd
	foreach hand [array names emailadd] {
		lassign $emailadd($hand) dev lvl
		set email(address,$hand) $dev
		set email(acl,$hand) $lvl
		email:debug 0 "email:add:entry: added email address directory entry: user: $hand dev: $dev acl: $lvl"	
	}
}

# -- load email address directory entries
email:load

putlog "\[@\] Armour: loaded plugin: email"
