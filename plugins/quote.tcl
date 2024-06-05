# -- quote.tcl
# quote bot plugin for Armour <empus@undernet.org>
#
# 2020-07-19: upgraded for Armour v4.0
# 2021-08-04: added '+' and 'top' command options
#
# quote add <quote>
# quote add last <nick> [lines]
# quote add last <nick1,nick2,nickN..> [lines] [ignore]
# quote + <id>
# quote
# quote rand
# quote view <id>
# quote delete <id>
# quote stats [chan]
# quote search <search>
# quote top [num]
#
# TODO:
#		- adding optional cron behaviour for regular channel random quotes
#		- implement timeago locally (to work in standalone)
#		- configurable option to allow opped or voiced users to view and add quotes
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# -- default channel
# - overridden if in integrated mode
set quote(chan) "#channel"

# -- debug level (0-3) - [1]
set quote(debug) 3

# -- how long to remember last spoken lines in a channel? (mins) - 180
set cfg(lastspeak:mins) 180

# -- recently spoken lines in the last N seconds should be avoided (secs) - 2
set cfg(lastspeak:ts) 2

# -- cronjob to output random quote to channels (on the hour, every hour)
bind cron - {0 * * * *} arm::quote:cron 

# -- quote mode
# - modes:
# 0:	off
# 1:	standalone
# 2:	integrated to Armour
set quote(mode) 2

# ------------------------------------------------------------------------------------------------
# command				plugin		level req.	binds
# ------------------------------------------------------------------------------------------------
set addcmd(quote)	{	quote		0			pub msg dcc	}
set addcmd(q)		{	quote		0			pub msg dcc	}; # -- command shortcut

# -- level to delete quotes
# -- only users added to bot can delete quotes
# -- only users meeting the quote command level can delete their own quotes
# -- only users with the below level or higher can delete quotes by others
set quote(cmd:del) 100


# ---- binds
# -- integration mode handling
if {$quote(mode) eq 1} {
	bind pub - .quote quote:bind:pub:quote
	proc quote:bind:pub:quote {n uh h c a} {
		quote:cmd:quote pub $n $uh $h $c [split $a]
	}
} else {
	# -- unbind in case we changed mode during operation
	if {[lsearch [info commands] "quote:bind:pub:quote"] != "-1"} {
		catch { unbind pub - .quote quote:bind:pub:quote }
	}
	# -- load commands
	loadcmds
}


# -- track last spoken line by a nick in a channel
bind pubm - * { arm::coroexec arm::quote:pubm }; 
bind ctcp - "ACTION" { arm::coroexec arm::quote:action };

# -- command shortcut (q)
proc quote:cmd:q {0 1 2 3 {4 ""}  {5 ""}} { coroexec quote:cmd:quote $0 $1 $2 $3 $4 $5 }

# -- the main command
proc quote:cmd:quote {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
	variable quote
	variable lastspeak; # -- tracks the last line a nick spoke in a chan (by 'chan,nick')
	variable dbchans
	lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    set cmd "quote"
				
	lassign [db:get user,id users curnick $nick] user uid
	if {[string index [lindex $arg 0] 0] eq "#"} {
		# -- channel name given
		set chan [lindex $arg 0]
		set arg [lrange $arg 1 end]
	} else {
		# -- chan name not given, figure it out
		set chan [userdb:get:chan $user $chan]
	}
	set what [string tolower [lindex $arg 0]]
	set tquote [join [lrange $arg 1 end]]
	if {![quote:isEnabled $chan]} { return; }; # -- only continue if setting is on
	set cid [db:get id channels chan $chan]
	set glevel [db:get level levels cid 1 uid $uid]
	set level [db:get level levels cid $cid uid $uid]

    # -- ensure user has required access for command
    set allowed 2
    # -- ensure user has required access for command
	#set allowed [cfg:get quote:allow]; # -- who can use commands? (1-5)
                                       #        1: all channel users
									   #        2: only voiced, opped, and authed users
                                       #        3: only voiced when not secure mode, opped, and authed users
                        	           #        4: only opped and authed channel users
                                       #        5: only authed users with command access
    set allow 0
    if {$uid eq ""} { set authed 0 } else { set authed 1 }
    if {$allowed eq 0} { return; } \
    elseif {$allowed eq 1} { set allow 1 } \
    elseif {$allowed eq 2} { if {[isop $nick $chan] || ([isvoice $nick $chan] && [dict get $dbchans $cid mode] ne "secure") || $authed} { set allow 1 } } \
	elseif {$allowed eq 3} { if {[isop $nick $chan] || [isvoice $nick $chan] || $authed} { set allow 1 } } \
    elseif {$allowed eq 4} { if {[isop $nick $chan] || $authed} { set allow 1 } } \
    elseif {$allowed eq 5} { if {$authed} { set allow [userdb:isAllowed $nick $cmd $chan $type] } }
    if {[userdb:isIgnored $nick $cid]} { set allow 0 }; # -- check if user is ignored
    if {!$allow} { return; }; # -- client cannot use command

	set done 0; set uselast 0;

	# -- view random quote
	# -- rand [search]
	if {$what eq "" || $what eq "rand" || $what eq "random" || $what eq "r"} {
		# -- show random quote
		quote:debug 2 "quote:cmd:quote: random"
		# -- wrap the search in * for wildcard as a quote will never be one word
		set search $tquote
		if {[string index $search 0] ne "*"} { set search "*$search" }
		set length [string length $search]
		if {[string index $search [expr $length - 1]] ne "*"} { set search "$search*" }
		regsub -all {\*} $search {%} search
		regsub -all {\?} $search {_} search
		set search [quote:db:escape $search]
		quote:db:connect
		set query "SELECT id,nick,uhost,user,timestamp,quote FROM quotes WHERE cid='$cid' AND lower(quote) LIKE '[string tolower $search]' ORDER BY random() LIMIT 1"
		set row [join [quote:db:query $query]]
		quote:db:close
		lassign $row id tnick tuhost tuser timestamp
		set tquote [join [lrange $row 5 end]]
		if {$row eq ""} {
			# -- empty db
			quote:reply $type $target "no quote found."
			return;
		}
		set lines [split [join $tquote] \n]
		set lcount [llength $lines]
		foreach line $lines {
			quote:reply $type $target "\002\[id:\002 $id\002\]\002 [join $line]"
		}
		set done 1;
	} elseif {$what eq "view" || $what eq "v"} {
		# -- view specific quote
		set id [lindex $arg 1]
		quote:debug 2 "quote:cmd:quote: view $id"
		if {$id eq "" || ![regexp -- {^\d+$} $id]} {
			quote:reply $stype $starget "usage: quote view <id> \[-more\]"
			return;
		}
		quote:db:connect
		set query "SELECT id,nick,uhost,user,timestamp,quote FROM quotes \
			WHERE id='$id' AND cid='$cid'"
		set row [join [quote:db:query $query]]
		quote:db:close
		lassign $row id tnick tuhost tuser timestamp
		set tquote [join [lrange $row 5 end]]
		if {$id eq ""} {
			# -- no such quote
			quote:reply $type $target "no such quote."
			return;		
		}
		if {[lindex $arg 2] eq "-more"} { set more 1 } else { set more 0 }
		# -- TODO: put the timeago script locally, for standalone mode
		set added [userdb:timeago $timestamp]
		#putlog "\002quote:\002 tquote: $tquote"
		set lines [split [join $tquote] \n]
		foreach line $lines {
			quote:reply $type $target "\002\[id:\002 $id\002\]\002 [join $line]"
		}
		set done 1
		if {$tuser eq ""} {
			# -- user not authed
			if {$more} { 
				if {$tuhost ne "user@host"} {
					quote:reply $type $target "\002\[nick:\002 $tnick -- \002uhost:\002 $tuhost -- \002added:\002 $added\002\]\002"
				} else {
					quote:reply $type $target "\002\[nick:\002 $tnick -- \002added:\002 $added\002\]\002"
				}
			}			
		} else {
			# -- user was authed
			if {$more} { quote:reply $type $target "\002\[user:\002 $tuser -- \002bywho:\002 $tnick!$tuhost -- \002added:\002 $added\002\]\002" }
		}
		
	# -- search quotes
	} elseif {$what eq "search" || $what eq "s"} {
		# -- search for quotes
		set search [string tolower [lindex $arg 1]]
		set searchu [lindex $arg 2]
		quote:debug 2 "quote:cmd:quote: search $search $searchu"
		if {$search eq ""} {
			quote:reply $stype $starget "usage: quote search <pattern> ?-user|-nick <source>?"
			return;
		}
		# -- wrap the search in * for wildcard as a quote will never be one word
		if {[string index $search 0] ne "*"} { set search "*$search" }
		set length [string length $search]
		if {[string index $search [expr $length - 1]] ne "*"} { set search "$search*" }
		regsub -all {\*} $search {%} search
		regsub -all {\?} $search {_} search
		
		set dbsearch [quote:db:escape $search]
		if {$searchu eq "-user"} {
			set usearch [quote:db:escape [string tolower [lindex $arg 3]]]
			set xtra "WHERE lower(quote) LIKE '[string tolower $dbsearch]' AND user LIKE '$usearch'"
		} elseif {$searchu eq "-nick"} {
			set nsearch [quote:db:escape [string tolower [lindex $arg 3]]]
			set xtra "WHERE lower(quote) LIKE '[string tolower $dbsearch]' AND lower(nick) LIKE '[string tolower $nsearch]'"
		} else {
			set xtra "WHERE lower(quote) LIKE '[string tolower $dbsearch]'"
		}
		quote:db:connect
		set query "SELECT id,nick,uhost,user,timestamp,quote FROM quotes $xtra AND cid='$cid'"
		set res [quote:db:query $query]
		quote:db:close
		if {$res eq ""} {
			# -- empty db
			quote:reply $type $target "0 results found."
			return;
		}
		set i 0;
		set results [llength $res]
		foreach row $res {
			incr i
			lassign $row id tnick tuhost tuser timestamp
			set tquote [join [lrange $row 5 end]]
			if {($type eq "pub" && $i eq "4") || ($type eq "msg" && $i eq "6") \
				|| ($i eq "11")} {
					quote:reply $type $target "too many results found ($results), please refine search."
					return;
			}
			set lines [split [join $tquote] \n]
			foreach line $lines {
				quote:reply $type $target "\[id: $id\] [join $line]"
			}
			#if {$i < $results} { quote:reply $type $target "-" }; # -- multi-line quotes are less common; line break not really needed
		}
		if {$i eq 1} {
			quote:reply $type $target "search complete ($i result found)."
		} else {
			quote:reply $type $target "search complete ($i results found)."
		}
		set done 1;
	# -- delete quote
	} elseif {$what eq "del" || $what eq "rem" || $what eq "d"} {
		# -- delete existing quote
		set id [lindex $arg 1]
		quote:debug 2 "quote:cmd:quote: delete $id"
		if {$id eq "" || ![regexp -- {^\d+$} $id]} {
			quote:reply $stype $starget "usage: quote del <id>"
			return;
		}
		quote:db:connect
		set query "SELECT id,user FROM quotes WHERE id='$id' AND cid='$cid'"
		set row [join [quote:db:query $query]]		
		set id [lindex $row 0] 
		set tuser [lindex $row 1]
		set allow 0
		if {$quote(mode) eq 2} {
			# -- integrated to Armour
			if {[string tolower $user] eq [string tolower $tuser]} {
				# -- deleter is author
				set allow 1
			}
		}
		# -- check chan and global level
		if {$level < $quote(cmd:del) && $glevel < $quote(cmd:del) && !$allow} {
			quote:reply $type $target "access denied."
			return;
		}
		if {$id eq ""} {
			# -- no such quote
			quote:reply $type $target "no such quote."
			quote:db:close
			return;		
		}
		set query "DELETE FROM quotes WHERE id='$id'"
		set res [quote:db:query $query]
		quote:reply $type $target "done."
		set done 1;

		# -- twitter
		if {[info command ::twitlib::query] ne "" && [twitter:isEnabled $chan 1]} {
			quote:debug 0 "quote:cmd:quote twitlib loaded (del)"
			set tid [db:get tid tweets qid $id]
			if {[catch {::twitlib::query ${::twitlib::delete_url}/${tid}.json "" POST} result]} {
				quote:debug 0 "quote:cmd:quote: \002tweet error:\002 $result"
				if {$result eq "OAuth not initialised."} {
					putnotc [cfg:get chan:report $chan] "Armour: \002twitter OAuth error\002 -- not initialised"
				}
				quote:db:close
				return;
			} else {
				set query [quote:db:query "DELETE FROM tweets WHERE tid='$tid'"]
				quote:debug 0 "quote:cmd:quote: deleted tweet from tweets table (tid: $tid -- qid: $id)"
			}
		}
		quote:db:close
	
	# -- add last line spoken
	} elseif {$what eq "last" || $what eq "l"} {
		set uselast 1;
		set tnick [lindex $arg 1]; # -- can be multiple nicks, comma deliminated
		set lines [lindex $arg 2]
		set ignore [lindex $arg 3]; # -- ignore the last N lines from the list of nicks (as a total)
		set tnicks [split $tnick ,]

		# -- handle optional newline param (-nl)
		set newline 0
		set all [lrange $arg 1 end]
		set length [llength $all]
		set last [lindex $all [expr $length -1]]
		if {[string match "-n*" $last]} {
			debug 0 "\002quote:\002 newline is on"
			set newline 1
		}

		if {$tnick eq ""} { set tnick "*"}; # -- default to the last nick who spoke
		if {$lines <= 0} { set lines 1 } elseif {$lines eq ""} { set lines 1 }; # -- default to 1 x line
		if {$lines eq 1 && [llength $tnicks] > 1} { set lines [llength $tnicks]}
		if {$ignore eq ""} { set ignore 0 }; # -- ignore zero lines by default

		set ltnick [string tolower $tnick]
		set sorted [join [lsort -decreasing [array names lastspeak]]]
		set found 0; set repeat 0; set count 0; set lquote [list]; set tquote ""; set asort [list]; set icount 0
		foreach key $sorted {
			lassign [split $key ,] tchan tts atnick
			debug 3 "\002quote:\002 looping: key: tchan: $tchan -- tts: $tts: -- $atnick: [join $atnick] -- chan: $chan -- ltnick: $ltnick -- lines: $lines"
			debug 3 "\002quote:\002 lastspeak line: [get:val lastspeak $tchan,$tts,$atnick]"
			if {[string tolower $chan] ne [string tolower $tchan]} { continue; }
			debug 4 "atnick: $atnick -- tnicks: $tnicks"
			if {[string tolower [join $atnick]] in [string tolower $tnicks] || $tnick eq "*"} {
				# -- nick match
				set secs [expr $tts / 1000]; # -- go from milisecs to secs
				set race [cfg:get lastspeak:ts $chan]
				if {$secs >= [expr [clock seconds] - $race]} { continue; }; # -- ignore this line, it's too recent
				if {$ignore > 0 && $icount < $ignore} { incr icount; continue; }; # -- ignore the last N lines from the list of nicks (as a total)
				set found 1; # -- mark it as found
				debug 3 "\002quote:\002 appending lquote: [get:val lastspeak $tchan,$tts,$atnick] -- count: $count"
				lappend asort $tts,$atnick
				set repeat 1;
				incr count
			}
			# -- stop when we have reached the required line count
			if {$count eq $lines} {
				set ascending [lsort -increasing $asort]
				foreach tsnick $ascending {
					if {$newline} { set xtra "\\n" } else { set xtra "" }
					append tquote "  [get:val lastspeak $tchan,$tsnick] $xtra"
				}
				break;
			}
		}

		if {$found eq 0} {
			quote:reply $type $target "\002error:\002 no line history tracking for $tnick"
			return;
		}
		
		set tquote [string trimleft $tquote "  "]; # -- strip leading spaces
		set tquote [string trimright $tquote "\\n"]; # -- strip trailing newlines

		#putlog "\002quote\002: tquote: $tquote"

		# -- force the normal add
		set what "add"
	}

	# -- add new quote
	if {$what eq "add" || $what eq "a"} {
		set repeat 0;
		# -- add new quote
		if {![isop $nick $chan] && ![isvoice $nick $chan] && ($level < $quote(cmd:del))} {
			quote:reply $type $target "access denied."
			return;		
		}
		
		quote:debug 2 "quote:cmd:quote: add $tquote"
		if {$tquote eq ""} {
			quote:reply $stype $starget "usage: quote add <quote>"
			return;
		}
		set dbnick [quote:db:escape $nick]
		set dbuhost [quote:db:escape $uh]
		set dbuser [quote:db:escape $user]
		set timestamp [clock seconds]
		set dbquote [quote:db:escape $tquote]
		quote:db:connect
		set query "INSERT INTO quotes (cid,nick,uhost,user,timestamp,quote) \
			VALUES ('$cid','$dbnick','$dbuhost','$dbuser','$timestamp','$dbquote')"
		set res [quote:db:query $query]
		set rowid [quote:db:last:rowid]
		if {$repeat eq 0} {
			quote:reply $type $target "done. (\002id:\002 $rowid)"
		} else {
			quote:reply $type $target "done. (\002id:\002 $rowid -- \002quote:\002 $tquote)"; # -- TODO: this isn't being used at the moment. too verbose?
		}
		quote:db:close
		set done 1;

		# -- twitter
		if {[info command ::twitlib::query] ne "" && [twitter:isEnabled $chan 1]} {
			quote:debug 0 "quote:cmd:quote twitlib loaded (add)"
			if {$uselast} {
				set twitquote "\[id: $rowid\] $tquote"
			} else {
				set twitquote "\[id: $rowid\] <$nick> $tquote"
			}
			
			if {[catch {::twitlib::query $::twitlib::status_url [list status $twitquote]} result]} {
				quote:debug 0 "quote:cmd:quote: \002tweet error:\002 $result"
				if {$result eq "OAuth not initialised."} {
					putnotc [cfg:get chan:report $chan] "Armour: \002twitter OAuth error\002 -- not initialised"
				}
				return
			} else {
				quote:debug 0 "quote:cmd:quote: tweet success: $tquote"
				set idstring [lrange $result 2 3]
				quote:debug 0 "quote:cmd:quote: idstring: $idstring"
				if {[lindex $idstring 0] eq "id"} {
					set tid [lindex $idstring 1]
					# -- insert tweetID into tweets table alongside quoteid for future deletions
					set query [db:query "INSERT INTO tweets (tid,qid) VALUES ('$tid','$rowid')"]
					quote:debug 0 "quote:cmd:quote: inserted tweet into tweets table (tid: $tid -- qid: $rowid)"
				}
			}
		}

	} elseif {$what eq "stats"} {
		# -- return quote stats
		set tchan [lindex $arg 1]
		# -- allow stats to have optional channel (incl. * for global)
		set glob 0; set isuser 0;
		if {[string index $tchan 0] != "#" && $tchan != "*" && $tchan != ""} { set isuser 1; set tuser $tchan }; # -- stats for a single user
		if {$tchan ne "" && $isuser eq 0} {
			if {$tchan eq "*"} {
				# -- global
				if {$glevel < $quote(cmd:del)} {
					quote:reply $type $target "access denied."
					return;
				}
				set glob 1
			} else {
				set cid [db:get id channels chan $tchan]
				if {$cid eq "" || $cid eq 0} {
					quote:reply $type $target "error: no such channel."
					return;
				}
				set tlevel [db:get level levels cid $cid uid $uid]
				if {$tlevel < $quote(cmd:del) && $glevel < $quote(cmd:del)} {
					quote:reply $type $target "access denied."
					return;
				}				
			}
		}

		set query1 "SELECT count(id) FROM quotes"
		set query2 "SELECT user,count(*) as total FROM quotes WHERE user!=''"
		if {!$glob} { append query1 " WHERE cid='$cid'"; append query2 " AND cid='$cid'" }

		# -- stats for a single user;
		if {$isuser} {
			lassign [db:get id,user users user $tuser] tuid tuser
			if {$tuser eq ""} {
				quote:reply $type $target "no such user."
				return;
			}
			if {$glob} { 
				append query1 " WHERE user='$tuser'"
			} else { 
				append query1 " AND user='$tuser'"
			}
			append query2 " AND user='$tuser'"
		}

		quote:db:connect
		append query2 " GROUP BY user ORDER BY total DESC LIMIT 10"

		set res1 [quote:db:query $query1]
		set count [lindex $res1 0]
		if {$count eq 0} {
			if {$isuser} {
				quote:reply $type $target "no authenticated quotes from $tuser."
			} else {
				quote:reply $type $target "quote db is empty."
			}
			quote:db:close	
			return;
		}

		set top ""
		set res2 [quote:db:query $query2]
		foreach pair $res2 {
			lassign $pair cuser ctotal
			append top "$cuser ($ctotal), "
		}
		set top [string trimright $top ", "]

		set query "SELECT timestamp FROM quotes"
		if {$glob eq 0} { set first "$query WHERE cid='$cid'"; set last "$query WHERE cid='$cid'" } \
		else { set first $query; set last $query }
		if {$isuser} {
			append first " AND user='$tuser'"
			append last " AND user='$tuser'"
		}
		set first "$first ORDER BY timestamp ASC LIMIT 1"
		set last "$last ORDER BY timestamp DESC LIMIT 1"

		set first [join [lindex [quote:db:query $first] 0]]
		set last [join [lindex [quote:db:query $last] 0]]
		
		quote:db:close
		# -- TODO: move timeago locally to work in standalone
		set firstago [userdb:timeago $first]
		set lastago [userdb:timeago $last]
		quote:reply $type $target "\002quotes:\002 $count -- \002first:\002 $firstago ago -- \002last:\002 $lastago ago"
		if {$top ne "" && $isuser eq 0} {
			quote:reply $type $target "\002top 10 authed quoters:\002 $top"
		}
		set done 1;

	} elseif {$what eq "+" || $what eq "vote"} {
		# -- vote for quote
		if {![isop $nick $chan] && ![isvoice $nick $chan] && ($level < $quote(cmd:del))} {
			quote:reply $type $target "access denied."
			return;		
		}
		set qid $tquote
		if {$qid eq ""} {
			quote:reply $stype $starget "usage: quote + <id>"
			return;
		}
		quote:debug 2 "quote:cmd:quote: increase score for quote id=$qid"
		set qid [quote:db:escape $qid]
		quote:db:connect
		set query "SELECT id,score FROM quotes WHERE cid='$cid' AND id='$qid'"
		set row [join [quote:db:query $query]]
		quote:debug 2 "quote: row: $row"
		lassign $row dbid score
		if {$dbid eq ""} { 
			quote:reply $stype $starget "no such quote."
			quote:db:close
			return;
		}
		set nscore [incr score]
		quote:debug 2 "quote:cmd:quote: increasing quote score (id: $qid -- cid: $cid -- score: $score -- newscore: $nscore)"
		set query "UPDATE quotes SET score='$nscore' WHERE id='$qid' AND cid='$cid'"
		set res [quote:db:query $query]
		quote:reply $type $target "done. (\002votes:\002 $nscore)"
		quote:db:close
		set done 1;

	} elseif {$what eq "t" || $what eq "top"} {
		if {![isop $nick $chan] && ![isvoice $nick $chan] && ($level < $quote(cmd:del))} {
			quote:reply $stype $starget "access denied."
			return;		
		}
		set num $tquote
		if {$num eq "" || $num eq 0} { set num 1 }; # -- number of results
		if {![regexp -- {^\d+$} $num]} {
			quote:reply $stype $starget "usage: quote top \[num\]"
			return;
		}
		set max 0
		if {$num > 5} { set max 1; set num 5; }

		quote:debug 2 "quote:cmd:quote: top vote scorers (num: $num)"
		quote:db:connect
		set rows [quote:db:query "SELECT id,quote,score FROM quotes WHERE cid='$cid' AND score!='0' ORDER BY score DESC LIMIT $num"]
		quote:debug 2 "quote: rows: $rows"
		if {$rows eq ""} { 
			quote:reply $stype $starget "no quote votes cast.  \002usage:\002 quote + <id>"
			quote:db:close
			return;
		}
		set count 0
		foreach row $rows {
			lassign $row dbid dbquote votes
			set lines [split [join $dbquote] \n]
			foreach line $lines {
				quote:reply $type $target "\002\[id:\002 $dbid -- \002votes:\002 $votes\002\]\002 [join $line]"
			}
			incr count;
		}

		if {$count < $num} { quote:reply $stype $starget "only $count quotes found with votes cast." }
		if {$max} { quote:reply $stype $starget "maximum of 5 results displayed."; }
		quote:db:close
		set done 1;
	}

	if {$done} {
		# -- create log entry for command use (if integrated to Armour)
		if {$quote(mode) eq 2} { log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] "[join $arg]" "$source" "" "" "" }
	}
}

# -- find the most recent line that matches a correction regex
proc quote:correct {chan regex} {
	global botnick;
	variable lastspeak; # -- tracks the last line a nick spoke in a chan (by 'chan,nick')
	variable dbchans;   # -- dict for db channels

	set cid [dict keys [dict filter $dbchans script {id dictData} { expr {[dict get $dictData chan] eq $chan} }]]
	if {$cid eq ""} { return; }; # -- channel not registered
	if {[dict exists $dbchans $cid correct]} {
		set correct [dict get $dbchans $cid correct]
		if {$correct eq "off" || $correct eq ""} { return; }; # -- 'correct' channel setting not on
	} else { return; }; # -- 'correct' channel setting not on

	if {![regexp {^s/([^\/]*)/([^\/]*)/$} $regex -> match new]} { return; }; # -- must be a correction regex
	if {$new ne ""} { set new "\002$new\002" }
	set chanlines [lsort -decreasing [array names lastspeak $chan,*]]
	foreach entry $chanlines {
		#debug 4 "quote:correct: checking line: $lastspeak($entry)"
		set line $lastspeak($entry)
		if {[lindex $line 0] eq "<$botnick>"} { continue; }; # -- skip bot lines
		if {[regexp {^<[^>]+> s/} $line]} { continue; }; # -- skip correction prvimsg lines
		if {[regsub -all $match $line $new newline]} {
			#debug 4 "quote:correct: match found (chan: $chan -- regex: $regex) -- line: $line"
			debug 1 "quote:correct: line in $chan replaced with: $newline"
			return $newline
		}
	}
	debug 1 "quote:correct: no match found (chan: $chan -- regex: $regex)"
	return; # -- no match found
}

# -- cronjob to output regular random quotes
proc quote:cron {minute hour day month weekday} { 
	variable dbchans; # -- dict containing channel data

	debug 0 "\002quote:cron:\002 starting -- minute: $minute -- hour: $hour -- month: $month -- weekday: $weekday"
	quote:db:connect
	# -- do for each channel where quoterand is enabled
	set cids [quote:db:query "SELECT cid FROM settings WHERE setting='quoterand' AND value='on'"]
	foreach cid $cids {
		set chan [dict get $dbchans $cid chan]
		if {![botonchan $chan]} { continue; }; # -- don't bother if not in chan
		set randid [quote:db:query "SELECT id FROM quotes WHERE cid='$cid' ORDER BY RANDOM() LIMIT 1"]
		set query "SELECT quote FROM quotes WHERE id='$randid' AND cid='$cid'"
		set quote [join [quote:db:query $query]]
		debug 0 "\002quote:cron\002 sending periodic random quote to $chan: [join $quote]"
		set lines [split [join $quote] \n]
		foreach line $lines {
			quote:reply msg $chan "\002\[id:\002 $randid\002\]\002 [join $line]"
		}
	}
	quote:db:close
} 


# -- debug proc
proc quote:debug {lvl msg} {
	variable quote
	if {$lvl <= $quote(debug)} { putloglev d * $msg }
}

# -- send text responses back to irc client
proc quote:reply {type target msg} {
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

# -- escape special chars in array
proc quote:escape {value} {
	regsub -all {\[} $value {\\[} nvalue
	regsub -all {\]} $nvalue {\\]} nvalue
	regsub -all {\{} $nvalue {\\{} nvalue
	regsub -all {\}} $nvalue {\\}} nvalue
	if {$value ne $nvalue} { quote:debug 2 "quote:escape: value $value is now $nvalue" }
	return $nvalue;
}

# -- remember the last line a nick spoke in a given channel (privmsg)
proc quote:pubm {nick uhost hand chan text} {
	# -- check for correction regex
	if {[regexp {^s/([^\/]*)/([^\/]*)/$} $text]} {
		set newline [quote:correct $chan $text]
		if {$newline ne ""} {
			quote:reply msg $chan "\002correction,\002 $newline"
			return;
		}
	}
	quote:addspeak $nick $uhost $hand [string tolower $chan] "<$nick> $text";
}

# -- remember the last line a nick spoke in a given channel (action)
proc quote:action {nick uhost hand dest keyword text} { 
	# -- only process channel actions 
	if {[string index $dest 0] ne "#"} { return; }
	set action "* $nick $text"

	# -- check for correction regex
	if {[regexp {^s/([^\/]*)/([^\/]*)/$} $action]} {
		set newline [quote:correct $chan $action]
		if {$newline ne ""} {
			quote:reply msg $chan "\002correction,\002 $newline"
			return;
		}
	}
	quote:addspeak $nick $uhost $hand [string tolower $dest] $action
}

# -- remember the last line a nick spoke in a given channel
proc quote:addspeak {nick uhost hand chan text} {
	variable dbchans;   # -- dict with database channels
	variable lastspeak; # -- tracks the last line a nick spoke in a chan (by 'chan,ts,nick')
	set cid [dict keys [dict filter $dbchans script {id dictData} { expr {[dict get $dictData chan] eq $chan} }]]
	if {$cid eq ""} { return; }; # -- channel not registered
	set snick [split $nick]
	set ts [clock milliseconds]; # -- track when spoken, to have race condition mitigation when someone does 'quote add last <nick>' and they very recently spoke something else
	set lastspeak($chan,$ts,$snick) $text
	timer [cfg:get lastspeak:mins $chan] "arm::quote:unset:lastspeak $chan $ts $snick"
}

# -- unset the lastspeak
proc quote:unset:lastspeak {chan ts nick} {
	variable lastspeak; # -- tracks the last line a nick spoke in a chan (by 'chan,ts,nick')
	arm::debug 5 "quote:unset:lastspeak: unsetting lastspeak($chan,$ts,$nick)"; 
	unset lastspeak($chan,$ts,[split $nick])
}

# -- check if quote is enabled on a channel
proc quote:isEnabled {chan} {
	set cid [db:get id channels chan $chan]
	if {$cid eq ""} { return 0; }
	set enabled [db:get value settings setting quote cid $cid]
	if {$enabled eq "" || $enabled eq 0 || $enabled eq "off"} { return 0; }
	return 1; # -- must be enabled!
}


# -- load sqlite (or at least try)
if {[catch {package require sqlite3} fail]} {
	debug 0 "error loading sqlite3 library.  unable to load Armour SQL DB functions."
	return false
}


# -- db connect
proc quote:db:connect {} { sqlite3 quotesql "./armour/db/$::arm::dbname.db" }
# -- escape chars
proc quote:db:escape {what} { return [string map {' ''} $what] }
proc quote:db:last:rowid {} { quotesql last_insert_rowid }

# -- query abstract
proc quote:db:query {query} {
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
proc quote:db:close {} { quotesql close }

# -- connect attempt
if {[catch {quote:db:connect} fail]} {
	putlog "\[@\] unable to create sqlite database. check directory permissions."
	return false
}

# -- create quotes
quote:db:query "CREATE TABLE IF NOT EXISTS quotes (\
	id INTEGER PRIMARY KEY AUTOINCREMENT,\
	cid INTEGER NOT NULL DEFAULT '1',\
	nick TEXT NOT NULL,\
	uhost TEXT NOT NULL,\
	user TEXT,\
	timestamp INT NOT NULL,\
	quote TEXT NOT NULL,\
	score INTEGER DEFAULT '0'
	)"
	
quote:db:close

putlog "\[@\] Armour: loaded plugin: quote"

}
# -- end of namespace