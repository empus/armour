# ------------------------------------------------------------------------------------------------
# armour.tcl v3.4.4 autobuild completed on: Sun Jan 19 06:23:53 PST 2020
# ------------------------------------------------------------------------------------------------
#
#    _                         ___ ___ 
#   /_\  _ _ _ __  ___ _  _ _ |_ _| _ \
#  / _ \| '_| '  \/ _ \ || | '_| ||  _/
# /_/ \_\_| |_|_|_\___/\_,_|_||___|_|  
#
#
# Anti abuse script for eggdrop bots on the Undernet IRC Network
#
# ------------------------------------------------------------------------------------------------
#
# Do not edit this code unless you really know what you are doing
#
# check for updates @ http://code.empus.com/armour
#
# - 	Empus
#	empus@undernet.org
#
# ------------------------------------------------------------------------------------------------




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-01_depends.tcl
#
# script dependencies
#

# -- script version
set arm(version) "v"

# -- we require Tcl 8.6 for coroutines now
package require Tcl 8.6

proc bgerror {message} { 
 putloglev d * "\002(bgError)\002: \"$message\":" 
 foreach line [split $::errorInfo "\n"] { 
  putloglev d * "  $line" 
 } 
 putloglev d * "b(\002gError)\002: errorCode: $::errorCode" 
}

# -- debug proc -- we use this alot
proc arm:debug {level string} {
	global arm
	#if {$level <= $arm(debug)} { putloglev d * "$string"; }
	if {$level == 0} { putlog "$string"; } elseif {$level <= $arm(debug)} { putloglev d * "$string"; }
}

# -- config variable fixes
set userdb(cfg.db.file) $arm(cfg.db.users)
set scan(cfg.ban.time) $arm(cfg.ban.time)
set userdb(method) $arm(method)
set userdb(sqlite) $arm(sqlite)

# -- remove trailing / if exists
set arm(cfg.dir.prefix) [string trimright $arm(cfg.dir.prefix) /]

arm:debug 0 "\[@\] Armour: loaded script configuration."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-02_unbinds.tcl 
#
# restructure default eggdrop binds
# takes the bot to barebones & high security
#

bind ctcp -|- FINGER *ctcp:FINGER
bind ctcp -|- ECHO *ctcp:ECHO
bind ctcp -|- ERRMSG *ctcp:ERRMSG
bind ctcp -|- USERINFO *ctcp:USERINFO
bind ctcp -|- CLIENTINFO *ctcp:CLIENTINFO
bind ctcp -|- TIME *ctcp:TIME
bind ctcp -|- CHAT *ctcp:CHAT

unbind ctcp -|- FINGER *ctcp:FINGER
unbind ctcp -|- ECHO *ctcp:ECHO
unbind ctcp -|- ERRMSG *ctcp:ERRMSG
unbind ctcp -|- USERINFO *ctcp:USERINFO
unbind ctcp -|- CLIENTINFO *ctcp:CLIENTINFO
unbind ctcp -|- TIME *ctcp:TIME

# -- dcc chat?
# unbind ctcp -|- CHAT *ctcp:CHAT
bind ctcp -|- ADMIN *ctcp:CHAT

# -- rebind VERSION & TIME
bind ctcp - "VERSION" arm:ctcp:version
bind ctcp - "TIME" arm:ctcp:time

bind msg m|m status *msg:status 
bind msg -|- pass *msg:pass 
bind msg n|- die *msg:die 
bind msg -|- ident *msg:ident 
bind msg -|- help *msg:help
bind msg -|- info *msg:info 
bind msg o|o invite *msg:invite 
bind msg m|- jump *msg:jump 
bind msg m|- memory *msg:memory 
bind msg m|- rehash *msg:rehash 
bind msg -|- voice *msg:voice 
bind msg -|- who *msg:who 
bind msg -|- whois *msg:whois 
bind msg m|- reset *msg:reset
bind msg -|- op *msg:op 
bind msg -|- go *msg:go

# -- strip eggdrop bare by disabling default commands
if {$arm(cfg.lockegg)} {

	 unbind msg m|m status *msg:status 
	 unbind msg -|- pass *msg:pass 
	 unbind msg n|- die *msg:die 
	 unbind msg -|- ident *msg:ident 
	 unbind msg -|- help *msg:help
	 unbind msg -|- info *msg:info 
	 unbind msg o|o invite *msg:invite 
	 unbind msg m|- jump *msg:jump 
	 unbind msg m|- memory *msg:memory 
	 unbind msg m|- rehash *msg:rehash 
	 unbind msg -|- voice *msg:voice 
	 unbind msg -|- who *msg:who 
	 unbind msg -|- whois *msg:whois 
	 unbind msg m|- reset *msg:reset
	 unbind msg -|- op *msg:op 
	 unbind msg -|- go *msg:go


# ---- DCC BINDS
# -- rebind to owner only, for high security.

	 unbind dcc m|- binds *dcc:binds
	 unbind dcc o|- relay *dcc:relay
	 unbind dcc m|- rehash *dcc:rehash
	 unbind dcc -|- assoc *dcc:assoc
	 unbind dcc -|- store *dcc:store
	 unbind dcc lo|lo topic *dcc:topic
	 unbind dcc o|o say *dcc:say
	 unbind dcc o|- msg *dcc:msg
	 unbind dcc lo|lo kickban *dcc:kickban
	 unbind dcc lo|lo kick *dcc:kick
	 unbind dcc o|o invite *dcc:invite
	 unbind dcc ov|ov devoice *dcc:devoice
	 unbind dcc ov|ov voice *dcc:voice
	 unbind dcc lo|lo dehalfop *dcc:dehalfop
	 unbind dcc lo|lo halfop *dcc:halfop
	 unbind dcc o|o deop *dcc:deop
	 unbind dcc o|o op *dcc:op
	 unbind dcc o|o channel *dcc:channel
	 unbind dcc o|o act *dcc:act
	 unbind dcc o|o resetinvites *dcc:resetinvites
	 unbind dcc o|o resetexempts *dcc:resetexempts
	 unbind dcc o|o resetbans *dcc:resetbans
	 unbind dcc m|m reset *dcc:reset
	 unbind dcc m|m deluser *dcc:deluser
	 unbind dcc m|m adduser *dcc:adduser
	 unbind dcc lo|lo unstick *dcc:unstick
	 unbind dcc lo|lo stick *dcc:stick
	 unbind dcc -|- info *dcc:info
	 unbind dcc m|m chinfo *dcc:chinfo
	 unbind dcc n|n chansave *dcc:chansave
	 unbind dcc n|n chanset *dcc:chanset
	 unbind dcc n|n chanload *dcc:chanload
	 unbind dcc m|m chaninfo *dcc:chaninfo
	 unbind dcc lo|lo invites *dcc:invites
	 unbind dcc lo|lo exempts *dcc:exempts
	 unbind dcc lo|lo -invite *dcc:-invite
	 unbind dcc lo|lo -exempt *dcc:-exempt
	 unbind dcc lo|lo bans *dcc:bans
	 unbind dcc m|m -chrec *dcc:-chrec
	 unbind dcc n|- -chan *dcc:-chan
	 unbind dcc lo|lo -ban *dcc:-ban
	 unbind dcc m|m +chrec *dcc:+chrec
	 unbind dcc n|- +chan *dcc:+chan
	 unbind dcc lo|lo +invite *dcc:+invite
	 unbind dcc lo|lo +exempt *dcc:+exempt
	 unbind dcc lo|lo +ban *dcc:+ban
	 unbind dcc m|- clearqueue *dcc:clearqueue
	 unbind dcc o|- servers *dcc:servers
	 unbind dcc m|- jump *dcc:jump
	 unbind dcc m|- dump *dcc:dump
	 unbind dcc n|- relang *dcc:relang
	 unbind dcc n|- lstat *dcc:lstat
	 unbind dcc n|- ldump *dcc:ldump
	 unbind dcc n|- -lsec *dcc:-lsec
	 unbind dcc n|- +lsec *dcc:+lsec
	 unbind dcc n|- -lang *dcc:-lang
	 unbind dcc n|- +lang *dcc:+lang
	 unbind dcc n|- language *dcc:language
	 unbind dcc -|- whoami *dcc:whoami
	 unbind dcc m|m traffic *dcc:traffic
	 unbind dcc -|- whom *dcc:whom
	 unbind dcc -|- whois *dcc:whois
	 unbind dcc -|- who *dcc:who
	 unbind dcc -|- vbottree *dcc:vbottree
	 unbind dcc m|m uptime *dcc:uptime
	 unbind dcc n|- unloadmod *dcc:unloadmod
	 unbind dcc t|- unlink *dcc:unlink
	 unbind dcc t|- trace *dcc:trace
	 unbind dcc n|- tcl *dcc:tcl
	 unbind dcc -|- su *dcc:su
	 unbind dcc -|- strip *dcc:strip
	 unbind dcc m|m status *dcc:status
	 unbind dcc n|- set *dcc:set
	 unbind dcc m|m save *dcc:save
	 unbind dcc m|- restart *dcc:restart
	 unbind dcc m|m reload *dcc:reload
	 unbind dcc n|- rehelp *dcc:rehelp
	 unbind dcc -|- quit *dcc:quit
	 unbind dcc -|- page *dcc:page
	 unbind dcc -|- nick *dcc:nick
	 unbind dcc -|- handle *dcc:handle
	 unbind dcc -|- newpass *dcc:newpass
	 unbind dcc -|- motd *dcc:motd
	 unbind dcc n|- modules *dcc:modules
	 unbind dcc m|- module *dcc:module
	 unbind dcc -|- me *dcc:me
	 unbind dcc ot|o match *dcc:match
	 unbind dcc n|- loadmod *dcc:loadmod
	 unbind dcc t|- link *dcc:link
	 unbind dcc m|- ignores *dcc:ignores
	 unbind dcc -|- help *dcc:help
	 unbind dcc -|- fixcodes *dcc:fixcodes
	 unbind dcc -|- echo *dcc:echo
	 unbind dcc n|- die *dcc:die
	 unbind dcc m|- debug *dcc:debug
	 unbind dcc t|- dccstat *dcc:dccstat
	 unbind dcc ot|o console *dcc:console
	 unbind dcc m|- comment *dcc:comment
	 unbind dcc t|- chpass *dcc:chpass
	 unbind dcc t|- chnick *dcc:chnick
	 unbind dcc t|- chhandle *dcc:chhandle
	 unbind dcc m|m chattr *dcc:chattr
	 unbind dcc -|- chat *dcc:chat
	 unbind dcc t|- chaddr *dcc:chaddr
	 unbind dcc -|- bottree *dcc:bottree
	 unbind dcc -|- bots *dcc:bots
	 unbind dcc -|- botinfo *dcc:botinfo
	 unbind dcc t|- botattr *dcc:botattr
	 unbind dcc t|- boot *dcc:boot
	 unbind dcc t|- banner *dcc:banner
	 unbind dcc m|m backup *dcc:backup
	 unbind dcc -|- back *dcc:back
	 unbind dcc -|- away *dcc:away
	 unbind dcc ot|o addlog *dcc:addlog
	 unbind dcc m|- -user *dcc:-user
	 unbind dcc m|- -ignore *dcc:-ignore
	 unbind dcc -|- -host *dcc:-host
	 unbind dcc t|- -bot *dcc:-bot
	 unbind dcc m|- +user *dcc:+user
	 unbind dcc m|- +ignore *dcc:+ignore
	 unbind dcc t|m +host *dcc:+host
	 unbind dcc t|- +bot *dcc:+bot

	 bind dcc  n|- binds *dcc:binds
	 bind dcc  n|- relay *dcc:relay
	 bind dcc  n|- rehash *dcc:rehash
	 bind dcc  n|- assoc *dcc:assoc
	 bind dcc  n|- store *dcc:store
	 bind dcc  n|- topic *dcc:topic
	 bind dcc  n|- say *dcc:say
	 bind dcc  n|- msg *dcc:msg
	 bind dcc  n|- kickban *dcc:kickban
	 bind dcc  n|- kick *dcc:kick
	 bind dcc  n|- invite *dcc:invite
	 bind dcc  n|- devoice *dcc:devoice
	 bind dcc  n|- voice *dcc:voice
	 bind dcc  n|- dehalfop *dcc:dehalfop
	 bind dcc  n|- halfop *dcc:halfop
	 bind dcc  n|- deop *dcc:deop
	 bind dcc  n|- op *dcc:op
	 bind dcc  n|- channel *dcc:channel
	 bind dcc  n|- act *dcc:act
	 bind dcc  n|- resetinvites *dcc:resetinvites
	 bind dcc  n|- resetexempts *dcc:resetexempts
	 bind dcc  n|- resetbans *dcc:resetbans
	 bind dcc  n|- reset *dcc:reset
	 bind dcc  n|- deluser *dcc:deluser
	 bind dcc  n|- adduser *dcc:adduser
	 bind dcc  n|- unstick *dcc:unstick
	 bind dcc  n|- stick *dcc:stick
	 bind dcc  n|- info *dcc:info
	 bind dcc  n|- chinfo *dcc:chinfo
	 bind dcc  n|- chansave *dcc:chansave
	 bind dcc  n|- chanset *dcc:chanset
	 bind dcc  n|- chanload *dcc:chanload
	 bind dcc  n|- chaninfo *dcc:chaninfo
	 bind dcc  n|- invites *dcc:invites
	 bind dcc  n|- exempts *dcc:exempts
	 bind dcc  n|- -invite *dcc:-invite
	 bind dcc  n|- -exempt *dcc:-exempt
	 bind dcc  n|- bans *dcc:bans
	 bind dcc  n|- -chrec *dcc:-chrec
	 bind dcc  n|- -chan *dcc:-chan
	 bind dcc  n|- -ban *dcc:-ban
	 bind dcc  n|- +chrec *dcc:+chrec
	 bind dcc  n|- +chan *dcc:+chan
	 bind dcc  n|- +invite *dcc:+invite
	 bind dcc  n|- +exempt *dcc:+exempt
	 bind dcc  n|- +ban *dcc:+ban
	 bind dcc  n|- clearqueue *dcc:clearqueue
	 bind dcc  n|- servers *dcc:servers
	 bind dcc  n|- jump *dcc:jump
	 bind dcc  n|- dump *dcc:dump
	 bind dcc  n|- relang *dcc:relang
	 bind dcc  n|- lstat *dcc:lstat
	 bind dcc  n|- ldump *dcc:ldump
	 bind dcc  n|- -lsec *dcc:-lsec
	 bind dcc  n|- +lsec *dcc:+lsec
	 bind dcc  n|- -lang *dcc:-lang
	 bind dcc  n|- +lang *dcc:+lang
	 bind dcc  n|- language *dcc:language
	 bind dcc  n|- whoami *dcc:whoami
	 bind dcc  n|- traffic *dcc:traffic
	 bind dcc  n|- whom *dcc:whom
	 bind dcc  n|- whois *dcc:whois
	 bind dcc  n|- who *dcc:who
	 bind dcc  n|- vbottree *dcc:vbottree
	 bind dcc  n|- uptime *dcc:uptime
	 bind dcc  n|- unloadmod *dcc:unloadmod
	 bind dcc  n|- unlink *dcc:unlink
	 bind dcc  n|- trace *dcc:trace
	 bind dcc  n|- tcl *dcc:tcl
	 bind dcc  n|- su *dcc:su
	 bind dcc  n|- strip *dcc:strip
	 bind dcc  n|- status *dcc:status
	 bind dcc  n|- set *dcc:set
	 bind dcc  n|- save *dcc:save
	 bind dcc  n|- restart *dcc:restart
	 bind dcc  n|- reload *dcc:reload
	 bind dcc  n|- rehelp *dcc:rehelp
	 bind dcc  n|- quit *dcc:quit
	 bind dcc  n|- page *dcc:page
	 bind dcc  n|- nick *dcc:nick
	 bind dcc  n|- handle *dcc:handle
	 bind dcc  n|- newpass *dcc:newpass
	 bind dcc  n|- motd *dcc:motd
	 bind dcc  n|- modules *dcc:modules
	 bind dcc  n|- module *dcc:module
	 bind dcc  n|- me *dcc:me
	 bind dcc  n|- match *dcc:match
	 bind dcc  n|- loadmod *dcc:loadmod
	 bind dcc  n|- link *dcc:link
	 bind dcc  n|- ignores *dcc:ignores
	 bind dcc  n|- help *dcc:help
	 bind dcc  n|- fixcodes *dcc:fixcodes
	 bind dcc  n|- echo *dcc:echo
	 bind dcc  n|- die *dcc:die
	 bind dcc  n|- debug *dcc:debug
	 bind dcc  n|- dccstat *dcc:dccstat
	 bind dcc  n|- console *dcc:console
	 bind dcc  n|- comment *dcc:comment
	 bind dcc  n|- chpass *dcc:chpass
	 bind dcc  n|- chnick *dcc:chnick
	 bind dcc  n|- chhandle *dcc:chhandle
	 bind dcc  n|- chattr *dcc:chattr
	 bind dcc  n|- chat *dcc:chat
	 bind dcc  n|- chaddr *dcc:chaddr
	 bind dcc  n|- bottree *dcc:bottree
	 bind dcc  n|- bots *dcc:bots
	 bind dcc  n|- botinfo *dcc:botinfo
	 bind dcc  n|- botattr *dcc:botattr
	 bind dcc  n|- boot *dcc:boot
	 bind dcc  n|- banner *dcc:banner
	 bind dcc  n|- backup *dcc:backup
	 bind dcc  n|- back *dcc:back
	 bind dcc  n|- away *dcc:away
	 bind dcc  n|- addlog *dcc:addlog
	 bind dcc  n|- -user *dcc:-user
	 bind dcc  n|- -ignore *dcc:-ignore
	 bind dcc  n|- -host *dcc:-host
	 bind dcc  n|- -bot *dcc:-bot
	 bind dcc  n|- +user *dcc:+user
	 bind dcc  n|- +ignore *dcc:+ignore
	 bind dcc  n|- +host *dcc:+host
	 bind dcc  n|- +bot *dcc:+bot

}
# -- end lockegg

putlog "\[@\] Armour: eggdrop binds restructured."



# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-03_binds.tcl
#
# command binds
#

# ---- protection binds
bind pubm - * arm:pubm:all 
bind notc - * arm:notc:all


proc arm:loadcmds {} {
	global arm armbind addcmd userdb botnet-nick
	
	# -- setup commands for autobinds
	foreach cmd [array names addcmd] {
		set prefix [lindex $addcmd($cmd) 0]
		set lvl [lindex $addcmd($cmd) 1]
		set binds [lrange $addcmd($cmd) 2 end]
		arm:debug 5 "arm:loadcmds: loaded $prefix command: $cmd (lvl: $lvl binds: $binds)"
		# -- check for public
		if {[lsearch $binds "pub"] != -1} { set armbind(cmd,$cmd,pub) $prefix; set userdb(cmd,$cmd,pub) $lvl }
		# -- check for privmsg
		if {[lsearch $binds "msg"] != -1 } { set armbind(cmd,$cmd,msg) $prefix; set userdb(cmd,$cmd,msg) $lvl; }
		# -- check for dcc
		if {[lsearch $binds "dcc"] != -1} { set armbind(cmd,$cmd,dcc) $prefix; set userdb(cmd,$cmd,dcc) $lvl; }
	
	}	

	#-- we should unbind existing commands here....

	# -- public commands
	bind pub - $arm(prefix) userdb:pub:cmd
	
	# -- we moved these to proc arm:pubm:binds
	# bind pub - ${botnet-nick} userdb:pub:cmd
	# bind pub - * userdb:pub:cmd
	proc userdb:pub:cmd {n uh h c a} {
		global armbind
		
		# -- try to do ; separated multiple commands?
		foreach xa [split $a ";"] {
			set a [string trim $xa]
			set cmd [lindex [split $a] 0]
			set a [lrange [split $a] 1 end]
			if {[info exists armbind(cmd,$cmd,pub)]} {
				set prefix $armbind(cmd,$cmd,pub)
				# -- redirect to cmd proc
				arm:coroexec $prefix:cmd:$cmd pub $n $uh $h $c $a
				# -- allow for command shortcuts?
			}
		}
	}


	# -- dcc binds
	bind dcc - $arm(prefix) userdb:dcc:*
	proc userdb:dcc:* {h i a} {
		global armbind
		
		# -- try to do ; separated multiple commands?
		foreach xa [split $a ";"] {
			set a [string trim $xa]
			set cmd [lindex [split $a] 0]
			set a [lrange [split $a] 1 end]
			if {[info exists armbind(cmd,$cmd,dcc)]} {
				set prefix $armbind(cmd,$cmd,dcc)
					
				# -- redirect to cmd proc
				arm:coroexec $prefix:cmd:$cmd dcc $h $i $a
			
				# -- allow for command shortcuts?
			}
		}
	}

	# -- privmsg binds
	foreach i [array names armbind] {
		set line [split $i ,]
		lassign $line a cmd type
		if {$a != "cmd" || $type != "msg"} { continue; }
		set prefix $armbind($i)
		# -- bind the command
		bind msg - $cmd $prefix:msg:$cmd
		proc $prefix:msg:$cmd {n uh h a} {
			set proc [lindex [info level 0] 0]
			set prefix [lindex [split $proc :] 0]
			set cmd [lindex [split $proc :] 2]
			arm:coroexec $prefix:cmd:$cmd msg $n $uh $h [split $a]
		}
	
		# -- allow for command shortcuts?
	}
	
	# ---- command shortcuts
	# -- intelligently load these later
	if {$arm(cfg.cmd.short)} {
                # -- cmd: ban
                proc arm:cmd:kb {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:ban $0 $1 $2 $3 $4 $5 }
                # -- cmd: cmds & commands (shortcut to 'help cmds')
                proc arm:cmd:cmds {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:help $0 $1 $2 $3 $4 $5 }
                proc arm:cmd:commands {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:help $0 $1 $2 $3 $4 $5 }
                # -- cmd: kick
                proc arm:cmd:k {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:kick $0 $1 $2 $3 $4 $5 }
                # -- cmd: black
                proc arm:cmd:b {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:black $0 $1 $2 $3 $4 $5 }
                # -- cmd: add
                proc arm:cmd:a {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:add $0 $1 $2 $3 $4 $5 }
                # -- cmd: rem
                proc arm:cmd:r {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:rem $0 $1 $2 $3 $4 $5 }
                # -- cmd: view
                proc arm:cmd:v {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:view $0 $1 $2 $3 $4 $5 }
                # -- cmd: exempt
                proc arm:cmd:e {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:exempt $0 $1 $2 $3 $4 $5 }
                # -- cmd: stats
                proc arm:cmd:s {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:stats $0 $1 $2 $3 $4 $5 }
                # -- cmd: op
                proc arm:cmd:o {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:op $0 $1 $2 $3 $4 $5 }
                # -- cmd: deop
                proc arm:cmd:d {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:deop $0 $1 $2 $3 $4 $5 }
                # -- cmd: topic
                proc arm:cmd:t {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:topic $0 $1 $2 $3 $4 $5 }
                # -- cmd: userlist
                proc arm:cmd:u {0 1 2 3 {4 ""}  {5 ""}} { arm:coroexec arm:cmd:userlist $0 $1 $2 $3 $4 $5 }
	}


}
# -- end of arm:loadcmds


# -- allow use of nickname (with or without nick completion char ':') or global char '*' as control char
if {$arm(cfg.char.nick) || $arm(cfg.char.glob)} {
	bind pubm - * arm:pubm:binds
	proc arm:pubm:binds {nick uhost hand chan text} {
		global arm botnick
		
		if {$nick == $botnick} { return; }
		
		# -- tidy nick
		set nick [split $nick]
		
		set first [lindex $text 0]
		
		# -- check for global prefix char '*' OR bot nickname
		if {($arm(cfg.char.glob) && $first == "*") || ([string trimright [string tolower $first] :] == [string tolower $botnick])} {
			arm:debug 3 "arm:pubm:binds: global char * exists or bots nickname"
			
			set continue 0
			# -- global control char
			if {$first == "*"} { set continue 1 }
			# -- no nick complete & not required
			if {[string index [string tolower $first] end] != ":" && $arm(cfg.char.tab) != 1} { set continue 1 }

			# -- nick complete used
			if {[string index [string tolower $first] end] == ":"} { set continue 1 }

			if {$continue} {			
				# -- initiating a command
				set second [string tolower [lindex $text 1]]
				arm:debug 3 "arm:pubm:binds: processing command: $second (args: [lrange $text 2 end])"
				# -- should only be one result here, take the first anyway as safety
				set res [lindex [info commands *:cmd:$second] 0]
				if {$res != ""} {
					# -- result is proc name, redirect to command proc
					arm:coroexec $res pub $nick $uhost $hand $chan [split [lrange $text 2 end]]
					return;
				}
			}
		} else {	
			# -- not initiating a command
			return;
		} 
	}
}


# -- coroutine execution
# -- we can put debug stuff here later, very generic for now
proc arm:coroexec {args} {
	coroutine coro_[incr ::coroidx] {*}$args
}

arm:loadcmds


arm:debug 0 "\[@\] Armour: loaded command binds."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-04_userdb.tcl
#
# user database functions
#
# U:id:user:xuser:level:curnick:curhost:lastnick:lasthost:lastseen:automode:pass
# U:1:Empus:Empus:500:Empus:empus@172.16.4.2:Empus:empus@172.16.4.2:1256364110:0:<MD5-PASSWORD>

# -- userlist config variables

set userdb(cfg.db.file) $arm(cfg.db.users)
if {![info exists arm(cfg.md5)]} { set userdb(cfg.md5) "md5" } else { set userdb(cfg.md5) $arm(cfg.md5) }

# -- load sqlite functions if required
if {$userdb(method) == "sqlite"} {
	source ./armour/plugins/sk/armdb.tcl
}

# -- binds

bind msg - login userdb:msg:login 
bind msg - logout userdb:msg:logout
bind msg - newpass userdb:msg:newpass
bind msg - whois userdb:msg:whois

bind join - * { arm:coroexec userdb:join }
bind part - * { arm:coroexec userdb:part }
bind sign - * { arm:coroexec userdb:signoff }
bind nick - * { arm:coroexec userdb:nick }
bind kick - * { arm:coroexec userdb:kick }


# -- logout all users upon server (re-)connection
bind evnt - connect-server userdb:init:logout
#bind evnt - init-server userdb:init:logout

bind raw - 330 userdb:raw:account
bind raw - 354 userdb:raw:who


proc userdb:cmd:do {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	putloglev d * "userdb:cmd:do: started"
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "do"
	# -- ensure user has required access on at least one active channel
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- end default proc template
	putloglev d * "userdb:cmd:do: end of proc template"
	# -- command: tcl

	set tcl [join $args]

	if {$tcl == ""} { userdb:reply $stype $starget "uhh.. do what?"; return; }

        set start [clock clicks]
        set errnum [catch {eval $tcl} error]
        set end [clock clicks]
        arm:reply 3 "userdb:cmd:do: tcl error: $error -- (errnum: $errnum)"
        if {$error==""} {set error "<empty string>"}
        switch -- $errnum {
                0 {if {$error=="<empty string>"} {set error "OK"} {set error "OK: $error"}}
                4 {set error "continue: $error"}
                3 {set error "break: $error"}
                2 {set error "return: $error"}
                1 {set error "error: $error"}
                default {set error "$errnum: $error"}
        }
        set error "$error ([expr ($end-$start)/1000.0] sec)"
        set error [split $error "\n"]
        foreach line $error { userdb:reply $type $target $line }

}


# -- command: whois
# lookup user account access
proc userdb:cmd:whois {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "whois"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: whois

	set targetuser [lindex $args 0]
	if {$targetuser == ""} { userdb:reply $stype $starget "\002usage:\002 whois <user>"; return; }
	
	# -- check if = used
	if {[regexp -- {^=(.+)$} $targetuser -> targetnick]} {
		# -- specified a nick, find the user
		if {![onchan $targetnick]} { userdb:reply $type $target "\002(\002error\002)\002 who is $targetnick?"; return; }
		set targetuser [userdb:uline:get user nick $targetnick]
		if {$targetuser == ""} { userdb:reply $type $target "\002(\002error\002)\002 $targetnick not authenticated."; return; }
	}
	
	# -- tidy targetuser case
	set origuser $targetuser
	set targetuser [userdb:uline:get user user $targetuser]
	if {$targetuser == ""} { userdb:reply $type $target "\002(\002error\002)\002 who is $origuser?"; return; }
	
	# -- targetuser exists, let's get the details!
	
	# U:id:user:xuser:level:curnick:curhost:lastnick:lasthost:lastseen:pass
	
	set trgid [userdb:uline:get userid user $targetuser]
	set trgxuser [userdb:uline:get xuser user $targetuser]
	set trglevel [userdb:uline:get level user $targetuser]
	set trgcurnick [userdb:uline:get curnick user $targetuser]
	set trgcurhost [userdb:uline:get curhost user $targetuser]
	set trglastnick [userdb:uline:get lastnick user $targetuser]
	set trglasthost [userdb:uline:get lasthost user $targetuser]
	set trglastseen [userdb:uline:get lastseen user $targetuser]
	set trgamode [userdb:uline:get automode user $targetuser]
	set trgemail [userdb:uline:get email user $targetuser]
	set trglang [userdb:uline:get languages user $targetuser]
	switch -- $trgamode {
		0	{ set automode "none" }
		1	{ set automode "voice" }
		2	{ set automode "op" }
		default { set automode "none"}
	}
	
	# -- format the info
	
	if {$trglastseen != ""} { set lastseen [userdb:timeago $trglastseen] } \
	else { set lastseen "never" }
	if {$trgemail == ""} { set trgemail "(not set)" }
	if {$trglang == ""} { set trglang "EN" }
	
	userdb:reply $type $target "\002user:\002 $targetuser -- \002xuser:\002 $trgxuser -- \002level:\002 $trglevel "
	userdb:reply $type $target "\002automode:\002 $automode -- \002lastseen:\002 $lastseen"
	userdb:reply $type $target "\002email:\002 $trgemail -- \002languages:\002 $trglang"
	if {$lastseen != "never"} {
		if {$trgcurnick != ""} { userdb:reply $type $target "\002where:\002 $trgcurnick!$trgcurhost" } \
		else { userdb:reply $type $target "\002last:\002 $trglastnick!$trglasthost" }
	}	
}

# -- command: userlist
# views userlist
proc userdb:cmd:userlist {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb uline arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "userlist"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: userlist

	# -- built basic list of users
	set userlist [list]
	set thelist [list]
	set tlist [lsort -dictionary [array names uline]]
	foreach i $tlist {
		set list [split $uline($i) |]
		# U:id:user:level:curnick:curhost:lastnick:lasthost:lastseen:automode:pass:email:lang
		# U:1:Empus:Empus:500:Empus:empus@172.16.4.2:Empus:empus@172.16.4.2:1256364110:2:<MD5-PASSWORD>:email:lang
		lassign $list u id user xuser level curnick curhost lastnick lasthost lastlog amode pass email lang
		switch -- $amode {
			0	{ set automode "none" }
			1	{ set automode "voice" }
			2	{ set automode "op" }
			default { set automode "none" }
		}
		lappend thelist "$level,$id,$user,$xuser,$curnick,$automode"
	}
	
	set newlist [lsort -decreasing $thelist]
	foreach i $newlist {
		lassign [split $i ,] level id user xuser curnick automode
		if {$curnick != ""} {
			# -- authenticated
			lappend userlist "\002$user\002 (xuser: $xuser level: $level mode: $automode)"
		} else {
			# -- not authenticated
			lappend userlist "$user (xuser: $xuser level: $level mode: $automode)"
		}
	
	}
	
	if {$userlist != ""} {
		set userlist [join $userlist " -- "]
		# -- we may need to wrap these lines if it gets too long
		arm:reply $type $target "userlist: $userlist"
	} else {
		# -- heh this shouldn't /ever/ happen.
		arm:reply $type $target "eek! userlist empty! \002epic fail.\002"
	}
	return;
}

# -- command: adduser
# add new user account
proc userdb:cmd:adduser {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb uline arm uservar botnick botnet-nick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "adduser"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: whois

	set trguser [lindex $args 0]
	set trglevel [lindex $args 1]
	set trgxuser [lindex $args 2]
	set trgamode [lindex $args 3]
	if {$trguser == "" || $trglevel == "" || $trgxuser == ""} { userdb:reply $stype $starget "\002usage:\002 adduser <user> <level> <xuser> \[automode\]"; return; }
	if {$trgamode == ""} { set trgamode "none" }
	
	set user [userdb:uline:get user nick $nick]
	
	# -- valid username?
	if {![regexp -- {^[A-Za-z0-9_]{2,12}$} $trguser]} { userdb:reply $type $target "\002(\002error\002)\002 erroneous username. (2-12 alphanumeric chars only)"; return; }

	# -- check if target user exists
	if {[userdb:isValiduser $trguser]} { userdb:reply $type $target "\002(\002error\002)\002 [userdb:uline:get user user $trguser] already exists"; return; }
	
	# -- reserved usernames 
	# -- helps with internal bot stats recollection (cmd: report)
	if {[string tolower $trguser] == "bot" || [string tolower $trguser] == "usernames" || [string tolower $trguser] == [string tolower ${botnet-nick}] \
		|| [string tolower $trguser] == [string tolower $botnick] || [string tolower $trguser] == $uservar} { 
		userdb:reply $type $target "\002(\002error\002)\002 reserved username.";
		return;
	}

	# -- check level
	if {![userdb:isInteger $trglevel]} { userdb:reply $type $target "level is 1-500"; return; }
	set level [userdb:uline:get level user $user]
	if {$trglevel >= $level} { userdb:reply $type $target "error: cannot add a user with a level equal to or above your own."; return; }
	
	# -- check it xuser is already assigned to a user
	set xuser [userdb:uline:get xuser xuser $trgxuser]
	if {$xuser != ""} {
		userdb:reply $type $target "error: xuser $xuser is already associated to a username ([userdb:uline:get user xuser $xuser]).";
		return;
	}

	switch -- $trgamode {
		none	{ set automode "0"; set automodew "none"; }
		0		{ set automode "0"; set automodew "none"; }
		1		{ set automode "1"; set automodew "voice"; }
		voice	{ set automode "1"; set automodew "voice"; }
		2		{ set automode "2"; set automodew "op"; }
		op		{ set automode "2"; set automodew "op"; }
		default { arm:reply $stype $starget "\002(\002error\002)\002 automode should be: none|voice|op"; return; }
	}
		
	# -- get next available userid
	set userid 0
	foreach dbuser [array names uline] {
		set list [split $uline($dbuser) |]
		set id [lindex $list 1]
		if {$id > $userid} { set userid $id }
	}
	set userid [expr $userid + 1]
	
	# -- add the user
        # U|id|user|level|curnick|curhost|lastnick|lasthost|lastseen|automode|pass|email|languages
        # U|1|Empus|Empus|500|Empus|empus@172.16.4.2|Empus|empus@172.16.4.2|1256364110|2|<MD5-PASSWORD>|empus@undernet.org|EN
        putloglev d * "userdb:db:adduser U|$userid|$trguser|$trgxuser|${trglevel}||||||$automode|||EN"

        userdb:db:adduser "U|$userid|$trguser|$trgxuser|${trglevel}||||||$automode|||EN"
			
	userdb:reply $type $target "added user $trguser \002(uid:\002 $userid \002xuser:\002 $trgxuser -- \002level:\002 $trglevel -- \002automode:\002 $automodew\002)\002"
	return;
}

# -- command: remuser
# remove a user account
proc userdb:cmd:remuser {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "remuser"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: whois

	set trguser [lindex $args 0]

	if {$trguser == ""} { userdb:reply $stype $starget "\002usage:\002 remuser <user>"; return; }
	
	set user [userdb:uline:get user nick $nick]

	# -- ensure target user exists
	if {![userdb:isValiduser $trguser]} { userdb:reply $type $target "\002(\002error\002)\002 who is $trguser?"; return; }

	# -- check level
	set level [userdb:uline:get level user $user]
	set trglevel [userdb:uline:get level user $trguser]
	# -- fix user case
	set trguser [userdb:uline:get user user $trguser]
	set uid [userdb:uline:get userid user $trguser]
	if {$trglevel >= $level} { userdb:reply $type $target "cannot remove a user with a level equal to or above your own."; return; }
	
	# -- remove user  
	userdb:db:remuser $trguser
			
	userdb:reply $type $target "removed user $trguser (\002uid:\002 $uid -- \002level:\002 $trglevel)"
	
}

# -- command: verify
# verify a user is authenticated
proc userdb:cmd:verify {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "verify"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: verify

	set trgnick [lindex $args 0]

	if {$trgnick == ""} { userdb:reply $stype $starget "\002usage:\002 verify <nick>"; return; }
		
	set user [userdb:uline:get user nick $trgnick]

	# -- ensure target user exists
	if {$user == ""} { userdb:reply $type $target "$trgnick is not authenticated."; return; }
	
	userdb:reply $type $target "[userdb:uline:get nick nick $trgnick] is authenticated as $user (\002level:\002 [userdb:uline:get level user $user])"
	
	return;
		
}

# -- command: login
# login <user> <passphrase>
proc userdb:msg:login {nick uhost hand arg} {
	global userdb arm
	set user [lindex $arg 0]
	set pass [lrange $arg 1 end]
	if {$user == "" || $pass == ""} { userdb:reply notc $nick "\002usage:\002 login <user> <passphrase>"; return; }
	
	# -- check if user exists
	if {![userdb:isValiduser $user]} { userdb:reply notc $nick "\002(\002error\002)\002 who is $user?"; return; }
	
	# -- for security, we should only allow this if the client is in a common channel
	if {![onchan $nick]} {
		# -- client isn't on a common channel
		userdb:reply notc $nick "login failed. please join a common channel."
		return;
	}
	
	# -- encrypt given pass
	set encrypt [userdb:encrypt $pass]
	
	# -- check against user
	set storepass [userdb:uline:get pass user $user]
	
	# -- get correct case for user
	set user [userdb:uline:get user user $user]
	
	# -- fail if password is blank
	if {$storepass == ""} { 
		userdb:reply notc $nick "error: autologin required for user $user."
		return;
	}
		
	# -- match encrypted passwords
	if {$encrypt == $storepass} {
		# -- match successful, login
		putloglev d * "userdb:msg:login: password match for $user, login successful"
		userdb:uline:set curnick $nick user $user
		userdb:uline:set curhost $uhost user $user
		userdb:uline:set lastseen [unixtime] user $user
		
		# -- check for notes, if plugin loaded
		if {[lsearch [info commands] "sk:cmd:note"] < 0} {
			# -- notes not loaded
			userdb:reply notc $nick "login successful.";
			
		} else {
			# -- notes loaded
			::armdb::db_connect
			set count [lindex [join [::armdb::db_query "SELECT count(*) FROM notes \
				WHERE to_u='$user' AND read='N'"]] 0]
			::armdb::db_close
			if {$count == 1} { userdb:reply notc $nick "login successful. 1 unread note."; } \
			elseif {$count > 1 || $count == 0} { userdb:reply notc $nick "login successful. $count unread notes."; }
		}
		
		# -- get automode
		set automode [userdb:uline:get automode user $user]
		foreach i [channels] {
			switch -- $automode {
				0	{ continue; }
				1	{ pushmode $i +v $nick; }
				2	{ pushmode $i +o $nick; }
				default { continue; }
			}
			flushmode $i
		}
		
		# -- write changes to file (now a timer)
		# userdb:db:write
		return;
	} else {
		# -- no password match
		putloglev d * "userdb:msg:login password mismatch for $user, login failed"
		userdb:reply notc $nick "login failed."
	}
}

# -- command: moduser
# modifies existing user account
proc userdb:cmd:moduser {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb uline arm code2lang
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "moduser"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: moduser

	lassign $args tuser ttype
	set tvalue [lrange $args 2 end]

	if {$tuser == "" || $ttype == "" || $tvalue == ""} { userdb:reply $stype $starget "\002usage:\002 moduser <user> <user|level|xuser|automode|lang|email|pass> <value>"; return; }
	
	set user [userdb:uline:get user nick $nick]

	# -- check if target user exists
	if {![userdb:isValiduser $tuser]} { userdb:reply $type $target "\002(\002error\002)\002 who is $tuser?"; return; }

	# -- check level
	set level [userdb:uline:get level user $user]
	set tlevel [userdb:uline:get level user $tuser]
	
	# -- parse type
	if {[string match "u*" $ttype]} { set ttype "user" } \
	elseif {[string match "le*" $ttype] || [string match "lvl" $ttype]} { set ttype "level" } \
	elseif {[string match "x*" $ttype]} { set ttype "xuser" } \
	elseif {[string match "e*" $ttype]} { set ttype "email" } \
	elseif {[string match "la*" $ttype]} { set ttype "lang" } \
	elseif {[string match "a*" $ttype] || [string match "m*" $ttype]} { set ttype "automode" } \
	elseif {[string match "p*" $ttype]} { set ttype "pass" } \
	else {
		userdb:reply $stype $starget "\002usage:\002 moduser <user> <user|level|xuser|automode|lang|email|pass> <value>"
		return;
	}
	
	if {$tlevel >= $level} {
		# -- allow user to change own password && automode if level>=100
		if {[string tolower $tuser] == [string tolower $user]} {
			if {($ttype != "pass" && $ttype != "automode" && $ttype != "email" && $ttype != "lang") \
				|| ($ttype == "automode" && $level <100)} {
				userdb:reply $type $target "\002(\002error\002)\002 cannot modify user $ttype (target level equal to or above your own)"; 	
				return;
			}
		}
	}
		
	if {$ttype == "user"} {
		# -- modifying username
		set tvalue [lindex $tvalue 0]
		if {[userdb:isValiduser $tvalue]} { userdb:reply $type $target "\002(\002error\002)\002 $tvalue already exists."; return; }
		# -- make the change
		userdb:uline:set user $tvalue user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "level"} {
		# -- modifying level
		set tvalue [lindex $tvalue 0]
		if {$tvalue < 1 || $tvalue > 500} { userdb:reply $type $target "\002(\002error\002)\002 level must be between 1-500"; return; }
		if {$tvalue >= $level} { userdb:reply $type $target "\002(\002error\002)\002 cannot modify to a level at or above your own."; return; }
		if {$tvalue == $tlevel} { userdb:reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
		# -- make the change
		userdb:uline:set level $tvalue user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "xuser"} {
		# -- modifying xuser
		set tvalue [lindex $tvalue 0]
		# -- check this username doesn't already exist against a user
		foreach i [array names uline] {
			set iuser [userdb:uline:get xuser user $i]
			if {[string tolower $iuser] == [string tolower $tvalue]} {
				userdb:reply $type $target "\002(\002error\002)\002 xuser $iuser already exists for user $i"
				return;
			}
		}
		set curx [userdb:uline:get xuser user $tuser]
		if {[string tolower $curx] == [string tolower $tvalue]} { userdb:reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
		# -- make the change
		userdb:uline:set xuser $tvalue user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "automode"} {
		# -- modifying automode
		set tvalue [lindex $tvalue 0]
		# -- get current mode
		set tmode [userdb:uline:get automode user $tuser]
		switch -- $tvalue {
			none	{ set automode "0"; }
			0	{ set automode "0"; }
			1	{ set automode "1"; }
			voice	{ set automode "1"; }
			2	{ set automode "2"; }
			op	{ set automode "2"; }
			default { userdb:reply $stype $starget "\002(\002error\002)\002 automode should be: none|voice|op"; return; }
		}
		if {$automode == $tmode} { userdb:reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
		# -- make the change
		userdb:uline:set automode $automode user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "pass"} {	
		# -- encrypt password
		set encpass [userdb:encrypt $tvalue]
		# -- make the change
		userdb:uline:set pass $encpass user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "email"} {	
		# -- modifying e-mail address
		set allow 0
		set tvalue [lindex $tvalue 0]
		# -- allow user to modify their own
		if {[string tolower $tuser] == [string tolower $user]} { set allow 1 }
		# -- allow user to modify someone lower than them (provided they are an admin)
		if {$level >= 400 && $level > $tlevel} { set allow 1}
		if {$allow == 0} { userdb:reply $type $target "\002(\002error\002)\002 insufficient access."; return; }
		# -- validate e-mail address
		if {![regexp -nocase {^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$} $tvalue]} { userdb:reply $type $target "\002(\002error\002)\002 invalid e-mail address."; return; }
		# -- make the change
		userdb:uline:set email $tvalue user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "lang"} {	
		# -- modifying languages
		# note: first one should be 'primary' in case language support is added later
		set allow 0
		# -- allow user to modify their own
		if {[string tolower $tuser] == [string tolower $user]} { set allow 1 }
		# -- allow user to modify someone lower than them (provided they are an admin)
		if {$level >= 400 && $level > $tlevel} { set allow 1 }
		if {!$allow} { userdb:reply $type $target "\002(\002error\002)\002 insufficient access."; return; }
		# -- validate language list (should be two char codes separated by space or comma)
		if {![regexp -- {^(?:[A-Za-z]{2}[,\s]?)+$} $tvalue]} {
			userdb:reply $type $target "\002(\002error\002)\002 invalid language list. used two character language codes, space or comma delimited."
			return;
		}
		set langlist [string trimright $tvalue " "]
		# -- replace commas with space
		regsub -all {,} $langlist { } langlist
		
		# -- ensure the language is valid from our table
		foreach lang $langlist {
			if {![info exists code2lang([string tolower $lang])]} {
				userdb:reply $type $target "language [string toupper $lang] unknown."
				return;
			}
		}
		
		set langlist [string toupper $langlist]
		# -- make the change
		userdb:uline:set languages $langlist user $tuser
		userdb:reply $type $target "done."
		return;
	}
	
}

# -- command: set
# changes username settings (for your own user)
proc userdb:cmd:set {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb uline arm code2lang
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "set"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: moduser

	set ttype [lindex $args 0]
	set tvalue [lrange $args 1 end]

	if {$ttype == "" || $tvalue == ""} { userdb:reply $stype $starget "\002usage:\002 set <automode|lang|email|pass> <value>"; return; }
	
	set user [userdb:uline:get user nick $nick]

	# -- parse type
	if {[string match "e*" $ttype]} { set ttype "email" } \
	elseif {[string match "la*" $ttype]} { set ttype "lang" } \
	elseif {[string match "a*" $ttype] || [string match "m*" $ttype]} { set ttype "automode" } \
	elseif {[string match "p*" $ttype]} { set ttype "pass" } \
	else {
		userdb:reply $stype $starget "\002usage:\002 set <automode|lang|email|pass> <value>"
		return;
	}
		
	if {$ttype == "automode"} {
		# -- modifying automode
		set tvalue [lindex $tvalue 0]
		# -- get current mode
		set tmode [userdb:uline:get automode user $user]
		switch -- $tvalue {
			none	{ set automode "0"; }
			0	{ set automode "0"; }
			1	{ set automode "1"; }
			voice	{ set automode "1"; }
			2	{ set automode "2"; }
			op	{ set automode "2"; }
			default { userdb:reply $type $target "\002(\002error\002)\002 automode should be: none|voice|op"; return; }
		}
		if {$automode == $tmode} { userdb:reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
		# -- make the change
		userdb:uline:set automode $automode user $user
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "pass"} {	
		# -- encrypt password
		set encpass [userdb:encrypt $tvalue]
		# -- make the change
		userdb:uline:set pass $encpass user $user
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "email"} {	
		# -- modifying e-mail address
		set tvalue [lindex $tvalue 0]
		# -- validate e-mail address
		if {![regexp -nocase {^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$} $tvalue]} { userdb:reply $type $target "\002(\002error\002)\002 invalid e-mail address."; return; }
		# -- make the change
		userdb:uline:set email $tvalue user $user
		userdb:reply $type $target "done."
		return;
	}
	
	if {$ttype == "lang"} {	
		# -- modifying languages
		# note: first one should be 'primary' in case language support is added later

		# -- validate language list (should be two char codes separated by space or comma)
		if {![regexp -- {^(?:[A-Za-z]{2}[,\s]?)+$} $tvalue]} {
			userdb:reply $type $target "\002(\002error\002)\002 invalid language list. used two character language codes, space or comma delimited."
			return;
		}
		set langlist [string trimright $tvalue " "]
		# -- replace commas with space
		regsub -all {,} $langlist { } langlist
		
		# -- ensure the language is valid from our table
		foreach lang $langlist {
			if {![info exists code2lang([string tolower $lang])]} {
				userdb:reply $type $target "language [string toupper $lang] unknown."
				return;
			}
		}
		
		set langlist [string toupper $langlist]
		# -- make the change
		userdb:uline:set languages $langlist user $user
		userdb:reply $type $target "done."
		return;
	}
	
}

# -- command: logout
# logout <user> <passphrase>
proc userdb:msg:logout {nick uhost hand arg} {
	global userdb arm
	set user [lindex $arg 0]
	set pass [lrange $arg 1 end]
	if {$user == "" || $pass == ""} { userdb:reply notc $nick "\002usage:\002 logout <user> <passphrase>"; return; }
	
	# -- check if user exists
	if {![userdb:isValiduser $user]} { userdb:reply notc $nick "\002(\002error\002)\002 who is $user?"; return; }
	
	# -- encrypt given pass
	set encrypt [userdb:encrypt $pass]
	
	# -- check against user
	set storepass [userdb:uline:get pass user $user]
		
	# -- match encrypted passwords
	if {$encrypt == $storepass} {
		# -- match successful, login
		putloglev d * "userdb:msg:logout: password match for $user, logout successful"
		
		# -- update lastnick and lasthost
		set lastnick [userdb:uline:get curnick user $user]
		set lasthost [userdb:uline:get curhost user $user]
		userdb:uline:set lastnick $lastnick user $user
		userdb:uline:set lasthost $lasthost user $user
		
		# -- void login by setting curnick and curhost to 0
		userdb:uline:set curnick "" user $user
		userdb:uline:set curhost "" user $user
		userdb:reply notc $nick "logout successful."; 
		# -- write changes to file (now a timer)
		# userdb:db:write
		return;
	} else {
		# -- no password match
		putloglev d * "userdb:msg:login password mismatch for $user, logout failed"
		userdb:reply notc $nick "logout failed."
	}
}

# -- command: newpass
# newpass <passphrase>
proc userdb:msg:newpass {nick uhost hand arg} {
	global userdb arm
	set newpass [lrange $arg 0 end]
	if {$newpass == ""} { userdb:reply notc $nick "\002usage:\002 newpass <passphrase>"; return; }
	
	# -- check if user is logged in
	set user [userdb:uline:get user curnick $nick]
	if {$user == ""} { userdb:reply notc $nick "\002(\002error\002)\002 perhaps not. login first."; return; }
	 
	# -- encrypt given pass
	set encrypt [userdb:encrypt $newpass]
		

	putloglev d * "userdb:msg:newpass: updating password for $user"
		
	# -- update lastnick and lasthost
	userdb:uline:set pass $encrypt user $user
	userdb:reply notc $nick "password changed."; 
	# -- write changes to file (now a timer)
	# userdb:db:write
}


putlog "\[@\] Armour: loading user database..."

# U:id:user:xuser:level:curnick:curhost:lastnick:lasthost:lastseen:automode:pass:email:languages
proc userdb:db:load {} {
	global userdb uline arm
	putloglev d * "userdb:db:load: started"

	catch { unset uline }
	
	# -- check what kind of DB we're using
	if {$userdb(method) == "file"} {
		set userfile $userdb(cfg.db.file)
		if {![file exists $userfile]} { exec touch $userfile }
		set fd [open $userfile r]
		set data [read $fd]
		set data [split $data "\n"]
		
		# -- read each U:line
		foreach line $data {
			if {$line != ""} { putloglev d * "userdb:db:load: file line: $line" }
			set list [split $line |]
			if {[lindex $list 0] == "#" || [lindex $list 0] != "U" || $list == ""} { continue; }
			lassign $list U userid user xuser level curnick curhost lastnick lasthost lastseen automode pass email languages
			set dbline "U|$userid|$user|$xuser|$level|$curnick|$curhost|$lastnick|$lasthost|$lastseen|$automode|$pass|$email|$languages"
			set uline($user) $dbline

		} # EOF
		close $fd
		
	} elseif {$userdb(method) == "sqlite"} {
		# -- sqlite3 DB
		::armdb::db_connect
		set result [::armdb::db_query "SELECT id, user, xuser, level, curnick, curhost, lastnick, lasthost, \
			lastseen, automode, pass, email, languages FROM users"]
		::armdb::db_close
		foreach row $result {
			if {$row != ""} { putloglev d * "userdb:db:load: sql row: $row" }
			lassign $row userid user xuser level curnick curhost lastnick lasthost lastseen automode pass email languages
			set dbline "U|$userid|$user|$xuser|$level|$curnick|$curhost|$lastnick|$lasthost|$lastseen|$automode|$pass|$email|$languages"
			set uline($user) $dbline
		}
	} else {
	
		putloglev d * "userdb:db:load: userdb(method) not set correctly (file|sqlite)"
		die "error: userdb(method) not set correctly (file|sqlite)"
		return;
	}

	putloglev d * "userdb:db:load: loaded [llength [array names uline]] users into the userlist"

}

proc userdb:db:write {} {
	global userdb uline arm

	# -- check what kind of DB we're using
	if {$userdb(method) == "file"} {
		# -- local flat file DB
		set userfile $userdb(cfg.db.file)
		catch { exec rm -rf $userdb(cfg.db.file) }
		if {![file exists $userfile]} { set fd [open $userfile w] } \
		else { set fd [open $userfile a] }
		# -- print header
		puts $fd "# U|id|user|xuser|level|curnick|curhost|lastnick|lasthost|lastseen|automode|pass|email|languages"
		puts $fd ""
		# -- write in order of uid's
		set uid 1
		while {$uid != 0} {
			set user [userdb:uline:get user userid $uid silent]
			if {$user != ""} { puts $fd $uline($user); incr uid } \
			else { set uid 0 }
		}
		close $fd
	} elseif {$userdb(method) == "sqlite"} {
		
		# -- with SQL we can't just overwrite the whole record
		# -- nor re-create it as user_id's are auto incremented
		# -- we must do each column update as it occurs
		
	}

	putloglev d * "userdb:db:write: wrote [llength [array names uline]] users to userlist file"
	
	# -- restart timer
	timer $arm(cfg.db.save) userdb:db:write

}

# U:id:user:xuser:level:curnick:curhost:lastnick:lasthost:lastseen:automode:pass:email:languages
proc userdb:db:adduser {string} {
	global userdb uline arm
	
	set list [split $string |]
	set user [lindex $list 2]
	set xuser [lindex $list 3]
	set level [lindex $list 4]
	set pass [lindex $list 11]
	set email [lindex $list 12]
	set languages [lindex $list 13]

	set uline($user) $string 
	
	if {$userdb(method) == "sqlite"} {
		# -- do sqlite3 user insert
		::armdb::db_connect
		set db_user [::armdb::db_escape $user]
		set db_xuser [::armdb::db_escape $xuser]
		set db_level [::armdb::db_escape $level]
		set db_pass [::armdb::db_escape $pass]
		::armdb::db_query "INSERT INTO users (user,xuser,level,pass,email,languages) \
			VALUES ('$user', '$xuser', '$level', '$pass', '$email', '$languages')"
		::armdb::db_close
	}

	putloglev d * "userdb:db:adduser: added $user to userlist array ([llength [array names uline]] users in total)"

	# -- write new userlist to file (now a timer)
	# userdb:db:write

}



# U:id:user:xuser:level:curnick:curhost:lastnick:lasthost:lastseen:automode:pass
proc userdb:db:remuser {user} {
	global userdb uline arm
 
	set deluser ""
	if {[info exists uline($user)]} { set deluser $user } else {
		# -- perhaps the array case for user is incorrect? (safety net)
		foreach entry [array names uline] {
			set line $uline($entry)
			set list [split $line |]
			set dbuser [lindex $list 2]
			if {[string tolower $user] == [string tolower $dbuser]} {
				# -- found a match 
				set deluser $dbuser
				break;
			}
		}
	}
	
	if {$deluser != ""} {
		unset uline($deluser)
		
		if {$userdb(method) == "sqlite"} {
			# -- do sqlite3 user delete
			::armdb::db_connect
			set db_deluser [::armdb::db_escape $deluser]
			::armdb::db_query "DELETE FROM users WHERE user='$db_deluser'"
			::armdb::db_close
		}
		
		putloglev d * "userdb:db:remuser: deleted $deluser from userlist ([llength [array names uline]] users remaining)"

		# -- write new userlist to file (now a timer)
		# userdb:db:write 

	}
}

# obtain uline value
# get <item> where <source> = <arg>
# example:
# userdb:uline:get user nick Empus
proc userdb:uline:get {item source value {silent ""}} {
	global userdb uline arm
	
	set itm [userdb:getarg $item] 
	set src [userdb:getarg $source]
	
	if {$source == "user"} {
		# -- we know which array, try direct
		set user $value
		if {[info exists uline($user)]} {
			set line $uline($user)
			set list [split $line |]
			if {[string tolower [lindex $list $src]] == [string tolower $value]} {
				# -- found a match (source = value)
				if {$silent == ""} { putloglev d * "userdb:uline:get: userlist get $item where $source=$value" }
				return [lindex $list $itm];
			}
		}
	}
	
	# -- check each uline for match
	foreach user [array names uline] {
		set line $uline($user)
		set list [split $line |]
		if {[string tolower [lindex $list $src]] == [string tolower $value]} {
			# -- found a match (source = value)
			if {$silent == ""} { putloglev d * "userdb:uline:get: userlist get $item where $source=$value" }
			return [lindex $list $itm];
		}
	}
	
	# -- return null if match not found
	
	return "";
}
	


# -- change uline items
# set <item> = <value> where <source> = <equal>
# example:
# userdb:uline:set level 1 userid 10
proc userdb:uline:set {item value source equal {silent ""}} {
	global userdb uline arm
	
	# -- item should never be "user"
	if {$item == "user"} { 
		putloglev d * "userdb:db:set: error! item should not be \'user\'"
		return ""
	}
	 
	if {$userdb(method) == "sqlite"} {
			# -- do sqlite3 user delete
			::armdb::db_connect
			set db_item [::armdb::db_escape $item]
			set db_value [::armdb::db_escape $value]
			set db_source [::armdb::db_escape $source]
			set db_equal [::armdb::db_escape $equal]
			#putlog "   (debug) UPDATE users SET $db_item='$db_value' WHERE lower($db_source)='[string tolower $db_equal]'"
			::armdb::db_query "UPDATE users SET $db_item='$db_value' WHERE lower($db_source)='[string tolower $db_equal]'"
			::armdb::db_close
	}
	
	# -- we need to write to memory always
	set itm [userdb:getarg $item]
	set src [userdb:getarg $source] 
	
	foreach user [array names uline] {
		set line $uline($user)
		set list [split $line |]
		if {[string tolower [lindex $list $src]] == [string tolower $equal]} {
			# -- found a match (source = equal)
			# putloglev d * "userdb:db:set: match! source $source = equal $equal"
			lassign $list foo id dbuser xuser level curnick curhost lastnick lasthost lastseen automode password email languages
						
			# -- set new value      
			switch -- $item {
				id		{ set id $value }
				userid		{ set id $value }
				user		{ set dbuser $value }
				xuser		{ set xuser $value }
				level		{ set level $value }
				curnick		{ set curnick $value }
				nick		{ set curnick $value }
				curhost		{ set curhost $value }
				uhost		{ set curhost $value }
				lastnick	{ set lastnick $value }
				lasthost	{ set lasthost $value }
				lastseen	{ set lastseen $value }
				automode	{ set automode $value }
				amode		{ set automode $value }
				mode		{ set automode $value }
				pass		{ set password $value }
				password	{ set password $value }
				email		{ set email $value }
				lang		{ set languages $value }
				language	{ set languages $value }
				languages	{ set languages $value }
			}
			
			# -- update uline
                        # putloglev d * "userdb:db:set: writing uline: U|$id|$dbuser|$xuser|$level|$curnick|$curhost|$lastnick|$lasthost|$lastseen|$automode|$password|$email|$languages"
                        set newuline "U|$id|$dbuser|$xuser|$level|$curnick|$curhost|$lastnick|$lasthost|$lastseen|$automode|$password|$email|$languages"
			set uline($dbuser) $newuline
			
		}
	}
	# -- end of foreach
	
	if {$silent == ""} { putloglev d * "userdb:uline:set: userlist set $item=$value where $source=$equal" }
	return;

}


# -- check if nick is logged in?
proc userdb:isLogin {nick} {
	global userdb arm
	# -- do this silently (no putloglev in userdb:uline:get)
	set user [userdb:uline:get user curnick $nick silent]
	if {$user == ""} { return 0; }
	# -- logged in
	return 1;
}

# -- check if user is valid?
proc userdb:isValiduser {user} {
	global userdb
	# -- do this silently (no putloglev in userdb:uline:get)
	set user [userdb:uline:get userid user $user silent]
	if {$user == ""} { return 0; }
	# -- validuser
	return 1;
}


# -- check which argument an item appears in the uline
proc userdb:getarg {item} {
	switch -- $item {
		id		{ set arg 1 }
		userid	{ set arg 1 }
		user	{ set arg 2 }
		xuser	{ set arg 3 }
		level	{ set arg 4 }
		curnick	{ set arg 5 }
		nick	{ set arg 5 }
		curhost	{ set arg 6 }
		uhost	{ set arg 6 }
		lastnick	{ set arg 7 }
		lasthost	{ set arg 8 }
		lastseen	{ set arg 9 }
		automode	{ set arg 10 }
		amode	{ set arg 10 }
		mode	{ set arg 10 }
		pass	{ set arg 11 }
		password	{ set arg 11 }
		email	{ set arg 12 }
		lang	{ set arg 13 }
		language	{ set arg 13 }
		languages	{ set arg 13 }
	}
}

# -- encrypt password (basic md5)
proc userdb:encrypt {pass} {
	global userdb
	switch -- $userdb(cfg.md5) {
		md5	{ set encrypt [exec md5 -q -s $pass] }
		md5sum	{ set encrypt [lindex [exec echo $pass | md5sum] 0] }
	}
	return $encrypt;
}


# ---- autologout procedures

# -- nickname change
proc userdb:nick {nick uhost handle chan newnick} {
	global userdb 
	global hostnicks ipnicks fullname nickhost nickip
	global gklist
	global scanlist
	
	set host [lindex [split $uhost @] 1]
	
	# -- remove nick from hostnicks if exists
	if {![info exists hostnicks($host)]} { set hostnicks($host) $newnick } else {
		set pos [lsearch $hostnicks($host) $nick]
		if {$pos != -1} {
			# -- nick within
			set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
			lappend hostnicks($host) $newnick
		}
	}

	# -- remove nick from ipnicks if exists
	if {[info exists nickip($nick)]} {
		set ip $nickip($nick)
		if {![info exists ipnicks($ip)]} { set ipnicks($ip) $newnick } else {
			set pos [lsearch $ipnicks($ip) $nick]
			if {$pos != -1} {
				# -- nick within
				set ipnicks($ip) [lreplace $ipnicks($ip) $pos $pos]
				lappend ipnicks($ip) $newnick
			}
		}
		set nickip($newnick) $nickip($nick)
		unset nickip($nick)
	}
	
	# -- remove nick from global kicklist if exists
	if {[info exists gklist]} {
		set pos [lsearch $gklist $nick]
		if {$pos != -1} {
			# -- nick within
			set gklist [lreplace $gklist $pos $pos]
			lappend gklist $newnick
		}
	}
	
	# -- scanlist(nicklist) (list of those to scan on /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $nick]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
			lappend scanlist(nicklist) $newnick
		}
	}
	
	# -- paranoid scanlist - list of those already scanned
	# - safety net
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $nick]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
			lappend scanlist(paranoid) $newnick
		}
	}

	# -- tidy fullname array
	if {[info exists fullname($nick)]} { set fullname($newnick) $fullname($nick); unset fullname($nick) }

	# -- tidy nickhost array
	if {[info exists nickhost($nick)]} { set nickhost($newnick) $nickhost($nick); unset nickhost($nick) }

	# -- tidy nickip array
	if {[info exists nickip($nick)]} { set nickip($newnick) $nickip($nick); unset nickip($nick) }

	if {[userdb:isLogin $nick]} {
		# -- begin login follow
		set user [userdb:uline:get user curnick $nick]
		# -- update curnick
		userdb:uline:set curnick $newnick user $user
		putloglev d * "userdb:nick changed nickname for $user to $newnick"
		# -- write changes to file (now a timer)
		# userdb:db:write
	}
}

# -- nickname signoff
proc userdb:signoff {nick uhost handle chan {text ""}} {
	global userdb 
	global hostnicks fullname nickhost nickip ipnicks
	global gklist scanlist
	
	set host [lindex [split $uhost @] 1]
	
	# -- remove nick from hostnicks if exists
	if {[info exists hostnicks($host)]} {
		set pos [lsearch $hostnicks($host) $nick]
		if {$pos != -1} {
			# -- nick within
			set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
			if {$hostnicks($host) == ""} { unset hostnicks($host) }
		}
	}
	
	
	# -- remove nick from global kicklist if exists
	if {[info exists gklist]} {
		set pos [lsearch $gklist $nick]
		if {$pos != -1} {
			# -- nick within
			set gklist [lreplace $gklist $pos $pos]
			if {$gklist == ""} { unset gklist }
		}
	}

	# -- remove nick from ipnicks if exists
	if {[info exists nickip($nick)]} {
		set ip $nickip($nick)
		unset nickip($nick)
		# -- remove nick from ipnicks if exists
		if {[info exists ipnicks($ip)]} {
			set pos [lsearch $ipnicks($ip) $nick]
			if {$pos != -1} {
				# -- nick within
				set ipnicks($ip) [lreplace $ipnicks($ip) $pos $pos]
				if {$ipnicks($ip) == ""} { unset ipnicks($ip) }
			}		
		}
	}

	# -- remove nick from hostnicks if exists
	if {[info exists hostnicks($host)]} {
		set pos [lsearch $hostnicks($host) $nick]
		if {$pos != -1} {
			# -- nick within
			set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
			if {$hostnicks($host) == ""} { unset hostnicks($host) }
		}
	}
	
	# -- scanlist(nicklist) (list of those to scan on /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $nick]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
	
	# -- paranoid scanlist - list of those already scanned
	# - safety net
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $nick]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}

	if {[userdb:isLogin $nick]} {
		# -- begin autologout
		set user [userdb:uline:get user nick $nick]
		# -- update lastnick and lasthost
		userdb:uline:set lastnick $nick user $user
		userdb:uline:set lasthost $uhost user $user
		# -- void login by setting curnick and curhost to null
		userdb:uline:set curnick "" user $user
		userdb:uline:set curhost "" user $user
		putloglev d * "userdb:signoff autologout for $user ($nick!$uhost)"
		# -- write changes to file (now a timer)
		# userdb:db:write
	}

	# -- tidy fullname array
	if {[info exists fullname($nick)]} { unset fullname($nick) }

	# -- tidy nickhost array
	if {[info exists nickhost($nick)]} { unset nickhost($nick) }

}
# -- nickname channel part
proc userdb:part {nick uhost handle chan {text ""}} {
	global userdb  botnick
	global hostnicks fullname nickhost nickip ipnicks
	global gklist
	global scanlist
	
	if {$nick == $botnick && [onchan $nick]} {
		# -- still on some channels common with me, leave data
		return;
	}
	
	set host [lindex [split $uhost @] 1]
	
	# -- remove nick from hostnicks if exists
	if {[info exists hostnicks($host)]} {
		set pos [lsearch $hostnicks($host) $nick]
		if {$pos != -1} {
			# -- nick within
			set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
			if {$hostnicks($host) == ""} { unset hostnicks($host) }
		}
	}
	
	# -- remove nick from global kicklist if exists
	if {[info exists gklist]} {
		set pos [lsearch $gklist $nick]
		if {$pos != -1} {
			# -- nick within
			set gklist [lreplace $gklist $pos $pos]
			if {$gklist == ""} { unset gklist }
		}
	}
	
	# -- remove nick from ipnicks if exists
	if {[info exists nickip($nick)]} {
		set ip $nickip($nick)
		unset nickip($nick)
		# -- remove nick from ipnicks if exists
		if {[info exists ipnicks($ip)]} {
			set pos [lsearch $ipnicks($ip) $nick]
			if {$pos != -1} {
				# -- nick within
				set ipnicks($ip) [lreplace $ipnicks($ip) $pos $pos]
				if {$ipnicks($ip) == ""} { unset ipnicks($ip) }
			}		
		}
	}
	
	# -- scanlist(nicklist) (list of those to scan on /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $nick]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
	
	# -- paranoid scanlist - list of those already scanned
	# - safety net
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $nick]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}
	
	# -- tidy fullname array
	if {[info exists fullname($nick)]} { unset fullname($nick) }

	# -- tidy nickhost array
	if {[info exists nickhost($nick)]} { unset nickhost($nick) }
	
	if {[userdb:isLogin $nick]} {
	
		foreach channel [channels] {
			if {[onchan $nick $channel] && $channel != $chan} {
				# -- still on a common channel, halt autologout
				return;
			}
		}
	
		# -- no longer on a common channel, begin autologout

		set user [userdb:uline:get user nick $nick]
	
		# -- update lastnick and lasthost
		userdb:uline:set lastnick $nick user $user
		userdb:uline:set lasthost $uhost user $user
		
		# -- void login by setting curnick and curhost to null
		userdb:uline:set curnick "" user $user
		userdb:uline:set curhost "" user $user
	
		putloglev d * "userdb:part: autologout for $user ($nick!$uhost)"
	
		# -- write changes to file (now a timer)
		# userdb:db:write
	}
		
}



# -- nickname channel join
proc userdb:join {nick uhost hand chan} {
	global userdb botnick arm
	
	if {$nick == $botnick} { return; }
	
	# -- check mode if already logged in
	set user [userdb:uline:get user curnick $nick]
	if {$user != ""} { 
		# -- get automode
		set automode [userdb:uline:get automode user $user]
		switch -- $automode {
			0	{ return; }
			1	{ pushmode $chan +v $nick; }
			2	{ pushmode $chan +o $nick; }
			default { return; }
		}
		flushmode $chan
		return; 
	}

		
	# -- nick is not logged in
	# -- check for umode +x
	set regex "\[^@\]+@(\[^\\.\]+)\\.users\\.undernet\\.org"
	if {[regexp -- $regex $uhost -> xuser]} {
		# -- user is umode +x
		set user [userdb:uline:get user xuser $xuser]
		if {$user == ""} { return; }
		
		# -- check no-one else is logged in on this user
		set lognick [userdb:uline:get curnick xuser $xuser]
		if {$lognick == ""} {
		
			# -- begin autologin
			putloglev d * "userdb:join: autologin begin for $user ($nick!$uhost)"
			userdb:uline:set curnick $nick user $user
			userdb:uline:set curhost $uhost user $user
			userdb:uline:set lastseen [unixtime] user $user
			
			# -- check for notes, if plugin loaded
			if {[lsearch [info commands] "sk:cmd:note"] < 0} {
				# -- notes not loaded
				userdb:reply notc $nick "autologin successful.";
				
			} else {
				# -- notes loaded
				::armdb::db_connect
				set count [lindex [join [::armdb::db_query "SELECT count(*) FROM notes \
					WHERE to_u='$user' AND read='N'"]] 0]
				::armdb::db_close
				if {$count == 1} { userdb:reply notc $nick "autologin successful. 1 unread note."; } \
				elseif {$count > 1 || $count == 0} { userdb:reply notc $nick "autologin successful. $count unread notes."; }
			}
			
			# -- tell them to use newpass if there is no password set
			set dbpass [userdb:uline:get pass user $user]
			if {$dbpass == "" && [info exists arm(cfg.alert.nopass)]} {
				if {$userdb(cfg.alert.nopass)} {
					userdb:reply notc $nick "password not set. use 'newpass' to set a password, before manual logins can work."
				}
			}
			
			# -- get automode
			set automode [userdb:uline:get automode user $user]
			switch -- $automode {
				0	{ return; }
				1	{ pushmode $chan +v $nick; }
				2	{ pushmode $chan +o $nick; }
				default { return; }
			}
			flushmode $chan
							
			# -- write changes to file (now a timer)
			# userdb:db:write
		}
		return; 
	}

	# -- if Armour is in use, only do this when in secure mode
	global arm
	if {[info exists arm(mode)]} {
		if {$arm(mode) == "secure"} {
			set userdb(autologin.$nick) 1
			putquick "WHOIS $nick"
		}
	}
}



# -- nickname kicked from chan
proc userdb:kick {nick uhost handle chan vict reason} {
	global userdb  botnick
	global hostnicks fullname ipnicks nickhost nickip
	global gklist scanlist
	
	if {$nick == $botnick || [onchan $nick]} {
		# -- still on some channels common with me, leave data
		return;
	}
	
	set victuhost [getchanhost $vict]
	set victhost [lindex [split $victuhost @] 1]
	set host [lindex [split $uhost @] 1]
	
	# -- remove nick from hostnicks if exists
	# (nicknames on a hostname)
	if {[info exists hostnicks($victhost)]} {
		set pos [lsearch $hostnicks($victhost) $vict]
		if {$pos != -1} {
			# -- nick within
			set hostnicks($victhost) [lreplace $hostnicks($victhost) $pos $pos]
			if {$hostnicks($victhost) == ""} { unset hostnicks($victhost) }
		}
	}
	
	# -- remove nick from scanlist(paranoid) if exists
	# (nicknames we're maintaining a list of that are currently indistinguishable from bad guy, when in secure mode)
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $vict]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}
	
	# -- scanlist(nicklist) (list of those to scan on /names -d)
	# (nicknames that we are scanning when not currently visible to the channel, during secure mode)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $vict]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
	
	# -- remove nick from global kicklist if exists
	if {[info exists gklist]} {
		set pos [lsearch $gklist $vict]
		if {$pos != -1} {
			# -- nick within
			set gklist [lreplace $gklist $pos $pos]
			if {$gklist == ""} { unset gklist }
		}
	}
	
	# -- remove nick from ipnicks if exists
	if {[info exists nickip($vict)]} {
		set ip $nickip($vict)
		unset nickip($vict)
		# -- remove nick from ipnicks if exists
		if {[info exists ipnicks($ip)]} {
			set pos [lsearch $ipnicks($ip) $vict]
			if {$pos != -1} {
				# -- nick within
				set ipnicks($ip) [lreplace $ipnicks($ip) $pos $pos]
				if {$ipnicks($ip) == ""} { unset ipnicks($ip) }
			}		
		}
	}
	
	# -- tidy fullname array
	if {[info exists fullname($vict)]} { unset fullname($vict) }

	# -- tidy nickhost array
	if {[info exists nickhost($vict)]} { unset nickhost($vict) }
	
	
	if {[userdb:isLogin $vict]} {

		foreach channel [channels] {
			if {[onchan $vict $channel] && $channel != $chan} {
				# -- still on a common channel, halt autologout
				putloglev d * "userdb:kick: $vict still on a common channel ($channel), halt autologout"
				return;
			}
		}
	
		# -- no longer on a common channel, begin autologout

		putloglev d * "userdb:kick: $vict no longer on a common channel, begin autologout"

		set user [userdb:uline:get user nick $vict]
		
		# -- update lastnick and lasthost
		userdb:uline:set lastnick $vict user $user
		userdb:uline:set lasthost $victuhost user $user
		
		# -- void login by setting curnick and curhost to null
		userdb:uline:set curnick "" user $user
		userdb:uline:set curhost "" user $user
	
		putloglev d * "userdb:kick: autologout for $user ($vict!$victuhost)"
	
		# -- write changes to file (now a timer)
		# userdb:db:write
	}

	# -- nothing should go here, in lieu of 'return' above

}


proc userdb:raw:who {server cmd arg} {
	global userdb botnick
	
	set arg [split $arg]
		
	# mynick  chan    ident   ip      host    nick    xuser
	set type [lindex $arg 1]
	if {$type != "101"} { return; }
	set ident [lindex $arg 2]
	set ip [lindex $arg 3]
	set host [lindex $arg 4]
	set nick [lindex $arg 5]
	set xuser [lindex $arg 6]
	set uhost "$ident@$host"
	set nuh "$nick!$uhost"
	if {$nick == $botnick} { return; }
	if {($xuser == "0" || $xuser == "")} { return; }
	if {[userdb:isLogin $nick]} { return; }
	
	# -- check if this xuser exists in database
	set user [userdb:uline:get user xuser $xuser silent]
	# putloglev d * "userdb:raw:who autologin for $nick (xuser: $xuser) -> user: $user"
	if {$user == ""} { return; }
	
	# -- check if someone is already logged in on this xuser (safety net)
	set lognick [userdb:uline:get curnick xuser $xuser silent]
	# putloglev d * "userdb:raw:who autologin for $nick (xuser: $xuser) -> lognick: $lognick"
	if {$lognick != ""} { return; }
	
	set lastseen [userdb:uline:get lastseen user $user silent]
	# putloglev d * "userdb:raw:who autologin for $nick (xuser: $xuser) -> lastseen: $lastseen"
        if {$lastseen != ""} {
                set timeago [userdb:timeago $lastseen]
                set days [lindex $timeago 0]
                if {$days >= 30} {
                        # -- Over 30 days since last login (safety net)
                        putloglev d * "userdb:raw:who autologin failed for $user: not logged in for $timeago"
                        # -- this needs checks to prevent multiple reminders to the same nick, until they manually login
                        # -- update trackers when: quit, leave all chans (part or kick), change nicknames
                        #userdb:reply notc $nick "autologin failed, please login manually. (last login: $days days ago)"
                        return;
                }
        }
	
	# -- begin autologin!
	putloglev d * "userdb:raw:who: autologin begin for $user ($nick!$uhost)"
	userdb:uline:set curnick $nick user $user
	userdb:uline:set curhost $uhost user $user
	userdb:uline:set lastseen [unixtime] user $user
	
	# -- check for notes, if plugin loaded
	if {[lsearch [info commands] "sk:cmd:note"] < 0} {
		# -- notes not loaded
		userdb:reply notc $nick "autologin successful.";
	} else {
		# -- notes loaded
		::armdb::db_connect
		set count [lindex [join [::armdb::db_query "SELECT count(*) FROM notes \
			WHERE to_u='$user' AND read='N'"]] 0]
		::armdb::db_close
		if {$count == 1} { userdb:reply notc $nick "autologin successful. 1 unread note."; } \
		elseif {$count > 1 || $count == 0} { userdb:reply notc $nick "autologin successful. $count unread notes."; }
	}
	
	# -- tell them to use newpass if there is no password set
	set dbpass userdb:uline:get pass user $user
	if {$dbpass == "" && [info exists arm(cfg.alert.nopass)]} {
		if {$userdb(cfg.alert.nopass)} {
			userdb:reply notc $nick "password not set. use 'newpass' to set a password, before manual logins can work."
		}
	}
	
	# -- get automode
	set automode [userdb:uline:get automode user $user]
	foreach i [channels] {
		switch -- $automode {
			0	{ continue; }
			1	{ pushmode $i +v $nick; }
			2	{ pushmode $i +o $nick; }
			default { continue; }
		}
	}
	flushmode $i
}



proc userdb:raw:account {server cmd arg} {
	global userdb botnick
	
	set arg [split $arg]

	set nick [lindex $arg 1]
	if {$nick == $botnick} { return; }
	set xuser [lindex $arg 2]

	if {[info exists userdb(autologin.$nick)]} {
		# -- check for autologin
		set user [userdb:uline:get user xuser $xuser silent]
		if {$user == ""} { return; }
		
		set lastseen [userdb:uline:get lastseen user $user silent]
		set timeago [userdb:timeago $lastseen]
		set days [lindex $timeago 0]
		if {$days >= 30} {
			# -- Over 30 days since last login (safety net)
			putloglev d * "userdb:raw:account autologin failed for $user: not logged in for $timeago"
			userdb:reply notc $nick "autologin failed, please login manually. (last login: $days days ago)"
			return;
		}
	
		# -- begin autologin!
		set uhost [getchanhost $nick]
		putloglev d * "userdb:raw:who: autologin begin for $user ($nick!$uhost)"
		userdb:uline:set curnick $nick user $user
		userdb:uline:set curhost $uhost user $user
		userdb:uline:set lastseen [unixtime] user $user
		
		# -- check for notes, if plugin loaded
		if {[lsearch [info commands] "sk:cmd:note"] < 0} {
			# -- notes not loaded
			userdb:reply notc $nick "autologin successful.";
			
		} else {
			# -- notes loaded
			::armdb::db_connect
			set count [lindex [join [::armdb::db_query "SELECT count(*) FROM notes \
				WHERE to_u='$user' AND read='N'"]] 0]
			::armdb::db_close
			if {$count == 1} { userdb:reply notc $nick "autologin successful. 1 unread note."; } \
			elseif {$count > 1 || $count == 0} { userdb:reply notc $nick "autologin successful. $count unread notes."; }
		}
		
		# -- get automode
		set automode [userdb:uline:get automode user $user]
		foreach i [channels] {
			switch -- $automode {
				0	{ continue; }
				1	{ pushmode $i +v $nick; }
				2	{ pushmode $i +o $nick; }
				default { continue; }
			}
			flushmode $i
		}
		
		
		unset userdb(autologin.$nick)
		# -- write changes to file (now a timer)
		# userdb:db:write
	}

}

# -- check if command is allowed for nick
proc userdb:isAllowed {nick cmd {type ""} {chan ""}} {
        global userdb

        # -- get username
        set user [userdb:uline:get user curnick $nick]

        # -- safety fallback
        if {![info exists userdb(cmd,$cmd,$type)]} { set req 500 } else { set req $userdb(cmd,$cmd,$type) }

        # -- obtain user level
        set level [userdb:uline:get level user $user]

        if {$req != 0} {
                # -- is user logged in?
                if {![userdb:isLogin $nick]} { return 0 }
                # -- safety net is user doesn't exist
                if {![userdb:isValiduser $user]} { return 0 }

        }  else { return 1; }
        
        if {$level >= $req} {
                # -- cmd allowed
                return 1
        } else {
                # -- cmd not allowed
                return 0;
        }
}



# -- start autologin (who every 20s)
proc userdb:init:autologin {} {
	global userdb server arm

	# -- only continue if autologin chan set
	if {$arm(cfg.chan.login) != ""} {
		utimer $arm(cfg.autologin.cycle) userdb:init:autologin
	}
	# -- only send the /WHO if connected to server
	if {$server != ""} {
		putquick "WHO $arm(cfg.chan.login) %nuhiat,101"
	}
}

# -- kill timers on rehash
proc userdb:killtimers {} {
	global userdb
	set ucount 0
	set count 0
	foreach utimer [utimers] {
		# putloglev d * "userdb:killtimers: utimer: $utimer"
		# -- kill only autologin timer
		if {[lindex $utimer 1] == "userdb:init:autologin"} {  incr ucount; catch { killutimer [lindex $utimer 2] } }
	}
	foreach timer [timers] {
		# putloglev d * "userdb:killtimers: timer: $timer"
		# -- kill only autologin timer
		if {[lindex $timer 1] == "userdb:init:autologin"} {  incr count; catch { killtimer [lindex $timer 2] } }
	}
	putloglev d * "userdb:killtimers: killed $count timers and $ucount utimers"
}

# -- load the userlist to memory
userdb:db:load

# -- killtimers
userdb:killtimers

# -- start autologin
userdb:init:autologin

# -- reply to target
proc userdb:replyold {type target args} {
	 set args [join $args]
	 switch -- $type {
			pub { putquick "PRIVMSG $target :$args"; return; }
			msg { putquick "NOTICE $target :$args"; return; }
			notc { putquick "NOTICE $target :$args"; return; }
			dcc {
			
		}
	 }
}


# -- send text responses back to irc client
proc userdb:reply {type target text} {
	switch -- $type {
	  notc { set med "NOTICE" }
	  pub { set med "PRIVMSG" }
	  msg { set med "PRIVMSG" }
	  dcc {
		if {[userdb:isInteger $target]} { putidx $target "$text"; return; } \
		else { putidx [hand2idx $target] "$text"; return; }
	  }
	}

	# -- ensure text wrapping occurs
	while {($text != "") && ([string length $text] >= 400)} {
		set tmp [userdb:nearestindex "$text" 400]
		if {$tmp != -1} {
			set text2 [string range $text 0 [expr $tmp - 1]]
			set text [string range $text [expr $tmp + 1] end]
		} else {
		  set text2 [string range $text 0 400]
		  set text [string range $text 401 end]
		}
		foreach line [split $text2 \n] {
		  putquick "$med $target :$line"
		}
	}
	if {$text != ""} {
		foreach line [split $text \n] {
			putquick "$med $target :$line"
		}
	}

}

# -- find the nearest index
proc userdb:nearestindex {text index {char " "}} {
  set tchar [string index $text $index]
  while {($tchar != $char) && ($index >= 0)} {
    incr index -1
    set tchar [string index $text $index]
  }
  set index
}


proc userdb:timeago {lasttime} {
        set utime [unixtime]
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
                set secs $totalmin
                set mins 00
                if {$secs < 10} { set secs "0$secs"; }
        }

	set output ""
	if {$years > 1} { append output "$years years, " } \
	elseif {$years == 1} { append output "$years year, " }

	if {$days == 0 || $days > 1} { append output "$days days, " } \
	elseif {$days == 1} { append output "$days day, " }

	append output "$hours:$mins:$secs"

    return $output;
}


# -- check if string is Integer?
proc userdb:isInteger {args} {
	if {[string length $args] == 0} {return 0}
	set ctr 0
	while {$ctr < [string length $args]} {
		if {![string match \[0-9\] [string index $args $ctr]]} {return 0}
		set ctr [expr $ctr + 1]
	}
	return 1
}


# -- check if channel is valid?
proc userdb:isValidchan {chan} {
	global userdb arm
	set list [split $arm(cfg.chan.valid) ,]
	foreach channel $list {
		if {[string tolower $channel] == [string tolower $chan]} {
			return 1
		}
	}
	return 0
}

proc userdb:init:logout {type} {
	global userdb arm uline

	# -- logout all users
	
	putloglev d * "userdb:init:logout: beginning global logout sequence..."
	
	foreach user [array names uline] {
		set line $uline($user)
		set list [split $line |]
		
		lassign $list U id dbuser xuser level curnick curhost lastnick lasthost lastseen automode password email lang

		# -- only process this record if they're actually logged in
		if {$curnick == "" && $curhost == ""} { continue; }
		
		
		if {$userdb(method) == "sqlite"} {
			# -- do sqlite3 user delete
			::armdb::db_connect
			set db_curnick [::armdb::db_escape $curnick]
			set db_curhost [::armdb::db_escape $curhost]
			set db_dbuser [::armdb::db_escape $dbuser]
			::armdb::db_query "UPDATE users SET curnick='', curhost='', lastnick='$db_curnick', lasthost='$db_curhost', \
                        	lastseen='[clock seconds]' WHERE user='$db_dbuser'" 
			::armdb::db_close
		} elseif {$userdb(method) == "file"} {
			# -- set new value
			set lastnick $curnick
			set lasthost $curhost
			set lastseen [clock seconds]
			set curnick ""
			set curhost ""
				
			# -- update uline
			set newuline "U|$id|$dbuser|$xuser|$level|$curnick|$curhost|$lastnick|$lasthost|$lastseen|$automode|$password|$email|$lang"
			set uline($dbuser) $newuline
		}
		
		putloglev d * "userdb:init:logout: deauthenticated user: $dbuser ($curnick!$curhost)"



	}
	# -- end of foreach

 return;
}



putlog "\[@\] Armour: loaded user database."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-05_rblscan.tcl
#
# dnsbl lookup functions
#

#putlog "\[@\] loading rbl scan procedures...."

 
## begin settings ##
 
## location of dig binary including path (default should work on most systems)
#set rbl(digbin) [lindex [split [exec which dig]] 0]

 
## array of rbls, descriptions, and a score for each
## format: rblname {{description to show offenders} score}
## scores must be numeric, but can be either + or - and whole or decimal numbes
##array set rbls {
##	dnsbl.dronebl.org {{DroneBL} +1.0}
##	rbl.efnetrbl.org {{Abusive Host} +1.0}
##	rbl.bentdata.net {{G-Lined Hosts} +1.0}
##	ddd.bentdata.net {{Undernet Drone} +1.0}
##}

## end settings ##
#set rbl(version) 1.1
 
## option fetcher
#proc rbl:getOpt {opts key text} {
#	## make sure only valid options are passed
#	foreach {opt val} $text {
#		if {[lsearch -exact $opts $opt] == -1} {
#			return -code error "Unknown option '$opt', must be one of: [join $opts {, }]"
#		}
#	}
#	## return selected option
#	if {[set index [lsearch -exact $text $key]] != -1} {
#		return [lindex $text [expr {$index +1}]]
#	} else {return {}}
#}
 
## exec dig and parse the output
#proc rbl:dig {host args} {
#	global rbl check score dig
#	## filter out some options
#	set type [rbl:getOpt {-ns -type -callback} -type $args]; if {![string length $type]} {set type A}
#	set ns [rbl:getOpt {-ns -type -callback} -ns $args]; if {[string length $ns]} {set ns "@$ns "}
#	## do our lookup...call our digbin...
#	if {[catch {set lookup [eval exec $rbl(digbin) $ns $host $type]} xError] != 0} {
#		return -code error "Error calling dig:($rbl(digbin) $ns $host $type): $xError"
#	}
#	## parse out our info from dig output
#	foreach line [split [string trim [regsub -all {;(.+?)\n} $lookup {}]] \n] {
#		if {![string length $line]} {continue}
#		foreach {x y z rec} $line {break}
#		switch -exact -- $rec {
#			A {lappend ips [join [lindex [split $line] end]]}
#			TXT {lappend txts [join [lindex [split $line {"}] 1]]}
#			default {continue}
#		}
#	}
#	## make sure we got everything we needed
#	foreach var {ips txts} {if {![info exists [set var]]} {set [set var] NULL}}
#	## check for callback...execute if you got one...otherwise just return our results
#	if {[string length [set cmd [rbl:getOpt {-ns -type -callback} -callback $args]]]} {
#		switch -- $type {
#			A {eval [linsert [set cmd] end $host $ips]}
#			TXT {eval [linsert [set cmd] end $host $txts]}
#			ANY {eval [linsert [set cmd] end $host $ips $txts]}
#		}
#	} else {
#		switch -- $type {
#			A {return [list $host $ips]}
#			TXT {return [list $host $txts]}
#			ANY {return [list $host $ips $txts]}
#		}
#	}
#}
 
## prepare our information to pass off to dig proc
#proc rbl:check {host rbl args} {
#	global check score
#	## check for ipv4 decimal host...if not we need to resolve it
#	if {![regexp {^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$} $host]} {
#
#		# -- debug with timer
#		set start [clock seconds]
#		putloglev d * "rbl:check: doing dns lookup for $host..."
#		set host [lindex [lindex [rbl:dig $host] 1] 0]
#		set stop [clock seconds]
#		putloglev d * "rbl:check: dns resolution for $host took [expr $stop - $start] secs"
#
#		## make sure we got a valid return....if not let's return all nulls
#		if {[string equal {NULL} $host]} {
#			## do a callback?...if not just return em
#			if {[string length [set cmd [rbl:getOpt {-ns -type -callback} -callback $args]]]} {
#				eval [set cmd] NULL NULL NULL NULL NULL
#			} else {return "NULL NULL NULL NULL NULL"}
#		}
#	}
#	## reverse the ip...
#	for {set i 0} {$i < 4} {incr i} {lappend rip [lindex [split $host {.}] end-$i]}; set rip [join $rip {.}]
#	## do the lookup
#
#	# -- debug with timer
#	set start [clock seconds]
#	putloglev d * "rbl:check: doing dns lookup for $rip\.$rbl..."
#
#	foreach {xhost ips txts} [rbl:dig $rip\.$rbl -type ANY] {}
#
#	set stop [clock seconds]
#	putloglev d * "rbl:check: dns resolution for $rip\.$rbl took [expr $stop - $start] secs"
#
#	## do a callback?...if not just return the results
#	if {[string length [set cmd [rbl:getOpt {-ns -type -callback} -callback $args]]]} {
#		eval [linsert [set cmd] end $host $xhost $ips $txts]
#	} else {return [list $host $xhost $ips $txts]}
#}
 
## compute our score and pass off to callback if provided
#proc rbl:score {host args} {
#	global check rbls
#	set total 0; set details [list]
#	foreach rbl [array names rbls] {
#	set check [rbl:check $host $rbl]
#	if {[lindex $check 2] != "NULL" || [lindex $check 3] != "NULL"} {
#			set total [expr [subst {$total [set score [lindex $rbls($rbl) end]]}]]
#			lappend details [list $score $rbl [lindex $rbls($rbl) 0] [lindex $check end]]
#		}
#	}; if {![string length $details]} {set details NULL}
#	if {[string length [set cmd [rbl:getOpt {-ns -type -callback} -callback $args]]]} {
#		eval [linsert [set cmd] end [lindex $check 0] $details $total]
#	} else {return [list [lindex $check 0] $details $total]}
#}

 


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-06_cidr.tcl
#
# CIDR matching functions
#

proc cidr:ip2int ip {
	set res 0
	foreach i [split $ip .] {set res [expr {$res<<8 | $i}]}
	return $res
}

proc cidr:bits n {
	set res 0
	foreach i [split [string repeat 1 $n][string repeat 0 [expr {32-$n}]] ""] {
		set res [expr {$res<<1 | $i}]
	}
	set res
}
proc cidr:maskmatch {ip1 width ip2} {
	 expr {([ip2int $ip1] & [cidr:bits $width]) == ([cidr:ip2int $ip2] & [cidr:bits $width])}
}

proc cidr:match {ip cidr} {
	# -- disable IPv6 for now
	if {[string match "*:*" $ip]} { return 0; }
	
	set width [lindex [split $cidr \/] 1]
	set network [lindex [split $cidr \/] 0]
	#putlog "\$width $width \$network $network"
	expr {([cidr:ip2int $ip] & [cidr:bits $width]) == ([cidr:ip2int $network] & [cidr:bits $width])}
}
proc cidr:onNet {cidrAddr addr} {
	scan $cidrAddr {%d.%d.%d.%d/%d} a b c d bits
	set num [expr {((($a<<8)+$b<<8)+$c<<8)+$d}]
	set mask [expr {0xffffffff & (0xffffffff << (32-$bits))}]
	set net [expr {$num & $mask}]
	return [expr {$net == ($mask & [cidr:ip2int $addr])}]
}
proc cidr:cidr {cidrAddr addr} {
	scan $cidrAddr {%d.%d.%d.%d/%d} a b c d bits
	set addr2 [format {%d.%d.%d.%d} $a $b $c $d]
	set mask [expr {0xffffffff & (0xffffffff << (32-$bits))}]
	expr {($mask & [cidr:ip2int $addr]) == ($mask & [cidr:ip2int $addr2])}
}

putlog "\[@\] Armour: loaded CIDR procedures."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-07_geo.tcl
# 
# asn & country lookup functions
#

# -- convert ip address to asn
proc geo:ip2asn {ip} {

	# -- reverse the IP
	if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
		# -- not valid IP
		return;
	}
	set revip "$d.$c.$b.$a"  

	# -- asynchronous lookup via coroutine	
	set answer [arm:dns:lookup $revip.origin.asn.cymru.com TXT]
	
	# -- example:
	# 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
	
	if {$answer == "NULL" || $answer == ""} { return; }
	
	set string [split $answer "|"]

	set asn [lindex $string 0]
	regsub -all { } $asn {} asn

 return $asn
}

# -- convert ip to country
proc geo:ip2country {ip} {

	# -- reverse the IP
	if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
		# -- not valid IP
		return;
	}
	set revip "$d.$c.$b.$a"  

        # -- asynchronous lookup via coroutine
        set answer [arm:dns:lookup $revip.origin.asn.cymru.com TXT]
	
	# -- example:
	# 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
	
	if {$answer == "NULL" || $answer == ""} { return; }
	
	set string [split $answer "|"]

	set country [lindex $string 2]
	regsub -all { } $country {} country

 return $country
}

# -- convert IP to long format
proc geo:ip2int ip {
	set res 0
	foreach i [split $ip .] {set res [expr {$res<<8 | $i}]}
	return $res
}


putlog "\[@\] Armour: loaded geolocation tools."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-08_nmap.tcl
#
# nmap port scanning functions
#

proc arm:port:scan {ip {ports ""} {conns ""} {timeout ""}} {
	arm:portscan $ip $ports $conns $timeout
}

# -- syntax: portscan IP [list PORT1 PORT2 ..] MAXCONNECTIONS TIMEOUT_IN_MS
# ex: portscan 127.0.0.1 {80 8080 3128 22 21 23 119} 3 5000
# this MUST be called in/from* a coroutine
proc arm:portscan {ip {ports ""} {conns ""} {timeout ""}} {
	global scanports
	set myconns 0
	set openports [list]
	set notimeoutports [list]

	set start [clock clicks]
	set portlist ""
	if {$ports == ""} {
		# -- scan all ports in array
		foreach entry [array names scanports] {
				append portlist "$entry "
		}
		set ports [string trimright $portlist " "]
	} else { set ports $ports }

	if {$conns == ""} { set conns [llength [array names scanports]] }
	if {$timeout == ""} { set timeout "1000" }

    putloglev d * "arm:portscan: scanning: $ip ports: $ports conns: $conns timeout: $timeout"


	foreach port $ports {
		set s [socket -async $ip $port]
		fileevent $s writable [list [info coroutine] [list $s $port open]]
		after $timeout catch [list [list [info coroutine] [list $s $port timeout]]]
		incr myconns
		if {$myconns < $conns} {
			continue
		} else {
			arm:portscan_getfeedback
			arm:portscan_assignstate
		}
	}
	while {$myconns} {
		arm:portscan_getfeedback
		arm:portscan_assignstate
	}

	set fullopen [list]
	foreach i $openports {
			lappend fullopen "${i}/tcp ($scanports($i))"
	}
	set fullopen [join [lsort $fullopen]]

	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"

	if {$fullopen == ""} { putloglev d * "arm:port:scan: no open ports on $ip ($runtime)" } \
	else { putloglev d * "arm:portscan: open ports: $fullopen ($runtime)" }

	return $fullopen;

}

# -- helper function 1 (uplevel executes in callers stack - just code grouping)
proc arm:portscan_getfeedback {} {
	uplevel 1 {
		lassign [yield] s port state
		incr myconns -1
		while {$state eq "timeout" && $port in $notimeoutports} {
			lassign [yield] s port state
		}
	}
}
# -- helper function 2 (uplevel executes in callers stack - just code grouping)
proc arm:portscan_assignstate {} {
	uplevel 1 {
		if {$state eq "open"} {
			lappend notimeoutports $port
			if {[fconfigure $s -error] eq ""} {
				lappend openports $port
			}
		}
		catch {close $s}
	}
}


putlog "\[@\] Armour: loaded asynchronous port scanner."







proc arm:thom:scan {ip {port ""}} {
	global arm scanports

	set start [clock clicks]

	set ports ""
        if {$port == ""} {
                # -- scan all ports in array
                foreach entry [array names scanports] {
                        append ports "$entry "
                }
                set ports [join $ports ,]
        } else { set ports $port }

        putloglev d * "arm:thom:scan: scanning: $ip ports: $ports"

        # -- execute port scan
        if { [catch { set data [exec /home/armour/thomscan.tcl $ip $ports 2 2500] } err] } {
                putlog "error: $err";
                return -code error $err
        }

        set open [string trimleft $data "Open ports: "]

        set fullopen ""
        foreach i $open {
                append fullopen "${i}/tcp ($scanports($i)) "
        }
        set fullopen [string trimright $fullopen " "]
        set fullopen [lsort $fullopen]
        
        set end [clock clicks]
        set runtime "[expr ($end-$start)/1000/1000.0] sec"

        if {$fullopen == ""} { putloglev d * "arm:thom:scan: no open ports on $ip ($runtime)" } \
        else { putloglev d * "arm:thom:scan: open ports: $fullopen ($runtime)" }

        return $fullopen;
	
}

putlog "\[@\] Armour: loaded thommey commandline port scanner."






proc arm:nmap:scan {ip {port ""}} {
	global arm scanports

	set start [clock clicks]

	set ports ""
	set data ""
	set open ""
	set closed ""
	set filtered ""

	if {$port == ""} {
		# -- scan all ports in array
		foreach entry [array names scanports] {
			append ports "$entry "
		}
		set ports [join $ports ,]
	} else { set ports $port }
	
	putloglev d * "arm:nmap:scan: scanning: $ip ports: $ports"
	
	# -- execute port scan
	if { [catch { set data [exec nmap -PN -p $ports $ip | grep -E {open|closed|filtered}] } err] } {
		putlog "error: $err"; 
		return -code error $err

		#return;
	}
	set line [split $data "\r\n"]
	foreach i $line {
		set port [lindex [split [lindex $i 0] /] 0]
		set status [lindex $i 1]
		set service [lindex $i 2]
		if {$status == "filtered"} { append filtered "$port " }
		if {$status == "closed"} { append closed "$port " }
		if {$status == "open"} { append open "$port " }
	}
	
	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"
		
	set fullopen ""
	foreach i $open {
		append fullopen "${i}/tcp ($scanports($i)) "
	}
	set fullopen [string trimright $fullopen " "]
	
	if {$fullopen == ""} { putloglev d * "arm:nmap:scan: no open ports on $ip ($runtime)" } \
	else { putloglev d * "arm:nmap:scan: open ports: $fullopen ($runtime)" }
	
	return $fullopen;
	
}

putlog "\[@\] Armour: loaded nmap scanner."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-09_xauth.tcl
#
# cservice authentication procedure
#
# credits: original x-login by shaithoan
#

# -- username
# note: we set this in the main config now
# set arm(auth.user) "USERNAME"

# -- password
# note: we set this in the main config now
# set arm(auth.pass) "PASSWORD"



# -- binds
bind evnt - connect-server x:deactivate
bind evnt - init-server x:init:server

set loginsucceed 0


# -- procedures
 
proc x:init:server {type} {
	global botnick arm

	if {$arm(auth.user) != "" && $arm(auth.pass) != ""} {
		# -- set umode +x?
		if {$arm(auth.hide)} {
			putserv "MODE $botnick +x"
			putlog "\[@\] (xAuth) executed +x initially before logging into X."
		}
		putserv "PRIVMSG X@channels.undernet.org :login $arm(auth.user) $arm(auth.pass)"

		putlog "\[@\] (xAuth) sent credentials to X, waiting 30 seconds for a response..."

		bind notc - "AUTHENTICATION SUCCESSFUL*" x:login:success
		bind notc - "AUTHENTICATION FAIL*" x:login:fail
		utimer 30 "x:activate_chans"
	
	}
	
	# -- apply silence masks
	foreach mask $arm(cfg.silence) {
		putquick "SILENCE $mask"
		arm:debug 0 "x:init:server: applied silence mask: $mask"
	}
	
	return 0
}

proc x:activate_chans {} {
	global loginsucceed
	if {$loginsucceed == 0} {
		putlog "\[@\] (xAuth) X is lagged, I'll join my channels and wait."
		foreach chan [channels] {
			channel set $chan -inactive
		}
		unbind notc - "AUTHENTICATION SUCCESSFUL*" x:login:success
		unbind notc - "AUTHENTICATION FAIL*" x:login:fail
		bind notc - "AUTHENTICATION SUCCESSFUL*" x:login:late:success
		bind notc - "AUTHENTICATION FAIL*" x:login:late:fail
	 }
}

proc x:deactivate {type} {
	global arm
	if {$arm(auth.user) != "" && $arm(auth.pass) != ""} {
		if {$arm(auth.hide)} {
			putlog "\[@\] (xAuth) Staying outside all channels until I am logged into X..."
			foreach chan [channels] {
				channel set $chan +inactive
	 		}
		}
	 }
}

proc x:login:late:success {mnick uhost hand text {dest ""}} {
	global loginsucceed
	if {$mnick == "X"} {
		set loginsucceed 1
		putlog "\[@\] (xAuth) Successfully logged into X. *phew*"
		unbind notc - "AUTHENTICATION SUCCESSFUL*" x:login:late:success
		unbind notc - "AUTHENTICATION FAIL*" x:login:late:fail
	}
}

proc x:login:late:fail {mnick uhost hand text {dest ""}} {
	global loginsucceed
	if {$mnick == "X"} {
		set loginsucceed 1
		putlog "\[@\] (xAuth) After all this time, NOW X tells me authentication failed!!!"
		unbind notc - "AUTHENTICATION SUCCESSFUL*" x:login:late:success
		unbind notc - "AUTHENTICATION FAIL*" x:login:late:fail
	}
}

proc x:login:success {mnick uhost hand text {dest ""}} {
	global loginsucceed
	if {$mnick == "X"} {
		set loginsucceed 1
		foreach chan [channels] {
			channel set $chan -inactive
		}
		putlog "\[@\] (xAuth) Successfully logged into X, now joining my channels..."
		unbind notc - "AUTHENTICATION SUCCESSFUL*" x:login:success
		unbind notc - "AUTHENTICATION FAIL*" x:login:fail
	 }
}

proc x:login:fail {mnick uhost hand text {dest ""}} {
	global loginsucceed
	if {$mnick == "X"} {
	set loginsucceed 1
		foreach chan [channels] {
			channel set $chan -inactive
		}
		putlog "\[@\] (xAuth) Couldn't login to X, authentication failed somehow."
		putlog "\[@\] (xAuth) Joining my channels now..."
		unbind notc - "AUTHENTICATION SUCCESSFUL*" x:login:success
		unbind notc - "AUTHENTICATION FAIL*" x:login:fail
	 }
}
putlog "\[@\] Armour: loaded cservice authentication."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-10_adaptive.tcl
#
# adaptive regular expression pattern builder
#

proc arm:regex:adapt {string {flags ""}} {
	global arm
		
	# -- grab length
	set length [string length $string]
	
	set iswide 0
	set isrepeat 0
	set isnocase 0
	set isexplicit 0
	set ismin 0
	set ismax 0
	
	if {[string match "*-wide*" $flags]} { set iswide 1; set isrepeat 1; set isnocase 1; }
	
	# -- -min count
	if {[string match "*-min*" $flags]} { 
		set ismin 1
		set pos [lsearch $flags "-min"]
		set min [lindex $flags [expr $pos + 1]]
		if {![regexp -- {\d+} $min]} { putloglev d * "arm:regex:adapt: regexp -min error"; return; }
	}
	
	# -- -max results
	if {[string match "*-max*" $flags]} { 
		set ismax 1
		set pos [lsearch $flags "*-max*"]
		set max [lindex $flags [expr $pos + 1]]
		if {![regexp -- {\d+} $max]} { putloglev d * "arm:regex:adapt: regexp -max error"; return; }
	}
	
	if {[string match "*-repeat*" $flags]} { set isrepeat 1 }
	if {[string match "*-nocase*" $flags]} { set isnocase 1 }
	if {[string match "*-explicit*" $flags]} { set isexplicit 1 }
	
	set count 0
	
	set regexp ""
	
	arm:debug 5 "-----------------------------------------------------------------------------------------------"
	arm:debug 5 "arm:regex:adapt: building adaptive regex for string: $string"
	arm:debug 5 "arm:regex:adapt: wide: $iswide isrepeat: $isrepeat nocase: $isnocase explicit: $isexplicit min: $ismin max: $ismax"
	arm:debug 5 "-----------------------------------------------------------------------------------------------"

	
	# -- phase 1: basic regex form
 
	if {$isexplicit} { 
		# -- replace \ first
		regsub -all {\\} $string {\\\\} string
	}
	
	# ---- mIRC Control Codes
			
	# \x02 $chr(2)	Ctrl+b	Bold text
	# \x03 $chr(3)	Ctrl+k	Colour text
	# \x0F $chr(15)	Ctrl+o	Normal text
	# \x16 $chr(22)	Ctrl+r	Reversed text
	# \x1F $chr(31)	Ctrl+u	Underlined text

	# -- \x02 hex code (bold)
	regsub -all {\x02} $string {\\x02} string 
 
	# -- \x03 hex code (colour)
	regsub -all {\x03} $string {\\x03} string 
			
	# -- \x0F hex code (normal)
	regsub -all {\x0F} $string {\\x0F} string 
			
	# -- \x16 hex code (reverse)
	regsub -all {\x16} $string {\\x16} string 
			
	# -- \x1F hex code (underline)
	regsub -all {\x1F} $string {\\x1F} string 


	# ---- Special Codes

	# -- \x80 hex code (ascii: 128 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x80} $string {\\x80} string 
 
	# -- \x81 hex code (ascii: 129 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x81} $string {\\x81} string 
 
	# -- \x82 hex code (ascii: 130 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x82} $string {\\x82} string 
 
	# -- \x83 hex code (ascii: 131 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x83} $string {\\x83} string 
 
	# -- \x84 hex code (ascii: 132 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x84} $string {\\x84} string 
 
	# -- \x85 hex code (ascii: 133 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x85} $string {\\x85} string 
 
	# -- \x86 hex code (ascii: 134 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x86} $string {\\x86} string 
 
	# -- \x87 hex code (ascii: 135 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x87} $string {\\x87} string 
 
	# -- \x88 hex code (ascii: 136 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x88} $string {\\x88} string 
 
	# -- \x89 hex code (ascii: 137 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x89} $string {\\x89} string 
 
	# -- \x8A hex code (ascii: 138 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x8A} $string {\\x8A} string 
 
	# -- \x8B hex code (ascii: 139 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x8B} $string {\\x8B} string 
 
	# -- \x8C hex code (ascii: 140 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x8C} $string {\\x8C} string 
 
	# -- \x8D hex code (ascii: 141 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x8D} $string {\\x8D} string 
 
	# -- \x8E hex code (ascii: 142 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x8E} $string {\\x8E} string 
 
	# -- \x8F hex code (ascii: 143 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x8F} $string {\\x8F} string 
 
	# -- \x90 hex code (ascii: 144 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x90} $string {\\x90} string 
 
	# -- \x91 hex code (ascii: 145 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x91} $string {\\x91} string 
 
	# -- \x92 hex code (ascii: 146 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x92} $string {\\x92} string 
 
	# -- \x93 hex code (ascii: 147 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x93} $string {\\x93} string 
 
	# -- \x94 hex code (ascii: 148 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x94} $string {\\x94} string 
 
	# -- \x95 hex code (ascii: 149 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x95} $string {\\x95} string 
 
	# -- \x96 hex code (ascii: 150 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x96} $string {\\x96} string 
 
	# -- \x97 hex code (ascii: 151 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x97} $string {\\x97} string 
 
	# -- \x98 hex code (ascii: 152 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x98} $string {\\x98} string 
 
	# -- \x99 hex code (ascii: 153 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x99} $string {\\x99} string 
 
	# -- \x9A hex code (ascii: 154 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x9A} $string {\\x9A} string 
 
	# -- \x9B hex code (ascii: 155 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x9B} $string {\\x9B} string 
 
	# -- \x9C hex code (ascii: 156 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x9C} $string {\\x9C} string 
 
	# -- \x9D hex code (ascii: 157 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x9D} $string {\\x9D} string 
 
	# -- \x9E hex code (ascii: 158 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x9E} $string {\\x9E} string 
 
	# -- \x9F hex code (ascii: 159 char: . desc: not defined in HTML 4 standard)
	regsub -all {\x9F} $string {\\x9F} string 
 
	# -- \xA0 hex code (ascii: 160 char: . desc: non-breaking space)
	regsub -all {\xA0} $string {\\xA0} string 
 
	# -- \xA1 hex code (ascii: 161 char: ¡ desc: inverted exclamation mark)
	regsub -all {\xA1} $string {\\xA1} string 
 
	# -- \xA2 hex code (ascii: 162 char: ¢ desc: cent sign)
	regsub -all {\xA2} $string {\\xA2} string 
 
	# -- \xA3 hex code (ascii: 163 char: £ desc: pound sign)
	regsub -all {\xA3} $string {\\xA3} string 
 
	# -- \xA4 hex code (ascii: 164 char: ¤ desc: currency sign)
	regsub -all {\xA4} $string {\\xA4} string 
 
	# -- \xA5 hex code (ascii: 165 char: ¥ desc: yen sign)
	regsub -all {\xA5} $string {\\xA5} string 
 
	# -- \xA6 hex code (ascii: 166 char: ¦ desc: broken vertical bar)
	regsub -all {\xA6} $string {\\xA6} string 
 
	# -- \xA7 hex code (ascii: 167 char: § desc: section sign)
	regsub -all {\xA7} $string {\\xA7} string 
 
	# -- \xA8 hex code (ascii: 168 char: ¨ desc: spacing diaeresis - umlaut)
	regsub -all {\xA8} $string {\\xA8} string 
 
	# -- \xA9 hex code (ascii: 169 char: © desc: copyright sign)
	regsub -all {\xA9} $string {\\xA9} string 
 
	# -- \xAA hex code (ascii: 170 char: ª desc: feminine ordinal indicator)
	regsub -all {\xAA} $string {\\xAA} string 
 
	# -- \xAB hex code (ascii: 171 char: « desc: left double angle quotes)
	regsub -all {\xAB} $string {\\xAB} string 
 
	# -- \xAC hex code (ascii: 172 char: ¬ desc: not sign)
	regsub -all {\xAC} $string {\\xAC} string 
 
	# -- \xAD hex code (ascii: 173 char:  desc: soft hyphen)
	regsub -all {\xAD} $string {\\xAD} string 

	# -- \xAE hex code (ascii: 174 char: ® desc: registered trade mark sign)
	regsub -all {\xAE} $string {\\xAE} string 
 
	# -- \xAF hex code (ascii: 175 char: ¯ desc: spacing macron - overline)
	regsub -all {\xAF} $string {\\xAF} string 
 
	# -- \xB0 hex code (ascii: 176 char: ° desc: degree sign)
	regsub -all {\xB0} $string {\\xB0} string 
 
	# -- \xB1 hex code (ascii: 177 char: ± desc: plus-or-minus sign)
	regsub -all {\xB1} $string {\\xB1} string 
 
	# -- \xB2 hex code (ascii: 178 char: ² desc: superscript two - squared)
	regsub -all {\xB2} $string {\\xB2} string 
 
	# -- \xB3 hex code (ascii: 179 char: ³ desc: superscript three - cubed)
	regsub -all {\xB3} $string {\\xB3} string 
 
	# -- \xB4 hex code (ascii: 180 char: ´ desc: acute accent - spacing acute)
	regsub -all {\xB4} $string {\\xB4} string 
 
	# -- \xB5 hex code (ascii: 181 char: µ desc: micro sign)
	regsub -all {\xB5} $string {\\xB5} string 
 
	# -- \xB6 hex code (ascii: 182 char: ¶ desc: pilcrow sign - paragraph sign)
	regsub -all {\xB6} $string {\\xB6} string 
 
	# -- \xB7 hex code (ascii: 183 char: · desc: middle dot - Georgian comma)
	regsub -all {\xB7} $string {\\xB7} string 
 
	# -- \xB8 hex code (ascii: 184 char: ¸ desc: spacing cedilla)
	regsub -all {\xB8} $string {\\xB8} string 
 
	# -- \xB9 hex code (ascii: 185 char: ¹ desc: superscript one)
	regsub -all {\xB9} $string {\\xB9} string 
 
	# -- \xBA hex code (ascii: 186 char: º desc: masculine ordinal indicator)
	regsub -all {\xBA} $string {\\xBA} string 
 
	# -- \xBB hex code (ascii: 187 char: » desc: right double angle quotes)
	regsub -all {\xBB} $string {\\xBB} string 
 
	# -- \xBC hex code (ascii: 188 char: ¼ desc: fraction one quarter)
	regsub -all {\xBC} $string {\\xBC} string 
 
	# -- \xBD hex code (ascii: 189 char: ½ desc: fraction one half)
	regsub -all {\xBD} $string {\\xBD} string 
 
	# -- \xBE hex code (ascii: 190 char: ¾ desc: fraction three quarters)
	regsub -all {\xBE} $string {\\xBE} string 
 
	# -- \xBF hex code (ascii: 191 char: ¿ desc: inverted question mark)
	regsub -all {\xBF} $string {\\xBF} string 
 
	# -- \xC0 hex code (ascii: 192 char: À desc: latin capital letter A with grave)
	regsub -all {\xC0} $string {\\xC0} string 
 
	# -- \xC1 hex code (ascii: 193 char: Á desc: latin capital letter A with acute)
	regsub -all {\xC1} $string {\\xC1} string 
 
	# -- \xC2 hex code (ascii: 194 char: Â desc: latin capital letter A with circumflex)
	regsub -all {\xC2} $string {\\xC2} string 
 
	# -- \xC3 hex code (ascii: 195 char: Ã desc: latin capital letter A with tilde)
	regsub -all {\xC3} $string {\\xC3} string 
 
	# -- \xC4 hex code (ascii: 196 char: Ä desc: latin capital letter A with diaeresis)
	regsub -all {\xC4} $string {\\xC4} string 
 
	# -- \xC5 hex code (ascii: 197 char: Å desc: latin capital letter A with ring above)
	regsub -all {\xC5} $string {\\xC5} string 
 
	# -- \xC6 hex code (ascii: 198 char: Æ desc: latin capital letter AE)
	regsub -all {\xC6} $string {\\xC6} string 
 
	# -- \xC7 hex code (ascii: 199 char: Ç desc: latin capital letter C with cedilla)
	regsub -all {\xC7} $string {\\xC7} string 
 
	# -- \xC8 hex code (ascii: 200 char: È desc: latin capital letter E with grave)
	regsub -all {\xC8} $string {\\xC8} string 
 
	# -- \xC9 hex code (ascii: 201 char: É desc: latin capital letter E with acute)
	regsub -all {\xC9} $string {\\xC9} string 
 
	# -- \xCA hex code (ascii: 202 char: Ê desc: latin capital letter E with circumflex)
	regsub -all {\xCA} $string {\\xCA} string 
 
	# -- \xCB hex code (ascii: 203 char: Ë desc: latin capital letter E with diaeresis)
	regsub -all {\xCB} $string {\\xCB} string 
 
	# -- \xCC hex code (ascii: 204 char: Ì desc: latin capital letter I with grave)
	regsub -all {\xCC} $string {\\xCC} string 
 
	# -- \xCD hex code (ascii: 205 char: Í desc: latin capital letter I with acute)
	regsub -all {\xCD} $string {\\xCD} string 
 
	# -- \xCE hex code (ascii: 206 char: Î desc: latin capital letter I with circumflex)
	regsub -all {\xCE} $string {\\xCE} string 
 
	# -- \xCF hex code (ascii: 207 char: Ï desc: latin capital letter I with diaeresis)
	regsub -all {\xCF} $string {\\xCF} string 
 
	# -- \xD0 hex code (ascii: 208 char: Ð desc: latin capital letter ETH)
	regsub -all {\xD0} $string {\\xD0} string 
 
	# -- \xD1 hex code (ascii: 209 char: Ñ desc: latin capital letter N with tilde)
	regsub -all {\xD1} $string {\\xD1} string 
 
	# -- \xD2 hex code (ascii: 210 char: Ò desc: latin capital letter O with grave)
	regsub -all {\xD2} $string {\\xD2} string 
 
	# -- \xD3 hex code (ascii: 211 char: Ó desc: latin capital letter O with acute)
	regsub -all {\xD3} $string {\\xD3} string 
 
	# -- \xD4 hex code (ascii: 212 char: Ô desc: latin capital letter O with circumflex)
	regsub -all {\xD4} $string {\\xD4} string 
 
	# -- \xD5 hex code (ascii: 213 char: Õ desc: latin capital letter O with tilde)
	regsub -all {\xD5} $string {\\xD5} string 
 
	# -- \xD6 hex code (ascii: 214 char: Ö desc: latin capital letter O with diaeresis)
	regsub -all {\xD6} $string {\\xD6} string 
 
	# -- \xD7 hex code (ascii: 215 char: × desc: multiplication sign)
	regsub -all {\xD7} $string {\\xD7} string 
 
	# -- \xD8 hex code (ascii: 216 char: Ø desc: latin capital letter O with slash)
	regsub -all {\xD8} $string {\\xD8} string 
 
	# -- \xD9 hex code (ascii: 217 char: Ù desc: latin capital letter U with grave)
	regsub -all {\xD9} $string {\\xD9} string 
 
	# -- \xDA hex code (ascii: 218 char: Ú desc: latin capital letter U with acute)
	regsub -all {\xDA} $string {\\xDA} string 
 
	# -- \xDB hex code (ascii: 219 char: Û desc: latin capital letter U with circumflex)
	regsub -all {\xDB} $string {\\xDB} string 
 
	# -- \xDC hex code (ascii: 220 char: Ü desc: latin capital letter U with diaeresis)
	regsub -all {\xDC} $string {\\xDC} string 
 
	# -- \xDD hex code (ascii: 221 char: Ý desc: latin capital letter Y with acute)
	regsub -all {\xDD} $string {\\xDD} string 
 
	# -- \xDE hex code (ascii: 222 char: Þ desc: latin capital letter THORN)
	regsub -all {\xDE} $string {\\xDE} string 
 
	# -- \xDF hex code (ascii: 223 char: ß desc: latin small letter sharp s - ess-zed)
	regsub -all {\xDF} $string {\\xDF} string 
 
	# -- \xE0 hex code (ascii: 224 char: à desc: latin small letter a with grave)
	regsub -all {\xE0} $string {\\xE0} string 
 
	# -- \xE1 hex code (ascii: 225 char: á desc: latin small letter a with acute)
	regsub -all {\xE1} $string {\\xE1} string 
 
	# -- \xE2 hex code (ascii: 226 char: â desc: latin small letter a with circumflex)
	regsub -all {\xE2} $string {\\xE2} string 
 
	# -- \xE3 hex code (ascii: 227 char: ã desc: latin small letter a with tilde)
	regsub -all {\xE3} $string {\\xE3} string 
 
	# -- \xE4 hex code (ascii: 228 char: ä desc: latin small letter a with diaeresis)
	regsub -all {\xE4} $string {\\xE4} string 
 
	# -- \xE5 hex code (ascii: 229 char: å desc: latin small letter a with ring above)
	regsub -all {\xE5} $string {\\xE5} string 
 
	# -- \xE6 hex code (ascii: 230 char: æ desc: latin small letter ae)
	regsub -all {\xE6} $string {\\xE6} string 
 
	# -- \xE7 hex code (ascii: 231 char: ç desc: latin small letter c with cedilla)
	regsub -all {\xE7} $string {\\xE7} string 
 
	# -- \xE8 hex code (ascii: 232 char: è desc: latin small letter e with grave)
	regsub -all {\xE8} $string {\\xE8} string 
 
	# -- \xE9 hex code (ascii: 233 char: é desc: latin small letter e with acute)
	regsub -all {\xE9} $string {\\xE9} string 
 
	# -- \xEA hex code (ascii: 234 char: ê desc: latin small letter e with circumflex)
	regsub -all {\xEA} $string {\\xEA} string 
 
	# -- \xEB hex code (ascii: 235 char: ë desc: latin small letter e with diaeresis)
	regsub -all {\xEB} $string {\\xEB} string 
 
	# -- \xEC hex code (ascii: 236 char: ì desc: latin small letter i with grave)
	regsub -all {\xEC} $string {\\xEC} string 
 
	# -- \xED hex code (ascii: 237 char: í desc: latin small letter i with acute)
	regsub -all {\xED} $string {\\xED} string 
 
	# -- \xEE hex code (ascii: 238 char: î desc: latin small letter i with circumflex)
	regsub -all {\xEE} $string {\\xEE} string 
 
	# -- \xEF hex code (ascii: 239 char: ï desc: latin small letter i with diaeresis)
	regsub -all {\xEF} $string {\\xEF} string 
 
	# -- \xF0 hex code (ascii: 240 char: ð desc: latin small letter eth)
	regsub -all {\xF0} $string {\\xF0} string 
 
	# -- \xF1 hex code (ascii: 241 char: ñ desc: latin small letter n with tilde)
	regsub -all {\xF1} $string {\\xF1} string 
 
	# -- \xF2 hex code (ascii: 242 char: ò desc: latin small letter o with grave)
	regsub -all {\xF2} $string {\\xF2} string 
 
	# -- \xF3 hex code (ascii: 243 char: ó desc: latin small letter o with acute)
	regsub -all {\xF3} $string {\\xF3} string 
 
	# -- \xF4 hex code (ascii: 244 char: ô desc: latin small letter o with circumflex)
	regsub -all {\xF4} $string {\\xF4} string 
 
	# -- \xF5 hex code (ascii: 245 char: õ desc: latin small letter o with tilde)
	regsub -all {\xF5} $string {\\xF5} string 
 
	# -- \xF6 hex code (ascii: 246 char: ö desc: latin small letter o with diaeresis)
	regsub -all {\xF6} $string {\\xF6} string 
 
	# -- \xF7 hex code (ascii: 247 char: ÷ desc: division sign)
	regsub -all {\xF7} $string {\\xF7} string 
 
	# -- \xF8 hex code (ascii: 248 char: ø desc: latin small letter o with slash)
	regsub -all {\xF8} $string {\\xF8} string 
 
	# -- \xF9 hex code (ascii: 249 char: ù desc: latin small letter u with grave)
	regsub -all {\xF9} $string {\\xF9} string 
 
	# -- \xF1 hex code (ascii: 250 char: ú desc: latin small letter u with acute)
	regsub -all {\xF1} $string {\\xF1} string 
 
	# -- \xFB hex code (ascii: 251 char: û desc: latin small letter u with circumflex)
	regsub -all {\xFB} $string {\\xFB} string 
 
	# -- \xFC hex code (ascii: 252 char: ü desc: latin small letter u with diaeresis)
	regsub -all {\xFC} $string {\\xFC} string 
 
	# -- \xFD hex code (ascii: 253 char: ý desc: latin small letter y with acute)
	regsub -all {\xFD} $string {\\xFD} string 
 
	# -- \xFE hex code (ascii: 254 char: þ desc: latin small letter thorn)
	regsub -all {\xFE} $string {\\xFE} string 
 
	# -- \xFF hex code (ascii: 255 char: ÿ desc: latin small letter y with diaeresis)
	regsub -all {\xFF} $string {\\xFF} string 
			
	arm:debug 5 "arm:regex:adapt: string after control code regsub: $string"
	
	# -- set new count after extra chars added
	set length [string length $string]

	# ---- only process if -explicit not used
	
	if {!$isexplicit} {

	# -- foreach char in value
	while {$count < $length} {

		# -- current char we're working with
		set char [string index $string $count]
	
		# -- gather previous and proceeding chars (for dealing with control codes)
		set prior1 [string range $string [expr $count - 1] $count]
		set prior2 [string range $string [expr $count - 2] $count]
		set prior3 [string range $string [expr $count - 3] $count]
		#set prior6 [string range $string [expr $count - 6] $count]
		#set post1 [string range $string $count [expr $count + 1]]
		#set post2 [string range $string $count [expr $count + 2]]
		set post3 [string range $string $count [expr $count + 3]]
		
		#putlog "count: $count prior1: $prior1 prior2: $prior2 prior3: $prior3 post1: $post1 post2: $post2 post3: $post3"
					
		# -- check lowercase (provided char not part of hex code)
		#putloglev d * "arm:regex:adapt: checking lowercase (char: $char)"
		if {[regexp -- {[a-z]} $char] \
			&& ![regexp -- {\\x} $prior1] \
			&& ![regexp -- {\\x} $prior2]} { 
			# putloglev d * "arm:regex:adapt: char: $char is lowercase"
			lappend regexp {[a-z]} 

		# -- check uppercase (provided not part of hex code)
		#putloglev d * "arm:regex:adapt: checking uppercase (char: $char)"
		} elseif {[regexp -- {[A-Z]} $char] \
				&& ![regexp -- {\\x} $prior2] \
				&& ![regexp -- {\\x} $prior3]} { 
				# putloglev d * "arm:regex:adapt: char: $char is uppercase"
				lappend regexp {[A-Z]} 
				
		# -- check numeric (provided not part of hex code)
		#putloglev d * "arm:regex:adapt: checking numeric (char: $char)"
		} elseif {[regexp -- {\d} $char] \
				&& ![regexp -- {\\x} $prior2] \
				&& ![regexp -- {\\x} $prior3]} { 
				# putloglev d * "arm:regex:adapt: char: $char is numeric"
				lappend regexp {\d} 
				
		# -- append literal character
		} else {
				#putloglev d * "arm:regex:adapt: literal char: $char"
				# -- escape special literal chars
	
		# -- do char \ first, but only if not followed by hex code
		#putloglev d * "arm:regex:adapt: checking for \\ (char: $char)"
		if {[regexp -- {\\} $char]} {
			if {[string match "\\x??" $post3]} {
				set range [string range $string [expr $count + 2] [expr $count + 3]]
				if {![regexp -- {[0-9A-F][0-9A-F]} $range]} {
					regsub -all {\\} $char {\\\\} char
				}
			}
		}
		#if {[regexp -- {\\} $char] && ![regexp -- {\x[0-9A-F][0-9A-F]} $post3]} {
		#	regsub -all {\\} $char {\\\\} char
		#}

		#putloglev d * "arm:regex:adapt: checking other special chars (char: $char)"

		regsub -all {\|} $char {\\|} char
		regsub -all {\^} $char {\\^} char
		regsub -all {\.} $char {\\.} char
	 
		# -- take care when dealing with control chars
		regsub -all {\[} $char {\\[} char
		#if {[regexp -- {\[} $char]} {
		#	if {![regexp -- {(?:\x22?|\x31?|\x1F|\x16)} $prior3]} {
		#		regsub -all {\[} $char {\\[} char
		#	}
		#}

		# -- take care when dealing with control chars
		regsub -all {\]} $char {\\]} char
		#if {[regexp -- {\]} $char]} {
		#	if {![regexp -- {(?:\x22?|\x31?|\x1F|\x16)} $prior6]} {
		#		regsub -all {\]} $char {\\]} char
		#	}
		#}
				
		regsub -all {\(} $char {\\(} char
		regsub -all {\)} $char {\\)} char
		regsub -all {\?} $char {\\?} char
		regsub -all {\$} $char {\\$} char
		regsub -all {\+} $char {\\+} char
		regsub -all {\*} $char {\\*} char
		regsub -all {\#} $char {\\#} char
		regsub -all { } $char {\\s} char
			regsub -all {\:} $char {\\:} char	

				lappend regexp $char
		}
				
		incr count
	}
	
	arm:debug 5 "arm:regex:adapt: adaptive regex for string: $string is: [join $regexp]"
	#putlog "[regsub -all { } [join $regexp] {}]" 

	# -- phase 2: make regexp more efficient (process repetitions)
	arm:debug 5 "-----------------------------------------------------------------------------------------------"
	arm:debug 5 "arm:regex:adapt: beginning phase two: process repetitions"
	arm:debug 5 "-----------------------------------------------------------------------------------------------"
	
	set length [llength $regexp]
	set count 0
	set newregex ""
	while {$count < $length} {
		set item [lindex $regexp $count]
		set next [expr $count + 1]
		
		if {$item != [lindex $regexp $next]} {
			# -- item not repeated
			# putloglev d * "arm:regex:adapt: item not repeated: $item"
			lappend newregex $item
			incr count
		} else {
			# -- item is repeated
			# putloglev d * "arm:regex:adapt: item is repeated: $item"
			set repeat 1
			set occur 2
			while {$repeat != 0} {
				set next [expr $next + 1]
				if {$item != [lindex $regexp $next]} {
					# -- no more repeats
					# putloglev d * "arm:regex:adapt: item has no more repeats: $item"
					set repeat 0
				} else {
						# -- repeated
						# putloglev d * "arm:regex:adapt: item is repeated: $item"
						incr occur
				}
			}
			# -- append repeat value
			# putloglev d * "arm:regex:adapt: appending repetitions: $item{$occur}"
			
			# -- remove explicit repetitions?
			if {$isrepeat} { set post "+" } else { set post "{$occur}" }
			
			lappend newregex "$item$post"
			incr count $occur
		}

	}
	
	
	# -- remove spaces between list elements
	set newregex [regsub -all { } [join $newregex] {}]
	
	# ---- end if -explicit
	} else { 
				
		regsub -all {\|} $string {\\|} string
		regsub -all {\^} $string {\\^} string
		regsub -all {\.} $string {\\.} string
		regsub -all {\[} $string {\\[} string
		regsub -all {\]} $string {\\]} string
		regsub -all {\(} $string {\\(} string
		regsub -all {\)} $string {\\)} string
		regsub -all {\?} $string {\\?} string
		regsub -all {\$} $string {\\$} string
		regsub -all {\+} $string {\\+} string
		regsub -all {\*} $string {\\*} string
		regsub -all {\#} $string {\\#} string
		regsub -all { } $string {\\s} string
		regsub -all {\:} $string {\\:} string
		
		set newregex $string 
	}

	
	# -- remove case?
	if {$isnocase} { set newregex "(?i)$newregex" }
	
	# -- resulting adaptive regular expression!
	arm:debug 5 "arm:regex:adapt: adaptive regex built & repetitions processed: $newregex"
	arm:debug 5 "-----------------------------------------------------------------------------------------------"
	
	return [split $newregex];
	
}

putlog "\[@\] Armour: loaded adaptive regex pattern builder."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-11_remotescan.tcl
#
# remote DNSBL/port scan functions (can act standalone on 'remote' bot)
# 

# ---- configuration



# -- debug level
set iscan(debug) 2

# -- how to set channel bans? (chan|x) [x]
set iscan(cfg.ban) "x"

# -- default ban time
set iscan(cfg.ban.time) "1h"


# ------------------------------------------------------------------------------------------------
# REPORT SETTINGS
# ------------------------------------------------------------------------------------------------

# -- send user notices for whitelist entries? (0|1) - [0]
set iscan(cfg.notc.white) 0

# -- send user notices for blacklist entries? (0|1) - [0]
set iscan(cfg.notc.black) 0

# -- send op notices for whitelist entries? (0|1) - [1]
set iscan(cfg.opnotc.white) 1

# -- send op notices for blacklist entries? (0|1) - [1]
set iscan(cfg.opnotc.black) 1

# -- send debug chan notices for whitelist entries? (0|1) - [1]
set iscan(cfg.dnotc.white) 1

# -- send debug chan notices for blacklist entries? (0|1) - [1]
set iscan(cfg.dnotc.black) 1

# -- kick reason for open ports
set iscan(cfg.portscan.reason) "Armour: possible insecure host unintended for IRC -- please install identd"


# ---- binds

# -- trigger scan
bind bot - scan:port arm:bot:send:port
bind bot - scan:dnsbl arm:bot:send:dnsbl
bind bot - scan:whois arm:bot:send:whois

# -- receive scan response
bind bot - recv:port arm:bot:recv:port
bind bot - recv:dnsbl arm:bot:recv:dnsbl
bind bot - recv:whois arm:bot:recv:whois

# -- whois response
bind raw - 319 arm:raw:chanlist

# ---- procedures

proc arm:bot:recv:port {bot cmd text} {
	global arm gklist chanban

	set ip [lindex $text 0]
	set host [lindex $text 1]
	# -- target can be 0 if manual scan
	set target [lindex $text 2]
	# -- chan can be 0 if manual scan
	set chan [lindex $text 3]
	set openports [lrange $text 4 end]
	
	if {$openports == "NULL"} { return; }

	arm:debug 1 "arm:bot:recv:port: insecure host (host: $host ip: $ip openports: $openports)"

	if {$chan != 0} {
		set nick [lindex [split $target !] 0]
		
		set mask "*!*@$host"
		set mask2 "*!~*@$host"
		
		# -- don't continue if nick already exists in global kick list (caught by floodnet detection)
		if {[lsearch $gklist $nick] != -1 || [info exists chanban($chan,$mask)] || [info exists chanban($chan,$mask2)]} { return; }

		# -- minimum number of open ports before action
		set min $arm(cfg.portscan.min)
		# -- divide list length by two as each has two args
		set portnum [expr [llength $openports] / 2]
		
		if {$portnum >= $min} {
			arm:kickban $nick $chan $mask2 $arm(cfg.ban.time) $arm(cfg.portscan.reason)
			arm:report black $chan "Armour: $target insecure host (\002open ports:\002 $openports \002reason:\002 install identd)"
		}
	}
	return;
}

proc arm:bot:recv:dnsbl {bot cmd text} {
	global arm gklist chanban
	
	set ip [lindex $text 0]
	set host [lindex $text 1]
	set target [lindex $text 2]
	set chan [lindex $text 3]

	set data [lrange $text 4 end]

	if {$data == "NULL"} { return; }

	set response [join [lindex $data 1]]
	set score [lindex $data 2]
		
	set rbl [lindex $response 1]
	set desc [lindex $response 2]
	set info [lindex $response 3]
	
	# {{+1.0 dnsbl.swiftbl.org SwiftRBL {{DNSBL. 80.74.160.3 is listed in SwiftBL (SOCKS proxy)}}} {+1.0 rbl.efnetrbl.org {Abusive Host} NULL}}

	arm:debug 1 "arm:bot:recv:dnsbl: dnsbl data: $data"
			
	arm:debug 1 "arm:bot:recv:dnsbl: dnsbl match found for $target: $response"
	arm:debug 1 "arm:scan: ------------------------------------------------------------------------------------"
	set nick [lindex [split $target !] 0]
	
	set mask "*!*@$host"
	
	# -- don't continue if nick already exists in global kick list (caught by floodnet detection)
	if {[lsearch $gklist $nick] != -1 || [info exists chanban($chan,$mask)]} { return; }
	
	if {[join $info] == "NULL"} { set info "" } else { set info [join $info] }

	arm:kickban $nick $chan $mask $arm(cfg.ban.time) "Armour: DNSBL blacklisted (\002ip:\002 $ip \002rbl:\002 $rbl \002desc:\002 $desc \002info:\002 $info)"

	arm:report black $chan "Armour: DNSBL match found on $target (\002ip:\002 $ip \002rbl:\002 $rbl \002desc:\002 $desc \002info:\002 $info)"
	return;
			
}


proc arm:bot:send:port {bot cmd text} {
	global arm
	
	set start [clock clicks]
	# arm:debug 1 "arm:bot:send:port: started.  cmd: $cmd text: $text"
	set ip [lindex $text 0]
	set host [lindex $text 1]
	# -- target can be 0 if manual scan
	set target [lindex $text 2]
	# -- chan can be 0 if manual scan
	set chan [lindex $text 3]

	arm:debug 1 "arm:bot:send:port: (from: $bot) -- executing port scanner: $ip (host: $host)"
	set openports [arm:port:scan $ip]
	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"
	if {$openports != ""} {
		arm:debug 1 "arm:bot:send:port: insecure host (host: $host ip: $ip) - runtime: $runtime"
		putbot $bot "recv:port $ip $host $target $chan $openports"

	} else {
			arm:debug 1 "arm:bot:send:port: no open ports found (host: $host ip: $ip) - runtime: $runtime"
			putbot $bot "recv:port $ip $host $target $chan NULL"
	}
	return;
}

proc arm:bot:send:dnsbl {bot cmd text} {
	global arm
	# arm:debug 1 "arm:bot:send:dnsbl: started. cmd: $cmd text: $text"
	set start [clock clicks]
	set ip [lindex $text 0]
	set host [lindex $text 1]
	set target [lindex $text 2]
	set chan [lindex $text 3]
	if {[string match "*:*" $ip]} {
		# -- don't continue if IPv6 (TODO)
		arm:debug 1 "arm:bot:send:dnsbl: (from: $bot) -- halting scan for IPv6 dnsbl IP (ip: $ip)"
		return;
	}
	arm:debug 1 "arm:bot:send:dnsbl: (from: $bot) -- scanning for dnsbl match: $ip (host: $host)"
	# -- get score
	set response [arm:rbl:score $ip]
	set ip [lindex $response 0]
	set score [lindex [join $response] 1]
	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"
	if {$ip != $host} { set dst "$ip ($host)" } else { set dst $ip }
	if {$score <= 0} { 
		# -- no match found
		arm:debug 1 "arm:bot:send:dnsbl: no dnsbl match found for $host ($runtime)"
		putbot $bot "recv:dnsbl $ip $host $target $chan NULL"
		return;
	}
			
	putbot $bot "recv:dnsbl $ip $host $target $chan $response"

	arm:debug 1 "arm:bot:send:dnsbl: dnsbl match found ($runtime) for $host: $response ($runtime)"
	return;
}

proc arm:bot:send:whois {bot cmd text} {
	global whois
	set nick [lindex $text 0]
	set chan [lindex $text 1]
	arm:debug 1 "arm:bot:send:whois: (from: $bot) -- sending to server: /WHOIS [join $nick]"
	set whois(bot,$nick) $bot
	set whois(chan,$nick) $chan
	putserv "WHOIS [join $nick]"
}

proc arm:raw:chanlist {server cmd args} {
	global arm whois gklist wline bline hits

	set args [split $args]
	set nick [lindex $args 1]

	# -- only continue if /whois enabled (for channel whitelists and blacklists)
	if {[info exists arm(cfg.whois)]} {
		if {!$arm(cfg.whois)} { return; }
	} 
	if {![info exists whois(bot,$nick)] || ![info exists whois(chan,$nick)]} { return; }

	set bot $whois(bot,$nick)
	set chan $whois(chan,$nick)

	set chanlist [lrange $args 2 end]
	set chanlist [split $chanlist ":"]
	set chanlist [lrange $chanlist 1 end]
 
	set newlist "" 

	foreach channel [join $chanlist] {
		# -- only take the channel, not prefixed modes
		if {[string index $channel 0] != "#"} { set channel [string range $channel 1 end] } else { set channel $channel }
		lappend newlist $channel
	}

	set chanlist [join $newlist]

	# -- free array
	catch { unset whois(bot,$nick) }
	catch { unset whois(chan,$nick) }
	
	arm:debug 1 "arm:raw:chanlist: whois chanlist found for [join $nick]: $chanlist"

	if {$bot != 0} {
		# -- /whois was REMOTE lookup, send the channel list remotely
		putbot $bot "recv:whois $nick $chan $chanlist"
		return;
	}
	
	# -- /whois was LOCAL lookup, necessitates local processing

	# -- don't continue if nick already exists in global kick list (caught by floodnet detection)
	if {![info exists gklist]} { set gklist "" }
	if {[lsearch $gklist $nick] != -1} { return; }

	# ----- whitelist checks

	# -- sort whitelists (we do this so we can issue scans in a logical order)
	set wsort(list) [lsort [array names wline]]
	set wchan ""

	foreach white $wsort(list) {
		set line [split $white ,]
		set wtype [lindex $line 0]
		set value [lindex $line 1]
		if {$wtype == "chan"} { append wchan "$white " }
	}

	if {$wchan != ""} { arm:debug 5 "arm:raw:chanlist: sorted whitelist: chan: $wchan" }
	
	# -- begin whitelist: chan
	if {$wchan != ""} { 
		# -- match against common channels of mine here, do /WHOIS externally for rest
		foreach entry $wchan {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:raw:chanlist: whitelist scanning: wline($method,$value)"
			# -- search for a match (including wildcarded entries)
			if {[lsearch [string tolower $chanlist] [string tolower $value]] != -1} {
					# -- match: take whitelist action!
					set action [arm:list2action $wline($method,$value)]
					set reason [join [lrange [split $wline($method,$value) :] 9 end]]
					arm:debug 1 "arm:raw:chanlist: whitelist matched chanlist: wline($method,$value) -- taking action!"
					arm:debug 2 "arm:raw:chanlist: ------------------------------------------------------------------------------------"
					set mode [arm:wlist2mode $wline($method,$value)]
					if {$mode != ""} { putquick "MODE $chan $mode [join $nick]" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
					set uhost [getchanhost [join $nick] $chan] 
					set id [arm:get:id white $method $value]
					arm:report white $nick "Armour: [join $nick]!$uhost whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
					# -- incr statistics
					incr hits($id)
					catch { unset exempt($nick) }
					catch { unset fullname($nick) }
					# -- remove nick from securelist (scan list from /names -d)
					#arm:listremove securelist $nick
					arm:clean:scanlist $nick
					# -- pass join arguments to other standalone scripts, if configured
					# - WARNING: because /whois is delayed, this could send the join to the external script twice. don't do this.
					# arm:integrate $nick $uhost $hand $chan
					return;
			}
		}
		# -- end of foreach
	}
	# -- end of whitelist: chan

	# ----- blacklist checks

	# -- sort blacklists (we do this so we can issue scans in a logical order)
	set bsort(list) [lsort [array names bline]]
	set bchan ""

	foreach black $bsort(list) {
		set line [split $black ,]
		set btype [lindex $line 0]
		set value [lindex $line 1]
		if {$btype == "chan"} { append bchan "$black " }
	}

	if {$bchan != ""} { arm:debug 5 "arm:raw:chanlist: sorted blacklist: chan: $bchan" }

	# -- begin blacklist: chan
	if {$bchan != ""} { 
		# -- match against common channels of mine here, do /WHOIS externally for rest
		foreach entry $bchan {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:raw:chanlist: blacklist scanning: bline($method,$value)"
			if {[lsearch [string tolower $chanlist] [string tolower $value]] != -1} {
				# -- match: take blacklist action!
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:raw:chanlist: blacklist matched chanlist: bline($method,$value) -- taking action!"
				arm:debug 2 "arm:raw:chanlist: ------------------------------------------------------------------------------------"
				# -- only show the channel itself in the reason if configured to
				if {$arm(cfg.bchan.reason) == 1} { set string "Armour: blacklisted -- $value (reason: $reason)" } else { set string "Armour: blacklisted -- reason: $reason" }
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				set uhost [getchanhost [join $nick] $chan]
				set host [lindex [split $uhost "@"] 1]
				set id [arm:get:id black $method $value]
				
				if {$host == ""} { 
					 # -- safety net in case nick has already left channel (or been kicked)
					if {[info exists newjoin($nick)]} {
						set host [lindex [split $newjoin($nick) "@"] 1]
					}
				}
				# -- double saftey net
				if {$host != ""} {
					arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
					arm:report black $chan "Armour: $nick!$uhost blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002reason:\002 $reason)"
				}
				# -- incr statistics
				incr hits($id)
				catch { unset exempt($nick) }
				catch { unset fullname($nick) }
				# -- remove nick from securelist (scan list from /names -d)
				#arm:listremove securelist $nick
				arm:clean:scanlist $nick
				return;
			}
		}
		# -- end of foreach
	}
	# -- end of blacklist: chan
	
	return;
}

proc arm:bot:recv:whois {bot cmd text} {
	global arm wline bline hits gklist
	
	set nick [lindex $text 0]
	set chan [lindex $text 1]
	set chanlist [lrange $text 2 end]

	arm:debug 2 "arm:bot:recv:whois received chanlist for [join $nick]: [join $chanlist]"

	# -- don't continue if nick already exists in global kick list (caught by floodnet detection)
	if {[lsearch $gklist $nick] != -1} { return; }

	# ----- whitelist checks

	# -- sort whitelists (we do this so we can issue scans in a logical order)
	set wsort(list) [lsort [array names wline]]
	set wchan ""

	foreach white $wsort(list) {
		set line [split $white ,]
		set wtype [lindex $line 0]
		set value [lindex $line 1]
		if {$wtype == "chan"} { append wchan "$white " }
	}

	if {$wchan != ""} { arm:debug 5 "arm:bot:recv:whois: sorted whitelist: chan: $wchan" }

	# -- begin whitelist: chan
	if {$wchan != ""} { 
		# -- match against common channels of mine here, do /WHOIS externally for rest
		foreach entry $wchan {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:bot:recv:whois: whitelist scanning: wline($method,$value)"
			# -- search for a match (including wildcarded entries)
			if {[lsearch [string tolower $chanlist] [string tolower $value]] != -1} {
					# -- match: take whitelist action!
					set action [arm:list2action $wline($method,$value)]
					set reason [join [lrange [split $wline($method,$value) :] 9 end]]
					arm:debug 1 "arm:bot:recv:whois: whitelist matched chanlist: wline($method,$value) -- taking action!"
					arm:debug 2 "arm:bot:recv:whois: ------------------------------------------------------------------------------------"
					set mode [arm:wlist2mode $wline($method,$value)]
					if {$mode != ""} { putquick "MODE $chan $mode [join $nick]" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
					set uhost [getchanhost [join $nick] $chan] 
					set id [arm:get:id white $method $value]	
					arm:report white $nick "Armour: [join $nick]!$uhost whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
					# -- incr statistics
					incr hits($id)
					catch { unset exempt($nick) }
					catch { unset fullname($nick) }
					# -- remove nick from securelist (scan list from /names -d)
					#arm:listremove securelist $nick
					arm:clean:scanlist $nick
					return;
			}
		}
		# -- end of foreach
	}
	# -- end of whitelist: chan

	# ----- blacklist checks

	# -- sort blacklists (we do this so we can issue scans in a logical order)
	set bsort(list) [lsort [array names bline]]
	set bchan ""

	foreach black $bsort(list) {
		set line [split $black ,]
		set btype [lindex $line 0]
		set value [lindex $line 1]
		if {$btype == "chan"} { append bchan "$black " }
	}

	if {$bchan != ""} { arm:debug 5 "arm:bot:recv:whois: sorted blacklist: chan: $bchan" }

	# -- begin blacklist: chan
	if {$bchan != ""} { 
		# -- match against common channels of mine here, do /WHOIS externally for rest
		foreach entry $bchan {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:bot:recv:whois: blacklist scanning: bline($method,$value)"
			if {[lsearch [string tolower $chanlist] [string tolower $value]] != -1} {
				# -- match: take blacklist action!
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:bot:recv:whois: blacklist matched chanlist: bline($method,$value) -- taking action!"
				arm:debug 2 "arm:bot:recv:whois: ------------------------------------------------------------------------------------"
				# -- only show the channel itself in the reason if configured to
				if {$arm(cfg.bchan.reason) == 1} { set string "Armour: blacklisted -- $value (reason: $reason)" } else { set string "Armour: blacklisted -- reason: $reason" }
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				set uhost [getchanhost [join $nick] $chan]
				set host [lindex [split $uhost "@"] 1]
				set id [arm:get:id black $method $value]
				
				if {$host == ""} { 
					 # -- safety net in case nick has already left channel (or been kicked)
					if {[info exists newjoin($nick)]} {
						set host [lindex [split $newjoin($nick) "@"] 1]
					}
				}
				# -- double saftey net
				if {$host != ""} {
					arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
					arm:report black $chan "Armour: $nick!$uhost blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002reason:\002 $reason)"
				}
				# -- incr statistics
				incr hits($id)
				catch { unset exempt($nick) }
				catch { unset fullname($nick) }
				# -- remove nick from securelist (scan list from /names -d)
				#arm:listremove securelist $nick
				arm:clean:scanlist $nick
				return;
			}
		}
		# -- end of foreach
	}
	# -- end of blacklist: chan
 
}



proc arm:kickban {nick chan mask duration reason} {
	global arm chanban
	
	if {![info exists chanban($chan,$mask)]} {
		# -- mask not banned already, do the ban
		set chanban($chan,$mask) 1
		set addban 1
		# -- unset with minute timer
		arm:debug 1 "arm:kickban adding array: chanban($chan,$mask)... unsetting in $arm(cfg.time.newjoin) secs"
		set chanban($chan,$mask) 1
		utimer $arm(cfg.time.newjoin) "arm:unset:chanban $chan $mask"
	} else { set addban 0 }
	
	# -- get units
	regexp -- {(\d+)([A-Za-z])} $duration -> time unit
	set unit [string tolower $unit]
	
	if {[string tolower $arm(cfg.ban)] == "chan"} {
		# -- channel ban
		arm:debug 1 "arm:kickban adding chan kickban -- nick: $nick chan: $chan mask: $mask duration: $duration"
		if {$addban} {
			putquick "MODE $chan +b $mask" -next
			
		}
		# -- kick the guy!
		# putkick $chan $nick $reason
		putquick "KICK $chan $nick :$reason" -next
		
		if {$unit == "h"} { 
			# -- unit is hours
			set time [expr $time * 60]
			timer $time "arm:unban $chan $mask"
		} elseif {$unit == "s"} {
				# -- unit is secs
				utimer $time "arm:unban $chan $mask"
		} elseif {$unit == "m"} {
				# -- unit is mins
				set time [expr $time * 60]
				timer $time "arm:unban $chan $mask"
		}
		
		arm:debug 1 "arm:kickban ending procedure (debug)..."
		
		return;
		
	} elseif {[string tolower $arm(cfg.ban)] == "x"} {
		# -- X ban
		if {$addban} {
			set level 100
			arm:debug 1 "arm:kickban adding X ban -- chan: $chan mask: $mask duration: $duration"
			putquick "PRIVMSG X :BAN $chan $mask $duration $level $reason" -next
		} else {
				# -- if already in X's banlist, no need to kick?
				# putquick "PRIVMSG X :KICK $chan $nick $reason" -next 
		}
	} else {
			arm:debug 1 "arm:kickban error: value of \$arm(cfg.ban) needs to be \"cha\" or \"x\""
	}

}

# -- arm:unset:chanban
# clear chanban record
proc arm:unset:chanban {chan mask} {
	global chanban
	if {[info exists chanban($chan,$mask)]} {
		# -- chanban exists!
		arm:debug 1 "arm:unset:chanban: unsetting chanban array: chanban($chan,$mask)"
		unset chanban($chan,$mask)
	} else {
		arm:debug 1 "arm:unset:chanban: chanban array does not exist: chanban($chan,$mask)"
	}
}

proc arm:unban {chan mask} {
	arm:debug 1 "arm:unban: unbanning $mask in $chan"
	putquick "MODE $chan -b $mask" -next
}

# -- grab values from Armour config if this is not a standalone scan bounce bot
if {![info exists arm(cfg.ban)]} { set arm(cfg.ban) $iscan(cfg.ban) }
if {![info exists arm(cfg.ban.time)]} { set arm(cfg.ban.time) $iscan(cfg.ban.time) }
if {![info exists arm(debug)]} { set arm(debug) $iscan(debug) }
if {![info exists arm(cfg.notc.white)]} { set arm(cfg.notc.white) $iscan(cfg.notc.white) }
if {![info exists arm(cfg.opnotc.white)]} { set arm(cfg.opnotc.white) $iscan(cfg.opnotc.white) }
if {![info exists arm(cfg.dnotc.white)]} { set arm(cfg.dnotc.white) $iscan(cfg.dnotc.white) }
if {![info exists arm(cfg.notc.black)]} { set arm(cfg.notc.black) $iscan(cfg.notc.black) }
if {![info exists arm(cfg.opnotc.black)]} { set arm(cfg.opnotc.black) $iscan(cfg.opnotc.black) }
if {![info exists arm(cfg.dnotc.black)]} { set arm(cfg.dnotc.black) $iscan(cfg.dnotc.black) }
if {![info exists arm(cfg.portscan.reason)]} { set arm(cfg.portscan.reason) $iscan(cfg.portscan.reason) }
set scan(cfg.ban.time) $arm(cfg.ban.time)

# -- debug proc -- we use this alot
proc arm:debug {level string} {
	global arm
	#if {$level <= $arm(debug)} { putloglev d * "$string"; }
	if {$level == 0} { putlog "$string"; } elseif {$level <= $arm(debug)} { putloglev d * "$string"; }
}


proc arm:report {type target string} {
	global arm full
	
	# -- obtain the right chan for opnotice
	if {[info exists full]} {
		# -- full channel scan under way
		set list [lsort [array names full]]
		foreach channel $list {
			set chan [lindex [split $channel ,] 1]    
		}
		if {![info exists chan]} { set chan $arm(cfg.chan.auto) }
	} else { set chan $arm(cfg.chan.auto) }
	if {$type == "white"} {
		if {$arm(cfg.notc.white)} { putquick "NOTICE $target :$string" }
		if {$arm(cfg.opnotc.white)} { putquick "NOTICE @$chan :$string" }
		if {$arm(cfg.dnotc.white)} { putquick "NOTICE $arm(cfg.chan.report) :$string"}
	}
	if {$type == "black"} {
		if {$arm(cfg.notc.black)} { putquick "NOTICE $target :$string" }
		if {$arm(cfg.opnotc.black)} { putquick "NOTICE @$chan :$string" }
		if {$arm(cfg.dnotc.black)} { putquick "NOTICE $arm(cfg.chan.report) :$string" }
	}
}

putlog "\[@\] Armour: loaded remote dnsbl & portscan procedures."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-12_cmds.tcl
#
# core user commands
#

# -- commands

# -- generic procedure template
# a starting point for all command procedures
proc arm:cmd:CMD {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "CMD"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- end default proc template

	# INSERT PROC SPECIFIC STUFF HERE

}

# -- command: help
# command help topics
proc arm:cmd:help {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm armbind 
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "help"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- command: help

	set command [string tolower [lindex $args 0]]

	if {$command == "help"} { arm:reply $stype $starget "\002usage:\002 help \[command\]"; return; }
	
	set user [userdb:uline:get user nick $nick]
	set level [userdb:uline:get level user $user]
	
	if {$command == "" || $command == "cmds" || $command == "commands"} {
		# -- show a list of commands this guy has access to
		foreach i [array names userdb] {
			set line [split $i ,]
			lassign $line a c t
			if {$a != "cmd" || $t != $type} { continue; }
			# -- don't include the single char shortcut commands
            if {[string length $c] == 1} { continue; }
			set l $userdb($i)
			if {$level >= $l} {
				# -- has access to command (and bind type)
				lappend cmdlist $c
			}
		}
		if {$cmdlist == ""} { arm:reply $stype $starget "error: no access to commands."; return; }
		# -- send the command list
		arm:reply $stype $starget "commands: [join [lsort -dictionary $cmdlist]]"
		
		# -- create log entry for command use
		arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
		return;	
	}
	
	set command [string tolower $command]
	# -- find the help topic
	set notopic 0
	if {[file exists $arm(cfg.dir.prefix)/help/$command.help]} { 
		# -- standard armour command
		set file "$arm(cfg.dir.prefix)/help/$command.help"
	} elseif {[file exists $arm(cfg.dir.prefix)/plugins/help/$command.help]} { 
		# -- plugin help topic
		set file "$arm(cfg.dir.prefix)/plugins/help/$command.help"
	} else {
		# -- try to see if plugin has its own help directory
		# -- find the prefix first. assume 'msg' bind is most easy way to find
		if {[info exists armbind(cmd,$command,msg)]} {
			set prefix $armbind(cmd,$command,msg)
			if {[file exists $arm(cfg.dir.prefix)/plugins/$prefix/help/$command.help]} { 
				set file "$arm(cfg.dir.prefix)/plugins/$prefix/help/$command.help"
			} else { set notopic  1 }
		} else {
			set notopic 1
		}
		if {$notopic} {
			# -- help topic doesn't exist
			arm:reply $stype $starget "error: no such help topic exists. try: help cmds"
			return;
		}
	}
	
	# -- set level required
	set req $userdb(cmd,$command,$type)
	
	if {$level >= $req} {
		# -- user has access to command
		set fd [open $file r]
		set data [read $fd]
		set lines [split $data \n]
		foreach line $lines {
			# -- string replacements:
			# - %LEVEL%	level required
			# - %B%		bold text
			regsub -all {%LEVEL%} $line $req line
			regsub -all {%B%} $line \x02 line
			arm:reply $stype $starget $line
		}
		close $fd
	}
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}


# -- command: op
# usage: op ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:op {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "op"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- end default proc template
	
	set user [userdb:uline:get user nick $nick]

	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { set chan $first; set oplist [lrange $args 1 end] } else {
		set oplist [lrange $args 0 end]
	}
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to op when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to op someone when not oppped myself"; return; }
	
	set length [llength $oplist]
	if {$oplist == ""} {
		# -- op individual
		arm:debug 0 "arm:cmd:op: opping $nick on $chan"
		putquick "MODE $chan +o $nick"
	} else {
		while {$oplist != ""} {
			if {$length >= 6} { set modes "+oooooo" } else { set modes "+[string repeat "o" $length]" }
			arm:debug 2 "arm:cmd:op: executing: MODE $chan $modes [join [lrange $oplist 0 5]]"
			putquick "MODE $chan $modes [join [lrange $oplist 0 5]]"
			set oplist [lreplace $oplist 0 5]
		}
	}
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}

# -- command: deop
# usage: deop ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:deop {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "deop"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- end default proc template
	
	set user [userdb:uline:get user nick $nick]

	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { set chan $first; set deoplist [lrange $args 1 end] } else {
		set deoplist [lrange $args 0 end]
	}
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to deop when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to deop someone when not oppped myself"; return; }
	
	if {[lsearch $deoplist $botnick] != -1} { arm:reply $type $target "uhh... I don't think so."; return; }
		
	set length [llength $deoplist]
	if {$deoplist == ""} {
		# -- op individual
		arm:debug 0 "arm:cmd:deop: deopping $nick on $chan"
		putquick "MODE $chan -o $nick"
	} else {
		while {$deoplist != ""} {
			if {$length >= 6} { set modes "-oooooo" } else { set modes "-[string repeat "o" $length]" }
			arm:debug 2 "arm:cmd:deop: executing: MODE $chan $modes [join [lrange $deoplist 0 5]]"
			putquick "MODE $chan $modes [join [lrange $deoplist 0 5]]"
			set deoplist [lreplace $deoplist 0 5]
		}
	}
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}

# -- command: voice
# usage: voice ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:voice {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "voice"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }

	# -- end default proc template
	set user [userdb:uline:get user nick $nick]
	set voicelist ""

	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { set chan $first; set voicelist [lrange $args 1 end] } else {
		set voicelist [lrange $args 0 end]
	}
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to voice when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to voice someone when not oppped myself"; return; }
	
	set length [llength $voicelist]
	if {$voicelist == ""} {
		# -- op individual
		arm:debug 0 "arm:cmd:voice: voicing $nick on $chan"
		putquick "MODE $chan +v $nick"
	} else {
		while {$voicelist != ""} {
			if {$length >= 6} { set modes "+vvvvvv" } else { set modes "+[string repeat "v" $length]" }
			arm:debug 2 "arm:cmd:voice: executing: MODE $chan $modes [join [lrange $voicelist 0 5]]"
			putquick "MODE $chan $modes [join [lrange $voicelist 0 5]]"
			set voicelist [lreplace $voicelist 0 5]
		}
	}
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}

# -- command: devoice
# usage: devoice ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:devoice {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "devoice"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	set devoicelist ""

	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { set chan $first; set devoicelist [lrange $args 1 end] } else {
		set devoicelist [lrange $args 0 end]
	}
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to devoice when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to devoice someone when not oppped myself"; return; }
	
	if {[lsearch $devoicelist $botnick] != -1} { arm:reply $type $target "uhh... I don't think so."; return; }
	
	set length [llength $devoicelist]
	if {$devoicelist == ""} {
		# -- op individual
		arm:debug 0 "arm:cmd:devoice: devoicing $nick on $chan"
		putquick "MODE $chan -v $nick"
	} else {
		while {$devoicelist != ""} {
			if {$length >= 6} { set modes "-vvvvvv" } else { set modes "-[string repeat "v" $length]" }
			arm:debug 2 "arm:cmd:devoice: executing: MODE $chan $modes [join [lrange $devoicelist 0 5]]"
			putquick "MODE $chan $modes [join [lrange $devoicelist 0 5]]"
			set devoicelist [lreplace $devoicelist 0 5]
		}
	}
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}

# -- command: invite
# usage: invite ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:invite {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "invite"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { set chan $first; set invitelist [lrange $args 1 end] } else {
		set invitelist [lrange $args 0 end]
	}
	
	if {![botisop $chan]} { arm:reply $type $target "unable to invite, not opped."; return; }
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to invite when not in a channel."; return; }
	
	if {$invitelist == ""} {
		# -- op individual
		if {[onchan $nick $chan]} { arm:reply $type $target "you are already on $chan."; return; }
		arm:debug 0 "arm:cmd:invite: inviting $nick to $chan"
		putquick "INVITE $nick $chan"
		arm:reply $type $target "done."
	} else {
		set onchan [list]
		foreach tnick $invitelist {
			if {[onchan $tnick $chan]} { lappend onchan $tnick; continue; }
			arm:debug 0 "arm:cmd:invite: inviting $tnick to $chan"
			putquick "INVITE $tnick $chan"	
		}
		if {[llength $onchan] != "0"} { arm:reply $type $target "already on channel: [join $onchan]" } \
		else { arm:reply $type $target "done."	}
	}
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}

# -- command: kick
# usage: kick ?chan? <nick1,nick2,nick3...> [reason]
proc arm:cmd:kick {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "kick"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} {
		set chan $first
		set kicklist [lindex $args 1]
		set reason [lrange $args 2 end]
	} else {
		set kicklist [lindex $args 0]
		set reason [lrange $args 1 end]
	}

	set kicklist [split $kicklist ,]
	set length [llength $kicklist]
	
	if {[lsearch $kicklist $botnick] != -1} { arm:reply $type $target "uhh... I don't think so."; return; }
	
	if {$reason == ""} { set reason $arm(cfg.def.breason) }
	
	if {$kicklist == ""} { arm:reply $stype $starget "\002usage:\002 kick ?chan? <nick1,nick2,nick3...> \[reason\]"; return; }
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to kick when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to kick someone when not oppped myself"; return; }
	
	arm:debug 0 "arm:cmd:kick: kicking $length users from $chan"
	
	set noton [list]
	foreach client $kicklist {
		if {![onchan $client $chan]} { lappend noton $client; continue; }
		putquick "KICK $chan $client :$reason"
	}
	
	if {[join $noton] != ""} { arm:reply $type $target "not on channel: [join $noton]" }
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}

# -- command: ban
# usage: ban ?chan? <nick|mask..> [duration] [reason]
proc arm:cmd:ban {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "ban"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	#  usage: ban ?chan? <nick1,mask1,nick2,mask2,mask3...> [duration] [reason]
	
	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { 
		set chan $first
		set banlist [lindex $args 1]
		set duration [lindex $args 2]
		if {[string is digit $duration]} {
			# -- duration given
			set reason [lrange $args 3 end]
		} else {
			# -- no duration
			set duration ""
			set reason [lrange $args 2 end]
		}
	} else {
		set banlist [lindex $args 0]
		set duration [lindex $args 1]
		if {[string is digit $duration]} {
			# -- duration given
			set reason [lrange $args 2 end]
		} else {
			# -- no duration
			set duration ""
			set reason [lrange $args 1 end]
		}
	}
	
	set banlist [split $banlist ,]
	set length [llength $banlist]
	
	if {[lsearch $banlist $botnick] != -1} { arm:reply $type $target "uhh... I don't think so."; return; }
	
	if {$reason == ""} { set reason $arm(cfg.def.breason) }
	if {$duration == ""} { set duration $arm(cfg.ban.time) }
	
	if {$banlist == ""} { arm:reply $stype $starget "\002usage:\002 ban ?chan? <nick1,mask1,nick2,mask2,mask3...> \[duration\] \[reason\]"; return; }

	arm:debug 2 "arm:cmd:ban: chan: $chan -- banlist: $banlist -- duration: $duration -- reason: $reason"

	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to ban when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to set bans when not oppped myself"; return; }
	
	arm:debug 0 "arm:cmd:ban: banning $length targets from $chan"
	
	foreach item $banlist {
		arm:debug 0 "arm:cmd:ban: item: $item"
		if {[string match "\*" $item]} {
			# -- hostmask
			set tmask $item
			set tnick 0
			arm:debug 0 "arm:cmd:ban: item is hostmask: $tmask"
		} else {
			# -- nickname
			set thost [getchanhost $item $chan]
			set tmask "*!*$thost"
			set tnick $item
			arm:debug 0 "arm:cmd:ban: item was nickname ($item), now host: $tmask"
		}
		arm:kickban $tnick $chan $tmask $duration $reason
	}
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}


# -- command: unban
# usage: unban ?chan? <nick1,nick2,nick3...>
proc arm:cmd:unban {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "unban"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} {
			set chan $first
			set unbanlist [lindex $args 1]
	} else {
			set unbanlist [lindex $args 0]
	}

	set unbanlist [split $unbanlist ,]
	set length [llength $unbanlist]

	if {$unbanlist == ""} { arm:reply $stype $starget "\002usage:\002 unban ?chan? <nick1,nick2,mask1...>"; return; }
		
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to unban when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to unset bans when not oppped myself"; return; }

	# -- deal with the unbanlist (look for nicknames)
	set ublist [list]
	foreach i $unbanlist {
		if {![string match \* $i]} {
			# -- it's a nickname, check if we can see it
			set chanhost [getchanhost $i]
			if {$chanhost == ""} { continue; }
			# -- build the banmask
			set mask [maskhost "$i![getchanhost $i]"]
			lappend ublist $mask
		}
		lappend ublist $i
	}

	set length [llength $ublist]

    arm:debug 0 "arm:cmd:unban: unbanning $length hostmasks from $chan"
    if {$length >= 6} { set modes "-bbbbbb" } else { set modes "-[string repeat "b" $length]" }
	putnow "MODE $chan $modes [join $ublist]"
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}


# -- command: topic
# usage: topic ?chan? <topic>
proc arm:cmd:topic {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "topic"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	# -- check for channel
	set first [lindex $args 0]
	if {[string index $first 0] == "#"} { set chan $first; set topic [lrange $args 1 end] } else {
		set topic [lrange $args 0 end]
	}
	
	if {![onchan $botnick $chan]} { arm:reply $type $target "unable to set topics when not in a channel."; return; }
	if {![botisop $chan]} { arm:reply $type $target "unable to set topics when not oppped myself"; return; }
	
	if {$topic == ""} { arm:reply $stype $starget "topic: ?chan? <topic>"; return; }
 
	set topic "$topic ([userdb:uline:get user curnick $nick])"
	arm:debug 0 "arm:cmd:topic: setting topic in $chan: $topic"
	putquick "TOPIC $chan :$topic"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}


# -- command: black
# usage: black <nick>
# adds blacklist entry and kickbans <nick> from chan
proc arm:cmd:black {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm black
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "black"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set tnick [lindex $args 0]
	set reason [lrange $args 1 end]
	
	if {$tnick == ""} { arm:reply $stype $starget "\002usage:\002 black <nick> \[reason\]"; return; }
	if {![onchan $tnick $chan]} { arm:reply $type $target "uhh... who is $tnick?"; return; }
	if {[string tolower $nick] == [string tolower $tnick]} { arm:reply $type $target "uhh... mirror?"; return; }
	
	if {[validuser [nick2hand $tnick]] || [isop $tnick $chan] || [userdb:isLogin $tnick]} { arm:reply $type $target "uhh... I don't think so."; return; }
	
	if {$reason == ""} { set reason $arm(cfg.def.breason) }
	
	# -- execute /who so we know what to add & kickban
	
	arm:debug 1 "arm:cmd:black: $nick requesting black hit on $tnick, sending /who" 
	
	set nick [split $tnick]
	set black($tnick) 1
	set black($tnick,reason) $reason
	set black($tnick,chan) $chan
	set black($tnick,type) $type
	set black($tnick,target) $target
	set black($tnick,modif) "$nick!$uh"
	
	putquick "WHO $tnick n%nuhiart,102"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

}

# -- command: asn
# usage: asn <host/ip>
# does IP lookup for ASN (autonomous system number)
proc arm:cmd:asn {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "asn"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set ip [lindex $args 0]
	if {$ip == ""} { arm:reply $stype $starget "\002usage:\002 asn <ip>"; return; }
	
	# -- this only returns the ASN itself
	#set asn [geo:ip2asn $ip]
	
	# -- reverse the IP
	if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
		# -- not valid IP
		arm:reply $type $target "invalid IP address."
		return;
	}
	set revip "$d.$c.$b.$a"  
	set answer [arm:dns:lookup $revip.origin.asn.cymru.com TXT]
	
	# -- example:
	# 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
	
	if {$answer == "NULL" == $answer == ""} { arm:reply $type $target "ASN lookup failed."; return; }
	
	set string [split $answer "|"]

	# -- be sure to remove extra spaces
	set asn [lindex $string 0]
	regsub -all { } $asn {} asn
	set bgp [lindex $string 1]
	regsub -all { } $bgp {} bgp
	set country [lindex $string 2]
	regsub -all { } $country {} country
	set registry [string toupper [lindex $string 3]]
	regsub -all { } $registry {} registry
	set allocation [lindex $string 4]
	regsub -all { } $allocation {} allocation
	
	# -- now get AS description
	set answer [arm:dns:lookup AS$asn.asn.cymru.com TXT]

	# -- example:
	# 7545 | AU | apnic | 1997-04-25 | TPG-INTERNET-AP TPG Internet Pty Ltd
	if {$answer == "NULL" || $answer == ""} { set desc "none" }
	set string [split $answer "|"]
	set desc [lindex $string 4]
	set desc [string trimleft $desc " "]
	
	arm:debug 1 "arm:cmd:asn: asn lookup for $ip is: $asn (desc: $desc bgp: $bgp country: $country registry: $registry allocation: $allocation info: http://www.robtex.com/as/as${asn}.html)"
	
	arm:reply $type $target "\002(\002ASN\002)\002 for $ip is $asn \002(desc:\002 $desc -- \002bgp:\002 $bgp -- \002country:\002 $country -- \002registry:\002 $registry -- \002allocation:\002 $allocation -- \002info:\002 http://www.robtex.com/as/as${asn}.html\002)\002"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;

}

# -- command: chanscan
# usage: chanscan
# does full channel scan (simulates all users joining)
proc arm:cmd:chanscan {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm botnick full
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "chanscan"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	set start [clock clicks]

	set chan [lindex $args 0]
		
	#if {$chan == ""} { arm:reply $stype $starget "\002usage:\002 chanscan <chan>"; return; }
	if {$chan == ""} { set chan $arm(cfg.chan.def) }
	
	if {![validchan $chan]} { arm:reply $type $target "uhh... negative."; return; }
	if {![isop $botnick $chan]} { arm:reply $type $target "uhh... op me in $chan?"; return; }
	if {![onchan $botnick $chan]} { arm:reply $type $target "uhh... how?"; return; }
		
	arm:debug 1 "arm:cmd:chanscan: doing full chanscan for $chan"
	
	if {$type != "pub"} { putquick "NOTICE @$chan :Armour: beginning full channel scan... fire in the hole!" }
	if {$chan != $arm(cfg.chan.report)} { putquick "NOTICE $arm(cfg.chan.report) :Armour: beginning full channel scan... fire in the hole!" }
		
	arm:reply $type $target "scanning $chan..."

	catch { unset full }	
	set full(usercount,$chan) 0
	set full(chanscan,$chan) "$type $target $start"
	
	putquick "WHO $chan n%nuhiart,102"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;

}


# -- command: mode
# usage: mode <off|on|secure>
# changes Armour mode ('secure' uses chanmode +Dm)
proc arm:cmd:mode {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "mode"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set mode [lindex $args 0]
	if {$mode == ""} { arm:reply $type $target "mode is: $arm(mode)"; return; }
	if {$mode != "on" && $mode != "off" && $mode != "secure" && $mode != ""} { arm:reply $stype $starget "\002usage:\002 mode <on|off|secure>"; return; }
	
	arm:debug 1 "arm:cmd:mode: changing mode for $nick to: $mode"
	
	set arm(mode) $mode
	
	if {$chan != $arm(cfg.chan.auto)} { set chan $arm(cfg.chan.auto); }
	
	# -- secure mode?
	if {$mode == "secure"} {
		if {![botisop $chan]} { 
			arm:debug 2 "arm:cmd:mode: cannot change mode to secure, not opped on $chan"
			arm:reply $type $target "$nick: cannot change mode, I'm not opped."
			return;
		}
		putquick "MODE $chan +Dm"
		foreach user [chanlist $chan] {
			if {![isop $user $chan] && ![isvoice $user $chan]} {
				lappend voicelist $user
			}
		}
		# -- stack the voices
		if {[info exists voicelist]} {
			while {$voicelist != ""} {
				# -- voice stack workaround (pushmode doesn't work as client not in chan yet)
				set length [llength $voicelist]
				if {$length >= 6} { set modes "+vvvvvv" } else { set modes "+[string repeat "v" $length]" }
				arm:debug 2 "arm:cmd:mode: executing: MODE $arm(cfg.chan.auto) $modes [join [lrange $voicelist 0 5]]"
				putquick "MODE $arm(cfg.chan.auto) $modes [join [lrange $voicelist 0 5]]"
				set voicelist [lreplace $voicelist 0 5]
			}
		}
		arm:debug 2 "arm:cmd:mode: secure mode activated, voiced all users"
	} else {
	
		# -- turn off chanmode +Dm
		putquick "MODE $chan -Dm"
		
		# -- kill any existing arm:secure timers
		foreach utimer [utimers] {
			set thetimer [lindex $utimer 1]
			if {$thetimer != "arm:secure"} { continue; }
			arm:debug 1 "arm:cmd:mode: killing arm:secure utimer: $utimer"
			killutimer [lindex $utimer 2] 
		}
	
	}
	
	# -- should de devoice users that aren't added to the bot with automode=op|voice?
	# -- defer
	
	arm:reply $type $target "done."
	
	if {$mode == "secure"} {
		# -- start '/names -d' timer
		arm:secure
	}
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;

}

# -- command: country
# usage: country <host/ip>
# does IP lookup for country (geo lookup with mapthenet.org)
proc arm:cmd:country {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "country"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	set ip [lindex $args 0]
	if {$ip == ""} { arm:reply $stype $starget "\002usage:\002 country <ip>"; return; }
	
	#set country [geo:ip2country $ip]
	
	# -- reverse the IP
	if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
		# -- not valid IP
		arm:reply $type $target "invalid IP address."
		return;
	}
	set revip "$d.$c.$b.$a"  
	set answer [arm:dns:lookup $revip.origin.asn.cymru.com TXT]
	
	# -- example:
	# 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
	
	if {$answer == "NULL" || $answer == ""} { arm:reply $type $target "country lookup failed."; return; }
	
	set string [split $answer "|"]

	set asn [lindex $string 0]
	regsub -all { } $asn {} asn
	set bgp [lindex $string 1]
	regsub -all { } $bgp {} bgp
	set country [lindex $string 2]
	regsub -all { } $country {} country
	set registry [string toupper [lindex $string 3]]
	regsub -all { } $registry {} registry
	set allocation [lindex $string 4]
	regsub -all { } $allocation {} allocation

	# -- now get AS description
	set answer [arm:dns:lookup AS$asn.asn.cymru.com TXT]

	# -- example:
	# 7545 | AU | apnic | 1997-04-25 | TPG-INTERNET-AP TPG Internet Pty Ltd
	if {$answer == "NULL" || $answer == ""} { set desc "none" }
	set string [split $answer "|"]
	set desc [lindex $string 4]
	set desc [string trimleft $desc " "]
	
	arm:debug 1 "arm:cmd:country: country lookup for $ip is: $country (desc: $desc bgp: $bgp country: $country registry: $registry allocation: $allocation info: http://www.robtex.com/as/as${asn}.html)"
	
	arm:reply $type $target "\002(\002country\002)\002 for $ip is $country \002(desc:\002 $desc -- \002asn:\002 $asn -- \002bgp:\002 $bgp -- \002registry:\002 $registry -- \002allocation:\002 $allocation -- \002info:\002 http://www.robtex.com/as/as${asn}.html\002)\002"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;
	
}

# -- command: scanrbl
# usage: scanrbl <host/ip>
# scans dnsbl servers for match
proc arm:cmd:scanrbl {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "scanrbl"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- command: scanrbl

	set host [lindex $args 0]

	if {$host == ""} { arm:reply $stype $starget "\002usage:\002 scanrbl <host|ip>"; return; }

	set response [arm:rbl:score $host]

	set ip [lindex $response 0]
	set response [join $response]
	set score [lindex $response 1]

	if {$ip != $host} { set dst "$ip ($host)" } else { set dst $ip }

	if {$score <= 0} { arm:reply $type $target "no dnsbl match \002(ip:\002 $dst\002)\002"; return; }


	arm:debug 1 "arm:cmd:scanrbl: match found: $response"

	set dnsbl [lindex $response 2]
	set desc [lindex $response 3]
	set info [join [lindex $response 4]]

	if {$info != ""} {
		arm:reply $type $target "\002(\002dnsbl\002)\002 $dnsbl \002desc:\002 $desc \002(ip:\002 $dst -- \002score:\002 $score -- \002info:\002 $info\002)\002"
	} else {
		arm:reply $type $target "\002(\002dnsbl\002)\002 $dnsbl \002desc:\002 $desc \002(ip:\002 $dst -- \002score:\002 $score\002)\002"
	}
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
}

# -- command: scanport
# usage: scanport <host|ip> [port1,port2,port3...]
# scans for open ports
proc arm:cmd:scanport {0 1 2 3 {4 ""}  {5 ""}} { arm:cmd:scanports $0 $1 $2 $3 $4 $5 }
proc arm:cmd:scanports {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global scanports
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "scanport"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- command: scanport

	set host [lindex $args 0]
	set customports [lindex $args 1]
	
	if {$host == ""} { arm:reply $stype $starget "\002usage:\002 scanports <host|ip> \[port1,port2,port3...\]"; return; }
	
	if {$customports != ""} { set custom 1 } else { set custom 0 }
		
	set openports [arm:port:scan $host $customports]
	
	if {$openports == ""} {
		arm:debug 1 "arm:cmd:scanports: no open ports at: $host"
		arm:reply $type $target "no open ports \002(ip:\002 $host\002)\002"
		return;
	}
	
	arm:debug 1 "arm:cmd:scanports: response: $openports"
	
	arm:reply $type $target "\002(\002open ports\002)\002 -> $openports"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

}

# -- command: exempt
# usage: exempt <nick>
# add a temporary join scan exemption (1 min)
proc arm:cmd:exempt {0 1 2 3 {4 ""}  {5 ""}} {
	global arm override
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "exempt"
	
	# -- allow any chanop to execute this command
	if {![userdb:isAllowed $nick $cmd $type] && ![isop $nick $chan]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- command: exempt

	set exempt [lindex $args 0]
	set mins [lindex $args 1]
	
	if {$exempt == ""} { arm:reply $stype $starget "\002usage:\002 exempt <nick> \[mins\]"; return; }

	if {$mins == ""} { set mins $arm(cfg.exempt.time) }
	
	# -- safety net
	if {[regexp -- {^\d+$} $mins]} {
	  if {$mins < 0 || > 1440} { arm:reply $type $target "error: mins must be between 1-1440"; return; }
	} else { arm:reply $type $target "error: mins must be an integer between 1-1440"; return; }
        
	arm:debug 1 "arm:cmd:exempt: $nick is adding temporary $mins mins exemption (override) for $exempt"
	
	arm:reply $type $target "added $mins mins scan exemption for $exempt."
	
	set exempt [split $exempt]
	set override([string tolower $exempt]) 1
	
	# -- unset later
	timer $mins "catch { unset override([string tolower $exempt]) }"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}

# -- command: scan
# usage: scan <value>
# ie. scan Empus
# ie: scan 172.16.4.5
# ie. scan Empus!empus@172.16.4.5/why? why not?
# scans all appropriate lists for match

proc arm:cmd:scan {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline regex
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "scan"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- command: scan

	set search [lrange $args 0 end]
	
	if {$search == ""} { arm:reply $stype $starget "\002usage:\002 scan <value>"; return; }
	
	# -- runtime counter
	set start [clock clicks]
	
	arm:debug 1 "arm:cmd:scan: value: $search"
	
	# -- we need to determine what the value is
	
	set ip 0
	set nuhr 0
	set nuh 0
	set hostmask 0
	set host 0
	set nickxuser 0
	set nick 0
	set xuser 0
	set regexp 0
	set dnsbl 0
	
	set tnick ""
	set tident ""
	set thost ""
	set tip ""
	set trname ""
	
	set match 0
	
	# -- check for IP
	if {[regexp -- {^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$} $search]} {
	 # -- value is IP
	 arm:debug 2 "arm:cmd:scan: value: $search is type: IP"
	 set ip 1
	 set match 1
	 set vtype "ip"
	 set dnsbl 1
	 set tip $search
	 set thost $tip
	 set country [geo:ip2country $tip]
	 set asn [geo:ip2asn $tip]
	 arm:debug 2 "arm:cmd:scan: asn: $asn country: $country"
	}
	
	# -- check for nick!user@host/rname
	if {[regexp -- {^([^!]+)!([^@]+)@([^/]+)/(.+)$} $search -> tnick tident thost trname]} {
	 # -- value is nick!user@host/rname (regex)
	 arm:debug 2 "arm:cmd:scan: value: $search is type: nuhr (regex)"
	 set regexp 1
	 set match 1
	 set dnsbl 1
	 set vtype "regex"
	}
	
	# -- check for nick!user@host
	if {[regexp -- {^([^!]+)!([^@]+)@([^/]+)$} $search -> tnick tident thost]} {
	 # -- value is nick!user@host
	 arm:debug 2 "arm:cmd:scan: value: $search is type: nuh"
	 set nuh 1
	 set match 1
	 set dnsbl 1
	 set vtype "nuh"
	}
	
	# -- check if thost is IP?
	if {[regexp -- {^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$} $thost] && $ip != 1} {
		set tip $thost
		set thost tip
		set country [geo:ip2country $tip]
		set asn [geo:ip2asn $tip]
		arm:debug 2 "arm:cmd:scan: asn: $asn country: $country"
	}
	
	# -- check for ASN
	if {[regexp -- {^[0-9]+$} $search]} {
	 # -- value is ASN
	 arm:debug 2 "arm:cmd:scan: value: $search is type: ASN"
	 set match 1
	 set vtype "asn"
	}
	
	# -- check for existence of '*'
	if {[regexp -- {\*} $search]} {
	 # -- value is hostmask
	 arm:debug 2 "arm:cmd:scan: value: $search is type: hostmask"
	 set hostmask 1
	 set match 1
	 set vtype "hostmask"
	}
	
	# -- check for existence of '.'
	if {[string match "*.*" $search] && $regexp != 1 && $nuh != 1 && $hostmask != 1 && $ip != 1} {
	 # -- value is hostname
	 arm:debug 2 "arm:cmd:scan: value: $search is type: hostname"
	 set host 1
	 set match 1
	 set thost $search
	 set vtype "host"
	}
	
	# -- if no match so far, must be nickname, username or country
	if {!$match} {
		# -- value is either nickname, username or country
		if {[regexp -- {^[A-Za-z0-9-]+$} $search] && [string length $search] > 2} {
			# -- nickname or username
			arm:debug 2 "arm:cmd:scan: value: $search is type: nickname or username"
			set nickxuser 1
			set vtype "nickxuser"
		} else {
				if {[string length $search] > 2} {
					# -- must be a nickname
					arm:debug 2 "arm:cmd:scan: value: $search is type: nickname"
					set nick 1
					set vtype "nick"
					set tnick $search
				}
				# -- either a nickname or country
				set vtype "nickgeo"
				arm:debug 2 "arm:cmd:scan: value: $search is type: nickgeo"
		}
		# -- get host
	}
		
	# -- save a second lookup later?
	#if {$tip != "" && $thost == ""} { set thost $tip }
	#if {$tip == "" && $thost != ""} { set tip $thost }
		
	set mcount 0
	set match 0
	
	arm:debug 1 "arm:cmd:scan: beginning whitelist scans"
	# -- whitelist scans (user, host, country, asn)
		foreach entry [array names wline] {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 2 "arm:cmd:scan: scanning: wline($method,$value)"
			if {$method == "regex"} { continue; }
			if {[regexp -- {/} $value]} {
				# -- CIDR notation
				if {$tip != ""} {
					if {[cidr:match $tip $value]} { set cidrmatch($value) 1 }
				}
			}
			if {$method == "asn" && [info exists asn]} {
				# -- ASN
				if {[string match $asn $value]} { set asnmatch($value) 1 }
			}
			if {$method == "country" && [info exists country]} {
				# -- country
				if {[string match $country $value]} { set geomatch($value) 1 }
			}
			if {[string match [string tolower $search] [string tolower $value]] || [info exists cidrmatch($value)] || [info exists asnmatch($value)] || [info exists geomatch($value)]} {
			# -- match!
			arm:debug 2 "arm:cmd:scan: matched $search: wline($method,$value)"
			set match 1
			incr mcount
			# -- send response
				arm:reply $type $target [arm:listparse white $method $value $wline($method,$value)]
			}
		}
		# -- end of whitelist

		arm:debug 1 "arm:cmd:scan: beginning blacklist scans"
		# -- blacklist scans (user, host, country, asn)
		foreach entry [array names bline] {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			if {$method == "regex"} { continue; }
						if {[regexp -- {/} $value]} {
				# -- CIDR notation
				arm:debug 3 "arm:cmd:scan: checking CIDR"
				if {$tip != ""} {
					if {[cidr:match $tip $value]} { set cidrmatch($value) 1 }
				}
			}
			arm:debug 3 "arm:cmd:scan: checking ASN"
			if {$method == "asn" && [info exists asn]} {
				# -- ASN
				if {[string match $asn $value]} { set asnmatch($value) 1 }
			}
			arm:debug 3 "arm:cmd:scan: checking Country"
			if {$method == "country" && [info exists country]} {
				# -- country
				if {[string match $country $value]} { set geomatch($value) 1 }
			}
			if {[string match [string tolower $search] [string tolower $value]] || [info exists cidrmatch($value)] || [info exists asnmatch($value)] || [info exists geomatch($value)]} {
				# -- match!
				arm:debug 2 "arm:cmd:scan: matched $search: bline($method,$value)"
				set match 1
				incr mcount
				# -- send response
				arm:reply $type $target [arm:listparse black $method $value $bline($method,$value)]
			}
	}
	# -- end of blacklist
	
	arm:debug 2 "arm:cmd:scan: beginning regex scans"
	# -- regex scans
	if {$regexp} {
		foreach id [array names regex] {
			set exp [split $regex($id)]
			#set exp [join $exp]
			# putloglev d * "arm:cmd:scan: matching $search against regex: [join $exp]"
			if {[regexp -- [join $exp] $search]} {
				# -- match!
				arm:debug 2 "arm:cmd:scan: matched $search: regex($id) -- [join $exp]"
				if {[info exists wline(regex,$id)]} {
					# -- whitelist entry
					arm:reply $type $target [arm:listparse white regex $exp $wline(regex,$id)]
				} else {
						if {[info exists bline(regex,$id)]} {
							# -- blacklist entry
							arm:reply $type $target [arm:listparse black regex $exp $bline(regex,$id)]
						}
				}
				set match 1
				incr mcount
			}
		}
		# -- end of foreach 
	}
	# -- end of regex scans

		
        # -- dnsbl checks (if not ipv6)
        if {$dnsbl && ![string match "*:*" $ip]} {
		arm:debug 2 "arm:cmd:scan: scanning for dnsbl match: $thost (tip: $tip)"
		# -- get score
		set response [arm:rbl:score $thost]

		set ip [lindex $response 0]
		set response [join $response]
		set score [lindex $response 1]
		if {$ip != $thost} { set dst "$ip ($thost)" } else { set dst $ip }
		if {$score > 0} {
			# -- match found!
			set match 1
			arm:debug 2 "arm:cmd:scan: dnsbl match found for $thost: $response"
		        set rbl [lindex $response 2]
       			set desc [lindex $response 3]
      			set info [lindex $response 4]

			arm:reply $type $target "\002dnsbl match:\002 $rbl \002desc:\002 $desc (\002ip:\002 $dst \002score:\002 $score \002info:\002 [join $info])"
		} else {
				arm:debug 1 "arm:cmd:scan: no dnsbl match found for $thost"
		}
	}
	# -- end of dnsbl


	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"

	if {!$match} {
		arm:reply $type $target "scan negative ($runtime)" 
		return;
	}
	
	arm:reply $type $target "scan complete ($runtime)"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}

# -- command: search
# usage: search <type> <method> <value>
# ie: search <white|black|*> <wildcard>
# scans lists for matching value
proc arm:cmd:search {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline regex
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "search"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- command: match

	set list [lindex $args 0]
	set search [lindex $args 1]
	
	if {$list == "" || $search == ""} { arm:reply $stype $starget "\002usage:\002 search <white|black|*> <search>"; return; }
	
	# -- runtime counter
	set start [clock clicks]
	
	arm:debug 3 "arm:cmd:search: type: $list search: $search"
	
	set mcount 0
	set match 0
	
	if {$list == "white" || $list == "*"} {
		# -- whitelist

		# -- regex whitelist
		foreach id [array names regex] {
			set exp [split $regex($id)]
			#set exp $regex($id)
			# putloglev d * "arm:cmd:search: matching $search against regex: [join $exp]"
			if {[string match $search $exp] && [info exists wline(regex,$id)]} {
				# -- match!
				arm:debug 2 "arm:cmd:search: matched $search: regex($id) -- [join $exp]"
				set match 1
				incr mcount
				if {$mcount > 5 && $type != "dcc"} { 
					set end [clock clicks]
					set runtime "[expr ($end-$start)/1000/1000.0] sec"
					arm:reply $type $target "more than 5 matches, please refine search ($runtime)"
					return;
				}
				# -- send response
				arm:reply $type $target [arm:listparse white regex $exp $wline(regex,$id)]
			}
		}
		# -- end of foreach

		# -- everything else (user, host, country, asn)
		foreach entry [array names wline] {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			if {$method == "regex"} { continue; }
			if {[string match [string tolower $search] [string tolower $value]]} {
				# -- match!
				arm:debug 2 "arm:cmd:search: matched $search: wline($method,$value)"
				set match 1
				incr mcount
				if {$mcount > 5 && $type != "dcc"} { 
					set end [clock clicks]
					set runtime "[expr ($end-$start)/1000/1000.0] sec"
					arm:reply $type $target "more than 5 matches, please refine search ($runtime)"
					return;
				}
				# -- send response
				arm:reply $type $target [arm:listparse white $method $value $wline($method,$value)]
			}
		}

	} elseif {$list == "black" || $list == "*"} {
		# -- blacklist

		# -- regex blacklist
		foreach id [array names regex] {
			set exp [split $regex($id)]
			#set exp $regex($id)
			# putloglev d * "arm:cmd:search: matching $search against regex: [join $exp]"
			if {[string match $search $exp] && [info exists bline(regex,$id)]} {
				# -- match!
				arm:debug 2 "arm:cmd:search: matched $search: regex($id) -- [join $exp]"
				set match 1
				incr mcount
				if {$mcount > 5 && $type != "dcc"} { 
					set end [clock clicks]
					set runtime "[expr ($end-$start)/1000/1000.0] sec"
					arm:reply $type $target "more than 5 matches, please refine search ($runtime)"
					return;
				}
				arm:reply $type $target [arm:listparse black regex $exp $bline(regex,$id)]
			}
		}
		# -- end of foreach
		
		# -- everything else (user, host, country, asn)
		foreach entry [array names bline] {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			if {$method == "regex"} { continue; }
			if {[string match [string tolower $search] [string tolower $value]]} {
				# -- match!
				arm:debug 2 "arm:cmd:search: matched $search: bline($method,$value)"
				set match 1
				incr mcount
				if {$mcount > 5 && $type != "dcc"} { 
					set end [clock clicks]
					set runtime "[expr ($end-$start)/1000/1000.0] sec"
					arm:reply $type $target "more than 5 matches, please refine search ($runtime)"
					return;
				}
				# -- send response
				arm:reply $type $target [arm:listparse black $method $value $bline($method,$value)]
			}
		}
	} else {
		# -- invalid list type
		arm:reply $stype $starget "\002usage:\002 search <white|black|*> <wildcard>"
		return;
	}

	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

	if {!$match} {
		if {$list == "*"} { set list "whitelist or blacklist" } else { set list "${list}list" }
		arm:reply $type $target "no $list match found for: $search ($runtime)" 
		return;
	}
	
	arm:reply $type $target "search complete ($runtime)"
	
}
	



# -- command: save
proc arm:cmd:save {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline uline
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "save"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	arm:debug 1 "arm:cmd:save: writing list arrays to db file"
	
	# -- saving list arrays to file
	arm:db:write
	
	# -- save user arrays to file
	userdb:db:write
	
	arm:reply $type $target "saved [llength [array names wline]] whitelist, [llength [array names bline]] blacklist, and [llength [array names uline]] user entries to db"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}

# -- command: load
proc arm:cmd:reload {0 1 2 3 {4 ""} {5 ""}} { arm:cmd:load $0 $1 $2 $3 $4 $5 }
proc arm:cmd:load {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline uline
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "load"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	arm:debug 1 "arm:cmd:load: loading list entries to memory"
	
	# -- loading list arrays from file
	arm:db:load
	
	# -- loading user db from file
	userdb:db:load
	
	arm:reply $type $target "loaded [llength [array names wline]] whitelist, [llength [array names bline]] blacklist, and [llength [array names uline]] user entries to memory"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}

# -- cmd: rehash
# -- save db's & rehash eggdrop
proc arm:cmd:rehash {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "rehash"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	# -- save list db
	arm:db:write
	
	# -- save user db
	userdb:db:write

	# -- rehash bot
	rehash

	arm:reply $type $target "done." 
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

}


# -- cmd: restart
# -- syntax: restart [reason]
# -- save db's & restart eggdrop
proc arm:cmd:restart {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "restart"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set reason [lrange $args 0 end]
	if {$reason == ""} { set reason "requested by $nick!$uh ([userdb:uline:get user nick $nick])" }

	# -- save list db
	arm:db:write
	
	# -- save user db
	userdb:db:write

	# -- quit server connection gracefully first (so restart doesn't 'EOF')
	putnow "QUIT :restarting: $reason"

	# -- restart bot
	restart
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

}

# -- cmd: restart
# -- syntax: die [reason]
# -- save db's & kills bot
proc arm:cmd:die {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "die"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set safety [lindex $args 0]
	if {[string tolower $safety] != "-force"} { arm:reply $stype $starget "seriously? use: die -force <reason>"; return; }
	set reason [lrange $args 1 end]
	if {$reason == ""} { set reason "requested by $nick!$uh ([userdb:uline:get user nick $nick])" }

	# -- save list db
	arm:db:write
	
	# -- save user db
	userdb:db:write

	# -- quit server connection gracefully first (so die doesn't 'EOF')
	putnow "QUIT :shutdown: $reason"

	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	# -- kill bot
	die $reason

}

# -- command bot to speak
proc arm:cmd:say {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "say"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set dest [lindex $args 0]
	set string [lrange $args 1 end]
	# -- should have at least two args
	if {$dest == "" || $string ==""} { arm:reply $stype $starget "\002usage:\002 say \[-a\] <chan|*|nick> <string>"; return;  }
	
	set action 0
	if {$dest == "-a"} {
		# -- action
		set action 1
		set dest [lindex $args 1]
		set string "\001ACTION [lrange $args 2 end]\002"
		if {$string == ""} { arm:reply $stype $starget "\002usage:\002 say \[-a\] <chan|*|nick> <string>"; return;  }
	}
	
	set msglist [list]
	if {$dest == "*"} {
		# -- global say (all chans)
		foreach i [channels] {
			if {[botonchan $i]} {
				lappend msglist $i
			}
		}
	} else {
		# -- individual or chan
		if {[string index $dest 0] == "#"} {
			# -- channel
			if {![botonchan $dest]} { arm:reply $type $target "uhh.. no."; return; }
			
		} else {
			# -- individual
			if {![onchan $dest]} { arm:reply $type $target "uhh.. who is $dest? hint: help say"; return; }
		}
		set msglist $dest 
	}
	set msglist [join $msglist ,]
	
	# -- send the message
	putquick "PRIVMSG $msglist :$string"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;
}




# -- cmd: jump
# -- syntax: jump [server]
# -- jump servers
proc arm:cmd:jump {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "jump"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set jumpto [lindex $args 0]

	# -- jump server
	#jump $jumpto
	
	# -- don't allow server, to protect IP
	jump
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

}


# -- command: version
proc arm:cmd:version {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "version"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	arm:debug 1 "arm:cmd:version: version recall"

	arm:reply $type $target "version: Armour $arm(version)"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}

# -- command: stats
proc arm:cmd:stats {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline hits
	
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "stats"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	arm:debug 1 "arm:cmd:stats: stats recall"

	# -- whitelist counts
	set count(white) [llength [array names wline]]
	set count(white,user) 0
	set count(white,host) 0
	set count(white,regex) 0
	set count(white,country) 0
	set count(white,asn) 0
	set count(white,chan) 0
	set count(white,rname) 0
	
	# -- whitelist hitcounts
	set hitcount(white,user) 0
	set hitcount(white,host) 0
	set hitcount(white,regex) 0
	set hitcount(white,country) 0
	set hitcount(white,asn) 0
	set hitcount(white,chan) 0
	set hitcount(white,rname) 0
	
	# -- blacklist counts
	set count(black) [llength [array names bline]]
	set count(black,user) 0
	set count(black,host) 0
	set count(black,regex) 0
	set count(black,country) 0
	set count(black,asn) 0
	set count(black,chan) 0
	set count(black,rname) 0
	
	# -- blacklist hitcounts
	set hitcount(black,user) 0
	set hitcount(black,host) 0
	set hitcount(black,regex) 0
	set hitcount(black,country) 0
	set hitcount(black,asn) 0
	set hitcount(black,chan) 0
	set hitcount(black,rname) 0
	
	set hitcount(black) 0
	set hitcount(white) 0
	
	# -- check whitelist entries
	foreach entry [array names wline] {
		set line [split $entry ,]
		set method [lindex $line 0]
		set value [lindex $line 1]
		incr count(white,$method)
		# -- find hits
		set id [lindex [split $wline($method,$value) :] 1]
		if {![info exists hits($id)]} { set hits($id) 0 }
		if {$hits($id) == ""} { set hits($id) 0 }
		incr hitcount(white,$method) $hits($id)
		incr hitcount(white) $hits($id)
	}
	# -- check whitelist entries
	foreach entry [array names bline] {
		set line [split $entry ,]
		set method [lindex $line 0]
		set value [lindex $line 1]
		incr count(black,$method)
		# -- find hits
		set id [lindex [split $bline($method,$value) :] 1]
		if {![info exists hits($id)]} { set hits($id) 0 }
		if {$hits($id) == ""} { set hits($id) 0 }
		incr hitcount(black,$method) $hits($id)
		incr hitcount(black) $hits($id)
	}
	
	arm:reply $type $target "\002(\002whitelist\002)\002 \002total:\002 $count(white) \002hits:\002 $hitcount(white) -> (\002user:\002 $count(white,user) \002hits:\002 $hitcount(white,user)) -- (\002host:\002 $count(white,host) \002hits:\002 $hitcount(white,host)) -- (\002rname:\002 $count(white,rname) \002hits:\002 $hitcount(white,rname)) -- (\002regex:\002 $count(white,regex) \002hits:\002 $hitcount(white,regex)) -- (\002country:\002 $count(white,country) \002hits:\002 $hitcount(white,country)) -- (\002asn:\002 $count(white,asn) \002hits:\002 $hitcount(white,asn)) -- (\002chan:\002 $count(white,chan) \002hits:\002 $hitcount(white,chan))"
	arm:reply $type $target "\002(\002blacklist\002)\002 \002total:\002 $count(black) \002hits:\002 $hitcount(black) -> (\002user:\002 $count(black,user) \002hits:\002 $hitcount(black,user)) -- (\002host:\002 $count(black,host) \002hits:\002 $hitcount(black,host)) -- (\002rname:\002 $count(black,rname) \002hits:\002 $hitcount(black,rname)) -- (\002regex:\002 $count(black,regex) \002hits:\002 $hitcount(black,regex)) -- (\002country:\002 $count(black,country) \002hits:\002 $hitcount(black,country)) -- (\002asn:\002 $count(black,asn) \002hits:\002 $hitcount(black,asn)) -- (\002chan:\002 $count(black,chan) \002hits:\002 $hitcount(black,chan))"

	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
}


# -- cmd: status
# -- syntax: status [server]
# -- jump status
proc arm:cmd:status {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global botnick botnet-nick server-online uptime
	global wline bline
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}

	set cmd "status"

	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	# -- cmd: status

	arm:reply $type $target "${botnet-nick} (as $botnick) -- server connection: [userdb:timeago ${server-online}] -- actual uptime: [userdb:timeago $uptime])"
	arm:reply $type $target "machine: [unames] -- uptime: [exec uptime]"
	arm:reply $type $target "traffic since last restart: [expr [lindex [lindex [traffic] 5] 2] / 1024]/KB \[in\] and [expr [lindex [lindex [traffic] 5] 4] / 1024]/KB \[out\]"
	arm:reply $type $target "whitelist db: [llength [array names wline]] entries -- blacklist db: [llength [array names bline]] entries"
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""

}


# -- command: view
proc arm:cmd:view {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline regex hits
	
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "view"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- command: view
	
	set list [lindex $args 0]
	set method [lindex $args 1]
	set value [lindex $args 2]
	
	# -- check if ID is given
	if {[regexp -- {^\d+(?:,\d+)*$} $list]} {
		# -- id provided
		set origid $list
		foreach id [split $origid ,] {
			set result [arm:get:line $id]
			if {$result == ""} { arm:reply $type $target "error: no such id exists ($id)"; continue; }
			
			# -- interpret the line
			
			arm:debug 3 "arm:cmd:view: interpret line result: $result"
		
			set result [split $result :]
			set list [lindex $result 0]
			if {$list == "W"} { set list "white" } else { set list "black" }
			set id [lindex $result 1]
			set method [lindex $result 2]
			set value [lindex $result 3]
			set timestamp [lindex $result 4]
			set modifby [lindex $result 5]
			set action [lindex $result 6]
			switch -- $action {
				B	{ set action "kickban" }
				K	{ set action "kick" }
				V	{ set action "voice" }
				A	{ set action "accept" }
				O	{ set action "op" }
			}
			set limit [lindex $result 7]
			if {[info exists hits($id)]} { set hitnum $hits($id) } else { set hits($id) 0; set hitnum 0 }
			set reason [join [lrange $result 9 end]]

			# -- slip in the limit
			if {$limit != "1-1-1"} {
				# -- non standard limit
				regsub -all {\-} $limit {:} limit
				set tl "\002limit:\002 $limit "
			} else { set tl "" }
			
			# -- send response
			if {$reason != ""} { arm:reply $type $target "\002(\002${list}list\002)\002 \002$method:\002 $value (\002id:\002 $id \002action:\002 $action ${tl}\002hits:\002 $hitnum \002added:\002 [userdb:timeago $timestamp] ago \002by:\002 $modifby \002reason:\002 $reason)" } \
			else { arm:reply $type $target "\002(\002${list}list\002)\002 \002$method:\002 $value (\002id:\002 $id \002action:\002 $action ${tl}\002hits:\002 $hitnum \002added:\002 [userdb:timeago $timestamp] ago \002by:\002 $modifby)" }

		}
		# -- end foreach
		
		# -- create log entry for command use
		arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
		return;
		
	}
	# -- end of ID
	if {[string index $list 0] == "w"} { set list "white" } \
	elseif {[string index $list 0] == "b"} { set list "black" } \
	elseif {[string index $list 0] == "d"} { set list "dronebl" } \
	else {	
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			# -- libdronebl not loaded or user doesn't have sufficient access
			arm:reply $stype $starget "\002usage:\002 view <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?";
		} else {
			# -- libdronebl loaded & user has sufficient access
			arm:reply $stype $starget "\002usage:\002 view <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?";
		}
		return;
	}

	arm:debug 3 "arm:cmd:view: view type: $list method: $method value: $value"
	
	# -- DroneBL
	if {$list == "dronebl"} {
		# -- check if libdronebl loaded & user has access
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			arm:reply $stype $starget "\002usage:\002 view <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
			return; 
		} else {
			if {$value == "" || $method == ""} {
				arm:reply $stype $starget "\002usage:\002 view dronebl <host|ip> <value1,value2..>"
				return;				
			}
		
		}
		
		set ttype [lindex $args 3]
		set loop [split $value ,]
		# -- allow comma delimited
		foreach ip $loop {
			if {$ip == "" || (![arm:isValidIP $ip] && {set ip [arm:dns:lookup $ip]} == "error") || ($method != "ip" && $method != "host")} {
				arm:reply $stype $starget "\002usage:\002 view dronebl <host|ip> <value1,value2..>"
				continue;		
			}
			if {$ttype == "" || ![regexp -- {^\d+$} $ttype]} { set ttype $arm(cfg.dronebl.type) }
			# -- check if entry even exists
			set result [::dronebl::lookup $ip]	
			arm:debug 2 "arm:cmd:view: dronebl result: $result"
			if {[join [lindex $result 0]] == "No matches."} {
				# -- exists
				arm:debug 1 "arm:cmd:view: dronebl entry does not exist (ip: $ip)"
				arm:reply $type $target "error: dronebl entry does not exist -- ip: $ip"
				continue;
			}
			# -- parse the results
			set i 1
			foreach line $result {
				arm:debug 2 "arm:cmd:view: dronebl line: $line"
				# -- ignore the first (header) line
				if {$i == 1} { incr i; continue; }
				# {ID IP {Ban type} Listed Timestamp} {305082 173.212.195.50 17 1 {2011.02.15 01:54:17}}
				lassign $line sid sip stype slisted stimestamp
				arm:debug 1 "arm:cmd:view: id: $sid ip: $sip type: $stype listed: $slisted timestamp: $stimestamp"
				arm:reply $type $target "id: $sid ip: $sip type: $stype timestamp: $stimestamp"
				incr i
				#break;
			}
			

		}
		# -- endof foreach ip
		
		# -- create log entry for command use
		arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
		return;
	}
	# -- end dronebl add	
	
	set noexist 0
	set regexmatch 0
	
	# -- loop through comma separated values
	# -- only do this for types that aren't regex, or rname -- which could include ',' chars
	set origvalue $value
	if {$method != "regex" && $method != "rname"} { set tvalue [split $origvalue ,] } else { set tvalue $origvalue }
	foreach value $tvalue {
	
		if {$list == "white"} {
			if {$method == "regex"} {
				# -- regex whitelist
				foreach dbid [array names regex] {
					set res [join [split $regex($dbid)]]
					arm:debug 3 "arm:cmd:view: res: $res value: $value"
					if {$res == $value} { 
						set regexmatch 1
						set result $wline(regex,$dbid)
					}
				}
			} else {
			# -- endof regex whitelist
				set tid [arm:get:id white $method $value]
				set result [arm:get:line $tid]
				if {$result == ""} { incr noexist; set result "" }
			}
		} elseif {$list == "black"} {
			if {$method == "regex"} {
				# -- regex blacklist
				foreach dbid [array names regex] {
					set res [join [split $regex($dbid)]]
					arm:debug 3 "arm:cmd:view: res: $res value: $value"
					if {$res == $value} { 
						set regexmatch 1
						set result $bline(regex,$dbid)
					}
				}
			} else {
				# -- endof regex blacklist
				set tid [arm:get:id black $method $value]
				set result [arm:get:line $tid]
				if {$result == ""} { incr noexist; set result "" }
			} 
		} else {
			# -- invalid list type
			if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
				# -- libdronebl not loaded or user doesn't have sufficient access
				arm:reply $stype $starget "\002usage:\002 view <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?";
			} else {
				# -- libdronebl loaded & user has sufficient access
				arm:reply $stype $starget "\002usage:\002 view <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?";
			}
			return;
		}
		
		if {$noexist == 1 || $method == "regex" && $regexmatch == 0} { 
			arm:debug 2 "arm:cmd:view: no such entry exists"
			arm:reply $type $target "no such entry exists."
			continue; 
		}
		
		# -- interpret line results
		
		arm:debug 3 "arm:cmd:view: interpret line result: $result"
		
		set result [split $result :]
		set id [lindex $result 1]
		set method [lindex $result 2]
		set value [lindex $result 3]
		set timestamp [lindex $result 4]
		set modifby [lindex $result 5]
		set action [lindex $result 6]
		switch -- $action {
			B	{ set action "kickban" }
			K	{ set action "kick" }
			V	{ set action "voice" }
			A	{ set action "accept" }
			O	{ set action "op" }
		}
		set limit [lindex $result 7]
		if {[info exists hits($id)]} { set hitnum $hits($id) } else { set hits($id) 0; set hitnum 0 }
		set reason [join [lrange $result 9 end]]
		
		# -- send response
		if {$reason != ""} { arm:reply $type $target "\002(\002${list}list\002)\002 \002$method:\002 $value (\002id:\002 $id \002action:\002 $action \002hits:\002 $hitnum \002added:\002 [userdb:timeago $timestamp] ago \002by:\002 $modifby \002reason:\002 $reason)" } \
		else { arm:reply $type $target "\002(\002${list}list\002)\002 \002$method:\002 $value (\002id:\002 $id \002action:\002 $action \002hits:\002 $hitnum \002added:\002 [userdb:timeago $timestamp] ago \002by:\002 $modifby)" }
	}
	# -- end value loop
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
}

# -- command: add
# add a whitelist or blacklist entry
proc arm:cmd:add {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline regex hits
	# -- recently joined hosts (for fast blacklist entry)
	global lasthosts
	# -- nicks on a host
	global hostnicks
	
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "add"
		
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template
	
	# set args [join $args]
	
	set list [lindex $args 0]
	set method [lindex $args 1]
	set value [lindex $args 2]
	set action [lindex $args 3]
	
	# -- catch method
	switch -- $method {
		regex	{ set method "regex" }
		r		{ set method "regex" }
		user	{ set method "user" }
		u		{ set method "user" }
		xuser	{ set method "user" }
		host	{ set method "host" }
		h		{ set method "host" }
		ip		{ set method "host" }
		net		{ set method "host" }
		mask	{ set method "host" }
		asn		{ set method "asn" }
		a		{ set method "asn" }
		country	{ set method "country" }
		geo		{ set method "country" }
		g		{ set method "country" }
		chan	{ set method "chan" }
		channel	{ set method "chan" }
		c		{ set method "chan" }
		rname	{ set method "rname" }
		realname { set method "rname" }
		name	{ set method "rname" }
		ircname	{ set method "rname" }
		n		{ set method "rname" }
		l	{	 set method "last" }
		last	{ set method "last" }
		default {
			if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
				# -- libdronebl not loaded, or no access to dronebl submit
				arm:reply $stype $starget "\002usage:\002 add <white|black> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"
			} else {
				# -- libdronebl loaded & user has access to dronebl submit
				arm:reply $stype $starget "\002usage:\002 add <white|black|dronebl> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"		
			}
			return;
		}
	}
	
	if {[string index $list 0] == "w"} { set list "white" } \
	elseif {[string index $list 0] == "b"} { set list "black" } \
	elseif {[string index $list 0] == "d"} { set list "dronebl" } \
	else {
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			# -- libdronebl not loaded, or no access to dronebl submit
			arm:reply $stype $starget "\002usage:\002 add <white|black> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"
		} else {
			# -- libdronebl loaded & user has access to dronebl submit
			arm:reply $stype $starget "\002usage:\002 add <white|black|dronebl> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"		
		}
		return;
	}

	# -- DroneBL
	if {$list == "dronebl"} {
		# -- check if libdronebl loaded & user has access
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			arm:reply $stype $starget "\002usage:\002 add <white|black> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"
			return; 
		} else {
			if {$value == "" || $method == ""} {
				arm:reply $stype $starget "\002usage:\002 add dronebl <host|ip|last> <value1,value2..> \[type\]"
				return;				
			}
		
		}
		
		set ttype [lindex $args 3]
		
		# -- cater for last N hosts
		if {$method == "last"} {
			if {![info exists lasthosts($arm(cfg.chan.def))]} { arm:reply $type $target "error: no hosts in memory."; return; }
			set method "host"
			set loop [lrange $lasthosts($arm(cfg.chan.def)) 0 [expr $value - 1]] 
		} else { 
			set loop [split $value ,]
		}
		# -- allow comma delimited
		foreach ip $loop {
			if {$ip == "" || (![arm:isValidIP $ip] && {set ip [arm:dns:lookup $ip]} == "error") || ($method != "ip" && $method != "host")} {
				arm:reply $stype $starget "\002usage:\002 add dronebl <host|ip|last> <value1,value2..> \[type\]"
				continue;		
			}
			if {$ttype == "" || ![regexp -- {^\d+$} $ttype]} { set ttype $arm(cfg.dronebl.type) }
			# -- check if entry exists
			set result [::dronebl::lookup $ip]
			arm:debug 2 "arm:cmd:add: dronebl result: $result"
			if {[join [lindex $result 0]] != "No matches."} {
				# -- exists
				arm:debug 1 "arm:cmd:add: dronebl submit failed (ip exists: $ip)"
				arm:reply $type $target "error: entry already exists -- ip: $ip"
				continue;
			}
			# -- add the entry
			set result [::dronebl::submit "$ttype $ip"]
			if {$result == "true"} {
				arm:debug 1 "arm:cmd:add: dronebl submit successful (ip: $ip)"
				arm:reply $type $target "dronebl submit successful -- ip: $ip"
				continue;
			} else {
				arm:debug 1 "arm:cmd:add: dronebl submit failed (ip: $ip response: $result)"
				arm:reply $type $target "dronebl submit failed -- ip: $ip"
				continue;
			}
		}
		# -- endof foreach ip
		# -- create log entry for command use
		arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
		return;
	}
	# -- end dronebl add
	
	# -- see if the action is given
	if {[string tolower [lindex $args 3]] == "accept" || [string tolower [lindex $args 3]] == "voice" || \
		[string tolower [lindex $args 3]] == "op" || [string tolower [lindex $args 3]] == "ban"} {
		set action [lindex $args 3]
		set tn 4
	} else {
		set tn 3
	}
		
	# -- detect if limit (joins:secs:hold) is specified as 4th argument
	if {[regexp -- {(\d+):(\d+)(?::(\d+))?} [lindex $args 4] -> joins secs hold] || [regexp -- {(\d+):(\d+)(?::(\d+))?} [lindex $args 3] -> joins secs hold]} {
		# -- set the reason position dependant on where the joins:secs:hold is (because 'action' is also optional)
		if {[regexp -- {(\d+):(\d+)(?::(\d+))?} [lindex $args 4]]} { set tn 5 } else { set tn 4 }
		# -- limit specified
		if {$list == "white" || ($method != "host" && $method != "regex")} { arm:reply $type $target "\002(\002error\002)\002 joinflood limit settings only pertinent to 'host' and 'regex' blacklists"; return; }
		if {$hold == ""} { set hold $secs }
		set origlimit "$joins:$secs:$hold"
		set limit "$joins-$secs-$hold"
		set reason [lrange $args $tn end]
	} else {
			# -- limit not specified
			set limit "1-1-1"
			set reason [lrange $args $tn end]
	}

	if {$list == "" || $method == "" || $value == ""} {
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			# -- libdronebl not loaded, or no access to dronebl submit
			arm:reply $stype $starget "\002usage:\002 add <white|black> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"
		} else {
			# -- libdronebl loaded & user has access to dronebl submit
			arm:reply $stype $starget "\002usage:\002 add <white|black|dronebl> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"		
		}
		return;
	}
	
	# -- disallow : char, it's the delimiter in our DB file
	if {[string match "*:*" $reason] || [string match "*:*" $value]} {
		arm:reply $type $target "illegal character: :"
		return;  
	}
	

		
	arm:debug 3 "arm:cmd:add: list: $list method: $method value: $value action: $action limit: $limit reason: $reason"
	
	# -- check if already exists
	set exists 0
	if {$method == "regex"} {
		
		# -- check if already exists
		foreach id [array names regex] {
			if {$value == $regex($id)} { 
				if {[info exists bline(regex,$id)]} { set thelist "blacklist"; } else { set thelist "blacklist"; }
				if {[info exists wline(regex,$id)]} { set thelist "whitelist"; } else { set thelist "whitelist"; }
				arm:reply $type $target "error: a matching $thelist entry already exists. (id: $id type: regex value: $value)"; 
				return; 
			}
		}
			
		# -- regex is method, validate expression (we don't want regex errors ie. invalid backreference)
		catch { regexp -- $value "nick!user@host/rname" } err
		if {$err != 0} {
			arm:reply $type $target "error: $err"
			return;
		}
	}
	
	# -- cater for last N hosts
	set islast 0
	if {$method == "last"} {
		if {![info exists lasthosts($arm(cfg.chan.def))]} { arm:reply $type $target "error: no hosts in memory."; return; }
		set islast 1
		set method "host"
		set loop [lrange $lasthosts($arm(cfg.chan.def)) 0 [expr $value - 1]] 
	} else { 
			# -- allow for comma separated values (if not a regex or rname)
			if {$method != "regex" && $method != "rname"} { set loop [split $value ,] } else { set loop $value }
	}
		
	foreach tvalue $loop {
		set exists 0
		if {[regexp -- {([^\.]+)\.users\.undernet\.org} $tvalue -> xuser]} {
			set method "user"
			set value $xuser
		} else {
			if {$islast} {
				set method "host"
			} else { set method $method }
			set value $tvalue
		}
		
		if {[info exists bline($method,$value)]} { set exists 1; set thelist "blacklist"; }
		if {[info exists wline($method,$value)]} { set exists 1; set thelist "whitelist"; }
		if {$exists} {
			arm:reply $type $target "error: a matching $thelist entry already exists (id: [arm:get:id $thelist $method $value] type: $method value: $value)"; 
			continue;
		}
			
		# -- determine what list to add 
		if {[string match "w*" $list]} {
			# -- whitelist

			set list "white"
			set prefix "W"
		
			# -- we don't care about limits for whitelist entries
			set limit "1-1-1"
		
			if {$reason == ""} { set reason $arm(cfg.def.wreason) }
			# -- accept, voice, op actions
			if {[string index [string toupper $action] 0] == "A"} { set action "A"; set theaction "accept" } \
			elseif {[string index [string toupper $action] 0] == "V"} { set action "V"; set theaction "voice" } \
			elseif {[string index [string toupper $action] 0] == "O"} { set action "O"; set theaction "op" } \
			else {
				# arm:reply $type $target "error: whitelist action must be either: accept, voice or op"
				# return;
				# -- default to 'accept'
				set action "A"; set theaction "accept"
			}
		
		} elseif {[string match "b*" $list]} {
			# -- blacklist
					 
			set list "black"
			set prefix "B"
			# -- default reason
			if {$reason == ""} { set reason $arm(cfg.def.breason) }
			# -- deny, voice, op actions
			if {[string index [string toupper $action] 0] == "B"} { set action "B"; set theaction "kickban" } \
			else {
				# arm:reply $type $target "error: blacklist action must only be ban."
				# return;
				# -- default to ban
				set action "B"; set theaction "kickban"
			}
		
		} else {
			# -- unknown
			if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
				# -- libdronebl not loaded, or no access to dronebl submit
				arm:reply $stype $starget "\002usage:\002 add <white|black> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"
			} else {
				# -- libdronebl loaded & user has access to dronebl submit
				arm:reply $stype $starget "\002usage:\002 add <white|black|dronebl> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? \[reason\]"		
			}
			continue;
		}
		
		# -- convert host to IP (only if it's a hostname)
		if {$method == "host"} {
			if {[regexp -- {^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$} $value]} {
				# -- host or IP
				if {![regexp -- {^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$} $value]} {
					# -- hostname
					set ip [lindex [arm:dns:lookup $value] 0]
					if {$ip == "NULL" || $ip == ""} { set value $value } else { set value $ip }
				}
			}
		}

		set timestamp [unixtime]
		set modifby $source
	
		set line "${prefix}::$method:$value:$timestamp:$modifby:$action:$limit:0:$reason"
	
		arm:debug 1 "arm:cmd:add: adding line: $line"

		# -- add the list entry
		set id [arm:db:add $line]
		set hits($id) 0
	
		if {$limit != "1-1-1"} { set textlimit " \002limit:\002 $origlimit "  } else { set textlimit " " }
	
		if {$reason != ""} { arm:reply $type $target "added $method ${list}list entry (\002id:\002 $id \002value:\002 $value \002action:\002 ${theaction}${textlimit}\002reason:\002 $reason)" } \
		else { arm:reply $type $target "added $method ${list}list entry (\002id:\002 $id \002value:\002 $value \002action:\002 ${theaction}${textlimit})" }
	
		# -- add automatic bans?
		if {$theaction == "kickban" && $arm(cfg.ban.auto)} {
			set hit 0
			set addban 0
			if {$method == "user"} { set mask "*!*@$tvalue.users.undernet.org"; set addban 1 }
			if {$method == "host"} {
				if {[regexp -- {\*} $tvalue]} { set mask $tvalue } else { set mask "*!*@$tvalue" }
				set addban 1
			}
			if {$addban} {
				if {[info exists hostnicks($tvalue)]} {
					foreach i $hostnicks($tvalue) {
						incr hit
						arm:kickban $i $arm(cfg.chan.def) $mask $arm(cfg.ban.time) "Armour: blacklisted -- $value (reason: $reason) \[id: $id\]"
					}
				}
				if {!$hit} {
					# -- no nicknames on that host found, just do a generic ban
					arm:kickban 0 $arm(cfg.chan.def) $mask $arm(cfg.ban.time) "Armour: blacklisted -- $value (reason: $reason) \[id: $id\]"
				}
			}
		}
	
	}
	# -- end of loop
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;

}

# -- command: rem
# remove a whitelist or blacklist entry
proc arm:cmd:rem {0 1 2 3 {4 ""}  {5 ""}} {
	global userdb arm
	global wline bline regex fline hits
	set type $0
	if {$type == "pub"} {
		set nick $1; set uh $2; set hand $3; set chan $4; set args $5; set target $chan; set source "$nick!$uh"
		if {![userdb:isValidchan $chan]} { return; }
		if {$arm(cfg.help.notc)} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
	}
	if {$type == "msg"} {
		set nick $1; set uh $2; set hand $3; set args $4; set target $nick; set chan $arm(cfg.chan.def); set source "$nick!$uh"
	}
	if {$type == "dcc"} {
		set hand $1; set idx $2; set args $3; set target $idx; set nick $hand; set chan $arm(cfg.chan.def); set source "$hand/$idx"
	}
	
	set cmd "rem"
	
	# -- ensure user has required access for command
	if {![userdb:isAllowed $nick $cmd $type]} { return; }
	set user [userdb:uline:get user nick $nick]
	# -- end default proc template

	set list [lindex $args 0]
	set method [lindex $args 1]
	set value [lindex $args 2]
	
	if {$list == ""} {
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			# -- libdronebl not loaded or user does not have submit access
			arm:reply $stype $starget "\002usage:\002 rem <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
		} else {
			# -- libdronebl loaded & user has submit access
			arm:reply $stype $starget "\002usage:\002 rem <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>? \[type\]"
		}
		return;
	}
	
	# -- check if ID is given
	if {[regexp -- {^\d+(?:,\d+)*$} $list]} {
		# -- id provided
		set origid $list
		foreach id [split $origid ,] {
			set result [arm:get:line $id]
			if {$result == ""} { arm:reply $type $target "error: no such id exists ($id)"; continue; }
			
			# -- interpret the line
			
			arm:debug 3 "arm:cmd:rem: interpret line result: $result"
		
			set result [split $result :]
			lassign $result list id method value
			set reason [join [lrange $result 9 end]]
			if {$list == "W"} { set list "whitelist" } else { set list "blacklist" }
			set action [lindex $result 6]
			set limit [lindex $result 7]
			if {![info exists hits($id)]} { set hits($id) 0 }
			set hitnum $hits($id)
			
			if {$list == "whitelist"} {
				# -- whitelist
				if {$method != "regex"} {
					unset wline($method,$value)
				} else {
					# -- regex whitelist
					unset regex($id)
					unset wline(regex,$id)
				}
			} else {
				# -- blacklist
				if {$method != "regex"} {
					unset bline($method,$value)
				} else {
					# -- regex blacklist
					unset regex($id)
					unset bline(regex,$id)
				}
				# -- unset flood detection cumulative limit if exists
				if {[info exists fline($method,$value)]} { unset fline($method,$value) }
			}
			
			# -- remove from sqlite if in use
			if {$userdb(method) == "sqlite"} {
				# -- sqlite3
				::armdb::db_connect
				::armdb::db_query "DELETE FROM entries WHERE id='$id'"
				::armdb::db_close
				set tmethod "from sqlite"
			} else { set tmethod "from file" }
			
			switch -- $action {
				B	{ set action "kickban" }
				K	{ set action "kick" }
				V	{ set action "voice" }
				A	{ set action "accept" }
				O	{ set action "op" }
			}
			
			# -- try to remove any existing ban?
			if {$method == "host"} {
				arm:debug 2 "arm:cmd:rem: attempting to remove an assocated host ban"
				if {[regexp -- {\*} $value]} { set mask $value } else { set mask "*!*@$value" }
				putquick "PRIVMSG X :UNBAN $chan $mask"
			} elseif {$method == "user"} {
				arm:debug 2 "arm:cmd:rem: attempting to remove an assocated xuser ban"
				set mask "*!*@$value.users.undernet.org"
				putquick "PRIVMSG X :UNBAN $chan $mask"
			}
	
			arm:debug 1 "arm:cmd:rem: removed $list $method entry $tmethod: $value action: $action reason: $reason"
			if {$limit != "1-1-1"} { arm:reply $type $target "removed $method $list entry (\002id:\002 $id \002value:\002 $value \002action:\002 $action \002limit:\002 $limit \002hits:\002 $hitnum \002reason:\002 $reason)" } \
			else { arm:reply $type $target "removed $method $list entry (\002id:\002 $id \002value:\002 $value \002action:\002 $action \002hits:\002 $hitnum \002reason:\002 $reason)" }

		}
		# -- end of foreach
		
		# -- create log entry for command use
		arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
		return;
		
	}
	# -- end of ID

	
	arm:debug 3 "arm:cmd:rem: list: $list method: $method value: $value"

		
	# -- catch method
	switch -- $method {
		regex	{ set method "regex" }
		r		{ set method "regex" }
		user	{ set method "user" }
		u		{ set method "user" }
		xuser	{ set method "user" }
		host	{ set method "host" }
		h		{ set method "host" }
		ip		{ set method "host" }
		net		{ set method "host" }
		mask	{ set method "host" }
		asn		{ set method "asn" }
		a		{ set method "asn" }
		country	{ set method "country" }
		geo		{ set method "country" }
		g		{ set method "country" }
		chan	{ set method "chan" }
		channel	{ set method "chan" }
		c		{ set method "chan" }
		rname	{ set method "rname" }
		realname { set method "rname" }
		name	{ set method "rname" }
		ircname	{ set method "rname" }
		n		{ set method "rname" }
		default {
			if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
				# -- libdronebl not loaded or user does not have submit access
				arm:reply $stype $starget "\002usage:\002 rem <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
			} else {
				# -- libdronebl loaded & user has submit access
				arm:reply $stype $starget "\002usage:\002 rem <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>? \[type\]"
			}
			return;
		}
	}
	
	if {[string index $list 0] == "w"} { set list "white" } \
	elseif {[string index $list 0] == "b"} { set list "black" } \
	elseif {[string index $list 0] == "d"} { set list "dronebl" } \
	else {
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			# -- libdronebl not loaded or user does not have submit access
			arm:reply $stype $starget "\002usage:\002 rem <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
		} else {
			# -- libdronebl loaded & user has submit access
			arm:reply $stype $starget "\002usage:\002 rem <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>? \[type\]"
		}
		return;
	}
		
	# -- DroneBL
	if {$list == "dronebl"} {
		# -- check if libdronebl loaded & user has access
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			arm:reply $stype $starget "\002usage:\002 rem <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
			return; 
		} else {
			if {$value == "" || $method == ""} {
				arm:reply $stype $starget "\002usage:\002 rem dronebl <host|ip> <value1,value2..> \[type\]"
				return;				
			}
		
		}
		
		
		set ttype [lindex $args 3]
		
		# -- cater for last N hosts
		if {$method == "last"} {
			if {![info exists lasthosts($arm(cfg.chan.def))]} { arm:reply $type $target "error: no hosts in memory."; return; }
			set method "host"
			set loop [lrange $lasthosts($arm(cfg.chan.def)) 0 [expr $value - 1]] 
		} else { 
			set loop [split $value ,]
		}
		# -- allow comma delimited
		foreach ip $loop {
			if {$ip == "" || (![arm:isValidIP $ip] && {set ip [arm:dns:lookup $ip]} == "error") || ($method != "ip" && $method != "host")} {
				arm:reply $stype $starget "\002usage:\002 rem dronebl <host|ip> <value1,value2..> \[type\]"
				continue;		
			}
			if {$ttype == "" || ![regexp -- {^\d+$} $ttype]} { set ttype $arm(cfg.dronebl.type) }
			# -- check if entry exists
			set result [::dronebl::lookup $ip]	
			arm:debug 2 "arm:cmd:rem: dronebl result: $result"
			if {[join [lindex $result 0]] == "No matches."} {
				# -- exists
				arm:debug 1 "arm:cmd:rem: dronebl removal failed (no match: $ip)"
				arm:reply $type $target "error: entry does not exist -- ip: $ip"
				continue;
			}
			# -- parse the results (most useful with the view command)
			set i 1
			foreach line $result {
				arm:debug 2 "arm:cmd:rem: dronebl line: $line"
				# -- ignore the first (header) line
				if {$i == 1} { incr i; continue; }
				# {ID IP {Ban type} Listed Timestamp} {305082 173.212.195.50 17 1 {2011.02.15 01:54:17}}
				lassign $line sid sip stype slisted stimestamp
				arm:debug 1 "arm:cmd:rem: id: $sid ip: $sip type: $stype listed: $slisted timestamp: $stimestamp"
				incr i
				break;
			}
			# -- remove the entry
			set result [::dronebl::remove $sid]
			if {$result == "true"} {
				arm:debug 1 "arm:cmd:rem: dronebl removal successful (ip: $ip)"
				arm:reply $type $target "dronebl removal successful -- ip: $ip"
				continue;
			} else {
				arm:debug 1 "arm:cmd:rem: dronebl removal failed (ip: $ip response: $result)"
				arm:reply $type $target "dronebl removal failed -- ip: $ip"
				continue;
			}
		}
		# -- endof foreach ip
		
		# -- create log entry for command use
		arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
		
		return;
	}
	# -- end dronebl add
	
	if {$list == "" || $method == "" || $value == ""} {
		if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
			# -- libdronebl not loaded or user does not have submit access
			arm:reply $stype $starget "\002usage:\002 rem <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
		} else {
			# -- libdronebl loaded & user has submit access
			arm:reply $stype $starget "\002usage:\002 rem <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>? \[type\]"
		}
		return;
	}
	
	
	set noexist 0
	set regexmatch 0
	
	set origvalue $value
	# -- loop through comma separated values
	# -- only do this for types that aren't regex, or rname -- which could include ',' chars
	if {$method != "regex" && $method != "rname"} { set tvalue [split $origvalue ,] } else { set tvalue $origvalue }
	foreach value $tvalue {
	
		# -- determine what list to remove from
		if {[string match "w*" $list]} {
			# -- whitelist
			set list "whitelist"
	
			if {$method == "regex"} {
				# -- regex whitelist
				foreach dbid [array names regex] {
					#set res [split $regex($dbid)]
					set res $regex($dbid)
					arm:debug 2 "arm:cmd:rem: res: $res value: $value"
					if {$res == $value} { 
						set regexmatch 1
						set id $dbid
						set action [lindex [split $wline(regex,$dbid) :] 6]
						set limit [lindex [split $wline(regex,$dbid) :] 7]
						set reason [lrange [split $wline(regex,$dbid) :] 9 end]
						unset wline(regex,$dbid)
						unset regex($dbid)
						break;
					}
				}
			} elseif {![info exists wline($method,$value)]} { set noexist 1 } \
				else {
					set id [lindex [split $wline($method,$value) :] 1]
					set action [lindex [split $wline($method,$value) :] 6]
					set limit [lindex [split $wline($method,$value) :] 7]
					set reason [lrange [split $wline($method,$value) :] 9 end]
					unset wline($method,$value)
			}
	
		} elseif {[string match "b*" $list]} {
			# -- blacklist
			set list "blacklist"
			
			if {$method == "regex"} {
				# -- regex blacklist
				foreach dbid [array names regex] {
					#set res [split $regex($dbid)]
					set res $regex($dbid)
					arm:debug 2 "arm:cmd:rem: res: $res value: $value"
					if {$res == $value} { 
						set regexmatch 1
						set id $dbid
						set action [lindex [split $bline(regex,$dbid) :] 6]
						set limit [lindex [split $bline(regex,$dbid) :] 7]
						set reason [lrange [split $bline(regex,$dbid) :] 9 end]
						unset bline(regex,$dbid)
						unset regex($dbid)
						# -- remove fline in case it exists (floodnet detection)
						if {[info exists fline($method,$value)]} { unset fline($method,$value) }
						break;
					}
				}
			} elseif {![info exists bline($method,$value)]} { set noexist 1 } \
				else {
					set id [lindex [split $bline($method,$value) :] 1]
					set action [lindex [split $bline($method,$value) :] 6]
					set limit [lindex [split $bline($method,$value) :] 7]
					set reason [lrange [split $bline($method,$value) :] 9 end]
					unset bline($method,$value)
					# -- remove fline in case it exists (floodnet detection)
					if {[info exists fline($method,$value)]} { unset fline($method,$value) }
				}
			} else {
			# -- unknown
			if {[info command ::dronebl::submit] == "" || [userdb:uline:get level nick $nick] < $arm(cfg.dronebl.lvl)} {
				# -- libdronebl not loaded or user does not have submit access
				arm:reply $stype $starget "\002usage:\002 rem <white|black|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>?"
			} else {
				# -- libdronebl loaded & user has submit access
				arm:reply $stype $starget "\002usage:\002 rem <white|black|dronebl|id> ?<user|host|rname|regex|country|asn|chan> <value1,value2..>? \[type\]"
			}
			continue;
		}
		
		
		# -- error if entry didn't exist
		if {$noexist || $method == "regex" && !$regexmatch} { arm:reply $type $target "$method $list entry $value does not exist"; continue; }
		
		# -- remove from sqlite if in use
		if {$userdb(method) == "sqlite"} {
			# -- sqlite3
			::armdb::db_connect
			::armdb::db_query "DELETE FROM entries WHERE id='$id'"
			::armdb::db_close
			set tmethod "from sqlite"
		} else { set tmethod "from file" }
		
		arm:debug 1 "arm:cmd:rem: removed $method $list entry $tmethod: $value reason: $reason"
	
		# -- try to remove any existing ban?
		if {$method == "host"} { 
			arm:debug 2 "arm:cmd:rem: attempting to remove an assocated host ban"
			if {[regexp -- {\*} $value]} { set mask $value } else { set mask "*!*@$value" }
			putquick "PRIVMSG X :UNBAN $chan $mask"
		} elseif {$method == "xuser"} {
			arm:debug 2 "arm:cmd:rem: attempting to remove an assocated xuser ban"
			mask "*!*@$value.users.undernet.org"
			putquick "PRIVMSG X :UNBAN $chan $mask"
		}
		
		switch -- $action {
			B	{ set action "kickban" }
			K	{ set action "kick" }
			V	{ set action "voice" }
			A	{ set action "accept" }
			O	{ set action "op" }
		}
		
		set hitnum $hits($id)
		
		if {$limit != "1-1-1"} { arm:reply $type $target "removed $method $list entry (\002id:\002 $id \002value:\002 $value \002action:\002 $action \002limit:\002 $limit \002hits:\002 $hitnum \002reason:\002 $reason)" } \
		else { arm:reply $type $target "removed $method $list entry (\002id:\002 $id \002value:\002 $value \002action:\002 $action \002hits:\002 $hitnum \002reason:\002 $reason)" }
		
	}
	# -- end foreach value loop
	
	# -- create log entry for command use
	arm:log:cmdlog BOT $user [userdb:uline:get id user $user] [string toupper $cmd] [join $args] "$nick!$uh" "" "" ""
	
	return;

}


arm:debug 0 "\[@\] Armour: loaded user commands"




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-13_raw.tcl
#
# raw server response procedures
#


bind join - * { arm:coroexec arm:raw:join }
bind sign - * { arm:coroexec arm:raw:quit }

# -- netsplit handling
bind splt - * { arm:coroexec arm:raw:split }
bind rejn - * { arm:coroexec arm:raw:rejn }

bind raw - 354 { arm:coroexec arm:raw:who }
bind raw - 315 { arm:coroexec arm:raw:endofwho }
bind raw - 317 { arm:coroexec arm:raw:signon }
bind raw - 355 { arm:coroexec arm:raw:names }
bind raw - 366 { arm:coroexec arm:raw:endofnames }
bind raw - 401 { arm:coroexec arm:raw:nicknoton }
bind raw - 478 { arm:coroexec arm:raw:fullbanlist }

# -- auto management of mode 'secure'
bind mode - "* +D" { arm:coroexec arm:modeadd:D }
bind mode - "* -D" { arm:coroexec arm:moderem:D }
bind mode - "* +d" { arm:coroexec arm:modeadd:d }
bind mode - "* -d" { arm:coroexec arm:moderem:d }

# -- manage global banlist
bind mode - "* +b" { arm:coroexec arm:modeadd:b }

# -- manage scanlist on manual voice
bind mode - "* +v" { arm:coroexec arm:modeadd:v }



# -- begin onjoin scans
proc arm:raw:join {nick uhost hand chan} {
	global arm botnick full adapt chanban
	global setx time ltypes
	global adaptn adaptni adaptnir adapti adaptir adaptr
	global exempt override netsplit
	global jointime newjoin moded
	# -- fline is a bline (blacklist entry) with a non-default flood limit
	global fline
	# -- expost gklist to not send /who if nick is already being kicked (and thus, caught)
	global gklist
	# -- track nicknames on a host (for floodnet clone hits)
	global hostnicks
	# -- track recent hosts (for quick blacklists)
	global lasthosts
	
	# -- tidy nickname
	set nick [split $nick]
		
	if {$nick == $botnick} { return; }
	
	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]
	
	# -- add host to lasthosts
	if {$arm(cfg.lasthosts) != ""} {
		if {![info exists lasthosts($chan)]} { set lasthosts($chan) $host }
		if {[lsearch $lasthosts($chan) $host] == -1} {
			# -- add host to lasthost tracking
			set length [llength $lasthosts($chan)]
			set lasthosts($chan) [linsert $lasthosts($chan) 0 $host]
			# -- keep the list maintained
			set pos [expr $arm(cfg.lasthosts) - 1]
			if {$length >= $arm(cfg.lasthosts)} { set lasthosts($chan) [lreplace $lasthosts($chan) $pos $pos] }
		}
	}
 
	# -- safety nets
	if {![info exists arm(mode)]} { return; }
	# -- only do scans if Armour is on.  If 'secure', scans were already done.
	if {$arm(mode) == "off" || $arm(mode) == "secure"} { return; }
	# -- only scan if this is the active scan chan
	if {[string tolower $arm(cfg.chan.auto)] != [string tolower $chan]} { return; }
	# -- safety net (global kick list)
	if {![info exists gklist]} { set gklist "" }
	
	# -- set newjoin for nick (identify 'newcomers')
	set newjoin($nick) $uhost
	
	# -- store timestamp of newcomer for ordered sorting with floodnets
	set jointime([clock clicks]) $nick
		
	# -- unset after 20 secs
	utimer $arm(cfg.time.newjoin) "arm:newjoin:unset [split $nick]"

	# -- check if full channel scan running
	#if {[info exists full]} { 
	#	arm:debug 1 "arm:raw:join: [join $nick] joined $chan, however full channel scan in progress: [array names full]"
	#	return; 
	#}
	
	# -- ensure I am opped
	if {![botisop $arm(cfg.chan.auto)]} { 
		arm:debug 1 "arm:raw:join: [join $nick] joined $chan, however I am not opped so cannot proceed!"
		return; 
	}
	
	# ---- mode must be "on" -- begin
	
	set start [clock clicks]
	set time($nick) [clock clicks]
		
	arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------"
	arm:debug 1 "arm:raw:join: [join $nick]!$uhost joined $chan....."
	# arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------" 

	# ---- FLOODNET DETECTION (adaptive & positive regex scans with join limits)    
	
	# -- check adaptive regex exempts
	set exempt($nick) 0
		
	# -- track nicknames on a host
	if {![info exists hostnicks($host)]} { set hostnicks($host) $nick } else {
		# -- only add if doesn't already exist (for some strange reason)
		if {[lsearch $hostnicks($host) $nick] == -1} { lappend hostnicks($host) $nick }
	}

	# -- check if returning from netsplit?
	if {[info exists netsplit($nick!$uhost)]} {
		# -- check if timeago is not more than netsplit memory timeout
		if {[expr ([clock seconds] - $netsplit($nick!$uhost)) * 60] >= $arm(cfg.split.mem)} {
			arm:debug 1 "arm:raw:join: [join $nick] returned from netsplit (split [userdb:timeago $netsplit($nick!$uhost)] ago), exempting from scans..."
			set exempt($nick) 1
		} else {
				arm:debug 1 "arm:raw:join: [join $nick] returned after 'netsplit' after timeout period (split [userdb:timeago $netsplit($nick!$uhost)] ago), not exempt from scans..."
		}
		unset netsplit($nick!$uhost)
	}

	# -- exempt if recently set umode +x (read from signoff message)
	if {[info exists setx($nick)] && !$exempt($nick)} { 
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost has just set umode +x (exempt from floodnet detection)"
		set exempt($nick) 1 
	}

	# -- exempt if opped on common chan
	if {[isop $nick] && !$exempt($nick)} {
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost is opped on common chan (exempt from floodnet detection" 
		set exempt($nick) 1 
	}

	# -- exempt if voiced on common chan
	if {[isvoice $nick] && !$exempt($nick)} {
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost is voiced on common chan (exempt from floodnet detection)" 
		set exempt($nick) 1
	}
	
	# -- exempt if umode +x
	if {[string match -nocase "*.users.undernet.org" $host] && !$exempt($nick)} { 
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost is umode +x (exempt from floodnet detection)" 
		set exempt($nick) 1
	}
		
	# -- exempt if resolved ident
	if {![string match "~*" $ident] && !$exempt($nick)} { 
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost has resolved ident (exempt from floodnet detection)"
		set exempt($nick) 1 
	}

	# -- check for manual [temporary] override (from 'exempt' cmd)
	if {[info exists override([string tolower $nick])] && !$exempt($nick)} {
		set exempt($nick) 1
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost is exempt from all scans via manual override."
	}
	
	# -- check for mode +D removal in chan (avoid floodnet scans for mass revoiced clients)
	if {[info exists moded($chan)] && !$exempt($nick)} {
		set exempt($nick) 1
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost is exempt from all scans as result of post 'mode -d' mass-revoice"
	}
	
		
	# -- TURN OFF EXEMPT IF TEST MODE ON (helps for testing)
	if {[info exists arm(test)]} { 
		arm:debug 1 "arm:raw:join: TEST MODE ON -- [join $nick]!$uhost is NOT exempt from floodnet detection"
		set exempt($nick) 0 
	}
	
	# -- floodnet checks
	set hit 0
	if {!$exempt($nick) && $arm(mode) != "secure"} {
		# -- run floodnet detection
		set hit [arm:check:floodnet $nick $uhost $hand $chan]
	} else { arm:debug 1 "arm:raw:join: user was exempt from primary (ie. nick, ident & nick!ident) floodnet detection" }
	
	if {$arm(mode) == "secure"} {
		# -- don't do floodnet detection in mode: secure
		# -- multiple /who replies from '/names -d <chan>' currently confuses it for simultaneous joins
		arm:debug 0 "arm:raw:join: floodnet detection not ran for $nick!$uhost (mode: secure)"
	} 
	
	# -- end of exempt

	# -- user has been hit if already in global kick list
	if {[lsearch $gklist $nick] != -1} { set hit 1 }

	# -- continue with further scans
	
	# arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------" 

	# -- send /WHO for further scans
	
	set runtime [arm:runtime $start]
	
	# -- check for manual [temporary] override (from 'exempt' cmd)
	if {[info exists override([string tolower $nick])]} {
		catch { unset override([string tolower $nick]) }
		arm:debug 1 "arm:raw:join: [join $nick]!$uhost was exempt from all scans via manual override.. halting. ($runtime)"
		arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------" 
		return;
	}
	
	# -- if no adaptive hit, and user wasn't exempt
	if {!$hit && !$exempt($nick)} {
		arm:debug 1 "arm:raw:join: floodnet detection complete (no hit), sending /WHO [join $nick] n%nuhiart,102 ($runtime)"
		# arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------" 
		putquick "WHO [join $nick] n%nuhiart,102"
		return;
	}
	
	if {!$hit && $exempt($nick)} {
		arm:debug 1 "arm:raw:join: floodnet detection exempted, sending /WHO [join $nick] n%nuhiart,102 ($runtime)"
		# arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------" 
		putquick "WHO [join $nick] n%nuhiart,102"
		return;
	}
	
	# -- there is an adaptive scan hit (user kickbanned)
	arm:debug 1 "arm:raw:join: floodnet detection complete (user [join $nick]!$uhost hit!), ending. ($runtime)"
	arm:debug 1 "arm:raw:join: ------------------------------------------------------------------------------------" 
	return;

}


proc arm:raw:nicknoton {server cmd text} {
	global arm

	# 401 notEmp1599 nick123blah :No such nick
	
	set mynick [lindex $text 0]
	set nick [lindex $text 1]
	
	# -- clean up any vars for this nick that may exist
	global hostnicks fullname nickhost ipnicks
	global gklist scanlist
	
	# -- we only know the host if this is set
	if {[info exists nickhost($nick)]} {
		set host $nickhost($nick)
		
		# -- remove nick from hostnicks if exists
		if {[info exists hostnicks($host)]} {
			set pos [lsearch $hostnicks($host) $nick]
			if {$pos != -1} {
				# -- nick within
				set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
				if {$hostnicks($host) == ""} { unset hostnicks($host) }
			}
		}
		
		# -- remove nick from hostnicks if exists
		if {[info exists hostnicks($host)]} {
			set pos [lsearch $hostnicks($host) $nick]
			if {$pos != -1} {
				# -- nick within
				set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
				if {$hostnicks($host) == ""} { unset hostnicks($host) }
			}
		}
	}
	
	
	# -- remove nick from global kicklist if exists
	if {[info exists gklist]} {
		set pos [lsearch $gklist $nick]
		if {$pos != -1} {
			# -- nick within
			set gklist [lreplace $gklist $pos $pos]
			if {$gklist == ""} { unset gklist }
		}
	}

	# -- remove nick from ipnicks if exists
	if {[info exists nickip($nick)]} {
		set ip $nickip($nick)
		unset nickip($nick)
		# -- remove nick from ipnicks if exists
		if {[info exists ipnicks($ip)]} {
			set pos [lsearch $ipnicks($ip) $nick]
			if {$pos != -1} {
				# -- nick within
				set ipnicks($ip) [lreplace $ipnicks($ip) $pos $pos]
				if {$ipnicks($ip) == ""} { unset ipnicks($ip) }
			}		
		}
	}

	
	# -- scanlist(nicklist) (list of those to scan on /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $nick]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
	
	# -- paranoid scanlist- list of those already scanned
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $nick]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}

	if {[userdb:isLogin $nick]} {
		# -- begin autologout
		set user [userdb:uline:get user nick $nick]
		# -- update lastnick and lasthost
		userdb:uline:set lastnick $nick user $user
		set lasthost [userdb:uline:get curhost user $user]
		userdb:uline:set lasthost $lasthost user $user
		# -- void login by setting curnick and curhost to null
		userdb:uline:set curnick "" user $user
		userdb:uline:set curhost "" user $user
		putloglev d * "arm:raw:nicknoton autologout for $user ($nick!$lasthost)"
	}

	# -- tidy fullname array
	if {[info exists fullname($nick)]} { unset fullname($nick) }

	# -- tidy nickhost array
	if {[info exists nickhost($nick)]} { unset nickhost($nick) }	

}


# -- from periodic '/names -d' from secure mode
proc arm:raw:names {server cmd text} {
        global arm scanlist

        # 355 Empus = #armour : Empus nick2 nick3

        set text [split $text]

        set mynick [lindex $text 0]
        set chan [lindex $text 2]

        # -- only continue if correct chan, and secure mode enabled
        if {[string tolower $chan] != [string tolower $arm(cfg.chan.auto)] || $arm(mode) != "secure"} { return; }

        # -- only include new nicknames on the list to /WHO, if they haven't already been scanned and ignored (ie. on paranoid list)
        set thelist [string trimleft [lrange $text 3 end] :]

        if {$thelist != ""} { arm:debug 4 "arm:raw:names: thelist: $thelist" }

        if {![info exists scanlist(paranoid)]} { set scanlist(paranoid) "" }
        if {![info exists scanlist(nicklist)]} { set scanlist(nicklist) "" }

        # -- only add to the scan list if we haven't already scanned this guy
        set nicklist ""
        foreach i $thelist {
                if {[lsearch $scanlist(paranoid) $i] == -1} {
                        # -- nick hasn't been scanned before
                        set i [string trimleft $i :]
                        lappend nicklist [join $i]
                }
        }
        #set scanlist(nicklist) $thelist
        # -- should this be $thelist or $nicklist?
        set scanlist(nicklist) $nicklist
        if {($scanlist(nicklist) != "") && ($scanlist(paranoid) != "")} {
                arm:debug 4 "arm:raw:names: scanlist(paranoid): $scanlist(paranoid) -- scanlist(nicklist): [join [join $scanlist(nicklist)]]"
        }
}


proc arm:raw:endofnames {server cmd args} {
        global arm scanlist
        global hostnicks ipnicks
        global nickip fullname nickhost

        set args [join $args]
        set chan [lindex $args 1]

        if {$chan != $arm(cfg.chan.def)} { return; }

        # -- safety nets
        if {![info exists scanlist(nicklist)]} { set scanlist(nicklist) [list] }
        if {![info exists scanlist(paranoid)]} { set scanlist(paranoid) [list] }

        # -- build the list of nicknames to scan (sent from arm:raw:endofnames)
        if {$scanlist(nicklist) != ""} {
                arm:debug 4 "\002arm:raw:endofnames:\002 list of '/names -d' nicks: [join $scanlist(nicklist)]"
        }

        # -- we need to clean here otherwise list doesn't clear and '/names -d' won't restart
        # -- if we don't get a /who response from a client (ie. they quickly quit or changed nicks)

        # -- use temp var for further down in proc
        set thelist $scanlist(nicklist)

        if {$scanlist(nicklist) != ""} {
                foreach n $scanlist(nicklist) {
                        arm:scan:cleanup $n
                }
        } else {
                if {$arm(mode) == "secure"} {
                        # -- only start the timer again if it's not already running
                        # -- (/names could be running for other reasons)
                        arm:secure;
                }
        }

        # -- 'scanlist(paranoid)' contains the nicknames we have already scanned (don't scan them again)
        if {$scanlist(paranoid) != ""} { }
        arm:debug 5 "\002arm:raw:endofnames:\002 scanlist(paranoid): $scanlist(paranoid)"

        # -- we need to remove people from paranoid scanlist (previously scanned), if they are no longer waiting to be scanned
        # -- nick may have left, quit, kicked, or changed nicks
        foreach p $scanlist(paranoid) {
                if {[lsearch $thelist $p] == -1} {
                        # -- nick is no longer waiting to be scanned... remove them from scanlist(paranoid)
                        # -- unless the nicklist is empty for some reason:
                        if {$thelist != ""} {
                                set pos [lsearch $scanlist(paranoid) $p]
                                arm:debug 4 "arm:raw:endofnames: removing nick: $p from scanlist(paranoid)"
                                set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
                        }
                }
        }

        if {$scanlist(paranoid) != ""} { }
        arm:debug 5 "\002arm:raw:endofnames:\002 updated scanlist(paranoid): $scanlist(paranoid)"

        # -- trigger the /WHO so the results can be scanned
        if {$thelist != ""} {
                set list [join $thelist ,]
                arm:debug 4 "\002arm:raw:endofnames:\002 sending /WHO $list n%nuhiart,102"
                putquick "WHO $list n%nuhiart,102"
        }
}

proc arm:raw:fullbanlist {server cmd args} {
	global arm

	set args [join $args]

	set chan [lindex $args 1]
	set banmask [lindex $args 2]
	
	# -- only continue if the main chan
	if {$chan != $arm(cfg.chan.auto)} { return; }
	
	arm:debug 0 "arm:raw:fullbanlist: channel $chan banlist full! (using generic X ban)";
	
	# -- lockdown chan (if not already)
	if {![regexp -- {r} [getchanmode $chan]]} {
		putquick "MODE $chan +r" -next
		# -- advise channel  
		# -- we only want to do this once though... 
		putquick "NOTICE $arm(cfg.chan.auto) :Armour: channel banlist is full!"
	}
	
	# -- use generic ban
	putquick "PRIVMSG X :BAN $chan $banmask $arm(cfg.ban.time) $arm(cfg.ban.level) Armour: generic ban (full banlist)" -next
	
}


			

# -- signoff procedure to exempt clients from adaptive scans when setting umode +x
proc arm:raw:quit {nick uhost hand chan reason} {
	global arm setx netsplit hostnicks ipnicks nickip nickhost
	global scanlist
	
	set nick [split $nick]
	set host [lindex [split $uhost @] 1]
	
	# -- remove nick from hostnicks if exists
	if {[info exists hostnicks($host)]} {
		set pos [lsearch $hostnicks($host) $nick]
		if {$pos != -1} {
			# -- nick within
			set hostnicks($host) [lreplace $hostnicks($host) $pos $pos]
		}
	}
	
	if {[info exists nickip($nick)]} {
		set ip $nickip($nick)
		# -- remove nick from ipnicks if exists
		if {[info exists ipnicks($ip)]} {
			set pos [lsearch $ipnicks($ip) $nick]
			if {$pos != -1} {
				# -- nick within
				set ipnicks($ip) [lreplace $ipnicks($ip) $pos $pos]
			}
		}
		unset nickip($nick)
	}
	
	# -- scanlist(nicklist) (list of those to scan on /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $nick]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
	
	# -- scanlist(paranoid) -- (list of those already scanned)
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $nick]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}
	
	if {[info exists nickhost($nick)]} { unset nickhost($nick) }
	if {[info exists fullname($nick)]} { unset fullname($nick) }
		
	arm:debug 4 "arm:raw:quit: quit detected in $chan: [join $nick]!$uhost (reason: $reason)"
	
	# -- those who set umode +x
	if {$reason == "Registered"} {
		# -- umode +x detected
		# -- note: this could be cheated, we have no /true/ way of detecting this during /quit
		set setx($nick) 1
		# -- unset array after 2 seconds (plenty of time to allow rejoin)
		utimer 2 "catch { unset setx($nick) }"
		return;
		
	}
	
	# -- those who get glined, do we add auto blacklist entry
	if {[string match "G-lined *" $reason] && $arm(cfg.gline.auto)} {
		arm:debug 4 "arm:raw:quit: G-Line $chan: [join $nick]!$uhost (reason: $reason)"
		# -- only if matches configured mask
                if {[string match $arm(cfg.gline.mask) $reason] && ![string match $arm(cfg.gline.nomask) $reason]} {
			# -- add automatic blacklist entry
			set thost [lindex [split $uhost @] 1]
			if {[regexp -- $arm(cfg.xhost) $thost -> tuser]} {
				# -- user is umode +x, add a 'user' blacklist entry instead of 'host'
				set method "user"
				set equal $tuser
			} else {
				# -- add a host blacklsit entry
				set method "host"
				set equal $thost
			}

			if {![info exists bline($method,$equal)] && ![info exists wline($method,$equal)]} {
				# -- add automatic blacklist entry

				set reason "(auto) $reason"
				set line "B::$method:$equal:[unixtime]:Armour:B:1-1-1:0:$reason"
				arm:debug 1 "arm:raw:quit: adding auto blacklist line: $line"

				# -- add the list entry
				set id [arm:db:add $line]
			}
			# -- end of exists
		}
		# -- end gline match
	}
	# -- end automatic blacklist on gline
	
	
}

# -- netsplit handling
proc arm:raw:split {nick uhost hand chan} {
	global arm netsplit
	set nick [split $nick]
	# -- netsplit detected
	if {![info exists netsplit($nick)]} {
		arm:debug 1 "arm:raw:split: netsplit detected in $chan: [join $nick]!$uhost"
		set netsplit($nick!$uhost) [unixtime]
		# -- do we keep this array value indefinitely, or unset after a configured timeout?
		timer $arm(cfg.split.mem) "arm:split:unset $nick!$uhost"
	}
}

# -- netsplit rejoin handling
proc arm:raw:rejn {nick uhost hand chan} {
	global arm netsplit
	set nick [split $nick]
	# -- netsplit detected
	arm:debug 1 "arm:raw:split: netsplit rejoin identified in $chan: [join $nick]!$uhost"
	catch { unset netsplit($nick!$uhost) }
}


# -- /whois from arm:scan:continue
# obtains client signon and idle time to yield within coroutine
proc arm:raw:signon {server cmd text} {
        global arm
        global paranoid

        set text [split $text]

        # notEmp notEmp 16015 1300141746 :seconds idle, signon time

        set nick [lindex $text 1]
        arm:debug 4 "arm:raw:signon: text: $text -- nick: $nick"

        # -- continue if trying to yield results in arm:scan:continue
        if {[info exists paranoid(coro,$nick)]} {

                set idle [lindex $text 2]
                set signon [lindex $text 3]

                arm:debug 3 "arm:raw:signon: nick: $nick idle: $idle signon: $signon"

                # -- yield the results -> proc arm:scan:continue
                $paranoid(coro,$nick) "$idle $signon"
                return 0;
        }
}


# -- /who response for client scans
# only used to obtain realname for regex scans (if any regex entries exist)
proc arm:raw:who {server cmd text} {
	global arm black
	# -- don't continue if nick exists in global kick list (already caught by floodnet)
	global gklist
	# -- track nicknames on host
	global hostnicks
	# -- track nicknames on ip
	global ipnicks
	# -- track hostname of nick
	global nickhost
	# -- track ip of nick
	global nickip
	# -- track rname of nick
	global fullname
	# -- track the scanlist (to send at /endofwho)
	global scanlist
	# -- fullscan underway?
	global full
	# -- recent channel bans
	global chanban
	
	# -- safety nets
	if {$arm(mode) == "off" || ![info exists arm(mode)]} { return; }
	if {![info exists gklist]} { set gklist "" }

	# FORMAT:
	#
	# Empus2 101 empus 172.16.4.5 172.16.4.5 Empus Empus :why? why not?
	# Empus2 101 empus 172.16.4.5 172.16.4.5 Empus 0 :why? why not?
	#
	
	set text [split $text]

        lassign $text mynick qtype ident ip host nick xuser
        set rname [lrange $text 7 end]

	# -- using query type 102 for Armour queries
	if {$qtype != 102} { return; }

        set rname [string trimleft $rname ":"]
        set rname [string trimright $rname " "]
        set rname [list $rname]
	
	# -- don't continue if nick already exists in global kick list (caught by floodnet detection)
	if {[lsearch $gklist $nick] != -1} { return; }
	
	# -- don't continue if mask has been recently banned (ie. floodnet detection)
	set mask1 "*!*@$host"
	set mask2 "*!~*@$host"

	# -- is full channel scan underway?	
	if {[info exists full]} {
		# -- full channel scan under way
		set fullscan 1
		set list [lsort [array names full]]
		foreach channel $list {
			set split [split $channel ,]
			if {[lindex [split $channel ,] 0] == "chanscan"} {
				set chan [lindex [split $channel ,] 1]
				incr full(usercount,$chan)
				break;
			} 
		}
	} else { set chan $arm(cfg.chan.auto); }
	
	if {[info exists chanban($chan,$mask1)] || [info exists chanban($chan,$mask2)]} { return; }
		
	# -- save array for adaptive rname scan
	set fullname($nick) $rname
				
	# -- check if 'black' command was used
	if {[info exists black($nick)]} {
		# -- /who triggered from 'black' command
		arm:debug 2 "arm:raw:who: /who response received from 'black' command"
		set mask [maskhost $nick!$ident@$host]
		set timestamp [unixtime]
		set modifby $black($nick,modif)
		set chan $black($nick,chan)
		set type $black($nick,type)
		set target $black($nick,target)
		set reason $black($nick,reason)
		
		if {$xuser == 0} {
			# -- not logged in, do host entry
			set method "host"
			set value $mask
		} else {
			# -- logged in, add username entry
			set method "user"
			set value $xuser      
		}
		
		arm:reply $type $target "added $method blacklist entry for: $value (reason: $reason)"
		
		# -- add the list entry
		set line "B::$method:$value:$timestamp:$modifby:B:1-1-1:0:$reason"
		arm:debug 1 "arm:raw:who adding line from 'black' command: $line"
		set id [arm:db:add $line]
		# -- add the ban
		arm:kickban $nick $chan $mask $arm(cfg.ban.time) $reason
		
		# -- clear vars
		catch { unset black($nick) }
		catch { unset black($nick,chan) }
		catch { unset black($nick,type) }
		catch { unset black($nick,target) }
		catch { unset black($nick,reason) }
		catch { unset black($nick,modif) }
		
		return;
	}
		
        # -- track nicknames on host
        #if {![info exists hostnicks($host)]} { set hostnicks($host) $nick } else {
        #        # -- only add if doesn't already exist
        #        if {[lsearch $hostnicks($host) $nick] == -1} { lappend hostnicks($host) $nick }
        #}
        # -- track nicknames on IP
        #if {![info exists ipnicks($ip)]} { set ipnicks($ip) $nick } else {
        #        # -- only add if doesn't already exist
        #        if {[lsearch $ipnicks($ip) $nick] == -1} { lappend ipnicks($ip) $nick }
        #}
        # -- track hostname of nick
        set nickhost($nick) $host
        # -- track ip of nick
        set nickip($nick) $ip

        # -- build list to use at /endofwho
        arm:debug 3 "arm:raw:who: appending to scanlist(scanlist): nick: [join $nick] -- ident: $ident -- ip: $ip -- host: $host -- xuser: $xuser -- rname: [join [join $rname]]"
        lappend scanlist(scanlist) "[list $nick] $ident $ip $host $xuser $rname"

}

proc arm:raw:endofwho {server cmd text} {
        global arm full scanlist
        # set mynick [lindex [join $text] 0]
        set mask [lindex $text 1]
        # -- any vars to unset?

        if {[info exists full(chanscan,$mask)]} {
                # -- it was a full chanscan
                set chan $mask
                arm:debug 1 "arm:raw:endofwho: ending full channel scan: $chan"
                set type [lindex $full(chanscan,$mask) 0]
                set target [lindex $full(chanscan,$mask) 1]
                set start [lindex $full(chanscan,$mask) 2]
                set count $full(usercount,$mask)
                set runtime [arm:runtime $start]

                arm:reply $type $target "channel scan complete.. scanned $count users ($runtime)"
                if {$type != "pub"} { putquick "NOTICE @$chan :Armour: channel scan complete.. scanned $count users ($runtime)"  }
                if {$chan != $arm(cfg.chan.report)} { putquick "NOTICE $arm(cfg.chan.report) :Armour: channel scan complete.. scanned $count users ($runtime)" }
        }

        # -- this should never be empty.. safety net
        if {![info exists scanlist(scanlist)]} { set scanlist(scanlist) "" }

        # -- send to arm:scan only after all client /WHO responses have returned
        foreach i $scanlist(scanlist) {
                lassign $i nick ident ip host xuser rname
                set rname [list $rname]
                arm:debug 3 "arm:raw:endofwho: sending args to arm:scan: nick: $nick -- ident: $ident -- ip: $ip -- host: $host -- xuser: $xuser -- rname: [join [join $rname]]"
                arm:scan [list $nick] $ident $ip $host $xuser $rname
        }
}


# ---- enable & disable mode 'secure' on the fly

# -- manual set of +D
# - let the ops do the rest (ie. voicing existing users if they also set +m)
proc arm:modeadd:D {nick uhost hand chan mode target} {
        global arm botnick
        if {([string tolower $chan] != [string tolower $arm(cfg.chan.auto)]) || ($nick == $botnick)} { return; }
        arm:debug 0 "arm:modeadd:D: mode: $mode in $chan, enabled mode 'secure'"
        set arm(mode) "secure"
        arm:reply pub $chan "changed mode to: secure"
        # -- start '/names -d' timer
        # -- kill any existing arm:secure timers
	foreach utimer [utimers] {
		set thetimer [lindex $utimer 1]
		if {$thetimer != "arm:secure"} { continue; }
		arm:debug 1 "arm:raw:endofnames: killing arm:secure utimer: $utimer"
		killutimer [lindex $utimer 2] 
	}
        arm:secure
}

# -- manual set of -D
proc arm:moderem:D {nick uhost hand chan mode target} {
        global arm botnick
        if {([string tolower $chan] != [string tolower $arm(cfg.chan.auto)]) || ($nick == $botnick)} { return; }
        arm:debug 0 "arm:moderem:D: mode: $mode in $chan, disabled mode 'secure' (enabled mode 'on')"
        set arm(mode) "on"
        arm:reply pub $chan "changed mode to: on"
        # -- kill any existing arm:secure timers
	foreach utimer [utimers] {
		set thetimer [lindex $utimer 1]
		if {$thetimer != "arm:secure"} { continue; }
		arm:debug 1 "arm:raw:endofnames: killing arm:secure utimer: $utimer"
		killutimer [lindex $utimer 2] 
	}
}

# -- auto server set of +d (still hidden users available via /names -d <chan>)
proc arm:modeadd:d {nick uhost hand chan mode target} {
        global arm moded botnick
        if {([string tolower $chan] != [string tolower $arm(cfg.chan.auto)]) || ($nick == $botnick)} { return; }
        # -- notify chan of hidden clients
        arm:debug 0 "arm:modeadd:d: mode: $mode in $chan, hidden clients -- /quotes names -d $chan"
        arm:reply notc @$chan "info: hidden clients -- /quote names -d $chan"
        
        # -- disable floodnet processing
        arm:debug 0 "arm:modeadd:d: mode: $mode in $chan, disabling floodnet processing on joins (for $arm(cfg.time.moded) secs or until mode -d)"
        set moded($chan) 1
        # -- unset the array on configured time
        utimer $arm(cfg.time.moded) "catch { unset moded($chan) }"
}

# -- auto server set of -d (all hidden users left, kicked, voiced or opped)
proc arm:moderem:d {nick uhost hand chan mode target} {
        global arm moded botnick
        # -- notify chan of visible clients
        if {([string tolower $chan] != [string tolower $arm(cfg.chan.auto)]) || ($nick == $botnick)} { return; }
        arm:debug 0 "arm:moderem:d: mode: $mode in $chan, all hidden clients now visiable"
        arm:reply notc @$chan "info: all hidden clients now visible."
        
        # -- re-enable floodnet processing
        if {[info exists moded($chan)]} {
                arm:debug 0 "arm:moderem:d: mode: $mode in $chan, re-enabling floodnet detection on joins"
                unset moded($chan)
        }
}


# --- manage the global banlist by removing those that actually get banned
proc arm:modeadd:b {nick uhost hand chan mode target} {
        global arm gblist
        if {([string tolower $chan] != [string tolower $arm(cfg.chan.auto)])} { return; }
        set mask $target
        # -- remove mask from global kicklist if exists
	set pos [lsearch $gblist $mask]
	if {$pos != -1} {
		# -- nick within
		set gblist [lreplace $gblist $pos $pos]
		if {$gblist == ""} { unset gblist }
	}
}

# --- remove a nickname from scanlist (previously scanned clients under mode 'secure'), if someone voices them manually
proc arm:modeadd:v {nick uhost hand chan mode target} {
        global arm scanlist
        if {([string tolower $chan] != [string tolower $arm(cfg.chan.auto)])} { return; }
	# -- remove nick from scanlist(paranoid) if exists
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $target]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}
	# -- remove nick from scanlist(nicklist) if exists (list of those to scan from /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $target]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
}


arm:debug 0 "\[@\] Armour: loaded raw functions."
# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-14_scan.tcl
#
# core list scanner (triggered by /who responses)
#

proc arm:scan {nick ident ip host xuser rname} {
	global userdb arm botnick
	global full fullname chanban
	global wline bline regex exempt adapt
	# -- hit counts
	global hits
	global chanban time ltypes
	global adaptn adaptni adaptnir adapti adaptir adaptr adaptnr
	global whois time
	# -- global kick and banlist
	global gblist gklist
	# -- track the floodnet occurance
	global floodnet
	# -- track nicks on the host
	global hostnicks
	
	# -- NEW SINCE LOCKOUT
	global jointime newjoin override
		
	
	global botnet-nick

	# arm:debug 1 "arm:scan: ------------------------------------------------------------------------------------"

	set nick [join $nick]

	# -- halt if me
	if {$nick == $botnick} { 
		arm:debug 1 "arm:scan: halting: $nick (user is me)"
		arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
	 	return; 
	}
	
	set start [clock clicks]

	# -- setup nuhr var for regex matching
	arm:debug 3 "arm:scan: received: nick: [join $nick] -- ident: $ident -- host: $host -- ip: $ip -- rname: $rname"

	set nuhr "[join $nick]!$ident@$host/$rname"
	set uhost "$ident@$host"
	# -- add rname to newjoin(nick) array
	if {[info exists newjoin($nick)]} { set newjoin($nick) "$newjoin($nick) $rname" }
	
	# -- what chan for modes and kicks?
	set fullscan 0
	if {[info exists full]} {
		# -- full channel scan under way
		set fullscan 1
		set list [lsort [array names full]]
		foreach channel $list {
			set split [split $channel ,]
			if {[lindex [split $channel ,] 0] == "chanscan"} {
				set chan [lindex [split $channel ,] 1]
				break;
			} 
		}
	} else { set chan $arm(cfg.chan.auto); }
	
	
	# -- is full channel scan underway?
	if {$fullscan} {
		incr full(usercount,$chan)
	}
	
	set pushop 0
	
	if {$xuser == 0} { 
		arm:debug 2 "arm:scan: scanning: $nuhr (not logged in)"
		set auth 0 
	} else {
		if {![userdb:isLogin $nick]} {
			# -- begin autologin sequence
			set user [userdb:uline:get user xuser $xuser]
			if {$user != ""} {
	
				# -- check no-one else is logged in on this user
				set lognick [userdb:uline:get curnick xuser $xuser]
				if {$lognick == ""} {
	
					# -- begin autologin
					putloglev d * "arm:scan: autologin begin for $user ($nick!$uhost)"
					userdb:uline:set curnick $nick user $user
					userdb:uline:set curhost $uhost user $user
					userdb:uline:set lastseen [unixtime] user $user
					# -- get automode
					set automode [userdb:uline:get automode user $user]
					foreach i [channels] {
						switch -- $automode {
							0	{ continue; }
							1	{ pushmode $i +v $nick; }
							2	{ pushmode $i +o $nick; }
							default { continue; }
						}
					}
					flushmode $i
					userdb:reply notc $nick "autologin successful.";
				}
			
			}
		}
		arm:debug 2 "arm:scan: scanning: $nuhr (xuser: $xuser)"
		set auth 1
	}
			
	# -- dnsbl scans?
	set dnsbl $arm(cfg.dnsbl)
	
	# -- default to on
	set ipscan 1
	set portscan 1
	
	# -- turn off dnsbl & ports scans if resolved ident?
	if {!$arm(cfg.scans.all)} {
		if {[string match "~*" $ident]} { set dnsbl 1; set portscan 1 } else { set dnsbl 0; set portscan 0 }
	} else { set dnsbl $dnsbl }
	
	# -- turn off dnsbl & port scans if umode +x or service
	if {$ip == "127.0.0.1" || $ip == "0::"} { set dnsbl 0; set portscan 0; set ipscan 0 }
	
	# -- turn off dnsbl & port scans if rfc1918 ip space
	# -- beware of ipv6
	if {![string match "*:*" $ip]} {
		if {[cidr:match $ip "10.0.0.0/8"]} { set dnsbl 0; set portscan 0 }
		if {[cidr:match $ip "172.16.0.0/12"]} { set dnsbl 0; set portscan 0 }
		if {[cidr:match $ip "192.168.0.0/16"]} { set dnsbl 0; set portscan 0 }
	} else { set dnsbl 0; set portscan 0 }

	# -- turn off dnsbl scans if host "undernet.org"
	if {$host == "undernet.org"} { set dnsbl 0; set portscan 0; set ipscan 0 }
	
	# -- regexp scans?
	set regexp 1
	
	set asn ""
	set country ""
		
	# -- safety net
	if {![info exists exempt($nick)]} { set exempt($nick) 0 }
	
	arm:debug 2 "arm:scan: pre-vars: dnsbl: $dnsbl ipscan: $ipscan portscan: $portscan auth: $auth exempt: $exempt($nick)"
	
	set hit 0

	# -- do floodnet detection
	# - only if not chanscan & not secure mode
	if {![info exists full(chanscan,$chan)] && $arm(mode) != "secure"} {
		set hand [nick2hand $nick]
		set hit [arm:check:floodnet $nick $uhost $hand $chan $xuser $rname]
	}
	
	# -- START LOCKOUT
	if {0} {
	
	if {!$exempt($nick) && !$fullscan} {
	
		arm:debug 2 "arm:scan: adaptive regex matching beginning for user: $nick!$ident@$host"
	
		# -- do some basic nick!ident checks against adapt regex, prior to /WHO
		# -- we want this to be a fast way to match floodnet joins
	
		# -- join flood rate  
		set joins [lindex [split $arm(cfg.adapt.rate) :] 0]
		set secs [lindex [split $arm(cfg.adapt.rate) :] 1]
		set retain [lindex [split $arm(cfg.adapt.rate) :] 2]
			
		# ---- adaptive regex types
		set types $arm(cfg.adapt.types.who)

		# ---- adaptive regex types
		# -- if mode is 'secure', match nick and ident, else only match rname (nick & ident were probably alrady done during client /join)
		# if {$arm(mode) == "secure"} { set types "n i r" } else { set types "r" }
		
		# -- if mode is 'secure', combine /join and /who match types
		if {$arm(mode) == "secure"} { set types "$arm(cfg.adapt.types.join) $arm(cfg.adapt.types.who)" } else { set types $arm(cfg.adapt.types.who) }
	 

		# -- build adaptive regex's
		# -- only build what is required
						
		# -- nickname
		if {[lsearch $types "n"] != -1} { set nregex  [split "^[join [arm:regex:adapt "$nick"]]$"] }
		# -- ident
		if {[lsearch $types "i"] != -1} { set iregex [split "^[join [arm:regex:adapt "$ident"]]$"] }
		# -- nick!ident
		if {[lsearch $types "ni"] != -1} { set niregex [split "^[join [arm:regex:adapt "$nick!$ident"]]$"] }
		# -- nick!ident/rname
		if {[lsearch $types "nir"] != -1} { set nirregex [split "^[join [arm:regex:adapt "$nick!$ident/$rname"]]$"] }
		# -- ident!rname
		if {[lsearch $types "ir"] != -1} { set irregex [split "^[join [arm:regex:adapt "$ident/$rname"]]$"] }
		# -- realname
		if {[lsearch $types "r"] != -1} { set rregex [split "^[join [arm:regex:adapt "$rname"]]$"] }
		# -- nick/rname
		if {[lsearch $types "nr"] != -1} { set nrregex [split "^[join [arm:regex:adapt "$nick/$rname"]]$"] }  
				 

		# -- copy newjoin array to mlist array
		foreach client [array names newjoin] {
			set mlist($client) 1
		}
		
		# -- use hit var to stop unnecessary looping if client already got hit
		set hit 0
		
		foreach type $types {

			# -- allow for all permutations
			switch -- $type {
				n { set array "adaptn"; set exp $nregex }
				ni { set array "adaptni"; set exp $niregex }
				nir { set array "adaptnir"; set exp $nirregex }
				nr { set array "adaptnr"; set exp $nrregex }
				i { set array "adapti"; set exp $iregex }
				ir { set array "adaptir"; set exp $irregex }
				r { set array "adaptr"; set exp $rregex }
			}
			
			# -- get longtype from ltypes array
			set ltype $ltypes($type)
			
			arm:debug 3 "arm:scan: checking for adaptive regex type array: $array exp: [join $exp]"
			
			if {!$hit} {
				
				if {![info exists [subst $array]($exp)]} {
					# -- no counter being tracked for this nickname pattern
					set [subst $array]($exp) 1
					arm:debug 4 "arm:scan: unsetting track array for $ltype pattern in $secs secs: [join $exp]"
					utimer $secs "arm:adapt:unset $ltype [split $exp]"
				} else {
					# -- existing counter being tracked for this nickname pattern
					arm:debug 2 "arm:scan: increasing counter for $ltype pattern: [join $exp]"
					incr [subst $array]($exp)
				
					upvar 0 $array value
					set count [subst $value($exp)]

					if {$count >= $joins} {
						# -- flood join limit reached! -- take action
						arm:debug 1 "arm:scan: adaptive ($ltype) regex joinflood detected (joincount: $count): $nick!$uhost"
						set hit 1
						# -- store the active floodnet
						set floodnet($chan) 1
							
						# -- hold pattern for longer after initial join rate hit
						set secs $retain
							
						# -- we need a way of finding the previous nicknames on this pattern...              
						set klist ""
						set blist ""
						arm:debug 3 "arm:raw:join: mlist: [array names mlist]"
						foreach newuser [array names mlist] {
							# set uh [getchanhost $newuser $chan]
							if {![info exists newjoin($newuser)]} {
								set uh [getchanhost $newuser $chan]
								set newjoin($newuser) $uh
							} else {
									set uh [lindex $newjoin($newuser) 0]
							}
							# -- we now have the rname after /who
							set realname [lrange $newjoin($newuser) 1 end]
							set i [lindex [split $uh @] 0]
							set h [lindex [split $uh @] 1]
							switch -- $type {
								n	{ set match $newuser }
								ni	{ set match "$newuser!$i" }
								nir	{ set match "$newuser!$i@$h/$realname" }
								nr	{ set match "$newuser/$realname" }
								i	{ set match $i }
								ir	{ set match "$i/$realname" }
								r	{ set match $realname }
							}
							
							if {[regexp -- [join $exp] $match]} {
								arm:debug 4 "arm:raw:join: pre-record regex match: [join $exp] against string: $match"
								# -- only include the pre-record users
								# -- add this nick at the end
								if {$newuser == $nick} { continue; }
								# -- weed out people who rejoined from umode +x
								arm:debug 4 "arm:raw:join: checking if recent umode+x"
								if {[info exists setx($newuser)]} { continue; }
								arm:debug 1 "arm:raw:join: pre-record! adaptive ($ltype) regex joinflood detected: [join $newuser]!$uh"
								set mask "*!*@$h"
								# -- add mask to ban queue if doesn't exist and wasn't recently banned
								if {[lsearch $blist $mask] == -1} { lappend blist $mask }
								if {[lsearch $gblist $mask] == -1} { lappend gblist $mask }
								if {![info exists chanban($chan,$mask)]} {
									set chanban($chan,$mask) 1
									utimer $arm(cfg.time.newjoin) "arm:unset:chanban $chan $mask"
								}
								# -- add nick to kick queue
								if {[lsearch $klist $newuser] == -1} { lappend klist $newuser }
								if {[lsearch $gklist $newuser] == -1} { lappend gklist $newuser }
								catch { unset mlist($newuser) }
								# -- add any other nicknames on this host to kickqueue
								foreach hnick $hostnicks($h) {
									if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
									if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
								}
							}
						}
					
						# -- insert current user
						set host [lindex [split $uhost @] 1]
						arm:debug 4 "arm:raw:join: adding *!*@$host to banlist"
						if {[lsearch $blist "*!*@$host"] == -1} { lappend blist "*!*@$host" }
						if {[lsearch $gblist "*!*@$host"] == -1} { lappend gblist "*!*@$host" }
						
						arm:debug 4 "arm:raw:join: adding nick: $nick to kicklist"
						if {$klist != ""} { lappend klist $nick } else { set klist $nick }
						if {[lsearch $gklist $nick] == -1} { lappend gklist $nick }
						# -- add any other nicknames on this host to kickqueue
						foreach hnick $hostnicks($host) {
							if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
							if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
						}					 
						

						
						# -- automatic blacklist entries
						if {$arm(cfg.auto.black)} {

						 foreach ban $blist {
							 # -- don't need a mask
							 set thost [lindex [split $ban "@"] 1]
	
							 if {[regexp -- $arm(cfg.xhost) $thost -> tuser]} {
								 # -- user is umode +x, add a 'user' blacklist entry instead of 'host'
								 set method "user"
								 set equal $tuser
							 } else {
								 # -- add a host blacklsit entry
								 set method "host"
								 set equal $thost
							 }

							 if {![info exists bline($method,$equal)] && ![info exists wline($method,$equal)]} {
			 					 # -- add automatic blacklist entry

								 set reason "(auto) join flood detected"
								 set line "B::$method:$equal:[unixtime]:Armour:B:1-1-1:0:$reason"
								 arm:debug 1 "arm:kickban: adding auto blacklist line: $line"

								 # -- add the list entry
								 set id [arm:db:add $line]
							 }
							 # -- end of exists
						 }
						 # -- foreach blist ban
					 }						
					 # -- end of automatic blacklist entries
							
						arm:debug 1 "arm:scan: adaptive regex join flood detected (\002type:\002 $ltype \002count:\002 $count \002list:\002 $klist)"
					}
					# -- end of flood detection
						
					# -- clear existing unset utimers for this pattern
					arm:adapt:preclear [split $exp]
						
					# -- setup timer to clear adaptive pattern count
					arm:debug 3 "arm:scan: unsetting in $secs secs: $ltype [join $exp] $count"
					utimer $secs "arm:adapt:unset $ltype [split $exp]"
				
				}
				# -- end if exists
			}
			# -- end of hit (prevents unnecessary loops)
		}
		# -- end foreach types
	} else { arm:debug 1 "arm:scan: user was exempt from secondary (rname) adaptive regex scans" }
	# -- end of exempt
	
	}
	# --- END LOCKOUT
	
	# -- prevent further scans if adaptive regex matched
	if {$hit} {
		set runtime [arm:runtime $time($nick)]

		# -- no matches at all.... 
		# arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
		arm:debug 1 "arm:scan: adaptive regex matching complete... hit found! -- $runtime"
		arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
		catch { unset exempt($nick) }
                # -- cleanup vars
                arm:scan:cleanup $nick
		return;
	}

	arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"

	# --- WHITELIST scans (user, host, country, asn)
	arm:debug 1 "arm:scan: beginning whitelist scans"
	
	# -- sort whitelists (we do this so we can issue scans in a logical order)
	set wsort(list) [lsort [array names wline]]
	set wuser ""
	set whost ""
	set wregex ""
	set wcountry ""
	set wasn ""
	set wchan ""
	set wrname ""

	foreach white $wsort(list) {
		set line [split $white ,]
		set wtype [lindex $line 0]
		set value [lindex $line 1]
		switch -- $wtype {
			user	{ append wuser "$white " }
			host	{ append whost "$white " }
			regex	{ append wregex "$white " }
			country	{ append wcountry "$white " }
			asn	{ append wasn "$white " }
			chan	{ append wchan "$white " }
			rname	{ append wrname "$white " }
		}
	}
	if {$wuser != "" } { arm:debug 5 "arm:scan: sorted whitelist: user: $wuser" }
	if {$whost != "" } { arm:debug 5 "arm:scan: sorted whitelist: host: $whost" }
	if {$wrname != "" } { arm:debug 5 "arm:scan: sorted whitelist: rname: $wrname" }
	if {$wregex != "" } { arm:debug 5 "arm:scan: sorted whitelist: regex: $wregex" }
	if {$wcountry != ""}  { arm:debug 5 "arm:scan: sorted whitelist: country: $wcountry" }
	if {$wasn != "" } { arm:debug 5 "arm:scan: sorted whitelist: asn: $wasn" }
	if {$wchan != "" } { arm:debug 5 "arm:scan: sorted whitelist: chan: $wchan" }
	
	# -- begin whitelist: user (cservice username)
	if {$auth && $wuser != ""} {
		foreach entry $wuser {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			if {[string tolower $xuser] == [string tolower $value] || [string match [string tolower $value] [string tolower $xuser]]} {
				# -- match: take whitelist action!
				set id [arm:get:id white $method $value]
				set runtime [arm:runtime $start]
				set action [arm:list2action $wline($method,$value)]
				set reason [join [lrange [split $wline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: whitelist matched $xuser: wline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set mode [arm:wlist2mode $wline($method,$value)]

				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
				arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id white $method $value])
				# -- pass join arguments to other standalone scripts, if configured
				arm:integrate $nick $uhost [nick2hand $nick] $chan 1
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
				
			}
		}
	}
	# -- end of user whitelist
	
	# -- begin whitelist: host
	set match 0
	if {$whost != ""} {
		foreach entry $whost {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			# -- check against host
			if {[string match [string tolower $value] [string tolower $host]]} { set hit "host"; set match 1; set res "$host" }
			# -- check against user@host
			if {[string match [string tolower $value] [string tolower "$ident@$host"]]} { set hit "user@host"; set match 1; set res "$ident@$host" }
			# -- check against nick!user@host
			if {[string match [string tolower $value] [string tolower "$nick!$ident@$host"]]} { set hit "nick!user@host"; set match 1; set res "$nick!$ident@$host" }
			# -- IP scans? (only if IP is known and not rfc1918)
			if {$ipscan && !$match} {
				# -- check against IP
				if {[string match $value $ip]} { set hit "ip"; set match 1; set res $ip }
				# -- check IP against CIDR
				if {[regexp -- {/} $value] && !$match} { 
					# -- check if cidr belonged to hostmask
					if {[regexp -- {@} $value]} {
						set umask [lindex [split $value @] 0]
						set block [lindex [split $value @] 1]
						if {[cidr:match $ip $block]} {
							# -- CIDR block matched, check ident
							if {[string match [string tolower $umask] [string tolower $ident]]} { set hit "cidr mask"; set match 1; set res "$ident@$ip" } \
							elseif {[string match [string tolower $umask] [string tolower "$nick!$ident"]]} { set hit "cidr mask"; set match 1; set res "$nick!$ident@$ip" }
						}
					} elseif {[cidr:match $ip $value]} {
						set hit "cidr"; set match 1; set res $ip 
					}
				}
			}
			# -- end ipscan
			if {$match} {
				# -- match: take whitelist action!
				set id [arm:get:id white $method $value]
				set runtime [arm:runtime $start]
				set action [arm:list2action $wline($method,$value)]
				set reason [join [lrange [split $wline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: whitelist matched $res ($hit): wline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set mode [arm:wlist2mode $wline($method,$value)]
				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
				arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action\002: $action \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id white $method $value])
				# -- pass join arguments to other standalone scripts, if configured
				arm:integrate $nick $uhost [nick2hand $nick] $chan 1
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			 
			} 
		}
	}
	# -- end of host whitelist
	
	# -- begin whitelist: rname
	if {$wrname != ""} {
		foreach entry $wrname {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			if {[string tolower $rname] == [string tolower $value] || [string match [string tolower $value] [string tolower $rname]]} {
				# -- match: take whitelist action!
				set id [arm:get:id white $method $value]
				set runtime [arm:runtime $start]
				set action [arm:list2action $wline($method,$value)]
				set reason [join [lrange [split $wline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: whitelist matched $rname: wline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set mode [arm:wlist2mode $wline($method,$value)]
				
				# -- csc2learn
				if {${botnet-nick} == "shield" && ![onchan $nick #csc2learn]} { return; }
				# -- end csc2learn

				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
				arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id white $method $value])
				# -- pass join arguments to other standalone scripts, if configured
				arm:integrate $nick $uhost [nick2hand $nick] $chan 1
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
				
			}
		}
	}
	# -- end of rname whitelist
	
	# -- begin whitelist: regex
	if {$wregex != ""} {
		foreach entry $wregex {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			set id $value
			set exp [split $regex($id)]
			#set exp [join $exp]
			# putloglev d * "arm:scan: whitelist matching $nuhr against regex: [join $exp]"
			if {[regexp -- [join $exp] $nuhr]} {
				# -- match: whitelist entry, take action!
				set id [arm:get:id white $method $value]
				set runtime [arm:runtime $start]
				set action [arm:list2action $wline($method,$value)]
				set reason [join [lrange [split $wline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: whitelist matched $nuhr: regex($id) id: $id -- [join $exp] -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set mode [arm:wlist2mode $wline($method,$value)]
				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
				arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id white $method [join $exp]])
				# -- pass join arguments to other standalone scripts, if configured
				arm:integrate $nick $uhost [nick2hand $nick] $chan 1
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;

			}
		}
	}
	# -- end of regex whitelist

	
	# -- begin whitelist: country
	if {$wcountry != "" && $ipscan} { 
		# -- get country
		set country [geo:ip2country $ip]
		foreach entry $wcountry {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			if {[string tolower $country] == [string tolower $value]} {
				# -- match: take whitelist action!
				set runtime [arm:runtime $start]
				set action [arm:list2action $wline($method,$value)]
				set reason [join [lrange [split $wline($method,$value) :] 9 end]]
				arm:debug 2 "arm:scan: whitelist matched $country: wline($method,$value) -- taking action! ($runtime)"
				set mode [arm:wlist2mode $wline($method,$value)]
				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
				arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id white $method $value])
				# -- pass join arguments to other standalone scripts, if configured
				arm:integrate $nick $uhost [nick2hand $nick] $chan 1
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
	}
	# -- end country whitelist

	# -- begin whitelist: ASN
	if {$wasn != "" && $ipscan} { 
		# -- get ASN
		set asn [geo:ip2asn $ip]
		foreach entry $wasn {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			if {$asn == $value} {
				# -- match: take whitelist action!
				set id [arm:get:id white $method $value]
				set runtime [arm:runtime $start]
				set action [arm:list2action $wline($method,$value)]
				set reason [join [lrange [split $wline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: whitelist matched $asn: wline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set mode [arm:wlist2mode $wline($method,$value)]
				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
				arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id white $method $value])
				# -- pass join arguments to other standalone scripts, if configured
				arm:integrate $nick $uhost [nick2hand $nick] $chan 1
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
	}
	# -- end ASN  

	# -- begin whitelist: chan
	if {$wchan != "" || $wchan == ""} { 
		# -- match against common channels of mine here, do /WHOIS externally for rest
		foreach entry $wchan {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: whitelist scanning: wline($method,$value)"
			# -- ensure valid chan of mine
			if {[validchan $entry]} {
				if {[onchan $nick $entry]} {
					# -- match: take whitelist action!
					set id [arm:get:id white $method $value]
					set runtime [arm:runtime $start]
					set action [arm:list2action $wline($method,$value)]
					set reason [join [lrange [split $wline($method,$value) :] 9 end]]
					arm:debug 1 "arm:scan: whitelist matched $asn: wline($method,$value) id: $id -- taking action! ($runtime)"
					arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
					set mode [arm:wlist2mode $wline($method,$value)]
					if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
					arm:report white $nick "Armour: $nick!$ident@$host whitelisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
					# -- incr statistics
					incr hits([arm:get:id white $method $value])
					# -- pass join arguments to other standalone scripts, if configured
					arm:integrate $nick $uhost [nick2hand $nick] $chan 1
					# -- cleanup vars
					arm:scan:cleanup $nick
					return;
				}
			}
			# -- end validchan
		}
		# -- end foreach
		# -- at this point, all other whitelists are complete, we can send '/WHOIS nick' to remote bot for further checks (namely, badchan)
		# -- check if remote /WHOIS lookups?
		if {$arm(cfg.whois)} {
			if {$arm(cfg.whois.remote)} {
				# -- remote (botnet) /whois
				if {![islinked $arm(cfg.bot.remote.whois)]} { 
					arm:debug 0 "arm:scan: ERROR: remote /WHOIS scan bot $arm(cfg.bot.remote.whois) is not linked!"
				} else {
					arm:debug 2 "arm:scan: sending remote /WHOIS chan lookup to $arm(cfg.bot.remote.whois) on [join $nick]"
					putbot $arm(cfg.bot.remote.whois) "scan:whois $nick $chan"
				}
			} else {
					# -- do local lookup
					arm:debug 2 "arm:scan: sending local /WHOIS chan lookup on [join $nick]"
					set whois(bot,$nick) 0
					set whois(chan,$nick) $chan
					putserv "WHOIS [join $nick]"
			}
		}
		# -- end of /whois
	}
	# -- end chan 
	
	# ---- END WHITELIST SCANS
	
	arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
	
	# --- BLACKLIST scans (user, host, country, asn)
	arm:debug 1 "arm:scan: beginning blacklist scans"
	
	# -- sort blacklists (we do this so we can issue scans in a logical order)
	set bsort(list) [lsort [array names bline]]
	set buser ""
	set bhost ""
	set bregex ""
	set bcountry ""
	set basn ""
	set bchan ""
	set brname ""
	
	foreach black $bsort(list) {
		set line [split $black ,]
		set btype [lindex $line 0]
		set value [lindex $line 1]
		switch -- $btype {
			user	{ append buser "$black " }
			host	{ append bhost "$black " }
			regex	{ append bregex "$black " }
			country	{ append bcountry "$black " }
			asn	{ append basn "$black " }
			rname	{ append brname "$black " }
		}
	}
	# -- removed chan from sorting, it's done elsewhere (from remote bot or raw chanlist reply)
	#chan	{ append bchan "$black " }
	if {$bchan != ""} { arm:debug 5 "arm:scan: sorted blacklist: chan: $bchan" }
	if {$buser != ""} { arm:debug 5 "arm:scan: sorted blacklist: user: $buser" }
	if {$bhost != ""} { arm:debug 5 "arm:scan: sorted blacklist: host: $bhost" }
	if {$brname != ""} { arm:debug 5 "arm:scan: sorted blacklist: rname: $brname" }
	if {$bregex != ""} { arm:debug 5 "arm:scan: sorted blacklist: regex: $bregex" }
	if {$bcountry != ""} { arm:debug 5 "arm:scan: sorted blacklist: country: $bcountry" }
	if {$basn != ""} { arm:debug 5 "arm:scan: sorted blacklist: asn: $basn" }
	
	# -- begin blacklist: user (cservice username)
	if {$auth && $buser != ""} {
		foreach entry $buser {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: blacklist scanning: bline($method,$value)"
			if {[string tolower $xuser] == [string tolower $value] || [string match [string tolower $value] [string tolower $xuser]]} {
				# -- match: take blacklist action!
				set id [arm:get:id black $method $value]
				set runtime [arm:runtime $start]
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: blacklist matched $xuser: bline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set string "Armour: blacklisted -- $xuser (reason: $reason) \[id: $id\]"
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
				arm:report black $chan "Armour: $nick!$ident@$host blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id black $method $value])
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
	}
	# -- end of user blacklist
	
	# -- begin blacklist: host
	if {$bhost != ""} {
		foreach entry $bhost {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: blacklist scanning: bline($method,$value)"
			# -- check against host
			if {[string match [string tolower $value] [string tolower $host]]} { set hit "host"; set match 1; set res "$host" }
			# -- check against user@host
			if {[string match [string tolower $value] [string tolower "$ident@$host"]]} { set hit "user@host"; set match 1; set res "$ident@$host" }
			# -- check against nick!user@host
			if {[string match [string tolower $value] [string tolower "$nick!$ident@$host"]]} { set hit "nick!user@host"; set match 1; set res "$nick!$ident@$host" }      
			# -- IP scans? (only if IP is known and not rfc1918)
			if {$ipscan && !$match} {
				# -- check against IP
				if {[string match $value $ip]} { set hit "ip"; set match 1; set res $ip }
				# -- check IP against CIDR
				if {[regexp -- {/} $value] && !$match} {
					# -- check if cidr belonged to hostmask
					if {[regexp -- {@} $value]} {
						set umask [lindex [split $value @] 0]
						set block [lindex [split $value @] 1]
						if {[cidr:match $ip $block]} {
							# -- CIDR block matched, check ident
							if {[string match [string tolower $umask] [string tolower $ident]]} { set hit "cidr mask"; set match 1; set res "$ident@$ip" } \
							elseif {[string match [string tolower $umask] [string tolower "$nick!$ident"]]} { set hit "cidr mask"; set match 1; set res "$nick!$ident@$ip" }
						}
					} elseif {[cidr:match $ip $value]} {
							set hit "cidr"; set match 1; set res $ip 
					}
				}
			}
			# -- end ipscan
			
			if {$match} {
				# -- match: take blacklist action!
				set id [arm:get:id black $method $value]
				set runtime [arm:runtime $start]
				set limit [lindex [split $bline($method,$value) :] 7]
				if {$limit != "1-1-1"} { continue; }
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: blacklist matched $res ($hit): bline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set string "Armour: blacklisted -- $value (reason: $reason) \[id: $id\]"
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
				arm:report black $chan "Armour: $nick!$ident@$host blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id black $method $value])
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			} 
		}
	}
	# -- end of host blacklist
	
	# -- begin blacklist: rname
	if {$brname != ""} {
		foreach entry $brname {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: blacklist scanning: bline($method,$value)"
			if {[string tolower $rname] == [string tolower $value] || [string match [string tolower $value] [string tolower $rname]]} {
				# -- match: take blacklist action!
				set id [arm:get:id black $method $value]
				set runtime [arm:runtime $start]
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: blacklist matched $rname: bline($method,$value) id: $id -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set string "Armour: blacklisted -- $value (reason: $reason) \[id: $id\]"
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
				arm:report black $chan "Armour: $nick!$ident@$host blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id black $method $value])
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
	}
	# -- end of rname blacklist
	
	# -- begin blacklist: regex
	if {$bregex != ""} {
		foreach entry $bregex {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: blacklist scanning: bline($method,$value)"
			set id $value
			set exp [split $regex($id)]
			#set exp [join $exp]
			# putloglev d * "arm:scan: blacklist matching $nuhr against regex: [join $exp]"
			if {[regexp -- [join $exp] $nuhr]} {    
				# -- match: blacklist entry, take action!
				set runtime [arm:runtime $start]
				set limit [lindex [split $bline($method,$value) :] 7]
				if {$limit != "1-1-1"} { continue; }
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: blacklist matched $nuhr: regex($id) id: $id -- [join $exp] -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set string "Armour: blacklisted (reason: $reason) \[id: $id\]"
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
				arm:report black $chan "Armour: $nick!$ident@$host blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 [join $exp] \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id black $method [join $exp]])
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
	}
	# -- end of regex blacklist

	
	# -- begin blacklist: country
        # -- only hit if allowed
        set chit 1
        if {($arm(cfg.country.ident) == 0) && ![string match "~*" $ident]} { set chit 0 }
        if {$chit} {
		if {$bcountry != "" && $ipscan} {
			# -- set country
			if {$country == ""} { set country [geo:ip2country $ip] }
			foreach entry $bcountry {
				set line [split $entry ,]
				set method [lindex $line 0]
				set value [lindex $line 1]
				arm:debug 5 "arm:scan: blacklist scanning: bline($method,$value)"
				if {[string tolower $country] == [string tolower $value]} {
					# -- match: take blacklist action!
					set id [arm:get:id black $method $value]
					set runtime [arm:runtime $start]
					set reason [join [lrange [split $bline($method,$value) :] 9 end]]
					arm:debug 1 "arm:scan: blacklist matched $country: bline($method,$value) id: $id -- taking action! ($runtime)"
					arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
					set string "Armour: blacklisted -- $country (reason: $reason) \[id: $id\]"
					# -- truncate reason for X bans
					if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
					arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
					arm:report black $chan "Armour: $nick!$ident@$host blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $country \002reason:\002 $reason)"
					# -- incr statistics
					incr hits([arm:get:id black $method $value])
					# -- cleanup vars
					arm:scan:cleanup $nick
					return;
				}
			}
		}
	}
	# -- end country blacklist

	# -- begin blacklist: asn
	if {$basn != "" && $ipscan} { 
		# -- set asn
		if {$asn == ""} { set asn [geo:ip2asn $ip] }
		foreach entry $basn {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			arm:debug 5 "arm:scan: blacklist scanning: bline($method,$value)"
			if {$asn == $value} {
				# -- match: take blacklist action!
				set id [arm:get:id black $method $value]
				set runtime [arm:runtime $start]
				set reason [join [lrange [split $bline($method,$value) :] 9 end]]
				arm:debug 1 "arm:scan: blacklist matched $asn: bline($method,$value) -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set string "Armour: blacklisted -- AS$asn (reason: $reason) \[id: $id\]"
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
				arm:report black $chan "Armour: $nick!$ident@$host blacklisted (\002id:\002 $id \002type:\002 $method \002value:\002 $asn \002reason:\002 $reason)"
				# -- incr statistics
				incr hits([arm:get:id black $method $value])
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
	}
	# -- end asn blacklist

	# -- blacklist: chan
	# we don't do local blacklist checks because we assume that the bot does not sit in these common chans
	# wait for /WHOIS response we did in whitelist check (from remote bot, or locally as configured)
	# -- end of chan blacklist
	
	# ---- END OF BLACKLIST SCANS
	
	# -- dnsbl checks
	if {$arm(cfg.dnsbl) && $dnsbl} {
	
	# -- check if remote scans?
	if {$arm(cfg.dnsbl.remote)} {
		# -- remote (botnet) dnsbl scan
		if {![islinked $arm(cfg.bot.remote.dnsbl)]} { 
			arm:debug 0 "arm:scan: ERROR: remote dnsbl scan bot $arm(cfg.bot.remote.dnsbl) is not linked!"
		} else {
			arm:debug 2 "arm:scan: sending remote dnsbl scan to $arm(cfg.bot.remote.dnsbl)"
			putbot $arm(cfg.bot.remote.dnsbl) "scan:dnsbl $ip $host $nick!$ident@$host $chan"
		}
        } elseif {![string match "*:*" $ip]} {
        # -- dnsbl checks (if not IPv6)
		arm:debug 2 "arm:scan: scanning for dnsbl match: $ip (host: $host)"
		# -- get score
		set response [arm:rbl:score $ip]
		set ip [lindex $response 0]
		set response [join $response]
		set score [lindex $response 1]
		if {$ip != $host} { set dst "$ip ($host)" } else { set dst $ip }
		if {$score > 0} {
			# -- match found!
			set match 1
			set rbl [lindex $response 2]
			set desc [lindex $response 3]
			set info [lindex $response 4]
			if {[join $info] == "NULL"} { set info "" } else { set info [join $info] }
	
			# dnsbl match! ... take action!
	 
			set runtime [arm:runtime $start]
			
			# -- white dns list / black?
			set white 0; set black 0;
			if {$score > 0} { set dnslist "black"; set dnsshort "bl"; set black 1 } else { set dnslist "white"; set dnsshort "wl"; set white 1}
			
			arm:debug 1 "arm:scan: dns$dnsshort match found ($runtime) for $host: $response"
			arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
			
			if {$white} {
				set mode [arm:wlist2mode $wline($method,$value)]
				if {$mode != ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) == "secure"} { arm:voice $chan $nick }
			} else {
				set string "Armour: DNSBL blacklisted -- (ip: $ip rbl: $rbl desc: $desc info: $info)"
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "$string"
			}
			arm:report $dnslist $chan "Armour: DNS[string toupper $dnsshort] match found on $nick!$ident@$host (\002ip:\002 $ip \002rbl:\002 $rbl \002desc:\002 $desc \002info:\002 $info)"
			# -- cleanup vars
			arm:scan:cleanup $nick
			return;    
		} else {
			# -- no match found
			arm:debug 1 "arm:scan: no dnsbl match found for $host"
		}
	}
	# -- end of local scan
	}
	# -- end of dnsbl  
		
	# -- port scanner (if configured, and IP known)
	if {$arm(cfg.portscan) && $portscan} {
	
		# -- check if remote scans?
		if {$arm(cfg.portscan.remote)} {
			# -- remote (botnet) dnsbl scan
			if {![islinked $arm(cfg.bot.remote.port)]} { 
				arm:debug 0 "arm:scan: ERROR: remote port scan bot $arm(cfg.bot.remote.port) is not linked!"
			} else {
				arm:debug 1 "arm:scan: sending remote port scan to $arm(cfg.bot.remote.port)"
				putbot $arm(cfg.bot.remote.port) "scan:port $ip $host $nick!$ident@$host $chan"
			}
		} else {
			# -- local port scan
			arm:debug 1 "arm:scan: executing port scanner: $ip (host: $host)"

			# -- new additions
			set openports [arm:port:scan $ip]

			# -- hit if sshd is open and identd is closed
		
			# -- minimum number of open ports before action
			set min $arm(cfg.portscan.min)
			set portlist [split $openports " "]
			# -- divide list length by two as each has two args
			set portnum [expr [llength $portlist] / 2]

			# -- not null if any open ports
			if {$openports != "" && $portnum >= $min} {
				# -- insecure host (install identd) -- take action!
				set runtime [arm:runtime $start]
				arm:debug 1 "arm:scan: insecure host (host: $host ip: $ip) -- taking action! ($runtime)"
				arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
				set string $arm(cfg.portscan.reason)
				# -- truncate reason for X bans
				if {[string tolower $arm(cfg.ban)] == "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
				arm:kickban $nick $chan *!~*@$host $arm(cfg.ban.time) "$string"
				arm:report black $chan "Armour: $nick!$ident@$host insecure host (\002open ports:\002 $openports \002reason:\002 install identd)"
				# -- cleanup vars
				arm:scan:cleanup $nick
				return;
			}
		}
		# -- end local port scan
	}
	# -- end port scanner
 
	
	set runtime [arm:runtime $start]

	# -- no matches at all.... 
	# arm:debug 2 "arm:scan: ------------------------------------------------------------------------------------"
	arm:debug 1 "arm:scan: no matches (whitelist/dnswl/blacklist/portscan/dnsbl) found against $nuhr (xuser: $xuser) -- $runtime"
	arm:debug 1 "arm:scan: ------------------------------------------------------------------------------------"
	
	
	# -- continue for further scans before voicing (paranoid mode?)
	arm:scan:continue $nick $ident $ip $host $xuser $rname $chan
		
	return;

}

# -- continue further scans before voicing
# -- paranoid mode? :>
proc arm:scan:continue {nick ident ip host xuser rname chan} {

        arm:debug 1 "arm:scan:continue: started"

        global arm scanlist
        global exempt fullname
        global hostnicks ipnicks paranoid

        set legit 0; set voice 0; set hasscore 0;

        if {![info exists scanlist(paranoid)]} { set scanlist(paranoid) "" }

        if {$arm(mode) == "secure"} {
                arm:debug 1 "arm:scan:continue: mode:secure"

                # -- get the signon & idle time from remote /whois
                set paranoid(coro,[join $nick]) [info coroutine]

                putquick "WHOIS $nick $nick"
                # -- yield the results
                set result [yield]

                lassign [join $result] idle signon
                set signago [expr [clock seconds] - $signon]

                # -- count clients on this host
                if {![info exists hostnicks($host)]} {
                        set hostnicks($host) $nick
                        set hostcount 1
                } else {
                        set hostcount [llength $hostnicks($host)]
                }
                # -- count clients on this IP
                if {![info exists ipnicks($ip)]} {
                        set ipnicks($ip) $nick
                        set ipcount 1
                } else {
                        set ipcount [llength $ipnicks($ip)]
                }

                arm:debug 4 "arm:scan:continue: result nick: $nick -- idle: $idle -- signon: $signon -- signago: $signago -- hostnicks: $hostcount -- ipcount: $ipcount"
                arm:debug 4 "arm:scan:continue: hostnicks($host): $hostnicks($host)"
                arm:debug 4 "arm:scan:continue: ipnicks($ip): $ipnicks($ip)"

                # -- make this configurable later (see below)
                set manual 1; set voice 0; set black 0; set kb 0;

                # -- check trakka database (if plugin loaded)
                set score 0
                if {[info command trakka:score] != ""} {
                        # -- calculate score
                        set score [trakka:score $nick "$ident@$host" $xuser]
                        arm:debug 1 "arm:scan:continue: total trakka score for $nick!$ident@$host is: $score"
                }

                # -- check for: new server connections (ie. connection in last 10 secs)
                if {$signago < $arm(cfg.paranoid.signon)} {
                        if {$score == 0} {
                                arm:debug 0 "arm:scan:continue: no score & freshly connected client joined $chan (signago: $signago) -- \002floodbot?\002"

                                # ---- decide what to do (this should be configurable)
                                set manual 1; set voice 0; set black 0; set kb 0;
                                # -- manual intervention
                                if {$manual} {
                                        arm:reply notc @$chan "Armour: $nick!$ident@$host waiting manual action (recent signon) -- /quote names -d $chan"
                                        # -- maintain a list so we don't scan this client again
                                        lappend scanlist(paranoid) $nick
                                }
                                # -- kickban?
                                if {$kb} {

                                }
                                # -- blacklist?
                                if {$black} {

                                }
                        } else {
                                # -- recent signon, but they have a score
                                set voice 1
                        }
                        # -- end of score

                } else {
                        # -- signon time acceptable

                        # -- voice if score >0
                        if {$score > 0} { set voice 1 }

                        # -- check for clones based on IP/host (ie. 2 or more)
                        # -- ensure: IP clones for umode +x clients and services aren't counted
                        if {($hostcount >= $arm(cfg.paranoid.clone) || $ipcount >= $arm(cfg.paranoid.clone)) && ($ip != "127.0.0.1" || $ip != "0::")} {
                                # -- express the highest
                                if {$hostcount >= $ipcount} { set highest "$hostcount hosts" } else { set highest "$ipcount ips" }
                                # ---- decide what to do (this should be configurable)
                                set manual 1; set black 0; set kb 0;

                                arm:debug 4 "arm:scan:continue: hostcount: $hostcount -- ipcount: $ipcount"

                                # -- manual intervention if not scoring
                                if {$manual && !$voice} {
                                        arm:reply notc @$chan "Armour: $nick!$ident@$host waiting manual action (clone count: $highest) -- /quote names -d $chan"
                                        # -- maintain a list so we don't scan this client again
                                        lappend scanlist(paranoid) $nick
                                }
                                # -- kickban?
                                if {$kb} {

                                }
                                # -- blacklist?
                                if {$black} {

                                }
                        } else {
                                # -- signon time ok, no clones
                                # -- voice the client
                                set legit 1; set voice 1
                        }
                }

        } else {
                # -- mode secure not on
                # -- do nothing here.
                set legit 1
        }

        if {$legit} {
                # -- pass join arguments to other standalone scripts, if configured
                arm:integrate $nick "$ident@$host" [nick2hand $nick] $chan 0
        }
        if {$voice} {
                # -- voice the guy, provided they're not voiced by now
                if {![isvoice $nick $chan]} { arm:voice $chan $nick }
        }

        catch { unset paranoid(coro,$nick) }
        # -- cleanup vars
        # -- leave the nick in scanlist(paranoid) -- (so we don't keep scanning them)
        arm:scan:cleanup $nick 1

}



arm:debug 0 "\[@\] Armour: loaded scanner."





# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-15_floodnet.tcl
#
# dynamic floodnet detection
# 

proc arm:check:floodnet {nick uhost hand chan {xuser ""} {rname ""}} {
	global arm botnick full adapt chanban
	global setx time ltypes
	global adaptn adaptni adaptnir adapti adaptir adaptr adaptnr
	global exempt override 
	global newjoin jointime
	# -- track nicknames on a host
	global hostnicks
	# -- fline is a bline (blacklist entry) with a non-default flood limit
	global fline
	# -- flud array holds counters for a fline pattern
	global flud
	# -- expose global klist and blist to arm:flud:queue to attempt stacked bans during flood
	global gklist gblist
	# -- expose kick reasons (cumulative patterns)
	global kreason
	# -- track a floodnet underway
	global floodnet
	
        global tslist
        set tslist ""

	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]
	
	arm:debug 3 "arm:check:floodnet: nick: $nick -- rname: $rname "
	
	arm:debug 3 "arm:check:floodnet: received: nick: [join $nick] -- ident: $ident -- host: $host -- hand: $hand -- chan: $chan -- xuser: $xuser -- rname: $rname"
	
	if {![info exists hostnicks($host)]} { set hostnicks($host) $nick }
	
	# -- reorder newjoin list in chronological order
	foreach ts [array names jointime] {
		lappend tslist $ts
	}
	# -- tslist containing nicknames, ordered by time they joined
	set tslist [lsort -increasing $tslist]
	
	set joinlist ""
	foreach ts $tslist {
		# -- only append nick if not already in the list
		#if {[lsearch $joinlist $jointime($ts)] == -1} {
		#	lappend joinlist $jointime($ts)
		#}
		lappend joinlist $jointime($ts)
	}
	set joinlist [join $joinlist]
	
	arm:debug 3 "arm:check:floodnet: re-ordered newcomer (newjoin) list by jointime: [join $joinlist]"
	
	# -- do some basic nick!ident checks against adapt regex, prior to /WHO
	# -- we want this to be a fast way to match floodnet joins
	# -- ie. do these first without waiting for a response with realname
	
	# -- join flood rate  
	set joins [lindex [split $arm(cfg.adapt.rate) :] 0]
	set secs [lindex [split $arm(cfg.adapt.rate) :] 1]
	set retain [lindex [split $arm(cfg.adapt.rate) :] 2]
	
	# -- build types for join if 'xuser' is not set (send after /who from arm:scan)
	if {$xuser == ""} {
		# ---- adaptive regex types
		# -- match nickname, and ident
		set prefix "join"
		arm:debug 4 "arm:check:floodnet: running floodnet detection against $nick after /join"
		set types $arm(cfg.adapt.types.join)
	} else {
		# -- send from arm:scan after /who
		# -- can include rname
		set prefix "who"
		arm:debug 4 "arm:check:floodnet: running floodnet detection against $nick from arm:scan after /who"
		set types $arm(cfg.adapt.types.who)
		
	
	}
	
	# -- if mode is 'secure', combine /join and /who match types (as we didn't see the /join because of chanmode +D)
	if {$arm(mode) == "secure"} { set types "$arm(cfg.adapt.types.join) $arm(cfg.adapt.types.who)" }
	   
	# -- build adaptive regex's
	# -- only build what is required
					
	# -- nickname
	if {[lsearch $types "n"] != -1} { set nregex  [split "^[join [arm:regex:adapt "$nick"]]$"] }
	# -- ident
	if {[lsearch $types "i"] != -1} { set iregex [split "^[join [arm:regex:adapt "$ident"]]$"] }
	# -- nick!ident
	if {[lsearch $types "ni"] != -1} { set niregex [split "^[join [arm:regex:adapt "$nick!$ident"]]$"] }
	# -- nick!ident/rname
	if {[lsearch $types "nir"] != -1} { set nirregex [split "^[join [arm:regex:adapt "$nick!$ident/$rname"]]$"] }
	# -- ident!rname
	if {[lsearch $types "ir"] != -1} { set irregex [split "^[join [arm:regex:adapt "$ident/$rname"]]$"] }
	# -- realname
	if {[lsearch $types "r"] != -1} { set rregex [split "^[join [arm:regex:adapt "$rname"]]$"] }
	# -- nick/rname
	if {[lsearch $types "nr"] != -1} { set nrregex [split "^[join [arm:regex:adapt "$nick/$rname"]]$"] } 		
	
	
	# -- use hit var to stop unnecessary looping if client already got hit
	set hit 0
	set complete 0
	set processed 1
	
	# -- kicklist & banlist
	set klist ""
	set blist ""
	
	# ---- ADAPTIVE DETECTION
	# -- (automatic regex generation)
	set clength [llength $types]
			
	foreach type $types {
		switch -- $type {
			n { set array "adaptn"; set exp $nregex }
			ni { set array "adaptni"; set exp $niregex }
			nir { set array "adaptnir"; set exp $nirregex }
			nr { set array "adaptnr"; set exp $nrregex }
			i { set array "adapti"; set exp $iregex }
			ir { set array "adaptir"; set exp $irregex }
			r { set array "adaptr"; set exp $rregex }
		}
		
		# -- get longtype string from ltypes array
		set ltype $ltypes($type)
		
		arm:debug 4 "arm:check:floodnet: (adaptive -- $prefix) looping: type: $type ltype: $ltype exp: [join $exp]"
		
		# -- setup array?
		
		if {!$hit} {
	
			arm:debug 4 "arm:check:floodnet: (adaptive -- $prefix) checking array: [subst $array]([join $exp])"
			
			if {![info exists [subst $array]($exp)]} {
				# -- no counter being tracked for this nickname pattern
				set [subst $array]($exp) 1
				arm:debug 3 "arm:check:floodnet: (adaptive -- $prefix) no existing track counter: unsetting track array for $ltype pattern in $secs secs: [join $exp]"
				utimer $secs "arm:adapt:unset $ltype [split $exp]"
			} else {
				# -- existing counter being tracked for this nickname pattern
				arm:debug 2 "arm:check:floodnet: (adaptive -- $prefix) existing track counter: increasing for $ltype pattern: [join $exp]"
				incr [subst $array]($exp)
			
				upvar 0 $array value
				set count [subst $value($exp)]
	
				if {$count >= $joins} {
					# -- flood join limit reached! -- take action
					arm:debug 1 "\002arm:check:floodnet: (adaptive -- $prefix) adaptive ($ltype) regex joinflood detected: $nick!$uhost\002"
					# -- store the active floodnet
					set floodnet($chan) 1
					
					set matched 1
						
					# -- hold pattern for longer after initial join rate hit
					set secs $retain
						
					# -- we need a way of finding the previous nicknames on this pattern...              
					#set klist ""
					#set blist ""
					arm:debug 3 "arm:check:floodnet: (adaptive -- $prefix) newcomer joinlist: $joinlist"
					foreach newuser $joinlist {
						if {![info exists newjoin($newuser)]} {
							set uh [getchanhost $newuser $chan]
							set newjoin($newuser) $uh
						} else {
							set uh [lindex $newjoin($newuser) 0]
						}
						set i [lindex [split $uh @] 0]
						set h [lindex [split $uh @] 1]
						switch -- $type {
							n { set match $newuser }
							i { set match $i }
							ni { set match "$newuser!$i" }
						}
						arm:debug 4 "arm:check:floodnet: (adaptive -- $prefix) attempting to find pre-record matches: type: $type match: $match exp: [join $exp]"
						if {[regexp -- [join $exp] $match]} {
							arm:debug 3 "arm:check:floodnet: (adaptive -- $prefix) pre-record regex match: [join $exp] against string: $match"
							# -- only include the pre-record users
							# -- add this nick at the end
							if {$newuser == $nick} { continue; }
							# -- weed out people who rejoined from umode +x
							arm:debug 4 "arm:check:floodnet: (adaptive -- $prefix) checking if recent umode+x"
							if {[info exists setx($newuser)]} { continue; }
							arm:debug 2 "\002arm:check:floodnet: (adaptive -- $prefix) pre-record! adaptive ($ltype) regex joinflood detected: [join $newuser]!$uh\002"
							set mask "*!*@$h"
							# -- add mask to ban queue if doesn't exist and wasn't recently banned by me
							if {[lsearch $blist $mask] == -1 && ![info exists chanban($chan,$mask)]} {
								# -- add to queue
								lappend blist $mask
								# -- remember
								set chanban($chan,$mask) 1
								utimer $arm(cfg.time.newjoin) "arm:unset:chanban $chan $mask"
							}
							# -- add mask to global ban queue if not in already
							if {[lsearch $gblist $mask] == -1} { lappend gblist $mask }
							# -- add nick to kick queue
							if {[lsearch $klist $newuser] == -1} { lappend klist $newuser }
							if {[lsearch $gklist $newuser] == -1} { lappend gklist $newuser }
							# -- add any other nicknames on this host to kickqueue
							foreach hnick $hostnicks($h) {
								if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
								if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
							}
						}
					}
	
					# -- insert current user
					arm:debug 4 "arm:check:floodnet: (adaptive -- $prefix) adding nick: [join $nick] to kicklist"
	
					
					if {[lsearch $klist $nick] == -1} { lappend klist $nick }
					if {[lsearch $gklist $nick] == -1} { lappend gklist $nick }
					# -- add any other nicknames on this host to kickqueue
					foreach hnick $hostnicks($host) {
						if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
						if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
					}
					
					# set host [lindex [split $uhost @] 1]
					arm:debug 4 "arm:check:floodnet: (adaptive -- $prefix) adding *!*@$host to banlist"
					if {$blist == ""} { set blist "*!*@$host" } else {
						# -- add to end, not to front
						if {[lsearch $blist "*!*@$host"] == -1} { lappend blist "*!*@$host" }
					}
					if {[lsearch $gblist "*!*@$host"] == -1} { lappend gblist "*!*@$host" }
					
	
					# -- send kicks and bans at the end
						
					arm:debug 2 "\002arm:check:floodnet: (adaptive -- $prefix) adaptive regex join flood detected (type: $ltype count: $count list: $klist)\002"
					set hit 1
				}
				# -- end of flood detection
					
				# -- clear existing unset utimers for this pattern
				arm:adapt:preclear [split $exp]
					
				# -- setup timer to clear adaptive pattern count
				arm:debug 3 "arm:check:floodnet: (adaptive -- $prefix) unsetting in $secs secs: $ltype [join $exp] $count"
				utimer $secs "arm:adapt:unset $ltype [split $exp]"
	
			}
			# -- end if exists
			
			# -- prevent unnecessary looped scans
			incr $processed
			if {($processed >= $clength) || $hit} { set complete 1 }
			
		}
		# -- end of if hit
	
	} 
	# -- end foreach types
	
	# ---- END OF ADAPTIVE DETECTION
	# -- (automatic regex generation)
	
	# ---- BEGIN CUMULATIVE REGEX MATCHES
	arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) beginning cumulative regex checks (floodnet detection)"
	
	#set host [lindex [split $uhost @] 1]
	
		
	foreach entry [array names fline] {
	
		# -- break out before we even begin if we've hit this client already
		# -- prevent unnecessary processing
		if {$hit} { break }
	
		set method [lindex [split $entry ,] 0]
		
		# -- fix strings that may have ',' in it by removing spaces aftersplit
		set rest [lrange [split $entry ,] 1 end]
		set equal [join $rest ,]
		set id [arm:get:id black regex $equal]
		
		arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) looping: fline($entry): method: $method value: $equal"
		
		# -- get joinflood limit values
		set limit [lindex $fline($method,$equal) 0]
		set reason [lrange $fline($method,$equal) 1 end]
		append reason " \[id: $id\]"
		set extlimit [split $limit "-"]
		set joins [lindex $extlimit 0]
		set secs [lindex $extlimit 1]
		set hold [lindex $extlimit 2]
		
		# -- we really only care about host and regex types
		
		if {$method == "host"} {
			# -- check if match nick
			if {[string tolower $equal] == $host || [string match [string tolower $equal] [string tolower $host]]} {
				# -- matched!
				arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host match: [join $equal] against string: [join $nick]!$uhost"
				if {![info exists $flud($equal)]} {
					# -- no such tracking array exists for this host/mask
					arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host: no tracking array exists: flud($equal) -- created."
					set flud($equal) 1
					# -- unset after timeout
					utimer $secs "arm:flud:unset [split $equal]"
					
				} else {
						# -- existing tracking array, increase counter
						incr flud($equal)
						arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host: existing tracking array count flud($equal): $flud($equal)"
						set count $flud($equal)
						if {$count < $joins} {
							# -- breach not met
							arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host: breach not yet met -- increased flud($equal) counter."
							# -- clear existing unset utimers for this value
							arm:flud:preclear $equal
					
							# -- setup timer to clear adaptive pattern count
							arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host: unsetting in $secs secs: flud($equal)"
							# -- unset after timeout
							utimer $secs "arm:flud:unset [split $equal]"
							
						} else {
								# -- joinflood breach!
								incr flud($equal)
								# -- store the active floodnet
								set floodnet($chan) 1
								
								set hit 1
								# -- clear existing unset utimers for this value
								arm:flud:preclear [split $equal]
								# -- setup timer to clear adaptive pattern count
								arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host: unsetting in extended $hold secs: flud($equal)"
								# -- unset after timeout
								utimer $hold "arm:flud:unset [split $equal]"    
								
								arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host breach met! client found: [join $nick]!$uhost -- finding pre-record clients..."   
	
								foreach client $joinlist {
									# -- add this nick at the end
									if {$client == $nick} { continue; }
									if {[string match [string tolower $equal] [string tolower $newjoin($client)]]} {
										set thehost [lindex [split $newjoin($client) @] 1]
										set mask "*!*@$thehost"
										arm:debug 3 "\002arm:check:floodnet: (cumulative -- $prefix) host pre-record client found: [join $client]!$newjoin($client)\002"
										# -- add client to kickban queue if doesn't exist
										if {[lsearch $klist $client] == -1} { lappend klist $client }
										if {[lsearch $gklist $client] == -1} { lappend gklist $client }
										# -- track kick reason
										set kreason($client) $reason
										# -- add any other nicknames on this host to kickqueue
										foreach hnick $hostnicks($thehost) {
											if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
											if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
										}
										# -- add mask to ban queue if doesn't exist and wasn't recently banned by me
										if {[lsearch $blist $mask] == -1} { lappend blist $mask }
										if {[lsearch $gblist $mask] == -1} { lappend gblist $mask }
										if {![info exists chanban($chan,$mask)]} {
											set chanban($chan,$mask) 1
											utimer $arm(cfg.time.newjoin) "arm:unset:chanban $chan $mask"
										}
									
									}
								}
								# -- add this client if doesn't exist
								if {[lsearch $klist [join $nick]] == -1} { lappend klist [join $nick] }
								if {[lsearch $gklist [join $nick]] == -1} { lappend gklist [join $nick] }
								# -- add any other nicknames on this host to kickqueue
								foreach hnick $hostnicks($host) {
									if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
									if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
								}
								
								set mask "*!*@$host"
								# -- track kick reason
								set kreason($nick) $reason
								# -- add mask to ban queue if doesn't exist
								if {[lsearch $blist $mask] == -1} { lappend blist $mask }
								if {[lsearch $gblist $mask] == -1} { lappend gblist $mask }
								
						}
						# -- end of joinflood breach by host
				}
			}
			# -- end of match
		}
		# -- end of host check
		
		if {$method == "regex"} {
			# -- check if match nick
			if {[regexp -- [split $equal] "[join $nick]!$uhost/$rname"] || [regexp -- [split $equal] $rname]} {
				# -- matched!
				arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) regex match: [join $equal] against string: [join $nick]!$uhost/$rname"
				if {![info exists flud($equal)]} {
					# -- no such tracking array exists for this host/mask
					arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) host: no tracking array exists: flud($equal) -- created."
					set flud($equal) 1
					# -- unset after timeout
					utimer $secs "arm:flud:unset [split $equal]"
					
				} else {
						# -- existing tracking array, increase counter
						incr flud($equal)
						arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) regex: existing tracking array count flud($equal): $flud($equal)"
						set count $flud($equal)
						if {$count < $joins} {
							# -- breach not met
							arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) regex: breach not yet met -- increased flud($equal) counter."
							# -- clear existing unset utimers for this value
							arm:flud:preclear [split $equal]
					
							# -- setup timer to clear adaptive pattern count
							arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) regex: unsetting in $secs secs: flud($equal)"
							# -- unset after timeout
							utimer $secs "arm:flud:unset [split $equal]"
							
						} else {
								# -- joinflood breach!
								set hit 1
								incr flud($equal)
								# -- store the active floodnet
								set floodnet($chan) 1
								# -- clear existing unset utimers for this value
								arm:flud:preclear [split $equal]
								# -- setup timer to clear adaptive pattern count
								arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) regex: unsetting in extended $hold secs: flud($equal)"
								# -- unset after timeout
								utimer $hold "arm:flud:unset [split $equal]"    
								
								arm:debug 3 "arm:check:floodnet: (cumulative -- $prefix) regex breach met! client found: [join $nick]!$uhost -- finding pre-record clients..."              
								# -- find the pre-record clients
								foreach client $joinlist {
									if {[regexp -- [join $equal] $newjoin($client)]} {
										# -- add this nick at the end
										if {$client == $nick} { continue; }
										arm:debug 3 "\002arm:check:floodnet: (cumulative -- $prefix) regex pre-record client found: [join $client]!$newjoin($client)\002"
										# -- add client to kickban queue if doesn't exist already
										if {[lsearch $klist $client] == -1} { lappend klist $client }
										if {[lsearch $gklist $client] == -1} { lappend gklist $client }
										set thehost [lindex [split $newjoin($client) @] 1]
										set mask "*!*@$thehost"
										# -- add any other nicknames on this host to kickqueue
										foreach hnick $hostnicks($thehost) {
											if {[lsearch $klist $hnick] == -1} { lappend klist $hnick }
											if {[lsearch $gklist $hnick] == -1} { lappend gklist $hnick }
										}
										# -- track kick reason
										set kreason($client) $reason
										# -- add mask to ban queue if doesn't exist and wasn't recently banned by me
										if {[lsearch $blist $mask] == -1} { lappend blist $mask }
										if {[lsearch $gblist $mask] == -1} { lappend gblist $mask }
										if {![info exists chanban($chan,$mask)]} {
											set chanban($chan,$mask) 1
											utimer $arm(cfg.time.newjoin) "arm:unset:chanban $chan $mask"
										}
									}
								}
								# -- add this client if doesn't exist already
								if {[lsearch $klist [join $nick]] == -1} { lappend klist [join $nick] }
								if {[lsearch $gklist [join $nick]] == -1} { lappend gklist [join $nick] }
								set mask "*!*@$host"
								# -- track kick reason
								set kreason($nick) $reason
								# -- add mask to ban queue if doesn't exist
								if {[lsearch $blist $mask] == -1} { lappend blist $mask }
								if {[lsearch $gblist $mask] == -1} { lappend gblist $mask }
								
						}
						# -- end of joinflood breach by regex
				}
			}
			# -- end of match
		}
		# -- end of regex check
		
	}
	# -- end foreach fline
	
	# ---- END CUMULATIVE REGEX MATCHES
	
	# -- automatic blacklist entries
	if {$arm(cfg.auto.black)} {
	
		foreach ban $blist {
			# -- don't need a mask
			set thost [lindex [split $ban "@"] 1]
	
			if {[regexp -- $arm(cfg.xhost) $thost -> tuser]} {
				# -- user is umode +x, add a 'user' blacklist entry instead of 'host'
				set method "user"
				set equal $tuser
			} else {
				# -- add a host blacklsit entry
				set method "host"
				set equal $thost
			}
	
			if {![info exists bline($method,$equal)] && ![info exists wline($method,$equal)]} {
				# -- add automatic blacklist entry
	
				set reason "(auto) join flood detected"
				set line "B::$method:$equal:[unixtime]:Armour:B:1-1-1:0:$reason"
				arm:debug 1 "arm:kickban: adding auto blacklist line: $line"
	
				# -- add the list entry
				set id [arm:db:add $line]
			}
			# -- end of exists
		}
		# -- foreach blist ban
	}						
	# -- end of automatic blacklist entries
	
	# -- process kicklist (klist) and banlist (blist)
	# -- for a more effective queue, this now happens on 1sec timer via arm:flud:queue procedure
	
	arm:debug 3 "arm:check:floodnet: ending procedure... hit=$hit"
	return $hit

};

# -- custom ban queue (and chammode -r to unlock chan when serverqueue is emptied)
# -- i've noticed that the eggdrop queues are too slow, and I need to try to stack modes wherever possible
proc arm:flud:queue {} {
	global arm
	# -- global banlist queue
	global gblist
	# -- global kicklist queue
	global gklist
	
	global floodnet
	global chanlock

	if {![info exists gblist]} { set gblist "" }
	
	arm:debug 5 "arm:flud:queue: global ban queue list: $gblist"
	
	set chan $arm(cfg.chan.auto)
	
	if {![info exists floodnet($chan)]} { set fludactive 0 } else { set fludactive 1 }
	
	set size [queuesize server]
	
	set lockdown 0
	
	if {$size >= 0 && $fludactive} {       
		# -- announce queue size if floodnet is active
		arm:debug 5 "arm:flud:queue: server queue size is >= 3 messages (size: $size)"
		if {![info exists chanlock($chan)]} { set lockdown 1 }
	}
	
	# -- process global ban queue if exists
	
	if {$gblist != ""} {
		arm:debug 1 "\002arm:flud:queue:\002 stacking ban modes for banlist: $gblist"
		set length [llength $gblist]
		while {$gblist != ""} {
			if {$lockdown && ![info exists chanlock($chan)]} {
				# -- safetey net in case + isn't included in the var
				if {![string match "+*" $arm(cfg.chanlock.mode)]} { set lockmode $arm(cfg.chanlock.mode) } else { set lockmode [string range $arm(cfg.chanlock.mode) 1 end] }
				# -- count the modes
				set mcount [string length $lockmode]   
				# -- subtract from the 6 stacked modes allowed  
				set bstack [expr 6 - $mcount]
				# -- concatenate the modes for stack
				#set modes "+$lockmode[string repeat "b" $bstack]"
				set modes  "+$lockmode[string repeat "b" $length]"
								
				arm:debug 1 "\002arm:flud:queue:\002 locking down chan $chan via chanmode $arm(cfg.chanlock.mode)"
				
				set chanlock($chan) 1
				# -- number of banmasks to include in stack (counting from 0)
				set num [expr 5 - $mcount]
				set blist [join [lrange $gblist 0 $num]]
				# -- unlock chan in N seconds (if serverqueue is cleared) - 20secs
				arm:flud:unlock $chan
				# -- prevent kicks from starting for 5 seconds after chanlock
				utimer 5 arm:flud:kick:queue
				
			} else {
				if {$length >= 6} { set modes "+bbbbbb" } else { set modes "+[string repeat "b" $length]" }
				set blist [join [lrange $gblist 0 5]]
				set num 5
			}
			arm:debug 1 "\002arm:flud:queue:\002 executing: MODE $chan $modes $blist"
			# -- putnow is instant
			# -- WARNING: it is *possible* for putnow to excess flood the bot
			putnow "MODE $chan $modes $blist"
			set gblist [lreplace $gblist 0 $num]
			
		}
		
		arm:debug 1 "arm:flud:queue: server queue size is empty, unset floodnet track in $arm(cfg.chanlock.time) secs"
		utimer $arm(cfg.chanlock.time) "catch { unset floodnet($chan) }"
	
	} 
		
	# -- use miliseconds
	after $arm(cfg.queue.flud) arm:flud:queue
	
}

# -- before we unlock (chanmode -r) the chan, we have a delay to be sure
proc arm:flud:unlock {chan} {
	global arm chanlock floodnet
	
	# -- let's check the server queue again and ensure it's empty
	if {![info exists floodnet($chan)]} { set fludactive 0 } else { set fludactive 1 }
	set size [queuesize server]
	
	# -- only unlock if queue is empty and flood is not active
	if {$size == 0 && !$fludactive} { 
		if {[info exists chanlock($chan)]} {
			# -- unlock channel
			regsub {\+} $arm(cfg.chanlock.mode) {-} unlock
			arm:debug 1 "arm:flud:unlock: unlocking chan $chan via chanmode $unlock"
			putquick "MODE $chan $unlock"
			catch { unset chanlock($chan) }
			catch { unset floodnet($chan) }
		}
	} else {
		# -- add another N seconds to the delay and check again
		utimer $arm(cfg.chanlock.time) "arm:flud:unlock $chan"
	}
}

# -- including kicks in main ban queue slows the bans down -- do these less often
proc arm:flud:kick:queue {} {
	global arm
	# -- global global kicklist queue
	global gklist
	# -- kick reason
	global kreason

	if {![info exists gklist]} { set gklist "" }
	
	arm:debug 5 "arm:flud:kick:queue: gklist: $gklist"
	
	set chan $arm(cfg.chan.auto)
	
	if {$gklist != ""} {     
		# -- default reason
		set reason "join flood detected"   
		# -- kick users
		foreach client $gklist {
			arm:debug 3 "arm:flud:kick:queue: kicking kicklist: [join $gklist]"
			if {[info exists kreason($client)]} { 
				# -- safety net
				if {$kreason($client) != ""} {
					set reason $kreason($client)
					unset kreason($client) 
				}
			}
			putquick "KICK $chan $client :Armour: $reason"
			# putkick $chan $client "Armour: $reason"
			
			# putkick $chan [join $gklist ,] "Armour: join flood detected" 
			#set gklist ""
		}
	}
	
	set gklist ""
	
	# -- we don't need to restart this0
	#utimer 5 arm:flud:kick:queue
	
}

arm:debug 0 "\[@\] Armour: loaded floodnet detection."





# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-16_db.tcl
#
# database file support procedures
#

# type:id:method:value:timestamp:modifby:action:limit:hits:reason
proc arm:db:add {string} {
	global arm userdb
	global uline wline bline regex
	global fline
	
	set list [split $string :]	
	lassign $list type id method value timestamp modifby action limit hits
	set reason [join [lrange $list 9 end]]
	
	# -- add it to sqlite if necessary
	# -- how do we ensure the ID's are in sync with those entries in memory?
	# -- always do SQL insert first and use that last row ID
	if {$userdb(method) == "sqlite"} {
		# -- sqlite3 database
		::armdb::db_connect
		set db_value [::armdb::db_escape $value]
		set db_modifby [::armdb::db_escape $modifby]
		set db_reason [::armdb::db_escape $reason]
		::armdb::db_query "INSERT INTO entries (list, type, value, timestamp, modifby, action, \"limit\", hits, reason) \
			VALUES ('$type', '$method', '$db_value', '[clock seconds]', '$db_modifby', '$action', '$limit', '$hits', '$db_reason')" 
		set id [::armdb::db_last_rowid]
		::armdb::db_close
	} else {
		# -- otherwise increment from memory
		set id [arm:get:nextID]
	}
	# -- reform the string
	set string "$type:$id:$method:$value:$timestamp:$modifby:$action:$limit:$hits:$reason"
	
	if {$type == "W"} {
		# -- whitelist
		set llist "whitelist"
		set array "wline"
		if {$method == "regex"} { set wline(regex,$id) $string; set regex($id) $value } \
		else { set wline($method,$value) $string }
		
	} elseif {$type == "B"} {
		# -- blacklist
		set llist "blacklist"
		set array "bline"
		if {$limit != "1-1-1" && ($method == "regex" || $method == "host")} { set fline($method,$value) "$limit [join [lrange $list 8 end]]" } 
		if {$method == "regex"} { set bline(regex,$id) $string; set regex($id) $value } \
		else { set bline($method,$value) $string }
		
	} else { 
		# -- this shouldn't happen, but return an erroneous ID if it does
		return -1 
	}
	
	arm:debug 1 "arm:db:add: added $value to $llist $method array ([llength [array names $array]] $llist entries in total)"
	
	# -- return the ID
	return $id

}

# type:id:method:value:timestamp:modifby:action:limit:hits:reason
proc arm:db:load {} {
	global arm userdb 
	global wline bline regex fline hits
	arm:debug 2 "userdb:db:load: started"

	# -- flush existing from memory
	catch { unset wline }
	catch { unset bline }
	catch { unset regex }
	catch { unset fline }
	catch { unset hits }
	
	# -- check the database method
	if {$userdb(method) == "file"} {
		# -- flat file DB
		set listfile $arm(cfg.db.file)
		if {![file exists $listfile]} { exec touch $listfile }
		set fd [open $listfile r]
		set data [read $fd]
		set data [split $data "\n"]
		close $fd
		set src "file line"
		
	} elseif {$userdb(method) == "sqlite"} {
		# -- sqlite3 database
		::armdb::db_connect			
		set result [::armdb::db_query "SELECT id, list, type, value, timestamp, modifby, action, \"limit\", hits, reason FROM entries"]
		::armdb::db_close
		set data [list]
		set src "sql row"
		foreach row $result {
			lassign $row id type method value timestamp modifby action limit hitnum
			set reason [lrange $row 9 end]
			set line "$type:$id:$method:$value:$timestamp:$modifby:$action:$limit:$hitnum:[join $reason]"
			lappend data $line
		}
	} else {
		# -- uh oh... no such method
		putloglev d * "arm:db:load: userdb(method) not set correctly (file|sqlite)"
		die "error: userdb(method) not set correctly (file|sqlite)"
	}
	
	# -- read each line
	foreach line $data {
		#arm:debug 4 "arm:db:load: $src: $line"
		set list [split $line :]
		if {[lindex $list 0] == "#" || [lindex $list 0] != "B" && [lindex $list 0] != "W" || $list == ""} { continue; }
		
		lassign $list type id method value timestamp modifby action limit hitnum
		set hits($id) $hitnum
		set reason [join [lrange $list 9 end]]
		set dbline "$type:$id:$method:$value:$timestamp:$modifby:$action:$limit:$hitnum:[join $reason]"

		arm:debug 5 "arm:db:load: src: $src -- method: $method -- value: $value"

		if {$type == "W"} { 
			if {$method == "regex"} { set wline(regex,$id) $dbline; set regex($id) $value } else {
				set wline($method,$value) $dbline 
			}
		}
		if {$type == "B"} { 
			if {$method == "regex"} { 
				set bline(regex,$id) $dbline; set regex($id) $value 
				if {$limit != "1-1-1"} {
					# -- non-default join flood limit used
					# -- create separate array for faster floodnet detection
					set fline($method,$value) "$limit $reason"
				}
			} else {
				set bline($method,$value) $dbline
			}
		}

	}
	arm:debug 1 "arm:db:load: loaded [llength [array names wline]] whitelist and [llength [array names bline]] blacklist entries to memory"
}

# -- write list entries to file
proc arm:db:write {} {
	global arm userdb 
	global uline wline bline hits

	# -- only write to file if file method
	if {$userdb(method) == "file"} {
		set listfile $arm(cfg.db.file)
		
		catch { exec rm -rf $arm(cfg.db.file) }
		
		if {![file exists $listfile]} { set fd [open $listfile w] } \
		else { set fd [open $listfile a] }
		
		# -- print header
		puts $fd "# list:id:type:value:timestamp:modifby:action:limit:hits:reason"
		puts $fd "#"
		puts $fd "# lists: W (Whitelist), B (Blacklist)"
		puts $fd "# types: user, host, rname, regex, asn, country, chan"
		puts $fd "# actions: O (Op), V (Voice), A (Accept), B (KickBan)"
		puts $fd "# limit: joins:secs:hold (N joins in X seconds, and hold detection window for further Y seconds)"
		puts $fd "# hits: statistical hit count"
		puts $fd "#"
		
		# -- write in order of id's
		set list ""
		
		# -- whitelists
		foreach entry [array names wline] {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			set dbid [lindex [split $wline($entry) :] 1]

			# -- add leading zero's for proper sorting
			# -- allow for 99999 unique ID's with 4 x leading 0's
			set length [string length $dbid]
			set repeat [expr 5 - $length]
			set dbid "[string repeat 0 $repeat]$dbid"

			lappend list $dbid,wline,$entry
		}

		# -- blacklists
		foreach entry [array names bline] {
			set line [split $entry ,]
			set method [lindex $line 0]
			set value [lindex $line 1]
			set dbid [lindex [split $bline($entry) :] 1]

			# -- add leading zero's for proper sorting
			# -- allow for 99999 unique ID's with 4 x leading 0's
			set length [string length $dbid]
			set repeat [expr 5 - $length]
			set dbid "[string repeat 0 $repeat]$dbid"

			lappend list $dbid,bline,$entry
		}
		
		# -- sort in increasing order
		set list [lsort -increasing $list]
		
		arm:debug 5 "arm:db:write: full sorted list: $list"
		
		foreach entry $list {
				set line [split $entry ,]
				set dbid [lindex $line 0]
				set type [lindex $line 1]
				set method [lindex $line 2]
				set value [lindex $line 3]

				arm:debug 5 "arm:db:write: type: $type method: $method value: $value -> line: $line"

				if {$type == "wline"} {
						set list [split $wline($method,$value) :]
						if {[lindex $list 0] == "#" || [lindex $list 0] != "B" && [lindex $list 0] != "W" || $list == ""} { continue; }
						set type [lindex $list 0]
						set id [lindex $list 1]
						set method [lindex $list 2]
						set value [lindex $list 3]
						set timestamp [lindex $list 4]
						set modifby [lindex $list 5]
						set action [lindex $list 6]
						set limit [lindex $list 7]
						if {![info exists hits($id)]} { set hits($id) 0 }
						set hitnum $hits($id)
						set reason [join [lrange $list 9 end]]
						set dbline "$type:$id:$method:$value:$timestamp:$modifby:$action:$limit:$hitnum:[join $reason]"
						puts $fd $dbline;
				} else {
						set list [split $bline($method,$value) :]
						if {[lindex $list 0] == "#" || [lindex $list 0] != "B" && [lindex $list 0] != "W" || $list == ""} { continue; }
						set type [lindex $list 0]
						set id [lindex $list 1]
						set method [lindex $list 2]
						set value [lindex $list 3]
						set timestamp [lindex $list 4]
						set modifby [lindex $list 5]
						set action [lindex $list 6]
						set limit [lindex $list 7]/
						if {![info exists hits($id)]} { set hits($id) 0 }
						set hitnum $hits($id)
						set reason [join [lrange $list 9 end]]
						set dbline "$type:$id:$method:$value:$timestamp:$modifby:$action:$limit:$hitnum:[join $reason]"
						puts $fd $dbline;
				}

		}
		
		close $fd

		arm:debug 1 "arm:db:write: wrote [llength [array names wline]] whitelist and [llength [array names bline]] blacklist entries to file"

	} 
	# -- end of file method
	

	# -- we should clear existing timers (ie. if SAVE was called manually via command)
	arm:preclear:timer arm:db:write
	# -- start the timer again
	timer $arm(cfg.db.save) arm:db:write

}

# -- obtain list value
proc arm:db:get {item list source {silent ""}} {
	global arm userdb 
	global uline wline bline
	
	set itm [arm:getarg $item]
	
	if {[string index $list 0] == "w"} { set list "wline" } else { set list "bline" }
	
	# -- assume case in array is correct
	if {[info exists [subst $list]($source)]} {
		if {$list == "wline"} { set line $wline($source) } \
		else { set line $bline($source) }
		set list [split $line :]
		set result [lindex $list $itm]
		return $result;
	}

	# -- entry not found - perhaps incorrect array case?
	foreach entry [array names [subst $list]] {
		if {[string tolower $source] == [string tolower $entry]} {
			# -- found match
			if {$list == "wline"} { set line $wline($entry) } \
			else { set line $bline($entry) }
			set list [split $line :]
			set result [lindex $list $itm]
			return $result;    
		}
	}

}

# -- obtain ID of given list entry
proc arm:get:id {list method value} {
	global regex

	if {$method != "regex"} {

		return [arm:db:get id $list [join "$method $value" ,]]

	} else {
			# -- type is regex
			foreach pid [array names regex] {
				set pattern $regex($pid)
				if {$pattern == $value} { return $pid }
			}
	}

	# -- else, return 0 if no match found
	return 0;
}


# -- check which argument an item appears in the list line
proc arm:getarg {item} {
	switch -- $item {
		type		{ set arg 0 }
		id		{ set arg 1 }
		method		{ set arg 2 }
		value		{ set arg 3 }
		timestamp	{ set arg 4 }
		modifby		{ set arg 5 }
		timestamp	{ set arg 6 }
		limit		{ set arg 7 }
		hits		{ set arg 8 }
		reason		{ set arg 9 }
	}
}

proc arm:get:nextID {} {
	global wline bline
	global arm

	set dbid 0

	# -- get next available list id

	# -- whitelist
	foreach entry [array names wline] {
		set list [split $wline($entry) :]
		set id [lindex $list 1]
		if {$id > $dbid} { set dbid $id }
	}
	
	# -- blacklist
	foreach entry [array names bline] {
		set list [split $bline($entry) :]
		set id [lindex $list 1]
		if {$id > $dbid} { set dbid $id }
	}

	# -- safety net
	if {$dbid == "" || ![regexp {^\d+$} $dbid]} { set dbid 0 }

	# -- add one for next available
	set dbid [expr $dbid + 1]
	
	return $dbid
	
}

# -- return the list line for a given ID
proc arm:get:line {id} {
	# -- whitelists
	global wline
	foreach entry [array names wline] {
		set line [split $entry ,]
		set method [lindex $line 0]
		set value [lindex $line 1]
		set dbid [lindex [split $wline($entry) :] 1]
		if {$dbid == $id} { return $wline($entry) }
	}

	# -- blacklists
	global bline
	foreach entry [array names bline] {
		set line [split $entry ,]
		set method [lindex $line 0]
		set value [lindex $line 1]
		set dbid [lindex [split $bline($entry) :] 1]
		if {$dbid == $id} { return $bline($entry) }
	}
	
	# -- return "" if no match
	return;

}

arm:debug 0 "\[@\] Armour: loaded database functions."




# -- dns resolver with coroutines
#

# -- require dns from tcllib
package require dns

set dns(debug) 1
bind dcc n score { arm:coroexec arm:cmd:score }
bind dcc n lookup { arm:coroexec arm:cmd:lookup }

proc arm:cmd:score {hand idx text} {
	lassign $text ip type
	putlog "[arm:rbl:score $ip]"
}

proc arm:cmd:lookup {hand idx text} {
	lassign $text ip type
	putlog "lookup: [arm:dns:lookup $ip $type]"
}

proc arm:rbl:score {ip} {
	global rbls
	
	set start [clock clicks]

        # -- reverse the ip
        for {set i 0} {$i < 4} {incr i} {lappend rip [lindex [split $ip {.}] end-$i]}; set rip [join $rip {.}]

	set total 0
	set desc ""; set point ""; set info ""; set therbl "";
	foreach rbl [array names rbls] {
		set lookup "$rip.$rbl"
		set response [arm:dns:lookup $lookup A]
		if {$response == "error"} { continue; }
		# name 210.204.211.58.dnsbl.dronebl.org type TXT class IN ttl 300 rdlength 51 rdata {Automatically determined botnet IPs (experimental)} name 210.204.211.58.dnsbl.dronebl.org type A class IN ttl 300 rdlength 4 rdata 127.0.0.17
		#set info ""; set resp "";
		#regexp -- {type TXT class IN ttl \d+ rdlength \d+ rdata \{([^\}]+)\} name [^\s]+ type A class IN ttl \d+ rdlength \d+ rdata (.+)} $response -> info resp
		set desc [lindex $rbls($rbl) 0]
		set point [lindex $rbls($rbl) 1]
		set info [lindex $response 11]
		incr total [expr round($point)]
		set therbl $rbl
	}
	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"
	
	arm:debug 3 "arm:rbl:score: total score: $total rbl: $therbl desc: $desc info: $info (runtime: $runtime)"
	
	# {{+1.0 dnsbl.swiftbl.org SwiftRBL {{DNSBL. 80.74.160.3 is listed in SwiftBL (SOCKS proxy)}}} {+1.0 rbl.efnetrbl.org {Abusive Host} NULL}}

	set output [list]
	lappend output $ip
        lappend output "$point $therbl {$desc} {$info}"
        
	return $output
}

proc arm:dns:lookup {host {type ""}} {

	set start [clock clicks]
	
	# -- ensure type is uppercase
	set type [string toupper $type]
	if {$type == ""} { set type "A" }

	# -- perform lookup
	# arm:debug 3 "arm:dns:lookup: lookup: $host -type $type"
	set tok [::dns::resolve $host -type $type -command [info coroutine]]
	yield

	# -- get status (ok, error, timeout, eof)
	set status [::dns::status $tok]
	# putlog "status: $status"
	
	if {$status == "error"} {
		set error [::dns::error $tok]
		# arm:debug 3 "arm:dns:lookup: dns lookup error: $error"
		::dns::cleanup $tok
		set end [clock clicks]
		set runtime "[expr ($end-$start)/1000/1000.0] sec"
		arm:debug 3 "arm:dns:lookup: dns resolution failure for $host took $runtime"
		# -- return error
		return "error"
	} elseif {$status == "eof"} {
		# arm:debug 3 "arm:dns:lookup: dns eof"
		::dns::cleanup $tok
		# -- return error
		set end [clock clicks]
		set runtime "[expr ($end-$start)/1000/1000.0] sec"
		arm:debug 3 "arm:dns:lookup: dns resolution eof for $host took $runtime"
		return "error"

	} elseif {$status == "timeout"} {
		# arm:debug 3 "arm:dns:lookup: dns timeout"
		::dns::cleanup $tok
		# -- return error
		set end [clock clicks]
		set runtime "[expr ($end-$start)/1000/1000.0] sec"
		arm:debug 3 "arm:dns:lookup: dns resolution timeout for $host took $runtime"
		return "error"
	}
	
	# putlog "end of error checks"

	# -- fetch entire result
	set result [join [::dns::result $tok]]
	
	#  name google.com type TXT class IN ttl 2779 rdlength 82 rdata {v=spf1 include:_netblocks.google.com ip4:216.73.93.70/31 ip4:216.73.93.72/31 ~all}
	set typ [lindex $result 3]
	set class [lindex $result 5]
	set ttl [lindex $result 7]
	
	set resolve [lindex $result 11]

	# -- cleanup token
	::dns::cleanup $tok
	

	set end [clock clicks]
	set runtime "[expr ($end-$start)/1000/1000.0] sec"
	arm:debug 3 "arm:dns:lookup: dns resolution success for $host took $runtime"
	
	if {$type == "*"} { 
		# arm:debug 3 "arm:dns:lookup:  final result: $result"
		return $result
	} else {
		# arm:debug 3 "arm:dns:lookup: final result: $resolve"
		return $resolve
	}
}

proc bgerror {message} { 
 putloglev d * "\002(bgError)\002: \"$message\":" 
 foreach line [split $::errorInfo "\n"] { 
  putloglev d * "  $line" 
 } 
 putloglev d * "b(\002gError)\002: errorCode: $::errorCode" 
}

putlog "\[@\] Armour: loaded asynchronous dns resolver."
# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-18_support.tcl
#
# core script support functions
#

proc arm:listparse {list method value string} {

	global hits

	set result [split $string :]
	set id [lindex $result 1]
	set timestamp [lindex $result 4]
	set modifby [lindex $result 5]
	set action [lindex $result 6]
	# -- interpret action
	switch -- $action {
		O	{ set action "op" }
		V 	{ set action "voice" }
		B	{ set action "kickban" }
		A	{ set action "accept" }
	}
	set limit [lindex $result 7]
	set hitnum $hits($id)
	regsub -all {\-} $limit {:} limit
	
	set reason [join [lrange $result 9 end]]
	
	# -- send response
	if {$limit == "1:1:1"} {
		# -- no custom limit set
		return "\002list match:\002 ${list}list \002$method:\002 [lindex $value 0] (\002id:\002 $id \002action:\002 $action \002hits:\002 $hitnum \002added:\002 [userdb:timeago $timestamp] ago \002by:\002 $modifby \002reason:\002 $reason)" 
	} else {
		# -- custom limit set
		return "\002list match:\002 ${list}list \002$method:\002 [lindex $value 0] (\002id:\002 $id \002action:\002 $action \002hits:\002 $hitnum \002limit:\002 $limit \002added:\002 [userdb:timeago $timestamp] ago \002by:\002 $modifby \002reason:\002 $reason)" 
	}

}

proc arm:list2action {list} {
	set result [split $list :]
	set action [lindex $result 6]
	# -- interpret action
	switch -- $action {
		O	{ set action "op" }
		V 	{ set action "voice" }
		B	{ set action "kickban" }
		A	{ set action "accept" }
		D	{ set action "deny" }
	}
	return $action;
}

proc arm:wlist2mode {list} {
	set result [split $list :]
	set action [lindex $result 6]
	# -- interpret action
	switch -- $action {
		O	{ set mode "+o" }
		V 	{ set mode "+v" }
		default	{ set mode "" }
	}
	return $mode;
}

# -- start the secure '/names -d' timer
proc arm:secure {} {
        global arm

        # -- safety net
        if {$arm(mode) != "secure"} { return; }
        # -- only start the timer again if it's not already running
        # -- (/names could be running for other reasons)
        set restart 1
        foreach utimer [utimers] {
                set theproc [lindex $utimer 1]
                arm:debug 6 "arm:secure: utimer: $utimer"
                if {$theproc == "arm:secure" || [string match "*NAMES -d*" $utimer]} {
                        # -- arm:secure is already running
                        arm:debug 4 "arm:secure: timer already exists, not restarting"
                        set restart 0
                        break;
                }
        }
        if {$restart} {
                arm:debug 4 "arm:secure: starting /names -d $arm(cfg.chan.auto)"

                # -- begin
                utimer 5 { putquick "NAMES -d $arm(cfg.chan.auto)" }
        }
}


proc arm:notc:all {nick uhost hand text {dest ""}} {
	global arm botnick
	if {[string tolower $dest] !=  [string tolower $arm(cfg.chan.auto)]} { return; }
	
	# -- pass to arm:pubm:all -- saves on code cutting
	arm:pubm:all $nick $uhost $hand $dest $text
	
}

proc arm:pubm:all {nick uhost hand chan text} {
	global arm newjoin botnick override
	
	if {$nick == $botnick} { return; }
	
	# -- tidy nick
	set nick [split $nick]

	set ident [lindex [split $uhost @] 0]
	set host [lindex [split $uhost @] 1]

	# -- exempt if opped on common chan
	if {[isop $nick]} { return; }

	# -- exempt if voiced on common chan
	if {[isvoice $nick]} { return; }
	
	# -- exempt if umode +x
	if {[string match -nocase "*.users.undernet.org" $host]} { return; }
	
	# -- exempt if resolved ident
	if {![string match "~*" $ident]} { return; }
	
	# -- exempt if 3 repeating chars across nick!ident
	# -- (this should never happen when strings are random)
	#if {[regexp -- {(...).*\1} "$nick!$ident"]} { return; }
	
	# -- exempt if manual override (cmd: exempt)
	if {[info exists override($nick)]} { return; }
	
	# -- check if nick has newly joined (last 20 seconds)
	if {[info exists newjoin($nick)]} { set newcomer 1 } else { set newcomer 0 }

	# -- take action on channel name repeats (spam) - or website spam for newcomers
	set match 0
	foreach word $text {
		if {[string index $word 0] == "#"} { incr match }
	}
	if {$match > 2 || ($newcomer && [regexp -- {(?:https?\://|www\.[A-Za-z_\d-]+\.)} $text])} {
		# -- spammer match!
		arm:debug 1 "arm:pubm:all: spam detected from [join $nick]!$uhost (\002matches:\002 $match)"
		arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "Armour: spam is not tolerated."
		return;
		
	}
	
	# -- take action on word repeats (annoyance/spam)
	foreach word $text {
		# -- only if word is sizeable (elminates words like: it a is at etc
		if {[string length $word] >= 4} {
			if {![info exists repeat($word)]} { set repeat($word) 1 } else { incr repeat($word) }
		}
	}
	foreach word [array names repeat] {
		if {$repeat($word) >= 5} { 
			# -- annoyance match!
			arm:debug 1 "arm:pubm:all: annoyance detected from [join $nick]!$uhost (\002repeats:\002 $repeat($word))"
			arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "Armour: annoyances are not tolerated."
			# -- automatic blacklist entries
			if {$arm(cfg.auto.black)} {

				if {![info exists bline(host,$host)]} {
					# -- add automatic blacklist entry

					set reason "(auto) annoyances are not tolerated"
		
					# -- get next id
					set id [arm:get:nextID]
		
					set line "B:$id:host:$host:[unixtime]:Armour:B:1-1-1:0:$reason"
		
					arm:debug 1 "arm:pubm:all: adding auto blacklist line: $line"
		
					# -- add the list entry
					arm:db:add $line
				}

			}
		 	return;
		}
	}

	# -- kickban on coloured profanity for all, or any profanity for newly joined clients (last 20seconds)
	if {[regexp -- {\x3} $text] || $newcomer} {
		# -- colour codes used in text
		foreach word $arm(cfg.badwords) {
			if {[string match -nocase $word $text]} {
				# -- badword match!
				arm:debug 1 "arm:pubm:all: badword detected from [join $nick]!$uhost (\002mask:\002 $word)"
				arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "Armour: abuse is not tolerated."
				return;
			}
		}
	}
	
	if {$newcomer && [regexp -- {\x3} $text]} {
		# -- colour codes used in text
		arm:debug 1 "arm:pubm:all: colour detected from newcomer [join $nick]!$uhost (\002mask:\002 $word)"
		arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "Armour: tone it down a little"
		return;
	}
	
	# -- check string length (if newcomer)
	set length [string length $text]
	if {$newcomer && $length > 200} {
		# -- client is a newcomer (joined less than 20secs ago) & string length over 200 chars
		arm:debug 1 "arm:pubm:all: excessive string detected from newcomer [join $nick]!$uhost (\002length:\002 $length chars)"
		arm:kickban $nick $chan *!*@$host $arm(cfg.ban.time) "Armour: excess strings not yet tolerated from you."
		return;
	}
	
}


# -- arm:adapt:unset
# clear adaptive regex track
proc arm:adapt:unset {type exp} {
	global adaptn adaptni adaptnir adaptnr
	global adapti adaptir
	global adaptr
	
	switch -- $type {
		nick 		{ set array "adaptn" }
		ident		{ set array "adapti" }
		nick!ident		{ set array "adaptni" }
		nick!ident/rname	{ set array "adaptnir" }
		nick/rname		{ set array "adaptnr" }
		ident/rname		{ set array "adaptir" }
		rname		{ set array "adaptr" }
	}
	arm:debug 3 "arm:adapt:unset: removing adaptive regex tracker (type: $type array: $array exp: [join $exp])"

	catch { unset [set array]($exp) } error
	if {$error != "" } { putlog "error: $error" }
	
}

# -- arm:flud:unset
# clear floodnet track
proc arm:flud:unset {value} {
	global flud
	arm:debug 3 "arm:adapt:unset: removing floodnet tracker flud([join $value])"
	catch { unset flud($value) }
}



# -- unset netsplit tracker
proc arm:split:unset {value} {
	global arm
	arm:debug 2 "arm:split:unset: unsetting netsplit([join $value]) after $arm(cfg.split.mem) mins"
	catch { unset netsplit($value) }
}

# -- arm:newjoin:unset
# clear newjoin track
proc arm:newjoin:unset {nick} {
	global newjoin jointime

	# -- remove associated jointime
	foreach ts [array names jointime] {
		set tnick $jointime($ts)
		if {$nick == $tnick} { 
			unset jointime($ts) 
			arm:debug 4 "arm:newjoin:unset: removed newcomer jointime (timestamp) tracker jointime($ts) for nick: $nick"
		}
	}
	
	catch { unset newjoin($nick) }
	arm:debug 4 "arm:newjoin:unset: removed newjoin tracker newjoin([join $nick])"
}

# -- kill adaptive pattern timer unset
proc arm:adapt:preclear {regexp} {
	set ucount 0
	foreach utimer [utimers] {
		set timer [lindex $utimer 1]
		set id [lindex $utimer 2]
		set func [lindex $timer 0]
		if {$func != "arm:adapt:unset"} { continue; }
		# -- pattern is second arg of timer call (count is second)
		set pattern [lindex $timer 2]
		arm:debug 4 "arm:adapt:preclear: function: $func pattern: $pattern utimerID: $id"
		if {$pattern == [join $regexp]} {
			# -- kill the utimer
			incr ucount
			arm:debug 3 "arm:adapt:preclear: match! killing utimerID: $id"
			killutimer $id
		} 
	}
	arm:debug 3 "arm:adapt:preclear: killed $ucount utimers"
}

# -- kill floodnet counter timer unset
proc arm:flud:preclear {value} {
	arm:debug 4 "arm:flud:preclear: started for flud value: $value"
	set ucount 0
	foreach utimer [utimers] {
		set timer [lindex $utimer 1]
		set id [lindex $utimer 2]
		set func [lindex $timer 0]
		if {$func != "arm:flud:unset"} { continue; }
		# -- pattern is second arg of timer call (count is second)
		set result [lindex $timer 1]
		arm:debug 4 "arm:adapt:preclear: function: $func value: $result utimerID: $id"
		if {$value == $result} {
			# -- kill the utimer
			incr ucount
			arm:debug 3 "arm:flud:preclear: match! killing utimerID: $id"
			killutimer $id
		} 
	}
	arm:debug 3 "arm:flud:preclear: killed $ucount utimers"
}

# -- generic utimer preclear
proc arm:preclear:utimer {value {value2 ""}} {
	arm:debug 4 "arm:preclear:utimer started for utimer: $value"
	set ucount 0
	foreach utimer [utimers] {
		set timer [lindex $utimer 1]
		set id [lindex $utimer 2]
		set func [lindex $timer 0]
		set var [lindex $timer 1]
		if {$func != $value} { continue; }
		putlog "\002\arm:preclear:utimer:\002 value: $value: value2: $value2 -> timer func: $func var: $var"
		# -- kill the utimer
		if {$value2 == "" || $var == $value2} {
			incr ucount
			arm:debug 1 "\002arm:preclear:utimer:\002 match! killing utimerID: $id"
			killutimer $id
		}
	} 
	arm:debug 3 "arm:preclear:utimer killed $ucount utimers"
}

# -- generic timer preclear
proc arm:preclear:timer {value} {
	arm:debug 4 "arm:preclear:timer started for timer: $value"
	set count 0
	foreach timer [timers] {
		set thetimer [lindex $timer 1]
		set id [lindex $timer 2]
		set func [lindex $timer 0]
		if {$func != "$value"} { continue; }
		# -- kill the timer
		incr count
		arm:debug 3 "arm:preclear:timer match! killing timerID: $id"
		killtimer $id
	} 
	arm:debug 3 "arm:preclear:timer killed $count timers"
}


proc arm:report {type target string} {
	global arm full
	
	# -- obtain the right chan for opnotice
	if {[info exists full]} {
		# -- full channel scan under way
		set list [lsort [array names full]]
		foreach channel $list {
			set chan [lindex [split $channel ,] 1]    
		}
		if {![info exists chan]} { set chan $arm(cfg.chan.auto) }
	} else { set chan $arm(cfg.chan.auto) }
	if {$type == "white"} {
		if {$arm(cfg.notc.white)} { putquick "NOTICE $target :$string" }
		if {$arm(cfg.opnotc.white)} { putquick "NOTICE @$chan :$string" }
		if {$arm(cfg.dnotc.white)} { putquick "NOTICE $arm(cfg.chan.report) :$string"}
	}
	if {$type == "black"} {
		if {$arm(cfg.notc.black)} { putquick "NOTICE $target :$string" }
		if {$arm(cfg.opnotc.black) || $arm(mode) == "secure"} { putquick "NOTICE @$chan :$string" }
		if {$arm(cfg.dnotc.black) || $arm(mode) == "secure"} { putquick "NOTICE $arm(cfg.chan.report) :$string" }
	}
}


# -- remove value from a list
proc arm:listremove {list value} {
	set value [split $value]
	arm:debug 3 "arm:listremove: STARTED!!!"
	# -- this will fail if the list doesn't actually exist!
	# -- THIS IS BUGGY FOR THIS REASON... the below trap isn't working
	if {[info exists [subst $list]]} {
		arm:debug 3 "arm:listremove: 2"
		upvar 0 $list tmp
		if {[info exists [subst $tmp]($value)]} {
			arm:debug 3 "arm:listremove: removing $value from $list"
			set loc [lsearch [subst $tmp] $value]
			set newlist [lreplace [subst $tmp] $loc $loc]
			set [subst $list] $newlist
			arm:debug 4 "arm:listremove: $list is now: $newlist"
		}
	}
}


proc arm:killtimers {} {
	# -- kill existing timers
	set ucount 0
	set count 0
	foreach utimer [utimers] {
		incr ucount
		arm:debug 1 "arm:killtimers: killing utimer: $utimer"
		killutimer [lindex $utimer 2] 
	}
	foreach timer [timers] {
		incr count
		arm:debug 1 "arm:killtimers: killing timer: $timer"
		killtimer [lindex $timer 2] 
	}
	arm:debug 1 "arm:killtimers: killed $ucount utimers and $count timers"
}

# -- voice the nick
proc arm:voice {chan nick} {
	global arm voicelist scanlist
	# -- stack voice?
	if {$arm(cfg.stackvoice)} { lappend voicelist $nick } else {
		# -- single voice
		putserv "MODE $chan +v $nick" -next
	}
	
	# -- clear from paranoid scanlist if exist
	if {[info exists scanlist(paranoid)]} {
		set pos [lsearch $scanlist(paranoid) $nick]
		if {$pos != -1} {
			set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
		}
	}
	
	# -- clear from scanlist(nicklist) if exists (list of those to scan from /names -d)
	if {[info exists scanlist(nicklist)]} {
		set pos [lsearch $scanlist(nicklist) $nick]
		if {$pos != -1} {
			set scanlist(nicklist) [lreplace $scanlist(nicklist) $pos $pos]
		}
	}
	
}

# -- stack the voice modes
proc arm:stackvoice {} {
	global arm voicelist

	if {![info exists voicelist]} { set voicelist "" }
	set voicelist [join $voicelist " "]


	while {$voicelist != ""} {
		# -- voice stack workaround (pushmode doesn't work as client not in chan yet)
		set length [llength $voicelist]
		if {$length >= 6} { set modes "+vvvvvv" } else { set modes "+[string repeat "v" $length]" }
		arm:debug 2 "arm:stackvoice: executing: MODE $arm(cfg.chan.auto) $modes [join [lrange $voicelist 0 5]]"
		putquick "MODE $arm(cfg.chan.auto) $modes [join [lrange $voicelist 0 5]]"
		set voicelist [lreplace $voicelist 0 5]
	}
	utimer $arm(cfg.stack.secs) arm:stackvoice
}

# -- build longtypes (ltypes) -- adaptive regex
# -- ltypes
array set ltypes {
	n	{nick}
	ni	{nick!ident}
	nir	{nick!ident/rname}
	nr	{nick/rname}
	i	{ident}
	ir	{ident/rname}
	r	{rname}
}

# -- redirect tcl errors to a channel
# -- decided against this, sends too much (from 'catch unset...')
#if {![info exists ::errortracer]} { set ::errortracer 1; trace add variable ::errorInfo write redirecterror }
proc redirecterror {n1 n2 op} {
	set ::olddblvalue ${::double-help}
	set ::double-help 0
	foreach line [split $::errorInfo \n] {
			#puthelp "PRIVMSG #armour_info :$line"
			putlog "(TCL ERROR): $line"
	}
	set ::double-help $::olddblvalue
}

# -- calculate runtime
proc arm:runtime {start} {
	set end [clock clicks]
	return "[expr ($end-$start)/1000/1000.0] sec"
}

# -- eggdrop 1.6.19 putnow (available in 1.6.20 core)
# proc putnow {text} { putdccraw 0 [strlen $text\r\n] $text\r\n }

# -- ctcp version response
proc arm:ctcp:version {nick uhost hand dest keyword args} {
	global arm
	putquick "NOTICE $nick :\001VERSION Armour $arm(version) -- Empus <empus@undernet.org>\001"
 	return 1;
}


# -- sending join data to external scripts for integration
proc arm:integrate {nick uhost hand chan extra} {
	global arm
	# -- pass join arguments to other standalone scripts
	foreach proc $arm(cfg.integrate.procs) {
		arm:debug 0 "arm:integrate: passing data to external script proc $proc: $nick $uhost $hand $arm(cfg.chan.def) $extra"
		$proc $nick $uhost $hand $arm(cfg.chan.def) $extra
	}
}

# -- ensure IP is valid
proc arm:isValidIP {ip} {
	# -- need to add IPv6 here too
	if {![regexp -- {(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)} $ip]} { 
		return 0; 
	}
  	return 1;
}

# -- cleanup some vars when finished scan
# -- restart '/names -d' timer if this was last nick in the scan list
proc arm:scan:cleanup {nick {leave ""}} {
        global arm scanlist exempt
        catch { unset exempt($nick) }
        # -- remove the nick from the scanlist (created from /names -d)
        #arm:listremove scanlist(nicklist) $nick

        #arm:debug 4 "arm:scan:cleanup: started: leave: $leave"

        arm:clean:scanlist $nick 1

        if {$leave == "" || $leave == 0} {
                # -- don't leave nick in paranoid scanlist (they have been left for manual review)
                arm:debug 4 "arm:scan:cleanup: removing $nick from scanlists";
                #arm:listremove scanlist(paranoid) $nick
                arm:clean:scanlist $nick 0
        }

        set flush 0
        if {![info exists scanlist(nicklist)]} {
                set flush 1
        } else {
                if {$scanlist(nicklist) == ""} { set flush 1 }
        }
        if {$flush} {
                # -- the nicklist to scan is now empty (all scanned)

                # -- flush the scanlist(scanlist) array -- all nicks should be scanned so no longer needed
                if {[info exists scanlist(scanlist)]} { unset scanlist(scanlist) }
                # -- restart /names -d
                if {$arm(mode) == "secure"} {
                        arm:debug 4 "arm:scan:cleanup: flushed scanlist(nicklist) -- all nicknames have been scanned, restarting arm:secure in 5 secs"
                        utimer 5 arm:secure;
                }
        }
}


proc arm:clean:scanlist {nick {leave ""}} {
        global scanlist

        # -- list of those being scanned
        if {[info exists scanlist(scanlist)]} {
			if {$scanlist(scanlist) != ""} { arm:debug 4 "arm:clean:scanlist: $scanlist(scanlist)" }
			set pos 0
			foreach theset $scanlist(scanlist) {
				set tnick [lindex $theset 0]
				if {[join $tnick] == [join $nick]} {
					# -- nick within
					arm:debug 4 "arm:clean:scanlist: nick is within scanlist(scanlist): [join $nick] -- removing"
					set scanlist(scanlist) [lreplace $scanlist(scanlist) $pos $pos]
					if {$scanlist(scanlist) == ""} {
							unset scanlist(scanlist)
							arm:debug 4 "arm:clean:scanlist: scanlist(scanlist) now empty"
					}
				} else { arm:debug 4 "arm:clean:scanlist: nick is NOT within scanlist(scanlist): [join $nick]" }
				incr pos
			}
        }
		
        # -- list of those from /names -d
        if {[info exists scanlist(nicklist)]} {
			if {$scanlist(nicklist) != ""} { arm:debug 4 "arm:clean:scanlist: $scanlist(nicklist)" }
			set pos 0
			foreach theset $scanlist(nicklist) {
				set tnick [lindex $theset 0]
				if {[join $tnick] == [join $nick]} {
					# -- nick within
					arm:debug 4 "arm:clean:scanlist: nick is within scanlist(nicklist): [join $nick] -- removing"
					set scanlist(nicklist) [lreplace $scanlist(scanlist) $pos $pos]
					if {$scanlist(nicklist) == ""} {
							unset scanlist(nicklist)
							arm:debug 4 "arm:clean:scanlist: scanlist(nicklist) now empty"
					}
				} else { arm:debug 4 "arm:clean:scanlist: nick is NOT within scanlist(nicklist): [join $nick]" }
				incr pos
			}
        }



        # -- list of those we have left for manual review
		# -- only remove them if not told to leave
        if {$leave == 0 || $leave == ""} {
            if {[info exists scanlist(paranoid)]} {
				if {$scanlist(paranoid) != ""} { arm:debug 4 "arm:clean:scanlist: $scanlist(paranoid)" }
				set pos 0
				foreach theset $scanlist(paranoid) {
					set tnick [lindex $theset 0]
					if {[join $tnick] == [join $nick]} {
						# -- nick within
						arm:debug 4 "arm:clean:scanlist: nick is within scanlist(paranoid): [join $nick] -- removing"
						set scanlist(paranoid) [lreplace $scanlist(paranoid) $pos $pos]
						if {$scanlist(paranoid) == ""} {
								unset scanlist(paranoid)
								arm:debug 4 "arm:clean:scanlist: scanlist(paranoid) now empty"
						}
					} else { arm:debug 4 "arm:clean:scanlist: nick is NOT within scanlist(paranoid): [join $nick]" }
					incr pos
				}
			}   
        }
}



# -- add log entry
proc arm:log:cmdlog {source user user_id command params bywho target target_xuser wait} {
	global arm
	if {$arm(method) == "sqlite"} {
		::armdb::db_connect
		set db_user [::armdb::db_escape $user]
		set db_params [::armdb::db_escape $params]
		set db_bywho [::armdb::db_escape $bywho]
		set db_target [::armdb::db_escape $target]
		set db_target_xuser [::armdb::db_escape $target_xuser]
		::armdb::db_query "INSERT INTO cmdlog (timestamp, source, user, user_id, \
			command, params, bywho, target, target_xuser, wait) \
			VALUES ('[clock seconds]', '$source', '$db_user', '$user_id', '$command', \
			'$db_params', '$db_bywho', '$db_target', '$db_target_xuser', '$wait')"
		::armdb::db_close
	} else {
		# -- should we write to a local logfile?
	}
	if {$arm(cfg.chan.report) != ""} {
		if {$params != ""} {
                        putquick "PRIVMSG $arm(cfg.chan.report) :cmd: [string tolower $command] $params (user: $user)"
                } else {
                        putquick "PRIVMSG $arm(cfg.chan.report) :cmd: [string tolower $command] (user: $user)"
		}
        }
	return
}

arm:debug 0 "\[@\] Armour: loaded support functions."




# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-19_init.tcl
#
# script initialisation (array clean & timer inits)
#


# -- rebind for generic userdb procs
proc arm:reply {type target args} { userdb:reply $type $target [join $args] }
proc arm:init:autologin {} { userdb:init:autologin }

# -- secure eggdrop
unbind msg - hello *msg:hello
unbind msg - ident *msg:ident

# -- load lists to memory
arm:db:load

# -- unset existing exempt array
catch { unset exempt }

# -- unset existing adaptive regex tracking arrays
catch { unset adapt }
catch { unset adaptn; unset adaptni; unset adaptnir; unset adaptnr; }
catch { unset adapti; unset adaptir; }
catch { unset adaptr; }
# -- unset floodnet tracking counters
catch { unset flud; }
catch { unset floodnet; }

# -- unset nicks on host tracking array
catch { unset hostnicks; }

# -- unset nicks on ip tracking array
catch { unset ipnicks; }

# -- unset host on nick tracking array
catch { unset nickhost; }

# -- unset ip on nick tracking array
catch { unset nickip; }

# -- unset scanlist for /endofwho
catch { unset scanlist; }

# -- unset pranoid coroutine array for arm:scan:continue
catch { unset paranoid; }

# -- unset channel lock array (recently set chanmode +r)
catch { unset chanlock; }

# -- unset realname tracker
catch { unset fullname; }

# -- unset kick reason array (tracks cumulative floodnet blacklist reason)
catch { unset kreason; }

# -- unset existing setx array (newly umode +x clients)
catch { unset setx }

# -- unset existing newjoin array (temp array to identify newcomers in channel)
catch { unset newjoin }

# -- unset wholist (tracks users between /WHO's)
catch { unset wholist }

# -- unset temporary exemption overrides (from 'exempt' command)
catch { unset override }

# -- unset netsplit memory (track's users lost in netsplits)
catch { unset netsplit }

# --- unset global kicklist array
catch { unset gklist }

# --- unset global banlist array
catch { unset gblist }

# -- kill existing timers
arm:killtimers

# -- kill any tcl timers ('after' cmd)
foreach id [after info] { after cancel $id }

# -- start list db save timer
timer $arm(cfg.db.save) arm:db:write

# -- start userfile save timer
timer $arm(cfg.db.save) userdb:db:write

# -- start /names -d (for secure mode)
arm:debug 4 "ArmourIP: restarting arm:secure..."; 
arm:secure

# -- start voice stack timer
arm:stackvoice

# -- start floodnet mode queue timer (attempts to stack bans during floodnet)
arm:flud:queue

# -- start autologin
arm:init:autologin


arm:debug 0 "\[@\] Armour: initialised"
arm:debug 0 "\[@\] Armour loaded $arm(version) loaded (empus@undernet.org)"




