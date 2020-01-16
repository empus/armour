# -- quote.tcl
# quote bot plugin for Armour <empus@undernet.org>
# 2020.01.09
#
# TODO:
#		- adding optional cron behaviour for regular channel random quotes
#		- implement timeago locally (to work in standalone)

# -- default channel
# - overridden if in integrated mode
set quote(chan) "#channel"

# -- debug level (0-3) - [1]
set quote(debug) 3

# -- quote mode
# - modes:
# 0:	off
# 1:	standalone
# 2:	integrated to Armour
set quote(mode) 2


# -----------------------------------------------------------------------------
# command				plugin		level req.	binds
# -----------------------------------------------------------------------------
set addcmd(quote)	{	quote		0			pub msg dcc	}
# -- command shortcut
set addcmd(q)		{	quote		0			pub msg dcc	}

# -- level to delete quotes
# -- only users added to bot can delete quotes
# -- only users meeting the quote command level can delete their own quotes
# -- only users with the below level or higher can delete quotes by others
set quote(cmd.del) 100


# ---- binds
# -- integration mode handling
if {$quote(mode) == 1} {
	bind pub - .quote quote:bind:pub:quote
	proc quote:bind:pub:quote {n uh h c a} {
		quote:cmd:quote pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind in case we changed mode during operation
	catch { unbind pub - .quote quote:pub:quote }
	# -- load commands
	arm:loadcmds
}

# -- command shortcut (q)
proc quote:cmd:q {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec quote:cmd:quote $0 $1 $2 $3 $4 $5 }

# -- the main command
proc quote:cmd:quote {0 1 2 3 {4 ""}  {5 ""}} {
	global arm quote
	set type $0

	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {$quote(mode) == 2} { if {![userdb:isValidchan $chan]} { return; } }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick;
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $quote(chan) }
		set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; 
		if {[info exists arm(cfg.chan.def)]} { set chan $arm(cfg.chan.def) } else { set chan $quote(chan) }
		set source "$hand/$idx"
	}
	
	set cmd "quote"
	quote:debug 1 "quote:cmd:quote: $args"
	
	# -- check for integration mode
	if {$quote(mode) == 2} {
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
		
	set what [string tolower [lindex $args 0]]

	# -- view random quote
	if {$what == "" || $what == "rand" || $what == "random" || $what == "r"} {
		# -- show random quote
		quote:debug 2 "quote:cmd:quote: random"
		::quotedb::db_connect
		set query "SELECT id,nick,uhost,user,timestamp,quote FROM quotes \
			ORDER BY random() LIMIT 1"
		set row [join [::quotedb::db_query $query]]
		::quotedb::db_close
		lassign $row id tnick tuhost tuser timestamp
		set tquote [join [lrange $row 5 end]]
		if {$row == ""} {
			# -- empty db
			quote:reply $type $target "quote db empty."
			return;
		}
		if {$tuser == ""} {
			# -- user was not authed
			quote:reply $type $target "\[id: $id\] $tquote"
			return;
		} else {
			# -- user was authed
			quote:reply $type $target "\[id: $id\] $tquote"
			return;
		}
		
	# -- view specific quote
	} elseif {$what == "view" || $what == "v"} {
		# -- view specific quote
		set id [lindex $args 1]
		quote:debug 2 "quote:cmd:quote: view $id"
		if {$id == "" || ![regexp -- {^\d+$} $id]} {
			quote:reply $type $target "usage: quote view <id> \[-more\]"
			return;
		}
		::quotedb::db_connect
		set query "SELECT id,nick,uhost,user,timestamp,quote FROM quotes \
			WHERE id='$id'"
		set row [join [::quotedb::db_query $query]]
		::quotedb::db_close
		lassign $row id tnick tuhost tuser timestamp
		set tquote [join [lrange $row 5 end]]
		if {$id == ""} {
			# -- no such quote
			quote:reply $type $target "no such quote."
			return;		
		}
		if {[lindex $args 2] == "-more"} { set more 1 } else { set more 0 }
		# -- TODO: put the timeago script locally, for standalone mode
		set added [userdb:timeago $timestamp]
		if {$tuser == ""} {
			# -- user was not authed
			quote:reply $type $target "\[id: $id\] $tquote"
			if {$more} { quote:reply $type $target "\[nick: $tnick -- uhost: $tuhost -- added: $added\]" }
			
			return;
		} else {
			# -- user was authed
			quote:reply $type $target "\[id: $id\] $tquote"
			if {$more} { quote:reply $type $target "\[user: $tuser -- bywho: $tnick!$tuhost -- added: $added\]" }
			return;
		}
		
	# -- search quotes
	} elseif {$what == "search" || $what == "s"} {
		# -- search for quotes
		set search [string tolower [lindex $args 1]]
		quote:debug 2 "quote:cmd:quote: search $search"
		if {$search == ""} {
			quote:reply $type $target "usage: quote search <pattern>"
			return;
		}
		regsub -all {\*} $search {%} search
		regsub -all {\?} $search {_} search
		set dbsearch [::armdb::db_escape $search]		
		::quotedb::db_connect
		set query "SELECT id,nick,uhost,user,timestamp,quote FROM quotes \
			WHERE user LIKE '$dbsearch' OR nick LIKE '$dbsearch' OR quote LIKE '$dbsearch'"
		set res [::quotedb::db_query $query]
		::quotedb::db_close
		if {$res == ""} {
			# -- empty db
			quote:reply $type $target "0 results found."
			return;
		}
		set i 0
		set results [llength $res]
		foreach row $res {
			lassign $row id tnick tuhost tuser timestamp
			set tquote [join [lrange $row 5 end]]
			if {($type == "pub" && $i == "3") || ($type == "msg" && $i == "5") \
				|| ($i == "10")} {
					quote:reply $type $target "too many results found ($results), please refine search."
					return;
			} 
			quote:reply $type $target "\[id: $id\] $tquote"
			incr i
		}
		quote:reply $type $target "search complete ($i results found)."
		return;
		
	# -- delete quote
	} elseif {$what == "del" || $what == "rem" || $what == "d"} {
		# -- delete existing quote
		set id [lindex $args 1]
		quote:debug 2 "quote:cmd:quote: delete $id"
		if {$id == "" || ![regexp -- {^\d+$} $id]} {
			quote:reply $type $target "usage: quote del <id>"
			return;
		}
		::quotedb::db_connect
		set query "SELECT id,user FROM quotes WHERE id='$id'"
		set row [join [::quotedb::db_query $query]]		
		set id [lindex $row 0] 
		set tuser [lindex $row 1]
		set allow 0
		if {$quote(mode) == 2} {
			# -- integrated to Armour
			set tuser [userdb:uline:get user user $user]
			if {[string tolower $user] == [string tolower $tuser]} {
				# -- deleter is author
				set allow 1
			}
		}
		if {$level < $quote(cmd.del) && !$allow} {
			quote:reply $type $target "access denied."
			return;
		}
		if {$id == ""} {
			# -- no such quote
			quote:reply $type $target "no such quote."
			::quotedb::db_close
			return;		
		}
		set query "DELETE FROM quotes WHERE id='$id'"
		set res [::quotedb::db_query $query]
		::quotedb::db_close
		quote:reply $type $target "done."
		return;
		
	# -- add new quote
	} elseif {$what == "add" || $what == "a"} {
		# -- add new quote
		if {![isop $nick $chan] && ![isvoice $nick $chan]} {
			quote:reply $type $target "access denied."
			return;		
		}
		set tquote [join [lrange $args 1 end]]
		quote:debug 2 "quote:cmd:quote: add $tquote"
		if {$tquote == ""} {
			quote:reply $type $target "usage: quote add <quote>"
			return;
		}
		set dbnick [::quotedb::db_escape $nick]
		set dbuhost [::quotedb::db_escape $uh]
		set dbuser [::quotedb::db_escape $user]
		set timestamp [clock seconds]
		set dbquote [::quotedb::db_escape $tquote]
		::quotedb::db_connect
		set query "INSERT INTO quotes (nick,uhost,user,timestamp,quote) \
			VALUES ('$dbnick','$dbuhost','$dbuser','$timestamp','$dbquote')"
		set res [::quotedb::db_query $query]
		set rowid [::quotedb::db_last_rowid]
		quote:reply $type $target "done. (id: $rowid)"
		return;
	}
}


# -- debug proc
proc quote:debug {lvl msg} {
	global quote
	if {$lvl <= $quote(debug)} { putloglev d * $msg }
}

# -- send text responses back to irc client
proc quote:reply {type target msg} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	}
	putquick "$med $target :$msg"
}

# -- namespace for sqlite3 functions
namespace eval quotedb {
# -- load sqlite (or at least try)
if {[catch {package require sqlite3} fail]} {
	putlog "\[@\] error loading sqlite3 library.  unable to load Armour SQL DB functions."
	return false
}

# -- db connect
proc db_connect {} { sqlite3 quotesql $::userdb(sqlite) }
# -- escape chars
proc db_escape {what} { return [string map {' ''} $what] }
proc db_last_rowid {} { quotesql last_insert_rowid }

# -- query abstract
proc db_query {query} {
	set res {}
	quotesql eval $query v {
		set row {}
		foreach col $v(*) {
			lappend row $v($col)
		}
		lappend res $row
	}
	return $res
}
# -- db close
proc db_close {} { quotesql close }

# -- connect attempt
if {[catch {db_connect} fail]} {
	putlog "\[@\] unable to create sqlite database. check directory permissions."
	return false
}

# -- create quotes
db_query "CREATE TABLE IF NOT EXISTS quotes (\
	id INTEGER PRIMARY KEY AUTOINCREMENT,\
	nick TEXT NOT NULL,\
	uhost TEXT NOT NULL,\
	user TEXT,\
	timestamp INT NOT NULL,\
	quote TEXT NOT NULL\
	)"
	
db_close
}

putlog "\[@\] Armour: loaded plugin: quote"
