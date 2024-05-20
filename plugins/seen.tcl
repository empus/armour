# Armour: seen
#
# Find when nicks were last seen on the channel.
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

bind join - * { arm::coroexec arm::seen:raw:join }
bind kick - * { arm::coroexec arm::seen:raw:kick }
bind part - * { arm::coroexec arm::seen:raw:part }
bind sign - * { arm::coroexec arm::seen:raw:quit }
bind splt - * { arm::coroexec arm::seen:raw:split }
bind rejn - * { arm::coroexec arm::seen:raw:rejn }
bind pubm - * { arm::coroexec arm::seen:raw:speak }
bind mode - * { arm::coroexec arm::seen:raw:mode }
bind topc - * { arm::coroexec arm::seen:raw:topic }

# -- the main command
proc seen:cmd:seen {0 1 2 3 {4 ""} {5 ""}} {
    global botnick
	variable dbchans
	lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    set cmd "seen"

	lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0]; 
    if {[string index $first 0] eq "#"} {
        set chan $first; set rest [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set rest [lrange $arg 0 end]
    }
    # -- end default proc template

	set cid [db:get id channels chan $chan]
    set ison [arm::db:get value settings setting "seen" cid $cid]
    if {$ison ne "on"} {
        # -- seen not enabled on chan
        debug 1 "\002seen:cmd:seen\002 seen not enabled on $chan. to enable, use: \002modchan $chan seen on\002"
        return;
    }

    # -- ensure user has required access for command
	set allowed [cfg:get seen:allow];   # -- who can use commands? (1-5)
                                        #        1: all channel users
									    #        2: only voiced, opped, and authed users
                                        #        3: only voiced when not secure mode, opped, and authed users
                        	            #        4: only opped and authed channel users
                                        #        5: only authed users with command access
    set allow 0
    if {$uid eq ""} { set authed 0 } else { set authed 1 }
    if {$allowed eq 0} { return; } \
    elseif {$allowed eq 1} { set allow 1 } \
	elseif {$allowed eq 2} { if {[isop $nick $chan] || [isvoice $nick $chan] || $authed} { set allow 1 } } \
    elseif {$allowed eq 3} { if {[isop $nick $chan] || ([isvoice $nick $chan] && [dict get $dbchans $cid mode] ne "secure") || $authed} { set allow 1 } } \
    elseif {$allowed eq 4} { if {[isop $nick $chan] || $authed} { set allow 1 } } \
    elseif {$allowed eq 5} { if {$authed} { set allow [userdb:isAllowed $nick $cmd $chan $type] } }
    if {[userdb:isIgnored $nick $cid]} { set allow 0 }; # -- check if user is ignored
    if {!$allow} { return; }; # -- client cannot use command
		
	if {$arg eq "" || $rest eq ""} {
		reply $type $target "\002usage:\002 seen ?chan? <nick>"
		return;
	}

	set tnick [lindex $rest 0]
	if {[string match -nocase $tnick $botnick]} {
		reply $type $target "$nick: uhh, I'm right here."
		return;
	}

	if {[string match -nocase $tnick $botnick]} {
		reply $type $target "$nick: uhh, look in the mirror."
		return;
	}

    set cid [db:get id channels chan $chan]

	set ltnick [string tolower $tnick]	
    regsub -all {\*} $ltnick "%" dbnick
    regsub -all {\?} $dbnick "_" dbnick
	set dbnick [db:escape $dbnick]

	db:connect
	set row [db:query "SELECT ts, type, nick, uhost, text FROM chanlog WHERE lower(nick) = '$dbnick' \
		AND cid=$cid ORDER BY ts DESC"]
	db:close
	set onChan [onchan $tnick $chan]
	set onAny [onchan $tnick]
	set done 0

	if {$row ne ""} {
		lassign [join $row] seenTS seenType seenNick seenUhost seenText
        set seenText [encoding convertfrom utf-8 $seenText]
        #debug 4 "seen:cmd:seen: seenTS: $seenTS -- seenType: $seenType -- seenNick: $seenNick -- seenUhost: $seenUhost -- seenText: $seenText"
		switch -- $seenType {
			JOIN   { set context "joining" }
			PART   { set context "parting" }
			QUIT   { set context "quitting" }
			SPLIT  { set context "splitting" }
			REJOIN { set context "rejoining from a split" }
			KICK   { set context "kicking" }
			KICKED { set context "being kicked" }
			SPEAK  { set context "speaking"; }
			MODE   { set context "setting a mode" }
			TOPIC  { set context "changing the topic" }
		}
		reply $type $target "\002seen:\002 $seenNick ($seenUhost) was last seen \002$context\002 [userdb:timeago $seenTS] ago."
		set done 1
	}

	# -- no rows returned
	if {!$done} {
		# -- no rows returned
		if {[onchan $tnick $chan]} {
			# -- nick is on this chan
			reply $type $target "\002seen:\002 $tnick ([getchanhost $tnick]) is here but I have not yet seen activity from them."
		} elseif {[onchan $tnick]} {
			# -- nick is not on this chan but on some other bot chan
			reply $type $target "\002seen:\002 $tnick is online ([getchanhost $tnick]) but not on this channel."
		} else {
			# -- not on any channel
			reply $type $target "\002seen:\002 $tnick has not been seen."
		}
	}

    # -- cmdlog
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] "[join $arg]" "$source" "" "" ""

}


# -- seen JOIN
proc seen:raw:join {nick uhost hand chan} {
	seen:insert JOIN $chan $nick $uhost ""
}

# -- seen PART
proc seen:raw:part {nick uhost hand chan reason} {
	seen:insert PART $chan $nick $uhost $reason
}

# -- seen QUIT
proc seen:raw:quit {nick uhost hand chan reason} {
	seen:insert QUIT $chan $nick $uhost $reason
}

# -- seen SPLIT
proc seen:raw:split {nick uhost hand chan} {
	seen:insert SPLIT $chan $nick $uhost ""
}

# -- seen REJOIN
proc seen:raw:rejn {nick uhost hand chan} {
	seen:insert REJOIN $chan $nick $uhost ""
}

# -- seen TOPIC
proc seen:raw:topic {nick uhost hand chan topic} {
	seen:insert TOPIC $chan $nick $uhost $topic
}

# -- seen MODE
proc seen:raw:mode {nick uhost hand chan mode target} {
	seen:insert MODE $chan $nick $uhost "$mode $target"
}

# -- seen KICK
proc seen:raw:kick {nick uhost hand chan vict reason} {
	seen:insert KICK $chan $nick $uhost $reason
	seen:insert KICKED $chan $vict [getchanhost $vict] $reason
}

# -- seen SPEAK
proc seen:raw:speak {nick uhost hand chan text} {
	seen:insert SPEAK $chan $nick $uhost $text
}

# -- abstract proc to insert SEEN log
proc seen:insert {type chan nick uhost text} {
	if {$chan eq [cfg:get chan:report chan]} { return; }; # -- do not update from report chan
    #if {$chan eq ""} { set chan [cfg:get chan:def] }; # -- default chan
	variable dbchans
    set cid [dict keys [dict filter $dbchans script {id dictData} { 
        expr {[string tolower [dict get $dictData chan]] eq [string tolower $chan]} 
    }]]
	set uid [db:get id users curnick $nick]
	set dbnick [db:escape $nick]
	set dbtext [db:escape [encoding convertto utf-8 $text]]
	debug 5 "seen:insert: SEEN $type -- cid: $cid -- uid: $uid -- nick: $dbnick -- uhost: $uhost -- text: $dbtext"
	db:connect
	db:query "INSERT INTO chanlog (ts, type, cid, uid, nick, uhost, text) VALUES ('[unixtime]', '$type', '$cid', '$uid', '$dbnick', '$uhost', '$dbtext')"
	db:close
}


# -- create seen
db:connect
db:query "CREATE TABLE IF NOT EXISTS chanlog (\
	id INTEGER PRIMARY KEY AUTOINCREMENT,\
	ts INT NOT NULL,\
	type TEXT NOT NULL,\
	cid INT NOT NULL,\
	uid INT,\
	nick TEXT NOT NULL,\
	uhost TEXT NOT NULL,\
	text TEXT
)"
db:close

putlog "\[A\] Armour: loaded plugin: seen"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------



