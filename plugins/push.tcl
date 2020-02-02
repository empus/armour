# -- pushbot
#
# push notifications using www.pushover.com JSON API
#

set push(cfg.push.url) "https://api.pushover.net/1/messages.json"

# -- application key/token
set push(cfg.push.token) "EDIT-ME" # -- user key
set push(cfg.push.user) "EDIT-ME"


# -- default channel
# - overridden if in integrated mode
set push(chan) "#channel"


# -- debug level (0-3) - [1]
set push(debug) 3


# -- push mode
# - modes:
# 0:	off
# 1:	standalone
# 2:	integrated to Armour
set push(mode) 2


# -- setup push notification user directory
#
# lvl req. to send push to user can be:
#	- level:	standard access level
#	- o:		opped user
#	- v:		voiced user
#	- *:		anyone
#	- +<flag>:	eggdrop flags
#	- #chan:	in #chan (ensure a channel is encapsulated in "#quotemarks")
#
# device of * denotes push to all devices
#
# -------------------------------------------------------------------------------
#	handle				device		lvl req.
# -------------------------------------------------------------------------------
set pushadd(empus)		{	iphone		"#channel"	}
set pushadd(empus1)		{	iphone		200		}


# ---------------------------------------------------------------------------------------
# command			plugin			level req.	binds
# ---------------------------------------------------------------------------------------
set addcmd(push)		{	push		0	pub msg dcc	}


# ---- binds
# -- integration mode handling
if {$push(mode) == 1} {
	bind pub - .push push:bind:pub:push
	proc push:bind:pub:push {n uh h c a} {
		push:cmd:push pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind in case we changed mode during operation
	if {[lsearch [info commands] "push:bind:pub:push"] != "-1"} {
		unbind pub - .push push:bind:pub:push
	}
	# -- load commands
	arm:loadcmds
}


package require http
package require tls
::http::register https 443 ::tls::socket


proc push:cmd:push {0 1 2 3 {4 ""}  {5 ""}} {
	global arm push
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {$push(mode) == 2} {
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
	
	set cmd "push"
	
	# -- check for integration mode
	if {$push(mode) == 2} {
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
	
	if {$from == "" || $to == "" || $text == ""} { push:reply $stype $starget "syntax: push <to> <message>"; return; }
	
	push:debug 1 "push:pub:push: $nick!$uh requesting push from $from to $to (message: $text)"
	
	# -- ensure user is in push directory (we do a scan to avoid case sensitivity issues)
	set match 0
  	foreach entry [array names push] {
  		set line [split $entry ,]
  		lassign $line bit user
  		if {$bit != "dev"} { continue; }
		if {[string tolower $user] == [string tolower $to]} { set dest $push(dev,$user); set match 1; set to $user; break; }
  	}
  	if {!$match} {
  		# -- no such user
    		push:debug 1 "push:pub:push: failed to send push to $to (no such user)"
    		push:reply $type $target "error: no such user $to"
    		return;
  	}
  	
  	set req $push(acl,$user)
  	set handle $user
	set reject 0
	
	if {[regexp -- {^\d+$} $req]} {
		# -- level acl
		if {$level < $req} { set reject 1; push:debug 2 "push:pub:push: \002error:\002 acl rejected -- level $level < required $req" }
	} elseif {[string index $req 0] == "#"} {
		# -- in channel
		if {![onchan $nick $req] && ![handonchan $hand $req]} { set reject 1; push:debug 2 "push:pub:push: \002error:\002 acl rejected -- not in channel $req" }
	} elseif {$req == "o"} {
		# -- op required
		if {![isop $nick $chan]} { set reject 1; push:debug 2 "push:pub:push: \002error:\002 acl rejected -- not opped" }
	} elseif {$req == "v"} {
		# -- voice required
		if {![isvoice $nick $chan]} { set reject 1; push:debug 2 "push:pub:push: \002error:\002 acl rejected -- not voiced" }
	} elseif {[regexp -- {^\+\[A-Za-z]+} $req]} {
		# -- eggdrop flag used
		if {![matchattr $hand $chan $req]} { set reject 1; push:debug 2 "push:pub:push: \002error:\002 acl rejected -- missing flag $req" }
	} else {
		# -- malformed acl configured
		set reject 1
		push:debug 2 "push:pub:push: \002error:\002 acl rejected -- malformed acl ($req)"
	}
	
	push:debug 3 "req: $req handle: $handle reject: $reject"

	if {$reject} {
		# -- ACL error
		push:debug 0 "push:pub:push: acl rejected push send from $from to $to (acl required: $req)"
		push:reply $type $target "error: malformed acl configured for handle $handle (acl: $req)"
		return;
	}
	
	# -- ensure message length not >160
	set length [string length $text]
	if {$length > 160} {
	  push:reply $type $target "error: message too long ($length chars) -- must not exceed 160 chars."
	  return;  
	}
	
	# -- send the message!
	
	if {$type == "pub"} { set title "From: $fromnuh in $chan" } else { set title "From: $fromnuh" }
	
	# -- formulate query
	http::config -useragent "mozilla" 

	#
	# -- See https://pushover.net/api
	#	
	# -- POST an HTTP request to https://api.pushover.net/1/messages.json with the following parameters: 
	#
	#	token (required) - your application's API token
	# 	user (required) - the user key (not e-mail address) of your user (or you), viewable when logged into our dashboard
	# 	message (required) - your message 
	#
	# -- Some optional parameters may be included:
	#	
	#	device - your user's device name to send the message directly to that device, rather than all of the user's devices
	#  	title - your message's title, otherwise your app's name is used
	#  	url - a supplementary URL to show with your message
	#  	url_title - a title for your supplementary URL, otherwise just the URL is shown
	#  	priority - send as -1 to always send as a quiet notification, 1 to display as high-priority and bypass the user's quiet hours
	#  	timestamp - a Unix timestamp of your message's date and time to display to the user, rather than the time your message is received by our API
	#  	sound - the name of one of the sounds supported by device clients to override the user's default sound choice 
	

	set query [http::formatQuery token $push(cfg.push.token) user $push(cfg.push.user) device $push(dev,$user) title $title message $text]
	
	# -- send HTTP post data

	push:debug 0 "push:pub:push: sending push query: $push(cfg.push.url)?$query"
	
	catch {set tok [http::geturl $push(cfg.push.url) -query $query -keepalive 1]} error
        push:debug 1 "push:pub:push: checking for errors...(error: $error)"
        if {[string match -nocase "*couldn't open socket*" $error]} {
	        push:debug 0 "push:pub:push: could not open socket to: $push(cfg.push.url)"
		push:reply $type $target "\002(error)\002 could not open socket."
		return 0
        }

	set ncode [http::ncode $tok]
	set status [http::status $tok]
	set token $tok
	set data [http::data $tok]
	set lines [split $data \n]
	  
	# -- check for errors
	push:debug 1 "push:pub:push: checking for errors...(error: $error)"
	if {[string match -nocase "*couldn't open socket*" $error]} { 
	  push:debug 0 "push:pub:push: could not open socket to: $push(cfg.push.url)"
	  push:reply $type $target "\002(error)\002 could not open socket."
	  return 0 
	} elseif {$status == "timeout"} { 
	  push:debug 0 "push:pub:push: connection to $push(cfg.push.url) has timed out."
	  push:reply $type $target "\002(error)\002 connection timeout."
	  return 0 
	} elseif {$status == "error"} {
	  push:debug 0 "push:pub:push: connection to $push(cfg.push.url) has error."
	  push:reply $type $target "\002(error)\002 connection error."
	  return 0  
	}
	
	# -- we only want the first line
	foreach line $lines { 
	  push:debug 3 "push:pub:push: (\002wwwdata\002) $line";
	  if {[regexp -- {^ERROR:} $line]} {
	    push:debug 0 "push:pub:push: $line"
	    push:reply $type $target "[string tolower $line]"
	    return;
	  }
	  # -- notification successfully sent
	  push:reply $type $target "notification sent."
	  break;
	}
	     
	push:debug 1 "push:pub:push: notification sent (status: $status ncode: $ncode token: $token)"
	
	http::cleanup $tok
	return;

}


# -- debug proc
proc push:debug {lvl msg} {
	global push
	if {$lvl <= $push(debug)} { putloglev d * $msg }
}

# -- send text responses back to irc client
proc push:reply {type target msg} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	}
	putquick "$med $target :$msg"
}

proc push:load {} {
	global push pushadd
	foreach hand [array names pushadd] {
		lassign $pushadd($hand) dev lvl
		set push(dev,$hand) $dev
		set push(acl,$hand) $lvl
		push:debug 0 "push:add:entry: added push notification user entry: user: $hand dev: $dev acl: $lvl"	
	}
}

# -- load phonebook entries
push:load

putlog "\[@\] Armour: loaded plugin: push"
