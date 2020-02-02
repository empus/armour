# -- smsbot
#
# sms gateway using www.smsglobal.com HTTP API
#

set sms(cfg.sms.url) "http://www.smsglobal.com/http-api.php"

set sms(cfg.sms.user) "EDIT-ME"
set sms(cfg.sms.pass) "EDIT-ME"


# -- enable two way SMS? (0|1) - [1]
set sms(cfg.inc) 1

# -- file for incoming messages posted by optional incoming.php
# HTTP POST back must be configured @ smsglobal.com for that script
set sms(cfg.inc.file) "/home/armour/www/messages/sms.txt"

# -- log file for messages
set sms(cfg.inc.archive) "/home/armour/www/messages/sms-archive.log"

# -- timer for incoming messages read (secs) - [30]
set sms(cfg.inc.timer) "10"


# -- default channel
# - overridden if in integrated mode
set sms(chan) "#channel"

# -- debug level (0-3) - [1]
set sms(debug) 1

# -- sms mode
# - modes:
# 0:	off
# 1:	standalone
# 2:	integrated to Armour
set sms(mode) 2


# -- setup phonebook
# lvl req. to send sms to user can be:
#	- level:	standard access level
#	- o:		opped user
#	- v:		voiced user
#	- *:		anyone
#	- +<flag>:	eggdrop flags
#	- #chan:	in #chan (ensure a channel is encapsulated in "#quotemarks")
#
# ACL entry with a handle of * allows a user to specify phone number manually in international format
#
# ---------------------------------------------------------------
#	handle			number		lvl req.
# ---------------------------------------------------------------
set smsadd(Empus)	{	1234567890	#somechannel	}
set smsadd(foo)		{	0987654321	1		}


# -----------------------------------------------------------------------------
# command			plugin		level req.	binds
# -----------------------------------------------------------------------------
set addcmd(sms)		{	sms		0		pub priv dcc	}


# ---- binds
# -- integration mode handling
if {$sms(mode) == 1} {
	bind pub - .sms sms:bind:pub:sms
	proc sms:bind:pub:sms {n uh h c a} {
		sms:cmd:sms pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind in case we changed mode during operation
	catch { unbind pub - .sms sms:pub:sms }
	if {[lsearch [info commands] "sms:bind:pub:sms"] != "-1"} {
		unbind pub - .sms sms:bind:pub:sms
	}
	# -- load commands
	arm:loadcmds
}


package require http


proc sms:cmd:sms {0 1 2 3 {4 ""}  {5 ""}} {
	global arm sms
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {$sms(mode) == 2} { if {![userdb:isValidchan $chan]} { return; } }
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
	
	set cmd "sms"
	
	# -- check for integration mode
	if {$sms(mode) == 2} {
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
	
	# -- syntax: <number> <from> <message>
	if {$hand == "" || $hand == 0 || $hand == "*"} { set from $nick } else { set from $hand }
	set to [lindex $args 0]
	set text [lrange $args 1 end]
	
	if {$from == "" || $to == "" || $text == ""} { sms:reply $type $target "syntax: sms <to> <message>"; return; }
	
	sms:debug 1 "sms:pub:sms: $nick!$uh requesting SMS from $from to $to (message: $text)"
	
	set reject 0
	
	if {![regexp -- {^\d+$} $to]} {
		# -- phone book entry used

		# -- ensure user is in phonebook (we do a scan to avoid case issues)
		set match 0
	  	foreach entry [array names sms] {
	  		set line [split $entry ,]
	  		lassign $line bit user
	  		if {$bit != "num"} { continue; }
			if {[string tolower $user] == [string tolower $to]} { set dest $sms(num,$user); set match 1; set to $user; break; }
	  	}
	  	if {!$match} {
	  		# -- no such user
	    		sms:debug 1 "sms:pub:sms: failed to send SMS to $to (no such user)"
	    		sms:reply $type $target "\002(error)\002 no such user $to"
	    		return;
	  	}
	  	
	  	set req $sms(acl,$user)
	  	set handle $user
	  	
	} else {
		# -- raw phone number used, check for access
		
		# -- only proceed if there is an ACL entry for * (manual phone numbers)
		if {![info exists sms(acl,*)]} { return; }
		
		set req $sms(acl,*)
		set handle "*"
		
		if {[string index $to 0] == "+" || [string index $to 0] == "0"} {
			sms:reply $type $target "\002(error)\002 malformed phone number (please use international format without + or leading 0)"
	  		return;
		}
		
	}
	
	putlog "req: $req handle: $handle reject: $reject"
	
	if {[regexp -- {^\d+$} $req]} {
		# -- level acl
		if {$level < $req} { set reject 1; sms:debug 2 "sms:pub:sms: \002error:\002 acl rejected -- level $level < required $req" }
	} elseif {[string index $req 0] == "#"} {
		# -- in channel
		if {![onchan $nick $req] && ![handonchan $hand $req]} { set reject 1; push:debug 2 "sms:pub:sms: \002error:\002 acl rejected -- not in channel $req" }
	} elseif {$req == "o"} {
		# -- op required
		if {![isop $nick $chan]} { set reject 1; sms:debug 2 "sms:pub:sms: \002error:\002 acl rejected -- not opped" }
	} elseif {$req == "v"} {
		# -- voice required
		if {![isvoice $nick $chan]} { set reject 1; sms:debug 2 "sms:pub:sms: \002error:\002 acl rejected -- not voiced" }
	} elseif {[regexp -- {^\+\[A-Za-z]+} $req]} {
		# -- eggdrop flag used
		if {![matchattr $hand $chan $req]} { set reject 1; sms:debug 2 "sms:pub:sms: \002error:\002 acl rejected -- missing flag $req" }
	} else {
		# -- malformed acl configured
		set reject 1
		sms:debug 2 "sms:pub:sms: \002error:\002 acl rejected -- malformed acl ($req)"
	}
	
	if {$reject} {
		# -- ACL error
		sms:debug 0 "sms:pub:sms: acl rejected SMS send from $from to $to (acl required: $req)"
		sms:reply $type $target "\002(error)\002 acl rejected SMS send from $from to $to (acl required: $req)"
		return;
	}
	
	# -- ensure message length not >160
	set length [string length $text]
	if {$length > 160} {
	  sms:reply $type $target "\002(error)\002 message too long ($length chars) -- must not exceed 160 chars."
	  return;  
	}
	
	# -- send the message!
	
	set action "sendsms"
	
	# -- formulate query
	http::config -useragent "mozilla" 
	set query [http::formatQuery action $action user $sms(cfg.sms.user) password $sms(cfg.sms.pass) api $sms(cfg.inc) userfield "$source|$type|$to|$chan" from $from to $dest text "From: $nick ($type) -- $text"]
	
	# -- send HTTP post data

	sms:debug 0 "sms:pub:sms: sending SMS query: $sms(cfg.sms.url)?$query"
	#sms:reply $type $target "connecting to gateway..."
	
	catch {set tok [http::geturl $sms(cfg.sms.url) -query $query -keepalive 1]} error
	set ncode [http::ncode $tok]
	set status [http::status $tok]
	set token $tok
	set data [http::data $tok]
	set lines [split $data \n]
	  
	# -- check for errors
	sms:debug 1 "sms:pub:sms: checking for errors...(error: $error)"
	if {[string match -nocase "*couldn't open socket*" $error]} { 
	  sms:debug 0 "sms:pub:sms: could not open socket to: $sms(cfg.sms.url)"
	  sms:reply $type $target "\002(error)\002 could not open socket to: $sms(cfg.sms.url)"
	  http::cleanup $tok
	  return 0 
	} elseif {$status == "timeout"} { 
	  sms:debug 0 "sms:pub:sms: connection to $sms(cfg.sms.url) has timed out."
	  sms:reply $type $target "\002(error)\002 connection timeout."
	  http::cleanup $tok
	  return 0 
	} elseif {$status == "error"} {
	  sms:debug 0 "sms:pub:sms: connection to $sms(cfg.sms.url) has error."
	  sms:reply $type $target "\002(error)\002 connection error."
	  http::cleanup $tok
	  return 0  
	}
	
	# -- we only want the first line
	foreach line $lines { 
	  sms:debug 3 "sms:pub:sms: (\002wwwdata\002) $line";
	  if {[regexp -- {^ERROR:} $line]} {
	    sms:debug 0 "sms:pub:sms: $line"
	    sms:reply $type $target "\002(error)\002) [string tolower $line]"
	    http::cleanup $tok
	    return;
	  }
	  # -- message successfully sent
	  sms:reply $type $target "message delivered."
	  break;
	}
	     
	sms:debug 1 "sms:pub:sms: message sent (status: $status ncode: $ncode token: $token)"
	
	http::cleanup $tok

	# -- create log entry for command use (if integrated to Armour)
	if {$sms(mode) == 2} { arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] $source "" "" "" }
	
	return;

}


# -- debug proc
proc sms:debug {lvl msg} {
	global sms
	if {$lvl <= $sms(debug)} { putloglev d * $msg }
}

# -- send text responses back to irc client
proc sms:reply {type target msg} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	}
	putquick "$med $target :$msg"
}

proc sms:load {} {
	global sms smsadd
	foreach hand [array names smsadd] {
		lassign $smsadd($hand) num lvl
		set sms(num,$hand) $num
		set sms(acl,$hand) $lvl
		sms:debug 0 "sms:add:entry: added phonebook entry: user: $hand number: $num acl: $lvl"	
	}
}

# -- load phonebook entries
sms:load

# -- timer to read any incoming messages
proc sms:incoming {} {
	global sms
	set fd [open $sms(cfg.inc.file) r]
	set data [read $fd]
	if {$data != ""} {
		set lines [split $data \n]
		foreach line $lines {
			if {$line == ",,,," || $line == ""} { continue; }
			set params [split $line ,]
			lassign $params to from userfield date msg
			sms:debug 0 "sms:incoming: incoming message: to: $to -- from: $from -- userfield: $userfield -- date: $date -- message: $msg"
			lassign [split $userfield |] source type rcpt chan
			set inc 0
			# -- nick!u@host
			if {$type == "msg" } { set target [lindex [split $source !] 0]; }
			# -- dcc (idx)
			if {$type == "dcc" } { set target [lindex [split $source /] 1]; }
			# -- public (chan)
			if {$type == "pub"} { set target $chan; set inc 1 }
			
			sms:debug 0 "sms:incoming: sending response from: $rcpt back to: $source (via $type to $target) --- msg: $msg" 
			
			if {$inc} {
				# -- include the nickname, it's being sent to the channel
				arm:reply $type $target "\002(\002sms response\002)\002 from: $rcpt -- to: [lindex [split $source !] 0] -- msg: $msg";
			} else {
				# -- don't include the nickname, send directly
				arm:reply $type $target "\002(\002sms response\002)\002 from: $rcpt -- msg: $msg";
			}
			
			exec echo "\[$date\] incoming message: to: $to -- from: $from -- userfield: $userfield -- date: $date -- message: $msg" >> $sms(cfg.inc.archive)
		}
	}
	sms:debug 4 "sms:incoming: end of file"
	exec echo "" > $sms(cfg.inc.file)
	close $fd
	utimer $sms(cfg.inc.timer) sms:incoming
}

# -- start timer for incoming messages
sms:incoming

putlog "\[@\] Armour: loaded plugin: smsbot"
