# ------------------------------------------------------------------------------------------------
# armour.tcl v4.0 autobuild completed on: Fri Dec 16 07:55:25 PST 2022
# ------------------------------------------------------------------------------------------------
#
#     _                                    
#    / \   _ __ _ __ ___   ___  _   _ _ __ 
#   / _ \ | '__| '_ ` _ \ / _ \| | | | '__|
#  / ___ \| |  | | | | | | (_) | |_| | |   
# /_/   \_\_|  |_| |_| |_|\___/ \__,_|_|   
#                                          
#
# Anti abuse and channel management script for eggdrop bots on IRC networks
#
# ------------------------------------------------------------------------------------------------
#
# Do not edit this code unless you really know what you are doing
#
# Note that this *.tcl file does not get loaded by your eggdrop config file.  Instead, load your 
# armour.conf file from your eggdrop config file.  This *.tcl then gets loaded by the config file.
#
# Multiple bots can run from a common eggdrop installation directory.  Each individual bot should
# then have its own armour configuration file (e.g., named <botname>.conf), just as is the case
# with the eggdrop configuration files in the deirectly above this ./armour directory.
#
# Check for updates @ https://wwww.armour.bot
#
# - Empus
#   empus@undernet.org
#
# ------------------------------------------------------------------------------------------------


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-01_depends.tcl
#
# script dependencies
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- we require min Tcl 8.6 for coroutines
package require Tcl 8.6

# -- provide some extra detail in TCL errors
proc ::bgerror {message} { 
    putloglev 1 * "\002(bgError)\002: \"$message\":" 
    foreach line [split $::errorInfo "\n"] { 
        putloglev 1 * "  $line" 
    } 
    putloglev 1 * "\002(bgError)\002: errorCode: $::errorCode" 
    putloglev 1 * "-"
}

# -- override some eggdrop settings based on ircd type
if {$cfg(ircd) eq 1} {
    # -- Undernet (ircu)
    set ::stack-limit 6;    # -- modes per line
    set ::optimize-kicks 0; # -- avoid optimizing kicks so users can be kicked when channel is mode +d (mode: secure)
                            # https://github.com/eggheads/eggdrop/blob/63dce0f5bc17d88c3b42983228b89695ebf182ae/src/mod/server.mod/server.c#L652-L656
} elseif {$cfg(ircd) eq 2} {
    # -- IRCnet/Quakenet
}

# -- abstraction to obtain configuration values
proc cfg:get {setting {chan ""}} {
    variable cfg
        
    # -- for now, just keep reading from file (database to come soon!)
    
    # -- log the retrieval so we can identify inefficiencies where duplicate reads happen within a proc
    #    this will become much more important when moving to the DB (avoiding superfluous DB hits)
    #    exclude particularly verbose setting recalls which can't be avoided
    #    NOTE: caching some in memory and detecting changes by timestamp, will also lessen DB hits
    set avoid 0;
    switch -- $setting {
        botname                 { set avoid 1; }
        debug                   { set avoid 1; }
        debug:type              { set avoid 1; }
        chan:login              { set avoid 1; }
        autologin:cycle         { set avoid 1; }
        prefix                  { set avoid 1; }
        queue:flud              { set avoid 1; }
        chanlock:time           { set avoid 1; }
        stack:secs              { set avoid 1; }
        ircd                    { set avoid 1; }
        queue:secure            { set avoid 1; }
        char:glob               { set avoid 1; }
        text:exempt:voice       { set avoid 1; }
        text:exempt:op          { set avoid 1; }
        text:autoblack          { set avoid 1; }
        flood:line:nicks        { set avoid 1; }
        flood:line:chan         { set avoid 1; }
        flood:line:newcomer     { set avoid 1; }
        flood:line:autoblack    { set avoid 1; }
        flood:line:exempt:op    { set avoid 1; }
        flood:line:exempt:voice { set avoid 1; }
        stack:voice             { set avoid 1; }
        lasthosts               { set avoid 1; }
        lastspeak:mins          { set avoid 1; }
        xhost:ext               { set avoid 1; }
        gline:auto              { set avoid 1; }
        gline:mask              { set avoid 1; }
        split:mem               { set avoid 1; }
        routing:chan            { set avoid 1; }
        routing:alert           { set avoid 1; }
        routing:alert:perc      { set avoid 1; }
        routing:alert:count     { set avoid 1; }
    }
    if {[string match "fn:platform:*" $setting] || [string match "fn:user:*" $setting]} { set avoid 1 }; # -- silence user-specific Fortnite settings
    
    if {!$avoid} { debug 4 "\002cfg:get:\002 retrieving config setting: \002cfg($setting)\002" }
    
    # -- output the config file value for now
    if {[info exists cfg($setting)]} {
        return $cfg($setting)
    } else {
        debug 0 "\002cfg:get: (!CONFIG ERROR!)\002 -- setting not found: \002cfg($setting)\002"
        putnotc $cfg(chan:report) "Armour: \002config error\002 -- setting not found: \002cfg($setting)\002"
        return "";
    }

    # -- when switching to DB:
    #      - ensure DB entries that must only be set globally, are marked as such
    #      - fix 'conf' command to read settings properly
    #      - remove 'variable cfg' declaration from all other procs
    #      - place cfg:get procedure (and supporting DB functions) early in script:
    #          - before other procs using cfg:get are used;

    # -- begin DB retrieval!
    if {$chan eq "" || $chan eq 0} { set chan "*" }; # -- safety net
    # ... more here later
    
    # -- schema concept:
    # db:query "CREATE TABLE IF NOT EXISTS config (\
    #   id INTEGER PRIMARY KEY AUTOINCREMENT,\
    #   cid INTEGER NOT NULL DEFAULT '1',\
    #   setting TEXT NOT NULL,\
    #   value TEXT NOT NULL,\
    #   global INT NOT NULL DEFAULT 0,\
    #   new INT NOT NULL DEFAULT 0,\
    #   added_id INTEGER NOT NULL,\
    #   added_bywho TEXT NOT NULL,\
    #   added_ts INTEGER NOT NULL,\
    #   added_id INTEGER NOT NULL,\
    #   modif_bywho TEXT NOT NULL,\
    #   modif_ts INTEGER NOT NULL\
    #   )"
}

# -- debug proc -- we use this alot
proc debug {level string} {
    if {$level eq 0 || [cfg:get debug:type *] eq "putlog"} {
        putlog "\002\[A\]\002 $string";
    } else {
        putloglev $level * "\002\[A\]\002 $string";
    }
}

set scan(cfg:ban:time) [cfg:get ban:time *]; # -- config variable fixes

if {![info exists uservar]} { set uservar ${botnet-nick} }; # -- set var if not used in eggdrop config

# -- handle script config file in case user keeps as armour.conf
# -- the below will help make script 3.x to 4.x migrations easier for users, and for those that don't rename armour.conf
set armname [cfg:get botname]
if {$armname eq ""} {
    # -- handle config
    debug 0 "\002warning\002: cfg(botname) not set in \002armour.conf\002, defaulting to \002armour\002"
    if {[info commands report] ne ""} { report debug "" "Armour \002warning\002: cfg(botname) not set in \002armour.conf\002, defaulting to \002armour\002" }
    set confname "armour"
    # -- check for old db entry
    set sqlitedb [cfg:get sqlite]
    if {$sqlitedb ne ""} {
        debug 0 "\002warning\002: cfg(sqlite) in \002armour.conf\002 is \002deprecated!\002 please remove."
        if {[info commands report] ne ""} { report debug "" "Armour \002warning\002: cfg(sqlite) in \002armour.conf\002 is \002deprecated!\002 please remove." }
        set dbname [file tail $sqlitedb]
        string trimright $dbname .db
    } else {
        debug 0 "\002warning\002: cfg(botname) not set in \002armour.conf\002, defaulting database to \002./armour/db/armour.db\002"
        if {[info commands report] ne ""} { report debug "" "Armour \002warning\002: cfg(botname) not set in \002armour.conf\002, defaulting database to \002./armour/db/armour.db\002" }
        set dbname "armour"
    }
} else {
    if {![file isfile ./armour/$armname.conf]} {
        debug 0 "\002warning\002: ./armour/$armname.conf does not exist. defaulting to \002armour.conf\002"
        if {[info commands report] ne ""} { report debug "" "Armour \002warning\002: ./armour/$armname.conf does not exist. defaulting to \002armour.conf\002" }
        set confname "armour"
    } else { set confname $armname }

    if {![file isfile ./armour/db/$armname.db]} {
        debug 0 "\002warning\002: ./armour/db/$armname.db does not exist. defaulting to \002./armour/db/armour.db\002"
        if {[info commands report] ne ""} { report debug "" "Armour \002warning\002: ./armour/db/$armname.db does not exist. defaulting to \002./armour/db/armour.db\002" }
        set dbname "armour"
    } else { set dbname $armname }
}




debug 0 "\[@\] Armour: loaded script configuration."

}
# -- end of namespace


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
bind ctcp - "VERSION" arm::ctcp:version
bind ctcp - "TIME" arm::ctcp:time

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
if {[arm::cfg:get lockegg *]} {

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
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# ---- protection binds
bind pubm - * arm::pubm:all 
bind notc - * arm::notc:all
bind ctcp - "ACTION" arm::ctcp:action


proc loadcmds {} {
    variable cfg 
    variable armbind 
    variable addcmd 
    variable userdb 
    global botnet-nick
    
    # -- TODO: unbind existing binds; so commands can be disabled once bot is running
    
    # -- setup commands for autobinds
    foreach cmd [array names addcmd] {
        set prefix [lindex $addcmd($cmd) 0]
        set lvl [lindex $addcmd($cmd) 1]
        set binds [lrange $addcmd($cmd) 2 end]
        debug 5 "arm:loadcmds: loaded $prefix command: $cmd (lvl: $lvl binds: $binds)"
        # -- check for public
        if {[lsearch $binds "pub"] ne -1} { set armbind(cmd,$cmd,pub) $prefix; set userdb(cmd,$cmd,pub) $lvl }
        # -- check for dcc
        if {[lsearch $binds "dcc"] ne -1} { set armbind(cmd,$cmd,dcc) $prefix; set userdb(cmd,$cmd,dcc) $lvl; }
        # -- check for privmsg
        if {[lsearch $binds "msg"] ne -1} {
            set armbind(cmd,$cmd,msg) $prefix; set userdb(cmd,$cmd,msg) $lvl;
            set cmdprefix [cfg:get prefix *]
            if {[regexp -- {^[A-Za-z]$} $cmdprefix]} {
                # -- command prefix is a letter
                
                bind pub - $cmdprefix arm::userdb:pub:cmd; # -- bind the command prefix for generic proc
                # -- create the generic command proc
                proc userdb:pub:cmd {n uh h c a} {
                    variable armbind
                    # -- try to do ; separated multiple commands?
                    foreach xa [split $a ";"] {
                        set a [string trim $xa]
                        set cmd [lindex [split $a] 0]
                        set a [lrange [split $a] 1 end]
                        if {[info exists armbind(cmd,$cmd,pub)]} {
                            set prefix $armbind(cmd,$cmd,pub)
                            # -- redirect to cmd proc
                            coroexec arm::$prefix:cmd:$cmd pub $n $uh $h $c $a
                        } elseif {$cmd eq "login"} {
                            # -- public channel login (with no other params, for self-login)
                            coroexec arm::userdb:pub:login $n $uh $h $c $a
                        }
                    }
                }
            } elseif {regexp -- {^\*$} $cmdprefix]} {
                # -- command prefix * is illegal! (clashes with multi-bot prefix response)
                debug 0 "\002loadcmds\002: shutting down bot -- illegal configuration 'prefix' of *"
                die "Armour: illegal configuration 'prefix' of * in cfg(prefix)"
            } else {
                # -- command prefix is some sort of control char (i.e. '!' or '.')
                bind pub - ${cmdprefix}$cmd arm::userdb:pub:cmd:$cmd; # -- bind the command prefix for generic proc
                # -- create the generic command proc
                proc userdb:pub:cmd:$cmd {n uh h c a} {
                    variable armbind
                    set prefix [lindex [split [lindex [info level 0] 0] :] 2]
                    set cmd [lindex [split [lindex [info level 0] 0] :] 5]
                    if {[info exists armbind(cmd,$cmd,pub)]} {
                        set prefix $armbind(cmd,$cmd,pub)
                        # -- redirect to cmd proc
                        coroexec arm::$prefix:cmd:$cmd pub $n $uh $h $c $a
                    } elseif {$cmd eq "login"} {
                        # -- public channel login (with no other params, for self-login)
                        coroexec arm::userdb:pub:login $n $uh $h $c $a
                    }
                }
            }
        }
    } 

    # -- dcc binds
    bind dcc - [cfg:get prefix *] arm::userdb:dcc:*
    proc userdb:dcc:* {h i a} {
        variable armbind
        
        # -- try to do ; separated multiple commands?
        foreach xa [split $a ";"] {
            set a [string trim $xa]
            set cmd [lindex [split $a] 0]
            set a [lrange [split $a] 1 end]
            if {[info exists armbind(cmd,$cmd,dcc)]} {
                set prefix $armbind(cmd,$cmd,dcc)
                    
                # -- redirect to cmd proc
                coroexec arm::$prefix:cmd:$cmd dcc $h $i $a
            
                # -- allow for command shortcuts?
            }
        }
    }

    # -- privmsg binds
    foreach i [array names armbind] {
        set line [split $i ,]
        lassign $line a cmd type
        if {$a ne "cmd" || $type ne "msg"} { continue; }
        set prefix $armbind($i)
        # -- bind the command
        debug 5 "\002loadcmds:\002 armbind: cmd: $cmd -- bind: arm::$prefix:msg:$cmd"
        bind msg - $cmd arm::$prefix:msg:$cmd
        proc $prefix:msg:$cmd {n uh h a} {
            set prefix [lindex [split [lindex [info level 0] 0] :] 2]
            set cmd [lindex [split [lindex [info level 0] 0] :] 4]
            coroexec arm::$prefix:cmd:$cmd msg $n $uh $h [split $a]
        }
    
        # -- allow for command shortcuts?
    }
    
    # ---- command shortcuts
    # -- intelligently load these later
    if {[cfg:get cmd:short *]} {
        # -- cmd: ban
        proc arm:cmd:kb {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:ban $0 $1 $2 $3 $4 $5 };        # -- cmd: ban
        proc arm:cmd:commands {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:cmds $0 $1 $2 $3 $4 $5 }; # -- cmd: cmds
        proc arm:cmd:k {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:kick $0 $1 $2 $3 $4 $5 };        # -- cmd: kick
        proc arm:cmd:b {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:black $0 $1 $2 $3 $4 $5 };       # -- cmd: black
        proc arm:cmd:a {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:add $0 $1 $2 $3 $4 $5 };         # -- cmd: add
        proc arm:cmd:r {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:rem $0 $1 $2 $3 $4 $5 };         # -- cmd: rem
        proc arm:cmd:m {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:mod $0 $1 $2 $3 $4 $5 };         # -- cmd: mod
        proc arm:cmd:v {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:view $0 $1 $2 $3 $4 $5 };        # -- cmd: view
        proc arm:cmd:i {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:info $0 $1 $2 $3 $4 $5 };        # -- cmd: info
        proc arm:cmd:e {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:exempt $0 $1 $2 $3 $4 $5 };      # -- cmd: exempt
        proc arm:cmd:s {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:search $0 $1 $2 $3 $4 $5 };      # -- cmd: search
        proc arm:cmd:o {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:op $0 $1 $2 $3 $4 $5 };          # -- cmd: op
        proc arm:cmd:d {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:deop $0 $1 $2 $3 $4 $5 };        # -- cmd: deop
        proc arm:cmd:t {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:topic $0 $1 $2 $3 $4 $5 };       # -- cmd: topic
        proc arm:cmd:u {0 1 2 3 {4 ""} {5 ""}} { coroexec arm:cmd:userlist $0 $1 $2 $3 $4 $5 };    # -- cmd: userlist
    }
}
# -- end of arm:loadcmds


# -- allow use of nickname (with or without nick completion char ':') or global char '*' as control char
if {[cfg:get char:nick *] || [cfg:get char:glob *]} {
    bind pubm - * arm::arm:pubm:binds
    proc arm:pubm:binds {nick uhost hand chan text} {
        variable cfg 
        global botnick
        
        if {$nick eq $botnick} { return; }
        
        # -- tidy nick
        set nick [split $nick]

        set first [lindex [split $text] 0]
        # -- check for global prefix char '*' OR bot nickname
        if {([cfg:get char:glob *] && $first eq "*") || ([string match -nocase [string trimright $first :] $botnick] eq 1)} {
            debug 3 "arm:pubm:binds: global char * exists or bots nickname"
            
            set continue 0
            # -- global control char
            if {$first eq "*"} { set continue 1 }
            # -- no nick complete & not required
            if {[string index $first end] ne ":" && [cfg:get char:tab *] ne 1} { set continue 1 }

            # -- nick complete used
            if {[string index $first end] eq ":"} { set continue 1 }

            if {$continue} {            
                # -- initiating a command
                set second [lindex $text 1]
                if {[regexp -- {^[A-Za-z]+$} $second] eq 0} { return; }; # -- safety net, not a command
                set second [string tolower $second]
                debug 3 "arm:pubm:binds: processing command: $second (text: [lrange $text 2 end])"
                # -- should only be one result here, take the first anyway as safety
                set res [lindex [info commands *:cmd:$second] 0]
                if {$res ne ""} {
                    # -- result is proc name, redirect to command proc
                    coroexec $res pub $nick $uhost $hand $chan [lrange [split $text] 2 end]
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
proc coroexec {args} {
    coroutine coro_[incr ::coroidx] {*}$args
}

# -- load the actual commands!
loadcmds


debug 0 "\[@\] Armour: loaded command binds."

}
# -- end of namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-04_db.tcl
#
# user database functions
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- this revision is used to match the DB revision for use in upgrades and migrations
set cfg(revision) "2022121400"; # -- YYYYMMDDNN (allows for 100 revisions in a single day)
set cfg(version) "v4.0";        # -- script version

# -- load sqlite (or at least try)
if {[catch {package require sqlite3} fail]} {
    putlog "\002\[@\] Armour: error loading sqlite3 library. error: $fail\002"
    return false
}

# -- create db directories if they don't already exist
if {![file isdirectory "./db"]} { exec mkdir "./db" };                # -- eggdrop db files
if {![file isdirectory "./armour/db"]} { exec mkdir "./armour/db" };  # -- armour db files

# -- db connect
proc db:connect {} { sqlite3 armsql "./armour/db/$::arm::dbname.db" }
# -- escape chars
proc db:escape {what} { return [string map {' ''} $what] }
proc db:last:rowid {} { armsql last_insert_rowid }

# -- query abstract
proc db:query {query} {
    set res {}
    armsql eval $query v {
        set row {}
        foreach col $v(*) {
            lappend row $v($col)
        }
        lappend res $row
    }
    return $res
}
# -- db close
proc db:close {} { armsql close }

# -- connect attempt
if {[catch {db:connect} fail]} {
    putlog "\002\[@\] Armour: unable to connect to sqlite database. error: $fail\002"
    return false
}

# example: db:get level levels nick Empus 
# supports multiple columns in one query: db:get level,automode levels uid 1
proc db:get {item table source value {source2 ""} {value2 ""}} {
    # -- safety net
    if {$item eq "" || $table eq "" || $source eq "" || $value eq ""} {
        debug 0 "\002(error)\002 db:get: missing param (item: $item -- table: $table -- source: $source -- value: $value)"
        return;
    }
    db:connect
    # -- encapsulate columns in "" for special names (limit)
    set items ""
    foreach i [split $item ,] {
        append items "\"$i\","
    }
    set items [string trimright $items ,]
    set item $items

    set dbvalue [db:escape $value]
    if {$source2 ne "" && $value2 ne ""} {
        set dbvalue2 [db:escape $value2]
        set extra " AND lower($source2)='[string tolower $dbvalue2]'"
        set extra2 " and $source2=$value2"
    } else { set extra ""; set extra2 "" }
    set query "SELECT $item FROM $table WHERE lower($source)='[string tolower $dbvalue]' $extra"
    #putlog "\002db:get:\002 query: $query"
    set row [db:query $query]
    set result [lindex $row 0]; # -- return one value/row
    #debug 4 "db:get: get $item from $table where $source=$value$extra2 (\002row:\002 $row)"
    if {[llength [join $result]] eq 1} { return [join $result] } else { return $result }
}

# ---- create the tables
# -- user database
db:query "CREATE TABLE IF NOT EXISTS users (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    user TEXT UNIQUE NOT NULL,\
    xuser TEXT,\
    email TEXT,\
    curnick TEXT,\
    curhost TEXT,\
    lastnick TEXT,\
    lasthost TEXT,\
    lastseen INTEGER,\
    languages TEXT NOT NULL DEFAULT 'EN',\
    pass TEXT,\
    register_ts INT,\
    register_by TEXT\
    )"
    
# -- user login table
db:query "CREATE TABLE IF NOT EXISTS users_login (\
    id INTEGER NOT NULL,\
    user TEXT NOT NULL,\
    xuser TEXT NOT NULL,\
    curnick TEXT,\
    curhost TEXT,\
    lastseen INTEGER\
    )"

# -- channels
# -- 
db:query "CREATE TABLE IF NOT EXISTS channels (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    chan TEXT UNIQUE NOT NULL,\
    reg_uid INTEGER,\
    reg_bywho TEXT,\
    reg_ts INTEGER,\    
    mode TEXT DEFAULT 'on'\
    )"
    
# -- settings
# -- stores channel and user settings; avoids schema changes later
db:query "CREATE TABLE IF NOT EXISTS settings (\
    cid INTEGER,\
    uid INTEGER,\
    setting TEXT NOT NULL,\
    value TEXT DEFAULT 'on'\
    )"
    
# -- single values
# -- special table to record individual values
# -- largely to provide a mechanism for db upgrade procedure
db:query "CREATE TABLE IF NOT EXISTS singlevalues (\
    entry TEXT NOT NULL,\
    value TEXT NOT NULL\
    )"    
    
# -- access levels
db:query "CREATE TABLE IF NOT EXISTS levels (\
    cid INTEGER NOT NULL,\
    uid INTEGER NOT NULL,\
    level INTEGER NOT NULL,\
    automode INT NOT NULL DEFAULT 0,\
    added_ts INTEGER NOT NULL,\
    added_bywho TEXT NOT NULL,\
    modif_ts INTEGER NOT NULL,\
    modif_bywho TEXT NOT NULL\
    )"

# -- initialise missing db data
proc db:init {} {
    global botnick
    variable cfg
    variable dbfresh
    variable dbmigrate
    
    set dbfresh 0
    
    db:connect
    set count [db:query "SELECT count(*) FROM users"]
    if {$count eq 0} {
        # -- this indicates a fresh bot install; capture it for db:upgrade
        debug 0 "db:init: \002fresh Armour install detected!\002"
        debug 0 "db:init:"
        debug 0 "db:init: \002INITIALISATION:\002"
        debug 0 "db:init:"
        debug 0 "db:init: \002    /msg $botnick inituser <user> \[account\]\002"
        debug 0 "db:init:"
        debug 0 "db:init: \002    Use your desired bot username as <user>\002"
        debug 0 "db:init: \002    Use your network username as \[account\] for autologin.\002"
        debug 0 "db:init:"
        debug 0 "db:init: \002    This command will only work once, when user database is empty.\002"
        debug 0 "db:init:"
        debug 0 "db:init: \002END INITIALISATION:\002"
        debug 0 "db:init:"
        set dbfresh 1
        # -- set to the current revision
        db:query "INSERT INTO singlevalues (entry,value) VALUES ('revision','$cfg(revision)')"
    }
    db:close
}
db:init; # -- initialise!

db:connect

# -- blacklist & whitelist entries      
db:query "CREATE TABLE IF NOT EXISTS entries (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    cid INTEGER NOT NULL DEFAULT 0,\
    list TEXT NOT NULL,\
    type TEXT NOT NULL,\
    value TEXT NOT NULL,\
    flags INT NOT NULL DEFAULT 0,\
    timestamp INT NOT NULL,\
    modifby TEXT NOT NULL,\
    action TEXT NOT NULL,\
    'limit' TEXT NOT NULL DEFAULT '1:1:1',\
    hits TEXT NOT NULL DEFAULT 0,\
    depends TEXT,\
    reason TEXT NOT NULL\
    )"
    
# -- IDB (information database)
db:query "CREATE TABLE IF NOT EXISTS idb (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    timestamp INTEGER NOT NULL,\
    user_id INTEGER NOT NULL,\
    user TEXT NOT NULL,\
    idb TEXT NOT NULL,\
    level INTEGER DEFAULT '1',\
    sticky TEXT NOT NULL DEFAULT 'N',\
    secret TEXT NOT NULL DEFAULT 'N',\
    addedby TEXT NOT NULL,\
    text TEXT NOT NULL\
    )"
    
# -- user notes
db:query "CREATE TABLE IF NOT EXISTS notes (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    timestamp INTEGER NOT NULL,\
    from_u TEXT NOT NULL,\
    from_id INTEGER NOT NULL,\
    to_u TEXT NOT NULL,\
    to_id INTEGER NOT NULL,\
    note TEXT NOT NULL,\
    read TEXT NOT NULL DEFAULT 'N'\
    )"
              
# -- user greetings
db:query "CREATE TABLE IF NOT EXISTS greets (\
    cid INTEGER NOT NULL,\
    uid INTEGER NOT NULL,\
    greet TEXT NOT NULL\
    )"

# -- topics
# -- list of pre-set channel topics
db:query "CREATE TABLE IF NOT EXISTS topics (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    topic TEXT NOT NULL\
    )"

# -- generic command history log
db:query "CREATE TABLE IF NOT EXISTS cmdlog (\
    timestamp INTEGER,\
    source TEXT NOT NULL,\
    chan TEXT NOT NULL DEFAULT '*',\
    chan_id INTEGER NOT NULL DEFAULT '1',\
    user TEXT NOT NULL,\
    user_id INTEGER,\
    command TEXT NOT NULL,\
    params TEXT,\
    bywho TEXT,\
    target TEXT,\
    target_xuser TEXT,\
    wait INTEGER\
    )"

# -- create trakka table
db:query "CREATE TABLE IF NOT EXISTS trakka (\
    cid INTEGER NOT NULL,\
    type TEXT NOT NULL,\
    value TEXT NOT NULL,\
    score INTEGER NOT NULL DEFAULT '1'\
    )"

# -- providing a mechanism to manage DB upgrade and migration between script versions
proc db:upgrade {} {
    variable cfg
    variable upgrade
    variable dbfresh
    # -- we're going to store a script revision in the DB and the *.tcl
    #    this will allow a means to perform automatic DB upgrades as new verisons get loaded
    #    including DB schema changes; data migrations; new setting insertions etc
    
    # -- cfg(revision) represents the loaded script version; $revision represents db version    
    set revision [db:get value singlevalues entry revision]

    set insert 0;  # -- to track whether to insert or update cfg(version) in DB
    set upgrade 0; # -- to track whether any upgrades were done
        
    # -- safety net to avoid migration if table that only arrived in v4.0 already exists
    db:connect
    catch { db:query "SELECT count(*) FROM levels" } err
    if {$err eq "no such table: levels"} {
        # -- levels table does not exist-- must be a v3.x DB (needs migration)
        set nomigrate 0
    } else {
        if {$revision eq ""} { 
            # -- levels table exists (v4.x or later DB) & no revision stored
            # -- this means the DB is migrated already but we still need to insert revision
            set nomigrate 0
        } else {
            # -- levels table exists (v4.x or later DB) and revision is already stored
            set nomigrate 1
        }
    }
    
    set confrev [cfg:get revision]
    putlog "\002db:upgrade:\002 dbrevision: $revision -- confrev: $confrev -- dbfresh: $dbfresh -- nomigrate: $nomigrate"
    
    if {$revision eq "" && $dbfresh eq 0 && $nomigrate eq 0} {
    
        set upgrade 1;
        
        # -- bot must be on v3.x (the first public release)
        debug 0 "\[@\] Armour: beginning db migration from v3.x"
        
        # -- things to do:
        #      - remove unused columns from users table
        #      - migrate global level data to levels table
        #      - insert global channel (cid=1) into channels table
        #       - add cid column to greets table
        #      - add cid and flags columns to entries table
        #
        # -- unfortunately sqlite doesn't make this easy so temp tables are needed!
        
        set insert 1; # -- to insert cfg(version) into DB (rather than update)
        
        db:connect
        # -- create a temp users table
        debug 0 "db:upgrade: creating new temporary users_new table"
        db:query "CREATE TABLE IF NOT EXISTS users_new (id INTEGER PRIMARY KEY AUTOINCREMENT,user TEXT NOT NULL,\
            xuser TEXT,email TEXT,curnick TEXT,curhost TEXT,lastnick TEXT,lasthost TEXT,\
            lastseen INTEGER,languages TEXT NOT NULL DEFAULT 'EN',pass TEXT);"

        # -- copy the existing users table into the temp table
        debug 0 "db:upgrade: copying relevant data from users table to users_new"
        db:query "INSERT INTO users_new(id,user,xuser,email,curnick,curhost,lastnick,lasthost,lastseen,languages,pass)\
            SELECT id,user,xuser,email,curnick,curhost,lastnick,lasthost,lastseen,languages,pass FROM users;"
        
        # -- migrate data over to levels table
        set rows [db:query "SELECT id,level,automode FROM users"]
        foreach row $rows {
            lassign $row uid level automode
            set added_ts [unixtime]
            set added_bywho [db:escape "Armour (DB migration)"]
            set modif_ts [unixtime]
            set modif_bywho [db:escape "Armour (DB migration)"]
            # -- use global channel for level 500, otherwise use default channel if available
            if {[cfg:get chan:def] ne ""} { set cid [db:get id channels chan [cfg:get chan:def]] } else { set cid 1 }
            if {$level eq 500} { set cid 1 }
            if {$level eq 500 && $cid eq 1 && $uid eq 1} { continue; }; # -- this access has already been inserted on db:init
            debug 0 "db:upgrade: inserting into levels table: cid: $cid -- uid: $uid -- level: $level -- automode: $automode"
            db:query "INSERT INTO levels (cid,uid,level,automode,added_ts,added_bywho,modif_ts,modif_bywho) \
                VALUES ($cid,$uid,$level,'$automode',$added_ts,'$added_bywho',$modif_ts,'$modif_bywho');"    
        }
        
        # -- drop the old user table
        debug 0 "db:upgrade: dropping old users table"
        db:query "DROP TABLE users;"
        
        # -- rename the temp table to users
        debug 0 "db:upgrade: renaming users_new table to users"
        db:query "ALTER TABLE users_new RENAME TO users;"
        
        # -- create global channel
        # -- use config file default mode if exists (as it might get removed in future)
        #if {[info exists cfg(mode)]} { set mode [cfg:get mode *] } else { set mode "on" }
        #debug 0 "db:upgrade: inserting global channel into channels table"
        #db:query "INSERT INTO channels (chan,mode) VALUES ('*','$mode')"
        
        # -- create new temporary greets table (with cid column)
        debug 0 "db:upgrade: creating new temporary greets_new table"
        db:query "CREATE TABLE IF NOT EXISTS greets_new (cid INTEGER NOT NULL, uid INTEGER NOT NULL, greet TEXT NOT NULL);"
        
        # -- migrate data over to new greets table
        set rows [db:query "SELECT uid,greet FROM greets"]
        foreach row $rows {
            lassign $row uid greet
            set db_greet [db:escape $greet]
            # -- use default channel, if set; otherwise, global
            if {[cfg:get chan:def] ne ""} { set cid [db:get id channels chan [cfg:get chan:def]] } else { set cid 1 }
            debug 0 "db:upgrade: inserting into greets_new table: cid: $cid -- uid: $uid -- greet: $greet"
            db:query "INSERT INTO greets_new (cid,uid,greet) VALUES ($cid,$uid,'$db_greet');"
        }
        
        # -- drop the old greets table
        debug 0 "db:upgrade: dropping old greets table"
        db:query "DROP TABLE greets;"
        
        # -- rename the temp greets_new table to greets
        debug 0 "db:upgrade: renaming greets_new table to greets"
        db:query "ALTER TABLE greets_new RENAME TO greets;"
        
        # -- create new temporary entries table
        debug 0 "db:upgrade: creating new temporary entries_new table"
        db:query "CREATE TABLE IF NOT EXISTS entries_new ( id INTEGER PRIMARY KEY AUTOINCREMENT, cid INTEGER NOT NULL DEFAULT 0, \
            list TEXT NOT NULL, type TEXT NOT NULL, value TEXT NOT NULL, flags INT NOT NULL DEFAULT 0, \
            timestamp INT NOT NULL, modifby TEXT NOT NULL, action TEXT NOT NULL, 'limit' TEXT NOT NULL DEFAULT '1:1:1', \
            hits TEXT NOT NULL DEFAULT 0, reason TEXT NOT NULL );"
            
        set rows [db:query "SELECT id,list,type,value,timestamp,modifby,action,'limit',hits,reason FROM entries"]
        foreach row $rows {
            lassign $row id list type value timestamp modifby action limit hits reason
            set db_value [db:escape $value]
            set db_modifby [db:escape $modifby]
            set db_reason [db:escape $reason]
            # -- TODO: should all entries become global, or enter as global?!
            # -- use default channel, if set; otherwise, global
            if {[cfg:get chan:def] ne ""} { set cid [db:get id channels chan [cfg:get chan:def]] } else { set cid 1 }
            debug 0 "db:upgrade: inserting into entries_new table: cid: $cid -- id: $id -- list: $list -- type: $type value: $value"
            db:query "INSERT INTO entries_new (id,cid,list,type,value,timestamp,modifby,action,'limit',hits,reason) \
                VALUES ($id,$cid,'$list','$type','$db_value','$timestamp','$db_modifby','$action','$limit',$hits,'$db_reason');"
        }
        
        # -- drop the old entries table
        debug 0 "db:upgrade: dropping old entries table"
        db:query "DROP TABLE entries;"
        
        # -- rename the temp entries_new table to entries
        debug 0 "db:upgrade: renaming entries_new table to entries"
        db:query "ALTER TABLE entries_new RENAME TO entries;"
                
        db:close
        
    } elseif {$revision eq [cfg:get revision *]} {
        debug 0 "\[@\] Armour: no upgrade steps to perform! (revision match: $revision)"
        unset dbfresh
        return;
    } 
        
    # -- this is where we check for incremental upgrades between versions
    #    include steps required between releases to cater to small and big upgrades
    
    if {$revision < "2020071700" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        # -- proving process to edit cmdlog
        db:connect
        # -- create a temp cmdlog_new table
        debug 0 "db:upgrade: creating new temporary cmdlog_new table"
        db:query "CREATE TABLE IF NOT EXISTS cmdlog_new (timestamp INTEGER, source TEXT NOT NULL, chan TEXT NOT NULL DEFAULT '*', \
            chan_id INTEGER NOT NULL DEFAULT '1', user TEXT NOT NULL, user_id INTEGER, command TEXT NOT NULL, params TEXT, \
            bywho TEXT, target TEXT, target_xuser TEXT, wait INTEGER);"
        
        # -- copy the existing cmdlog table data into the temp table
        debug 0 "db:upgrade: copying relevant data from cmdlog table to cmdlog_new"
        db:query "INSERT INTO cmdlog_new(timestamp,source,user,user_id,command,params,bywho,target,target_xuser,wait) \
            SELECT timestamp,source,user,user_id,command,params,bywho,target,target_xuser,wait FROM cmdlog;"
                
        # -- drop the old cmdlog table
        debug 0 "db:upgrade: dropping old cmdlog table"
        db:query "DROP TABLE cmdlog;"
        
        # -- rename the temp cmdlog_new table to cmdlog
        debug 0 "db:upgrade: renaming cmdlog_new table to cmdlog"
        db:query "ALTER TABLE cmdlog_new RENAME TO cmdlog;"
        
        # -- update all logs to the default channel, except for special generic/global commands
        if {[info exists cfg(chan:def)]} {
            set chan [cfg:get chan:def *]
            set db_chan [db:escape $chan]
            set cid [db:get id channels chan $chan]
            debug 0 "db:upgrade: updating all non-generic and non-global commands to default channel ($chan)"
            db:query "UPDATE cmdlog SET chan='$db_chan',chan_id=$cid WHERE lower(command) NOT IN ('addchan', 'asn', 'chanlist', 'cmds', \
                'conf', 'country', 'die', 'do', 'help', 'ipqs', 'jump', 'load', 'newuser', 'queue', 'register', 'rehash', 'reload', \
                'remchan', 'restart', 'save', 'scan', 'scanport', 'scanrbl', 'showlog', 'status', 'userlist', 'verify', 'version', \
                'login', 'newpass', 'logout');"
        }
        db:close
    }

    # -- make quotes chan specific
    # -- note that previous IDs will have changed (if any ever got deleted)
    if {$revision < "2021011700" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        # -- proving process to edit quotes
        db:connect
        # -- create a temp quotes_new table
        debug 0 "db:upgrade: copying relevant data from quotes table to quotes_new"
        db:query "CREATE TABLE quotes_new ( id INTEGER PRIMARY KEY AUTOINCREMENT, cid INTEGER NOT NULL DEFAULT '1', \
        nick TEXT NOT NULL, uhost TEXT NOT NULL, user TEXT, timestamp INT NOT NULL, quote TEXT NOT NULL )"

        # -- only migrate if quotes table exists (was optional plugin in v3.x)
        catch { db:query "SELECT count(*) FROM quotes" } err
        if {$err eq "no such table: quotes"} {
            # -- this indicates a fresh bot install; capture it for db:upgrade
            debug 0 "db:upgrade: \002quotes table does not exist, avoiding migration!\002"
        } else {
            # -- copy the existing cmdlog table data into the temp table
            debug 0 "db:upgrade: copying relevant data from quotes table to quotes_new"
            db:query "INSERT INTO quotes_new(nick,uhost,user,timestamp,quote) SELECT nick,uhost,user,timestamp,quote FROM quotes;"

            # -- update the channel ID on all existing quotes, to the default channel
            set defchan [cfg:get chan:def]
            set cid [db:get id channels chan $defchan]
            debug 0 "db:upgrade: updating chanID on all existing quotes in quotes_new to default channel (chan: $defchan -- cid: $cid)"
            db:query "UPDATE quotes_new SET cid=$cid";
                    
            # -- drop the old quotes table
            debug 0 "db:upgrade: dropping old quotes table"
            db:query "DROP TABLE quotes;"
        }        
        # -- rename the temp quotes_new table to quotes
        debug 0 "db:upgrade: renaming quotes_new table to quotes"
        db:query "ALTER TABLE quotes_new RENAME TO quotes;"
        db:close
    }

    # -- add dependencies to whitelist & blacklists
    if {$revision < "2021052600" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        # -- proving process to edit quotes
        db:connect

        # -- create new temporary entries table
        debug 0 "db:upgrade: creating new temporary entries_new table (depends)"
        db:query "CREATE TABLE IF NOT EXISTS entries_new ( id INTEGER PRIMARY KEY AUTOINCREMENT, cid INTEGER NOT NULL DEFAULT 0, \
            list TEXT NOT NULL, type TEXT NOT NULL, value TEXT NOT NULL, flags INT NOT NULL DEFAULT 0, \
            timestamp INT NOT NULL, modifby TEXT NOT NULL, action TEXT NOT NULL, 'limit' TEXT NOT NULL DEFAULT '1:1:1', \
            hits TEXT NOT NULL DEFAULT 0, depends TEXT, reason TEXT NOT NULL );"
            
        set rows [db:query "SELECT id,cid,list,type,value,timestamp,modifby,action,'limit',hits,reason FROM entries"]
        foreach row $rows {
            lassign $row id cid list type value timestamp modifby action limit hits reason
            set db_value [db:escape $value]
            set db_modifby [db:escape $modifby]
            set db_reason [db:escape $reason]
            # -- TODO: should all entries become global, or enter as global?!
            # -- use default channel, if set; otherwise, global
            if {[cfg:get chan:def] ne ""} { set cid [db:get id channels chan [cfg:get chan:def]] } else { set cid 1 }
            debug 0 "db:upgrade: inserting into entries_new table: cid: $cid -- id: $id -- list: $list -- type: $type value: $value"
            db:query "INSERT INTO entries_new (id,cid,list,type,value,timestamp,modifby,action,'limit',hits,reason) \
                VALUES ($id,$cid,'$list','$type','$db_value','$timestamp','$db_modifby','$action','$limit',$hits,'$db_reason');"
        }
        
        # -- drop the old entries table
        debug 0 "db:upgrade: dropping old entries table"
        db:query "DROP TABLE entries;"
        
        # -- rename the temp entries_new table to entries
        debug 0 "db:upgrade: renaming entries_new table to entries"
        db:query "ALTER TABLE entries_new RENAME TO entries;"
                
        db:close
    }

    # -- add registration history to users
    if {$revision < "2021061100" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        db:connect
        # -- alter users table
        debug 0 "db:upgrade: altering users table (registration history)"
        db:query "ALTER TABLE users ADD COLUMN register_ts INT"
        db:query "ALTER TABLE users ADD COLUMN register_by TEXT"

        db:close
    }

    # -- fix old bug re: 'limit' column name & entry
    if {$revision < "2021062600" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        db:connect
        # -- alter users table
        debug 0 "db:upgrade: fixing 'limit' entry value"
        db:query "UPDATE entries SET 'limit'='1:1:1' WHERE 'limit'='limit'"
        db:close
    }

    # -- fix old bug re: 'limit' column name & entry
    if {$revision < "2021080401" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        db:connect
        # -- alter users table
        debug 0 "db:upgrade: adding vote score column to quotes table"
        db:query "ALTER TABLE quotes ADD COLUMN score INTEGER DEFAULT '0'"
        db:close
    }

    # -- file structure changes
    if {$revision < "2022121100" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        catch { exec rm ./armour/plugins/ext/libdronebl.tcl };   # -- moved to packages/
        catch { exec rm ./armour/plugins/ext/github.tcl };       # -- moved to packages/
        #catch { exec rm -rf ./armour/plugins/ext };             # -- delete later, when onetimepass.tcl is removed
    }

    # -- remove unique constraint on 'curnick' and 'xuser' columns
    if {$revision < "2022121200" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        db:connect
        debug 0 "db:upgrade: creating new temporary users_new table (removing unique constraint on curnick and xuser)"
        db:query "CREATE TABLE users_new (\
            id INTEGER PRIMARY KEY AUTOINCREMENT,\
            user TEXT UNIQUE NOT NULL,\
            xuser TEXT,\
            email TEXT,\
            curnick TEXT,\
            curhost TEXT,\
            lastnick TEXT,\
            lasthost TEXT,\
            lastseen INTEGER,\
            languages TEXT NOT NULL DEFAULT 'EN',\
            pass TEXT\,\
            register_ts INT,\
            register_by TEXT\
            )"

        debug 0 "db:upgrade: copying users into temporary users_new table"
        db:query "INSERT INTO users_new SELECT * FROM users"

        debug 0 "db:upgrade: dropping old users table"
        db:query "DROP TABLE users";  # -- drop the old users table
        
        debug 0 "db:upgrade: renaming users_new table to users"
        db:query "ALTER TABLE users_new RENAME TO users;"
        db:close
    }

    # -- remove unique constraint on 'curnick' and 'xuser' columns
    if {$revision < "2022121400" && $dbfresh eq 0} {
        if {!$upgrade} { debug 0 "\[@\] Armour: beginning db migration from $revision to $confrev" }
        set upgrade 1;
        db:connect
        db:query "CREATE TABLE channels_new (\
        id INTEGER PRIMARY KEY AUTOINCREMENT,\
        chan TEXT UNIQUE NOT NULL,\
        reg_uid INTEGER,\
        reg_bywho TEXT,\
        reg_ts INTEGER,\    
        mode TEXT DEFAULT 'on'\
        )"

        debug 0 "db:upgrade: copying channels into temporary channels_new table"
        db:query "INSERT INTO channels_new (id,chan,mode) SELECT id,chan,mode FROM channels"

        debug 0 "db:upgrade: dropping old channels table"
        db:query "DROP TABLE channels";  # -- drop the old channels table
        
        debug 0 "db:upgrade: renaming channels_new table to channels"
        db:query "ALTER TABLE channels_new RENAME TO channels;"
        db:close
    }

    # -- update the DB revision entry
    db:connect
    set rev [cfg:get revision *]
    if {$insert} {
        db:query "INSERT INTO singlevalues (entry,value) VALUES ('revision','$rev')"
        debug 0 "\[@\] Armour: inserted new revision into DB: $rev"
    } else {
        if {$revision eq ""} { set xtra ""} { set xtra "(old: $revision)" }
        db:query "UPDATE singlevalues SET value='[cfg:get revision *]' WHERE entry='revision'"
        debug 0 "\[@\] Armour: updated new revision in DB: $rev $xtra"        
    }
    #db:close
    unset dbfresh
    if {$upgrade} { debug 0 "\[@\] Armour: upgrade complete! (revision: $rev)" }
}

# -- run the upgrade
db:upgrade

variable upgrade; # -- only log the below if no upgrade ran
if {!$upgrade} { putlog "\[@\] Armour: loaded database upgrade mechanism." }

# -- load the blacklist & white entries into memory
proc db:load {} {   
    variable entries;  # -- dict: blacklist & whitelist entries    
    variable flud:id;  # -- the id of a given cumulative pattern (by method,value)
    
    #debug 4 "db:load: started"

    # -- flush existing from memory 
    if {[info exists entries]    }   { unset entries   }
    if {[info exists flud:id]    }   { unset flud:id   }
    if {[info exists flud:count] }   { unset flud:hits }
    
    set entries [list]; # -- safety net; when there are 0 entries in db

    # -- sqlite3 database
    db:connect          
    set results [db:query "SELECT id, cid, list, type, value, flags, timestamp, modifby, \
        action, \"limit\", hits, depends, reason FROM entries"]
    db:close
    set wcount 0; set bcount 0;
    foreach row $results {
        #putlog "row: $row"
        lassign $row id cid list method value flags timestamp modifby action limit hitnum depends
        set reason [join [lrange $row 12 end]]
        # -- list type specific handling
        if {$list eq "W"} { set type "white"; incr wcount } \
        elseif {$list eq "B"} { set type "black"; incr bcount }
        set chan [join [db:get chan channels id $cid]]
        
        dict set entries $id id $id
        dict set entries $id cid $cid
        dict set entries $id type $type
        dict set entries $id chan $chan
        dict set entries $id method $method
        dict set entries $id value $value
        dict set entries $id flags $flags
        dict set entries $id ts $timestamp
        dict set entries $id modifby $modifby
        dict set entries $id action $action
        dict set entries $id limit $limit
        dict set entries $id hits $hitnum
        dict set entries $id depends $depends
        dict set entries $id reason $reason
        
        foreach flag {noident onlykick nochans manual captcha disabled onlysecure silent ircbl notsecure} {
            # -- get flag integer
            if {$flags eq 0} { 
                set val 0;
            } else {
                set int [getFlag $flag]
                if {($int & $flags) eq $int} { set val 1 } else { set val 0 }; # -- on or off
            }
            debug 5 "db:load: type: $type -- id: $id -- flag: $flag -- val: $val"
            dict set entries $id $flag $val; # -- set a dict entry for each flag
        }
                
        debug 3 "db:load: type: $type -- id: $id -- chan: $chan -- chanid: $cid -- method: $method -- value: $value"
        
        # -- track the ids of cumulative patterns
        if {$limit != "1:1:1" && $limit != ""} { set flud:id($method,$value) $id; set flud:hits($id) $hitnum };
    }    
    debug 0 "db:load: loaded $wcount whitelist and $bcount blacklist entries into memory"
}

# -- add a blacklist or whitelist entry
proc db:add {list chan method value modifby action limit reason} {
    variable entries;  # -- dict: blacklist and whitelist entries
    variable flud:id;  # -- the id of a given cumulative pattern (by chan,method,value)
    
    set reason [join $reason]
    set ts [clock seconds]
    
    # -- always do SQL insert first and use that last row ID (keeping memory in sync with db)
    db:connect
    set db_value [db:escape $value]
    set db_modifby [db:escape $modifby]
    set db_reason [db:escape $reason]
    set db_chan [string tolower [db:escape $chan]]
    set chanid [db:get id channels chan $chan]
    db:query "INSERT INTO entries (list, cid, type, value, timestamp, modifby, action, \"limit\", reason) \
        VALUES ('$list', '$chanid', '$method', '$db_value', '$ts', '$db_modifby', '$action', '$limit', '$db_reason')" 
    set id [db:last:rowid]
    db:close

    # -- list type specific handling
    if {$list eq "W"} { set type "white"; set llist "whitelist" } \
    elseif {$list eq "B"} { set type "black"; set llist "blacklist" }
    
    dict set entries $id id $id    
    dict set entries $id cid $chanid
    dict set entries $id type $type
    dict set entries $id chan $chan
    dict set entries $id method $method
    dict set entries $id value $value
    dict set entries $id flags 0
    dict set entries $id noident 0;    # -- flag:   1
    dict set entries $id onlykick 0;   # -- flag:   2
    dict set entries $id nochans 0;    # -- flag:   4
    dict set entries $id manual 0;     # -- flag:   8
    dict set entries $id captcha 0;    # -- flag:  16
    dict set entries $id disabled 0;   # -- flag:  32
    dict set entries $id onlysecure 0; # -- flag:  64
    dict set entries $id silent 0;     # -- flag: 128
    dict set entries $id ircbl 0;      # -- flag: 256
    dict set entries $id notsecure 0;  # -- flag: 512
    dict set entries $id ts $ts
    dict set entries $id modifby $modifby
    dict set entries $id action $action
    dict set entries $id limit $limit
    dict set entries $id hits 0
    dict set entries $id depends ""
    dict set entries $id reason [join [split $reason]]
    
    # -- track the ids of cumulative patterns
    if {$limit ne "1:1:1" && $limit ne ""} { set flud:id($chan,$method,$value) $id };
    
    debug 0 "db:add: added $value $method $llist entry ([dict size $entries] total list entries)"
    
    # -- return the ID
    return $id
}

# -- add a blacklist or whitelist entry
proc db:rem {id} {
    variable entries;   # -- dict: blacklist and whitelist entries
    variable flud:id;   # -- the id of a given cumulative pattern (by method,value)
    
    set list [dict get $entries $id type]
    set method [dict get $entries $id method]
    set value [dict get $entries $id value]
    set chan [dict get $entries $id chan]
    set entries [dict remove $entries $id]; # -- remove entry!
        
    db:connect
    db:query "DELETE FROM entries WHERE id='$id'" 
    db:close
        
    if {[info exists flud:id($chan,$method,$value)]} { unset flud:id($chan,$method,$value) };

    if {$list eq "white"} { set llist "whitelist" } \
    elseif {$list eq "black"} { set llist "blacklist" } \
    elseif {$list eq "reply"} { set llist "replylist" }
    
    set count [dict size $entries]
    
    debug 0 "db:rem: removed $value $method $llist entry ($count list entries remaining)"
    
    return
}


# -- load the channels into memory
proc db:load:chan {} {   
    variable chan:id;      # -- the id of a registered channel (by chan)
    variable chan:chan;    # -- the name of a registered channel (by chan)
    variable chan:chan:id; # -- the name of a registered channel (by id)
    variable chan:mode;    # -- state: the operational mode of a registered channel (by chan)
    variable chan:modeid;  # -- state: the operational mode of a registered channel (by id)
    
    variable dbchans;      # -- dict to store channel db data
    
    debug 2 "db:load:chan: started"

    # -- flush existing from memory 
    if {[info exists chan:id]     } { unset chan:id     }
    if {[info exists chan:chan]   } { unset chan:chan   }
    if {[info exists chan:mode]   } { unset chan:mode   }
    if {[info exists chan:modeid] } { unset chan:modeid }

    if {[info exists dbchans]} { unset dbchans }
    

    # -- sqlite3 database
    db:connect          
    set results [db:query "SELECT id,chan FROM channels"]
    set settings [db:query "SELECT setting FROM settings WHERE cid !='' GROUP BY setting"]; # -- get unique setting names
    db:close
    set count 0;
    foreach row $results {
        lassign $row id chan
        set mode [db:get value settings setting "mode" cid $id]
        
        # -- old structure
        # -- TODO: remove these old remnants
        set chan:id([string tolower $chan]) $id
        set chan:chan($id) $chan
        set chan:mode([string tolower $chan]) $mode
        set chan:modeid($id) $mode
        
        # -- new dict structure
        dict set dbchans $id id $id
        dict set dbchans $id chan $chan
        foreach set $settings {
            dict set dbchans $id $set [db:get value settings setting $set cid $id]; # -- intelligently set all channel settings
        }
        
        debug 3 "db:load:chan: id: $id -- chan: $chan -- mode: $mode"
        incr count
    }
    
    debug 0 "db:load:chan: loaded $count channels into memory"
}

# -- quick function to obtain array values
# this method is especially important due to : value in array names
# use a case insensitive fetch to be safe
proc get:val {var val} {
    variable $var

    # -- handle special regexp chars
    set valexp $val
    regsub -all {\*} $valexp "\\*" valexp;
    regsub -all {\+} $valexp "\\+" valexp;
    regsub -all {\?} $valexp "\\?" valexp;
    regsub -all {\$} $valexp "\\$" valexp;
    regsub -all {\^} $valexp "\\^" valexp;
    regsub -all {\[} $valexp {\\[} valexp;
    regsub -all {\]} $valexp {\\]} valexp;
    regsub -all {\#} $valexp {\\#} valexp;
    #regsub -all {\{} $valexp {\\{} valexp;
    #regsub -all {\}} $valexp {\\}} valexp;

    set exp "(?i)^\\{?$valexp\\}?$"
    set v [join [array names $var -regexp $exp]]
    set v [lindex $v 0]
    if {![info exists [subst $var]($v)] || $v eq ""} { return "" }
    set res [set [subst $var]($v)]

    if {$var ne "data:bans" && $var ne "data:kicks" && $var ne "scan:list"} { 
        debug 5 "get:val: returned: var: $var -- val: $val -- result: $res" 
    }
    return $res
}

# -- compare blacklist & whitelist entry flag values (bitwise)
proc isFlag {dbflags flag} {
    # -- entry flags:
    #      0   : none
    #      1   : noident
    #      2   : onlykick
    #      4   : nochans
    #      8   : manual
    #      16  : captcha
    #      32  : disabled
    #      64  : onlysecure
    #     128  : silent
    #     256  : ircbl
    #     512  : notsecure
    switch -- $flag {
      none       { set int 0   }
      noident    { set int 1   }
      onlykick   { set int 2   }
      nochans    { set int 4   }
      manual     { set int 8   }
      captcha    { set int 16  }
      disabled   { set int 32  }
      onlysecure { set int 64  }
      silent     { set int 128 }
      silent     { set int 256 }
      notsecure  { set int 512 }
      default    { return 0    }
    }
    if {($int & $dbflags)} { return 1 } else { return 0 }
}

proc getFlag {flag} {
    # -- entry flags:
    #      0   : none
    #      1   : noident
    #      2   : onlykick
    #      4   : nochans
    #      8   : manual
    #      16  : captcha
    #      32  : disabled
    #      64  : onlysecure
    #     128  : silent
    #     256  : ircbl
    #     512  : notsecure
    switch -- $flag {
      none       { set int 0   }
      noident    { set int 1   }
      onlykick   { set int 2   }
      nochans    { set int 4   }
      manual     { set int 8   }
      captcha    { set int 16  }
      disabled   { set int 32  }
      onlysecure { set int 64  }
      silent     { set int 128 }
      ircbl      { set int 256 }
      notsecure  { set int 512 }
      default    { set 0       }
    }
    return $int
}

# -- close sqlite connection        
db:close

debug 0 "\[@\] Armour: loaded sqlite3 database functions."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-05_hmac.tcl
#
# Pure TCL implementation of HOTP and TOP algorithms
#
# API based on the onetimepass Python library:
#     https://github.com/tadeck/onetimepass
#
# ------------------------------------------------------------------------------------------------

package require sha1
package require sha256

namespace eval onetimepass {
    # Set up state
    variable HOTP_AND_VALUE 0x7FFFFFFF

    
# HMAC-based one time password (HOTP) as specified in RFC 4226
# HOTP(K, C) = Truncate(HMAC-SHA-1(K,C))
#
#    :param key: string used to key the HMAC, aka, the secret
#    :type key: string
#
#    :param interval_no: incrementing interval number to use for
#                    producing the token
#                    The C in HOTP(K, C)
#    :type interval_no: unsigned int
#
#    :param digest: which HMAC digest to use
#                currently only supports sha1 or sha256
#                defaults to sha1
#    :type digest: string from the list {sha1 sha2}
#
#     :param token_length: how long the resulting HOTP token will be
#                      defaults to 6 as recommended in the RFC
#    :type token_length: int
#
#    :return: generated HOTP token
#    :rtype: 0 padded string of the HOTP int token
#
#
proc get_hotp {key interval_no {digest sha1} {token_length 6}} {
    variable HOTP_AND_VALUE

    # The message passed to the HMAC is the big-endian 64-bit
    # unsigned int representation of the interval_no
    set message [binary format Wu $interval_no]

    # Obtain the HMAC as a string of hex digits using the key and the message
    set hmac_digest [${digest}::hmac $key $message]

    # Obtain the starting offset into the HMAC to use for truncation
    # The starting offset is obtained by grabbing the last byte of the
    # of the HMAC, then bitwise-AND'ing it with 0xF
    # offset & 0xF is multiplied by 2 b/c it is a string of hex digits
    # and not the raw bytes
    scan [string range $hmac_digest end-1 end] %x offset
    set offset [expr {($offset & 0xF) * 2}]

    # For truncation, grab four bytes, starting at offset
    # It is offset + 7 b/c hmac_digest is a string of hex
    # digits and not raw bytes
    set four_bytes [binary format H* [string range $hmac_digest $offset $offset+7]]

    # Once the last four bytes are extracted, binary scan converts
    # the raw bytes into an unsigned 32-bit big-endian integer
    binary scan $four_bytes Iu1 token_base

    # Penultimate step: bitwise-AND token_base with 0x7FFFFFFF
    set token_base [expr {$token_base & $HOTP_AND_VALUE}]

    # Lastly, use mod to shorten the token to passed in length
    set token [expr {$token_base % 10**$token_length}]

    # 0 pad the token so it's exactly $token_length characters
    return [format "%0${token_length}d" $token]
}

#
#
# Time-based one time password (TOTP) as specified in RFC 6238
# TOTP(K, T) = Truncate(HMAC-SHA-1(K,T))
# Same as HOTP but with C replaced by T, a time factor
#
# This implementation does not support setting a different value for T0.
# It always uses the Unix epoch as the initial value to count the time steps.
#
#    :param key: string used to key the HMAC, aka, the secret
#    :type key: string
#
#    :param interval: Time interval in seconds that a TOTP token
#                  is valid
#                  Default is 30 as recommended by the RFC
#                  See Section 5.2 for futher discussion
#    :type interval: unsigned int
#
#    :param digest: which HMAC digest to use
#                currently only supports sha1 or sha256
#                defaults to sha1
#    :type digest: string from the list {sha1 sha2}
#
#     :param token_length: how long the resulting TOTP token will be
#                      defaults to 6
#    :type token_length: unsigned int
#
#    :return: generated TOTP token
#    :rtype: 0 padded string of the TOTP token
#
#
proc get_totp {key {interval 30} {digest sha1} {token_length 6}} {
    # TOTP is HOTP(K, C) with C replaced by T, a time factor
    set interval_no [expr [clock seconds] / $interval]

    return [get_hotp $key $interval_no $digest $token_length]
}

#
#
# Check if a given HOTP token is valid for the key passed in. Returns
# the interval number that was successful, or -1 if not found.
#
#   :param token: token being checked
#   :type token: string
#
#   :param key: key, or secret, for which token is checked
#   :type key: str
#
#   :param last: last used interval (start checking with next one)
#             To check the 0'th interval, pass -1 for last
#   :type last: int
#
#   :param trials: number of intervals to check after 'last'
#               defaults to 1000
#   :type trials: unsigned int
#
#   :param digest: which HMAC digest to use
#               currently only supports sha1 or sha256
#               defaults to sha1
#   :type digest: string from the list {sha1 sha2}
#
#   :param token_length: length of the token (6 by default)
#   :type token_length: unsigned int
#
#   :return: interval number, or -1 if check unsuccessful
#   :rtype: int
#
#
proc valid_hotp {token key last {trials 1000} {digest sha1} {token_length 6}} {
    # Basic sanity check before looping
    if {![string is digit $token] || [string length $token] ne $token_length} {
        return -1
    }

    # Check each interval no
    for {set i 0} {$i <= $trials} {incr i} {
        set interval_no [expr $last + $i + 1]
        if {[get_hotp $key $interval_no $digest $token_length] eq $token} {
            return $interval_no
        }
    }

    return -1
}

#
#
# Check if a given TOTP token is valid for a given HMAC key
#
#   :param token: token which is being checked
#   :type token: int or str
#
#   :param key: HMAC secret key for which the token is being checked
#   :type key: str
#
#   :param digest: which HMAC digest to use
#               currently only supports sha1 or sha256
#               defaults to sha1
#   :type digest: string from the list {sha1 sha2}
#
#   :param token_length: length of the token (6 by default)
#   :type token_length: int
#
#   :param interval: length in seconds of TOTP interval
#                (30 by default)
#   :type interval: int
#
#   :return: 1 if valid, 0 otherwise
#   :rtype: int
#
#
proc valid_totp {token key {interval 30} {digest sha1} {token_length 6}} {
    set calculated_token [get_totp $key $interval $digest $token_length]
    return [expr {$calculated_token eq $token}]
}

};
# -- end namespace



# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-06_cidr.tcl
#
# CIDR matching functions
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


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
    # -- disable IPv6 for now (TODO cidr:match)
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

}
# -- end namespace



# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-07_geo.tcl
# 
# asn & country lookup functions
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# -- convert ip address to asn
proc geo:ip2asn {ip} {

    # -- reverse the IP
    if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
        # -- not valid IP
        return;
    }
    set revip "$d.$c.$b.$a"  

    # -- asynchronous lookup via coroutine  
    set answer [dns:lookup $revip.origin.asn.cymru.com TXT]
    
    # -- example:
    # 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
    
    if {$answer == "NULL" || $answer == ""} { return; }
    set string [split $answer "|"]
    set asn [lindex $string 0]
    regsub -all { } $asn {} asn
    debug 3 "\002geo:ip2asn\002: ASN for IP $ip is: $asn"
    return $asn
}

# -- convert ip to country
proc geo:ip2country {ip} {
    # -- reverse the IP
    if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
        # -- not valid IP
        # -- TODO: geo:ip2country IPv6 support
        return;
    }
    set revip "$d.$c.$b.$a"  
    # -- asynchronous lookup via coroutine
    set answer [dns:lookup $revip.origin.asn.cymru.com TXT]
    
    # -- example:
    # 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
    
    if {$answer == "NULL" || $answer == ""} { return; }
    set string [split $answer "|"]
    set country [lindex $string 2]
    regsub -all { } $country {} country
    debug 3 "\002geo:ip2asn\002: country for IP $ip is: $country"
    return $country
}

# -- convert IP to long format
proc geo:ip2int {ip} {
    set res 0
    foreach i [split $ip .] {set res [expr {$res<<8 | $i}]}
    return $res
}


putlog "\[@\] Armour: loaded geolocation tools."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-08_portscan.tcl
#
# acynhronous port scanning functions
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------



proc port:scan {ip {ports ""} {conns ""} {timeout ""}} {
    portscan $ip $ports $conns $timeout
}

# -- syntax: portscan IP [list PORT1 PORT2 ..] maxconns timeout_in_ms
# ex: portscan 127.0.0.1 {80 8080 3128 22 21 23 119} 3 5000
proc portscan {ip {ports ""} {conns ""} {timeout ""}} {
    variable scan:ports;  # -- array that stores the ports to scan (by port)
    set start [clock clicks]
    
    set myconns 0
    set openports [list]
    set notimeoutports [list]
    set portlist ""
    
    if {$ports eq ""} {
        # -- scan all ports in array
        foreach entry [array names scan:ports] {
            append portlist "$entry "
        }
        set ports [string trimright $portlist " "]
    } else { set ports $ports }

    if {$conns eq ""} { set conns [llength [array names scan:ports]] }
    if {$timeout eq ""} { set timeout "1000" }

    debug 2 "portscan: scanning: $ip ports: $ports conns: $conns timeout: $timeout"

    foreach port $ports {
        set s [socket -async $ip $port]
        fileevent $s writable [list [info coroutine] [list $s $port open]]
        after $timeout catch [list [list [info coroutine] [list $s $port timeout]]]
        incr myconns
        if {$myconns < $conns} {
            continue
        } else {
            portscan:get:feedback
            portscan:assign:state
        }
    }
    while {$myconns} {
        portscan:get:feedback
        portscan:assign:state
    }

    set fullopen [list]
    foreach i $openports {
        lappend fullopen "${i}/tcp ([get:val scan:ports $i])"
    }
    set fullopen [join [lsort $fullopen]]

    set runtime [runtime]

    if {$fullopen eq ""} { debug 2 "arm:port:scan: no open ports on $ip ($runtime)" } \
    else { debug 1 "portscan: open ports: $fullopen ($runtime)" }

    return $fullopen;

}

# -- helper function 1 (uplevel executes in callers stack - just code grouping)
proc portscan:get:feedback {} {
    uplevel 1 {
        lassign [yield] s port state
        incr myconns -1
        while {$state eq "timeout" && $port in $notimeoutports} {
            lassign [yield] s port state
        }
    }
}

# -- helper function 2 (uplevel executes in callers stack - just code grouping)
proc portscan:assign:state {} {
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

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-09_xauth.tcl
#
# cservice authentication procedure
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- username
# note: we set this in the main config now
# set cfg(auth:user) "USERNAME"

# -- password
# note: we set this in the main config now
# set cfg(auth:pass) "PASSWORD"

# -- binds
bind evnt - connect-server arm::auth:server:connect
bind evnt - init-server arm::auth:server:init


if {[info commands "*auth:success"] eq ""} {
    if {[string tolower [cfg:get auth:mech *]] eq "gnuworld"} {
        # -- gnuworld auth service
        bind notc - "AUTHENTICATION SUCCESSFUL*" arm::auth:success
        bind notc - "Sorry, You are already authenticated as *" arm::auth:success
        bind notc - "AUTHENTICATION FAIL*" arm::auth:fail
    } elseif {[string tolower [cfg:get auth:mech *]] eq "nickserv"} {
        # -- nickserv auth service
        # Freenode:
        bind notc - "You are now identified for *" arm::auth:success
        # TODO: freenode auth failure notice
    
        # Anope NickServ responses: https://github.com/atheme/atheme/blob/master/modules/nickserv/identify.c
        bind notc - "You are now identified for *" arm::auth:success
        bind notc - "You are now logged in as *" arm::auth:success
        bind notc - "Sorry, You are already authenticated as *" arm::auth:success
        bind notc - "You cannot log in as *" arm::auth:fail
        bind notc - "You cannot identify to *" arm::auth:fail
        bind notc - "Password authentication is disabled *" arm::auth:fail
        bind notc - "You are already logged in as *" arm::auth:fail
        bind notc - "Invalid password for *" arm::auth:fail
    }
}

set auth:succeed 0;  # -- stores whether auth has succeeded or not

# -- procedures
 
# -- ran just prior to connecting to server
proc auth:server:connect {type} {
    global nick
    variable cfg
    variable data:authnick;  # -- stores the nickname to restore after login
    
    if {[cfg:get auth:user *] != "" && [cfg:get auth:pass *] != ""} {
        if {[cfg:get auth:rand *]} {
            set data:authnick $nick
            set nick "${::uservar}-[randpass 4 "ABCDEFGHIJKLMNOP0123456789"]"
            debug 0 "\[@\] Armour: set random nickname of $nick until authenticated."
        }
    
        if {[cfg:get auth:hide *]} {
            debug 0 "\[@\] Armour: staying out of channels until authed with [cfg:get auth:serv:nick *]..."
            foreach chan [channels] {
                channel set $chan +inactive
            }
        }
    }
}

# -- connected to server
proc auth:server:init {type} {
    global botnick
    variable cfg
    if {[cfg:get auth:user *] ne "" && [cfg:get auth:pass *] ne ""} {
        # -- set umode +x?
        if {[cfg:get auth:hide *]} {
            putserv "MODE $botnick +x"
            debug 0 "\[@\] Armour: executed umode +x initially before authenticating."
        }
        # -- send the actual auth attempt
        auth:attempt
    }
    # -- apply silence masks
    foreach mask [cfg:get silence *] {
        putquick "SILENCE $mask"
        debug 0 "\@\] Armour: applied silence mask: $mask"
    }
    return 0
}

# -- send the authentication attempt (shared by init:server and retries)
proc auth:attempt {} {
    variable cfg
    variable auth:succeed;  # -- stores whether auth has succeeded or not
    if {${auth:succeed}} { return; }
    # -- only use full nick@server host for auth, if service server is set
    if {[cfg:get auth:serv:host *] ne ""} { set authhost "[cfg:get auth:serv:nick *]@[cfg:get auth:serv:host *]" } \
    else { set authhost [cfg:get auth:serv:nick *] }
    
    # -- append the TOTP token, if a secret key is configured
    set thepass [cfg:get auth:pass *]
    #if {[cfg:get auth:totp *] ne ""} { append thepass " [onetimepass::get_totp [cfg:get auth:totp *]]" }
    if {[cfg:get auth:totp *] ne ""} { append thepass " [exec /usr/local/bin/oathtool --totp [cfg:get auth:totp *]]" }
    
    # -- determine the auth mechanism:
    # gnuworld: LOGIN <user> <pass>
    # nickserv: IDENTIFY <pass>
    if {[string tolower [cfg:get auth:mech *]] eq "gnuworld"} { set mech "LOGIN [cfg:get auth:user *]" } \
    elseif {[string tolower [cfg:get auth:mech *]] eq "nickserv"} { set mech "IDENTIFY" } \
    else {
        debug 0 "\[@\] Armour: \002(error)\002 halting auth due to unsupport auth mechanism -- see setting \[cfg:get auth:mech *]"
        return;
    }
    
    debug 0 "\[@\] Armour: sending authentication attempt to [cfg:get auth:serv:nick *]"
    putserv "PRIVMSG $authhost :$mech $thepass"

    if {[cfg:get auth:retry *] != ""} {
        set mins [cfg:get auth:retry *]
        debug 0 "\[@\] Armour: sent auth userentials to [cfg:get auth:serv:nick *], waiting $mins mins for a response..."
        timer $mins arm::auth:attempt
    }
}


# -- triggered when auth succeeds
proc auth:success {nnick uhost hand text {dest ""}} {
    global nick
    variable cfg
    variable auth:succeed;   # -- stores whether auth has succeeded or not
    variable data:authnick;  # -- stores the nickname to restore after login
    set auth:succeed 1
    if {[info exists data:authnick]} { set nick ${data:authnick}; unset data:authnick }
    if {[string match -nocase $nnick [cfg:get auth:serv:nick *]]} {
        debug 0 "\[@\] Armour: joining channels after successfully authenticating with [cfg:get auth:serv:nick *]..."
        foreach chan [channels] {
            channel set $chan -inactive
        }
    }
}

# -- triggered when auth fails
proc auth:fail {nick uhost hand text {dest ""}} {
    variable cfg
    if {$nick eq [cfg:get auth:serv:nick *]} {
        debug 0 "\[@\] Armour: authentication failed with [cfg:get auth:serv:nick *]"
        if {![cfg:get auth:wait *]} {
            debug 0 "\[@\] Armour: joining all channels now..."
            foreach chan [channels] {
                channel set $chan -inactive
            }
        } else {
            # -- wait to join channels
        }
    }
}

debug 0 "\[@\] Armour: loaded service authentication."

}
# -- end namespace



# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-10_adaptive.tcl
#
# adaptive regular expression pattern builder
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


proc regex:adapt {string {flags ""}} {
    set start [clock clicks]
    variable cfg
        
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
        if {![regexp -- {\d+} $min]} { putloglev d * "regex:adapt: regexp -min error"; return; }
    }
    
    # -- -max results
    if {[string match "*-max*" $flags]} { 
        set ismax 1
        set pos [lsearch $flags "*-max*"]
        set max [lindex $flags [expr $pos + 1]]
        if {![regexp -- {\d+} $max]} { putloglev d * "regex:adapt: regexp -max error"; return; }
    }
    
    if {[string match "*-repeat*" $flags]} { set isrepeat 1 }
    if {[string match "*-nocase*" $flags]} { set isnocase 1 }
    if {[string match "*-explicit*" $flags]} { set isexplicit 1 }
    
    set count 0
    
    set regexp ""
    
    debug 5 "-----------------------------------------------------------------------------------------------"
    debug 5 "regex:adapt: building adaptive regex for string: $string"
    debug 5 "regex:adapt: wide: $iswide isrepeat: $isrepeat nocase: $isnocase explicit: $isexplicit min: $ismin max: $ismax"
    debug 5 "-----------------------------------------------------------------------------------------------"

    
    # -- phase 1: basic regex form
 
    if {$isexplicit} { 
        # -- replace \ first
        regsub -all {\\} $string {\\\\} string
    }
    
    # ---- mIRC Control Codes
            
    # \x02 $chr(2)    Ctrl+b    Bold text
    # \x03 $chr(3)    Ctrl+k    Colour text
    # \x0F $chr(15)    Ctrl+o    Normal text
    # \x16 $chr(22)    Ctrl+r    Reversed text
    # \x1F $chr(31)    Ctrl+u    Underlined text

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
            
    debug 5 "regex:adapt: string after control code regsub: $string"
    
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
                        
            # -- check lowercase (provided char not part of hex code)
            #putloglev d * "regex:adapt: checking lowercase (char: $char)"
            if {[regexp -- {[a-z]} $char] \
                && ![regexp -- {\\x} $prior1] \
                && ![regexp -- {\\x} $prior2]} { 
                # putloglev d * "regex:adapt: char: $char is lowercase"
                lappend regexp {[a-z]} 

            # -- check uppercase (provided not part of hex code)
            #putloglev d * "regex:adapt: checking uppercase (char: $char)"
            } elseif {[regexp -- {[A-Z]} $char] \
                && ![regexp -- {\\x} $prior2] \
                && ![regexp -- {\\x} $prior3]} { 
                # putloglev d * "regex:adapt: char: $char is uppercase"
                lappend regexp {[A-Z]} 
                    
            # -- check numeric (provided not part of hex code)
            #putloglev d * "regex:adapt: checking numeric (char: $char)"
            } elseif {[regexp -- {\d} $char] \
                && ![regexp -- {\\x} $prior2] \
                && ![regexp -- {\\x} $prior3]} { 
                # putloglev d * "regex:adapt: char: $char is numeric"
                lappend regexp {\d} 
                    
            # -- append literal character
            } else {
                #putloglev d * "regex:adapt: literal char: $char"
                # -- escape special literal chars
        
            # -- do char \ first, but only if not followed by hex code
            #putloglev d * "regex:adapt: checking for \\ (char: $char)"
            if {[regexp -- {\\} $char]} {
                if {[string match "\\x??" $post3]} {
                    set range [string range $string [expr $count + 2] [expr $count + 3]]
                    if {![regexp -- {[0-9A-F][0-9A-F]} $range]} {
                        regsub -all {\\} $char {\\\\} char
                    }
                }
            }
            #if {[regexp -- {\\} $char] && ![regexp -- {\x[0-9A-F][0-9A-F]} $post3]} {
            #    regsub -all {\\} $char {\\\\} char
            #}

            #putloglev d * "regex:adapt: checking other special chars (char: $char)"

            regsub -all {\|} $char {\\|} char
            regsub -all {\^} $char {\\^} char
            regsub -all {\.} $char {\\.} char
         
            # -- take care when dealing with control chars
            regsub -all {\[} $char {\\[} char
            #if {[regexp -- {\[} $char]} {
            #    if {![regexp -- {(?:\x22?|\x31?|\x1F|\x16)} $prior3]} {
            #        regsub -all {\[} $char {\\[} char
            #    }
            #}

            # -- take care when dealing with control chars
            regsub -all {\]} $char {\\]} char
            #if {[regexp -- {\]} $char]} {
            #    if {![regexp -- {(?:\x22?|\x31?|\x1F|\x16)} $prior6]} {
            #        regsub -all {\]} $char {\\]} char
            #    }
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
        
        debug 5 "regex:adapt: adaptive regex for string: $string is: [join $regexp]"
        #putlog "[regsub -all { } [join $regexp] {}]" 

        # -- phase 2: make regexp more efficient (process repetitions)
        debug 5 "-----------------------------------------------------------------------------------------------"
        debug 5 "regex:adapt: beginning phase two: process repetitions"
        debug 5 "-----------------------------------------------------------------------------------------------"
        
        set length [llength $regexp]
        set count 0
        set newregex ""
        while {$count < $length} {
            set item [lindex $regexp $count]
            set next [expr $count + 1]
            
            if {$item != [lindex $regexp $next]} {
                # -- item not repeated
                # putloglev d * "regex:adapt: item not repeated: $item"
                lappend newregex $item
                incr count
            } else {
                # -- item is repeated
                # putloglev d * "regex:adapt: item is repeated: $item"
                set repeat 1
                set occur 2
                while {$repeat != 0} {
                    set next [expr $next + 1]
                    if {$item != [lindex $regexp $next]} {
                        # -- no more repeats
                        # putloglev d * "regex:adapt: item has no more repeats: $item"
                        set repeat 0
                    } else {
                            # -- repeated
                            # putloglev d * "regex:adapt: item is repeated: $item"
                            incr occur
                    }
                }
                # -- append repeat value
                # putloglev d * "regex:adapt: appending repetitions: $item{$occur}"
                
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
    debug 5 "regex:adapt: adaptive regex built & repetitions processed in [runtime $start]: $newregex"
    debug 5 "-----------------------------------------------------------------------------------------------"
    
    return [split $newregex];
}

putlog "\[@\] Armour: loaded adaptive regex pattern builder."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-11_remotescan.tcl
#
# remote DNSBL/port scan functions (can act standalone on 'remote' bot)
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# ---- configuration

# -- please note that the below configuration is unused unless this script
#    is loaded standalone on a remote scan bot via 'remotescan.tcl'
#
#    In all other cases these variables are set in the main armour.conf file

# -- debug level
set iscan(debug) 2

# -- how to set channel bans? (chan|x) [x]
set iscan(cfg:ban) "x"

# -- default ban time
set iscan(cfg:ban:time) "1h"


# ------------------------------------------------------------------------------------------------
# REPORT SETTINGS
# ------------------------------------------------------------------------------------------------

# -- send user notices for whitelist entries? (0|1) - [0]
set iscan(cfg:notc:white) 0

# -- send user notices for blacklist entries? (0|1) - [0]
set iscan(cfg:notc:black) 0

# -- send op notices for whitelist entries? (0|1) - [1]
set iscan(cfg:opnotc:white) 1

# -- send op notices for blacklist entries? (0|1) - [1]
set iscan(cfg:opnotc:black) 1

# -- send debug chan notices for whitelist entries? (0|1) - [1]
set iscan(cfg:dnotc:white) 1

# -- send debug chan notices for blacklist entries? (0|1) - [1]
set iscan(cfg:dnotc:black) 1

# -- kick reason for open ports
set iscan(cfg:portscan:reason) "Armour: possible insecure host unintended for IRC -- please install identd"


# ------------------------------------------------------------------------------------------------
# END OF CONFIGURATION SETTINGS -- do not edit below this line
# ------------------------------------------------------------------------------------------------

# ---- binds

# -- trigger scan
bind bot - scan:port arm::bot:send:port
bind bot - scan:dnsbl arm::bot:send:dnsbl
bind bot - scan:whois arm::bot:send:whois

# -- receive scan response
bind bot - recv:port arm::bot:recv:port
bind bot - recv:dnsbl arm::bot:recv:dnsbl
bind bot - recv:whois arm::bot:recv:whois

# -- whois response
bind raw - 319 arm::raw:chanlist

# ---- procedures

proc bot:recv:port {bot cmd text} {
    variable cfg
    variable data:kicks;    # -- stores list of recently kicked nicknames for a channel (by chan)
    variable data:chanban;  # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    
    lassign $text nick ident host ip host chan;  # -- target and chan can be '0' if manual scan
    set openports [lrange $text 4 end]
    
    if {$openports eq "NULL"} { return; }

    debug 1 "bot:recv:port: insecure host (host: $host ip: $ip openports: $openports)"

    if {$chan != 0} {
        set nick [lindex [split $target !] 0]
        
        set mask1 "*!*@$host"
        set mask2 "*!~*@$host"
        set mask3 "*!$ident@$host"
        
        # -- don't continue if nick was recently caught by floodnet detection, or otherwise banned
        if {$nick in [get:val data:kicks $chan]} {
            debug 2 "bot:recv:port: $nick exists in $chan global kick list data:kicks($chan), halting."
            return;
        }
        
        foreach mask "$mask1 $mask2 $mask3" {
            if {[info exists data:chanban($chan,$mask)]} {
                debug 2 "bot:recv:port: mask $mask exists in recent banlist for $chan, halting."
                return;
            }
        }

        # -- minimum number of open ports before action
        set min [cfg:get portscan:min $chan]
        # -- divide list length by two as each has two arg
        set portnum [expr [llength $openports] / 2]
        
        if {$portnum >= $min} {
            kickban $nick $ident $host $chan [cfg:get ban:time $chan] [cfg:get portscan:reason $chan]
            report black $chan "Armour: $target insecure host (\002open ports:\002 $openports \002reason:\002 install identd)"
        }
    }
    return;
}

proc bot:recv:dnsbl {bot cmd text} {
    variable cfg
    variable data:kicks;    # -- stores list of recently kicked nicknames for a channel (by chan)
    variable data:chanban;  # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    
    lassign $text nick ident host ip chan
    set data [lrange $text 5 end]

    if {$data eq "NULL"} { return; }

    set response [join [lindex $data 1]]
    set score [lindex $data 2]
    set rbl [lindex $response 1]
    set desc [lindex $response 2]
    set info [lindex $response 3]
    
    # {{+1.0 dnsbl.swiftbl.org SwiftRBL {{DNSBL. 80.74.160.3 is listed in SwiftBL (SOCKS proxy)}}} {+1.0 rbl.efnetrbl.org {Abusive Host} NULL}}

    debug 3 "bot:recv:dnsbl: dnsbl data: $data"
            
    debug 1 "bot:recv:dnsbl: dnsbl match found for $nuh: $response"
    debug 1 "scan: ------------------------------------------------------------------------------------"
    set nick [lindex [split $target !] 0]
    set mask1 "*!*@$host"
    set mask2 "*!~*@$host"
    set mask3 "*!$ident$host"
    
    # -- don't continue if nick was recently caught by floodnet detection, or otherwise banned
    if {$nick in [get:val data:kicks $chan]} {
        debug 2 "bot:recv:dnsbl: $nick exists in $chan kick list data:kicks($chan), halting."
        returnl
    }
    
    foreach mask "$mask1 $mask2 $mask3" {
        if {[info exists data:chanban($chan,$mask)]} {
            debug 2 "bot:recv:dnsbl: mask $mask exists in recent banlist for $chan, halting."
            return;
        }
    }
    
    if {[join $info] eq "NULL"} { set info "" } else { set info " \002info:\002 [join $info]" }

    kickban $nick $ident $host $chan [cfg:get ban:time $chan] "Armour: DNSBL blacklisted (\002ip:\002 $ip \002rbl:\002 $rbl \002desc:\002 $desc)"

    if {$info == ""} { set xtra "" } else { set xtra " \002info:\002 $info" }
    report black $chan "Armour: DNSBL match found on $target (\002ip:\002 $ip \002rbl:\002 $rbl \002desc:\002 $desc)"
    return;
            
}

proc bot:send:port {bot cmd text} {
    set start [clock clicks]
    lassign $text ip host nick ident host chan; # -- nuh and chan can be "0" if manual scan
    debug 1 "arm:bot:send:port: (from: $bot) -- executing port scanner: $ip (host: $host)"
    set openports [port:scan $ip]
    if {$openports ne ""} {
        debug 1 "bot:send:port: insecure host (host: $host ip: $ip) - runtime: [runtime $start]"
        putbot $bot "recv:port $nick $ident $host $ip $chan $openports"

    } else {
        debug 1 "bot:send:port: no open ports found (host: $host ip: $ip) - runtime: [runtime $start]"
        putbot $bot "recv:port $nick $ident $host $ip $chan NULL"
    }
    return;
}

proc bot:send:dnsbl {bot cmd text} {
    global arm
    # debug 1 "bot:send:dnsbl: started. cmd: $cmd text: $text"
    set start [clock clicks]
    lassign $text nick ident host ip chan

    if {[string match "*:*" $ip]} {
        # -- don't continue if IPv6 (TODO)
        debug 0 "bot:send:dnsbl: (from: $bot) -- halting scan for IPv6 dnsbl IP (ip: $ip)"
        return;
    }
    debug 1 "bot:send:dnsbl: (from: $bot) -- scanning for dnsbl match: $ip (host: $host)"
    # -- get score
    set response [rbl:score $ip]
    set ip [lindex $response 0]
    set score [lindex [join $response] 1]
    if {$ip != $host} { set dst "$ip ($host)" } else { set dst $ip }
    if {$score <= 0} { 
        # -- no match found
        debug 1 "bot:send:dnsbl: no dnsbl match found for $host ([runtime $start])"
        putbot $bot "recv:dnsbl $nick $ident $host $ip $chan NULL"
        return;
    }
    putbot $bot "recv:dnsbl $nick $ident $host $ip $chan $response"
    debug 1 "bot:send:dnsbl: dnsbl match found for $host: $response ([runtime $start])"
    return;
}

proc bot:send:whois {bot cmd text} {
    variable data:whois;  # -- stores data relating to /WHOIS for remotescans (by bot,nick and chan,nick)
    lassign $text nick chan
    debug 1 "bot:send:whois: (from: $bot) -- sending to server: /WHOIS [join $nick]"
    set data:whois(bot,$nick) $bot
    set data:whois(chan,$nick) $chan
    putserv "WHOIS [join $nick]"
}

proc raw:chanlist {server cmd arg} {
    variable cfg
    variable data:whois;    # -- stores data relating to /WHOIS for remotescans (by bot,nick and chan,nick)
    variable data:kicks;    # -- stores list of recently kicked nicknames for a channel (by chan)
    variable data:chanban;  # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    
    variable entries;       # -- dict: blacklist and whitelist entries

    variable nickdata;      # -- dict: stores data against a nickname
                            #           nick
                            #            ident
                            #           host
                            #           ip
                            #           uhost
                            #           rname
                            #           account
                            #           signon
                            #           idle
                            #           idle_ts
                            #           isoper
                            #           chanlist
                            #           chanlist_ts
                              
    set arg [split $arg]
    set nick [lindex $arg 1]
    set lnick [string tolower $nick]


    if {![info exists data:whois(bot,$nick)] || ![info exists data:whois(chan,$nick)]} { return; }

    set bot [get:val data:whois bot,$nick]
    set chan [get:val data:whois chan,$nick]

    if {$chan eq "" || ![validchan $chan]} { return; }; # -- safety net

    set uhost [getchanhost [join $nick] $chan]; # -- this won't work in secure mode, if nick not yet on channels
    if {[dict exists $nickdata $lnick uhost]} {
        set uhost [dict get $nickdata $lnick uhost]
    }  else {
        dict set nickdata $lnick uhost $uhost
    }
    lassign [split $uhost @] ident host
    
    putlog "\002:raw:chanlist: nick: $nick -- uhost: $uhost\002"

    # -- only continue if /whois enabled (for channel whitelists and blacklists)
    if {[info exists cfg(whois)]} {
        if {![cfg:get whois $chan]} { return; }
    } 

    set chanlist [lrange $arg 2 end]
    set chanlist [split $chanlist ":"]
    set chanlist [lrange $chanlist 1 end]
 
    set newlist "" 

    foreach channel [join $chanlist] {
        # -- only take the channel, not prefixed modes
        if {[string index $channel 0] ne "#"} { set channel [string range $channel 1 end] } else { set channel $channel }
        lappend newlist $channel
    }

    set chanlist [join $newlist]
    
    # -- store nick data in dictionary
    dict set nickdata $lnick chanlist $chanlist
    dict set nickdata $lnick chanlist_ts [clock seconds]

    # -- free array data
    unset data:whois(bot,$nick)
    unset data:whois(chan,$nick)
    
    debug 1 "raw:chanlist: whois chanlist found for [join $nick]: $chanlist (chan: $chan -- bot: $bot)"

    if {$bot ne 0 && $bot ne ""} {
        # -- /whois was REMOTE lookup, send the channel list remotely
        putbot $bot "recv:whois $nick $chan $chanlist"
        return;
    }
    
    # -- /whois was LOCAL lookup, necessitates local processing

    # -- don't continue if nick already exists in global kick list (caught by floodnet detection)
    if {![info exists data:kicks($chan)]} { set data:kicks($chan) "" }
    if {$nick in [get:val data:kicks $chan]} {
        debug 2 "raw:chanlist: $nick exists in $chan global kick list data:kicks($chan), halting."
        return;
    }
    
    chanlist:hit $chan $nick $uhost $chanlist; # -- send to common code to process
}

proc bot:recv:whois {bot cmd text} {
    variable cfg
    variable data:kicks; # -- stores list of recently kicked nicknames for a channel (by chan)
    
    lassign $text nick chan
    set uhost [getchanhost [join $nick] $chan]
    lassign [split $uhost @] ident host
    set chanlist [list [lrange $text 2 end]]

    debug 2 "bot:recv:whois received chanlist for [join $nick]: [join $chanlist] -- sending to chanlist:hit"
    
    chanlist:hit $chan $nick $uhost $chanlist; # -- send to common code to process
}

proc chanlist:hit {chan nick uhost chanlist} {
    variable entries;         # -- dict: blacklist and whitelist entries
    variable nickdata;        # -- dict: stores data against a nickname
                              #           nick
                              #              ident
                              #           host
                              #           ip
                              #           uhost
                              #           rname
                              #           account
                              #           signon
                              #           idle
                              #           idle_ts
                              #           isoper
                              #           chanlist
                              #           chanlist_ts
                              
    set chanlist [join $chanlist]
    set lnick [string tolower $nick]
    lassign [split $uhost @] ident host
    
    # -- do the list lookups
    foreach list "white black" {
        debug 1 "chanlist:hit: beginning ${list}list matching in $chan";        
        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {([dict get $dictData chan] eq $chan || [dict get $dictData chan] eq "*") \
            && [dict get $dictData type] eq $list && [dict get $dictData method] eq "chan"}
        }]]
        foreach id $ids {
            set chan [dict get $entries $id chan]
            set ltype [dict get $entries $id type]
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            set match 0

            debug 5 "chanlist:hit: ${list}list scanning $chan: type: $ltype -- method: $method -- value: $value"
            # -- search for a match (including wildcarded entries)
            
            foreach c $chanlist {
                if {[string match -nocase $value $c]} { set match 1; break; }
            }
            
            if {$match} {
                set action [dict get $entries $id value]
                set reason [dict get $entries $id reason]
                debug 1 "chanlist:hit: ${list}list matched chanlist: chan: $chan -- type: $ltype -- method: $method -- value: $value (id: $id) -- taking action!"
                debug 2 "chanlist:hit: ------------------------------------------------------------------------------------"
                #set uhost [getchanhost [join $nick] $chan]
                if {$list eq "white"} {
                    # -- whitelist 
                    set mode [list:mode $id]
                    if {$mode ne ""} { putquick "MODE $chan $mode [join $nick]" -next } elseif {[get:val chan:mode $chan] eq "secure"} { voice:give $chan $nick }
                    report $list $nick "Armour: [join $nick]!$uhost ${list}listed (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002action:\002 $action \002reason:\002 $reason)"
                } else {
                    # -- blacklist
                    set string "Armour: blacklisted"
                    if {[cfg:get black:kick:value $chan]} { append string " -- $value" }
                    if {[cfg:get black:kick:reason $chan]} { append string " (reason: $reason)" }
                    set string "$string \[id: $id\]";
                    # -- truncate reason for X bans
                    if {[string tolower [cfg:get ban $chan]] eq "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
                    if {$host eq ""} { 
                        # -- safety net in case nick has already left channel (or been kicked)
                        if {[dict exists $nickdata $lnick uhost]} {
                            if {[dict get $nickdata $lnick uhost] ne ""} {
                                set host [lindex [split [dict get $nickdata $lnick uhost] @] 1]
                            }
                         }
                    }
                    putlog "\002chanlist:hit\002: match! id: $id -- value: $value -- host: $host"
                    # -- double saftey net
                    if {$host ne ""} {
                        kickban $nick $ident $host $chan [cfg:get ban:time $chan] "$string" $id
                        report $list $nick "Armour: $nick!$uhost ${list}listed (\002id:\002 $id \002type:\002 $method \002value:\002 $value \002reason:\002 $reason)"
                    }
                }
                hits:incr $id; # -- incr statistics
                if {$list eq "white"} { integrate $nick $uhost [nick2hand $nick] $chan 1}; # -- pass join to any integrated scripts
                scan:cleanup $nick $chan; # -- cleanup vars
                return;
            }; # -- end of match
        }; # -- end of foreach list
    }; # -- end of foreach (white black)
}

# -- change eggdrop setting to not optimize kick queue
# solves removal of kick targets from chanmode +d in ircu (in mode: secure)
# https://github.com/eggheads/eggdrop/blob/63dce0f5bc17d88c3b42983228b89695ebf182ae/src/mod/server.mod/server.c#L652-L656
set ::optimize-kicks 0

# -- kickban handler
proc kickban {nick ident host chan duration reason {id ""}} {
    variable cfg
    variable data:chanban;   # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    variable data:banmask;   # -- tracking banmasks banned recently by a blacklist (by id)
    variable data:kicknicks; # -- tracking nicknames recently kicked from chan (by 'chan,nick')
    variable entries;        # -- dict: blacklist and whitelist entries  
    variable data:idban;     # -- tracks the most recently banned ban for a given entry ID (chan,id)
    variable nickdata;       # -- dict: stores data against a nickname
                             #           nick
                             #            ident
                             #           host
                             #           ip
                             #           uhost
                             #           rname
                             #           account
                             #           signon
                             #           idle
                             #           idle_ts
                             #           isoper
                             #           chanlist
                             #           chanlist_ts

    debug 4 "kickban: adding chan kickban: \002nick:\002 $nick -- chan: $chan -- ident: $ident -- host: $host -- duration: $duration -- reason: $reason -- id: $id"

    set lnick [string tolower $nick]
    if {[dict exists $nickdata $lnick account] eq 1} { set xuser [dict get $nickdata $lnick account] } \
    else { set xuser 0 }
    
    # -- what banmask to apply?
    # -- cheat by using the ident as hostmask if the nick var is set to '0'
    if {$nick eq 0} { set mask $ident } else {

        # -- build the hostmask
        set mask [getmask $nick $xuser $ident $host]

        # -- track nick as recently kicked (to bump to kickban if threshold met)
        if {![info exists data:kicknicks($chan,$nick)]} {
            set data:kicknicks($chan,$nick) 1
            utimer [lindex [split [cfg:get paranoid:klimit $chan] :] 1] "unset arm::data:kicknicks($chan,$nick)"
        } else { 
            incr data:kicknicks($chan,$nick)
        }
    }

    # -- store the most recently banned mask for this entry ID
    if {$id ne ""} {
        set idban($chan,$id) $mask
    }

    if {![info exists data:chanban($chan,$mask)]} {
        # -- mask not banned already, do the ban
        set data:chanban($chan,$mask) 1
        set addban 1
        # -- unset with minute timer
        debug 1 "kickban: adding array: data:chanban($chan,$mask)... unsetting in [cfg:get time:newjoin $chan] secs"
        utimer [cfg:get time:newjoin $chan] "arm::unset:chanban $chan $mask"
    } else { set addban 0 }
    
    # -- TODO: work out what to do here with addban and the data:chanban entry
    #          it may be there users are not being banned again if they were banned recently
    #          are we cleaning the data:chanban data?
    set addban 1
    
    # -- get units
    if {![regexp -- {(\d+)([A-Za-z])} $duration -> time unit]} { set time $duration; set unit "s" }
    set unit [string tolower $unit]
    
    if {[string tolower [cfg:get ban $chan]] eq "chan"} {
        if {$id ne ""} {
            if {[dict exists $entries $id onlykick]} {
                if {[dict get $entries $id onlykick] eq 1} {
                    set addban 0
                    debug 1 "kickban: not placing ban (flag: onlykick=1) -- nick: $nick -- chan: $chan -- mask: $mask -- duration: $duration"
                }
            }
        }
    
        # -- channel ban
        debug 1 "kickban: adding chan kickban -- nick: $nick -- chan: $chan -- mask: $mask -- duration: $duration -- addban: $addban"
        if {$addban} {
            putquick "MODE $chan +b $mask" -next
        }
        
        # -- kick the guy!
        set klist ""
        if {$nick eq 0} {
            foreach i [chanlist $chan] {
                set imask "$i![getchanhost $i $chan]"
                if {[string match -nocase $mask $imask]} { lappend klist $i }
            }
            foreach i $klist {
                putquick "KICK $chan $i :$reason"
            }
        } else {
            putquick "KICK $chan $nick :$reason"
        }
        
        if {$unit eq "h"} { 
            # -- unit is hours
            set time [expr $time * 60]
            timer $time "arm::unban $chan $mask"
        } elseif {$unit eq "s"} {
            # -- unit is secs
            utimer $time "arm::unban $chan $mask"
        } elseif {$unit eq "m"} {
            # -- unit is mins
            timer $time "arm::unban $chan $mask"
        } elseif {$unit eq "d"} {
            # -- unit is days
            set time [expr $time * 1440]
            timer $time "arm::unban $chan $mask"
        } else {
            # -- just use mins
            timer $time "arm::unban $chan $mask"
        }        
    } elseif {[string tolower [cfg:get ban $chan]] eq "x"} {
        # -- X ban
        # -- TODO: support non-gnuworld services
        if {$addban} {
            set level 100
            debug 1 "kickban: adding X ban -- chan: $chan mask: $mask duration: $duration"
            putquick "PRIVMSG [cfg:get auth:serv:nick *] :BAN $chan $mask $duration $level $reason" -next
        } else {
            # -- if already in X's banlist, no need to kick?
            # putquick "PRIVMSG X :KICK $chan $nick $reason" -next 
        }
    } else {
        debug 0 "\002kickban: error:\002 value of \[cfg:get ban $chan] needs to be \"chan\" or \"x\""
    }
    
    if {$id ne ""} {
        set data:banmask($id) $mask; 
        utimer [cfg:get id:unban:time $chan] "unset arm::data:banmask($id)"; # -- allow automatic unban of recently banned mask, when removing blacklist by id
    }
}

# -- arm:unset:chanban
# clear chanban record
proc unset:chanban {chan mask} {
    variable data:chanban;  # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    if {[info exists data:chanban($chan,$mask)]} {
        # -- chanban exists!
        debug 1 "unset:chanban: unsetting chanban array: [get:val data:chanban $chan,$mask]"
        unset data:chanban($chan,$mask)
    } else {
        debug 1 "unset:chanban: chanban array does not exist: [get:val data:chanban $chan,$mask]"
    }
}

proc unban {chan mask} {
    debug 1 "unban: unbanning $mask in $chan"
    putquick "MODE $chan -b $mask" -next
}

# -- grab values from Armour config if this is not a standalone scan bounce bot
if {![info exists cfg(ban)]} { set cfg(ban) $iscan(cfg:ban) }
if {![info exists cfg(ban:time)]} { set cfg(ban:time) $iscan(cfg:ban:time) }
if {![info exists cfg(notc:white)]} { set cfg(notc:white) $iscan(cfg:notc:white) }
if {![info exists cfg(opnotc:white)]} { set cfg(opnotc:white) $iscan(cfg:opnotc:white) }
if {![info exists cfg(dnotc:white)]} { set cfg(dnotc:white) $iscan(cfg:dnotc:white) }
if {![info exists cfg(notc:black)]} { set cfg(notc:black) $iscan(cfg:notc:black) }
if {![info exists cfg(opnotc:black)]} { set cfg(opnotc:black) $iscan(cfg:opnotc:black) }
if {![info exists cfg(dnotc:black)]} { set cfg(dnotc:black) $iscan(cfg:dnotc:black) }
if {![info exists cfg(portscan:reason)]} { set cfg(portscan:reason) $iscan(cfg:portscan:reason) }
set scan(cfg:ban:time) [cfg:get ban:time *]

# -- debug proc -- we use this alot
if {[info commands "arm::debug"] eq ""} {
    # -- only create if not already loaded
    proc debug {level string} {
        if {$level eq 0 || [cfg:get debug:type *] eq "putlog"} { 
            putlog "\002\[A\]\002 $string"; 
        } else { 
            putloglev $level * "\002\[A\]\002 $string";
        }
    }
}


if {[info commands "arm::report"] eq ""} {
    # -- only create if not already loaded
    proc report {type target string {chan ""} {chanops "1"}} {
        variable scan:full; # -- stores data when channel scan in progress (arrays: chan,<chan> and count,<chan>)
        
        set prichan [db:get id channels id 2]; # -- channel id 2 (1 = global)
        
        # -- obtain the right chan for opnotice
        # -- TODO: properly support multiple channels
        if {[info exists scan:full]} {
            # -- full channel scan under way
            set list [lsort [array names scan:full]]
            foreach channel $list {
                set chan [lindex [split $channel ,] 1]    
            }
            if {![info exists chan]} { set chan $prichan }
        } elseif {$chan eq ""} { set chan $prichan }

        set rchan [cfg:get chan:report $chan]
        
        if {$type eq "white"} {
            if {[cfg:get notc:white $chan]} { putquick "NOTICE $target :$string"}
            if {[cfg:get opnotc:white $chan]} { putquick "NOTICE @$chan :$string"}
            if {[cfg:get dnotc:white $chan] && $rchan ne ""} { putquick "NOTICE $rchan :$string"}
        } elseif {$type eq "black"} {
            if {[cfg:get notc:black $chan]} { putquick "NOTICE $target :$string" }
            if {$chanops && ([cfg:get opnotc:black $chan] || [get:val chan:mode $chan] eq "secure")} { putquick "NOTICE @$chan :$string" }
            if {([cfg:get dnotc:black $chan] || [get:val chan:mode $chan] eq "secure") && $rchan ne ""} { putquick "NOTICE $rchan :$string" }    
        } elseif {$type eq "text"} {
            if {[cfg:get opnotc:text $chan]} { putquick "NOTICE @$chan :$string" }
            if {[cfg:get dnotc:text $chan] && $rchan ne ""} { putquick "NOTICE $rchan :$string" }
        } elseif {$type eq "operop"} {
            if {[cfg:get opnotc:operop $chan]} { putquick "NOTICE @$chan :$string" }
            if {[cfg:get dnotc:operop $chan] && $rchan ne ""} { putquick "NOTICE $rchan :$string" }
        } elseif {$type eq "debug"} {
            if {$rchan ne ""} { putquick "NOTICE $rchan :$string" }
        }
    }
}

putlog "\[@\] Armour: loaded remote dnsbl & portscan procedures."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-12_cmds.tcl
#
# core user commands
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# -- commands

# -- cmd: conf
# synax: conf <setting|mask>
# allows to search for configuration setting values
# vars can be specified in colon form (without 'cfg' prefix), or with spaces
# wildcard searches supported
proc arm:cmd:conf {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    set cmd "conf"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template
    
    if {$arg eq "" || [llength $arg] < 2} { reply $stype $starget "usage: conf ?chan? <setting|mask> \[-out\]"; return; }
    set chan [lindex $arg 0]
    if {[string index $chan 0] ne "#" && $chan eq "*"} { set chan "*" }; # -- default to global if not given
    set cid [db:get id channels chan $chan]
    if {$cid eq ""} { reply $type $target "\002error:\002 channel $chan is not registered."; return; }
    set rest [lrange $arg 1 end]
    set var ""; set length [llength $rest]; set out 0;
    if {$length eq "1"} {
        if {[string match "*:*" $rest]} {
            # -- var is colon notation
            set var [join [lrange $arg 1 end]]
        }
        set var $rest
    } else {
        if {[lindex $rest [expr $length - 1]] eq "-out"} {
            set var [join [lrange $rest 0 [expr $length - 2]] :]
            set out 1;
        } else {
            # -- spaced delimited
            set var [join $rest :]
        }
    }
        
    # -- check the var
    set count 0;
    if {[cfg:get $var $chan] ne ""} {
        reply $type $target "\002setting:\002 cfg($var) -- value: [cfg:get $var $chan]"
    } else {
        # -- return those that do match?
        set thelist ""
        foreach i [array names cfg] {
            set long [split $i :]
            # -- protect some sensitive vars
            switch -- $i {
                auth:pass { continue; }
                auth:totp { continue; }
                ipqs:key  { continue; }
                ircbl:key { continue; }
            }
            if {[string match $var $i] || [string match $var $long]} { lappend thelist $i }
        }
        if {$thelist ne ""} {
            # -- send the results
            if {!$out} {
                reply $type $target "\002matched settings:\002 $thelist"
            } else {
                set count 0
                foreach s $thelist {
                    if {$count eq 10 && $type ne "dcc"} {
                        break;
                    }
                    incr count;
                    reply $type $target "\002setting:\002 $s -- \002value:\002 [cfg:get $s $chan]"
                }
            }
        } else {
            # -- no such var
            reply $type $target "no matching setting(s) found."     
        }
    }
    if {$count eq 10} {
        reply $type $target "woah! over 10 results found, please restrict query."
    } elseif {$count > 1} {
        reply $type $target "done. $count results found."
    }
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: cmds
# command list
# usage:
#   cmds            - shows all commands user has access to
#   cmds [level]    - shows all commands at and below a given level (subject to requestor's level)
#   cmds levels     - shows each available command against each user level
proc arm:cmd:cmds {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    variable armbind; # -- the list of arm command binds
    variable userdb;  # -- the list of userdb command binds
    variable dbchans; # -- dict with the list of channels
    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "cmds"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    if {$user ne ""} { set chan [userdb:get:chan $user $chan] }

    set level [userdb:get:level $user $chan];   # -- get the effective access level for chan
    set clevel [lindex $arg 0]

    if {$clevel ne "" && $clevel ne "levels"} {
        # -- user given level to see commands for a specific level
        if {![regexp -- {^\d+$} $clevel]} {
            reply $stype $starget "\002error\002: level must be an integer."
            return;
        }
        if {$clevel > $level} {
            reply $stype $starget "\002error\002: level must be below or equal to your own."
            return;          
        }
    }

    # -- show a list of commands this guy has access to
    foreach i [array names userdb cmd,*,$type] {
        set line [split $i ,]
        lassign $line a c t
        if {[string length $c] eq 1 || $c eq "kb"} { continue; }; # -- don't include the single char shortcut commands
        if {$c eq "reload" || $c eq "whois"} { continue; }; # -- shortcut to 'load' and 'info'
        set l $userdb($i)
        # -- has access to command (for bind type)
        if {$clevel ne ""} {
            if {$clevel >= $l} {
                lappend cmdlist $c
                if {![info exists levels($l)]} { set levels($l) $c } else { lappend levels($l) $c }
            }
        } elseif {$level >= $l} {
            lappend cmdlist $c
            if {![info exists levels($l)]} { set levels($l) $c } else { lappend levels($l) $c }
        }
    }
    lappend levels(0) "login"
    lappend levels(0) "logout"
    lappend levels(0) "newpass"

    if {$cmdlist eq ""} { reply $stype $starget "\002error:\002 no access to any commands!"; return; }

    if {$clevel eq "levels"} {
        if {$type eq "pub"} {
            reply $type $target "response sent via /notice."
            set ntype "notc"; set ntarget $nick
        } else { set ntype $type; set ntarget $target }
        # -- user is looking for a command overview per level
        set lvls [lsort -integer -decreasing [array names levels]]
        foreach l $lvls {
            reply $ntype $ntarget "\002Level $l:\002 [lsort -dictionary [join $levels($l)]]"
        }
        # -- create log entry for command use
        log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
        return;
    }

    # -- load commands only if applicable
    lappend cmdlist "login logout newpass"; # -- userdb commands
    if {[cfg:get register *]} { lappend cmdlist "register" }; # -- self username register
    if {[cfg:get ipqs *]} { lappend cmdlist "ipqs" };         # -- IPQS (ipqualityscore.com)
    db:connect
    set clevels [db:query "SELECT cid FROM levels WHERE uid=$uid"]; # -- channels this user has access to
    db:close
    set trakka 0
    
    # -- append trakka commands
    foreach chanid $clevels {
        if {$chanid eq 1} { continue; }
        if {[dict exists $dbchans $chanid trakka]} {
            set istrakka [dict get $dbchans $chanid trakka]
            if {$istrakka eq "on"} { set trakka 1 }
        } else { set trakka 0 }
    }
    if {$trakka} { lappend cmdlist "ack nudge score" }

    # -- send the command list
    reply $stype $starget "\002commands:\002 [lsort -unique -dictionary [join $cmdlist]]"
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    
    return; 
}

# -- command: help
# command help topics
proc arm:cmd:help {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    variable armbind; # -- the list of arm command binds
    variable userdb;  # -- the list of userdb command binds
    variable dbchans;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "help"
        
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    if {$user ne ""} { set chan [userdb:get:chan $user $chan] }

    # -- command: help
    set command [string tolower [lindex $arg 0]]
    if {$command eq "help" || $command eq ""} {
        reply $stype $starget "\002usage:\002 help \[command\]"; 
        reply $stype $starget "\002hint:\002 for a command list, \002try:\002 'cmds \[level\]' or 'cmds levels' for per level summary."
        return; 
    }
        
    # -- find the help topic
    set notopic 0
    if {[file exists ./armour/help/$command.help]} { 
        # -- standard armour command
        set file "./armour/help/$command.help"
    } elseif {[file exists ./armour/plugins/help/$command.help]} { 
        # -- plugin help topic
        set file "./armour/plugins/help/$command.help"
    } else {
        # -- try to see if plugin has its own help directory
        # -- find the prefix first. assume 'msg' bind is most easy way to find
        if {[info exists armbind(cmd,$command,msg)]} {
            set prefix $armbind(cmd,$command,msg)
            if {[file exists ./armour/plugins/$prefix/help/$command.help]} { 
                set file "./armour/plugins/$prefix/help/$command.help"
            } else { set notopic  1 }
        } else {
            set notopic 1
        }
        if {$notopic} {
            # -- help topic doesn't exist
            reply $stype $starget "\002error:\002 no such help topic exists. try: \002help cmds\002"
            return;
        }
    }
    
    # -- set level required
    # -- safety net for userdb loaded commands (login, logout, newpass)
    if {[info exists userdb(cmd,$command,$type)]} { set req $userdb(cmd,$command,$type) } else { set req 0 }
    
    set level [userdb:get:level $user $chan];   # -- get the effective access level for chan

    if {$level >= $req} {
        # -- user has access to command
        set fd [open $file r]
        set data [read $fd]
        set lines [split $data \n]
        foreach line $lines {
            # -- string replacements:
            # - %LEVEL% level required
            # - %B%     bold text
            regsub -all {%LEVEL%} $line $req line
            regsub -all {%B%} $line \x02 line
            reply $stype $starget $line
        }
        close $fd
    }
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: op
# usage: op ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:op {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "op"
    
    # -- ensure user has required access for command
    lassign [db:get id,user users curnick $nick] uid user
    if {$user eq ""} { return; }

    # -- check for channel
    set first [lindex $arg 0]; 
    if {[string index $first 0] eq "#"} {
        set chan $first; set oplist [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set oplist [lrange $arg 0 end]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    # -- end default proc template
    
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to op when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to op someone when not oppped myself."; return; }
    
    if {$oplist eq ""} {
        # -- op individual
        debug 0 "arm:cmd:op: opping $nick on $chan"
        putquick "MODE $chan +o $nick"
    } else {
    
        # -- allow * for entire channel;
        # TODO: make configurable?
        if {$oplist eq "*"} {
            set olist [list]
            foreach i [chanlist $chan] {
                if {[isop $i $chan]} { continue; }
                if {$i eq $botnick} { continue; }
                lappend olist $i
            }
            set oplist [join $olist]
        }

        # -- check strictop
        foreach i $oplist {
            set strictlist [list]
            if {![strict:isAllowed op $chan $i]} {
                set pos [lsearch $oplist $i]
                set oplist [lreplace $oplist $pos $pos]
                lappend strictlist $i
            }
            if {$strictlist ne ""} {
                set strictlist [join $strictlist ,]
                reply $type $target "\[\002strictop\002\] cannot be opped: $strictlist"
            }
        }

        set length [llength $oplist]
        while {$oplist ne ""} {
            if {$length >= 6} { set modes "+oooooo" } else { set modes "+[string repeat "o" $length]" }
            debug 2 "arm:cmd:op: executing: MODE $chan $modes [join [lrange $oplist 0 5]]"
            putquick "MODE $chan $modes [join [lrange $oplist 0 5]]"
            set oplist [lreplace $oplist 0 5]
        }
    }
     if {$type ne "pub"} { reply $type $target "done." }   
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
    
}

# -- command: deop
# usage: deop ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:deop {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
 
    set cmd "deop"
    
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- check for channel
    set first [lindex $arg 0];
    if {[string index $first 0] eq "#"} {
        set chan $first; set deoplist [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set deoplist [lrange $arg 0 end]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    # -- end default proc template
    
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to deop when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to deop someone when not oppped myself."; return; }
    
    if {$botnick in $deoplist} { reply $type $target "uhh... nice try."; return; }
        
    set length [llength $deoplist]
    if {$deoplist eq ""} {
        # -- op individual
        debug 0 "arm:cmd:deop: deopping $nick on $chan"
        putquick "MODE $chan -o $nick"
    } else {
        while {$deoplist ne ""} {
            if {$length >= 6} { set modes "-oooooo" } else { set modes "-[string repeat "o" $length]" }
            debug 2 "arm:cmd:deop: executing: MODE $chan $modes [join [lrange $deoplist 0 5]]"
            putquick "MODE $chan $modes [join [lrange $deoplist 0 5]]"
            set deoplist [lreplace $deoplist 0 5]
        }
    }
    if {$type ne "pub"} { reply $type $target "done." }
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: voice
# usage: voice ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:voice {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "voice"
    lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0];
    if {[string index $first 0] eq "#"} {
        set chan $first; set voicelist [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set voicelist [lrange $arg 0 end]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]

    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to voice when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to voice someone when not oppped myself."; return; }
    
    if {$voicelist eq ""} {
        # -- op individual
        debug 0 "arm:cmd:voice: voicing $nick on $chan"
        putquick "MODE $chan +v $nick"
    } else {
        if {$voicelist eq "*"} {
            set vlist [list]
            foreach i [chanlist $chan] {
                if {[isvoice $i $chan]} { continue; }
                if {[isop $i $chan]} { continue; }
                if {$i eq $botnick} { continue; }
                lappend vlist $i
            }
            set voicelist [join $vlist]
        }
        # -- check strictvoice
        foreach i $voicelist {
            set strictlist [list]
            if {![strict:isAllowed voice $chan $i]} {
                set pos [lsearch $voicelist $i]
                set voicelist [lreplace $voicelist $pos $pos]
                lappend strictlist $i
            }
            if {$strictlist ne ""} {
                set strictlist [join $strictlist ,]
                reply $type $target "\[\002strictvoice\002\] cannot be voiced: $strictlist"
            }
        }
        set length [llength $voicelist]
        while {$voicelist ne ""} {
            if {$length >= 6} { set modes "+vvvvvv" } else { set modes "+[string repeat "v" $length]" }
            debug 2 "arm:cmd:voice: executing: MODE $chan $modes [join [lrange $voicelist 0 5]]"
            putquick "MODE $chan $modes [join [lrange $voicelist 0 5]]"
            set voicelist [lreplace $voicelist 0 5]
        }
    }
    if {$type ne "pub"} { reply $type $target "done." }
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: devoice
# usage: devoice ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:devoice {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "devoice"
    lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0];
    if {[string index $first 0] eq "#"} {
        set chan $first; set devoicelist [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set devoicelist [lrange $arg 0 end]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to devoice when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to devoice someone when not oppped myself."; return; }
    
    if {$botnick in $devoicelist} { reply $type $target "uhh... nice try."; return; }
    
    if {$devoicelist eq ""} {
        # -- op individual
        debug 0 "arm:cmd:devoice: devoicing $nick on $chan"
        putquick "MODE $chan -v $nick"
    } else {
        if {$devoicelist eq "*"} {
            set dvlist [list]
            foreach i [chanlist $chan] {
                if {[isvoice $i $chan]} { lappend dvlist $i; }
            }
            set devoicelist [join $dvlist]
        }
        set length [llength $devoicelist]
        while {$devoicelist ne ""} {
            if {$length >= 6} { set modes "-vvvvvv" } else { set modes "-[string repeat "v" $length]" }
            debug 2 "arm:cmd:devoice: executing: MODE $chan $modes [join [lrange $devoicelist 0 5]]"
            putquick "MODE $chan $modes [join [lrange $devoicelist 0 5]]"
            set devoicelist [lreplace $devoicelist 0 5]
        }
    }
    if {$type ne "pub"} { reply $type $target "done." }
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: invite
# usage: invite ?chan? [nick1] [nick2] [nick3] [nick4] [nick5] [nick6]....
proc arm:cmd:invite {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "invite"
    lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0]
    if {[string index $first 0] eq "#"} {
        set chan $first; set invitelist [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set invitelist [lrange $arg 0 end]
    }
    set cid [db:get id channels chan $chan]
    
    # -- continue for any chan if glob >=500
    set glevel [db:get level levels cid 1 uid $uid]
    if {![userdb:isAllowed $nick $cmd $chan $type]} { 
        if {$glevel < 500} { return; } else { set cid 1 }; # -- must be for unregistered chan
    }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    if {![botisop $chan]} { reply $type $target "sorry! unable to invite, not opped."; return; }
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to invite when not in a channel."; return; }
    
    if {$invitelist eq ""} {
        # -- op individual
        if {[onchan $nick $chan]} { reply $type $target "uhh... you are already on $chan."; return; }
        debug 0 "arm:cmd:invite: inviting $nick to $chan"
        putquick "INVITE $nick $chan"
        reply $type $target "done."
    } else {
        set onchan [list]
        foreach tnick $invitelist {
            if {[onchan $tnick $chan]} { lappend onchan $tnick; continue; }
            debug 0 "arm:cmd:invite: inviting $tnick to $chan"
            putquick "INVITE $tnick $chan"  
        }
        if {[llength $onchan] ne "0"} { reply $type $target "already on channel: [join $onchan ", "]" } \
        else { reply $type $target "done."  }
    }
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: kick
# usage: kick ?chan? <nick1,nick2,nick3...> [reason]
proc arm:cmd:kick {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "kick"
    lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0]
    if {[string index $first 0] eq "#"} {
        set chan $first; set kicklist [lindex $arg 1]; set reason [lrange $arg 2 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set kicklist [lindex $arg 0]; set reason [lrange $arg 1 end]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    set kicklist [split $kicklist ,]
    set length [llength $kicklist]
    
    if {$botnick in $kicklist} { reply $type $target "uhh... nice try."; return; }
    
    if {$reason eq ""} { set reason [cfg:get def:breason $chan] }
    
    if {$kicklist eq ""} { reply $stype $starget "\002usage:\002 kick ?chan? <nick1,nick2,nick3...> \[reason\]"; return; }
    
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to kick when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to kick someone when not oppped myself."; return; }
    
    debug 0 "arm:cmd:kick: kicking $length users from $chan"
    
    set noton [list]
    foreach client $kicklist {
        if {![onchan $client $chan] && [get:val chan:mode $chan] ne "secure"} { lappend noton $client; continue; }
        putquick "KICK $chan $client :$reason"
    }
    
    if {[join $noton] ne ""} { reply $type $target "not on channel: [join $noton ", "]" }
    if {$type ne "pub" || [get:val chan:mode $chan] eq "secure"} { reply $type $target "done." }
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: ban
# usage: ban ?chan? <nick1,mask1,nick2,mask2,mask3...> [duration] [reason]
proc arm:cmd:ban {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "ban"
    
    #  usage: ban ?chan? <nick1,mask1,nick2,mask2,mask3...> [duration] [reason]
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- check for channel
    set first [lindex $arg 0]
    if {[string index $first 0] == "#"} { 
        set chan $first; set banlist [lindex $arg 1]; set duration [lindex $arg 2];
        if {[string is digit $duration]} {
            # -- duration given
            set reason [join [lrange $arg 3 end]]
        } else {
            # -- no duration
            set duration ""; set reason [join [lrange $arg 2 end]]
        }
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set banlist [lindex $arg 0]; set duration [lindex $arg 1]
        if {[string is digit $duration]} {
            # -- duration given
            set reason [join [lrange $arg 2 end]]
        } else {
            # -- no duration
            set duration ""
            set reason [join [lrange $arg 1 end]]
        }
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
        
    set banlist [split $banlist ,]
    set length [llength $banlist]
    
    if {$botnick in $banlist} { reply $type $target "uhh... nice try."; return; }
    
    if {$reason eq ""} { set reason [cfg:get def:breason $chan] }
    if {$duration eq ""} { set duration [cfg:get ban:time $chan] }
    
    if {$banlist eq ""} { reply $stype $starget "\002usage:\002 ban ?chan? <nick1,mask1,nick2,mask2,mask3...> \[duration\] \[reason\]"; return; }

    debug 2 "arm:cmd:ban: chan: $chan -- banlist: [join $banlist] -- duration: $duration -- reason: $reason"

    
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to ban when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to set bans when not oppped myself."; return; }
    
    debug 1 "arm:cmd:ban: banning $length targets from $chan"
    
    set noton ""; set hit 0
    foreach item $banlist {
        debug 2 "arm:cmd:ban: item: $item"
        if {[regexp -- {\*} $item]} {
            # -- hostmask
            set tmask $item; set tident ""; set thost $tmask;
            set tnick 0; set hit 1
            debug 2 "arm:cmd:ban: item is hostmask: $tmask"
        } else {
            # -- nickname
            if {[onchan $item $chan]} {
                lassign [split [getchanhost $item $chan] @] tident thost
                set tnick $item; set hit 1
                debug 2 "arm:cmd:ban: item was nickname $item"
            } else {
                # -- not on chan
                lappend noton $item
                debug 2 "arm:cmd:ban: nick $item is not on $chan"
            }
        }
        if {$hit} { kickban $tnick $tident $thost $chan $duration $reason }
    }
    if {$noton != ""} {
        reply $type $target "missing: [join $noton ", "]"
    }
    if {$type != "pub"} { reply $type $target "done." }

    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}


# -- command: unban
# usage: unban ?chan? <nick1,nick2,nick3...>
proc arm:cmd:unban {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "unban"
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- check for channel
    set first [lindex $arg 0]
    if {[string index $first 0] == "#"} {
        set chan $first; set unbanlist [lindex $arg 1];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set unbanlist [lindex $arg 0]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    set unbanlist [split $unbanlist ,]
    set length [llength $unbanlist]

    if {$unbanlist == ""} { reply $stype $starget "\002usage:\002 unban ?chan? <nick1,nick2,mask1...>"; return; }
        
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to unban when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to unset bans when not oppped myself."; return; }

    # -- deal with the unbanlist (look for nicknames)
    set ublist [list]
    foreach i $unbanlist {
        if {![string match \* $i] || [onchan $i $chan]} {
            # -- it's a nickname, check if we can see it
            lassign [split [getchanhost $i $chan] @] ident chanhost
            if {$chanhost == ""} { continue; }
            # -- build the banmask
            if {[string match "~*" $ident]} { set mask "*!~*@$chanhost" } else { set mask "*!*@$chanhost" }
            lappend ublist $mask
        } else {
            lappend ublist $i
        }
    }
    
    set noton "";
    foreach item $unbanlist {
        debug 2 "arm:cmd:unban: item: $item"
        if {[regexp -- {\*} $item]} {
            # -- hostmask
            set tmask $item
            debug 2 "arm:cmd:unban: item is hostmask: $tmask"
        } else {
            # -- nickname
            lassign [split [getchanhost $item] @] tident thost
            if {$thost == ""} {
                # -- cannot convert nick to host
                lappend noton $item
            } else {
                if {[string match "~*" $tident]} { set tmask "*!~*@$thost" } else { set tmask "*!*@$thost" }
                debug 2 "arm:cmd:unban: item was nickname $item, now host: $tmask"
                lappend ublist $tmask
            }
        }
    }

    set length [llength $ublist]

    if {$ublist != ""} {
        debug 0 "arm:cmd:unban: unbanning $length hostmasks from $chan"
        if {$length >= 6} { set modes "-bbbbbb" } else { set modes "-[string repeat "b" $length]" }
        putnow "MODE $chan $modes [join $ublist]"
        if {$type != "pub"} { reply $type $target "done." }
    }
    
    if {$noton != ""} {
        reply $type $target "\002error\002: no such nick or host ([join $noton ", "])"
    }
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: topic
# usage: topic ?chan? <topic>
proc arm:cmd:topic {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "topic"
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- check for channel
    set first [lindex $arg 0]
    if {[string index $first 0] eq "#"} {
        set chan $first; set topic [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set topic [lrange $arg 0 end]
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
     
    if {![onchan $botnick $chan]} { reply $type $target "sorry! unable to set topics when not in a channel."; return; }
    if {![botisop $chan]} { reply $type $target "sorry! unable to set topics when not oppped myself."; return; }
    
    if {$topic eq ""} { reply $stype $starget "topic: ?chan? <topic>"; return; }
 
    if {[cfg:get topic:who $chan]} { set topic "$topic ($user)" }; # -- append user who set the topic, if configured to
    debug 0 "arm:cmd:topic: setting topic in $chan: $topic"
    putquick "TOPIC $chan :$topic"
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}


# -- command: black
# usage: black ?chan? <nick>
# adds blacklist entry and kickbans <nick> from chan
proc arm:cmd:black {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable corowho;
    variable nickdata;

    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "black"    
    lassign [db:get id,user users curnick $nick] uid user
    
    set snick [split $nick];  # -- make safe for use in arrays
    
    # -- check for channel
    if {[string index [lindex $arg 0] 0] eq "#" || [lindex $arg 0] eq "*"} {
        set chan [lindex $arg 0]; set tnick [lindex $arg 1];
        set reason [lrange $arg 2 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set tnick [lindex $arg 0]; set reason [lrange $arg 1 end]
    }
    set ltnick [string tolower $tnick]
    set stnick [split $tnick]

    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    set lchan [string tolower $chan]
    
    if {$tnick eq ""} { reply $stype $starget "\002usage:\002 black ?chan? <nick> \[reason\]"; return; }
    #if {![onchan $tnick $chan]} { reply $type $target "uhh... who is $tnick?"; return; }
    if {[string tolower $nick] eq [string tolower $tnick]} { reply $type $target "uhh.. mirror?"; return; }
        
    if {$reason eq ""} { set reason [cfg:get def:breason $chan] }
    
    set txuser 0;
    if {[onchan $tnick]} {
        set tuhost [getchanhost $tnick]
        lassign [split $tuhost @] tident thost
        if {[dict exists $nickdata $ltnick account]} {
            set txuser [dict get $nickdata $ltnick account]
        }
    } else {
        # -- execute /who so we know what to add & kickban
        debug 1 "arm:cmd:black: $nick requesting black hit on $tnick, sending /who" 
        set corowho($ltnick) [info coroutine]
        putquick "WHO $tnick n%nuhiart,105"
        lassign [yield] tident thost tuxser
        unset corowho($ltnick)
    }

    if {$tident eq 0} {
        # -- this means the nick was not online
        reply $type $target "\002error:\002 $tnick is not online."
        return;
    }

    #debug 0 "who: tnick: $tnick -- tident: $tident -- thost: $thost -- txuser: $txuser"

    set timestamp [unixtime]
    set modifby "$nick!$uh"
    lassign [split [getchanhost [join $snick]] @] ident host; # -- TODO: won't work when nick in no common chan
    set action "B"
    
    if {$txuser eq 0 || $txuser eq ""} {
        # -- not logged in, do host entry
        set method "host"; set value [getmask $tnick $txuser $tident $thost]
    } else {
        # -- logged in, add username entry
        set method "user"; set value $txuser      
    }
    debug 1 "who: adding auto blacklist entry: type: B -- chan: $chan -- method: $method -- \
        value: $value -- modifby: $modifby -- action: $action -- reason: $reason"
    set tid [db:add B $chan $method $value $modifby $action "" $reason]; # -- add the entry        

    # -- add the ban
    kickban $tnick $tident $thost $chan [cfg:get ban:time $chan] $reason $tid

    reply $type $target "added $method blacklist entry for: $value (\002id:\002 $tid \002reason:\002 $reason)"

    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: asn
# usage: asn <host/ip>
# does IP lookup for ASN (autonomous system number)
proc arm:cmd:asn {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "asn"
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- check for channel
    set chan [userdb:get:chan $user $chan]; set tnick [lindex $arg 0]; set reason [lrange $arg 1 end]
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    set lchan [string tolower $chan]
    
    set ip [lindex $arg 0]
    if {$ip == ""} { reply $stype $starget "\002usage:\002 asn <ip|host>"; return; }
    
    # -- this only returns the ASN itself
    #set asn [geo:ip2asn $ip]
    
    # -- reverse the IP
    # -- TODO: IPv6 lookups
    if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
        # -- presumed to be hostname
        set ip [lindex [dns:lookup $ip] 0]
        if {$ip == "NULL" || $ip == "" || $ip == "error"} { 
            reply $type $target "error: lookup failed.";
            return;
        } else {
            # -- host->ip resolution successful
            regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d
        }
    }
    set revip "$d.$c.$b.$a"  
    set answer [dns:lookup $revip.origin.asn.cymru.com TXT]
    
    # -- example:
    # 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
    
    if {$answer == "NULL" || $answer == "" || $answer == "error"} { reply $type $target "error: lookup failed."; return; }
    
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
    set answer [dns:lookup AS$asn.asn.cymru.com TXT]

    # -- example:
    # 7545 | AU | apnic | 1997-04-25 | TPG-INTERNET-AP TPG Internet Pty Ltd
    if {$answer == "NULL" || $answer == ""} { set desc "none" }
    set string [split $answer "|"]
    set desc [lindex $string 4]
    set desc [string trimleft $desc " "]
    
    debug 1 "arm:cmd:asn: asn lookup for $ip is: $asn (desc: $desc bgp: $bgp country: $country registry: $registry allocation: $allocation info: http://www.robtex.com/as/as${asn}.html)"
    
    reply $type $target "\002(\002ASN\002)\002 for $ip is $asn \002(desc:\002 $desc -- \002bgp:\002 $bgp -- \002country:\002 $country -- \002registry:\002 $registry -- \002allocation:\002 $allocation -- \002info:\002 http://www.robtex.com/as/as${asn}.html\002)\002"
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
    return;
}

# -- command: chanscan
# usage: chanscan
# does full channel scan (simulates all users joining)
proc arm:cmd:chanscan {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable cfg
    variable scan:full; # -- tracks data for full channel scan by chan,key (for handling by arm::scan after /WHO):
                        #    chan,state :  tracks enablement
                        #    chan,count :  the count of users being scanned
                        #    chan,type  :  the type for responses
                        #    chan,target:  the target for responses
                        #    chan,start :  the start time for runtime calc
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "chanscan"
    lassign [db:get id,user users curnick $nick] uid user

    if {[string index [lindex $arg 0] 0] eq "#"} {
        set chan [lindex $arg 0];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    set lchan [string tolower $chan];  # -- make safe for arrays
    #if {$chan eq ""} { reply $stype $starget "\002usage:\002 chanscan <chan>"; return; }
    
    if {![validchan $chan]} { reply $type $target "uhh... negative."; return; }
    if {![isop $botnick $chan]} { reply $type $target "uhh... op me in $chan?"; return; }
    if {![onchan $botnick $chan]} { reply $type $target "uhh... how?"; return; }
        
    debug 1 "arm:cmd:chanscan: doing full chanscan for $chan"
    
    if {$type ne "pub"} { putquick "NOTICE @$chan :Armour: beginning full channel scan... fire in the hole!" }
    if {$chan ne [cfg:get chan:report $chan]} { putquick "NOTICE [cfg:get chan:report $chan] :Armour: beginning full channel scan... fire in the hole!" }
        
    reply $type $target "scanning $chan..."
    set start [clock clicks]

    # -- unset existing tracking data for chan
    foreach i [array names scan:full "$lchan,*"] {
        unset scan:full($i)
    }

    # -- setup array data for /WHO response handling
    set scan:full($lchan,state) 1;        # -- state enabled
    set scan:full($lchan,count) 0;        # -- count of users scanned
    set scan:full($lchan,type) $type;     # -- command type for responses
    set scan:full($lchan,target) $target; # -- target for responses
    set scan:full($lchan,start) $start;   # -- start time (to calculate runtime)
    
    putquick "WHO $chan cd%cnuhiartf,102";   # -- handled by raw:who and raw:endofwho
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}


# -- command: mode
# usage: mode <off|on|secure>
# changes Armour mode ('secure' uses chanmode +Dm)
proc arm:cmd:mode {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable dbchans;
    variable chan:id;       # -- the id of a registered channel (by channel)
    variable chan:mode;     # -- the operational mode of the registered channel (by chan)
    variable chan:modeid;   # -- the operational mode of the registered channel (by id)
    variable scan:list;     # -- the list of nicknames to scan in secure mode:
                            #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                            #        nicks,*    :  the nicks being scanned
                            #        who,*      :  the current wholist being constructed
                            #        leave,*    :  those already scanned and left
                              
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "mode"
    lassign [db:get id,user users curnick $nick] uid user

    # -- determine channel
    if {[string index [lindex $arg 0] 0] eq "#"} {
        set chan [lindex $arg 0]
        set mode [string tolower [lindex $arg 1]]; set nomode [lindex $arg 2]
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set mode [string tolower [lindex $arg 0]]; set nomode [lindex $arg 1]
    }
    set lchan [string tolower $chan]
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    set id [get:val chan:id $chan]; set cid $id
    if {$type ne "pub"} { set xtra " on $chan" } else { set xtra "" }
    if {$mode eq ""} { reply $type $target "mode$xtra is: [get:val chan:modeid $id]"; return; }
    
    # -- prevent secure mode if ircd doesn't support it
    if {[cfg:get ircd $chan] eq 1} {
        # -- ircu (Undernet/Quakenet)
        if {$mode ne "on" && $mode ne "off" && $mode ne "secure" && $mode ne ""} {
            reply $stype $starget "\002usage:\002 mode ?chan? <on|off|secure> \[-nomode\]";
            return;
        }
    } elseif {[cfg:get ircd $chan] eq 2} {
        # -- IRCnet/EFnet
        if {$mode ne "on" && $mode ne "off" && $mode ne ""} {
            reply $stype $starget "\002usage:\002 mode ?chan? <on|off>";
            return;
        }
    }
    
    if {[string match -nocase "-nomode*" $nomode]} { set domode 0 } else { set domode 1} 
    
    debug 1 "arm:cmd:mode: changing mode on chan: $chan to: $mode ($source)"
        
    set cid [db:get id channels chan $chan]
    set exist [db:get value settings setting mode cid $cid]
    db:connect
    if {$exist eq ""} {
        # -- insert
        db:query "INSERT INTO settings (cid,setting,value) VALUES ($cid,'mode','$mode')"
    } else {
        # -- update
        db:query "UPDATE settings SET value='$mode' WHERE setting='mode' AND cid='$cid'"
    }
    db:close
    set chan:modeid($id) $mode;       # -- mode by chanid; TODO: deprecated?
    set chan:mode($lchan) $mode;      # -- mode by chan;   TODO: deprecated?
    dict set dbchans $id mode $mode;  # -- dict: channel mode
    
    # -- flush any existing trackers (safety net)
    set leavelist [get:val scan:list leave,$lchan]
    set nicklist [get:val scan:list nicks,$lchan]
    set wholist [get:val scan:list who,$lchan]
    set datalist [get:val scan:list data,$lchan]
    if {$wholist ne ""} { debug 4 "\002cmd:mode: clearing scan:list(who,$lchan):\002 $wholist"; unset scan:list(who,$lchan); }
    if {$datalist ne ""} { debug 4 "\002cmd:mode: clearing scan:list(data,$lchan):\002 $datalist"; unset scan:list(data,$lchan); }
    if {$nicklist ne ""} { debug 4 "\002cmd:mode: clearing scan:list(nicks,$lchan):\002 $nicklist"; unset scan:list(nicks,$lchan); }
    if {$leavelist ne ""} { debug 4 "\002cmd:mode: clearing scan:list(leave,$lchan):\002 $leavelist"; unset scan:list(leave,$lchan); }
    
    # -- secure mode?
    if {$mode eq "secure"} {
        if {![botisop $chan]} { 
            debug 2 "arm:cmd:mode: cannot change mode to secure, not opped on $chan"
            reply $type $target "$nick: cannot change mode, I'm not opped${xtra}."
            return;
        }
        putquick "MODE $chan +Dm"
        if {$domode} {
            foreach client [chanlist $chan] {
                if {![isop $client $chan] && ![isvoice $client $chan]} {
                    lappend voicelist $client
                }
            }
            # -- stack the voices
            if {[info exists voicelist]} {
                while {$voicelist ne ""} {
                    # -- voice stack workaround (pushmode doesn't work as client not in chan yet)
                    set length [llength $voicelist]
                    if {$length >= 6} { set modes "+vvvvvv" } else { set modes "+[string repeat "v" $length]" }
                    debug 2 "arm:cmd:mode: executing: MODE $chan $modes [join [lrange $voicelist 0 5]]"
                    putquick "MODE $chan $modes [join [lrange $voicelist 0 5]]"
                    set voicelist [lreplace $voicelist 0 5]
                }
            }
        }
        debug 2 "arm:cmd:mode: secure mode activated, voiced all users"
    } else {
        set chanmode [lindex [getchanmode $chan] 0]
        if {[string match *D* $chanmode] eq 1 && [string match *m* $chanmode] eq 1} {
            # -- turn off chanmode +Dm, if already set
            putquick "MODE $chan -Dm"
            
            # -- kill any existing arm:secure timers
            foreach utimer [utimers] {
                set thetimer [lindex $utimer 1]
                if {$thetimer ne "arm:secure"} { continue; }
                debug 1 "arm:cmd:mode: killing arm:secure utimer: $utimer"
                killutimer [lindex $utimer 2] 
            }
            
            if {$domode} {
                # -- devoice users that aren't opped, voiced, or authenticated
                # -- TODO: make this behaviour configurable (could be disruptive on chans toggling between modes)
                foreach client [chanlist $chan] {
                    if { [isop $client $chan]     } { continue; }
                    if { [userdb:isLogin $client] } { continue; }
                    # -- TODO: also leave users which match a whitelist with voice action
                    lappend devoicelist $client
                }
                # -- stack the voices
                if {[info exists devoicelist]} {
                    while {$devoicelist ne ""} {
                        # -- voice stack workaround (pushmode doesn't work as client not in chan yet)
                        set length [llength $devoicelist]
                        if {$length >= 6} { set modes "-vvvvvv" } else { set modes "-[string repeat "v" $length]" }
                        debug 2 "arm:cmd:mode: executing: MODE $chan $modes [join [lrange $devoicelist 0 5]]"
                        putquick "MODE $chan $modes [join [lrange $devoicelist 0 5]]"
                        set devoicelist [lreplace $devoicelist 0 5]
                    }
                }
            }
        }
    }
        
    reply $type $target "done."
    
    if {$mode eq "secure"} {
        # -- start '/names -d' timer
        mode:secure
    }
    
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
    return;
}

# -- command: country
# usage: country <ip|host>
# does IP lookup for country (geo lookup with mapthenet.org)
proc arm:cmd:country {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "country"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template
    
    set ip [lindex $arg 0]
    if {$ip == ""} { reply $stype $starget "\002usage:\002 country <ip|host>"; return; }
    
    #set country [geo:ip2country $ip]
        
    # -- reverse the IP
    # -- TODO: IPv6 lookups
    if {![regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d]} {
        # -- presumed to be hostname
        set ip [lindex [dns:lookup $ip] 0]
        if {$ip == "NULL" || $ip == "" || $ip == "error"} { 
            reply $type $target "error: lookup failed.";
            return;
        } else {
            # -- host->ip resolution successful
            regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip -> a b c d
        }
    }
    
    set revip "$d.$c.$b.$a"  
    set answer [dns:lookup $revip.origin.asn.cymru.com TXT]
    
    # -- example:
    # 7545 | 123.243.188.0/22 | AU | apnic | 2007-02-14
    
    if {$answer == "NULL" || $answer == "" || $answer == "error"} { reply $type $target "error: country lookup failed."; return; }
    
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
    set answer [dns:lookup AS$asn.asn.cymru.com TXT]

    # -- example:
    # 7545 | AU | apnic | 1997-04-25 | TPG-INTERNET-AP TPG Internet Pty Ltd
    if {$answer == "NULL" || $answer == ""} { set desc "none" }
    set string [split $answer "|"]
    set desc [lindex $string 4]
    set desc [string trimleft $desc " "]
    
    debug 1 "arm:cmd:country: country lookup for $ip is: $country (desc: $desc bgp: $bgp country: $country registry: $registry allocation: $allocation info: http://www.robtex.com/as/as${asn}.html)"
    
    reply $type $target "\002(\002country\002)\002 for $ip is $country \002(desc:\002 $desc -- \002asn:\002 $asn -- \002bgp:\002 $bgp -- \002registry:\002 $registry -- \002allocation:\002 $allocation -- \002info:\002 http://www.robtex.com/as/as${asn}.html\002)\002"
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    return;
}

# -- command: scanrbl
# usage: scanrbl <ip|host>
# scans dnsbl servers for match
proc arm:cmd:scanrbl {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    set type $0
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "scanrbl"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template
    
    # -- command: scanrbl

    set host [lindex $arg 0]

    if {$host == ""} { reply $stype $starget "\002usage:\002 scanrbl <host|ip>"; return; }

    set response [rbl:score $host 1]; # -- onlymanual=1 flag

    set ip [lindex $response 0]
    set response [join $response]
    set score [lindex $response 1]

    if {$ip != $host} { set dst "$ip ($host)" } else { set dst $ip }

    if {$score <= 0} { reply $type $target "no dnsbl match \002(ip:\002 $dst\002)\002"; return; }

    debug 1 "arm:cmd:scanrbl: match found: $response"

    set dnsbl [lindex $response 2]
    set desc [lindex $response 3]
    set info [join [lindex $response 4]]

    if {$info ne "" && $info ne "1"} {
        reply $type $target "\002(\002dnsbl\002)\002 $dnsbl \002desc:\002 $desc \002(ip:\002 $dst -- \002score:\002 $score -- \002info:\002 $info\002)\002"
    } else {
        reply $type $target "\002(\002dnsbl\002)\002 $dnsbl \002desc:\002 $desc \002(ip:\002 $dst -- \002score:\002 $score\002)\002"
    }
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: scanport
# usage: scanport <host|ip> [port1,port2,port3...]
# scans for open ports
proc arm:cmd:scanport {0 1 2 3 {4 ""} {5 ""}} { arm:cmd:scanports $0 $1 $2 $3 $4 $5 }
proc arm:cmd:scanports {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    variable scan:ports
    set type $0
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "scanport"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    set host [lindex $arg 0]
    set customports [lindex $arg 1]
    
    if {$host == ""} { reply $stype $starget "\002usage:\002 scanports <host|ip> \[port1,port2,port3...\]"; return; }
        
    set openports [port:scan $host $customports]
    
    if {$openports == ""} {
        debug 1 "arm:cmd:scanports: no open ports at: $host"
        reply $type $target "no open ports \002(ip:\002 $host\002)\002"
        return;
    }
    
    debug 1 "arm:cmd:scanports: response: $openports"
    
    reply $type $target "\002(\002open ports\002)\002 -> $openports"
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: exempt
# usage: exempt <nick>
# add a temporary join scan exemption (1 min)
proc arm:cmd:exempt {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable nick:override; # -- state: storing whether a manual exempt override is active (by chan,nick)
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "exempt"
    lassign [db:get id,user users curnick $nick] uid user
    
    if {[string index [lindex $arg 0] 0] == "#"} {
        lassign $arg chan exempt mins
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        lassign $arg exempt mins
    }
    if {![userdb:isAllowed $nick $cmd $chan $type] && ![isop $nick $chan]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    # -- command: exempt
    
    if {$exempt eq ""} { reply $stype $starget "\002usage:\002 exempt ?chan? <nick> \[mins\]"; return; }
    if {$mins eq ""} { set mins [cfg:get exempt:time $chan] }
    
    # -- safety net
    if {[regexp -- {^\d+$} $mins]} {
      if {$mins <= 0 || $mins > 1440} { reply $type $target "error: mins must be between 1-1440"; return; }
    } else { reply $type $target "error: mins must be an integer between 1-1440"; return; }
        
    debug 1 "arm:cmd:exempt: $nick is adding temporary $mins mins exemption (override) for $exempt"
    
    reply $type $target "done."
    
    set exempt [split $exempt]
    set nick:override([string tolower $exempt]) 1
    
    # -- unset later
    timer $mins "catch { unset nick:override([string tolower $exempt]) }"
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: scan
# usage: scan <value>
# ie. scan Empus
# ie: scan 172.16.4.5
# ie. scan Empus!empus@172.16.4.5/why? why not?
# scans all appropriate lists for match
proc arm:cmd:scan {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable entries
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "scan"

    lassign [db:get id,user users curnick $nick] uid user

    # -- deal with the optional channel argument
    set first [lindex $arg 0];
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        # -- chan (or global) provided
        set chan $first; set search [lindex $arg 1]
    } else {
        # -- chan not provided
        set search [lindex $arg 0]
        set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    }
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    # -- end default proc template
    
    # -- command: scan
    
    if {$search eq ""} { reply $stype $starget "\002usage:\002 scan ?chan? <nick|host|ip|mask|account|asn>"; return; }
    
    # -- runtime counter
    set start [clock clicks]
    
    debug 1 "arm:cmd:scan: value: $search"
    
    # -- we need to determine what the value is
    
    set ip 0; set ipscan 0; set nuhr 0; set nuh 0; set hostmask 0; set host 0; set nickxuser 0;
    set nick 0; set dnsbl 0; set match 0; set regexp 0;
    set tnick ""; set tident ""; set thost ""; set tip ""; set trname ""; set country ""; set asn ""; set txuser ""
    
    # -- check for IP
    if {[regexp -- {^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$} $search]} {
        # -- value is IP
        debug 2 "arm:cmd:scan: value: $search is type: IP"
        set ip 1; set ipscan 1;
        set vtype "ip"
        set dnsbl 1
        set tip $search
        set thost $tip
        set match 1
        set country [geo:ip2country $tip]
        set asn [geo:ip2asn $tip]
        debug 2 "arm:cmd:scan: asn: $asn -- country: $country"
    }
    
    # -- check for nick!user@host/rname
    if {[regexp -- {^([^!]+)!([^@]+)@([^/]+)/(.+)$} $search -> tnick tident thost trname]} {
        # -- value is nick!user@host/rname (regex)
        debug 2 "arm:cmd:scan: value: $search is type: nuhr (regex)"
        set regexp 1
        set dnsbl 1; set ipscan 1;
        set vtype "regex"
        set match 1
    }
    
    # -- check for nick!user@host
    if {[regexp -- {^([^!]+)!([^@]+)@([^/]+)$} $search -> tnick tident thost]} {
        # -- value is nick!user@host
        debug 2 "arm:cmd:scan: value: $search is type: nuh"
        set nuh 1; set ipscan 1
        set dnsbl 1
        set vtype "nuh"
        set match 1
    }
    
    # -- check if thost is IP?
    if {[regexp -- {^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$} $thost] && $ip != 1} {
        set tip $thost
        set thost tip
        set match 1
        set country [geo:ip2country $tip]
        set asn [geo:ip2asn $tip]
        set ipscan 1
        debug 2 "arm:cmd:scan: asn: $asn country: $country"
    }
    
    # -- check for ASN
    if {[regexp -- {^(AS)?[0-9]+$} $search]} {
        # -- value is ASN
        debug 2 "arm:cmd:scan: value: $search is type: ASN"
        set vtype "asn"
        set match 1
        set asn $search; set ipscan 1
    }

    # -- check for existence of '*'
    if {[regexp -- {\*} $search]} {
        # -- value is hostmask
        debug 2 "arm:cmd:scan: value: $search is type: hostmask"
        set hostmask 1
        set vtype "hostmask"
        set match 1
    }

    # -- check for existence of '.'
    if {[string match "*.*" $search] eq 1 && $regexp ne 1 && $nuh ne 1 && $hostmask ne 1 && $ip ne 1} {
        # -- value is hostname
        debug 2 "arm:cmd:scan: value: $search is type: hostname"
        set host 1; set ipscan 1
        set thost $search
        set vtype "host"
        set match 1
    }
    
    # -- if no match so far, must be nickname, username or country
    if {!$match} {
        # -- value is either nickname, username or country
        if {[regexp -- {^[A-Za-z0-9-]+$} $search] && [string length $search] > 2} {
            # -- nickname or username
            debug 2 "arm:cmd:scan: value: $search is type: nickname or username"
            set nickxuser 1
            set vtype "nickxuser"
            set txuser $search
        } else {
            if {[string length $search] > 2} {
                # -- must be a nickname
                debug 2 "arm:cmd:scan: value: $search is type: nickname"
                set nick 1
                set vtype "nick"
                set tnick $search
            }
            # -- either a nickname or country
            set vtype "nickgeo"
            debug 2 "arm:cmd:scan: value: $search is type: nickgeo"
        }
        # -- get host
    }

    set hits 0; set mcount 0; set match 0;
    foreach ltype "white black" {
        debug 0 "\002arm:scan:\002 looping: ltype: $ltype -- chan: $chan"
        # arm::scan:match chan ltype id method value ipscan nick ident host ip xuser rname ?country? ?asn? ?cache? ?hits? ?text?

        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {([dict get $dictData chan] eq $chan || [dict get $dictData chan] eq "*") \
            && [dict get $dictData type] eq $ltype}
        }]]

        set cache "";
        putlog "arm:scan: ids: $ids"
        foreach id $ids {
            set tchan [dict get $entries $id chan]
            set method [string tolower [dict get $entries $id method]]
            set value [dict get $entries $id value]

            debug 4 "\002arm:scan:\002 looping: id: $id -- tchan: $tchan -- method: $method -- value: $value (ltype: $ltype)"

            # -- check match, recursively
            lassign [scan:match $tchan $ltype $id $method $value $ipscan $tnick $tident $thost $tip $txuser $trname $country $asn $cache $hits] \
                match hit todo what cache hits country asn

            putlog "id: $id -- what: $what -- match: $match -- hit: $hit -- cache: $cache -- hits: $hits"
            
            if {$match} {
                # -- there was a match!
                if {$mcount >= 5} { break; }; # -- max output of 5 rows
                reply $type $target [list:return $id]
                incr mcount;
            }
        }
        if {$mcount >= 5} { break; }; # -- max output of 5 rows
     }

        
    # -- text pattern scans
    # -- TODO
        
    # -- dnsbl checks (if not ipv6)
    if {$dnsbl && ![string match "*:*" $ip]} {
        debug 2 "arm:cmd:scan: scanning for dnsbl match: $thost (tip: $tip)"
        # -- get score
        set response [rbl:score $thost]

        set ip [lindex $response 0]
        set response [join $response]
        set score [lindex $response 1]
        if {$ip ne $thost} { set dst "$ip ($thost)" } else { set dst $ip }
        if {$score > 0} {
            # -- match found!
            set match 1
            debug 2 "arm:cmd:scan: dnsbl match found for $thost: $response"
            set rbl [lindex $response 2]
            set desc [lindex $response 3]
            set info [lindex $response 4]
            reply $type $target "\002dnsbl match:\002 $rbl \002desc:\002 $desc (\002ip:\002 $dst \002score:\002 $score \002info:\002 [join $info])"
        } else {
            debug 1 "arm:cmd:scan: no dnsbl match found for $thost"
        }
    }
    # -- end of dnsbl

    set runtime [runtime $start]

    if {!$match} {
        reply $type $target "scan negative (runtime: $runtime)" 
    } else {
        reply $type $target "scan complete (results: $mcount -- runtime: $runtime)"
    }
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" "" 
}

# -- command: search
# usage: search ?chan? <type> <method> <value>
# ie: search ?chan? <white|black|*> <wildcard>
# scans lists for matching value
proc arm:cmd:search {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    variable entries;         # -- dict: blacklist and whitelist entries
    set start [clock clicks]; # -- runtime counter
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "search"

    lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0]; set anychan 0;
    if {([string index $first 0] eq "#" && [string match "\*" $first] ne 1) || $first eq "*" || [string index $first 0] eq "?"} {
        # -- '*' denotes global entries
        # -- '?' denotes any entry channel
        if {[string index $first 0] eq "?"} { set anychan 1 }
        set chan $first; set search [lindex $arg 1]; set tlist [lindex $arg 2]; set method [lrange $arg 3 4]
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set search [lindex $arg 0]; set tlist [lindex $arg 1]; set method [lrange $arg 2 3]
    }

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }

    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    # -- end default proc template
    
    set mcount 0; set match 0; set gmatch 0;

    putlog "arg: $arg"
    putlog "chan: $chan -- search: $search -- tlist: $tlist -- method: $method"
    
    set usage 0
    if {$search eq ""} { set usage 1 }
    if {$tlist eq "" || $tlist eq "-type"} { set tlist "*" }
    if {$tlist eq "*"} {
        set lists "white black"
    } elseif {[string index $tlist 0] eq "w"} {
        set lists "white"; set tlist "white"
    } elseif {[string index $tlist 0] eq "b"} {
        set lists "black"; set tlist "black"
    } else { set usage 1 }

    # -- make the list type optional
    if {[lsearch $arg "-type"] ne -1} {
        set method [lindex $arg [expr [lsearch $arg "-type"] + 1]]
    }
    if {$method eq ""} { set method "*" }
    #if {[lindex $method 0] eq "-type"} {
    #    set method [lindex $method 1]; # -- use the given list entry method
    #} else { set method "*"}; # -- all methods

    debug 4  "cmd:search: chan: $chan -- tlist: $tlist -- method: $method -- search: $search"

    if {$usage} {
        # -- invalid list type
        reply $stype $starget "\002usage:\002 search ?chan? <value> \[white|black|*\] \[-type <method>]"
        return;
    }

    set listtype $method
    foreach list $lists {
        debug 4 "cmd:search: beginning ${list}list matching in $chan";
        # -- check if chan '?' is used (denoting any channel)
        if {$anychan} {
            set ids [dict keys [dict filter $entries script {id dictData} {
                expr {[dict get $dictData type] eq $list && [string match -nocase $listtype [dict get $dictData method]] eq 1}
            }]]            
        } else {
            # -- channel specified
            set ids [dict keys [dict filter $entries script {id dictData} {
                expr {[string tolower [dict get $dictData chan]] in "[string tolower $chan] *" \
                && [dict get $dictData type] eq $list && [string match -nocase $listtype [dict get $dictData method]] eq 1}
            }]]
        }
        debug 5 "cmd:search: \002ids:\002 $ids"
        foreach id $ids {
            set tchan [dict get $entries $id chan]
            set ltype [dict get $entries $id type]
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            debug 5 "cmd:search: looping: id: $id -- tchan: $chan -- ltype: $ltype -- method: $method -- value: $value"
            if {$method eq "regex"} {
                # -- regex pattern
                if {[regexp -nocase $value $search]} {
                    set match 1; incr mcount; set gmatch 1
                }
            } elseif {[string match -nocase $search $value]} {
                # -- wildcard match!
                set match 1; incr mcount; set gmatch 1
            }
            if {$mcount > 5 && $type ne "dcc"} { 
                set runtime [runtime $start]
                reply $type $target "too many matches ([llength $ids]), please refine search ($runtime)"
                return;
            }
            if {$match} {
                debug 1 "cmd:search: \002matched\002 $search (id: $id -- type: $ltype -- method: $method)"
                # -- send response
                reply $type $target [list:return $id]
                set match 0; # -- reset for loop
            }            
        }
    }

    # -- end of list type looping

    set runtime [runtime $start]
    
    if {!$gmatch} {
        if {$tlist eq "*"} { set tlist "whitelist or blacklist" } else { set tlist "${tlist}list" }
        reply $type $target "no $tlist match found for: $search ($runtime)" 
    } else {
        reply $type $target "search complete (\002results:\002 $mcount -- \002runtime:\002 $runtime)"
    }
    
    # -- create log entry for command use
    if {$chan eq "?"} { set chan "*"}
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: load
proc arm:cmd:reload {0 1 2 3 {4 ""} {5 ""}} { arm:cmd:load $0 $1 $2 $3 $4 $5 }
proc arm:cmd:load {0 1 2 3 {4 ""}  {5 ""}} {
    variable entries; # -- dict to store blacklist and whitelist entries
    variable dbusers; # -- dict to store user db entries
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "load"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    debug 1 "arm:cmd:load: loading list entries to memory"
    
    # -- loading list arrays from file
    db:load
    
    # -- loading user db from file
    userdb:db:load
    
    set wcount 0; set bcount 0;
    set ids [dict keys $entries]
    foreach id $ids {
        set ltype [dict get $entries $id type]
        if {$ltype eq "white"} { incr wcount } elseif {$ltype eq "black"} { incr bcount }
    }
    set ucount [llength [dict keys $dbusers]]
    
    reply $type $target "loaded \002$wcount\002 whitelist, \002$bcount\002 blacklist, and \002$ucount\002 user entries to memory"
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- cmd: rehash
# -- save db's & rehash eggdrop
proc arm:cmd:rehash {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "rehash"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- rehash bot
    rehash

    reply $type $target "done." 
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- cmd: restart
# -- syntax: restart [reason]
# -- save db's & restart eggdrop
proc arm:cmd:restart {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "restart"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    set reason [lrange $arg 0 end]
    if {$reason == ""} { set reason "requested by $nick!$uh ($user)" }

    # -- quit server connection gracefully first (so restart doesn't 'EOF')
    putnow "QUIT :restarting: $reason"

    # -- restart bot
    restart
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- cmd: restart
# -- syntax: die [reason]
# -- save db's & kills bot
proc arm:cmd:die {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "die"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    set safety [lindex $arg 0]
    if {[string tolower $safety] ne "-force"} { reply $stype $starget "seriously? use: die -force <reason>"; return; }
    set reason [lrange $arg 1 end]
    if {$reason eq ""} { set reason "requested by $nick!$uh ($user)" }

    # -- quit server connection gracefully first (so die doesn't 'EOF')
    putnow "QUIT :shutdown: $reason"

    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    
    # -- kill bot
    die $reason
}

# -- command bot to speak
proc arm:cmd:say {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "say"
    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]

    set dest [lindex $arg 0]
    set string [join [lrange $arg 1 end]]
    
    set action 0; set idx 0
    if {$dest eq "-a"} {
        # -- action (/me)
        set action 1; set dest [lindex $arg 1]; set idx 1
    } 
    
    set msglist [list];
    if {$dest eq "*"} {
        # -- global say (all chans)
        # -- TODO: this should require global access, even if channel specific doesn't
        foreach i [channels] {
            if {[botonchan $i] && [userdb:isAllowed $nick $cmd $dest $type]} {
                lappend msglist $i
            }
        }
        incr idx
    } elseif {[string index $dest 0] eq "#"} {
            # -- channel provided; do they have access for that chan?
            if {![userdb:isAllowed $nick $cmd $dest $type] || ![botonchan $dest]} { reply $type $target "no, they won't like that."; return; }
            set mchan $dest; set msglist $mchan; incr idx
    } else {
        # -- chan not provided, we need to determine channel
        # -- TODO: this should only work for people in same chan, unless user has global access
        set mchan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set msglist $mchan
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set msglist [join $msglist ,]
    if {$action} { set string "\001ACTION [lrange $arg $idx end]\002" } else { set string [lrange $arg $idx end] }
    if {$msglist eq "" || $string eq ""} { reply $stype $starget "\002usage:\002 say \[-a\] <chan|*> <string>"; return;  }
    
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    # -- send the message
    putquick "PRIVMSG $msglist :$string"
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
    
    return;
}




# -- cmd: jump
# -- syntax: jump [server]
# -- jump servers
proc arm:cmd:jump {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "jump"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- check if server can be provided
    set tserver [lindex $arg 0]
    if {[cfg:get jump *]} { set tserver [lindex $arg 0]; } else { set tserver "" }

    # -- check if ZNC bouncer used
    if {[cfg:get znc] eq 1} {
        if {$tserver ne ""} { putmsg *status "jump $tserver" } else { putmsg *status "jump" }
    } else {
        if {$tserver ne ""} { jump $tserver } else { jump }
    }
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: version
proc arm:cmd:version {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "version"
   
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template
    
    debug 1 "arm:cmd:version: version recall (user: $user -- uid: $uid -- chan: $chan)"

    set branch [cfg:get update:branch]
    lassign [update:check $branch] success ghdata output
    set status [dict get $ghdata status]
    set version [cfg:get version]

    if {$success eq 1} {

        if {$status eq "current"} {
            set out "current vs \002$branch\002 branch"
        } elseif {$status eq "newer"} {
            set out "newer than \002$branch\002 branch"
        } elseif {$status eq "outdated"} {
            set out "older than \002$branch\002 branch"
        } else { set out "unknown" }

        if {[dict get $ghdata update]} { set extra "-- update \002available:\002 update install" } else { set extra "" }
        append extra ")"

        reply $type $target "\002version:\002 Armour $version (\002revision:\002 [cfg:get revision *]\
                        -- \002status:\002 $out$extra"

    } else {
        # -- github check failed
        reply $type $target "\002version:\002 Armour $version (\002revision:\002 [cfg:get revision *]\
            -- \002github:\002 unavailable"       
    }
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: idle
proc arm:cmd:idle {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "idle"
   
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- deal with the optional channel argument
    set first [lindex $arg 0]; set ischan 0
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        # -- chan (or global) provided
        set ischan 1; set chan $first; set tnick [lindex $arg 1];
    } else {
        # -- chan not provided
        set tnick [lindex $arg 0];
        set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    }

    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    debug 1 "arm:cmd:idle: idle check (user: $user -- uid: $uid -- chan: $chan)"
    
    if {$tnick eq ""} { reply $type $target "\002usage:\002 idle ?chan? <nick>"; return; } 

    set cidle [expr [getchanidle $tnick $chan] * 60]; # -- convert to seconds
    set unixtime [unixtime]
    set idle [userdb:timeago [expr $unixtime - $cidle]]    
    debug 0 "\002arm:cmd:idle:\002 chan: $chan -- tnick: $tnick -- cidle: $cidle -- unixtime: $unixtime -- idle: $idle"

    reply $type $target "\002chanidle:\002 $idle"
    
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: stats
proc arm:cmd:stats {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable entries;  # -- dict: blacklist and whitelist entries
    variable trakka;   # -- array storing all trakka values
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "stats"
    
    # -- ensure user has required access for command
    if {![userdb:isLogin $nick]} { return; }
    
    set where [lindex $arg 0]


    if {![userdb:isAllowed $nick $cmd $where $type]} { return; }; # -- check access for command in provided chan
    #if {$where ne "*" && [userdb:isValidchan $where] eq 0} { reply $type $target "\002error\002: channel $where is not registered."; return; }
    lassign [db:get id,user users curnick $nick] uid user

    # -- provide syntax only if chan is malformed
    if {($where ne "*" && [string index $where 0] ne "#") && $where ne ""} {
        reply $stype $starget "usage: stats \[chan|*\]";
        return;
    }

    # -- otherwise, determine chan?
    if {$where eq ""} {
        set where [userdb:get:chan $user $chan]
        #reply $stype $starget "usage: stats \[chan|*\]";
    }

    debug 1 "arm:cmd:stats: stats recall"
    
    set query "SELECT chan FROM channels"
    if {[string index $where 0] eq "#"} {
        set chan $where
        append query " WHERE lower(chan)='[db:escape [string tolower $where]]'"
        set cid [db:get id channels chan $where]
    } else {
        set chan "*"; set cid 1;
    }
    
    set methods "user host regex country asn chan rname text"; # -- entry methods 
    set types "white black"; # -- list types
    db:connect
    set chans [string tolower [join [join [db:query $query]]]]; # -- list of registered chans
    putlog "\002arm:stats:\002 chans: $chans"
    db:close
        
    foreach t $types {
        set count($t) [dict size [dict filter $entries script {id data} { expr {[dict get $data type] eq $t}}]]; # -- total list entries
        set hitcount($t) 0; # -- total hit count
        foreach m $methods {
            set count($t,$m) 0;    # -- global entry count
            set hitcount($t,$m) 0; # -- global hit count
            foreach c $chans {
                putlog "\002arm:stats:\002 t: $t -- c: $c -- m: $m"
                set count($t,$c,$m) 0;    # -- chan specific entry count
                set count($t,$c) 0;       # -- chan specific entry total
                set hitcount($t,$c,$m) 0; # -- chan specific hit count
                set hitcount($t,$c) 0;    # -- chan specific total
            }
        }
    }
    
    # -- calculate the totals
    foreach id [dict keys $entries] {
        set tchan [dict get $entries $id chan]
        set list [dict get $entries $id type]
        set method [dict get $entries $id method]
        set value [dict get $entries $id value]
        set hits [dict get $entries $id hits]
        
        incr count($list,$method);                 # -- global entry count
        incr hitcount($list,$method) $hits;        # -- global type hit total
        incr hitcount($list) $hits;                # -- global total
        
        incr count($list,$tchan,$method);          # -- chan specific entry type count
        incr count($list,$tchan);                  # -- chan specific entry count
        incr hitcount($list,$tchan,$method) $hits; # -- chan specific type hit total
        incr hitcount($list,$tchan) $hits;         # -- chan specific total
        debug 4 "cmd:stats: chan: $tchan -- list: $list -- method: $method -- value: $value -- id: $id -- hits: $hits"        
    }
    
    if {$where ne "*"} { set xtra " - $where" } else { set xtra "" }
    foreach t $types {
        set suffix ""
        set prefix "\002(\002${t}list$xtra\002)\002"
        if {$where ne "*"} {
            # -- chan specific entries
            set tt "$t,$where";
            set ccount [expr $count($tt) + $count($t)]
            set hcount [expr $hitcount($tt) + $hitcount($t)]
        } else {
            # -- only global entries
            set tt $t;
            set ccount $count($t)
            set hcount $hitcount($t)
        }
        append suffix "\002total:\002 $ccount \002hits:\002 $hcount -> "
        foreach m $methods {
            if {$where ne "*"} {
                # -- chan specific entries
                set ccount [expr $count($tt,$m) + $count($t,$m)]
                set hcount [expr $hitcount($tt,$m) + $hitcount($t,$m)]
            } else {
                # -- only global entries
                set ccount $count($t,$m)
                set hcount $hitcount($t,$m)
            }
            append suffix "(\002$m:\002 $ccount \002hits:\002 $hcount) -- "
        }
        set suffix [string trimright $suffix "-- "]
        reply $type $target "$prefix $suffix"; # -- send the response
    }

    # -- check if trakka is loaded
    if {[lsearch [binds] *trakka*] ne -1} {
        # -- check by chan
        if {[trakka:isEnabled $chan] || $chan eq "*"} {
            if {$chan eq "*"} {
                # -- check all trakka values
                set nmask "nick,*"
                set umask "uhost,*"
                set xmask "xuser,*"
                set out "global"
            } else {
                # -- check by chan
                set nmask "nick,$chan,*"
                set umask "uhost,$chan,*"
                set xmask "xuser,$chan,*"
                set out $chan 
            }
            set ncount [llength [array names trakka $nmask]]; # -- count of nickname trakkas
            set ucount [llength [array names trakka $umask]]; # -- count of uhost trakkas
            set xcount [llength [array names trakka $xmask]]; # -- count of xuser (account) trakkas
            reply $type $target "\002(\002trakka - $out\002)\002 \002nicks:\002 $ncount -- \002uhosts:\002 $ucount -- \002accounts:\002 $xcount"
        } 
    }

    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- cmd: status
# -- syntax: status [server]
# -- jump status
proc arm:cmd:status {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick server-online uptime
    variable cfg
    variable entries;  # -- dict: blacklist and whitelist entries  
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "status"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command 
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- cmd: status
    
    set wcount [dict size [dict filter $entries script {id data} { expr {[dict get $data type] eq "white"}}]]
    set bcount [dict size [dict filter $entries script {id data} { expr {[dict get $data type] eq "black"}}]]
    
    reply $type $target "\002server connection:\002 [userdb:timeago ${server-online}] -- \002bot uptime:\002 [userdb:timeago $uptime] -- \002machine:\002 [unames]"
    reply $type $target "\002uptime:\002 [exec uptime]"
    reply $type $target "\002traffic:\002 [expr [lindex [lindex [traffic] 5] 2] / 1024]/KB \[in\] and [expr [lindex [lindex [traffic] 5] 4] / 1024]/KB \[out\]\
        -- \002whitelists:\002 $wcount entries -- \002blacklists:\002 $bcount entries"
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: view
# views a white or blacklist entry
# usage: view ?chan? <dronebl|id> ?<host|ip>?
proc arm:cmd:view {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg    
    variable entries; # -- dict: blacklist and whitelist entries
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "view"
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- command: view
    
    # -- deal with the optional channel argument
    set first [lindex $arg 0];
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        # -- chan (or global) provided
        set chan $first; set ids [lindex $arg 1]
    } else {
        # -- chan not provided
        set ids [lindex $arg 0];
        set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    }
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }    
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    # -- check if ID(s) provided
    if {[regexp -- {^\d+(?:,\d+)*$} $ids] && $ids ne ""} {
        foreach id [split $ids ,] {
            debug 4 "arm:cmd:view: looping -- id: $id"
            
            if {![dict exists $entries $id]} { reply $type $target "\002(\002error\002)\002: no such entry exists (\002id:\002 $id)"; continue; }
            
            set tchan [dict get $entries $id chan]
            set ttype [dict get $entries $id type]
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            
            # -- send response
            reply $type $target [list:return $tchan $ttype $method $value]
        }
        # -- end foreach  
        
    } elseif {$ids eq "dronebl"} {
        # -- DroneBL
        
        # -- check if libdronebl loaded & user has access
        if {[info command ::dronebl::submit] eq "" || [userdb:get:level $user $chan] < [cfg:get dronebl:lvl $chan]} {
            reply $stype $starget "\002usage:\002 view ?chan? <id>"
            return; 
        } else {
            if {$value eq "" || $method eq ""} {
                reply $stype $starget "\002usage:\002 view dronebl <host|ip>"
                return;             
            }
        }

        set loop [split [lindex $arg 1] ,]        
        set ttype [lindex $arg 2]
        # -- allow comma delimited
        foreach ip $loop {
            if {$ip eq "" || (![isValidIP $ip] && {set ip [dns:lookup $ip]} eq "error") || ($method ne "ip" && $method ne "host")} {
                reply $stype $starget "\002usage:\002 view dronebl <host|ip> \[type\]"
                continue;       
            }
            if {$ttype eq "" || ![regexp -- {^\d+$} $ttype]} { set ttype [cfg:get dronebl:type $chan] }
            # -- check if entry even exists
            set result [::dronebl::lookup $ip]  
            debug 2 "arm:cmd:view: dronebl result: $result"
            if {[join [lindex $result 0]] == "No matches."} {
                # -- exists
                debug 1 "arm:cmd:view: dronebl entry does not exist (ip: $ip)"
                reply $type $target "error: dronebl entry does not exist -- ip: $ip"
                continue;
            }
            # -- parse the results
            set i 1
            foreach line $result {
                debug 2 "arm:cmd:view: dronebl line: $line"
                # -- ignore the first (header) line
                if {$i eq 1} { incr i; continue; }
                # {ID IP {Ban type} Listed Timestamp} {305082 173.212.195.50 17 1 {2011.02.15 01:54:17}}
                lassign $line sid sip stype slisted stimestamp
                debug 1 "arm:cmd:view: id: $sid ip: $sip type: $stype listed: $slisted timestamp: $stimestamp"
                reply $type $target "dronebl match (\002id:\002 $sid -- \002ip:\002 $sip -- \002type:\002 $stype -- \002timestamp:\002 $stimestamp)"
                incr i
                #break;
            }
        }
    } else {    
        reply $type $target "\002usage:\002 view ?chan? <id>" 
    }            
    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- command: add
# add a whitelist or blacklist entry
# usage: add ?chan? <white|black> <user|host|rname|regex|text|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? [reason]
proc arm:cmd:add {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable entries;         # -- dict: blacklist and whitelist entries
    variable data:lasthosts;  # -- stores a list of the last N joining a channel, for 'last' blacklist entries (by chan)
    variable data:hostnicks;  # -- stores a list of nicks on a given host (by host)
    variable corowho;         # -- track coroutine to convert =nick to network account
    variable nickdata;

    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "add"
    lassign [db:get id,user users curnick $nick] uid user
    
    # -- deal with the optional channel argument
    set first [lindex $arg 0]; set ischan 0
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        # -- chan (or global) provided
        set ischan 1; set chan $first; set list [lindex $arg 1]; set method [lindex $arg 2]
        set value [lindex [split $arg] 3]; set action [string tolower [lindex $arg 4]]
    } else {
        # -- chan not provided
        set list [lindex $arg 0]; set method [lindex $arg 1]; set value [lindex [split $arg] 2]
        set action [string tolower [lindex $arg 3]]
        set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    }
    set cid [db:get id channels chan $chan]
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    putlog "\002arm:cmd:add: chan: $chan\002"
    
    # -- catch method
    set usage 0;
    set method [string tolower $method]
    switch -- $method {
        regex     { set method "regex"   }
        r         { set method "regex"   }
        user      { set method "user"    }
        u         { set method "user"    }
        xuser     { set method "user"    }
        host      { set method "host"    }
        h         { set method "host"    }
        ip        { set method "host"    }
        net       { set method "host"    }
        mask      { set method "host"    }
        asn       { set method "asn"     }
        a         { set method "asn"     }
        country   { set method "country" }
        geo       { set method "country" }
        g         { set method "country" }
        chan      { set method "chan"    }
        channel   { set method "chan"    }
        c         { set method "chan"    }
        rname     { set method "rname"   }
        realname  { set method "rname"   }
        name      { set method "rname"   }
        ircname   { set method "rname"   }
        n         { set method "rname"   }
        l         { set method "last"    }
        last      { set method "last"    }
        text      { set method "text"    }
        t         { set method "text"    }
        reply     { set method "text"    }
        default   { set usage 1;         }
    }
    
    putlog "\002arm:cmd:add\002: 0a - usage: $usage  -- method: $method"
    
    if     {[string index $list 0] eq "w"} { set list "white"   } \
    elseif {[string index $list 0] eq "b"} { set list "black"   } \
    elseif {[string index $list 0] eq "d"} { set list "dronebl" } \
    elseif {[string index $list 0] eq "i"} { set list "ircbl"   } \
    else   { set usage 1; }
    
    set globlevel [db:get level levels cid 1 uid $uid]
    if {$globlevel eq ""} { set globlevel 0 }
    
    set candronebl 0; set canircbl 0; set xtra1 ""
    if {[info command ::dronebl::submit] ne "" && [userdb:get:level $user $chan] >= [cfg:get dronebl:lvl $chan]} {
        # -- dronebl loaded and user has access
        set candronebl 1; set canrbl 1; append xtra1 "|dronebl"; set xtra2 " \[reason|comment\]"
    } else { set xtra2 " \[reason\]" }
    
    if {[cfg:get ircbl $chan] && $globlevel >= [cfg:get ircbl:lvl $chan]} {
        # --ircbl enabled and user has sufficient access
        set canircrbl 1; set canrbl 1; append xtra1 "|ircbl"; set xtra2 " \[reason|comment\]"
    } else { set xtra2 " \[reason\]" }
    
    set syntax "\002usage:\002 add ?chan? <white|black${xtra1}> <user|host|rname|regex|text|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? $xtra2"
    
    # -- DroneBL / IRCBL
    if {$list eq "dronebl" || $list eq "ircbl"} {
        if {$value eq "" || $method eq ""} {
            if {$canrbl} {
                reply $stype $starget "\002usage:\002 add ?chan? $list <host|ip|last> <value1,value2..> \[comment\]"
                return;  
            } else {
                reply $stype $starget $syntax
                return;
            }
        }
        
        set comment [lrange $arg 3 end]
        
        # -- cater for last N hosts
        if {$method eq "last"} {
            if {![info exists data:lasthosts($chan)]} { reply $type $target "error: no hosts in memory."; return; }
            set method "host"
            set loop [lrange [get:val data:lasthosts $chan] 0 [expr $value - 1]] 
        } else { 
            set loop [split $value ,]
        }
        # -- allow comma delimited
        foreach ip $loop {
            if {$ip eq "" || (![isValidIP $ip] && {set ip [dns:lookup $ip]} eq "error") || ($method ne "ip" && $method ne "host")} {
                reply $stype $starget "\002usage:\002 add $list <host|ip|last> <value1,value2..> \[comment\]"
                continue;       
            }
            
            
            if {$list eq "dronebl"} {
                set ttype [cfg:get dronebl:type $chan]; # -- use entry type from configuration
                # -- check if DroneBL entry exists
                set result [::dronebl::lookup $ip]
                debug 2 "arm:cmd:add: dronebl result: $result"
                if {[join [lindex $result 0]] ne "No matches."} {
                    # -- exists
                    debug 1 "arm:cmd:add: dronebl submit failed (ip exists: $ip)"
                    reply $type $target "error: entry already exists (\002ip:\002 $ip)"
                    continue;
                }
                # -- add the entry
                set result [::dronebl::submit "$ttype $ip"]
                if {$result eq "true"} {
                    debug 1 "arm:cmd:add: dronebl submit successful (ip: $ip)"
                    reply $type $target "dronebl submit successful (\002ip:\002 $ip)"
                    continue;
                } else {
                    debug 1 "arm:cmd:add: dronebl submit failed (ip: $ip response: $result)"
                    reply $type $target "dronebl submit failed (\002ip:\002 $ip)"
                    continue;
                } elseif {$list eq "ircbl"} {
                    # -- check if IRCBL entry exists
                }
            } elseif {$list eq "ircbl"} {
                set ttype [cfg:get ircbl:type $chan]; # -- use entry type from configuration
                set result [lindex [ircbl:query add $ip $ttype $comment] 1]
                reply $type $target $result
                continue;
            }
        }
        # -- endof foreach ip
        # -- create log entry for command use
        log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
        
        return;
    }
    # -- end dronebl add
        
    # -- see if the action is given (incl. shorthand)
    if {$action eq "accept" || $action eq "a"} {
        if {$method eq "text"} { reply $type $target "\002error:\002 action does not apply to text entries."; return; }
        # -- accept the client
        set theaction "A"
        set tn 4
    } elseif {$action eq "voice" || $action eq "v"} {
        if {$method eq "text"} { reply $type $target "\002error:\002 action does not apply to text entries."; return; }
        # -- voice the client
        set theaction "V"
        set tn 4
    } elseif {$action eq "op" || $action eq "o"} {
        if {$method eq "text"} { reply $type $target "\002error:\002 action does not apply to text entries."; return; }
        # -- accept the client
        set theaction "O"
        set tn 4
    } elseif {$action eq "kick" || $action eq "kickban" || $action eq "ban" || $action eq "k" \
        || $action eq "kb" || $action eq "b"} {
        if {$method eq "text" && $list eq "white"} { reply $type $target "\002error:\002 this action does not apply to whitelist text entries."; return; }
        # -- kickban the client
        set theaction "B"
        set tn 4    
    } else { set tn 3 }
        
    # -- detect if limit (joins:secs:hold) is specified as 4th argument
    if {[regexp -- {(\d+):(\d+)(?::(\d+))?} [lindex $arg 4] -> joins secs hold] || [regexp -- {(\d+):(\d+)(?::(\d+))?} [lindex $arg 3] -> joins secs hold]} {
        # -- set the reason position dependant on where the joins:secs:hold is (because 'action' is also optional)
        if {[regexp -- {(\d+):(\d+)(?::(\d+))?} [lindex $arg 4]]} { set tn 5 } else { set tn 4 }
        # -- limit specified
        if {$list eq "white" || ($method ne "host" && $method ne "regex" && $method ne "text")} {
            reply $type $target "\002(\002error\002)\002 joinflood limit settings only relevant for host, regex, and text blacklist types";
            return;
        }
        if {$hold eq ""} { set hold $secs }
        set origlimit "$joins:$secs:$hold"
        if {$secs eq $hold} { set newlimit "$joins:$secs" } else { set newlimit $origlimit }
        set limit "$joins:$secs:$hold"
        set reason [lrange $arg $tn end]
    } else {
        # -- limit not specified
        set limit "1:1:1"
        set reason [lrange $arg $tn end]
    }
    
    # -- strip the action from the reason if found
    set first [lindex $reason 0]
    if {$first eq "kick" || $first eq "kickban" || $first eq "ban" || $first eq "k" \
        || $first eq "kb" || $first eq "b"} {
        set reason [lrange $reason 1 end]
    }

    if {($candronebl || $canircbl) && ($value eq "" || $method eq "")} {
        reply $stype $starget "\002usage:\002 add ?chan? $list <host|ip|last> <value1,value2..> \[comment\]"
        return;  
    } elseif {$value eq "" || $method eq ""} {
        reply $stype $starget $syntax
        return;
    }

    if {$method eq "asn"} {
        if {[string match -nocase "AS*" $value]} { set value [string range $value 2 end]}; # -- strip 'AS' from ASN value
    }
    
    # -- text entries only relevant for blacklists
    # -- allow this and make sure the reply (the 'reason') is spoken back to them before the action is taken :>
    #if {$list eq "white" && $method eq "text"} {
    #    reply $type $target "\002(\002error\002)\002 text type is only relevant for blacklists."
    #    return;
    #}
        
    debug 3 "arm:cmd:add: chan: $chan list: $list method: $method value: $value action: $action limit: $limit reason: $reason"
    
    # -- check if already exists
    set exists 0
    
    # -- we can't loop over multiple entries when type regex, rname, text, or reply
    if {$method eq "regex" || $method eq "text" || $method eq "rname"} {        
        # -- check whether regex is valid
        if {$method eq "regex"} {
            catch { regexp -- $value "nick!user@host/rname" } err
            if {$err ne 0} {
                debug 1 "arm:cmd:add: pattern $value is not a regular expression.";
                reply $type $target "\002error:\002 $err"
                return;
            }    
        }
    }
        
    # -- cater for last N hosts
    set islast 0
    if {$method eq "last"} {
        if {![info exists data:lasthosts($chan)]} { reply $type $target "error: no hosts in memory."; return; }
        set islast 1; set method "host"
        set loop [lrange [get:val data:lasthosts $chan] 0 [expr $value - 1]] 
    } else { 
        # -- allow for comma separated values (if not a regex, text, or rname)
        if {$method ne "regex" && $method ne "rname" && $method ne "text"} { set loop [split $value ,] } else { set loop $value }
    }
     
    foreach tvalue $loop {
        debug 0 "\002arm:cmd:add\002: tvalue: $value -- loop: $loop"
        set exists 0
        if {[regexp -- [cfg:get xregex *] $tvalue -> xuser] && $method eq "host"} {
            set method "user"; set value $xuser
        } else {
            if {$islast} {
                set method "host"
            } else { set method $method }
            set value $tvalue
        }

        # -- allow =nick format to auto translate to network account (xuser)
        if {[string index $value 0] eq "="} {
            set value [string range $value 1 end]
            set lvalue [string tolower $value]
            set method "xuser"
            set dowho 1
            if {[dict exists $nickdata $lvalue account]} {
                set value [dict get $nickdata $lvalue account]
                if {$value eq ""} { set dowho 1 } else { set dowho 0 }
            } 
            if {$dowho eq 1} {
                set corowho($lvalue) [info coroutine]
                putquick "WHO $value n%nuhiartf,104";   # -- send the WHO to lookup account
                set ovalue $value
                set value [yield]
                debug 0 "\002cmd:add:\002 received account value for $value from WHO: $value"
                unset corowho($lvalue)
            }
            if {$value eq 0 || $value eq ""} {
                # -- nick is not network authenticated 
                reply $type $target "\002error:\002 $ovalue is not network authenticated."
                continue; # -- loop to next comma delimited entry
            }
        }

        if {$method eq "country"} { set value [string toupper $value ]}; # -- uppercase country codes for consistency

        # -- determine what list to add 
        if {$list eq "white"} {
            # -- whitelist
            set list "white"; set prefix "W"
            set limit "1:1:1"; # -- we don't care about limits for whitelist entries
            if {$reason eq ""} { set reason [cfg:get def:wreason $chan] }
            # -- accept, voice, op actions
            if {[string index [string toupper $action] 0] eq "A"} { set action "A"; set theaction "accept" } \
            elseif {[string index [string toupper $action] 0] eq "V"} { set action "V"; set theaction "voice" } \
            elseif {[string index [string toupper $action] 0] eq "O"} { set action "O"; set theaction "op" } \
            else {
                # reply $type $target "error: whitelist action must be either: accept, voice or op"
                # return;
                # -- default to 'accept'
                set action "A"; set theaction "accept"
            }
        
        } elseif {$list eq "black"} {
            # -- blacklist
            set list "black"; set prefix "B"
            if {$reason eq ""} { set reason [cfg:get def:breason $chan] }; # -- default reason
            # -- deny, voice, op actions
            if {[string index [string toupper $action] 0] eq "B"} { set action "B"; set theaction "kickban" } \
            else {
                # reply $type $target "error: blacklist action must only be ban."
                # return;
                # -- default to ban
                set action "B"; set theaction "kickban"
            }
        } else {
            # -- unknown
            if {($candronebl || $canircbl) && ($value eq "" || $method eq "")} {
                reply $stype $starget "\002usage:\002 add ?chan? $list <host|ip|last> <value1,value2..> \[comment\]"
                return;  
            } elseif {$value eq "" || $method eq ""} {
                reply $stype $starget $syntax
                return;
            }
            continue;
        }
        
        # -- check to see if there is an identical entry that already exists
        set id [lindex [dict filter $entries script {id dictData} {
            expr {[dict get $dictData chan] eq $chan && [dict get $dictData type] eq $list \
                && [dict get $dictData method] eq $method && [dict get $dictData value] eq $value}
        }] 0]
        if {$id ne ""} {
            set flags 0; # -- new entries don't have flags
            set iaction [dict get $entries $id action]
            set ilimit [dict get $entries $id limit]
            set iflags [dict get $entries $id flags]
            
            putlog "\002cmd:add:\002 iaction: $iaction (action: $action) -- ilimit: $ilimit (limit: $limit) -- iflags: $iflags (flags: $flags)"
            
            if {$action eq $iaction && $limit eq $ilimit && $flags eq $iflags} {
                reply $type $target "\002error:\002 a matching ${list}list entry with identical behaviour already exists. (\002id:\002 $id -- \002type:\002 $method -- \002value:\002 $value)";
                return;        
            }
        }
        
        # -- check if the opposite type exists (and prevent if so)
        #if {$list eq "black"} { set opp "white" } else { set opp "black" }
        # -- there can only be one unique combination of this expression
        #set id2 [lindex [dict filter $entries script {id dictData} {
        #    expr {[dict get $dictData chan] eq $chan && [dict get $dictData type] eq $opp \
        #        && [dict get $dictData method] eq $method && [dict get $dictData value] eq $value}
        #}] 0]
        #if {$id2 ne ""} {
            #set oaction [dict get $entries $id2 action]
            #set olimit [dict get $entries $id2 limit]
            #set oflags [dict get $entries $id2 flags]
            #if {$action eq $oaction && $limit eq $olimit && $flags eq $oflags} {
            #    # -- we should allow opposite entries
            #    #reply $type $target "error: an opposite matching ${opp}list entry with common behaviour already exists. (\002id:\002 $id2 -- \002type:\002 $method -- \002value:\002 $value)";
            #    #continue;
            #}
        #}
        
        # -- convert host to IP (only if it's a hostname)
        # -- TODO: IPv6 support; config option to determine if we do this step?
        if {$method eq "host"} {
            if {[regexp -- {^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$} $value]} {
                # -- host or IP
                if {![regexp -- {^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$} $value]} {
                    # -- hostname
                    set ip [lindex [dns:lookup $value] 0]
                    if {$ip eq "NULL" || $ip eq ""} { set value $value } else { set value $ip }
                }
            }
        }

        set timestamp [unixtime]; set modifby $source
    
        debug 1 "arm:cmd:add: adding entry: chan: $chan -- type: $prefix -- method: $method -- value: $value -- modifby: $modifby -- action: $action -- reason: [join $reason]"

        # -- add the list entry
        set id [db:add $prefix $chan $method $value $modifby $action $limit $reason]
    
        if {$limit ne "1:1:1" && $limit ne ""} { set textlimit " -- \002limit:\002 $newlimit "  } else { set textlimit " " }
        
        # -- change response if method is text
        if {$method eq "text"} {
            if {$list eq "black"} {
                reply $type $target "added $method ${list}list entry (\002id:\002 $id -- \002value:\002 $value -- \002action:\002 ${theaction}${textlimit}-- \002reply:\002 [join $reason])"
            } else {
                reply $type $target "added $method ${list}list entry (\002id:\002 $id -- \002value:\002 $value -- \002reply:\002 [join $reason])"
            }
        } else {
            reply $type $target "added $method ${list}list entry (\002id:\002 $id -- \002value:\002 $value -- \002action:\002 ${theaction}${textlimit}-- \002reason:\002 [join $reason])"
        }
        
        # -- add automatic bans?
        if {$theaction eq "kickban" && [cfg:get ban:auto $chan]} {
            set hit 0
            set addban 0
            if {$method eq "user"} { set mask "*!*@$tvalue.[cfg:get xhost:ext *]"; set addban 1 }
            if {$method eq "host"} {
                if {[regexp -- {\*} $tvalue]} { set mask $tvalue } else { set mask "*!*@$tvalue" }
                set addban 1
            }
            if {$addban} {
                set lchan [string tolower $chan]
                if {[info exists data:hostnicks($tvalue,$lchan)]} {
                    foreach i [get:val data:hostnicks $tvalue,$lchan] {
                        incr hit
                        lassign [split [getchanhost $i] @] ident host
                        kickban $i $ident $host $chan [cfg:get ban:time $chan] "Armour: blacklisted -- $value (reason: [join $reason]) \[id: $id\]" $id
                    }
                }
                if {!$hit} {
                    # -- no nicknames on that host found, just do a generic ban
                    # -- use of 0 for nick means ident is banmask :>
                    kickban 0 $mask 0 $chan [cfg:get ban:time $chan] "Armour: blacklisted -- $value (reason: [join $reason]) \[id: $id\]" $id
                }
            }
        }
    
    }
    # -- end of loop
    
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
    return;
}

# -- command: rem
# remove a whitelist or blacklist entry
proc arm:cmd:rem {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    variable entries;     # -- dict: blacklist and whitelist entries
    variable data:idban;  # -- tracks the most recently banned ban for a given entry ID (chan,id)
    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "rem"
    lassign [db:get id,user users curnick $nick] uid user

    # -- deal with the optional channel argument
    set first [lindex $arg 0]; set ischan 0
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        # -- chan (or global) provided
        set ischan 1; set chan $first; set ids [lindex $arg 1]; set method [lindex $arg 2];
        set value [lindex $arg 3]; set ttype [lindex $arg 4]
    } else {
        # -- chan not provided
        set ids [lindex $arg 0]; set method [lindex $arg 1]; set value [lindex $arg 2]; set ttype [lindex $arg 3]
        set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    }
    set cid [db:get id channels chan $chan]
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    set globlevel [db:get level levels cid 1 uid $uid]
    if {$globlevel eq ""} { set globlevel 0 }
    
    putlog "\002arm:cmd:rem:\002 ids: $ids method: $method value: $value ttype: $ttype"
    
    # -- check if ID is given
    if {[regexp -- {^\d+(?:,\d+)*$} $ids]} {
        # -- ID(s) provided
        foreach id [split $ids ,] {
        
            set isexist [dict exists $entries $id]
            if {$isexist eq 0} { reply $type $target "\002(\002error\002)\002: no such entry exists (\002id:\002 $id)"; continue; }

            set ltype [dict get $entries $id type]
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            set limit [dict get $entries $id limit]
            set action [dict get $entries $id action]
            set hitnum [dict get $entries $id hits]             
            set reason [dict get $entries $id reason]
            set action [list:action $id]; # -- convert to action string
                        
            debug 3 "arm:cmd:rem: interpret entry: chan: $chan -- type: $ltype -- method: $method -- value: $value"
        
            if {$ltype eq "white"} { set list "whitelist" } else { set list "blacklist" }

            db:rem $id; # -- remove the entry

            # -- try to remove any existing blacklist ban?
            if {$ltype eq "white"} {
                set mask ""; set bantype ""
                if {[info exists data:idban($chan,$id)]} {
                    set bantype " host"
                    set mask $idban($chan,$id); # -- banmask of user last banned with this ID
                } elseif {$method eq "host"} {
                    set bantype " host"
                    if {[regexp -- {\*} $value]} { set mask $value } else { set mask "*!*@$value" }
                } elseif {$method eq "user" || $method eq "xuser"} {
                    set bantype " user"
                    set mask "*!*@$value.[cfg:get xhost:ext *]"
                } 
                
                if {$mask ne ""} {
                    # -- attempt the unban
                    debug 2 "arm:cmd:rem: attempting to remove an assocated${bantype} ban"
                    if {[cfg:get ban $chan] eq "chan"} {
                        # -- channel unban
                        putquick "MODE $chan -b $mask"
                    } elseif {[cfg:get ban $chan] eq "x"} {
                        # -- set service unban
                        putquick "PRIVMSG [cfg:get auth:serv:nick *] :unban $chan $mask"
                    }
                }
            }
    
            debug 1 "arm:cmd:rem: removed $list $method entry: $value -- action: $action -- reason: $reason"
            
            if {$method eq "text"} {
                if {$list eq "black"} {
                    reply $type $target "removed $method $list entry (\002id:\002 $id -- \002value:\002 $value \
                    -- \002action:\002 $action -- \002limit:\002 $limit -- \002hits:\002 $hitnum -- \002reply:\002 $reason)"
                } else {
                    reply $type $target "removed $method $list entry (\002id:\002 $id -- \002value:\002 $value \
                    -- \002action:\002 $action -- \002hits:\002 $hitnum -- \002reply:\002 $reason)"
                }
            } else {
                if {$limit ne "1:1:1" && $limit ne ""} {
                    reply $type $target "removed $method $list entry (\002id:\002 $id -- \002value:\002 $value \
                    -- \002action:\002 $action -- \002limit:\002 $limit -- \002hits:\002 $hitnum -- \002reason:\002 $reason)"
                } else {
                    reply $type $target "removed $method $list entry (\002id:\002 $id -- \002value:\002 $value \
                    -- \002action:\002 $action -- \002hits:\002 $hitnum -- \002reason:\002 $reason)"
                }
            }

        }
        # -- end of foreach
                
    } elseif {$ids eq "dronebl" || $ids eq "ircbl"} {
        set nodronebl 0; set noircbl 0;
        if {[info command ::dronebl::submit] eq "" || [userdb:get:level $user $chan] < [cfg:get dronebl:lvl $chan]} {
            # -- DroneBL not loaded, or no access
            set norbl 1
        } else { append xtra "|dronebl" }
        
        if {![cfg:get ircbl $chan] || $globlevel < [cfg:get ircbl:lvl $chan]} {
            # -- IRCBL not enabled, or not access
            set noircbl 1        
        } else { append xtra "ircbl" }
        
        if {$nodronebl && $noircbl} {
            reply $stype $starget "\002usage:\002 rem ?chan? <id>"
            return;
        }
        
        if {$value eq ""} {
            putlog "\002arm:cmd:rem\002: no value"
            reply $stype $starget "\002usage:\002 rem $ids <host|ip|las$xtra> <value1,value2..> \[type\]"
            return;             
        }
                
        # -- cater for last N hosts
        if {$method eq "last"} {
            if {![info exists data:lasthosts($chan)]} { reply $type $target "error: no hosts in memory."; return; }
            set method "host"
            set loop [lrange [get:val data:lasthosts $chan] 0 [expr $value - 1]] 
        } else { 
            set loop [split $value ,]
        }
        
        # -- allow comma delimited
        foreach ip $loop {
            if {$ip eq "" || (![isValidIP $ip] && {set ip [dns:lookup $ip]} eq "error") || ($method ne "ip" && $method ne "host")} {
                reply $stype $starget "\002usage:\002 rem $ids <value1,value2..> \[type\]"
                continue;       
            }
            if {$ttype eq "" || ![regexp -- {^\d+$} $ttype]} {
                if {$ids eq "dronebl"} { set ttype [cfg:get dronebl:type $chan] } \
                elseif {$ids eq "ircbl"} { set ttype [cfg:get ircbl:type $chan] }
            }

            if {$ids eq "dronebl"} {
                # -- check if entry exists
                set result [::dronebl::lookup $ip]  
                if {[join [lindex $result 0]] eq "No matches."} {
                    # -- exists
                    debug 1 "arm:cmd:rem: dronebl removal failed (no match: $ip)"
                    reply $type $target "error: entry does not exist (\002ip:\002 $ip)"
                    continue;
                }
                # -- parse the results (most useful with the view command)
                set i 1
                foreach line $result {
                    debug 2 "arm:cmd:rem: dronebl line: $line"
                    # -- ignore the first (header) line
                    if {$i eq 1} { incr i; continue; }
                    # {ID IP {Ban type} Listed Timestamp} {305082 173.212.195.50 17 1 {2011.02.15 01:54:17}}
                    lassign $line sid sip stype slisted stimestamp
                    debug 1 "arm:cmd:rem: id: $sid ip: $sip type: $stype listed: $slisted timestamp: $stimestamp"
                    incr i
                    break;
                }
                # -- remove the entry
                set result [::dronebl::remove $sid]
                if {$result eq "true"} {
                    debug 1 "arm:cmd:rem: dronebl removal successful (ip: $ip)"
                    reply $type $target "dronebl removal successful (\002ip:\002 $ip)"
                    continue;
                } else {
                    debug 1 "arm:cmd:rem: dronebl removal failed (ip: $ip -- response: $result)"
                    reply $type $target "dronebl removal failed (\002ip:\002 $ip)"
                    continue;
                }
            } elseif {$ids eq "ircbl"} {
                set result [lindex [ircbl:query del $ip $ttype] 1]
                reply $type $target $result
                continue;
            }
        }
        # -- endof foreach ip
    } else {
        set canrbl 0; set xtra ""
        if {[info command ::dronebl::submit] ne "" && [userdb:get:level $user $chan] >= [cfg:get dronebl:lvl $chan]} {
            # -- dronebl loaded and user has access
            append xtra "|dronebl"; set canrbl 1;
        }
        
        if {[cfg:get ircbl $chan] && $globlevel >= [cfg:get ircbl:lvl $chan]} {
            # --ircbl enabled and user has sufficient access
            append xtra "|ircbl"; set canrbl 1;
        }
        
        if {!$canrbl} {
            reply $stype $starget "\002usage:\002 rem ?chan? <id>"
        } else {
            reply $stype $starget "\002usage:\002 rem ?chan? <id$xtra> ?<value1,value2..>? \[type\]"
        }
    }
    
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
    return;
}

# -- command: mod
# modify a whitelist or blacklist entry
proc arm:cmd:mod {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    variable entries;  # -- dict: blacklist and whitelist entries    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "mod"
    lassign [db:get id,user users curnick $nick] uid user

    # -- deal with the optional channel argument
    set first [lindex $arg 0]; set ischan 0; set idgiven 0
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        # -- chan (or global) provided
        set ischan 1; lassign $arg chan ids param; set setval [lrange $arg 3 end]
    } else {
        # -- chan not provided
        lassign $arg ids param; set setval [lrange $arg 2 end]
        set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    }
    set cid [db:get id channels chan $chan]
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    set globlevel [db:get level levels cid 1 uid $uid]
    if {$globlevel eq ""} { set globlevel 0 }
    
    if {[cfg:get ircbl $chan] && $globlevel >= [cfg:get ircbl:lvl $chan]} { set xtra "|ircbl" } else { set xtra "" }; # -- IRCBL syntax

    set usage 0;
    if {$ids eq "" || $param eq "" || $setval eq ""} { set usage 1 }; # -- show command usage
    if {$param eq "depends" && $setval eq ""} { set usage 0; };       # -- allow null value to clear dependencies

    if {![cfg:get ircbl $chan] && $param eq "ircbl"} { set usage 1 }; # -- IRCBL not enabled; show command usage
    
    if {$usage} {
        reply $stype $starget "\002usage:\002 mod ?chan? <id> <value|action|limit|depends|reason|nochans|onlykick|noident|manual|captcha|disabled|onlysecure|notsecure|silent${xtra}> <value>"
        return;    
    }
        
    putlog "\002cmd:mod:\002 chan: $chan -- ids: $ids -- param: $param -- setval: $setval"
    
    # -- loop over any entries
    foreach id [split $ids ,] {

        #set x [dict keys [dict filter $entries script {id dictData} { expr {[dict get $dictData id] eq $id} } ]]
        set did [lindex [dict filter $entries script {did dictData} { expr {[dict get $dictData id] eq $id}}] 0]
        if {$did eq ""} { reply $type $target "\002(\002error\002)\002: no such entry exists (\002id:\002 $id)"; continue; }

        set cid [dict get $entries $id cid]
        set ltype [dict get $entries $id type]
        set method [dict get $entries $id method]
        set value [dict get $entries $id value]
        set flags [dict get $entries $id flags]
        set limit [dict get $entries $id limit]
        set action [dict get $entries $id action]
        set hitnum [dict get $entries $id hits]
        set depends [dict get $entries $id depends] 
        set reason [dict get $entries $id reason]
        set action [list:action $id]; # -- convert to action string
        set reason [dict get $entries $id depends]
                    
        if {$ltype eq "white"} { set list "whitelist" } else { set list "blacklist" }
        
        putlog "\002cmd:mod:\002 chan: $chan -- id: $id -- list: $ltype -- method: $method -- value: $value -- param: $param -- setval: $setval"

        set isflag 0

        switch -- $param {
            action     { set param "action" }
            limit      { set param "limit"  }
            reason     { set param "reason" }
            value      { set param "value" }
            depends    { set param "depends" }
            nochans    { set param "nochans"; set isflag 1    }
            nochan     { set param "nochans"; set isflag 1    }
            onlykick   { set param "onlykick"; set isflag 1   }
            kickonly   { set param "onlykick"; set isflag 1   }
            noban      { set param "onlykick"; set isflag 1   }
            noident    { set param "noident"; set isflag 1    }
            manual     { set param "manual"; set isflag 1     }
            captcha    { set param "captcha"; set isflag 1    }
            disable    { set param "disabled"; set isflag 1   }
            disabled   { set param "disabled"; set isflag 1   }
            onlysecure { set param "onlysecure"; set isflag 1 }
            secureonly { set param "onlysecure"; set isflag 1 }
            notsecure  { set param "notsecure"; set isflag 1  }
            silent     { set param "silent"; set isflag 1 }
            ircbl      { set param "ircbl"; set isflag 1 }
            rbl        { set param "ircbl"; set isflag 1 }
            default {
                reply $type $target "\002(\002error\002)\002 entry parameter must be one of: value|action|limit|depends|reason,\
                 nochans|onlykick|noident|manual|captcha|disabled|onlysecure|notsecure|silent${xtra}|ctcp.  try: \002help mod\002"
                return;
            }
        }
        
        putlog "\002cmd:mod:\002 id: $id -- param: $param isflag: $isflag"
        
        # -- list entry dependencies
        # -- allow null value to reset dependencies
        if {$param eq "depends" && $setval ne ""} {
            set setval [split $setval " "]
            set setval [split $setval ,]
            foreach val $setval {
                #if {$val in $depends} {
                #    reply $type $target "\002(\002error\002)\002 ${ltype}list entry $id is already dependent on \002id:\002 $val.";
                #    return;
                #}
                if {$val eq $id} {
                    reply $type $target "\002(\002error\002)\002 ${ltype}list entries cannot be dependent on themselves.";
                    return;
                }
                if {![regexp -- {^\d+$} $val] || [dict exists $entries $val] eq 0} {
                    reply $type $target "\002(\002error\002)\002 ID $setval is not a valid white or blacklist entry ID.";
                    return;
                }
                if {$ltype ne [dict get $entries $val type]} {
                    reply $type $target "\002(\002error\002)\002 dependent entries must be of the same type (\002id:\002 $id is a ${ltype}list).";
                    return;              
                }
            }
         }

        if {$param eq "nochans"} {
            # -- TODO: add nochans flag support
            reply $type $target "\002(\002error\002)\002 \002nochans\002 flag not yet implemented.";
            return;
        }
        
        if {$param eq "ctcp"} {
            # -- TODO: add ctcp support
            reply $type $target "\002(\002error\002)\002 \002ctcp\002 flag not yet implemented.";
            return;
        }

        if {$param eq "ircbl"} {
            # -- IRCBL additions require special global level
            if {$globlevel < [cfg:get ircbl:lvl $chan]} {
                reply $type $target "\002(\002error\002)\002 \002ircbl\002 flag access denied.";
                return;
            }
        }

        if {$isflag} {
            # -- entry flag
            set lsetval [string tolower $setval]
            if {$lsetval ne "on" && $lsetval ne "off"} {
                reply $type $target "\002(\002error\002)\002 parameter value must be \002on\002 or \002off\002."
                return;
            }
            
            set exist [dict get $entries $id $param]
            if {($exist eq 1 && $lsetval eq "on") || ($exist eq 0 && $lsetval eq "off")} {
                reply $type $target "\002(\002error\002)\002 $param is already \002$setval\002."
                return;
            }
            
            set iflag [getFlag $param]
            if {$lsetval eq "on"} {
                set newflags [expr $flags + $iflag];
                set db_setval $newflags
                set dictval 1; set col "flags"; putlog "\002cmd:mod:\002 setting on -- newflags: $newflags"
            } else {
                set newflags [expr $flags - $iflag];
                set db_setval $newflags;
                set dictval 0; set col "flags"; putlog "\002cmd:mod:\002 setting off -- newflags: $newflags"
            }
            
            dict set entries $id $param $dictval
            
        } else {
            # -- not a flag (standard entry field)
            if {$param eq "action"} {
                if {$method eq "text"} { reply $type $target "\002error:\002 action does not apply to reply entries."; return; }
            }
            set db_setval [db:escape $setval]
            set dictval $setval; set col $param;
            dict set entries $id $col $db_setval
        }

        if {$col eq "limit"} { set col "\"limit\"" }; # -- safety net for special column name

        db:connect
        db:query "UPDATE entries SET $col='$db_setval' WHERE id=$id AND cid=$cid"
        db:close

        if {$param eq "depends"} {
            set setval [join $setval ,]
            if {$setval eq ""} { set setval "null" }
        }
        debug 1 "arm:cmd:mod: modified $list $method entry: $value (chan: $chan -- id: $id -- param: $setval)"
        reply $type $target "modified $method $list entry (\002chan:\002 $chan -- \002id:\002 $id -- \002value:\002 $value -- \002$param:\002 $setval)"
    }
    # -- end of foreach
    
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log "$nick!$uh" "" "" ""
    return;
}


# -- retrieve log file contents
proc arm:cmd:showlog {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "showlog"

    # -- ensure user has required access for command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template
    
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- TODO: make channel specific
    
    if {$arg eq ""} { reply $type $target "usage: showlog ?chan? \[-cmd <cmd>\] \[-days n\] \[-user <user>\] \[-max n\] \[-last n\]"; return; }
    
    set flag_cmd false; set flag_days false; set flag_user false; set flag_max false;
    set usage false; set where false;
    set query "SELECT timestamp, user, user_id, command, params, bywho, target, target_xuser, wait FROM cmdlog"
    if {[string index [lindex $arg 0] 0] eq "#"} {
        set text [string tolower [lrange $arg 1 end]]
        set chan [lindex $arg 0]
        set cid [db:get id channels chan $chan]
        set db_chan [db:escape [string tolower $chan]]
        append query " WHERE lower(chan)='$db_chan'"
    } else {
        if {[lindex $arg 0] eq "*"} {
            set text [string tolower [lrange $arg 1 end]]
            set chan "*"; set cid 1;
        } else { 
            set text [string tolower $arg]
            set chan "*"; set cid 1;
        }
    }
    set text [string tolower $arg]
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    set c 0; set max 5 
    foreach i $text {
        if {$i eq "-cmd"} {
            set cmd [lindex $text [expr $c + 1]]
            if {[string index $cmd 0] eq "-"} { set usage true; } else { set flag_cmd true; }
        
        } elseif {$i eq "-days"} {
            set days [lindex $text [expr $c + 1]]
            if {[string index $cmd 0] eq "-" || ![string is digit $days]} { set usage true; } else { set flag_days true; }
        
        } elseif {$i eq "-user"} {
            set tuser [lindex $text [expr $c + 1]]
            if {[string index $cmd 0] eq "-"} { set usage true; } else { set flag_user true; }
            if {![userdb:isValiduser $tuser]} { reply $type $target "invalid user."; return; }
        } elseif {$i eq "-max" || $i eq "-last"} {
            set max [lindex $text [expr $c + 1]]
            if {[string index $cmd 0] eq "-" || ![string is digit $max]} { set usage true; } else { set flag_max true; }
            if {$max > 20} { reply $type $target "maximum of 20 results."; return; }
        }
        incr c
    }
    if {$usage} { reply $type $target "usage: showlog \[-cmd <cmd>\] \[-days n\] \[-user <user>\] \[-max n\] \[-last n\]"; return; }
    
    db:connect
    
    # -- specific command search
    if {$flag_cmd} {
        set db_cmd [string toupper [db:escape $cmd]]
        append query " WHERE command='$db_cmd'"
        set where true
    }
    # -- event in last N days
    if {$flag_days} {
        if {$where} {
            append query " AND timestamp>'[expr [clock seconds] - (8600*$days)]'"
        } else {
            append query " WHERE timestamp>'[expr [clock seconds] - (8600*$days)]'"
        }
    }
    # -- specific user initiated command
    if {$flag_user} {
        set db_user [string tolower [db:escape $tuser]]
        if {$where} {
            append query " AND lower(user)='$db_user'"
        } else {
            append query " WHERE lower(user)='$db_user'"
        }
    }
    
    # -- sort by recent events
    append query " ORDER BY timestamp DESC"
    
    set result [db:query $query]
    set count 0
    foreach row $result {
        lassign $row timestamp tuser tuser_id command params bywho ttarget ttarget_xuser wait
        if {$row eq ""} { reply $type $target "0 results found."; return; }
        incr count
        if {$params != ""} {
            reply $type $target "\002\[\002[clock format $timestamp -format "%H:%M %d/%m/%y"]\002\]\002 \002user:\002 $tuser (\002id:\002 $tuser_id) -- \002cmd:\002 $command $params -- \002bywho:\002 $bywho"
        } else {
            reply $type $target "\002\[\002[clock format $timestamp -format "%H:%M %d/%m/%y"]\002\]\002 \002user:\002 $tuser (\002id:\002 $tuser_id) -- \002cmd:\002 $command -- \002bywho:\002 $bywho"
        }
        if {$count eq $max} { break; }
    }
    
    set total [llength $result]
    if {$total > $max} {
     reply $type $target "done. $total results found. please refine your search. "; 
    } else {
        if {$total eq 1} { set res "result" } else { set res "results" }
        reply $type $target "done. $total $res found."
    }
    
    # -- create log entry for SHOWLOG command use    
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] $log $source "" "" ""
}

# -- cmd: note
# -- send notes between users
proc arm:cmd:note {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg;
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "note"
    if {![cfg:get note $chan]} { reply $type $target "notes disabled by administrator."; return; }; # -- exit if notes not enabled
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    set level [db:get level levels uid $uid cid=1]; # -- get global access
    
    # -- end default proc template
    set text $arg
    if {[lindex $text 0] eq ""} {
        if {$level >= [cfg:get note:glob $chan]} {
            # -- user can send notes to all users (global send)
            reply $stype $starget "\002usage:\002 note <send|view|rem> <user|id|*> \[note\]";
        } else {
            reply $stype $starget "\002usage:\002 note <send|view|rem> <user|id> \[note|-all\]";
        }
        return 0
    }
    set action [string tolower [lindex $text 0]]
    if {$action eq "send"} {
        set who [lindex $text 1]
        set note [lrange $text 2 end]
        if {$who eq "" || $note eq ""} {
            if {$level >= [cfg:get note:glob $chan]} {
                # -- user can send notes to all users (global send)
                reply $stype $starget "\002usage:\002 note send <user|*> \[note\]";
            } else {
                reply $stype $starget "\002usage:\002 note send <user> \[note\]";
            }
            return 0
        }
        set all false
        if {$who eq "*"} {
            if {$level < [cfg:get note:glob $chan]} {
                # -- not allowed to send global notes
                reply $type $target "access denied. cannot send global notes.";
                return;
            } else { set all true }
        }
        if {!$all} {
            set to [userdb:user:get user user $who silent]
            if {$to eq ""} { reply $type $target "no such user."; return; }
            set to_id [userdb:user:get id user $to silent]
            set towho $to
        } else {
            # -- global
            db:connect
            set rows [db:query "SELECT user FROM users WHERE user!='$user'"]; # -- not ourselves
            set towho [list]
            foreach usr $rows {
                lappend towho $usr
            }
            db:close
        }
        set from $user
        set from_id $uid
        set db_note [db:escape $note]
        set count 0; set notify 0
        debug 3 "arm:cmd:note: sending note: from: $from -- from_id: $from_id -- towho: $towho -- db:note: $db_note"
        foreach who $towho {
            set to $who
            incr count
            set to_id [userdb:user:get id user $who silent]
            # -- notify the recipient if online
            set read "N"
            set to_nick [join [join [db:get curnick users user $to]]]
            set online 0;
            if {$to_nick ne ""} {
                # -- recipient is online
                incr notify; set online 1
                # -- insert note as read if they're already online and get the /notice
                set read "Y"
            }
            # -- insert the note -> db
            db:connect
            db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, read, note) \
                VALUES ('[clock seconds]', '$from', '$from_id', '$to', '$to_id', '$read', '$db_note')"
            set rowid [db:last:rowid]
            if {$online} { putquick "NOTICE $to_nick :(\002note\002 from $from -- \002id:\002 $rowid): $note" }
        }
        if {$notify eq 1} { set nres "user" } else { set nres "users" }
        if {$count eq 1} { set cres "user" } else { set cres "users" }
        if {$all} {
            reply $type $target "done. (sent to $count $cres, notified $notify online $nres.)"
        } else {
            if {$notify == 1} {
                reply $type $target "done. notified user online. (\002id:\002 $rowid)"
            } else {
                reply $type $target "done. (\002id:\002 $rowid)"
            }
        }
        db:close
    
    } elseif {$action eq "view" || $action eq "read" || $action eq "check"} {
        set id [lindex $text 1]
        set flag_all [lindex $text 2]
        if {[string tolower $flag_all] eq "-all"} { set flag_all true; } else { set flag_all false }
        # -- allow to loop through all unread
        set all false; set onlyunread true;
        if {$id eq ""} { set all true; set onlyunread true; }
        if {$id eq "*"} { set all true; set onlyunread false; }
        db:connect
        if {$all} {
            # -- read all unread notes
            set result [db:query "SELECT id, timestamp, from_u, from_id, to_u, to_id, note, read \
                FROM notes WHERE from_u='$user' OR to_u='$user' \
                ORDER BY id DESC"]
        } else {
            # -- individual note view
            if {![string is digit $id]} {
                reply $type $target "uhh... try using a number.";
                db:close
                return 0
            }
            set onlyunread false;
            set result [join [list [db:query "SELECT id, timestamp, from_u, from_id, to_u, to_id, note, read \
                FROM notes WHERE id='$id' AND (from_u='$user' OR to_u='$user') \
                ORDER BY id DESC"]]]
        }
        db:close
        set tcount 0
        
        # onlyunread: false -- all: true -- flag_all: false            
        foreach row $result {
            debug 0 "\002arm:cmd:note:\002 row: $row"
            # -- either invalid note id or note not related to user
            if {$row eq ""} {
                if {$all && $onlyunread} { reply $type $target "no unread notes." } \
                elseif {$all && !$onlyunread} { reply $type $target "inbox empty." } \
                else { reply $type $target "no such note exists." }
                return;
            }
            lassign $row id timestamp from from_id to to_id note read
            debug 3 "arm:cmd:note: id: $id -- timestamp: $timestamp -- from: $from -- from_id: $from_id -- to: $to -- to_id: $to_id -- note: $note -- read: $read"
            # -- inbox or outbox? (messages to me always appear in inbox only, even if sent by me to myself)
            if {$user eq $to} { set box "\[\002 inbox\002\]" } \
            elseif {$from eq $user} {
                # -- outbox. skip if not showing all messages, or not showing specific ID
                if {!$flag_all || ![string is digit [lindex $text 1]]} { continue; }
                set box "\[\002outbox\002\]"
            } else { set box "\[\002 inbox\002\]" }
            
            # -- read or unread message?
            if {$read eq "Y"} {
                # -- if showing all notes, only show unread ones
                if {($onlyunread || ![string is digit [lindex $text 1]]) && !$flag_all} { continue; }
                incr tcount
                set r "(  read - \002id:\002 $id): "
            } else {
                incr tcount
                # -- currently unread, mark it read
                set r "(unread - \002id:\002 $id): "
                db:connect
                db:query "UPDATE notes SET read='Y' WHERE id='$id'"
                db:close
                # -- read receipts? only do receipt if the recipient isn't the 'view' user
                # (if we send ourselves a note, we don't need a read receipt)
                if {[cfg:get note:receipt $chan] && $to ne $user} {
                    # -- notify the recipient if online
                    set from_nick [userdb:user:get nick user $from silent]
                    if {$from_nick ne ""} {
                        # -- recipient is online
                        putquick "NOTICE $from_nick :(note read receipt): user $to read note (\002id:\002 $id -- \002note:\002 $note)"
                    } else {
                        # -- recipient is offline, send a note instead
                        db:connect
                        set receipt "user $to read note $id (\002note:\002 $note)"
                        set db_receipt [db:escape $receipt]
                        db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, note) \
                            VALUES ('[clock seconds]', '$to', '$to_id', '$from', '$from_id', '$db_receipt')"
                        db:close
                    }
                }
                # -- end read receipt
            }
            debug 3 "arm:cmd:note: $box $r \[[clock format $timestamp -format "%H:%M %d/%m/%y"]\] from: $from -- to: $to -- note: $note"
            reply $type $target "$box $r \[\002[clock format $timestamp -format "%H:%M %d/%m/%y"]\002\] \002from:\002 $from -- \002to:\002 $to -- \002note:\002 $note"
            if {$tcount eq 5} { break; }
        }
        # -- end of foreach
        if {$tcount eq 0} {
            if {$all && $onlyunread} { reply $type $target "no unread notes." } \
            elseif {$all && !$onlyunread} { reply $type $target "inbox empty." } \
            else { reply $type $target "no such note exists." }
        } else {
            set len [llength $result]
            if {$tcount eq 1} { set res "note" } else { set res "notes" }
            if {$len <= 5} { reply $type $target "done. $len $res found."; }
            if {$len > 5} { reply $type $target "done. [llength $result] notes found. delete notes to view more."; }
        }
            
    } elseif {$action eq "rem" || $action == "del"} {
        set id [lindex $text 1]        
        db:connect
        set query "DELETE FROM notes WHERE to_u='$user'"
        if {[string is digit $id]} {
            set db_id [lindex [db:query "SELECT id FROM notes WHERE to_u='$user' AND id='$id'"] 0]
            if {$db_id eq ""} { reply $type $target "no such note exists." ; return; }
            append query " AND id=$id"
        } elseif {$id eq "*"} {
            # -- delete all
        } else {
            reply $type $target "usage: note rem <id|*>"
            return;
        }

        # -- only delete from your own inbox
        # -- should we allow to delete from outbox? what if the sent item is not yet read?
        db:query $query
        db:close
        reply $type $target "done."
    }
    # -- create log entry for NOTE command use
    log:cmdlog BOT * 1 $user uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: queue
# usage: queue ?chan?
# checks the wait list when in secure mode
proc arm:cmd:queue {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable scan:list;  # -- the list of nicknames to scan in secure mode:
                         #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                         #        nicks,*    :  the nicks being scanned
                         #        who,*      :  the current wholist being constructed
                         #        leave,*    :  those already scanned and left
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "queue"
    lassign [db:get id,user users curnick $nick] uid user
    
    set chan [lindex $arg 0]; 
    if {$chan eq ""} { set chan [userdb:get:chan $user $chan] }; # -- predict chan when not given
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    set lchan [string tolower $chan]
    # -- command: queue    
    
    if {$chan eq "*"} { set chanlist [channels] } else { set chanlist $chan }    
    
    # -- all chans
    set hcount 0; set ncount 0; set count 0
    foreach tchan $chanlist {
        set ltchan [string tolower $tchan]
        set cid [db:get id channels chan $tchan]
        if {$cid eq ""} { continue; }
        if {![userdb:isAllowed $nick $cmd $tchan $type]} { continue; }
        if {[get:val chan:mode $tchan] != "secure"} { continue; }; # -- only return for secure mode chans
        incr count
        if {[info exists scan:list(leave,$ltchan)]} { set hcount [llength [get:val scan:list leave,$ltchan]] }
        if {[info exists scan:list(nicks,$ltchan)]} { set ncount [llength [get:val scan:list nicks,$ltchan]] }
        if {$hcount eq 0} { set hidden "hidden users" } else { set hidden "hidden users ([get:val scan:list leave,$ltchan])." }
        if {$ncount eq 0} { set leave "users being scanned" } else { set leave "users being scanned ([get:val scan:list nicks,$ltchan])." }
        reply $type $target "\002\[$tchan\]\002 \002$hcount\002 $hidden. \002$ncount\002 $leave"
    }

    if {$count eq 0} {
        reply $type $target "no channels in \002secure\002 mode found."
    } else {
        # -- create log entry
        log:cmdlog BOT * 1 $user uid [string toupper $cmd] [join $arg] $source "" "" ""
    }
}

debug 0 "\[@\] Armour: loaded user commands"

}
# -- end of namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-13_raw.tcl
#
# raw server response procedures
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

bind join - * { arm::coroexec arm::raw:join }
bind sign - * { arm::coroexec arm::raw:quit }

# -- netsplit handling
bind splt - * { arm::coroexec arm::raw:split }
bind rejn - * { arm::coroexec arm::raw:rejn }

bind raw - 352 { arm::coroexec arm::raw:genwho }
bind raw - 354 { arm::coroexec arm::raw:who }
bind raw - 315 { arm::coroexec arm::raw:endofwho }
bind raw - 317 { arm::coroexec arm::raw:signon }
bind raw - 313 { arm::coroexec arm::raw:oper }
bind raw - 401 { arm::coroexec arm::raw:nicknoton }
bind raw - 478 { arm::coroexec arm::raw:fullbanlist }

# -- auto management of mode 'secure'
bind mode - "* +D" { arm::coroexec arm::mode:add:D }
bind mode - "* -D" { arm::coroexec arm::mode:rem:D }
bind mode - "* +d" { arm::coroexec arm::mode:add:d }
bind mode - "* -d" { arm::coroexec arm::mode:rem:d }

# -- manage global banlist
bind mode - "* +b" { arm::coroexec arm::mode:add:b }

# -- manage scanlist and captcha expectation on manual voice
bind mode - "* +v" { arm::coroexec arm::mode:add:v }

# -- manage captcha expectation on manual op
bind mode - "* +o" { arm::coroexec arm::mode:add:o }

# -- remove blacklist entries on recent unbans
bind mode - "* -b" { arm::coroexec arm::mode:rem:b }


# -- begin onjoin scans
proc raw:join {nick uhost hand chan} {
    set start [clock clicks]
    global botnick 
    variable cfg

    variable data:moded;      # -- tracks a channel that has recently set mode -D+d (by chan)
    variable chan:mode;       # -- the operational mode of the registered channel (by chan)

    variable nick:setx;       # -- state: tracks a recent umode +x user (by nick)
    
    variable data:black;      # -- stores data against a recent blacklist entry (for /WHOIS results)
    variable data:chanban;    # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    variable data:kicks;      # -- stores queue of nicks to kick from a channel (by chan)
    variable data:bans;       # -- stores queue of masks to ban from a channel (by chan)
    variable data:netsplit;   # -- stores the nick!user@host for an active netsplit (by nick!userhost)    
    variable data:lasthosts;  # -- stores a list of the last N joining a channel, for 'last' blacklist entries (by chan)
    variable data:hostnicks;  # -- stores a list of nicks on a given host (by host,chan)
    variable data:ipnicks;    # -- stores a list of nicks on a given IP (by IP,chan)

    variable nick:override;   # -- state: tracks that a nick has a manual exemption in place (by chan,nick)
    variable nick:exempt;     # -- state: stores whether a nick is exempt from secondary floodnet scans (by chan,nick)
    
    variable nick:newjoin;    # -- stores uhost for nicks that have recently joined a channel (by chan,nick)
    variable nick:jointime;   # -- stores the timestamp a nick joined a channel (by chan,nick)
    variable jointime:nick;   # -- stores the nick that joined a channel (by chan,timestamp)
    
    variable nick:joinclicks; # -- the list of click references from channel joins (by nick)
    variable nick:clickchan;  # -- the channel associated with a join time in clicks (by clicks)
    
    variable scan:list;       # -- the list of nicknames to scan in secure mode:
                              #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                              #        nicks,*    :  the nicks being scanned
                              #        who,*      :  the current wholist being constructed
                              #        leave,*    :  those already scanned and left
                                        
    variable nickdata;        # -- dict: stores data against a nickname
                              #           nick
                              #              ident
                              #           host
                              #           ip
                              #           uhost
                              #           rname
                              #           account
                              #           signon
                              #           idle
                              #           idle_ts
                              #           isoper
                              #           chanlist
                              #           chanlist_ts

    variable corowho;         # -- coroutine from raw:join to send data to scanner (by nick)
            
    global fline;             # -- fline is a blacklist entry with a non-default flood limit
        
    if {$nick eq $botnick} { return; }; # -- halt if self joined
    set lchan [string tolower $chan];   # -- lower case for reliable array keys    
    set lnick [string tolower $nick];   # -- lower case for reliable key search
    set snick [split $nick];            # -- make nickname safe (for array keys)
    lassign [split $uhost @] ident host
    
    # -- store nick data in dictionary
    dict set nickdata $lnick nick $nick
    dict set nickdata $lnick ident $ident
    dict set nickdata $lnick host $host
    dict set nickdata $lnick uhost $uhost
    
    # -- ensure I am opped
    if {![botisop $chan]} { 
        putquick "WHO $nick %nuhiat,101"; # -- attempt autologin
        debug 1 "raw:join: $nick joined $chan, but I am not opped -- halting!"
        return; 
    }
    
    # -- add host to data:lasthosts
    if {[cfg:get lasthosts $chan] != ""} {
        if {![info exists data:lasthosts($lchan)]} { set data:lasthosts($lchan) $host }
        if {[lsearch -exact [get:val data:lasthosts $lchan] $host] == -1} {
            # -- add host to lasthost tracking
            set length [llength [get:val data:lasthosts $lchan]]
            set data:lasthosts($lchan) [linsert [get:val data:lasthosts $lchan] 0 $host]
            # -- keep the list maintained
            set pos [expr [cfg:get lasthosts $chan] - 1]
            if {$length >= [cfg:get lasthosts $chan]} { set data:lasthosts($lchan) [lreplace [get:val lasthosts $lchan] $pos $pos] }
        }
    }
 
    # -- halt scanner if no chan mode
    if {![info exists chan:mode($lchan)]} {
        debug 3 "raw:join: autologin (1) WHO $nick"
        putquick "WHO $nick %nuhiat,101"; # -- still attempt autologin
        return;
    }; 
        
    # -- only do scans if Armour is on.  If 'secure', scans were already done.
    set mode [get:val chan:mode $lchan]
    
    # -- prevent scanning if off, or if channel is secure (to prevent double scans)
    if {$mode eq "off" || $mode eq "secure"} {
        debug 3 "raw:join: autologin (2) WHO $nick"
        putquick "WHO $nick %nuhiat,101"; # -- still attempt autologin
        return;
    }
    
    # -- safety net (chan recent kick list)
    if {![info exists data:kicks($lchan)]} { set data:kicks($lchan) "" }
    
    # -- set newjoin tracker for nick (identify 'newcomers')
    set nick:newjoin($lchan,$snick) $uhost
    
    # -- store timestamp of newcomer for ordered sorting with floodnets
    set jtime [clock clicks]
    set jointime:nick($lchan,$jtime) $nick
    set nick:jointime($lchan,$snick) $jtime
        
    # -- unset soon (default 60 seconds)
    utimer [cfg:get time:newjoin $chan] "arm::newjoin:unset $snick $chan"
    
    # ---- mode is "on" -- begin
    debug 1 "\002raw:join: ------------------------------------------------------------------------------------\002"
    debug 1 "\002raw:join: [join $nick]!$uhost joined $chan.....\002"
    
        
    # -- track nicknames on a host
    if {![info exists data:hostnicks($host,$lchan)]} { set data:hostnicks($host,$lchan) $nick } else {
        # -- only add if doesn't already exist (for some strange reason)
        if {$nick ni [get:val data:hostnicks $host,$lchan]} { lappend data:hostnicks($host,$lchan) $nick }
    }
    
    # -- start floodnet scan exemptions
    set nick:exempt($lchan,$snick) 0; set exempt 0;

    # -- check if returning from netsplit?
    set splitval [get:val data:netsplit $nick!$uhost]
    if {$splitval ne ""} {
        # -- check if timeago is not more than netsplit memory timeout
        if {[expr ([clock seconds] - $splitval) * 60] >= [cfg:get split:mem *]} {
            debug 0 "raw:join: $nick returned from netsplit (split [userdb:timeago $splitval] ago), exempting from scans..."
            set nick:exempt($lchan,$snick) 1;
            set exempt 1;
        } else {
                debug 0 "raw:join: $nick returned after 'netsplit' after timeout period (split [userdb:timeago $splitval] ago), not exempt from scans..."
        }
        unset data:netsplit($nick!$uhost)
    } else {
        debug 0 "raw:join: $nick joined and data:netsplit($nick!$uhost) doesn't exist or is empty... continuing"
    }

    # -- exempt if recently set umode +x (read from signoff message)
    if {[info exists nick:setx($snick)] && $exempt eq 0} { 
        debug 1 "raw:join: $nick!$uhost has just set umode +x (exempt from floodnet detection)"
        set nick:exempt($lchan,$snick) 1; set exempt 1
    }

    # -- exempt if authenticated
    if {[userdb:isLogin $nick] && $exempt eq 0} {
        debug 1 "raw:join: $nick!$uhost is authenticated (exempt from floodnet detection)"
        set nick:exempt($lchan,$snick) 1; set exempt 1
    }

    # -- exempt if opped on common chan
    if {[isop $nick] && $exempt eq 0} {
        debug 1 "raw:join: $nick!$uhost is opped on common chan (exempt from floodnet detection" 
        set nick:exempt($lchan,$snick) 1; set exempt 1
    }

    # -- exempt if voiced on common chan
    if {[isvoice $nick] && $exempt eq 0} {
        debug 1 "raw:join: $nick!$uhost is voiced on common chan (exempt from floodnet detection)" 
        set nick:exempt($lchan,$snick) 1; set exempt 1
    }
    
    # -- exempt if umode +x
    if {[string match -nocase "*.[cfg:get xhost:ext *]" $host] && $exempt eq 0} { 
        debug 1 "raw:join: $nick!$uhost is umode +x (exempt from floodnet detection)" 
        set nick:exempt($lchan,$snick) 1; set exempt 1
    }
        
    # -- exempt if resolved ident
    if {![string match "~*" $ident] && $exempt eq 0} { 
        debug 1 "raw:join: $nick!$uhost has resolved ident (exempt from floodnet detection)"
        set nick:exempt($lchan,$snick) 1; set exempt 1
    }

    # -- check for manual [temporary] override (from 'exempt' cmd)
    if {[info exists nick:override($lchan,$snick)] && $exempt eq 0} {
        set nick:exempt($lchan,$snick) 1; set exempt 1
        debug 1 "raw:join: $nick!$uhost is exempt from all scans via manual override."
    }
    
    # -- check for mode +D removal in chan (avoid floodnet scans for mass revoiced clients)
    if {[info exists data:moded($chan)] && $exempt eq 0} {
        set nick:exempt($lchan,$snick) 1; set exempt 1
        debug 1 "raw:join: $nick!$uhost is exempt from all scans as result of post 'mode -d' mass-revoice"
    }
    
        
    # -- turn off exemption if test mode is on (helps for testing)
    if {[info exists cfg(test)] && $exempt eq 1} { 
        debug 1 "raw:join: test mode enabled -- $nick!$uhost is NOT exempt from floodnet detection"
        set nick:exempt($lchan,$snick) 0 
        set exempt 0
    }
    
    # -- floodnet checks
    set hit 0
    if {$exempt eq 0 && [get:val chan:mode $lchan] ne "secure"} {
        set hit [check:floodnet $snick $uhost $hand $chan]; # -- run floodnet detection
    } else { debug 1 "raw:join: user was exempt from primary (ie. nick, ident & nick!ident) floodnet detection" }
    
    # -- end of exempt

    # -- send /WHO for further scans
    
    # -- check for manual [temporary] override (from 'exempt' cmd)
    if {[info exists nick:override($lchan,$snick)]} {
        unset nick:override($lchan,$snick)
        debug 1 "\002raw:join: $nick!$uhost was exempt from all scans via manual override.. halting. ([runtime $start])\002"
        debug 1 "\002raw:join: ------------------------------------------------------------------------------------\002" 
        scan:cleanup $nick $chan; # -- cleanup tracking data
        return;
    }
    
    # -- no adaptive hit
    if {!$hit} {
        debug 1 "\002raw:join: floodnet detection complete (no hit), sending /WHO [join $nick] n%nuhiart,102 ([runtime $start])\002"
        debug 1 "\002raw:join: ------------------------------------------------------------------------------------\002" 
        # -- we need to keep some tracking data here so the 'scan' proc knows the associated channel after receiving 
        #    from raw:endofwho (which parses the list populated from each raw:who response.
        #    without this mechanism the bot will not reliably know which scan result is attributed to what channel join.
        lappend nick:joinclicks($nick) $start;  # -- a list of times in microseconds that this nick has joined a chan (by nick)
        set nick:clickchan($start) $chan;       # -- the channel that a user joined (referenced by the microsecond join time)
        set corowho($lnick) [info coroutine]
        putquick "WHO $nick n%nuhiartf,102";    # -- send the WHO to initiate scans
        lassign [yield] ip xuser rname
        unset corowho($lnick)
        
        # -- check for autologin
        if {$xuser eq ""} { set xuser 0 }; # -- safety net
        if {$xuser ne 0} {
            # -- only proceed if nickname is not already authed
            lassign [db:get user,curnick users xuser $xuser] user lognick
            if {$xuser ne 0 && $xuser ne ""} {
                dict set nickdata $lnick account $xuser
                dict set nickdata $lnick rname $rname
                if {$user ne ""} {
                    # -- TODO: make it configurable on whether to replace older eixsting logins for a user (if $lognick eq "")
                    # -- begin autologin
                    debug 1 "raw:join: autologin begin for $user ($nick!$ident@$host) - chan: $chan (\002TEMP DISABLED!\002)"
                    #userdb:login $nick $ident@$host $user 0 $chan;  # -- use common login code
                }
            }
        }
        
        if {![info exists data:kicks($lchan)]} { set data:kicks($lchan) "" }; # -- safety net
        
        set nick:uhost($snick) "$ident@$host";  # -- track hostname of nick

        # -- track nicknames on an IP
        if {![info exists data:ipnicks($ip,$lchan)]} { set data:ipnicks($ip,$lchan) $nick } else {
            # -- only add if doesn't already exist (for some strange reason)
            if {$nick ni [get:val data:ipnicks $ip,$lchan]} { lappend data:ipnicks($ip,$lchan) [join $nick] }
        }

        # -- don't continue if nick has recently been caught by floodnet detection, or otherwise kicked
        if {$nick in [get:val data:kicks $lchan]} {
            debug 2 "raw:join: nick $nick has been recently kicked from $chan -- stored in data:kicks($lchan)"
            return;
        }

        # -- don't continue if mask has been recently banned (ie. floodnet detection)
        set mask1 "*!*@$host"; set mask2 "*!~*@$host"; set mask3 "*!$ident@$host"
        foreach mask "$mask1 $mask2 $mask3" {
            if {[info exists data:chanban($lchan,$mask)]} {
                # -- nick has recently been banned; avoid unnecessary scanning
                debug 2 "raw:join: nick $nick has recently been banned from $chan -- halting"
                #return;
            }
        }
        
        # -- check if 'black' command was used
        if {[info exists data:black($lchan,state,$snick)]} {
            # -- /who triggered from 'black' command
            debug 2 "raw:join: /who response received from 'black' command"
            set timestamp [unixtime]
            set modifby [get:val data:black $lchan,modif,$snick]
            set chan [get:val data:black $lchan,chan,$snick]
            set type [get:val data:black $lchan,type,$snick]
            set target [get:val data:black $lchan,target,$snick]
            set reason [get:val data:black $lchan,reason,$snick]
            lassign [split [getchanhost [join $nick]] @] ident host; # -- TODO: won't work when nick is out of all chans
            set action "B"
            
            if {$xuser eq 0} {
                # -- not logged in, do host entry
                set method "host"; set value $banmask;
            } else {
                # -- logged in, add username entry
                set method "user"; set value $xuser      
            }
            debug 1 "raw:join: adding auto blacklist entry: type: B -- chan: $chan -- method: $type -- \
                value: $entry -- modifby: $modifby -- action: $action -- reason: $reason"
            set tid [db:add B $chan $method $value $modifby $action "" $reason]; # -- add the entry        

            # -- add the ban
            kickban $nick $ident $host $chan [cfg:get ban:time $chan] $reason $tid

            reply $type $target "added $method blacklist entry for: $value (id: $id reason: $reason)"
            
            # -- clear vars
            unset data:black($lchan,state,$snick)
            unset data:black($lchan,chan,$snick)
            unset data:black($lchan,type,$snick)
            unset data:black($lchan,target,$snick)
            unset data:black($lchan,reason,$snick)
            unset data:black($lchan,modif,$snick)
            
            return;
        }
        
        # -- build list to use at /endofwho
        debug 3 "\002raw:join:\002 appending to scan:list(data,$lchan): \002nick:\002 $nick -- \002chan:\002 $chan -- \002clicks: $start\002 -- \002ident:\002 $ident \
            -- \002ip:\002 $ip -- \002host:\002 $host -- \002xuser:\002 $xuser -- \002rname:\002 $rname"
        lappend scan:list(data,$lchan) "[list $nick] $chan 0 $start $ident $ip $host $xuser $rname"

        # -- end paste
        
    } else {
        # -- there is an adaptive scan hit (user kickbanned)
        debug 1 "\002raw:join: floodnet detection complete (user $nick!$uhost hit!), ending. ([runtime $start])\002"
        debug 1 "\002raw:join: ------------------------------------------------------------------------------------\002" 
    }
}


proc raw:nicknoton {server cmd text} {
    variable nick:host;  # -- the host of a nickname (by nick)
    variable scan:list;  # -- the list of nicknames to scan in secure mode:
                         #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                         #        nicks,*    :  the nicks being scanned
                         #        who,*      :  the current wholist being constructed
                         #        leave,*    :  those already scanned and left
    variable nickdata;   # -- dict: stores data against a nickname
                         #           nick
                         #           ident
                         #           host
                         #           ip
                         #           uhost
                         #           rname
                         #           account
                         #           signon
                         #           idle
                         #           idle_ts
                         #           isoper
                         #           chanlist
                         #           chanlist_ts
                              
    # 401 notEmp1599 nick123blah :No such nick
    set nick [lindex $text 1]
    set snick [split [string tolower $nick]]; # -- make safe for array keys
    # -- we only know the host if this is set
    if {[info exists nick:uhost($nick)]} {
        set uhost [get:val nick:uhost $nick]
    } else { set uhost "" }
    debug 2 "raw:nicknoton: no such nick: $nick (clearing vars; running logout sequence)"
    userdb:logout $nick;  # -- send logout to common code
    userdb:unset:vars nicknoton $nick $uhost server;  # -- common code to unset vars if set
    
    # -- remove if they were waiting to be scanned!
    set idx 0
    foreach list [array names scan:list data,*] {
        lassign [split $list ,] lnick chan
        set lchan [string tolower $chan]
        if {$nick eq $lnick} {
            # -- removing scanlist entry
            set scan:list(data,$lchan) [lreplace [get:val scan:list data,$lchan] $idx $idx]
            debug 3 "\002scan:cleanup:\002 removed $nick from scan:list(data,$lchan)"
        }
        incr idx
    }
    
    dict unset nickdata [string tolower $nick]; # -- remove dict data
}


proc raw:fullbanlist {server cmd arg} {
    variable cfg
    variable chan:mode;  # -- stores the operational mode of a channel (by chan)

    set chan [lindex $arg 1]
    set lchan [string tolower $chan]; # -- make safe for use in arrays
    set banmask [lindex $arg 2]
    
    # -- only continue if channel is registerd    
    if {![info exists chan:mode($lchan)]} { return; }
    
    debug 0 "arm:raw:fullbanlist: channel $chan banlist full! (using generic X ban)";
    
    # -- lockdown chan (if not already)
    if {![regexp -- {r} [getchanmode $chan]]} {
        putquick "MODE $chan +r" -next
        # -- advise channel
        if {[cfg:get chan:report $chan] != ""} { set xtra ",[cfg:get chan:report $chan]" } else { set xtra "" }
        putquick "NOTICE @$chan$xtra :Armour: channel banlist is full!"
    }
    
    # -- use generic ban
    if {[cfg:get ban $chan] eq "x"} {
        putquick "PRIVMSG [cfg:get auth:serv:nick *] :BAN $chan $banmask [cfg:get ban:time *] [cfg:get ban:level *] Armour: generic ban (full banlist)" -next
    }
}

# -- signoff procedure to exempt clients from adaptive scans when setting umode +x
proc raw:quit {nick uhost hand chan reason} {    
    variable cfg
    variable nick:setx;     # -- state: tracks a recent umode +x user (by nick)
    variable entries;       # -- dict: blacklist and whitelist entries  
    variable data:netsplit; # -- stores the nick!user@host for an active netsplit (by nick!userhost)
    variable nickdata
    
    set snick [split $nick]; # -- make nick safe for use in arrays

    dict unset nickdata [string tolower $nick]
    set host [lindex [split $uhost @] 1]
    
    debug 4 "raw:quit: quit detected in $chan: $nick!$uhost"
        
    # -- those who set umode +x (for ircu derived ircds)
    if {[cfg:get ircd *] eq 1} {
        if {$reason eq "Registered"} {
            # -- umode +x detected
            set nick:setx($snick) 1
            # -- unset array after 2 seconds (plenty of time to allow rejoin)
            utimer 2 "unset arm::nick:setx($nick)"
            return;
        }
    }
    
    # -- those who get glined, do we add auto blacklist entry
    if {[cfg:get gline:auto $chan]} {
        # -- only if matches configured mask
        if {[string match [cfg:get gline:mask $chan] $reason] && ![string match [cfg:get gline:nomask $chan] $reason]} {
            debug 4 "\002raw:quit:\002 G-Line $chan: $nick!$uhost (reason: $reason)"
            # -- add automatic blacklist entry
            if {[regexp -- [cfg:get xregex *] $host -> xuser]} {
                # -- user is umode +x
                set ttype "xuser"; set entry $xuser
            } else {
                # -- normal host entry
                set ttype "host"; set entry $host
            }
            
            # -- there can only be one unique combination of this expression
            set id [lindex [dict filter $entries script {id dictData} {
                expr {[dict get $dictData chan] eq $chan && [dict get $dictData type] eq "black" \
                    && [dict get $dictData method] eq $ttype && [dict get $dictData value] eq $entry}
            }] 0]
            
            if {$id eq ""} {
                # -- add automatic blacklist entry
                set reason "(auto) $reason"
                set modifby "Armour"
                set action "B"
                debug 1 "raw:quit: adding auto blacklist entry: type: B -- chan: $chan -- method: $ttype -- \
                    value: $entry -- modifby: $modifby -- action: $action -- reason: $reason"
                set tid [db:add B $chan $ttype $value $modifby $action "" $reason]; # -- add the entry
            }; # -- end of existing entry
        }; # -- end gline match
    }; # -- end automatic blacklist on gline    
}

# -- netsplit handling
proc raw:split {nick uhost hand chan} {
    variable data:netsplit;  # -- stores the unixtime that a client netsplit (by nick!userhost)
    # -- netsplit detected
    if {![info exists data:netsplit($nick!$uhost)]} {
        debug 1 "raw:split: netsplit detected in $chan: $nick!$uhost"
        set data:netsplit($nick!$uhost) [unixtime]
        # -- unset after a configured timeout
        timer [cfg:get split:mem *] "arm::split:unset [split $nick!$uhost]"
    }
}

# -- netsplit rejoin handling
proc raw:rejn {nick uhost hand chan} {
    variable data:netsplit;  # -- stores the unixtime that a client netsplit (by nick!userhost)
    if {[info exists data:netsplit($nick!$uhost)]} {
        # -- netsplit detected
        debug 1 "raw:split: netsplit rejoin identified in $chan: $nick!$uhost"
        unset data:netsplit($nick!$uhost)
    }
}


# -- /whois from arm:scan:continue
# obtains client signon and idle time to yield within coroutine
proc raw:signon {server cmd text} {
    variable paranoid;  # -- coroutine name to yield results
    variable nickdata;  # -- dict: stores data against a nickname
                        #             nick
                        #              ident
                        #             host
                        #             ip
                        #             uhost
                        #             rname
                        #             account
                        #             signon
                        #             idle
                        #             idle_ts
                        #             isoper
                        #             chanlist
                        #             chanlist_ts
                        
    # notEmp notEmp 16015 1300141746 :seconds idle, signon time
    set nick [lindex [split $text] 1]
    set lnick [string tolower $nick]
    #set snick [split $nick];  # -- make safe for use in arrays
    set idle [lindex [split $text] 2]
    set signon [lindex [split $text] 3]
    #debug 3 "raw:signon: nick: $nick -- cmd: $cmd -- text: $text"
    debug 3 "raw:signon: nick: $nick -- idle: $idle -- signon: $signon"
    dict set nickdata $lnick idle $idle
    dict set nickdata $lnick idle_ts [clock seconds]; # -- the capture age may come in useful
    dict set nickdata $lnick signon $signon
    # -- continue if trying to yield results in arm:scan:continue
    if {[info exists paranoid(coro,$nick)]} {
        # -- yield the results -> proc scan:continue
        #debug 3 "raw:signon: nick: $nick -- yield the results -> proc scan:continue"
        $paranoid(coro,$nick) "$idle $signon"
        unset paranoid(coro,$nick)
    } else { debug 3 "raw:signon: nick: $nick -- \002no yield!\002" }
}

# -- client is an IRC operator
proc raw:oper {server cmd text} {
    variable nickdata;  # -- dict: stores data against a nickname
                        #             nick
                        #              ident
                        #             host
                        #             ip
                        #             uhost
                        #             rname
                        #             account
                        #             signon
                        #             idle
                        #             idle_ts
                        #             isoper
                        #             chanlist
                        #             chanlist_ts
                        
    set nick [lindex $text 1]
    set lnick [string tolower $nick]
    #set snick [split $nick];  # -- make safe for use in arrays
    debug 4 "raw:oper: text: $text -- nick: $nick"
    dict set nickdata $lnick isoper 1
}

# -- proc for generic response (raw 352)
# -- add handling per ircd type
# -- this isn't returned on ircu (Undernet) for our special /WHOs that specify a 'querytype'
proc raw:genwho {server cmd arg} {
    variable cfg
    # -- ircd types:
    set ircd [cfg:get ircd *]
    if {$ircd eq "1"} {
        # -- ircu (Undernet)
        # -- do nothing, as ircu will already return raw 354 for extended WHO (instead of 352)
    } elseif {$ircd eq "2"} {        
        # -- IRCnet/EFnet
        #server    cmd    mynick type ident host server nick away :hopcount sid rname
        #irc.psychz.net    352    cori * _mxl    ipv4.pl    ircnet.hostsailor.com Maxell H :2 0PNH oskar@ipv4.pl
        lassign $arg mynick type chan ident host server nick flags hopcount sid
        set rname [lrange $arg 10 end]
        # -- NOTE: the above raw example doesn't appear to provide an actual IP; do a DNS lookup (doh! this slows us down)
        if {![isValidIP $host]} {
            # -- only do this if it's not already an IPv4 IP
            set ip [dns:lookup $host A]
            if {$ip eq "error" || $ip eq ""} { set ip 0 };    # -- fallback to disable IP scans in arm:scan
        } else { set ip $host }
        set account 0;    # -- TODO: where do we get an ACCOUNT from in IRCnet /WHO response?;
        # -- send it to arm:who
        # -- WARNING: how do we stop a scan happening on this network type, every time 
        #    there is a /WHO response returned for them?
        if {[string index $chan 0] ne "#"} {
            # -- /who was for an individual nickname
            who $nick 0 $ident $host $ip $flags $account $rname
        } else {
            # -- /who was for a channel
            who $nick $chan $ident $host $ip $flags $account $rname
        }
    }
}

# -- return from raw 354 (Undernet/ircu extended WHO)
proc raw:who {server cmd arg} {
    variable corowho
    variable nickdata

    set arg [split $arg]
    # mynick type ident ip host nick xuser :rname
    if {[string index [lindex $arg 2] 0] eq "#"} {
        # -- /who result is for channel
        lassign $arg mynick type chan ident ip host nick flags xuser
        set rname [lrange $arg 9 end]
    } else {
        # -- /who result is for individual nick
        lassign $arg mynick type ident ip host nick flags xuser
        set rname [lrange $arg 8 end]
        set chan 0
    }
    set lnick [string tolower $nick]
    dict set nickdata $lnick account $xuser

    # -- querytypes
    if {$type eq "101"} {
        # -- autologin
        return;
    } elseif {$type eq "102"} {
        # -- scanner
        who $nick $chan $ident $host $ip $flags $xuser $rname
    } elseif {$type eq "103"} {
        # -- register (username)
        return;
    } elseif {$type eq "104"} {
        # -- =nick convert to network username (xuser)
        if {[info exists corowho($lnick)]} {
            debug 0 "\002raw:who:\002 converted =nick ($lnick) to account ($xuser)"
            $corowho($lnick) $ip $xuser $rname
        }
    } elseif {$type eq "105"} {
        # -- cmd: black
        if {[info exists corowho($lnick)]} {
            debug 0 "\002raw:who:\002 returned data for $lnick (cmd: black)"
            $corowho($lnick) $ident $host $xuser
        }        
    }
}

# -- /who response for client scans
proc who {nick chan ident host ip flags xuser rname} {
    set start [clock clicks]
    variable cfg
    variable scan:full;       # -- tracks data for full channel scan by chan,key (for handling by arm::scan after /WHO):
                              #    chan,state :  tracks enablement
                              #    chan,count :  the count of users being scanned
                              #    chan,type  :  the type for responses
                              #    chan,target:  the target for responses
                              #    chan,start :  the start time for runtime calc
    variable scan:list;       # -- the list of nicknames to scan in secure mode:
                              #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                              #        nicks,*    :  the nicks being scanned
                              #        who,*      :  the current wholist being constructed
                              #        leave,*    :  those already scanned and left
    variable nick:uhost;      # -- the user@host of a nickname (by nick)
    variable nick:whotime;    # -- the timestamp when a who was received (by chan,nick)
    variable data:ipnicks;    # -- stores a list of nicks on a given IP (by IP,chan)
    variable data:hostnicks;  # -- stores a list of nicks on a given host (by host,chan)
    variable data:nickip;     # -- stores the IP address for a nickname (by nick)
    variable data:nickhost;   # -- stores the host for a nickname (by nick)
    variable data:kicks;      # -- stores list of recently kicked nicknames for a channel (by chan)
    variable data:chanban;    # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    variable data:black;      # -- stores data against a recent blacklist entry (for /WHOIS results)
    variable nickdata;        # -- dict: stores data against a nickname
                              #           nick
                              #              ident
                              #           host
                              #           ip
                              #           uhost
                              #           rname
                              #           account
                              #           signon
                              #           idle
                              #           idle_ts
                              #           isoper
                              #           chanlist
                              #           chanlist_ts
    variable dbchans;

    variable corowho;         # -- coroutine from raw:join to send data to scanner (by nick)
    
        
    debug 3 "\002who:\002 nick: $nick -- chan: $chan -- ident: $ident -- host: $host -- ip: $ip -- flags: $flags -- xuser: $xuser -- rname: $rname"
    
    set snick [split $nick];                        # -- make safe, for array keys
    set lnick [string tolower $nick];               # -- lower case for reliable dict search
    set lchan [string tolower $chan]
    set nick:whotime($lchan,$snick) [clock clicks]; # -- track the time a /who was received (for runtime in secure mode)

    # -- fix realname (if ircu)
    if {[cfg:get ircd *] eq "1"} {
        set rname [string trimleft $rname ":"]
        set rname [string trimright $rname " "]
        set rname [list $rname]
    } else { set rname [list $rname] }
    
    # -- update dictionary data for nick
    if {![dict exists $nickdata $lnick nick]} { dict set nickdata $lnick nick $nick }
    if {![dict exists $nickdata $lnick ident]} { dict set nickdata $lnick ident $ident }
    if {![dict exists $nickdata $lnick host]} { dict set nickdata $lnick host $host }
    if {![dict exists $nickdata $lnick uhost]} { dict set nickdata $lnick uhost "$ident@$host" }

    if {[regexp -- {\*} $flags]} { dict set nickdata $lnick isoper 1 } else { dict set nickdata $lnick isoper 0 }
    dict set nickdata $lnick ip $ip
    dict set nickdata $lnick account $xuser
    dict set nickdata $lnick rname $rname
    
    # -- store IP against nickname
    if {![info exists data:nickip($nick)]} { set data:nickip($nick) $ip }
        
    if {$chan eq 0} {
        # -- scan for a specific nick
        if {[info exists corowho($lnick)]} {
            # -- yield back to raw:join
            debug 4 "\002who:\002 corowho($lnick) -- ip: $ip -- xuser: $xuser -- rname: $rname"
            $corowho($lnick) "$ip $xuser $rname"
            return;
        } else {
            # -- what to do with this result?!!  no chan; no coroutine to yield
            debug 0 "\002ERROR\002! /WHO result for $nick has no chan and no coroutine to yield. Doh!"
            #putquick "NOTICE [cfg:get chan:report *] :\002ERROR\002! /WHO result for $nick has no chan and no coroutine to yield. Doh!"
            #return;
        }
        set mode "";
    } else {
        set cid [db:get id channels chan $lchan]
        set mode [dict get $dbchans $cid mode];     # -- get the operational mode for chan
    }
        
    set schan [split $chan]
    set lchan [string tolower $chan];               # -- make channel safe for arrays

    if {$mode eq "off" || $mode eq ""} { return; }; # -- TODO: don't halt if chanscan in progress
    
    if {$mode eq "secure"} {
        if {![regexp -- {<} $flags]} { return; }; # -- ignore anyone not hidden during secure mode
        if {[isvoice $nick $chan]} { return; };   # -- ignore everyone alrady voiced during secure mode (reduces race conditions)
        if {![botonchan $chan]} { return; };      # -- do not scan if bot not on chan
    }

    # -- track nicknames on an IP
    if {![info exists data:nickip($ip)]} { set data:nickip($nick) $ip }
    if {![info exists data:ipnicks($ip,$lchan)]} { set data:ipnicks($ip,$lchan) $nick } else {
        # -- only add if doesn't already exist (for some strange reason)
        debug 4 "who: data:ipnicks($ip,$lchan): [get:val data:ipnicks $ip,$lchan]"
        if {$nick ni [get:val data:ipnicks $ip,$lchan]} { lappend data:ipnicks($ip,$lchan) $nick }
    }

    # -- track nicknames on a host
    if {![info exists data:nickhost($nick)]} { set data:nickhost($nick) $host }
    if {![info exists data:hostnicks($host,$lchan)]} { set data:hostnicks($host,$lchan) $nick } else {
        # -- only add if doesn't already exist (for some strange reason)
        debug 4 "who: data:hostnicks($host,$lchan): [get:val data:hostnicks $host,$lchan]"
        if {$nick ni [get:val data:hostnicks $host,$lchan]} { lappend data:hostnicks($host,$lchan) $nick }
    }
    
    if {![info exists data:kicks($lchan)]} { set data:kicks($lchan) "" }; # -- safety net
    
    set nick:uhost($snick) "$ident@$host";  # -- track hostname of nick

    # -- don't continue if nick has recently been caught by floodnet detection, or otherwise kicked
    if {$nick in [get:val data:kicks $lchan]} {
        debug 2 "\002who: nick $nick has been recently kicked from $chan -- stored in data:kicks($chan) -- exiting\002"
        return; # -- TODO: will this prevent scans?
    }

    # -- don't continue if mask has been recently banned (ie. floodnet detection)
    set mask1 "*!*@$host"; set mask2 "*!~*@$host"; set mask3 "*!$ident@$host"
    foreach mask "$mask1 $mask2 $mask3" {
        if {[info exists data:chanban($lchan,$mask)]} {
            # -- nick has recently been banned; avoid unnecessary scanning
            debug 2 "who: nick $nick has recently been banned from $chan -- halting"
            #return; # -- TODO: should this happen?
        }
    }
    
    #putlog "\002who: scan:list(data,$lchan):\002 [get:val scan:list data,$lchan] -- in? [expr {$nick in [get:val scan:list data,$lchan]}]"
    #putlog "\002who: scan:list(nicks,$lchan):\002 [get:val scan:list nicks,$lchan] -- in? [expr {$nick in [get:val scan:list nicks,$lchan]}]"
    #putlog "\002who: scan:list(leave,$lchan):\002 [get:val scan:list leave,$lchan] -- in? [expr {$nick in [get:val scan:list leave,$lchan]}]"
    
    # -- only add people to scanlist if we haven't already scanned them and they are being left
    # -- build list to use at /endofwho
    if {![info exists scan:list(who,$lchan)]} { set scan:list(who,$lchan) [list] }
    lappend scan:list(who,$lchan) $nick
    if {$nick ni [get:val scan:list leave,$lchan]} {
        if {[info exists scan:full($chan,state)]} { set full 1 } else { set full 0 }
        debug 3 "who: appending to scan:list(data,$lchan): nick: $nick -- chan -- $chan -- full: $full -- clicks: $start -- ident: $ident -- ip: $ip -- host: $host -- xuser: $xuser -- rname: [join $rname]"
        lappend scan:list(nicks,$lchan) $nick
        lappend scan:list(data,$lchan) "[list $nick] $chan $full $start $ident $ip $host $xuser $rname"
        #debug 3 "\002who: scan:list(data,$lchan):\002 [get:val scan:list data,$lchan]"
    }
}

proc raw:endofwho {server cmd text} {
    variable cfg
    variable scan:full;       # -- tracks data for full channel scan by chan,key (for handling by arm::scan after /WHO):
                              #        chan,state :  tracks enablement
                              #        chan,count :  the count of users being scanned
                              #        chan,type  :  the type for responses
                              #        chan,target:  the target for responses
                              #        chan,start :  the start time for runtime calc
    variable scan:list;       # -- the list of nicknames to scan in secure mode:
                              #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                              #        nicks,*    :  the nicks being scanned
                              #        who,*      :  the current wholist being constructed
                              #        leave,*    :  those already scanned and left
    variable data:ipnicks;    # -- stores a list of nicks on a given IP (by IP,chan)
    variable data:nickip;     # -- stores the IP address for a nickname (by nick)
    variable data:hostnicks;  # -- stores a list of nicks on a given host (by host,chan)
    variable data:nickhost;   # -- stores the hostname for a nickname (by nick)

    variable corowho;
    variable nickdata;

    set mask [lindex $text 1]
    set lchan [string tolower $mask]
        
    # -- remove any 'leave' entries if the containing nick is not in this scan list
    # -- they could have changed nicks, quit, been kicked, or parted    
    set leavelist "";
    if {[string index $mask 0] eq "#"} {
        set mode [get:val chan:mode $lchan]
        if {$mode eq "secure"} {
            set leavelist [get:val scan:list leave,$lchan]
            set nicklist [get:val scan:list nicks,$lchan]
            set wholist [get:val scan:list who,$lchan]
            set datalist [get:val scan:list data,$lchan]
            if {$wholist ne ""} { debug 4 "\002endofwho: scan:list(who,$lchan):\002 $wholist" }
            if {$datalist ne ""} { debug 4 "\002endofwho: scan:list(data,$lchan):\002 $datalist" }
            if {$nicklist ne ""} { debug 4 "\002endofwho: scan:list(nicks,$lchan):\002 $nicklist" }
            if {$leavelist ne ""} { debug 4 "\002endofwho: scan:list(leave,$lchan):\002 $leavelist"    }
            
            if {$nicklist eq "" || $datalist eq ""} { set scan:list(who,$lchan) "" }
            
            foreach n $leavelist {
                # -- check if nick in leavelist, but not in nicklist
                if {$n ni $nicklist && $n ni $wholist} {
                    set idx [lsearch -exact $leavelist $n]
                    debug 4 "\002endofwho: 1 - \002removing $n from scan:list(leave,$lchan)"
                    set scan:list(leave,$lchan) [lreplace [get:val scan:list leave,$lchan] $idx $idx]
                    set leavelist [lreplace $leavelist $idx $idx]
                    set remove 1
                }
            }

            # --- remove from nicklist if not in recent wholist
            foreach n [get:val scan:list nicks,$lchan] {
                set remove 0
                if {[get:val scan:list who,$lchan] ne ""} {
                    if {$n ni [get:val scan:list who,$lchan]} {
                        # -- remove;
                        # nick must have left, changed nicks, been kicked, or quit
                        if {[info exists scan:list(nicks,$lchan)]} { debug 4 "\002endofwho: 2 - $n not in scan:list(who,$lchan)!\002 removing from scan:list(nicks,$lchan)"; unset scan:list(nicks,$lchan) }
                        if {[info exists scan:list(leave,$lchan)]} { debug 4 "\002endofwho: 3 - $n not in scan:list(leave,$lchan)!\002 removing from scan:list(leave,$lchan)"; unset scan:list(leave,$lchan) }
                        set remove 1
                    }
                    unset scan:list(who,$lchan)
                } else {
                    # -- wholist is emtpy
                    if {[info exists scan:list(nicks,$lchan)]} { debug 4 "\002endofwho:\002 4 - scan:list(who,$lchan) is empty!\002 clearing scan:list(nicks,$lchan)"; unset scan:list(nicks,$lchan) }
                }
                
                if {$remove} {
                    # -- stores the IP address of a nickname
                    if {[info exists data:nickip($n)]} {
                        set ip [get:val data:nickip $n]
                        if {[info exists data:ipnicks($ip,$lchan)]} {
                            # -- stores the nicknames on an IP
                            set pos [lsearch -exact [get:val data:ipnicks $ip,$lchan] $n]
                            if {$pos ne "-1"} {
                                debug 4 "\002endofwho: secure mode leave nick missing from $lchan!\002 removing $n from data:ipnicks($ip,$lchan)"
                                set data:ipnicks($ip,$lchan) [lreplace [get:val data:ipnicks $ip,$lchan] $pos $pos]
                                if {[get:val data:ipnicks $ip,$lchan] eq ""} { unset data:ipnicks($ip,$lchan) }
                            }
                        }
                        if {![onchan $n]} {
                            debug 4 "\002endofwho: secure mode leave nick missing from $lchan!\002 removing $n from data:nickip($n)"
                            unset data:nickip($n)
                        }
                    }
                    
                    # -- stores the host address of a nickname
                    # -- needed outside of eggdrop due to chanmode +D
                    if {[info exists data:nickhost($n)]} {
                        set host [get:val data:nickhost $n]
                        if {[info exists data:hostnicks($host,$lchan)]} {
                            # -- stores the nicknames on a host
                            set pos [lsearch -exact [get:val data:hostnicks $host,$lchan] $n]
                            if {$pos ne "-1"} {
                                debug 4 "\002endofwho: secure mode leave nick missing from $lchan!\002 removing $n from data:hostnicks($host,$lchan)"
                                set data:hostnicks($host,$lchan) [lreplace [get:val data:hostnicks $host,$lchan] $pos $pos]
                                if {[get:val data:hostnicks $host,$lchan] eq ""} { unset data:hostnicks($host,$lchan) }
                            }
                        }
                        if {![onchan $n]} {
                            debug 4 "\002endofwho: secure mode leave nick missing from $lchan!\002 removing $n from data:nickhost($n)"
                            unset data:nickhost($n)
                        }
                    }
                }
            }
        }
    }
    
    # -- send to arm:scan only after all client /WHO responses have returned
    foreach cgroup [array names scan:list "data,*"] {
        lassign [split $cgroup ,] data lchan
        foreach i [get:val scan:list data,$lchan] {
            lassign $i nick chan full clicks ident ip host xuser rname
            if {$nick ni $leavelist} {
                set lchan [join [lindex [split $cgroup ,] 1]]
                set rname [list $rname]
                debug 3 "raw:endofwho: sending arg to arm::scan: nick: $nick -- chan: $chan -- full: $full -- clicks: $clicks -- ident: $ident -- ip: $ip -- host: $host -- xuser: $xuser -- rname: $rname"
                scan [list $nick] $chan $full $clicks $ident $ip $host $xuser $rname
            }
        }
    }

    # -- full channel scan (cmd: chanscan)
    if {[string index $mask 0] eq "#"} {
        set chan $mask
        set lchan [string tolower $mask];
        if {[info exists scan:full($mask,state)]} {
            # -- it was a full chanscan
            debug 1 "raw:endofwho: ending full channel scan: $chan"
            set type [get:val scan:full $lchan,type]
            set target [get:val scan:full $lchan,target]
            set start [get:val scan:full $lchan,start]
            set count [get:val scan:full $lchan,count]
            set runtime [runtime $start]
            reply $type $target "done. scanned $count users ($runtime)"
            if {$type ne "pub"} { putquick "NOTICE @$chan :Armour: channel scan complete. scanned $count users ($runtime)"  }
            if {$chan ne [cfg:get chan:report $chan]} { putquick "NOTICE [cfg:get chan:report $chan] :Armour: channel scan of $chan complete. scanned $count users ($runtime)" }
            # -- unset existing tracking data for chan
            foreach i [array names scan:full "$lchan,*"] {
                unset scan:full($i)
            }
        }
    }

    # -- handle cases where WHO was done for =nick convert to network user but nick was not online
    if {[info exists corowho($mask)]} {
        if {[dict exists $nickdata $mask account]} {
            set xuser [dict get $nickdata $mask account]
        } else { set xuser 0 }
        debug 0 "\002raw:who:\002 presume conversion for =nick ($mask) to account -- user not online?"
        $corowho($mask) $xuser
    }
}


# ---- enable & disable mode 'secure' on the fly

# -- manual set of +D
# - let the ops do the rest (ie. voicing existing users if they also set +m)
proc mode:add:D {nick uhost hand chan mode target} {
    global botnick
    variable chan:mode; # -- stores the operational mode of a channel (by chan)
    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }
    # -- only react if configured to do so
    if {[cfg:get mode:auto]} {
        debug 0 "mode:add:D: mode: $mode in $chan, enabled mode 'secure'"
        set chan:mode($lchan) "secure"
        reply pub $chan "changed mode to: secure"
        # -- start '/names -d' timer
        # -- kill any existing mode:secure timers
        foreach utimer [utimers] {
            set thetimer [lindex $utimer 1]
            if {$thetimer eq "arm::mode:secure"} { continue; }
            debug 1 "mode:add:D: killing arm:secure utimer: $utimer"
            killutimer [lindex $utimer 2] 
        }
        mode:secure
    }
}

# -- manual set of -D
proc mode:rem:D {nick uhost hand chan mode target} {
    global botnick
    variable chan:mode;  # -- stores the operational mode of a channel (by chan)
    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }
    # -- only react if configured to do so
    if {[cfg:get mode:auto]} {
        debug 0 "mode:rem:D: mode: $mode in $chan, disabled mode 'secure' (enabled mode 'on')"
        set chan:mode($lchan) "on"
        reply pub $chan "changed mode to: on"
        # -- kill any existing arm:secure timers
        foreach utimer [utimers] {
            set thetimer [lindex $utimer 1]
            if {$thetimer ne "arm::mode:secure"} { continue; }
            debug 1 "mode:rem:D: killing arm:secure utimer: $utimer"
            killutimer [lindex $utimer 2] 
        }
    }
}

# -- auto server set of +d (still hidden users available via /names -d <chan>)
proc mode:add:d {nick uhost hand chan mode target} {
    global botnick
    variable cfg
    variable data:moded;  # -- tracks a channel that has recently set mode -D+d (by chan)
    variable chan:mode;   # -- stores the operational mode of a channel (by chan)
    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }
    # -- notify chan of hidden clients
    debug 0 "mode:add:d: mode: $mode in $chan, hidden clients -- /quotes names -d $chan"
    reply notc @$chan "info: hidden clients -- /quote names -d $chan"
    
    # -- disable floodnet processing
    debug 0 "mode:add:d: mode: $mode in $chan, disabling floodnet processing on joins (for [cfg:get time:moded $chan] secs or until mode -d)"
    set data:moded($lchan) 1
    # -- unset the array on configured time
    utimer [cfg:get time:moded $chan] "unset arm::data:moded($lchan)"
}

# -- auto server set of -d (all hidden users left, kicked, voiced or opped)
proc mode:rem:d {nick uhost hand chan mode target} {
    global botnick
    variable cfg
    variable data:moded;  # -- tracks a channel that has recently set mode -D+d (by chan)
    # -- notify chan of visible clients
    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }
    debug 0 "mode:rem:d: mode: $mode in $chan, all hidden clients now visiable"
    reply notc @$chan "info: all hidden clients now visible."
    
    # -- re-enable floodnet processing
    if {[info exists data:moded($lchan)]} {
        debug 0 "mode:rem:d: mode: $mode in $chan, re-enabling floodnet detection on joins"
        unset data:moded($lchan)
    }
}


# --- manage the global banlist by removing those that actually get banned
proc mode:add:b {nick uhost hand chan mode target} {
    variable cfg
    variable data:bans
    #if {![string match -nocase $chan [cfg:get chan:auto $chan]]} { return; }    
    set mask $target
    set lchan [string tolower $chan]
    # -- remove mask from global banlist if exists
    set pos [lsearch -exact [get:val data:bans $lchan] $mask]
    if {$pos ne -1} {
        # -- nick within
        set data:bans($lchan) [lreplace [get:val data:bans $lchan] $pos $pos]
        if {[get:val data:bans $lchan] eq ""} { unset data:bans($lchan) }
    }
}

# --- remove a nickname from scanlist (previously scanned clients under mode 'secure'), if someone voices them manually
proc mode:add:v {nick uhost hand chan mode target} {
    global botnick
    variable cfg
    variable chan:mode;     # -- stores the operational mode of a channel (by chan)    set lchan [string tolower $chan]
    variable scan:list;     # -- the list of nicknames to scan in secure mode:
                            #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                            #        nicks,*    :  the nicks being scanned
                            #        who,*      :  the current wholist being constructed
                            #        leave,*    :  those already scanned and left
    variable data:captcha;  # -- holds captcha data for nick (by nick,chan)
    variable data:ctcp;     # -- stores whether we're waiting for a CTCP VESION reply (by chan,nick)
    
    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }
    
    # -- check for strictvoice (if not mode secure)
    if {[strict:isAllowed voice $chan $target] eq 0 && [get:val chan:mode $lchan] ne "secure"} {
        # -- user not allowed to be opped in chan
        putquick "MODE $chan -v $target"
        set tuhost [getchanhost $target]
        putquick "NOTICE @$chan :Armour: $target!$tuhost not allowed to be voiced (\002strictvoice\002)"
    }


    # -- remove nick from scan:list(nicks,chan) if exists (list of those to scan from secure mode /WHO)
    if {[info exists scan:list(nicks,$lchan)]} {
        set pos [lsearch -exact [get:val scan:list nicks,$lchan] $target]
        if {$pos ne -1} {
            set scan:list(nicks,$lchan) [lreplace [get:val scan:list nicks,$lchan] $pos $pos]
        }
    }
    
    # -- remove nick from scan:list(leave,chan) if exists (list of those being left after secure mode scan)
    if {[info exists scan:list(leave,$lchan)]} {
        set pos [lsearch -exact [get:val scan:list leave,$lchan] $target]
        if {$pos ne -1} {
            set scan:list(leave,$lchan) [lreplace [get:val scan:list leave,$lchan] $pos $pos]
        }
    }
    
    # -- remove CAPTCHA response expectation
    if {[info exists data:captcha($nick,$chan)]} {
        debug 3 "mode:add:v: $nick!$uhost was voiced on $chan! removing CAPTCHA expectation"
        unset data:captcha($nick,$chan)
    }
    
    # -- remove any CTCP VESION reply tracker
    if {[info exists data:ctcp($chan,$nick)]} {
        debug 3 "mode:add:v: $nick!$uhost was voiced on $chan! removing CTCP VERSION reply expectation"
        unset data:ctcp($nick,$chan)        
    }
    
}

proc mode:add:o {nick uhost hand chan mode target} {
    global botnick
    variable cfg
    variable scan:list;     # -- the list of nicknames to scan in secure mode:
                            #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                            #        nicks,*    :  the nicks being scanned
                            #        who,*      :  the current wholist being constructed
                            #        leave,*    :  those already scanned and left
    variable data:captcha;  # -- holds captcha data for nick (by nick,chan)
    variable data:ctcp;     # -- stores whether we're waiting for a CTCP VESION reply (by chan,nick)
    variable chan:mode;     # -- state: the operational mode of a registered channel (by chan)    

    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }
    
    # -- check for strictop
    if {[info exists chan:mode($lchan)]} {
        # -- chan is registered
        if {[strict:isAllowed op $chan $target] eq 0} {
            # -- user not allowed to be opped in chan
            putquick "MODE $chan -o $target"
            set tuhost [getchanhost $target]
            putquick "NOTICE @$chan :Armour: $target!$tuhost not allowed to be opped (\002strictop\002)"
        }
    }

    # -- remove nick from scan:list(nicks,chan) if exists (list of those to scan from secure mode /WHO)
    if {[info exists scan:list(nicks,$lchan)]} {
        set pos [lsearch -exact [get:val scan:list nicks,$lchan] $target]
        if {$pos ne -1} {
            set scan:list(nicks,$lchan) [lreplace [get:val scan:list nicks,$lchan] $pos $pos]
        }
    }
    
    # -- remove nick from scan:list(leave,chan) if exists (list of those being left after secure mode scan)
    if {[info exists scan:list(leave,$lchan)]} {
        set pos [lsearch -exact [get:val scan:list leave,$lchan] $target]
        if {$pos ne -1} {
            set scan:list(leave,$lchan) [lreplace [get:val scan:list leave,$lchan] $pos $pos]
        }
    }
    
    # -- remove CAPTCHA response expectation
    if {[info exists data:captcha($nick,$chan)]} {
        debug 3 "mode:add:o: $nick!$uhost was opped on $chan! removing CAPTCHA expectation"
        unset data:captcha($nick,$chan)
    }
    
    # -- remove any CTCP VESION reply tracker
    if {[info exists data:ctcp($chan,$nick)]} {
        debug 3 "mode:add:o: $nick!$uhost was opped on $chan! removing CTCP VERSION reply expectation"
        unset data:ctcp($nick,$chan)        
    }

}
        
# --- delete blacklist if ban has been removed recently?
# - recently means within period: cfg(idunban.time)
proc mode:rem:b {nick uhost hand chan mode target} {
    global botnick
    variable cfg
    variable data:banmask
    variable userdb
    variable chan:mode;   # -- stores the operational mode of a channel (by chan) set lchan [string tolower $chan]
    variable entries;     # -- dict storing all whitelist & blacklist entries

    if {![cfg:get black:unban:rem $chan]} { return; }; # -- only continue if configured
    set lchan [string tolower $chan]
    if {![info exists chan:mode($lchan)] || $nick eq $botnick} { return; }    
    lassign [userdb:user:get id,user curnick $nick] uid user
    if {$user eq ""} { return; };
    if {![userdb:isAllowed $nick rem $chan pub]} { return; }; # -- user has no access to remove blacklists
    
    # -- check if there is a recent blacklist in memory
    foreach id [array names data:banmask] {
        if {$target eq [get:val data:banmask $id]} {
            unset data:banmask($id)
            if {![dict exists $entries $id]} { continue; }; # -- entry no longer exists

            set tchan [get:val list:chan $id]
            if {$tchan eq "*"} {
                # -- if the entry is global, we need to check the user has global access to remove
                set globlevel [lindex [db:get level levels uid $uid cid 0] 0]; # -- select level from levels where uid=$uid and cid=0
                if {$globlevel >= $userdb(cmd,rem,pub)} {
                    continue;
                }
            }
            # -- remove the blacklist
            set type [dict get $entries $id type]
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            set action [dict get $entries $id action]
            set limit [dict get $entries $id limit]
            set hits [dict get $entries $id hits]
            set reason [join [dict get $entries $id reason]]
            set ext [lassign [split $limit :] joins secs hold]
            if {$secs eq $hold} { set limit "$joins:$secs" }
            if {$type eq "white"} { set list "whitelist" } \
            elseif {$type eq "black"} { set list "blacklist" }
            debug 1 "mode:rem:b: $nick unbanned $target -- automatically removing blacklist (method: $method -- value: $value)"
            db:rem $id
            if {$limit ne "1:1"} { reply pub $chan "removed $method $list entry (\002id:\002 $id \002value:\002 $value \002action:\002 $action \002limit:\002 $limit \002hits:\002 $hits \002reason:\002 $reason)" } \
            else { reply pub $chan "removed $method $list entry (\002id:\002 $id \002value:\002 $value \002action:\002 $action \002hits:\002 $hits \002reason:\002 $reason)" }
        }
    }
}

debug 0 "\[@\] Armour: loaded raw functions."

}
# -- end of namespace

# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-14_scan.tcl
#
# core list scanner (triggered by /who responses)
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

bind pubm - * { arm::coroexec arm::pubm:scan }; # -- scanner for 'text' blacklist entries
bind ctcp - "ACTION" { arm::coroexec arm::scan:action };
bind ctcr - "VERSION" { arm::coroexec arm::ctcp:version:reply }


proc scan {nick chan full clicks ident ip host xuser rname} {
    set start [clock clicks]
    global botnick
    variable cfg;             # -- config variables
    
    variable scan:full;       # -- tracks data for full channel scan by chan,key (for handling by arm::scan after /WHO):
                              #    chan,state :  tracks enablement
                              #    chan,count :  the count of users being scanned
                              #    chan,type  :  the type for responses
                              #    chan,target:  the target for responses
                              #    chan,start :  the start time for runtime calc
    variable scan:list;       # -- the list of nicknames to scan in secure mode:
                              #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                              #        nicks,*    :  the nicks being scanned
                              #        who,*      :  the current wholist being constructed
                              #        leave,*    :  those already scanned and left
    variable chan:mode;       # -- state: the operational mode of a registered channel (by chan)
    variable data:whois;      # -- state: tracking client info for /WHOIS result
    variable nick:exempt;     # -- state: temporary client exemption (by chan,nick)
    variable nick:newjoin;    # -- state: tracking recently joined client (by chan,nick)
    variable nick:jointime;   # -- stores the timestamp a nick joined a channel (by chan,nick)
    variable nick:override;   # -- state: tracks that a nick has a manual exemption in place (by chan,nick)
    variable nick:joinclicks; # -- the list of click references from channel joins (by nick)
    variable nick:clickchan;  # -- the channel associated with a join time in clicks (by clicks)
    variable nick:setx;       # -- state: tracks a recent umode +x user (by nick)

    variable captchasent;     # -- state: where a captcha has already been sent (by chan,nick)
    variable captchaflag;     # -- state: where a captcha flag is enabled for a matched pattern (by chan,nick)
    
    variable entries;         # -- dict: blacklist and whitelist entries
    variable dbchans;         # -- dict to store channel db data
    variable nickdata;        # -- dict: stores data against a nickname
                              #           nick
                              #              ident
                              #           host
                              #           ip
                              #           uhost
                              #           rname
                              #           account
                              #           signon
                              #           idle
                              #           idle_ts
                              #           isoper
                              #           chanlist
                              #           chanlist_ts
                              #           whotime

    # -- halt if me
    if {$nick eq $botnick} { 
        debug 1 "scan: halting: $nick (user is me)"
        debug 1 "\002scan: ------------------------------------------------------------------------------------\002"
        return; 
    } else {
        debug 1 "\002scan: ------------------------------------------------------------------------------------\002"
    }
    
    set nick [join $nick];
    set lnick [string tolower $nick]
    set snick [split $nick];           # -- split nick for safe use in arrays 
    set lchan [string tolower $chan];  # -- make safe for use in arrays (lowercase)
    lassign [db:get id,chan channels chan $chan] cid chan; # -- get ID and fix chan case

    # -- setup nuhr var for regex matching
    debug 3 "\002scan: received: chan: $chan -- nick: $nick -- ident: $ident -- host: $host -- ip: $ip -- xuser: $xuser -- rname: $rname\002"
    
    # -- helpful debugging to find source of superfluous scans
    if {![info exists scan:list(who,$lchan)]} { set scan:list(who,$lchan) "" } else { debug 4 "scan:continue scan:list(who,$lchan): [get:val scan:list who,$lchan]" }
    if {![info exists scan:list(data,$lchan)]} { set scan:list(data,$lchan) "" } else { debug 4 "scan:continue scan:list(data,$lchan): [get:val scan:list data,$lchan]" }
    if {![info exists scan:list(nicks,$lchan)]} { set scan:list(nicks,$lchan) "" } else { debug 4 "scan:continue scan:list(nicks,$lchan): [get:val scan:list nicks,$lchan]" }
    if {![info exists scan:list(leave,$lchan)]} { set scan:list(leave,$lchan) "" } else { debug 4 "scan:continue scan:list(leave,$lchan): [get:val scan:list leave,$lchan]" }

    # -- remove click tracking for the nick & chan
    if {[info exists nick:clickchan($clicks)]} { unset nick:clickchan($clicks) }
    list:remove nick:joinclicks($nick) $clicks

    set nuhr "$nick!$ident@$host/$rname"
    set uhost "$ident@$host"
 
    # -- is full channel scan underway?
    if {$full} { incr scan:full(count,$lchan) }
       
    if {$xuser eq 0} {  debug 2 "scan: scanning: $nuhr (not logged in)"; set auth 0; } \
    else { debug 2 "scan: scanning: $nuhr (xuser: $xuser)"; set auth 1 }
            
    set dnsbl [cfg:get dnsbl $chan];  # -- enable DNSBL scans?
    set ipscan 1; set portscan 1;     # -- default to enable IP scans
    
    # -- turn off dnsbl & ports scans if resolved ident?
    if {![cfg:get scans:all $chan]} {
        if {[string match "~*" $ident]} { set dnsbl 1; set portscan 1 } else { set dnsbl 0; set portscan 0 }
    } else { set dnsbl $dnsbl }
    
    # -- turn off dnsbl & port scans if umode +x or service
    if {$ip eq "127.0.0.1" || $ip eq "0::"} { set dnsbl 0; set portscan 0; set ipscan 0 }
    
    # -- turn off dnsbl & port scans if rfc1918 ip space
    # -- TODO: IPv6
    if {[string match "*:*" $ip] eq 0} {
        if { [cidr:match $ip "10.0.0.0/8"]     } { set dnsbl 0; set ipscan 0; set portscan 0 } \
        elseif { [cidr:match $ip "172.16.0.0/12"]  } { set dnsbl 0; set ipscan 0; set portscan 0 } \
        elseif { [cidr:match $ip "192.168.0.0/16"] } { set dnsbl 0; set ipscan 0; set portscan 0 }
    } else { set dnsbl 0; set portscan 0; set ipscan 0; }

    # -- turn off IP scans if host is service (undernet.org)
    if {$host eq [cfg:get servicehost *]} { set dnsbl 0; set portscan 0; set ipscan 0 }

    # -- turn off IP scans if IP unknown from /WHO, unless 'host' is an IPv4 IP
    # -- TODO: IPv6
    if {$ip eq "0"} {
        if {[isValidIP $host]} {
            # -- the host is an IPv4 IP
            set ip $host
        } else {
            # -- disable IP scans if this isn't an ircu derived ircd (ie. IRCnet) and we cannot resolve the IP
            # -- note that this scenario makes for a performance hit with all scans
            if {[cfg:get ircd *] ne "1"} {
                set ip [dns:lookup $host A]
                if {$ip rq "error" || $ip eq ""} {
                    set ip 0; # -- fallback to disable IP scans in scan
                    set dnsbl 0; set portscan 0; set ipscan 0
                }
            }
        }
    }
    
    # -- check operop channel setting
    if {[dict exists $dbchans $cid operop]} {
        if {[dict get $dbchans $cid operop] eq "on"} {
            # -- setting to autoop opers
            if {[dict exists $nickdata $lnick isoper]} {
                if {[dict get $nickdata $lnick isoper] eq 1} {
                    set isoper [dict get $nickdata $lnick isoper]
                    debug 0 "scan: $nick!$uhost is an IRC operator... exempting from scans and opping!"
                    set exempt 1; set dnsbl 0; set portscan 0; set ipscan 0;
                    report operop $nick "Armour: $nick!$uhost is an IRC Operator (operop)" $chan
                    putquick "MODE $chan +o $nick"
                }
            }
        }
    }

    # -- is nick exempt?
    set exempt [get:val nick:exempt $lchan,$snick]
    if {$exempt eq ""} { set exempt 0 }
        
    debug 2 "scan: pre-vars: dnsbl: $dnsbl ipscan: $ipscan portscan: $portscan auth: $auth exempt: $exempt"

    set chanmode [get:val chan:mode $lchan]
    if {$chanmode eq "secure"} {
        # -- channel jointime not known
        set jointime [get:val nick:whotime $lchan,$snick]
    } else {
        # -- chan jointime should be known
        set jointime [get:val nick:jointime $lchan,$snick]
    }
    
    # -- do floodnet detection
    # - only if not chanscan & not secure mode & user not exempt
    set hit 0
    if {!$full && $chanmode ne "secure" && !$exempt} {
        debug 5 "scan: sending $nick to arm:check:floodnet for secondary floodnet matching"
        set hand [nick2hand $nick]
        set hit [check:floodnet $nick $uhost $hand $chan $xuser $rname]
    } else { debug 5 "scan: not sending $nick to arm:check:floodnet for secondary floodnet matching" }
    
    # -- prevent further scans if adaptive regex matched
    if {$hit} {
        # -- no matches at all.... 
        # debug 2 "scan: ------------------------------------------------------------------------------------"
        debug 1 "scan: adaptive regex matching complete... hit found! -- [runtime $jointime]"
        debug 2 "scan: ------------------------------------------------------------------------------------"
        if {$exempt} { unset nick:exempt($chan,$snick) }
        scan:cleanup $nick $chan; # -- cleanup vars
        return;
    }

    debug 2 "scan: ------------------------------------------------------------------------------------"

    # --- whitelist & blacklist scans
    set match 0; set todo 0; set hit 0; set id ""; set hits "";
    set tchan ""; set ltype ""; set method ""; set value ""; set what ""; 
    set country ""; set asn ""; # -- check this so we only do the lookups once

    foreach list "white black" {
        debug 1 "scan: beginning ${list}list matching in $chan";        
        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {([dict get $dictData chan] eq $chan || [dict get $dictData chan] eq "*") \
            && [dict get $dictData type] eq $list && [dict get $dictData limit] eq "1:1:1"}
        }]]

        #debug 1 "\002scan:\002 scanning $list \002ids:\002 $ids"
        set cache "";
        foreach id $ids {
            set tchan [dict get $entries $id chan]
            set ltype [dict get $entries $id type]
            switch -- $ltype {
                W { set ltype "white" }
                B { set ltype "black" }
            }
            set method [string tolower [dict get $entries $id method]]
            set value [dict get $entries $id value]

            # -- check match, recursively
            lassign [scan:match $tchan $ltype $id $method $value $ipscan $nick $ident $host $ip $xuser $rname $country $asn $cache $hits] \
                match hit todo what cache hits country asn
            
            if {$match} { break; }; # -- there has been a match!

        }; # -- end of foreach id

        # -- do matching for any scans still to do
        if {$todo} {
            if {[string match -nocase $value $what]} { set match 1; }
            # -- TODO: should we allow regex values for other types?
        }

        # -- DEPENDENCIES
        # -- If a list entry is dependent on others, we use the first matched ID's reason, action, flags

        # -- build a comma separated list of 'effective' IDs after following all dependent list entries
        if {$hits eq 0} { set depids $id } else { set depids [join $hits ,] }; # -- list of IDs that were matched

        debug 4 "scan: ended ${list}list matching in $chan; processing any results (match: $match -- ltype: $ltype)"; 
        if {[info exists what]} { debug 5 "scan: ${list}list result what: $what" };

        # -- process matches
        if {$match} {
            # -- there was a match
            set reason [dict get $entries $id reason]
            
            debug 1 "scan: ${list}list matched $value -- (id: $depids -- type: $ltype -- method: $method) -- taking action! ([runtime $jointime])"
            debug 2 "scan: ------------------------------------------------------------------------------------"
            if {[info exists chan:mode($chan)]} { set cmode [get:val chan:mode $chan] } else { set cmode [cfg:get mode $chan] };  # -- make mode chan specific
            set manual [dict get $entries $id manual];   # -- is the manual flag set?
            set captcha [dict get $entries $id captcha]; # -- is the captcha flag set?
            set silent [dict get $entries $id silent];   # -- is the silent flag set?
            if {$captcha} {
                set captchaflag($chan,$nick) 1
                if {[captcha:scan $nick "$ident@$host" $chan $id]} {
                    # -- returns whether manual handling required
                    set manual 1; set captchasent($chan,$nick) 1; 
                };
            } else { set captchasent($chan,$nick) 0; set captchaflag($chan,$nick) 0; }

            #putlog "\002scan: manual: $manual captcha: $captcha silent: $silent"
            if {$silent} { debug 1 "scan: skipping notice for $ltype entry as silent=1 (chan: $tchan -- id: $depids -- method: $method -- value: $value)" }
            if {[info exists nick:setx($nick)]} { 
                set silent 1
                debug 1 "scan: skipping notice for $ltype entry as umode +x just set (chan: $tchan -- id: $depids -- depids: $depids -- method: $method -- value: $value)"
            }
            if {$ltype eq "white"} {
                # -- whitelist match
                if {$manual} {
                    # -- manual action required
                    if {!$captcha && $silent eq 0} {
                        reply notc @$chan "Armour: $nick!$ident@$host waiting manual action (\002whitelist entry requires manual review\002 -- \002id:\002 $depids) -- \002/whois $nick\002"
                    }
                    # -- maintain a list so we don't scan this client again
                    debug 3 "\002scan:\002 adding $nick to scan:list(leave,$lchan)"
                    set leave "leave"; set chanops 0;
                } else {
                    set mode [list:mode $id]; set leave ""; set chanops 1;
                    if {$mode ne ""} { putquick "MODE $chan $mode $nick" -next } elseif {$cmode eq "secure"} { voice:give $chan $nick };
                }
            } elseif {$ltype eq "black"} {
                if {$manual} {
                    # -- manual action required
                    if {!$captcha && $silent eq 0} {
                        reply notc @$chan "Armour: $nick!$ident@$host waiting manual action (\002blacklist entry requires manual review\002 -- \002id:\002 $depids) -- \002/whois $nick\002"
                    }
                    # -- maintain a list so we don't scan this client again
                    debug 3 "\002scan:\002 adding $nick to scan:list(leave,$lchan)"
                    set leave "leave"; set chanops 0
                } else {
                    # -- blacklist match!
                    set limit [dict get $entries $id limit]
                    if {$limit ne "1:1:1"} { continue; }
                    set string "Armour: blacklisted"
                    if {[cfg:get black:kick:value $chan]} { append string " -- $value" }
                    if {[cfg:get black:kick:reason $chan]} { append string " (reason: $reason)" }
                    set string "$string \[id: $depids\]";
                    # -- truncate reason for X bans
                    if {[string tolower [cfg:get ban $chan]] eq "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
                    kickban $nick $ident $host $chan [cfg:get ban:time $chan] $string $id
                    set leave ""; set chanops 1
                    # -- check for IRCBL entry-- after ban so it doesn't slow the ban down
                    if {[dict get $entries $id ircbl]} {
                        if {[lindex [ircbl:query add $ip $reason] 0]} {
                            debug 1 "scan: added $ltype entry IP to \002IRCBL\002 as ircbl=1 (chan: $chan -- id: $id -- depids: $depids -- method: $method -- value: $value -- \002ip:\002 $ip)"
                        }
                    }
                }
            } else { break; }; #-- safety net 
            if {$silent eq 0} {
                set report "Armour: $nick!$ident@$host ${list}listed (\002id:\002 $depids \002type:\002 $method"
                if {[cfg:get report:value $chan]} { append report " \002value:\002 $value" }
                if {[cfg:get report:reason $chan]} { append report " \002reason:\002 $reason" }
                append report ")"
                report $list $nick $report $chan $chanops; # -- report to nick and/or channels (including chanops if configured)
            }
            foreach i [split $depids ,] {
                hits:incr $i; # -- incr statistics, for the ID and all dependencies 
            }
            integrate $nick $uhost [nick2hand $nick] $chan 1; # -- pass join to any integrated scripts
            scan:cleanup $nick $chan $leave; # -- cleanup vars
            debug 5 "\002scan: ending after a match\002"; 

            debug 1 "\002scan:\002 \002match found\002 against $nuhr (xuser: $xuser) in $chan -- [runtime $jointime]"
            debug 1 "\002scan: ------------------------------------------------------------------------------------\002"

            return;
        }; # -- end of match!

        debug 5 "scan: ended behaviour when there is a scan match"; 
        
    }; # -- end foreach lists
                
    # ---- end of whitelist and blacklist scans!
    debug 4 "scan: ended all scans in $chan; beginning DNSBL checks"; 
    
    # -- DNSBL checks
    if {[cfg:get dnsbl $chan] && $dnsbl} {
        # -- check if remote scans?
        if {[cfg:get dnsbl:remote $chan]} {
            # -- remote (botnet) dnsbl scan
            if {![islinked [cfg:get bot:remote:dnsbl *]]} { 
                debug 0 "scan: \002(error)\002: remote dnsbl scan bot [cfg:get bot:remote:dnsbl *] is not linked!"
            } else {
                debug 2 "scan: sending remote dnsbl scan to [cfg:get bot:remote:dnsbl *]"
                putbot [cfg:get bot:remote:dnsbl *] "scan:dnsbl $ip $host $nick $ident $host $chan"
            }
        } elseif {![string match "*:*" $ip]} {
            # -- dnsbl checks (if not IPv6)
            # -- TODO: IPv6 handling
            debug 2 "scan: scanning for dnsbl match: $ip (host: $host)"
            # -- get score
            set response [rbl:score $ip]
            set ip [lindex $response 0]
            set response [join $response]
            set score [lindex $response 1]
            if {$ip ne $host} { set dst "$ip ($host)" } else { set dst $ip }
            if {$score > 0} {
                # -- match found!
                set match 1
                set rbl [lindex $response 2]
                set desc [lindex $response 3]
                set info [lindex $response 4]

                if {[join $info] eq "NULL"} { set info "" } else { set info [join $info] }
        
                # -- dnsbl match! ... take action!
                
                # -- white dns list / black?
                set white 0; set black 0;
                if {$score > 0} { set dnslist "black"; set dnsshort "bl"; set black 1 } else { set dnslist "white"; set dnsshort "wl"; set white 1}
                
                debug 1 "scan: dns$dnsshort match found ([runtime $jointime]) for $host: $response"
                debug 2 "scan: ------------------------------------------------------------------------------------"
                
                if {$white} {
                    set mode [list:mode $id]
                    if {$mode ne ""} { putquick "MODE $chan $mode $nick" -next } elseif {$arm(mode) eq "secure"} { voice:give $chan $nick }
                } else {
                    if {$info eq ""} { set xtra "" } else { set xtra " info: $info" }
                    #set string "Armour: DNSBL blacklisted -- (ip: $ip rbl: $rbl desc: $desc${xtra})"
                    set string "Armour: DNSBL blacklisted -- (ip: $ip rbl: $rbl desc: $desc)"
                    # -- truncate reason for X bans
                    if {[string tolower [cfg:get ban $chan]] eq "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
                    kickban $nick $ident $host $chan [cfg:get ban:time $chan] $string
                }
                if {$info eq ""} { set xtra "" } else { set xtra "\002info:\002 $info" }
                report $dnslist $chan "Armour: DNS[string toupper $dnsshort] match found on $nick!$ident@$host (\002ip:\002 $ip \002rbl:\002 $rbl \002desc:\002 $desc)"
                scan:cleanup $nick $chan; # -- cleanup vars
                return;    
            } else {
                # -- no match found
                debug 1 "scan: no dnsbl match found for $host"
            }
        }
        # -- end of local scan
    }
    # -- end of dnsbl  

    debug 3 "scan: ended DNSBL scans in $chan; beginning port scanner"; 
        
    # -- port scanner (if configured, and IP known)
    if {[cfg:get portscan $chan] && $portscan} {
        # -- check if remote scans?
        if {[cfg:get portscan:remote *]} {
            # -- remote (botnet) dnsbl scan
            if {![islinked [cfg:get bot:remote:port *]]} { 
                debug 0 "scan: \002(error)\002: remote port scan bot [cfg:get bot:remote:port *] is not linked!"
            } else {
                debug 1 "scan: sending remote port scan to [cfg:get bot:remote:port *]"
                putbot [cfg:get bot:remote:port *] "scan:port $ip $host $nick $ident $host $chan"
            }
        } else {
            # -- local port scan
            debug 1 "scan: executing port scanner: $ip (host: $host)"

            # -- new additions
            set openports [port:scan $ip]
        
            # -- minimum number of open ports before action
            set min [cfg:get portscan:min $chan]
            set portlist [split $openports " "]
            # -- divide list length by two as each has two args
            set portnum [expr [llength $portlist] / 2]

            # -- not null if any open ports
            if {$openports ne "" && $portnum >= $min} {
                # -- insecure host (install identd) -- take action!
                debug 1 "\002scan: insecure host (host: $host ip: $ip) -- taking action! ([runtime $jointime])\002"
                debug 2 "\002scan: ------------------------------------------------------------------------------------\002"
                set string [cfg:get portscan:reason $chan]
                # -- truncate reason for X bans
                if {[string tolower [cfg:get ban $chan]] eq "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
                kickban $nick $ident $host $chan [cfg:get ban:time $chan] $string
                report black $chan "Armour: $nick!$ident@$host insecure host (\002open ports:\002 $openports \002reason:\002 install identd)"
                scan:cleanup $nick $chan; # -- cleanup vars
                return;
            }
        }; # -- end local port scan
    }; # -- end port scanner

    debug 3 "scan: ended portscanner in $chan"; 

    # -- no matches at all.... 
    # debug 2 "scan: ------------------------------------------------------------------------------------"
    debug 1 "\002scan:\002 \002zero\002 matches (whitelist/dnswl/blacklist/portscan/dnsbl) found against $nuhr (xuser: $xuser) in $chan -- [runtime $jointime]"
    debug 1 "\002scan: ------------------------------------------------------------------------------------\002"
    
    # -- continue for further scans before voicing
    scan:continue $nick $ident $ip $host $xuser $rname $chan
}

proc scan:match {chan ltype id method value ipscan nick ident host ip xuser rname {country ""} {asn ""} {cache ""} {hits ""} {text ""}} {
    variable entries; # -- dict: whitelist and blacklist entries
    set match 0; set hit ""; set todo 0; 
    set res ""; set what "";

    # -- skip if already checked
    if {[dict exists $cache $id]} {
        set match [dict get $cache $id]
    } else {
        # -- actual matching
        while {$match eq 0} {
            set chanmode [get:val chan:mode $chan]
            if {[dict get $entries $id onlysecure] && $chanmode ne "secure"} {
                debug 1 "scan:match: skipping $ltype entry as onlysecure=1 (chan: $chan -- id: $id -- method: $method -- value: $value)"
                break;
            }
            if {[dict get $entries $id notsecure] && $chanmode eq "secure"} {
                debug 1 "scan:match: skipping $ltype entry as notsecure=1 (chan: $chan -- id: $id -- method: $method -- value: $value)"
                break;
            }
            if {[dict get $entries $id disabled]} {
                debug 1 "scan:match: skipping $ltype entry as disabled=1 (chan: $chan -- id: $id -- method: $method -- value: $value)"
                break;
            }
            if {[dict get $entries $id noident] && ![string match "~*" $ident]} {
                debug 1 "scan:match: skipping $ltype entry as noident=1 (chan: $chan -- id: $id -- method: $method -- value: $value -- \002ident:\002 $ident)"
                break;
            }
            debug 5 "scan:match: scanning $ltype entry (chan: $chan -- method: $method -- value: $value)"

            # -- text matches
            if {$method eq "text"} { 
                # -- try regex match
                catch { regexp -- $value $text } err
                if {$err eq 1} {
                    # -- could be a regex
                    if {[regexp -nocase $value $text]} {
                        # -- regex match!
                        debug 0 "scan:match: matched blacklist text (regex): $chan: $chan -- id: $id -- type: $ltype -- value: $value";
                        set match 1
                    }
                } else {
                    # -- must be a wildcard
                    if {[string match -nocase $value $text]} {
                        # -- wildcard string match!
                        debug 0 "scan:match: matched blacklist text (wildcard): $chan: $chan -- id: $id -- type: $ltype -- value: $value";
                        set match 1
                    }
                }                
                break; 
            } elseif {$method eq "user" && $xuser ne "0" && $xuser ne ""} { set what $xuser; set todo 1; } \
            elseif {$method eq "chan" && $ltype eq "white" && [onValidchan $nick $value]} { set match 1; break; } \
            elseif {$method eq "chan" && $ltype eq "black"} { break; } \
            elseif {$method eq "regex" && [regexp $value "$nick!$ident@$host/$rname"]} { set match 1; break; } \
            elseif {$method eq "rname"} { set what $rname; set todo 1; } \
            elseif {$method eq "country" && $ipscan} { if {$country eq ""} { set what [geo:ip2country $ip]; set country $what } else { set what $country }; set todo 1; } \
            elseif {$method eq "asn" && $ipscan} { if {$asn eq ""} { set what [geo:ip2asn $ip]; set asn $what } else { set what $asn }; set todo 1; } \
            elseif {$method eq "host"} {
                # -- hostname (or IP incl. CIDR)
                if {[string match -nocase $value $host]} { set hit "host"; set match 1; set res "$host"; break; }
                # -- check against user@host
                if {[string match -nocase $value "$ident@$host"]} { set hit "user@host"; set match 1; set res "$ident@$host"; break; }
                # -- check against nick!user@host
                if {[string match -nocase $value "$nick!$ident@$host"]} { set hit "nick!user@host"; set match 1; set res "$nick!$ident@$host"; break; }
                # -- IP scans? (only if IP is known and not rfc1918)
                if {$ipscan && !$match} {
                    # -- check against IP
                    if {[string match $value $ip]} { set hit "ip"; set match 1; set res $ip; break; }
                    # -- check IP against CIDR
                    if {[regexp -- {/} $value] && !$match} { 
                        # -- check if CIDR belonged to hostmask
                        if {[regexp -- {@} $value]} {
                            lassign [split $value @] umask block
                            if {[cidr:match $ip $block]} {
                                # -- CIDR block matched, check ident
                                if {[string match -nocase $umask $ident]} { set hit "cidr mask"; set match 1; set res "$ident@$ip"; break; } \
                                elseif {[string match -nocase $umask "$nick!$ident"]} { set hit "cidr mask"; set match 1; set res "$nick!$ident@$ip"; break; }
                            }
                        } elseif {[cidr:match $ip $value]} {
                            set hit "cidr"; set match 1; set res $ip;
                            break;
                        }
                    }; # -- end of CIDR matching
                }; # -- end of IP matching
            }; # -- end of host matching
            if {$method eq "user" && $value eq "*" && $xuser eq "0"} { break; }; # -- only match on '*' for accounts if xuser is actually set 
            if {$method ne "host" && [info exists what]} {
                if {[string match -nocase $value $what]} { set match 1; break; };    # -- matching for all except chan, regex, and host
            }
            if {!$match} { 
                # -- ensure we escape the while loop
                break;
            } 
        }; # -- end while
        if {$match && $id ni $hits} { lappend hits $id }
        dict set cache $id $match; # -- update the cache to avoid rematching
    }; # -- end actual matching

    if {!$match} {
        #debug 0 "\002scan:match:\002 found \002no\002 hit on \002id=\002$id, returning"
        return [list 0 $hit $todo $what $cache $hits $country $asn]
    }

    # -- ID matches, now check dependencies that in turn check their dependencies
    if {[dict exists $entries $id depends]} {
        set depends [dict get $entries $id depends]
        debug 0 "\002scan:match:\002 found \002hit\002 on \002id=\002$id, dependencies=[join $depends ,]"
        foreach dep $depends {
            if {[dict exists $cache $dep]} {
                set match [dict get $cache $dep]
                debug 0 "\002scan:match:\002 found \002cache\002 hit on \002id\002=$id \002dependency=\002$dep (\002match:\002 $match)"
            } else {
                set chan [dict get $entries $dep chan]
                set ltype [dict get $entries $dep type]
                set method [dict get $entries $dep method]
                set value [dict get $entries $dep value]
                lassign [scan:match $chan $ltype $dep $method $value $ipscan $nick $ident $host $ip $xuser $rname $country $asn $cache $hits] match hit todo what cache
            }
            if {!$match} {
                #debug 0 "\002scan:match:\002 found \002no\002 hit on id=$id \002dependency=\002$dep, returning"
                return [list 0 $hit $todo $what $cache $hits $country $asn]
            } else {
                if {$dep ni $hits} { lappend hits $dep }
                debug 0 "\002scan:match:\002 found \002dependent\002 hit on \002id\002=$id \002dependency=\002$dep"
            }
        }
    }
    debug 0 "\002scan:match:\002 found \002hit\002 on \002id=\002$id, returning"
    return [list 1 $hit $todo $what $cache $hits $country $asn]
}

# -- continue further scans before voicing
proc scan:continue {nick ident ip host xuser rname chan} {
    corotrace
    debug 4 "scan:continue: started"
    variable cfg;              # -- configuration settings
    variable entries;          # -- dict: blacklist and whitelist entries    
    variable exempt;           # -- state: tracks whether nick is exempt from scans (by nick)
    variable chan:mode;        # -- the operational mode of the registered channel (by chan)
    variable scan:list;        # -- the list of nicknames to scan in secure mode:
                               #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                               #        nicks,*    :  the nicks being scanned
                               #        who,*      :  the current wholist being constructed
                               #        leave,*    :  those already scanned and left
    variable coroctcp;         # -- stores coroutine when we're waiting for a CTCP VESION reply (by chan,nick)
    variable paranoid;         # -- stores coroutine for the /WHOIS response yield
    variable data:whois;       # -- state: tracking client info for /WHOIS result
    variable data:hostnicks;   # -- holds the nicks on a given host (by host,chan)
    variable data:ipnicks;     # -- holds the nicks on a given IP (by IP,chan)
    variable data:kicknicks;   # -- tracking nicknames recently kicked from chan (by 'chan,nick')

    variable captchasent;     # -- state: where a captcha has already been sent (by chan,nick)
    variable captchaflag;     # -- state: where a captcha flag is enabled for a matched pattern (by chan,nick)

    set integrate 1; set voice 0; set hasscore 0; set end 0;
    set lchan [string tolower $chan]

    # -- helpful debugging to find source of superfluous scans
    if {![info exists scan:list(who,$lchan)]} { set scan:list(who,$lchan) "" } else { debug 4 "scan:continue scan:list(who,$lchan): [get:val scan:list who,$lchan]" }
    if {![info exists scan:list(data,$lchan)]} { set scan:list(data,$lchan) "" } else { debug 4 "scan:continue scan:list(data,$lchan): [get:val scan:list data,$lchan]" }
    if {![info exists scan:list(nicks,$lchan)]} { set scan:list(nicks,$lchan) "" } else { debug 4 "scan:continue scan:list(nicks,$lchan): [get:val scan:list nicks,$lchan]" }
    if {![info exists scan:list(leave,$lchan)]} { set scan:list(leave,$lchan) "" } else { debug 4 "scan:continue scan:list(leave,$lchan): [get:val scan:list leave,$lchan]" }

    if {[get:val chan:mode $lchan] eq "secure"} { set issecure 1 } else { set issecure 0 };        # -- get the operational chanmode
    if {[cfg:get ipqs:onlynoident $chan] && [string match "~*" $ident]} { set ipqs 1 } else { set ipqs 0 }; # -- only do IPQS for clients with ~ in ident?
    
    debug 4 "scan:continue: integrate: $integrate -- issecure: $issecure -- ipqs: $ipqs"

    # -- IP Quality Score (www.ipqualityscore.com) -- fraud check
    if {[cfg:get ipqs $chan] && [ip:isLocal $ip] eq 0 && $ipqs} {     
        lassign [ipqs:query $ip] match isfraud isproxy fraud_score json
        if {$match eq 1} {
            # -- IP is either a proxy of has high fraud rating
            foreach {name object} $json {
                set out($name) $object
            }
            set end 1
            if {$isproxy eq 1 && $isfraud eq 1} {
                set msg "appears to be on a proxy and be fraudulent (score: $out(fraud_score))"
            } elseif {$isproxy eq 1 && $isfraud eq 0} {
                set msg "appears to be on a proxy (score: $out(fraud_score))"
            } elseif {$isproxy eq 0 && $isfraud eq 1} {
                set msg "appears fraudulent (score: $out(fraud_score))"
            }
            set dokick 0; set dokb 1;
            if {$issecure} {
                if {[cfg:get ipqs:action:secure $chan] eq "kick"} {
                    set dokick 1;
                    putquick "NOTICE @$chan :Armour: $nick!$ident@$host $msg -- taking action!"
                } elseif {[cfg:get ipqs:action:secure $chan] eq "kickban"} {
                    putquick "NOTICE @$chan :Armour: $nick!$ident@$host $msg -- taking action!"
                    set dokb 1;
                } elseif {[cfg:get ipqs:action:secure $chan] eq "warn"} {
                    set end 0; # -- only send opnotice, continue other scans
                    putquick "NOTICE @$chan :Armour: $nick!$ident@$host $msg -- however \002not\002 taking action!"
                }
            } else {
                # -- mode must be on
                if {[cfg:get ipqs:action:on $chan] eq "kick"} {
                    set dokick 1; 
                } elseif {[cfg:get ipqs:action:on $chan] eq "kickban"} {
                    set dokb 1;
                } elseif {[cfg:get ipqs:action:on $chan] eq "warn"} {
                    set end 0; # -- only send opnotice, continue other scans
                    putquick "NOTICE @$chan :Armour: $nick!$ident@$host $msg -- however \002not\002 taking action!"
                }           
            }
            
            # -- check whether to kick client
            if {$dokick} {
                lassign [split [cfg:get paranoid:klimit $chan] :] lim secs
                if {![info exists data:kicknicks($chan,$nick)]} {
                    set data:kicknicks($chan,$nick) 1
                    utimer $secs "unset arm::data:kicknicks($chan,$nick)"
                } else {
                    incr data:kicknicks($chan,$nick)
                }
                if {[get:val data:kicknicks $chan,$nick] <= $lim} {
                    # -- ok to kick the user, threshold not met
                    putquick "KICK $chan $nick :Armour: $nick!$ident@$host $msg"
                } else {
                    # -- upgrade the kick to kickban!
                    set dokb 1;
                }
            }
            
            # -- send kickban for client
            if {$dokb} {
                kickban $nick $ident $host $chan [cfg:get ipqs:duration $chan] "Armour: $nick!$ident@$host $msg"
            }
            
        } elseif {$match eq 0} {
            # -- IP reports Ok, continue
            debug 0 "scan:continue: IPQS reports $nick!$ident@$host (ip:$ip) from $chan is OK"
        }
    }

    if {$issecure && $end ne 1} {
        debug 1 "scan:continue: mode:secure"

        # -- get the signon & idle time from remote /whois
        set paranoid(coro,$nick) [info coroutine]
        debug 2 "scan:continue: sending local /WHOIS lookup on $nick (for signon and idle)"
        set data:whois(bot,$nick) 0
        set data:whois(chan,$nick) $chan
        putquick "WHOIS $nick $nick"
        set result [yield]; # -- yield the result
        
        debug 1 "scan:continue: result yielded"

        lassign [join $result] idle signon
        set signago [expr [clock seconds] - $signon]

        # -- count clients on this host
        if {![info exists data:hostnicks($host,$lchan)]} { set data:hostnicks($host,$lchan) [join $nick]; set hostcount 1 } \
        else { set hostcount [llength [get:val data:hostnicks $host,$lchan]] }
        # -- count clients on this IP
        if {![info exists data:ipnicks($ip,$lchan)]} { set data:ipnicks($ip,$lchan) [join $nick]; set ipcount 1 } \
        else { set ipcount [llength [get:val data:ipnicks $ip,$lchan]] }
 
        debug 4 "scan:continue: result nick: $nick -- idle: $idle -- signon: $signon -- signago: $signago -- hostnicks: $hostcount -- ipcount: $ipcount"
        debug 4 "scan:continue: data:hostnicks($host,$lchan): [get:val data:hostnicks $host,$lchan]"
        debug 4 "scan:continue: data:ipnicks($ip,$lchan): [get:val data:ipnicks $ip,$lchan]"

        set manual 1; set voice 0; set integrate 0; set version 0; set text "paranoid"; # -- set some defaults

        # -- check trakka database (if plugin loaded)
        set score 0
        if {[info command trakka:score] ne ""} {
            # -- calculate score
            set score [trakka:score $nick "$ident@$host" $xuser]
            debug 1 "scan:continue: total trakka score for $nick!$ident@$host is: $score"
        }
        
        if {$score > 0} { set voice 1 }; # -- nick has a score, voice

        # -- check for: new server connections (ie. connection in last 30 secs)
        if {$signago < [cfg:get paranoid:signon $chan] && $score eq 0} {
            debug 0 "scan:continue: no score & freshly connected client joined $chan (signago: $signago) -- \002floodbot?\002"
            set text "recent signon"
            set integrate 1;  # -- send to integration proc (ie. trakka)
        }
        
        # -- check for clones based on IP/host (ie. 2 or more)
        # -- ensure: IP clones for umode +x clients and services aren't counted
        set pclone [cfg:get paranoid:clone $chan]
        if {($hostcount >= $pclone || $ipcount >= $pclone) && $ip ne "127.0.0.1" && $ip ne "0::" && $score eq 0} {
            # -- express the highest
            if {$hostcount >= $ipcount} {
                set text "clone count: $hostcount hosts"
            } else {
                set text "clone count: $ipcount ips"
            }
            # TODO: configurable response to clones
            set integrate 1;  # -- send to integration proc (ie. trakka)
            debug 4 "scan:continue: hostcount: $hostcount -- ipcount: $ipcount"
        }
                
        # -- send CTCP VERSION
        if {![info exists captchaflag($chan,$nick)]} { set captchaflag($chan,$nick) 0 }; # -- tracks whether captcha flag is set for matching pattern
        if {[cfg:get paranoid:ctcp $chan] && $captchaflag($chan,$nick) eq 0} {
            set coroctcp($chan,$nick) [info coroutine];  # -- track that we're waiting for a reply
            putquick "PRIVMSG $nick :\001VERSION\001";   # -- send the version
            utimer [cfg:get paranoid:ctcp:wait $chan] [list arm::scan:ctcp:check $nick $ident $host $chan]
            set version [yield]; # -- wait for the outcome of the VERSION
            debug 1 "scan:continue: VERSION yielded"
        }
        if {$version} { set voice 1; }; # -- voice user if VERSION reply received
        
        # -- send CAPTCHA -- if not voicing yet and captcha not already sent (via list entry flag)
        if {![info exists captchasent($chan,$nick)]} { set captchasent($chan,$nick) 0 }; # -- tracks whether captcha was alreadys ent
        if {!$voice && $captchasent($chan,$nick) eq 0} {
            set manual [captcha:scan $nick "$ident@$host" $chan]; # -- returns whether manual handling required (due to error)
            set text "CAPTCHA request error"
        }
        
        # -- send OPNOTICE if set to manual and not voicing, and if CAPTCHA not already sent (via list entry flag)
        if {($manual && !$voice) && $captchasent($chan,$nick) eq 0} {
            debug 0 "scan: \002waiting manual action\002 in \002$chan\002 for \002$nick\002 ($ident@$host) -- $text"
            reply notc @$chan "Armour: $nick!$ident@$host waiting manual action (\002$text\002) -- \002/whois $nick\002"
        }
        
    } elseif {$end ne 1} {
        # -- mode secure not on
        # -- whois lookups (for badchan)

        debug 4 "scan:continue secure mode not on"
        
        # -- there can only be one unique combination of this expression
        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {[dict get $dictData chan] eq $chan && [dict get $dictData type] eq "black" \
                && [dict get $dictData method] eq "chan"}
        }]]
        
        # -- only if we have at least one channel entry
        if {[cfg:get whois $chan] && $ids ne ""} {
            if {[cfg:get whois:remote $chan]} {
                # -- remote (botnet) /whois
                if {![islinked [cfg:get bot:remote:whois *]]} { 
                    debug 0 "scan:continue: \002(error)\002: remote /WHOIS scan bot [cfg:get bot:remote:whois *] is not linked!"
                } else {
                    debug 2 "scan:continue: sending remote /WHOIS chan lookup to [cfg:get bot:remote:whois *] on [join $nick]"
                    putbot [cfg:get bot:remote:whois *] "scan:whois $nick $chan"
                }
            } else {
                # -- do local lookup
                # -- TODO: don't do this if we already have recent channel data for nick (ie. avoid second /WHOIS)
                debug 2 "scan:continue: sending local /WHOIS chan lookup on [join $nick]"
                set data:whois(bot,$nick) 0
                set data:whois(chan,$nick) $chan
                putserv "WHOIS [join $nick]"
            }
        }
        # -- end of /whois
    }

    debug 3 "scan:continue: \002ending!\002 (integrate: $integrate)"
    if {$integrate} {
        # -- pass join arguments to other scripts (ie. captcha), if configured 
        integrate $nick "$ident@$host" [nick2hand $nick] $chan 0
    }
    
    if {$voice} {
        # -- voice the client, provided they're not voiced by now
        if {![isvoice $nick $chan]} { 
            debug 1 "scan:continue: \002giving voice to $nick on $chan!\002"; 
            voice:give $chan $nick 
        }
        set leave ""
    } else {
        # -- maintain a list so we don't scan this client again
        debug 3 "\002scan:continue:\002 adding $nick to scan:list(leave,$lchan)"
        set leave "leave"
    }
    
    scan:cleanup $nick $chan $leave; # -- remove tracking data arrays
    debug 1 "\002scan:continue: ------------------------------------------------------------------------------------\002"
}


proc pubm:scan {nick uhost hand chan text} {
    pubm:scan:process $nick $uhost $hand $chan $text
}

proc scan:action { nick uhost hand dest keyword text } { 
    # -- only process channel actions 
    if {[string index $dest 0] != "#"} { return; }
    pubm:scan:process $nick $uhost $hand $dest $text
}

# -- scanner for 'text' type blacklist entries
# -- public chatter matching using standard wildcard or regex entries
proc pubm:scan:process {nick uhost hand chan text} {
    set start [clock clicks]
    global botnick
    variable cfg;           # -- config variables
   
    variable nick:override; # -- state: tracks that a nick has a manual exemption in place (by chan,nick)
    variable nick:newjoin;  # -- state: tracks that a nick has recently joined a channel (by chan,nick)    
    variable flood:line;    # -- array to track the lineflood count (by nick,chan)
    variable flood:text;    # -- array to track the lines for a text pattern (by nick,chan,pattern)
    variable entries;       # -- dict: blacklist and whitelist entries
    variable nickdata;
        
    if {$nick eq $botnick} { return; };  # -- ignore text from bot 
    lassign [db:get id,chan channels chan $chan] cid chan; # -- get ID and fix chan case
    if {$cid eq ""} { return; }; # -- only run on registered channels
    
    set nick [split $nick]; # -- make nick safe for arrays
    set lnick [string tolower $nick]
    if {[dict exists $nickdata $lnick ip]} { set ip [dict get $nickdata $lnick ip] } else { set ip "" }
    if {[dict exists $nickdata $lnick account]} { set xuser [dict get $nickdata $lnick account]} else { set xuser "" }
    if {[dict exists $nickdata $lnick rname]} { set rname [dict get $nickdata $lnick rname]} else { set rname "" }
    set lchan [string tolower $chan]
    lassign [split $uhost @] ident host    
    set exempt(type:text) 0; set exempt(type:lines) 0; set exempt($nick) 0;
    
    # -- check if nick joined recently (newcomer)
    if {[get:val nick:newjoin $chan,$nick] ne ""} { set newcomer 1 } else { set newcomer 0 };

    # -- exempt if overridden from 'exempt' command
    if {[userdb:isLogin $nick]} {
        debug 6 "pubm:scan: chan: $chan -- authenticated user exempted from channel text and lineflood matching ([join $nick]!$uhost)"
        set exempt(type:text) 1; set exempt($nick) 1;
    }
    
    # -- exempt if overridden from 'exempt' command
    if {[info exists nick:override($lchan,$nick)]} {
        debug 6 "pubm:scan: chan: $chan -- client manually exempted from channel text and lineflood matching ([join $nick]!$uhost)"
        set exempt(type:text) 1; set exempt($nick) 1;
    }
    
    # -- exempt if opped
    if {[isop $nick $chan] && [cfg:get text:exempt:op $chan]} {
        debug 6 "pubm:scan: chan: $chan -- opped nick exempted from channel text matching ([join $nick]!$uhost)"
        set exempt(type:text) 1; set exempt($nick) 1;
    }

    # -- exempt if voiced
    if {[isvoice $nick $chan] && [cfg:get text:exempt:voice $chan]} {
        debug 6 "pubm:scan: chan: $chan -- voiced nick exempted from channel text matching ([join $nick]!$uhost)"
        set exempt(type:text) 1; set exempt($nick) 1;
    }
    
    # -- exempt if opped
    if {[isop $nick $chan] && [cfg:get flood:line:exempt:op $chan]} {
        debug 6 "pubm:scan: chan: $chan -- opped nick exempted from channel lineflood matching ([join $nick]!$uhost)"
        set exempt(type:lines) 1; set exempt($nick) 1;
    }

    # -- exempt if voiced
    if {[isvoice $nick $chan] && [cfg:get flood:line:exempt:voice $chan]} {
        debug 6 "pubm:scan: chan: $chan -- voiced nick exempted from channel lineflood matching ([join $nick]!$uhost)"
        set exempt(type:lines) 1
    }
    
    # -- exempt if nick has newly joined
    if {[cfg:get flood:line:newcomer $chan] && $newcomer} {
        debug 6 "pubm:scan: chan: $chan -- newcomer nick exempted from channel lineflood matching ([join $nick]!$uhost)"
        set exempt(type:lines) 1
    }   
    
    # -- line flood counters -- for the nickname
    set linehit(nick) 0; set linehit(chan) 0; set action(lines) 0
    # -- only continue if not already exempt for lineflood matching
    if {!$exempt(type:lines)} {
        set floodlinenicks [cfg:get flood:line:nicks $chan] 
        if {$floodlinenicks ne ""} {
            # -- line flood tracking for nicknames is enabled
            if {![regexp -- {^\d+:\d+$} $floodlinenicks]} {
                debug 0 "pubm:scan: \002(error)\002 invalid value for config setting cfg(flood:line:nicks)"
            } else {
                # -- config value is good
                set llines [lindex [split $floodlinenicks :] 0]
                set lsecs [lindex [split $floodlinenicks :] 1]
                if {[info exists flood:line($nick,$lchan)]} {
                    incr flood:line($nick,$lchan)
                } else {
                    set flood:line($nick,$lchan) 1
                }
                if {[get:val flood:line $nick,$lchan] >= $llines} {
                    # -- hit!
                    set linehit(nick) 1; set action(lines) 1
                    debug 1 "pubm:scan: lineflood hit! match on [get:val flood:line $nick,$chan] lines (nick: [join $nick]!$uhost)"
                }
                utimer $lsecs "arm::flood:line:decr [split $nick,$lchan]";  # -- decrease the counter by 1 x line
            }
        }

        # -- line flood counters -- for the channel
        set floodlinechan [cfg:get flood:line:chan $chan]
        if {$floodlinechan ne ""} {
            # -- line flood tracking for nicknames is enabled
            if {![regexp -- {^\d+:\d+$} $floodlinechan]} {
                debug 0 "pubm:scan: \002(error)\002 invalid value for config setting cfg(flood:line:chan)"
            } else {
                # -- config value is good
                set llines [lindex [split $floodlinechan :] 0]
                set lsecs [lindex [split $floodlinechan :] 1]
                if {[info exists flood:line($lchan)]} {
                    incr flood:line($lchan)
                } else {
                    set flood:line($lchan) 1
                }
                if {[get:val flood:line $chan] >= $llines} {
                    # -- hit!
                    set linehit(chan) 1; set action(lines) 1
                    debug 1 "pubm:scan: lineflood hit! match on [get:val flood:line $chan] lines (chan: [join $chan])"
                }
                utimer $lsecs "arm::flood:line:decr [split $lchan]";  # -- decrease the counter by 1 x line
            }
        }
    }
    # -- end of lineflood exemption
    
    # -- begin textflood matching
    set action(text) 0; set hit(text) 0
    if {!$exempt(type:text)} {
                # -- find all the text type blacklist entry IDs
        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {([dict get $dictData chan] eq $chan || [dict get $dictData chan] eq "*") && [dict get $dictData type] eq "black" \
                && [dict get $dictData method] eq "text"}
        }]]
        
        # -- match the actual text against all entries
        foreach id $ids {
            set value [dict get $entries $id value]
            # -- try wildcard first
            if {[string match -nocase $value $text]} {
                # -- wildcard hit!
                set hit(text) 1
                debug 1 "pubm:scan: wildcard hit! list value (id: $id) of $value (nick: [join $nick] -- text: $text)"
                break;
            } else {
                # -- try regex match
                catch { regexp -nocase -- $value $text } err
                if {$err eq 1} {
                    # -- regex hit!
                    set hit(text) 1
                    debug 1 "pubm:scan: list value (id: $id) hit! match of value: $value (nick: [join $nick] -- text: $text)"
                    break;
                } elseif {$err eq 0} {
                    # -- error; probably just a wildcard
                    #debug 0 "pubm:scan: \002(error)\002 regexp parse err: $err"
                }
            }
        }
        
        if {$hit(text)} {
            # -- match: blacklist entry, take action!
            hits:incr $id; # -- track the hitcount
            set limit [dict get $entries $id limit]
            if {$limit ne "1:1:1" && $limit ne ""} { 
                # -- check cumulative count
                
                # -- set or increase existing counter
                if {![info exists flood:text($nick,$lchan,$value)]} {
                    set flood:text($nick,$lchan,$value) 1
                } else { incr flood:text($nick,$lchan,$value) }
                
                set extlimit [split $limit ":"]
                lassign $extlimit matches secs hold
                
                if {[get:val flood:text $nick,$lchan,$value] >= $matches} {
                    # -- cumulative match threshold reached!
                    set action(text) 1
                    # -- extend timer by secs
                } else {
                    if {[get:val flood:text $nick,$lchan,$value] eq 1} {
                        # -- check if we need to warn them
                        if {[cfg:get text:warn $chan]} {
                            # -- send a warning
                            if {[cfg:get text:warn:type $chan] eq "notc"} {
                                # -- send via /notice
                                reply notc [join $nick] "[cfg:get text:warn:msg $chan] \[id: $id\]"
                            } elseif {[cfg:get text:warn:type $chan] eq "chan"} {
                                # -- send to public chan
                                reply msg $chan "[join $nick]: [cfg:get text:warn:msg $chan] \[id: $id\]"
                            } else {
                                debug 0 "pubm:scan: \002(error)\002 invalid value for config setting cfg(text:warn:type)"
                            }
                            set report [cfg:get text:warn:report $chan]
                            regsub -all {%N%} $report [join $nick] report
                            regsub -all {%I%} $report $id report
                            regsub -all {%C%} $report $chan report
                            report text $chan $report; # -- send report (to ops and/or debug chan)
                        }
                    }
                    # -- set timer to unset after secs
                    set thevar "$nick,$lchan,$value"
                    utimer $secs "arm::flood:text:unset [split $thevar]"
                }
            } else { set action(text) 1 }; # -- this is a hit because it's a single 1:1 match
        }; # -- end of text hit
    }
    # -- end of textflood exemption

    # -- do we add an automatic blacklist entry?
    if {([cfg:get text:autoblack $chan] || [cfg:get flood:line:autoblack $chan]) && ($action(text) || $action(lines))} {
        # -- add the entry!
        if {[regexp -- [cfg:get xregex *] $host -> xuser]} {
            # -- user is umode +x
            set ttype "xuser"
            set entry $xuser
        } else {
            # -- normal host entry
            set ttype "host"
            set entry $host
        }
        # -- there can only be one unique combination of this expression
        set id [lindex [dict filter $entries script {id dictData} {
            expr {[dict get $dictData type] eq "black" && ([dict get $dictData chan] eq $chan || [dict get $dictData chan] eq "*") \
                && [dict get $dictData method] eq $ttype && [dict get $dictData value] eq $entry}
        }] 0]
        if {$id eq ""} {
            # -- add automatic blacklist entry
            if {$action(text)} {
                set reason [cfg:get text:autoblack:reason $chan]
            } else {
                set reason [cfg:get flood:line:autoblack:reason $chan]
            }

            debug 1 "\002pubm:scan: adding auto blacklist entry: type: B -- chan: $chan -- method: $ttype -- value: $entry -- modifby: $modifby -- action: B -- reason: $reason\002"

            # -- add the list entry (we don't need the id)
            set tid [db:add B $chan $method $value $modifby $action "" $reason]
        }
    }
    
    # -- take action!
    if {$action(text)} {
        set reason [dict get $entries $id reason]
        set runtime [runtime $start]
        debug 1 "\002pubm:scan: blacklist matched [join $nick]!$uhost: chan: $chan -- type: text -- id: $id -- $value -- taking action! ($runtime)\002"
        debug 2 "\002pubm:scan: ------------------------------------------------------------------------------------\002"
        set string "Armour: blacklisted"
        if {[cfg:get black:kick:value $chan]} { append string " -- $value" }
        if {[cfg:get black:kick:reason $chan]} { append string " (reason: $reason)" }
        set string "$string \[id: $id\]";
        # -- truncate reason for X bans
        if {[string tolower [cfg:get ban $chan]] eq "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
        kickban [join $nick] $ident $host $chan [cfg:get ban:time $chan] "$string" $id
        #report black $chan "Armour: blacklisted text (\002id:\002 $id \002type:\002 text \002value:\002 $value \002reason:\002 $reason)"
        report black $chan $string
        hits:incr $id; # -- incr statistics
        return;
    } elseif {$hit(text)} {
        # -- cumulative match not yet reached
        set runtime [runtime $start]
        debug 1 "pubm:scan: cumulative match (current: [get:val flood:text $nick,$lchan,$value]) not yet found (required: $matches)! (runtime: $runtime -- nick: [join $nick] -- text: $text)"
    }
    
    set ishit 0
    # -- line flood matching.
    # -- we do these separately to focus on individual floods first
    if {$linehit(chan)} {
        # -- channel reached line threshold
        if {[cfg:get flood:line:chan:mode $chan] ne ""} {
            # -- temporarily lockdown channel
            putnow "MODE $chan [cfg:get flood:line:chan:mode $chan]"
            reply notc "@$chan" "Armour: line flood detected -- temporarily locking channel for [cfg:get flood:line:chan:lock $chan] secs (exceeded $llines lines in $lsecs secs)"
            # -- remove the lock after the configured timer
            utimer [cfg:get flood:line:chan:lock $chan] "arm::flood:line:unmode $chan"
            set ishit 1
        }
    }
    if {$linehit(nick)} {
        # -- nickname reached line threshold
        kickban [join $nick] $ident $host $chan [cfg:get ban:time $chan] [cfg:get flood:line:reason $chan] $id
        set ishit 1
    }
    
    if {!$ishit} {
        # -- check for 'text' type entries
        #debug 4 "pubm:scan: beginning text list entries matching in $chan"; 
        # -- this isn't very efficient if we want to support regex entries too, but at lest it's only looking at 'text' entries
        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {([dict get $dictData chan] eq $chan || [dict get $dictData chan] eq "*") && [dict get $dictData method] eq "text"}
        }]]
        # -- split off the whitelists and blacklists from each other so they can be processed appropriately
        set whites [list]
        set blacks [list]
        foreach id $ids {
            set ltype [dict get $entries $id type]
            if {$ltype eq "black"} { lappend blacks $id } elseif {$ltype eq "white"} { lappend whites $id }
        }
        
        #debug 4 "pubm:scan: blacks: $blacks";
        #debug 4 "pubm:scan: whites: $whites";
        
        # -- blacklists first
        set cache ""; set ipscan 1; set hits "";
        foreach id "$blacks $whites" {
            set chan [dict get $entries $id chan]
            set ltype [dict get $entries $id type]
            if {$ltype eq "black" && $exempt($nick)} { continue; }; # -- blacklist exempt
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            debug 4 "pubm:scan: looping blacklist text entry: chan: $chan -- id: $id -- type: $ltype -- value: $value";
            set ishit 0;

            # -- check match, recursively
            lassign [scan:match $chan $ltype $id $method $value $ipscan $nick $ident $host $ip $xuser $rname "" "" $cache $hits $text] \
                ishit hitdesc todo what cache hits

            # -- build a comma separated list of 'effective' IDs after following all dependent list entries
            #if {[info exists cache]} {
            #    if {$cache eq ""} { set depids $id } else { set depids [join [dict keys $cache] ,] }
            #} else { set depids $id }
            if {$hits eq 0} { set depids $id } else { set depids [join $hits ,] }; # -- list of IDs that were matched

            if {$ishit} {
                foreach i $depids {
                    hits:incr $id; # -- incr statistics, for each effective ID
                }
                if {$ltype eq "black"} {
                    # -- take action!
                    set reason [dict get $entries $id reason]; # -- reason from first hit
                    set string "Armour: blacklisted"
                    if {[cfg:get black:kick:value $chan]} { append string " -- $value" }
                    if {[cfg:get black:kick:reason $chan]} { append string " (reason: $reason)" }
                    set string "$string \[id: $depids\]";
                    # -- truncate reason for X bans
                    if {[string tolower [cfg:get ban $chan]] eq "x" && [string length $string] >= 124} { set string "[string range $string 0 124]..." }
                    kickban $nick $ident $host $chan [cfg:get ban:time $chan] $string $id
                    return;
                } elseif {$ltype eq "white"} {
                    # -- respond!
                    set reason [dict get $entries $id reason]
                    reply msg $chan $reason; # -- TODO: how do people find the entry responsible (without being verbose), if they want to modify or delete it?
                                             # -- for now, just rely on 'search' command; later, web interface will help
                    #return; # -- don't halt on one match, in case the bot needs to speak more lines :>
                }
            }
        }    
    }
    debug 6 "\002pubm:scan: ------------------------------------------------------------------------------------\002"
}

# -- respond if the CTCP VERSION reply has not yet been received
proc scan:ctcp:check {nick ident host chan} {
    variable cfg;
    variable coroctcp; # -- stores coroutine for yield we're waiting for a CTCP VESION reply (by chan,nick)
    debug 4 "\002scan:ctcp:check:\002 started"
    if {[info exists coroctcp($chan,$nick)]} {
        debug 4 "\002scan:ctcp:check:\002 coroctcp exists"
        # -- we're waiting for a CTCP VERSION reply from this nick in this chan
        if {[cfg:get paranoid:ctcp:action $chan] eq "kick"} {
            set txt "kicked client!"
            putquick "KICK $chan $nick :[cfg:get paranoid:ctcp:kickmsg $chan]"
            reply notc @$chan "Armour: $nick!$ident@$host removed from channel -- no CTCP VERSION reply received."
        } elseif {[cfg:get paranoid:ctcp:action $chan] eq "kickban"} {
            set txt "kickbanned client!"
            kickban $nick $ident $host $chan [cfg:get ban:time $chan] [cfg:get paranoid:ctcp:kickmsg $chan]
        } elseif {[cfg:get paranoid:ctcp:action $chan] eq "manual"} {
            set txt "awaiting manual action!"
            reply notc @$chan "Armour: $nick!$ident@$host waiting manual action (\002VERSION reply not received\002) -- \002/whois $nick\002"
        } elseif {[cfg:get paranoid:ctcp:action $chan] eq "captcha"} {
            set txt "awaiting CAPTCHA response!"
            if {[cfg:get captcha:opnotc $chan]} {
                # -- only send notice if configured to
                reply notc @$chan "Armour: $nick!$ident@$host sent CAPTCHA (\002VERSION reply not received\002) -- \002/whois $nick\002"
            }
        } else {
            set txt "\002no valid cfg(paranoid:ctcp:action) value\002"
        }
        debug 2 "scan:ctcp:check: not received a CTCP VERSION reply from $nick in $chan -- $txt"
        $coroctcp($chan,$nick) 0; # -- return "0" to continue with manual handling
        unset coroctcp($chan,$nick)
    }
    debug 4 "\002scan:ctcp:check:\002 ended"
}

proc ctcp:version:reply {nick uhost hand dest keyword text} {
    variable cfg;
    variable coroctcp; # -- stores coroutine for yield we're waiting for a CTCP VESION reply (by chan,nick)
    #putlog "\002ctcp:version:reply:\002 dest: $dest -- keyword: $keyword"
    if {$keyword ne "VERSION"} { return; }
    foreach t [utimers] {
        lassign $t secs proc timerid id
        #putlog "\002ctcp:version:reply:\002 timer t: $t secs: $secs proc: $proc: timerid: $timerid: id: $id"
        if {[lindex $proc 0] eq "arm::scan:ctcp:check"} {
            lassign $proc proc nick ident host chan
            #putlog "\002ctcp:version:reply:\002 timer proc: $proc nick: $nick chan: $chan"
            if {[info exists coroctcp($chan,$nick)]} {
                # -- we're waiting for a CTCP VERSION reply from this nick in this chan
                debug 2 "ctcp:version:reply: received CTCP VERSION reply from $nick in $chan -- cancelling timer"
                killutimer $timerid
                $coroctcp($chan,$nick) 1; # -- return "1" to give voice (coroutine yield)
                unset coroctcp($chan,$nick)
            }
        } 
    }
}


debug 0 "\[@\] Armour: loaded scanner."

}
# -- end namespace

# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-15_floodnet.tcl
#
# dynamic floodnet detection
# 
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


proc check:floodnet {nick uhost hand chan {xuser ""} {rname ""}} {
    global botnick time
    
    variable cfg
    variable entries;        # -- dict: blacklist and whitelist entries 
    
    variable flud:id;        # -- the id of a given cumulative pattern (by chan,method,value)
    variable flud:count;     # -- the count of a given cumulative pattern (by id)
    variable flud:nickcount; # -- the IDs that have already been matched for a given nick (by chan,nick)
                             # -- avoids double matching (first from channel join, second from /WHO result)
    
    variable floodnet;       # -- tracking active floodnet (by chan)
    variable chanlock;       # -- tracking active channel lock (by chan)    
    variable kreason;        # -- expose kick reasons for cumulative patterns (by chan,nick)
    variable data:setx;      # -- state: tracks a recent umode +x user (by nick)
    
    variable adapt:n;        # -- array to track the count of hits on a nick regex pattern (by regex)
    variable adapt:ni;       # -- array to track the count of hits on a nick!ident regex pattern (by regex)
    variable adapt:nir;      # -- array to track the count of hits on a nick!ident/rname regex pattern (by regex)
    variable adapt:ni;       # -- array to track the count of hits on a nick!ident regex pattern (by regex)
    variable adapt:i;        # -- array to track the count of hits on a ident regex pattern (by regex)
    variable adapt:ir;       # -- array to track the count of hits on a ident/rname regex pattern (by regex)
    variable adapt:nr;       # -- array to track the count of hits on a nick/rname regex pattern (by regex)
    
    variable data:banmask;   # -- tracking banmasks banned recently by a blacklist (by id)
    variable data:kicks;     # -- stores queue of nicks to kick from a channel (by chan)
    variable data:bans;      # -- stores queue of masks to ban from a channel (by chan)
    variable data:chanban;   # -- state: tracks recently banned masks for a channel (by 'chan,mask')    
    variable data:hostnicks; # -- track nicknames on a host (by host,chan)
    
    variable nick:newjoin;   # -- stores uhost for nicks that have recently joined a channel (by chan,nick)
    variable jointime:nick;  # -- stores the nick that joined a channel (by chan,timestamp)
    variable nick:jointime;  # -- stores the timestamp a nick joined a channel (by chan,nick)
    
    set ident [lindex [split $uhost @] 0]
    set host [lindex [split $uhost @] 1]
    set lchan [string tolower $chan]
    set snick [split [join $nick]]; # -- join first as this proc gets nicknames sent in two ways
        
    debug 3 "check:floodnet: received: nick: [join $nick] -- ident: $ident -- host: $host -- hand: $hand -- chan: $chan -- xuser: $xuser -- rname: $rname"
    
    if {![info exists data:hostnicks($host,$lchan)]} { set data:hostnicks($host,$lchan) $nick }

    # -- check if called from JOIN or WHO result
    # -- ensure processing doesn't occur twice for the same nick, for the same join
    if {$xuser eq "" && $rname eq ""} {
        # -- called from a channel JOIN
        debug 0 "\002check:floodnet: called from JOIN\002"
        set whoscan 0
        if {[info exists flud:nickcount($chan,$snick)]} { 
            unset flud:nickcount($chan,$snick)
        }
    } else {
        # -- called from a WHO result after a channel JOIN
        debug 0 "\002check:floodnet: called from WHO\002"
        set whoscan 1
    }
    
    set tslist ""
    # -- tslist containing timestamps, ordered by time they joined
    foreach val [array names nick:jointime $lchan,*] {
        lappend tslist [get:val nick:jointime $val]
    }
    set tslist [lsort -increasing $tslist]
    
    # -- produce a list of nicks in chronological order by jointime
    set joinlist ""
    foreach ts $tslist {
        lappend joinlist [get:val jointime:nick $lchan,$ts]
    }
    set joinlist [join $joinlist]
    
    debug 3 "check:floodnet: re-ordered newcomer (newjoin) list by jointime: [join $joinlist]"
    
    # -- do some basic nick!ident checks against adapt regex, prior to /WHO
    # -- we want this to be a fast way to match floodnet joins
    # -- ie. do these first without waiting for a response with realname
    
    # -- join flood rate
    set adaptrate [cfg:get adapt:rate $chan]
    set joins [lindex [split $adaptrate :] 0]
    set secs [lindex [split $adaptrate :] 1]
    set retain [lindex [split $adaptrate :] 2]
    
    # -- build types for join if 'xuser' is not set (send after /who from scan)
    if {$xuser eq ""} {
        # ---- adaptive regex types
        # -- match nickname, and ident
        set prefix "join"
        debug 4 "check:floodnet: running floodnet detection against $nick after /join"
        set types [cfg:get adapt:types:join $chan]
    } else {
        # -- send from scan after /who
        # -- can include rname
        set prefix "who"
        debug 4 "check:floodnet: running floodnet detection against $nick from scan after /who"
        set types [cfg:get adapt:types:who $chan]
    }
    
    set mode [get:val chan:mode $chan]; # -- get operational channel mode
    
    # -- if mode is 'secure', combine /join and /who match types (as we didn't see the /join because of chanmode +D)
    if {$mode eq "secure"} { set types "[cfg:get adapt:types:join $chan] [cfg:get adapt:types:who $chan]" }
       
    # -- build adaptive regex's;  only build what is required
    if {"n" in $types} { set nregex  [split "^[join [regex:adapt "$nick"]]$"] };                  # -- nickname
    if {"i" in $types} { set iregex [split "^[join [regex:adapt "$ident"]]$"] };                  # -- ident
    if {"ni" in $types} { set niregex [split "^[join [regex:adapt "$nick!$ident"]]$"] };          # -- nick!ident
    if {"nir" in $types} { set nirregex [split "^[join [regex:adapt "$nick!$ident/$rname"]]$"] }; # -- nick!ident/rname
    if {"ir" in $types} { set irregex [split "^[join [regex:adapt "$ident/$rname"]]$"] };         # -- ident!rname
    if {"r" in $types} { set rregex [split "^[join [regex:adapt "$rname"]]$"] };                  # -- realname
    if {"nr" in $types} { set nrregex [split "^[join [regex:adapt "$nick/$rname"]]$"] };          # -- nick/rname        
    
    # -- use hit var to stop unnecessary looping if client already got hit
    set hit 0; set complete 0; set processed 1
    
    # -- kicklist & banlist
    set klist ""; set blist ""
    
    # ---- ADAPTIVE DETECTION
    # -- (automatic regex generation)
    set clength [llength $types]
            
    foreach type $types {
        switch -- $type {
            n   { set array "adapt:n"; set exp $nregex     }
            ni  { set array "adapt:ni"; set exp $niregex   }
            nir { set array "adapt:nir"; set exp $nirregex }
            nr  { set array "adapt:nr"; set exp $nrregex   }
            i   { set array "adapt:i"; set exp $iregex     }
            ir  { set array "adapt:ir"; set exp $irregex   }
            r   { set array "adapt:r"; set exp $rregex     }
        }
        
        # -- get longtype string from ltypes array
        set ltype [get:val adapt:ltypes $type]
        
        debug 4 "check:floodnet: (adaptive -- $prefix) looping: type: $type ltype: $ltype exp: [join $exp]"
        
        # -- setup array?
        
        if {!$hit} {
    
            debug 4 "check:floodnet: (adaptive -- $prefix) checking array: [subst $array]([join $exp])"
            
            if {![info exists [subst $array]($exp)]} {
                # -- no counter being tracked for this nickname pattern
                set [subst $array]($exp) 1
                debug 3 "check:floodnet: (adaptive -- $prefix) no existing track counter: unsetting track array for $ltype pattern in $secs secs: [join $exp]"
                utimer $secs "arm::adapt:unset $ltype [split $exp]"
            } else {
                # -- existing counter being tracked for this nickname pattern
                debug 2 "check:floodnet: (adaptive -- $prefix) existing track counter: increasing for $ltype pattern: [join $exp]"
                incr [subst $array]($exp)
            
                upvar 0 $array value
                set count [subst $value($exp)]
                debug 4 "check:floodnet: count: $count -- joins: $joins"
    
                if {$count >= $joins} {
                    # -- flood join limit reached! -- take action
                    debug 1 "\002check:floodnet: (adaptive -- $prefix) adaptive ($ltype) regex joinflood detected: $nick!$uhost\002"
                    # -- store the active floodnet
                    set floodnet($chan) 1
                    
                    set matched 1
                        
                    # -- hold pattern for longer after initial join rate hit
                    set secs $retain
                        
                    # -- we need a way of finding the previous nicknames on this pattern...              
                    set klist ""; set blist ""
                    debug 3 "check:floodnet: (adaptive -- $prefix) newcomer joinlist: $joinlist"
                    foreach newuser $joinlist {
                        set newjoinuh [get:val nick:newjoin $chan,$newuser]
                        if {$newjoinuh eq ""} {
                            set uh [getchanhost $newuser $chan]
                            set nick:newjoin($newuser) $uh
                        } else {
                            set uh $newjoinuh
                        }
                        set i [lindex [split $uh @] 0]
                        set h [lindex [split $uh @] 1]
                        switch -- $type {
                            n   { set match "$newuser"           }
                            i   { set match "$i"                 }
                            ni  { set match "$newuser!$i"        }
                            nir { set match "$newuser!$i/$rname" }
                            ir  { set match "$i/$rname"          }
                            r   { set match "$rname"             }
                            nr  { set match "$newuser/$rname"    }
                        }
                        debug 4 "check:floodnet: (adaptive -- $prefix) attempting to find pre-record matches: type: $type match: $match exp: [join $exp]"
                        if {[regexp -- [join $exp] $match]} {
                            debug 3 "check:floodnet: (adaptive -- $prefix) pre-record regex match: [join $exp] against string: $match"
                            # -- only include the pre-record users
                            # -- add this nick at the end
                            if {$newuser == $nick} { continue; }
                            # -- weed out people who rejoined from umode +x
                            debug 4 "check:floodnet: (adaptive -- $prefix) checking if recent umode+x"
                            if {[info exists data:setx($newuser)]} { continue; }
                            debug 2 "\002check:floodnet: (adaptive -- $prefix) pre-record! adaptive ($ltype) regex joinflood detected: [join $newuser]!$uh\002"
                            set mask "*!*@$h"
                            # -- add mask to ban queue if doesn't exist and wasn't recently banned by me
                            if {$mask ni $blist && ![info exists data:chanban($chan,$mask)]} {
                                # -- add to queue
                                lappend blist $mask
                                # -- remember
                                set data:chanban($chan,$mask) 1
                                utimer [cfg:get time:newjoin $chan] "arm::unset:chanban $chan $mask"
                            }
                            # -- add mask to global ban queue if not in already
                            if {$mask ni [get:val data:bans $chan]} { lappend data:bans($chan) $mask }
                            # -- add nick to kick queue
                            if {$newuser ni $klist} { lappend klist $newuser }
                            if {[$newuser ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $newuser }
                            # -- add any other nicknames on this host to kickqueue
                            foreach hnick [get:val data:hostnicks $h,$lchan] {
                                if {$hnick ni $klist} { lappend klist $hnick }
                                if {$hnick ni [get:val data:kicks $chan] $hnick]} { lappend data:kicks($chan) $hnick }
                            }
                        }
                    }
    
                    # -- insert current user
                    debug 4 "check:floodnet: (adaptive -- $prefix) adding nick: [join $nick] to kicklist"
    
                    
                    if {$nick ni $klist} { lappend klist $nick }
                    if {$nick ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $nick }
                    # -- add any other nicknames on this host to kickqueue
                    foreach hnick [get:val data:hostnicks $host,$lchan] {
                        if {$hnick ni $klist} { lappend klist $hnick }
                        if {$hnick ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $hnick }
                    }
                    
                    # set host [lindex [split $uhost @] 1]
                    debug 4 "check:floodnet: (adaptive -- $prefix) adding *!*@$host to banlist"
                    if {$blist == ""} { set blist "*!*@$host" } else {
                        # -- add to end, not to front
                        if {"*!*@$host" ni $blist} { lappend blist "*!*@$host" }
                    }
                    if {"*!*@$host" ni [get:val data:bans $chan]} { lappend data:bans($chan) "*!*@$host" }
    
                    # -- send kicks and bans at the end
                        
                    debug 2 "\002check:floodnet: (adaptive -- $prefix) adaptive regex join flood detected (type: $ltype count: $count list: $klist)\002"
                    set hit 1
                }
                # -- end of flood detection
                    
                # -- clear existing unset utimers for this pattern
                adapt:preclear [split $exp]
                    
                # -- setup timer to clear adaptive pattern count
                debug 3 "check:floodnet: (adaptive -- $prefix) unsetting in $secs secs: $ltype [join $exp] $count"
                utimer $secs "arm::adapt:unset $ltype [split $exp]"
    
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
    debug 3 "check:floodnet: (cumulative -- $prefix) beginning cumulative regex checks in $lchan (floodnet detection)"

    # -- fetch blacklist regex and host entry IDs where limit is not 1:1:1
    set ids [dict keys [dict filter $entries script {id dictData} {
        expr {([dict get $dictData chan] eq $lchan || [dict get $dictData chan] eq "*") \
        && [dict get $dictData type] eq "black" \
        && ([dict get $dictData method] eq "host" || [dict get $dictData method] eq "regex") \
        && [dict get $dictData limit] ne "1:1:1"}
    }]]
    
    set noauto 0; # -- track to prevent prevention of automatic blacklist entries after cumulative hit

    foreach id $ids {    
        # -- break out before we even begin if we've hit this client already
        # -- prevent unnecessary processing
        if {$hit} { break; }

        # -- avoid double matching if called from WHO and ID was already matched
        if {$id in [get:val flud:nickcount $chan,$snick] && $whoscan} { 
            putlog "check:floodnet: \002skipping cumulative entry:\002 chan: $chan -- nick: $snick -- id: $id -- \002nickcount: [get:val flud:nickcount $chan,$snick]\002"
            continue; 
        }
        
        set method [dict get $entries $id method]
        set equal [dict get $entries $id value]
        set limit [dict get $entries $id limit]
        set reason [dict get $entries $id reason]

        set chanmode [get:val chan:mode $chan]
        if {[dict get $entries $id onlysecure] && $chanmode ne "secure"} {
            debug 1 "check:floodnet: skipping blacklist entry as onlysecure=1 (chan: $chan -- id: $id -- method: $method -- value: $equal)"
            continue;
        }
        if {[dict get $entries $id notsecure] && $chanmode eq "secure"} {
            debug 1 "check:floodnet: skipping blacklist entry as notsecure=1 (chan: $chan -- id: $id -- method: $method -- value: $equal)"
            continue;
        }
        if {[dict get $entries $id disabled]} {
            debug 1 "check:floodnet: skipping blacklist entry as disabled=1 (chan: $chan -- id: $id -- method: $method -- value: $equal)"
            continue;
        }
        if {[dict get $entries $id noident] && ![string match "~*" $ident]} {
            debug 1 "check:floodnet: skipping blacklist entry as noident=1 (chan: $chan -- id: $id -- method: $method -- value: $equal -- \002ident:\002 $ident)"
            continue;
        }
        
        debug 3 "check:floodnet: (cumulative -- $prefix) looping: id: $id (chan: $chan -- method: $method -- value: $equal -- limit: $limit)"

        append reason " \[id: $id\]"
        set extlimit [split $limit ":"]
        lassign $extlimit joins secs hold
        
        # -- we really only care about host and regex types
        
        if {$method eq "host"} {
            # -- check if match nick
            if {[string match -nocase $equal $uhost] || [string match -nocase $equal $host]} {
                # -- matched!
                debug 3 "check:floodnet: (cumulative -- $prefix) host match: [join $equal] against string: [join $nick]!$uhost"

                debug 3 "check:floodnet: \002adding host id: $id for $chan to flud:nickcount($chan,$snick) to prevent double matching\002"
                append flud:nickcount($chan,$snick) "$id "

                if {![info exists flud:count($id)]} {
                    # -- no such tracking array exists for this host/mask
                    debug 3 "check:floodnet: (cumulative -- $prefix) host: \002no trackin\002 array exists: flud:count($id) -- \002created.\002"
                    set flud:count($id) 1
                    # -- unset after timeout
                    utimer $secs "arm::flud:unset $chan $id $snick"
                    
                } else {
                        # -- existing tracking array, increase counter
                        incr flud:count($id)
                        debug 3 "check:floodnet: (cumulative -- $prefix) host: \002existing\002 tracking array count flud:count($id): [get:val flud:count $id]"
                        set count [get:val flud:count $id]
                        if {$count < $joins} {
                            # -- breach not met
                            debug 3 "check:floodnet: (cumulative -- $prefix) host: breach \002not yet met\002 -- \002increased\002 flud:count($id) counter."
                            # -- clear existing unset utimers for this value
                            flud:preclear $equal
                    
                            # -- setup timer to clear adaptive pattern count
                            debug 3 "check:floodnet: (cumulative -- $prefix) host: unsetting in $secs secs: flud:count($id)"
                            # -- unset after timeout
                            utimer $secs "arm::flud:unset $chan $id $snick"
                            
                        } else {
                                # -- joinflood breach!
                                incr flud:count($id)
                                # -- store the active floodnet
                                set floodnet($chan) 1
                                
                                # -- store the hit
                                set hit 1; set noauto 1; # -- do not also add auto blacklist entry

                                # -- clear existing unset utimers for this value
                                flud:preclear [split $equal]
                                # -- setup timer to clear adaptive pattern count
                                debug 3 "check:floodnet: (cumulative -- $prefix) host: unsetting in extended $hold secs: flud:count($id)"
                                # -- unset after timeout
                                utimer $hold "arm::flud:unset $chan $id $snick"    
                                
                                debug 3 "check:floodnet: (cumulative -- $prefix) \002host breach met!\002 client found: [join $nick]!$uhost -- finding \002pre-record\002 clients..."   
    
                                foreach client $joinlist {
                                    # -- add this nick at the end
                                    if {$client eq $nick} { continue; }
                                    set sclient [split $client]
                                    set newjoinuh [get:val nick:newjoin $chan,$sclient]
                                    if {[string match -nocase $equal $newjoinuh]} {
                                        set thehost [lindex [split $newjoinuh @] 1]
                                        set mask "*!*@$thehost"
                                        debug 3 "\002check:floodnet: (cumulative -- $prefix) host pre-record client found: $client!$newjoinuh\002"
                                        # -- add client to kickban queue if doesn't exist
                                        if {$client ni $klist} { lappend klist $client }
                                        if {$client ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $client }
                                        # -- track kick reason
                                        set kreason($chan,$client) $reason
                                        # -- add any other nicknames on this host to kickqueue
                                        foreach hnick [get:val data:hostnicks $thehost,$lchan] {
                                            if {$hnick ni $klist} { lappend klist $hnick }
                                            if {$hnick ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $hnick }
                                        }
                                        # -- add mask to ban queue if doesn't exist and wasn't recently banned by me
                                        if {$mask ni $blist} { lappend blist $mask }
                                        if {$mask ni [get:val data:bans $chan]} { lappend data:bans($chan) $mask }
                                        if {![info exists data:chanban($chan,$mask)]} {
                                            set data:chanban($chan,$mask) 1
                                            utimer [cfg:get time:newjoin $chan] "arm::unset:chanban $chan $mask"
                                        }
                                    
                                    }
                                }
                                # -- add this client if doesn't exist
                                if {[join $nick] ni $klist} { lappend klist [join $nick] }
                                if {[join $nick] ni [get:val data:kicks $chan]} { lappend data:kicks($chan) [join $nick] }
                                # -- add any other nicknames on this host to kickqueue
                                foreach hnick [get:val data:hostnicks $host,$lchan] {
                                    if {$hnick ni $klist} { lappend klist $hnick }
                                    if {$hnick [get:val data:kicks $chan]} { lappend data:kicks($chan) $hnick }
                                }
                                
                                set mask "*!*@$host"
                                # -- track kick reason
                                putlog "\002check:floodnet: setting kreason($chan,$nick) to $reason\002"
                                set kreason($chan,$nick) $reason
                                # -- add mask to ban queue if doesn't exist
                                if {$mask ni $blist} { lappend blist $mask }
                                if {$mask ni [get:val data:bans $chan]} { lappend data:bans($chan) $mask }
                                
                        }
                        # -- end of joinflood breach by host
                }
            }
            # -- end of match
        }
        # -- end of host check
        
        if {$method eq "regex"} {
            # -- check if match nick
            if {[regexp -- $equal "[join $nick]!$uhost/$rname"]} {
                # -- matched!
                debug 3 "check:floodnet: (cumulative -- $prefix) \002regex match\002: [join $equal] against string: [join $nick]!$uhost/$rname"

                debug 3 "check:floodnet: \002adding regex id: $id for $chan to flud:nickcount($chan,$snick) to prevent double matching\002"
                append flud:nickcount($chan,$snick) "$id "


                if {![info exists flud:count($id)]} {
                    # -- no such tracking array exists for this host/mask
                    debug 3 "check:floodnet: (cumulative -- $prefix) host: \002no tracking\002 array exists: flud:count($id) -- \002created.\002"
                    set flud:count($id) 1
                    # -- unset after timeout
                    utimer $secs "arm::flud:unset $chan $id $snick"
                    
                } else {
                        # -- existing tracking array, increase counter
                        debug 3 "check:floodnet: (cumulative -- $prefix) regex: \002existing tracking\002 array count flud:count($id): [get:val flud:count $id]"
                        incr flud:count($id)
                        set count [get:val flud:count $id]
                        if {$count < $joins} {
                            # -- breach not met
                            debug 3 "check:floodnet: (cumulative -- $prefix) regex: breach \002not yet met\002 -- increased flud:count($id) counter to: \002$count\002"
                            # -- clear existing unset utimers for this value
                            flud:preclear [split $equal]
                    
                            # -- setup timer to clear adaptive pattern count
                            debug 3 "check:floodnet: (cumulative -- $prefix) regex: unsetting in $secs secs: flud:count($id)"
                            # -- unset after timeout
                            utimer $secs "arm::flud:unset $chan $id $snick"
                            
                        } else {
                                # -- joinflood breach!
                                set hit 1; set noauto 1; # -- do not also add automatic entry
                                incr flud:count($id)
                                # -- store the active floodnet
                                set floodnet($chan) 1
                                # -- clear existing unset utimers for this value
                                flud:preclear [split $equal]
                                # -- setup timer to clear adaptive pattern count
                                debug 3 "check:floodnet: (cumulative -- $prefix) regex: unsetting in extended $hold secs: flud:count($id)"
                                # -- unset after timeout
                                utimer $hold "arm::flud:unset $chan $id $snick"    
                                
                                debug 3 "check:floodnet: (cumulative -- $prefix) \002regex breach met!\002 client found: [join $nick]!$uhost -- finding \002pre-record\002 clients..."              

                                # -- find the pre-record clients
                                foreach client $joinlist {
                                    set sclient [split $client]
                                    set newjoinuh [get:val nick:newjoin $chan,$sclient]
                                    if {[regexp -- [join $equal] $newjoinuh]} {
                                        # -- add this nick at the end
                                        if {$client == $nick} { continue; }
                                        debug 3 "\002check:floodnet: (cumulative -- $prefix) regex pre-record client found: $client!$newjoinuh\002"
                                        # -- add client to kickban queue if doesn't exist already
                                        if {$client ni $klist} { lappend klist $client }
                                        if {$client ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $client }
                                        set thehost [lindex [split $newjoinuh @] 1]
                                        set mask "*!*@$thehost"
                                        # -- add any other nicknames on this host to kickqueue
                                        foreach hnick [get:val hostnicks $thehost,$lchan] {
                                            if {$hnick ni $klist} { lappend klist $hnick }
                                            if {$hnick ni [get:val data:kicks $chan]} { lappend data:kicks($chan) $hnick }
                                        }
                                        # -- track kick reason
                                        putlog "\002check:floodnet: setting kreason($chan,$nick) to $reason\002"
                                        set kreason($chan,$client) $reason
                                        # -- add mask to ban queue if doesn't exist and wasn't recently banned by me
                                        if {$mask ni $blist} { lappend blist $mask }
                                        if {$mask ni [get:val data:bans $chan]} { lappend data:bans($chan) $mask }
                                        if {![info exists data:chanban($chan,$mask)]} {
                                            set data:chanban($chan,$mask) 1
                                            utimer [cfg:get time:newjoin $chan] "arm::unset:chanban $chan $mask"
                                        }
                                    }
                                }
                                # -- add this client if doesn't exist already
                                if {[join $nick] ni $klist} { lappend klist [join $nick] }
                                if {[join $nick] ni [get:val data:kicks $chan]} { lappend data:kicks($chan) [join $nick] }
                                set mask "*!*@$host"
                                # -- track kick reason
                                putlog "\002check:floodnet: setting kreason($chan,$nick) to $reason\002"
                                set kreason($chan,$nick) $reason
                                # -- add mask to ban queue if doesn't exist
                                if {$mask ni $blist} { lappend blist $mask }
                                if {$mask ni [get:val data:bans $chan]} { lappend data:bans($chan) $mask }
                                
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
    if {[cfg:get auto:black $chan] && !$noauto} {
    
        foreach ban $blist {
            # -- don't need a mask
            set thost [lindex [split $ban "@"] 1]
    
            if {[regexp -- [cfg:get xregex *] $thost -> tuser]} {
                # -- user is umode +x, add a 'user' blacklist entry instead of 'host'
                set method "user"
                set equal $tuser
            } else {
                # -- add a host blacklsit entry
                set method "host"
                set equal $thost
            }
    
            # -- add entry if no matching chan or global white/black entry exists
            # -- there can only be one unique combination of this expression
            set ids [lindex [dict keys [dict filter $entries script {id dictData} {
                expr {([dict get $dictData chan] eq $lchan || [dict get $dictData chan] eq "*") && \
                [dict get $dictData method] eq $method && [dict get $dictData value] eq $equal}
            }]] 0]
            
            if {$ids eq ""} {
                # -- add automatic blacklist entry
    
                set reason "(auto) join flood detected"
                set id [db:add B $chan $method $equal Armour B 1:1:1 $reason]
                
                debug 1 "kickban: added auto blacklist entry: $equal (id: $id)"

                set data:banmask($id) "*!*@$host"; 
                utimer [cfg:get id:unban:time $chan] "unset arm::data:banmask($id)"; # -- allow automatic unban of recently banned mask, when removing 
            }
            # -- end of exists
        }
        # -- foreach blist ban
    }                        
    # -- end of automatic blacklist entries
    
    # -- process kicklist (klist) and banlist (blist)
    # -- for a more effective queue, this now happens on 1sec timer via flud:queue procedure
    
    debug 3 "check:floodnet: ending procedure... hit=$hit"
    return $hit

};

# -- custom ban queue (and chammode -r to unlock chan when serverqueue is emptied)
# -- i've noticed that the eggdrop queues are too slow, and I need to try to stack modes wherever possible
proc flud:queue {} {
    global server
    variable data:bans;  # -- banlist queue
    variable data:kicks; # -- kicklist queue
    variable floodnet;   # -- tracking active floodnet (by chan)
    variable chanlock;   # -- tracking active channel lock (by chan)
    variable dbchans;    # -- dict: list of channel entries
    variable kreason;    # -- kick reason (by chan,nick)

    #debug 3 "flud:queue: starting..."

    set cids [dict keys $dbchans]
    
    foreach cid $cids {
        set chan [dict get $dbchans $cid chan]
        if {$chan eq "*"} { continue; }; # -- skip global chan

        set bans [get:val data:bans $chan]
        set kicks [get:val data:kicks $chan]

        if {![info exists floodnet($chan)]} { set fludactive 0 } else { set fludactive 1 }
                
        set size [queuesize server]
        set lockdown 0
        if {$size >= 3 && $fludactive} {       
            # -- announce queue size if floodnet is active
            debug 3 "flud:queue: server queue size is >= 3 messages (size: $size)"
            if {![info exists chanlock($chan)]} { set lockdown 1 }
        }
        
        # -- process global ban queue if exists
        while {$bans ne ""} {
            debug 1 "\002flud:queue:\002 stacking ban modes for banlist: $bans"
            set length [llength [get:val data:bans $chan]]
            if {$lockdown && ![info exists chanlock($chan)]} {
                # -- safetey net in case + isn't included in the var
                set lockmode [cfg:get chanlock:mode $chan]
                if {[string match "+*" $lockmode]} {
                    set lockmode [string range $lockmode 1 end] 
                }
                # -- count the modes
                set mcount [string length $lockmode]   
                # -- subtract from the 6 stacked modes allowed  
                set bstack [expr 6 - $mcount]
                # -- concatenate the modes for stack
                set modes  "+$lockmode[string repeat "b" $length]"
                                
                debug 1 "\002flud:queue:\002 locking down chan $chan via chanmode +$lockmode"
                
                set chanlock($chan) 1
                # -- number of banmasks to include in stack (counting from 0)
                set num [expr 5 - $mcount]
                set blist [join [lrange [get:val data:bans $chan] 0 $num]]
                # -- unlock chan in N seconds (if serverqueue is cleared) - 20secs
                flud:unlock $chan
                
            } else {
                if {$length >= 6} { set modes "+bbbbbb" } else { set modes "+[string repeat "b" $length]" }
                set blist [join [lrange [get:val data:bans $chan] 0 5]]
                set num 5
            }
            debug 1 "\002flud:queue:\002 executing: MODE $chan $modes $blist"
            # -- putnow is instant
            # -- WARNING: it is *possible* for putnow to excess flood the bot
            putnow "MODE $chan $modes $blist"
            set bans [lreplace [get:val data:bans $chan] 0 $num]
        
        }; # -- end ban queue

        set data:bans($chan) ""

        # -- kick queue
        if {$kicks ne ""} { debug 3 "flud:queue: kicking kicklist from $chan: [join $kicks]" }
        foreach client $kicks {
            # -- safety net if not on server
            if {![botonchan $chan] || ![botisop $chan] || $server eq ""} {
                debug 0 "flud:queue: not on chan $chan or not op... skipping"
                continue;
            };
            set sclient [split $client]
            set reason "join flood detected"; # -- default reason 
            # -- kick users
            if {[info exists kreason($chan,$sclient)]} { 
                # -- safety net
                if {$kreason($chan,$sclient) != ""} {
                    set reason [get:val kreason $chan,$sclient]
                    unset kreason($chan,$sclient) 
                }
            }
            putquick "KICK $chan $client :Armour: $reason"
            # putkick $chan $client "Armour: $reason"

        }
        
        set data:kicks($chan) ""
        # -- end kick queue

        # -- unlock channel after configured delay when server queue is empty
        set size [queuesize server]
        if {$size eq 0} {
            #debug 1 "flud:queue: server queue size is empty, unset floodnet track in [cfg:get chanlock:time $chan] secs"
            #utimer [cfg:get chanlock:time $chan] "arm::flud:unlock $chan"
            flud:unlock $chan
        }

    }; # -- end foreach chan

    # -- use miliseconds
    after [cfg:get queue:flud $chan] arm::flud:queue
}

# -- before we unlock (chanmode -r) the chan, we have a delay to be sure
proc flud:unlock {chan} {
    variable cfg
    variable floodnet;  # -- tracking active floodnet (by chan)
    variable chanlock;  # -- tracking active channel lock (by chan)
    
    # -- let's check the server queue again and ensure it's empty
    if {![info exists floodnet($chan)]} { set fludactive 0 } else { set fludactive 1 }
    set size [queuesize server]
    
    # -- only unlock if queue is empty and flood is not active
    if {$size eq 0 && !$fludactive} { 
        if {[info exists chanlock($chan)]} {
            # -- unlock channel
            regsub {\+} [cfg:get chanlock:mode $chan] {-} unlock
            debug 1 "flud:unlock: unlocking chan $chan via chanmode $unlock"
            putquick "MODE $chan $unlock"
            catch { unset chanlock($chan) }
            catch { unset floodnet($chan) }
        }
    } else {
        # -- add another N seconds to the delay and check again
        utimer [cfg:get chanlock:time $chan] "arm::flud:unlock $chan"
    }
}

debug 0 "\[@\] Armour: loaded floodnet detection."

}
# -- end namespace



# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-16_userdb.tcl
#
# database file support procedures
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- binds
bind msg - login arm::userdb:msg:login
bind msg - logout arm::userdb:msg:logout
bind msg - newpass arm::userdb:msg:newpass
bind msg - whois arm::userdb:msg:whois
bind msg - inituser arm::userdb:msg:inituser

bind join - * { arm::coroexec arm::userdb:join    }
bind part - * { arm::coroexec arm::userdb:part    }
bind sign - * { arm::coroexec arm::userdb:signoff }
bind nick - * { arm::coroexec arm::userdb:nick    }
bind kick - * { arm::coroexec arm::userdb:kick    }

# -- logout all users upon server (re-)connection
bind evnt - connect-server arm::userdb:init:logout

bind raw - 330 { arm::coroexec arm::userdb:raw:account }
bind raw - 352 { arm::coroexec arm::userdb:raw:genwho  }
bind raw - 354 { arm::coroexec arm::userdb:raw:who     }

bind msg - * arm::userdb:znc; # -- handle logout during ZNC disconnections

# -- command: inituser
# inituser <user> [account]
# -- create initial user on a blank database
proc userdb:msg:inituser {nick uhost hand arg} {
    global botnick
    set user [join [lindex $arg 0]]
    set account [join [lindex $arg 1]]

    if {$user eq ""} { 
        set ircd [cfg:get ircd *]
        if {$ircd eq "1"} {
            reply notc $nick "\002usage:\002 inituser <user> \[account\]";
            reply notc $nick "the <user> should be your desired bot username, and \[account\] is your network username, for autologin.";
        } else {
            # -- network accounts do not apply (e.g., EFnet, IRCnet)
            reply notc $nick "\002usage:\002 inituser <user>"; 
        }
        return;
    }

    db:connect
    # -- select user count
    debug 0 "userdb:msg:inituser: checking if user DB is empty"
    set count [db:query "SELECT count(*) FROM users"]
    db:close

    if {$count ne 0} {
        debug 0 "userdb:msg:inituser: user DB is not empty! (count: $count).. exiting."
        return;
    }
    
    # -- create the new user
    set randpass [randpass]
    set encpass [userdb:encrypt $randpass]; # -- hashed random password
    db:connect
    set db_user [db:escape $user]
    set db_xuser [db:escape $account]
    set reg_ts [unixtime]
    set reg_by [db:escape "$nick!$uhost ($user)"]
    db:query "INSERT INTO users (user,xuser,pass,register_ts,register_by) VALUES ('$db_user', '$db_xuser', '$encpass','$reg_ts','$reg_by')"
    set uid [db:last:rowid]

    set globid [db:get id channels chan "*"]; # -- check for global chan

    db:connect
    if {$globid eq ""} {
        # -- create global chan
        debug 0 "userdb:msg:inituser: auto creating missing channel: *"
        set res [db:query "INSERT INTO channels (chan,mode) VALUES ('*','on')"]
        # -- insert first usert with access
        set dbmodif [db:escape "(Armour) initial install"]
        debug 0 "userdb:msg:inituser: automatically adding initial user to global chan (uid: 1 -- user: $user)"
        db:connect
        # -- insert a default user
        db:query "INSERT INTO levels (cid,uid,level,added_ts,added_bywho,modif_ts,modif_bywho) \
            VALUES (1,$uid,500,'$reg_ts','$dbmodif','$reg_ts','$dbmodif')"        
    }
    db:close
    set defchan [cfg:get chan:def *]
    set defid [db:get id channels chan $defchan]
    if {$defid eq ""} {
        # -- create default chan
        debug 0 "userdb:msg:inituser: auto creating missing channel: $defchan"
        set reg_ts [unixtime]
        set reg_by "Armour (initial install)"
        # -- add chan
        db:connect
        db:query "INSERT INTO channels (chan,mode,reg_ts,reg_bywho) VALUES ('$defchan','on','$reg_ts','$reg_by')"
        set cid [db:get id channels chan $defchan]
        # -- add first user
        db:query "INSERT INTO levels (cid,uid,level,added_ts,added_bywho,modif_ts,modif_bywho) \
            VALUES ($cid,$uid,500,'$reg_ts','$reg_by','$reg_ts','$reg_by')"
        db:close
        # -- add to eggdrop if it doesn't exist
        set chanlist [string tolower [join [channels]]]
        if {[string tolower $defchan] ni $chanlist} { channel add $defchan }
    }

    reply notc $nick "newuser created. please login: /msg $botnick login $user $randpass"
    reply notc $nick "and then change password: /msg $botnick newpass <newpassword>"
    
    # -- command log entry
    set cmd "inituser"
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] "$nick!$uhost" "" "" ""

}

proc userdb:cmd:do {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg

    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 

    set cmd "do"
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- global command
    lassign [db:get id,user users curnick $nick] uid user

    # -- end default proc template

    set tcl [join $arg]

    if {$tcl eq ""} { reply $stype $starget "uhh.. do what?"; return; }

    set start [clock clicks]
    set errnum [catch {eval $tcl} error]
    set end [clock clicks]
    debug 3 "userdb:cmd:do: tcl error: $error -- (errnum: $errnum)"
    if {$error eq ""} {set error "<empty string>"}
    switch -- $errnum {
        0 {if {$error  eq "<empty string>"} {set error "OK"} {set error "OK: $error"}}
        4 {set error "continue: $error"}
        3 {set error "break: $error"}
        2 {set error "return: $error"}
        1 {set error "error: $error"}
        default {set error "$errnum: $error"}
    }
    set error "$error ([expr ($end-$start)/1000.0] sec)"
    set error [split $error "\n"]
    foreach line $error { reply $type $target $line }
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: info
# usage: info <user|chan>
# views information about a username or channel
proc userdb:cmd:chaninfo {0 1 2 3 {4 ""} {5 ""}} { userdb:cmd:info $0 $1 $2 $3 $4 $5 }
proc userdb:cmd:whois {0 1 2 3 {4 ""} {5 ""}} { userdb:cmd:info $0 $1 $2 $3 $4 $5 }
proc userdb:cmd:info {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "info"
    lassign [db:get id,user users curnick $nick] uid user
    
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- * for general command access
    if {[lindex $arg 0] eq ""} { reply $stype $starget "usage: info <user|chan>"; return; }
    
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#"} { set ischan 1; set chan $first; set cid [db:get id channels chan $chan] } \
    elseif {$first eq "*"} { set ischan 1; set cid 1; set chan "*"; } \
    else { set ischan 0; set cid 1; set chan "*"; }
    
    # -- channel
    if {$ischan} {
        set chan [lindex $arg 0]
        lassign [db:get id,chan channels chan $chan] cid tchan
        if {$tchan eq ""} { reply $type $target "\002(\002error\002)\002 channel $chan not registered."; return; }
        if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
        db:connect
        set uids [db:query "SELECT uid FROM levels WHERE level=500 AND cid=$cid"]
        # -- get the managers (level 500s)
        set tmgrs [list]
        foreach tuid $uids {
            set tuser [db:get user users id $tuid]
            lappend tmgrs $tuser
        }
        if {$tmgrs eq ""} { set txt "manager"; set tmgrs "(none)" } \
        elseif {[llength $tmgrs] > 1} { set txt "managers" } \
        else { set txt "manager" }
        set tmgrs [join $tmgrs ", "]
        reply $type $target "\002chan:\002 $tchan (\002id:\002 $cid) -- \002$txt:\002 $tmgrs"
        # -- get the channel settings
        set rows [db:query "SELECT setting,value FROM settings WHERE cid=$cid"]
        set longlist [list]; set shortlist [list]
        foreach row $rows {
            lassign $row setting value
            if {[string length $value] > 8} {
                # -- long line; output on its own
                lappend longlist [list "\002$setting:\002 $value"]
            } else {
                # -- shorter value (i.e. on|off)
                lappend shortlist [list "\002$setting:\002 $value"]
            }
        }
        # -- output the channel settings first
        while {$shortlist != ""} {
            # -- output 3 x settings per line
            reply $type $target "[join [join [lrange $shortlist 0 7]]]"
            set shortlist [lreplace $shortlist 0 7]
        }
        # -- now output the longer strings (url, description)
        foreach pair $longlist {
            reply $type $target [join $pair]
        }
        # -- store registration history
        lassign [db:get reg_ts,reg_bywho channels id $cid] reg_ts reg_bywho
        if {$reg_ts ne ""} {
            set reg_ago [userdb:timeago $reg_ts]
            reply $type $target "\002registered:\002 $reg_ago -- \002by:\002 $reg_bywho"
        }
        db:close

    # -- username            
    } else {
        set targetuser [lindex $arg 0]
        # -- check if = used
        if {[regexp -- {^=(.+)$} $targetuser -> targetnick]} {
            # -- specified a nick, find the user
            if {![onchan $targetnick]} { reply $type $target "\002(\002error\002)\002 who is $targetnick?"; return; }
            set targetuser [userdb:user:get user nick $targetnick]
            if {$targetuser eq ""} { reply $type $target "\002(\002error\002)\002 $targetnick not authenticated."; return; }
        }
        
        # -- tidy targetuser case
        set origuser $targetuser

        # -- get the data
        db:connect
        set row [lindex [db:query "SELECT id,user,xuser,curnick,curhost,lastnick,lasthost,lastseen,email,languages \
            FROM users WHERE lower(user)='[string tolower $targetuser]'"] 0]
        db:close
        lassign $row trgid targetuser trgxuser trgcurnick trgcurhost trglastnick trglasthost trglastseen trgemail trglang

        if {$targetuser eq ""} { reply $type $target "\002(\002error\002)\002 who is $origuser?"; return; }
            
        # -- format the info
        
        if {$trglastseen ne ""} { set lastseen [userdb:timeago $trglastseen] } \
        else { set lastseen "never" }
        if {$trgcurnick ne ""} { set lastseen "now (authed $lastseen ago)" }
        set where ""
        if {$lastseen ne "never"} {
            if {$trgcurnick ne ""} { set where "-- \002where:\002 $trgcurnick!$trgcurhost" } \
            else { set where "-- \002last:\002 $trglastnick!$trglasthost" }
        }   
        if {$trgemail eq ""} { set trgemail "(not set)" }
        if {$trglang eq "" || $trglang == "EN"} {
            set line1 "-- \002email:\002 $trgemail"
            set line2 "\002lastseen:\002 $lastseen $where"
        } else {
            set line1 "-- \002languages:\002 $trglang"
            set line2 "\002email:\002 $trgemail -- \002lastseen:\002 $lastseen $where"
        }
        
        # -- team memberships (if plugin loaded)
        set tlist [list]
        if {[info commands "train:cmd:team"] ne ""} {
            # -- training plugin loaded
            train:db_connect
            set rows [train:db_query "SELECT tid,flags FROM users WHERE uid=$trgid"]
            foreach row $rows {
                lassign $row tid flags
                train:db_connect
                set team [train:db_query "SELECT team FROM teams WHERE id=$tid"]
                # -- flags:
                #      0: no flags
                #      1: leader
                #      2: admin            
                switch -- $flags {
                    1       { lappend tlist "$team (leader)" }
                    2       { lappend tlist "$team (admin)" }
                    default { lappend tlist $team }
                }
            }
            train:db_close
            set tlist [join [string tolower $tlist] ", "]
        }
        if {$tlist ne ""} { set txtra "-- \002teams:\002 $tlist" } else { set txtra ""} 
        
        # -- greeting?  
        db:connect
        set query "SELECT greet FROM greets WHERE uid=$trgid"; # -- TODO: show only if one, otherwise show global greet?
        set row [db:query $query]
        set greet [lindex [lindex $row 0] 0]
            
        set lvls [list]
        set rows [db:query "SELECT cid,level FROM levels WHERE uid='$trgid' ORDER BY level DESC"]
        foreach row $rows {
            lassign $row cid tlevel
            if {$cid eq 1 && $tlevel != 0 && $tlevel != ""} { lappend lvls "global (\002$tlevel\002)"; continue; }
            set tchan [db:get chan channels id $cid]
            lappend lvls "[join $tchan] ($tlevel)"
        }
        set lvls [join $lvls ", "]
        if {$lvls eq ""} { set lvls "(no access)" }
        db:close
        
        if {[cfg:get ircd *] eq 1} {
            # -- ircu (ie. Undernet/Quakenet) -- ACCOUNT
            reply $type $target "\002user:\002 $targetuser -- \002account:\002 $trgxuser $line1 -- \002access:\002 $lvls $txtra"
        } else {
            # -- no ACCOUNT (ie. EFnet/IRCnet)
            reply $type $target "\002user:\002 $targetuser $line1 -- \002access:\002 $lvls $txtra"
        }
        
        # -- second line
        reply $type $target $line2
        
        if {$greet ne ""} {
            # -- output the onjoin greeting!
            reply $type $target "\002greet:\002 $greet"
        }    
    }
    
    # -- create log entry
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [lindex $arg 0] $source "" "" ""
}


# -- command: usearch
# usage: usearch <search>
# searches database for registered usernames
proc userdb:cmd:usearch {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "usearch"
    lassign [db:get id,user users curnick $nick] uid user
    
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- * for general command access
    set search [lindex $arg 0]
    if {$search eq ""} { reply $stype $starget "usage: usearch <search>"; return; }

    regsub -all {\*} $search "%" dbsearch
    regsub -all {\?} $dbsearch "_" dbsearch
    
    debug 0 "userdb:cmd:usearch: $nick (user: $user) looking up users in $chan (search: $search)"
    
    db:connect
    set rows [db:query "SELECT id,user,curnick FROM users WHERE user LIKE '$dbsearch' ORDER BY id ASC"]
    db:close
    set users [list]; set count 0;
    foreach row $rows {
        incr count;
        lassign $row tuid tuser curnick
        if {$curnick ne ""} { lappend users "\002$tuser\002" } else { lappend users $tuser }
        #lappend users "$tuser (\002id:\002 $tuid)"; # -- uid isn't really helpful
    }
    set users [join $users ", "]
    if {$count eq 1} { set out "user" } else { set out "users" }
    
    set response "$count $out matches found."
    if {$count > 0} { append response " $users" }
    
    reply $type $target $response
        
    # -- create log entry
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [lindex $arg 0] $source "" "" ""
}


# -- command: lang
# usage: lang <language>
# searches database for users speaking a certain languages
proc userdb:cmd:lang {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    variable lang2code
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "lang"
    lassign [db:get id,user users curnick $nick] uid user
    
    if {![userdb:isAllowed $nick $cmd * $type]} { return; }; # -- * for general command access
    lassign $arg search all
    if {$search eq ""} { reply $stype $starget "usage: lang <language> \[-all\]"; return; }
    if {$all eq "-all"} { set all 1; set match "total" } else { set all 0; set match "online" }

    set dbsearch $search
    if {[info exists lang2code([string tolower $dbsearch])]} {
        set dbsearch [string toupper $lang2code([string tolower $dbsearch])]
    }
    
    debug 0 "userdb:cmd:lang: $nick (user: $user) looking up languages in $chan (search: $search)"
    
    db:connect
    set rows [db:query "SELECT id,user,languages,curnick FROM users"]
    db:close
    set users [list]; set ulist [list]; set count 0;
    foreach row $rows {
        lassign $row tuid tuser langs curnick
        if {!$all && $curnick eq ""}  { continue; }; # -- only show online users
        foreach lang $langs {
            if {[string match [string toupper $dbsearch] $lang]} {
                if {$tuser in $ulist} { continue; }
                incr count;
                lappend ulist $tuser
                if {$curnick ne "" && $all eq 1} { lappend users "\002$tuser\002" } else { lappend users $tuser }; # -- bold if authenticated
                #lappend users "$tuser (\002id:\002 $tuid)"
            }
        }
    }
    set users [join $users ", "]
    if {$count eq 1} { set out "user" } else { set out "users" }
    
    set response "found \002$count\002 $match $out"
    if {$count > 0} { append response " \002(\002$users\002)\002" }
    
    reply $type $target $response
        
    # -- create log entry
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [lindex $arg 0] $source "" "" ""
}


# -- command: userlist
# views userlist
proc userdb:cmd:userlist {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "userlist"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- determine channel
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#" || $first eq "*"} {
        set chan [lindex $arg 0]
        set xtra "WHERE lower(chan)='[db:escape $chan]'"
    } else { set chan [userdb:get:chan $user $chan]; set xtra "" }
    set lchan [string tolower $chan]
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    set cid [db:get id channels chan $chan]

    # -- command: userlist
    if {[lsearch $arg "-more"] ne "-1"} { set more 1 } else { set more 0 }

    # -- built basic list of users
    set userlist [list]; set str ""
    db:connect
    set query "SELECT id,chan FROM channels $xtra ORDER BY id ASC"
    debug 3 "userdb:db:userlist: query: $query"
    set rows [db:query $query]
    db:close
    foreach row $rows {
        lassign $row tcid tchan
        if {![userdb:isAllowed $nick $cmd $tchan $type]} { continue; }; # -- no access to lookup this chan
        db:connect
        set rowsu [db:query "SELECT level,uid,automode FROM levels WHERE cid=$tcid"]
        set rowsu [lsort -decreasing $rowsu]
        db:close
        foreach rowu $rowsu {
            lassign $rowu tlevel tuid tautomode
            lassign [db:get user,xuser,curnick users id $tuid] tuser txuser tcurnick
            switch -- $tautomode {
                0       { set tamode "none" }
                1       { set tamode "voice" }
                2       { set tamode "op" }
                default { set tamode "none" }
            }
            if {$tcurnick ne ""} {
                # -- authenticated
                set iuser "\002$tuser\002"
            } else { 
                # -- not authed
                set iuser $tuser
            }
            if {$more} {
                # -- long form
                lappend userlist "$iuser (account: $txuser level: $tlevel mode: $tamode) --"
                set str " --"
            } else {
                # -- short form (default)
                lappend userlist "$iuser ($tlevel),"
                set str ","
            }
        }
        set userlist [string trimright [join $userlist] $str]
        if {$tcid eq 1} { set tchan "global" }
        if {$userlist eq ""} { set userlist "(empty)" }
        reply $type $target "userlist (\002$tchan\002): $userlist"    
        set userlist [list]
    }
    
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: chanlist
# views chanlist
proc userdb:cmd:chanlist {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "chanlist"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- command: chanlist
    
    if {[lsearch $arg "-more"] ne "-1"} { set more 1 } else { set more 0 }

    # -- built basic list of channels
    set chanlist [list]
    db:connect
    set rows [db:query "SELECT id,chan FROM channels ORDER BY id ASC"]
    db:close
    foreach row $rows {
        lassign $row tcid tchan
        if {![userdb:isAllowed $nick $cmd $tchan $type]} { continue; }; # -- no access to lookup this chan
        db:connect
        set uids [db:query "SELECT uid FROM levels WHERE cid=$tcid AND level=500"]
        db:close
        set mgrs [list]
        foreach tuid $uids {
            lassign [db:get user,curnick users id $tuid] tuser tcurnick
            #if {$tcid eq 1} { set tchan "global" }; -- use * name
            if {$tcurnick ne ""} {
                # -- authenticated
                lappend mgrs "\002$tuser\002"
            } else { 
                # -- not authed
                lappend mgrs $tuser
            }
        }
        if {$more} {
            # -- long form
            if {[llength $mgrs] eq 0} { set txt "mgr"; set mgrs "none" } \
            elseif {[llength $mgrs] > 1} { set txt "mgrs" } \
            else { set txt "mgr" }
            lappend chanlist "$tchan ($txt: [join $mgrs ,]) --"
            set str " --"
        } else {
            # -- short form (default)
            lappend chanlist "$tchan,"
            set str ","
        }
    }
    set chanlist [string trimright [join $chanlist] $str]
    reply $type $target "\[\002chanlist\002\]: $chanlist"    
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: adduser
# add user to channel access
proc userdb:cmd:adduser {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg

    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "adduser"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- determine channel
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#" || $first eq "*"} {
        lassign $arg chan trguser trglevel trgamode
    } else {
        set chan [userdb:get:chan $user $chan];
        lassign $arg trguser trglevel trgamode
    }
    set cid [db:get id channels chan $chan]
    set lchan [string tolower $chan]
    set log "$chan [join $arg]"; set log [string trimright $log " "]

    # -- command: adduser
    if {$trguser eq "" || $trglevel eq ""} {
        reply $stype $starget "\002usage:\002 adduser ?chan? <user> <level> \[automode\]";
        return;
    }

    # -- check if user exists
    lassign [db:get user,id users user $trguser] tuser tuid
    if {$tuser eq ""} {
        reply $type $target "error: user $trguser does not exist.  try 'newuser' first?"
        return;
    }
    
    # -- default automode of none
    if {$trgamode eq ""} { set trgamode "none" }
    
    # -- check level
    if {![userdb:isInteger $trglevel]} { reply $type $target "valid levels: 1-500"; return; }
    set level [userdb:get:level $user $chan]
    set globlevel [db:get level levels cid 1 uid $uid]
    if {$trglevel >= $level && $globlevel != 500 && $chan != "*"} {
        reply $type $target "error: cannot add a user with a level equal to or above your own.";
        return;
    }
    
    set tlevel [db:get level levels uid $tuid cid $cid]
    if {$tlevel ne ""} {
        reply $type $target "error: user $tuser already has access on $chan (level: $tlevel)";
        return;
    }

    switch -- $trgamode {
        none    { set automode "0"; set automodew "none"; }
        0       { set automode "0"; set automodew "none"; }
        1       { set automode "1"; set automodew "voice"; }
        voice   { set automode "1"; set automodew "voice"; }
        2       { set automode "2"; set automodew "op"; }
        op      { set automode "2"; set automodew "op"; }
        default { reply $stype $starget "\002(\002error\002)\002 automode should be: none|voice|op"; return; }
    }

    # -- add the access
    db:connect
    set db_added_bywho "$nick!$uh ($user)"
    set added_ts [unixtime]
    db:query "INSERT INTO levels (cid,uid,level,automode,added_ts,added_bywho,modif_ts,modif_bywho) \
        VALUES ('$cid', '$tuid', '$trglevel', '$automode', '$added_ts', '$db_added_bywho', '$added_ts', '$db_added_bywho')"
    db:close
    
    debug 1 "userdb:cmd:adduser: added user: $tuser (chan: $chan -- level: $trglevel -- automode: $automodew)"
    
    reply $type $target "added user $tuser \002(chan:\002 $chan -- \002level:\002 $trglevel -- \002automode:\002 $automodew\002)\002"
    
    # -- send a note to the user?
    if {[cfg:get note $chan] && [cfg:get note:adduser $chan] && $trguser ne $user} {
        set note "You have been given access to $chan (\002level:\002 $trglevel -- \002automode:\002 $automodew)"
        # -- notify the recipient if online
        set read "N"
        set to_nick [join [join [db:get curnick users user $trguser]]]
        set online 0;
        if {$to_nick ne ""} {
            # -- recipient is online
            # -- insert note as read if they're already online and get the /notice
            set read "Y"; set online 1;
        }
        db:connect
        set db_note [db:escape $note]
        db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, read, note) \
                VALUES ('[clock seconds]', '$user', '$uid', '$trguser', '$tuid', '$read', '$db_note')"
        set rowid [db:last:rowid]
        db:close
        if {$online} {
            putquick "NOTICE $to_nick :(\002note\002 from $user -- \002id:\002 $rowid): $note"
            debug 0 "userdb:cmd:adduser: notified $trguser ($to_nick![getchanhost $to_nick]) that $user added them to $chan with level $trglevel"
        }
    }
    
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: remuser
# remove a user from channel access
proc userdb:cmd:remuser {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "remuser"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- determine channel
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#" || $first eq "*"} {
        lassign $arg chan trguser
    } else {
        set chan [userdb:get:chan $user $chan];
        lassign $arg trguser 
    }
    set cid [db:get id channels chan $chan]
    set lchan [string tolower $chan]
    set log "$chan [join $arg]"; set log [string trimright $log " "]

    # -- command: remuser
    if {$trguser eq ""} {
        reply $stype $starget "\002usage:\002 remuser ?chan? <user>";
        return;
    }

    # -- check if user exists
    lassign [db:get user,id users user $trguser] tuser tuid
    if {$tuser eq ""} {
        reply $type $target "error: user $trguser does not exist."
        return;
    }
    
    set tlevel [db:get level levels uid $tuid cid $cid]
    if {$tlevel eq ""} {
        reply $type $target "error: user $tuser is not in the $chan userlist.";
        return;
    }
    set slevel [db:get level levels uid $uid cid $cid]; if {$slevel eq ""} { set slevel 0 }
    set glevel [db:get level levels uid $uid cid 1]; if {$glevel eq ""} { set glevel 0 }
    if {$glevel > $slevel} { set elevel $glevel } else { set elevel $slevel }
    if {$tlevel >= $elevel && $tuser ne $user && $glevel != 500} {
        reply $type $target "error: cannot remove a user with access equal or above your own.";
        return;        
    }

    # -- add the access
    db:connect
    db:query "DELETE FROM levels WHERE cid=$cid AND uid=$tuid"
    db:close
    
    debug 1 "userdb:cmd:remuser: removed user: $tuser (chan: $chan -- level: $tlevel)"
    
    reply $type $target "removed user $tuser \002(chan:\002 $chan -- \002level:\002 $tlevel)\002"
    
    # -- send a note to the user?
    if {[cfg:get note $chan] && [cfg:get note:remuser $chan] && $tuser ne $user} {
        set note "Your access to $chan has been revoked (\002level:\002 $tlevel)"
        # -- notify the recipient if online
        set read "N"
        set to_nick [join [join [db:get curnick users user $tuser]]]
        set online 0;
        if {$to_nick != ""} {
            # -- recipient is online
            # -- insert note as read if they're already online and get the /notice
            set read "Y"; set online 1;
        }
        db:connect
        set db_note [db:escape $note]
        db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, read, note) \
                VALUES ('[clock seconds]', '$user', '$uid', '$tuser', '$tuid', '$read', '$db_note')"
        set rowid [db:last:rowid]
        db:close
        if {$online} {
            putquick "NOTICE $to_nick :(\002note\002 from $user -- \002id:\002 $rowid): $note"
            debug 0 "userdb:cmd:remuser: notified $tuser ($to_nick![getchanhost $to_nick]) that their access has been revoked (level $tlevel)"
        }
    }
        
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: addchan
# register a new channel
proc userdb:cmd:addchan {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg
    variable chan:id;      # -- the id of a registered channel (by chan)
    variable chan:chan;    # -- the name of a registered channel (by chan)
    variable chan:chan:id; # -- the name of a registered channel (by id)
    variable chan:mode;    # -- state: the operational mode of a registered channel (by chan)
    variable chan:modeid;  # -- state: the operational mode of a registered channel (by id)
    
    variable dbchans;      # -- dict to store channel db data

    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "addchan"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    set achan [lindex $arg 0]
    set tuser [lindex $arg 1]
    set log "$chan [join $arg]"; set log [string trimright $log " "]

    # -- command: addchan
    if {$achan eq ""} {
        reply $stype $starget "\002usage:\002 addchan <chan> \[user\]";
        return;
    }

    # -- check if chan already exists
    lassign [db:get chan,id channels chan $achan] tchan tcid
    if {$tchan ne ""} {
        reply $type $target "\002error:\002 channel $tchan is already registered."
        return;
    }
    
    # -- add the channel!
    debug 1 "userdb:cmd:addchan: registering channel $achan (user: $tuser)"
    db:connect
    set db_chan [db:escape $achan]
    set db_bywho [db:escape "$nick!$uh ($user)"]
    set regts [unixtime]
    set res [db:query "INSERT INTO channels (chan,mode,reg_uid,reg_bywho,reg_ts) \
        VALUES ('$db_chan','on',$uid,'$db_bywho',$regts)"]
    set tcid [db:last:rowid]
    db:close
    channel add $achan; channel set $achan -inactive

    # -- old structure
    # -- TODO: remove these old remnants
    set chan:id([string tolower $achan]) $tcid
    set chan:chan($tcid) $achan
    set chan:mode([string tolower $achan]) "on"
    set chan:modeid($tcid) "on"
    
    # -- new dict structure
    dict set dbchans $tcid id $tcid
    dict set dbchans $tcid chan $achan
    
    if {$tuser ne ""} {
        lassign [db:get id,user users user $tuser] tuid tuser
        if {$tuid eq ""} {
            reply $type $target "error: user $tuser does not exist."
            return;
        }
        db:connect
        set res [db:query "INSERT INTO levels (cid,uid,level,added_ts,added_bywho,modif_ts,modif_bywho) \
            VALUES ($tcid, $tuid, 500, $regts, '$db_bywho', $regts, '$db_bywho')"]
        db:close
        reply $type $target "done. registered $achan (user: $tuser)"
    } else {
        reply $type $target "done. registered $achan"
    }
 
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: remchan
# purge a new channel
proc userdb:cmd:remchan {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "remchan"

    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    set rchan [lindex $arg 0]
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $rchan $type]} { return; }
    
    set isforce [lindex $arg 1]
    set log "$chan [join $arg]"; set log [string trimright $log " "]

    # -- command: remchan
    if {$rchan eq ""} {
        reply $stype $starget "\002usage:\002 remchan <chan>";
        return;
    }

    # -- check if chan already exists
    lassign [db:get chan,id channels chan $rchan] tchan tcid
    if {$tchan eq ""} {
        reply $type $target "error: channel $tchan is not registered."
        return;
    }
    
    if {[string tolower $isforce] ne "-force"} {
        reply $type $target "\002(warning)\002 to really purge this channel and any exclusive users, please add -force"
        return;
    }
    
    # -- delete the channel!
    debug 0 "userdb:cmd:remchan: purging channel $rchan"
    db:connect
    set res [db:query "DELETE FROM channels WHERE id=$tcid"]
    debug 0 "userdb:cmd:remchan: removing all channel access from chan $rchan"
    set res [db:query "DELETE FROM levels WHERE cid=$tcid"]
    catch { db:query "SELECT count(*) FROM trakka" } err
    if {$err ne "no such table: trakka"} {
        # -- trakka loaded
        debug 0 "userdb:cmd:remchan: removing all trakka entries from chan $rchan"
        db:query "DELETE FROM trakka WHERE cid=$tcid";
    }
    # -- deal with quotes plugin
    catch { db:query "SELECT count(*) FROM quotes" } err
    if {$err ne "no such table: quotes"} {
        # -- quotes plugin loaded
        # -- TODO: schema needs updating to support multi-chan
        debug 3 "userdb:cmd:remchan: deleting quotes from chan: $rchan"
        db:query "DELETE FROM quotes WHERE cid=$tcid";
    }

    # -- delete usernames when they are no longer added to any channels? 
    # -- risky as it could delete users who have not yet been added to other chans
    set rows [db:query "SELECT id FROM users"]
    db:close
    set count 0;
    foreach i $rows {
        set did [lindex $i 0]
        set x [db:get cid levels uid $did]
        if {$x eq ""} {
            # -- user not added anywhere anymore; delete user account
            set tuser [db:get user users id $did]
            userdb:deluser $tuser $did; # -- delete!
            incr count            
        }
    }
    channel remove $rchan; # -- remove chan from eggdrop
    
    if {$count eq 1} { set txt "user" } else { set txt "users" }
    reply $type $target "done. $rchan has \002disintegrated\002. $count users also deleted."
     
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: modchan
# modify a channel setting
proc userdb:cmd:modchan {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg
    variable dbchans; # -- dict to store channel db data
    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    
    set cmd "modchan"

    # -- ensure user has required access for command
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- determine channel
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#" || $first eq "*"} {
        lassign $arg chan ttype; set value [lrange $arg 2 end]
    } else {
        if {$type ne "pub"} { set chan [userdb:get:chan $user $chan]; }; # -- predict chan when not given
        set ttype [lindex $arg 0]; set value [lrange $arg 1 end]
    }
    set cid [db:get id channels chan $chan]
    set lchan [string tolower $chan]
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }

    # -- command: modchan
    set usage 0
    if {$ttype eq "" || $value eq ""} { set usage 1 }

    #if {$ttype ni "mode url desc autotopic strictop strictvoice"} { set usage 1 }

    if {[string match "m*" $ttype]} { set ttype "mode" } \
    elseif {[string match "u*" $ttype]} { set ttype "url" } \
    elseif {[string match "a*" $ttype] || [string match "top*" $ttype]} { set ttype "autotopic" } \
    elseif {[string match "d*" $ttype]} { set ttype "desc" } \
    elseif {[string match "stricto*" $ttype]} { set ttype "strictop" } \
    elseif {[string match "strictv*" $ttype]} { set ttype "strictvoice" } \
    elseif {[string match "trak*" $ttype]} { set ttype "trakka" } \
    elseif {[string match "oper*" $ttype]} { set ttype "operop" } \
    elseif {$ttype eq "quote"} { set ttype "quote" } \
    elseif {$ttype eq "quoterand"} { set ttype "quoterand" } \
    elseif {$ttype eq "tweet"} { set ttype "tweet" } \
    elseif {$ttype eq "tweetquote"} { set ttype "tweetquote" } \
    else { set usage 1 }
    
    if {$usage} {
        reply $stype $starget "\002usage:\002 modchan ?<chan|*> <mode|url|desc|autotopic|strictop|strictvoice|trakka|operop|quote|quoterand|tweet|tweetquote> <value>";
        return;
    }

    # -- check if chan already exists
    lassign [db:get chan,id channels chan $chan] tchan cid
    if {$tchan eq ""} {
        reply $type $target "error: channel $chan is not registered."
        return;
    }
    set chan $tchan; # -- ensure correct case
    
    # -- modify the chan setting!
    set lvalue [string tolower $value]
    set db_value [string tolower $value]
    set ltype $ttype
    
    if {$ttype in "strictop strictvoice trakka operop"} {
        set value $lvalue
        if {$lvalue ne "on" && $lvalue ne "off"} {
            reply $type $target "\002(\002error\002)\002 value must be: on or off."
            return;
        }
    } elseif {$ttype eq "mode"} {
        set value $lvalue
        if {$lvalue ne "on" && $lvalue ne "off" && $lvalue ne "secure"} {
            reply $type $target "\002(\002error\002)\002 value must be: on, off, or secure. try: \002help mode\002"
            return;
        }
    } elseif {$ttype in "desc"} {
        set ltype "description"
    } elseif {$ttype in "autotopic"} {
        reply $type $target "\002(\002error\002)\002 not yet implemented."
        return;    
    }
    
    set cvalue [db:get value settings cid $cid setting $ttype]
    if {[string tolower $cvalue] eq $lvalue} { reply $type $target "$ltype is already $cvalue."; return; }
    # -- update the setting!
    db:connect
    if {$cvalue eq ""} { db:query "INSERT INTO settings (cid,setting,value) VALUES($cid,'$ttype','[db:escape $value]')" } \
    else { db:query "UPDATE settings SET value='$value' WHERE cid=$cid AND setting='$ttype'" }
    db:close
    
    dict set dbchans $cid $ttype $value; # -- update the setting in dict
    
    debug 1 "userdb:cmd:modchan: modified channel $chan setting (setting: $ttype -- value: $value -- user: $user)"

    reply $type $target "done."
 
    # -- create log entry for command use
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: access
# lookup a user's channel access
proc userdb:cmd:access {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "access"

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- determine channel
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#" || $first eq "*"} {
        lassign $arg tchan trguser
    } else {
        if {$type ne "pub"} { set chan [userdb:get:chan $user $chan]; }
        lassign $arg trguser 
        set tchan $chan
    }

    if {$first eq "*"} { set cid 1 } else { set cid [db:get id channels chan $tchan] }
    set lchan [string tolower $tchan]
    set log "$tchan [join $arg]"; set log [string trimright $log " "]

    # -- command: access
    if {$trguser eq ""} {
        reply $stype $starget "\002usage:\002 access ?chan? <user>";
        return;
    }

    # -- check if user exists
    lassign [db:get user,id users user $trguser] tuser tuid
    if {$tuser eq ""} {
        reply $type $target "\002error:\002 user $trguser does not exist."
        return;
    }
    
    if {$cid eq ""} {
        reply $type $target "\002error:\002 channel $tchan does not exist."
        return;
    }
    
    # -- try channel first
    lassign [db:get level,automode,added_ts,added_bywho,modif_ts,modif_bywho levels uid $tuid cid $cid] \
        tlevel automode added_ts added_bywho modif_ts modif_bywho
    if {$tlevel eq ""} {
        # -- try global
        lassign [db:get level,automode,added_ts,added_bywho,modif_ts,modif_bywho levels uid $tuid cid 1] \
        tlevel automode added_ts added_bywho modif_ts modif_bywho
        if {$tlevel eq ""} {
            reply $type $target "error: user $tuser is not in the $tchan userlist.";
            return;
        } else {
            set tchan *; set cid 1
        }
    }
    
    switch -- $automode {
        none    { set automode "0"; set automodew "none"; }
        0       { set automode "0"; set automodew "none"; }
        1       { set automode "1"; set automodew "voice"; }
        voice   { set automode "1"; set automodew "voice"; }
        2       { set automode "2"; set automodew "op"; }
        op      { set automode "2"; set automodew "op"; }
        default { reply $stype $starget "\002(\002error\002)\002 bogus automode DB value for $tuser in $tchan"; return; }
    }

    debug 1 "userdb:cmd:access: access lookup (chan: $tchan -- user: $tuser -- level: $tlevel -- automode: $automode)"
    
    set ago_added [userdb:timeago $added_ts]
    set ago_modif [userdb:timeago $modif_ts]
    
    reply $type $target "\002chan:\002 $tchan -- \002user:\002 $tuser -- \002level:\002 $tlevel -- \002automode:\002 $automodew"
    reply $type $target "\002added by:\002 $added_bywho -- \002when:\002 $ago_added ago"
    if {$modif_ts ne $added_ts} {
        reply $type $target "\002last modified by:\002 $modif_bywho -- \002when:\002 $ago_modif ago"
    }
    
    # -- check for greeting
    set greet [db:get greet greets cid $cid uid $tuid]
    if {$greet ne ""} { reply $type $target "\002greeting:\002 [join $greet]" }
            
    # -- create log entry for command use
    log:cmdlog BOT $tchan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: register
# self register new user account
proc userdb:cmd:register {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable dbusers;         # -- dict to store users
    variable selfregister;    # -- the data for a username self-registration:
                              #            coro,$nick:    the coroutine for a nickname
    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "register"
    
    # -- are self-registrations allowed?
    if {![cfg:get register *]} { return; }

    # -- only continue if enabled and user is in optionally configured chanlist
    set cont 0
    foreach tchan [channels] {
        if {[cfg:get register:inchan $chan] eq ""} { set cont 1; break; }; # -- check if allowed from any chan
        if {[onchan $nick $tchan] && [string tolower $tchan] in [string tolower [cfg:get register:inchan $chan]]} { set cont 1; break; }
    }
    if {!$cont} { return; }
    
    # -- ensure user has required access for command
    lassign [db:get id,user users curnick $nick] uid user
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    # -- end default proc template
    
    set tuser [lindex $arg 0]    
    if {$tuser eq ""} {
        reply $stype $starget "\002usage:\002 register <user>";
        return;
    }
    
    if {$user ne ""} {
        reply $type $target "\002(\002error\002)\002 you are already authenticated ($user)";
        return;    
    }
    
    # -- valid username?
    if {![regexp -- {^[A-Za-z0-9_]{1,15}$} $tuser]} {
        reply $type $target "\002(\002error\002)\002 bogus username. (1-15 alphanumeric chars only)";
        return;
    }

    # -- check if target user exists
    if {[userdb:isValiduser $tuser]} {
        reply $type $target "\002(\002error\002)\002 [userdb:user:get user user $tuser] already exists";
        return;
    }
    
    # -- reserved usernames 
    # -- helps with internal bot stats recollection (cmd: report)
    set ltuser [string tolower $tuser]
    if {$ltuser eq "bot" || $ltuser eq "usernames" || $ltuser eq [string tolower ${botnet-nick}] \
        || $ltuser eq [string tolower $botnick] || $ltuser eq $uservar} { 
        reply $type $target "\002(\002error\002)\002 reserved username.";
        return;
    }

    # -- do some ircd dependant handling
    if {[cfg:get ircd *] eq 1} {
        # -- ircu (Undernet/Quakenet)
        #reply $type $target "looking up account.."
    
        # -- attempt account lookup via /WHO on nick
        set selfregister(coro,$nick) [info coroutine]
        putquick "WHO $nick n%nuhiat,103"
        
        set xuser [yield];              # -- obtain results from /WHO
        unset selfregister(coro,$nick); # -- clear coro from memory
        
        if {$xuser eq "0" || $xuser eq ""} {
            # -- not authed
            reply $type $target "\002(\002error\002)\002 please authenticate to your network service first."
            return;
        }

        lassign [db:get user,xuser users xuser $xuser] dbuser dbxuser
        if {$dbxuser ne ""} {
            # -- account alrady associated with a username
            reply $type $target "\002(\002error\002)\002 account is already associated with an existing user ($dbuser)."
            return;        
        }
        set encpass ""; # -- no default password
    } else {
        # -- ircd does not support ACCOUNT
        set xuser ""
        set newpass [randpass];                # -- random password
        set encpass [userdb:encrypt $newpass]; # -- hashed random password
    }

    # -- what global level to use?
    set newlevel [cfg:get register:level $chan]

    # -- add the user
    db:connect
    set db_user [db:escape $tuser]
    set db_xuser [db:escape $xuser]
    set reg_ts [unixtime]
    set reg_by [db:escape "$nick!$uh ($tuser)"]
    db:query "INSERT INTO users (user,xuser,pass,register_ts,register_by) VALUES ('$db_user', '$db_xuser', '$encpass','$reg_ts','$reg_by')"
    set userid [db:last:rowid]

    # -- store in dbusers dict
    dict set dbusers $userid [list user $tuser account $xuser pass $encpass register_ts $reg_ts register_by $reg_by \
        email "" languages "" curnick "" curhost "" lastnick "" lasthost "" lastseen ""]

    if {$newlevel eq 0 || $newlevel eq ""} {
        set newlevel "none"
    } else {
        # -- insert global access
        set added_ts [unixtime]
        set added_bywho [db:escape "$nick!$uh (self-register)"]
        db:query "INSERT INTO levels (cid,uid,level,added_ts,added_bywho,modif_ts,modif_bywho) \
            VALUES (1,$userid,$newlevel,$added_ts,'$added_bywho',$added_ts,'$added_bywho')"
    }
            
    debug 0 "userdb:cmd:register: user self-registration by nick: $nick (user: $tuser -- id: $userid -- account: $xuser -- globlevel: $newlevel)"
    
    if {$xuser ne ""} {
        reply $type $target "registered user $tuser (\002uid:\002 $userid \002account:\002 $xuser)"
    } else {
        reply $type $target "registered user $tuser. check /notice for temporary password \002(\002uid:\002 $userid\002)\002"
        reply notc $target "temporary password is '$newpass' -- to change, do /msg $botnick newpass <newpassword>"
    }

    # -- send a note to managers?
    if {[cfg:get note $chan] && [cfg:get note:register $chan]} {
        set note "$nick![getchanhost $nick] has registered a new username (\002user:\002 $tuser -- \002account:\002 $xuser)"
        db:connect
        set mgrids [db:query "SELECT uid FROM levels WHERE cid=1 AND level=500"]
        foreach mgrid $mgrids {
            lassign [db:get user,curnick users id $mgrid] mgruser mgrnick
            if {$mgrnick eq $nick} { continue; }; # -- don't send note to self
            # -- notify the recipient if online
            set read "N"
            set online 0;
            if {$mgrnick != ""} {
                # -- recipient is online
                # -- insert note as read if they're already online and get the /notice
                set read "Y"; set online 1;
            }
            
            set db_note [db:escape $note]
            db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, read, note) \
                    VALUES ('[clock seconds]', '$user', '$userid', '$mgruser', '$mgrid', '$read', '$db_note')"
            set rowid [db:last:rowid]
            db:close
            if {$online} {
                putquick "NOTICE $mgrnick :(\002note\002 from $tuser -- \002id:\002 $rowid): $note"
                debug 0 "userdb:cmd:adduser: notified $mgruser ($mgrnick![getchanhost $mgrnick]) that $nick!$uhost registered user: $usernames"
            }
        }
    }

    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: newuser
# create new user account
proc userdb:cmd:newuser {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable dbusers; # -- dict to store users
    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "newuser"
    
    # -- ensure user has required access for command
    lassign [db:get id,user users curnick $nick] uid user
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    # -- end default proc template

    set trguser [lindex $arg 0]    
    # -- do some ircd dependant syntax handling
    set ircd [cfg:get ircd *]
    if {$ircd eq 1} {
        # -- ircu (Undernet/Quakenet)
        set trgxuser [lindex $arg 1]
        set globlvl [lindex $arg 2]
        if {$trguser eq "" || $trgxuser eq ""} {
            reply $stype $starget "\002usage:\002 newuser <user> <xuser> \[globlevel\]";
            return;
        }
        set encpass ""; # -- do not set a temporary password
    } elseif {$ircd eq 2} {
        # -- IRCnet/EFnet
        set globlvl [lindex $arg 1]
        set trgxuser ""
        if {$trguser eq ""} {
            reply $stype $starget "\002usage:\002 newuser <user> \[globlevel\]";
            return;
        }
        # -- generate a password
        set genpass [randpass]; # -- default length from config, and chars from proc
        # -- encrypt given pass
        set encpass [userdb:encrypt $genpass]
    }
    
    if {$globlvl ne ""} {
        # -- check they have the access
        set sgloblvl [db:get level levels uid $uid cid 1]
        if {$sgloblvl eq ""} { set sgloblvl 0 }
        if {$globlvl >= $sgloblvl} {
            reply $type $target "\002(\002error\002)\002 global access level must be below your own ($sgloblvl)."
            return;
        }
    } else {
        set globlvl [cfg:get register:level $chan]; # -- default newuser global level
    }; 
    
    # -- valid username?
    if {![regexp -- {^[A-Za-z0-9_]{1,15}$} $trguser]} {
        reply $type $target "\002(\002error\002)\002 bogus username. (1-15 alphanumeric chars only)";
        return;
    }

    # -- check if target user exists
    if {[userdb:isValiduser $trguser]} {
        reply $type $target "\002(\002error\002)\002 [userdb:user:get user user $trguser] already exists";
        return;
    }
    
    # -- reserved usernames 
    # -- helps with internal bot stats recollection (cmd: report)
    if {[string tolower $trguser] eq "bot" || [string tolower $trguser] eq "usernames" || [string tolower $trguser] eq [string tolower ${botnet-nick}] \
        || [string tolower $trguser] eq [string tolower $botnick] || [string tolower $trguser] eq $uservar} { 
        reply $type $target "\002(\002error\002)\002 reserved username.";
        return;
    }

    # -- check level
    if {![userdb:isInteger $globlvl]} { reply $type $target "valid levels: 1-500"; return; }
    set level [userdb:get:level $user *]
    if {$globlvl >= $level} { reply $type $target "error: cannot add a user with a level equal to or above your own."; return; }
    
    # -- check it xuser is already assigned to a user
    set xuser [userdb:user:get xuser xuser $trgxuser]
    if {$xuser ne ""} {
        reply $type $target "\002error:\002 network account \002$xuser\002 is already associated with user: \002[userdb:user:get user xuser $xuser]\002";
        return;
    }

    # -- add the user
    db:connect
    set db_user [db:escape $trguser]
    set db_xuser [db:escape $trgxuser]
    set reg_ts [unixtime]
    set reg_by [db:escape "$nick!$uh ($user)"]
    db:query "INSERT INTO users (user,xuser,pass,register_ts,register_by) VALUES ('$db_user', '$db_xuser', '$encpass','$reg_ts','$reg_by')"
    set userid [db:last:rowid]

    # -- store in dbusers dict
    dict set dbusers $userid [list user $trguser account $trgxuser pass $encpass register_ts $reg_ts register_by $reg_by \
        email "" languages "" curnick "" curhost "" lastnick "" lasthost "" lastseen ""]
    if {$globlvl eq 0} {
        set globlvl "none"
    } else {
        # -- add global access
        set added_ts [unixtime]
        db:query "INSERT INTO levels (cid,uid,level,added_ts,added_bywho,modif_ts,modif_bywho) \
            VALUES (1,$userid,$globlvl,$added_ts,$uid,$added_ts,$uid)"
    }
            
    debug 1 "userdb:cmd:newuser: created user: $trguser (id: $userid -- xuser: $trgxuser -- level: $globlvl)"
    
    if {$trgxuser ne ""} {
        reply $type $target "created user $trguser \002(uid:\002 $userid -- \002account:\002 $trgxuser -- \002global level:\002 $globlvl)\002"
    } else {
        reply $type $target "created user $trguser \002(uid:\002 $userid -- \002global level:\002 $globlvl)\002 -- temporary password sent via /notice."
        reply $stype $starget "note: temporary password for user $trguser is: $genpass"
    }
    
    # -- attempt autologin via /WHO on xuser
    if {$trgxuser ne ""} {
        putquick "WHO $trgxuser a%nuhiat,101"
    }
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- command: deluser
# deletes a user account
proc userdb:cmd:deluser {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick botnet-nick uservar
    variable dbusers; # -- dict to store users
    
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "deluser"
    
    # -- ensure user has required access for command
    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]; # -- find a logical chan
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; };
    # -- end default proc template

    set trguser [lindex $arg 0]

    if {$trguser eq ""} {
        reply $stype $starget "\002usage:\002 deluser <user> -force";
        return;
    }
    
    lassign [db:get id,user users user $trguser] tuid tuser
    if {$tuid eq ""} {
        reply $type $target "\002error:\002 no such user.";
        return;
    }
        
    # -- they can only delete username if:
    #        - the user has no channel access (incl. global)
    #             OR
    #        - the user only has access in a channel with this person; AND
    #        - that access is less than the deleter
    #
    # -- if user has multiple channel accesses; conditions must be met in all
    
    set allow 1;
    db:connect
    set rows [db:query "SELECT cid,level FROM levels WHERE uid=$tuid"]
    foreach row $rows {
        # -- iterate over the channel accesses; compare to the deleter's access there
        lassign $row cid targetlvl
        set deleterlvl [db:get level levels cid $cid uid $uid]
        if {$targetlvl >= $deleterlvl} { set allow 0; break; }; # -- target has equal or higher access! disallow deletion
    }
    if {!$allow} {
        # -- deletion disallowed
        reply $type $target "nope. user is out of your reach."
        return;
    }
    
    set isforce [lindex $arg 1]
    if {[string tolower $isforce] ne "-force"} {
        reply $type $target "\002woah!\002 are you sure you want to vanquish this username from the universe? add -force if so."
        return;
    }

    userdb:deluser $tuser $tuid; # -- delete the actual user

    reply $type $target "done. user \002$tuser\002 has been eradicated \002(uid:\002 $tuid)\002"
    
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}


# -- command: verify
# verify a user is authenticated
proc userdb:cmd:verify {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "verify"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }

    # -- command: verify

    set trgnick [lindex $arg 0]

    if {$trgnick eq ""} { reply $stype $starget "\002usage:\002 verify <nick>"; return; }
        
    set tuser [userdb:user:get user nick $trgnick]
    lassign [db:get user,id users curnick $nick] user uid

    # -- ensure target user exists
    if {$tuser eq ""} { 
        reply $type $target "$trgnick is not authenticated.";
    } else {
        reply $type $target "[join [userdb:user:get nick nick $trgnick]] is authenticated as $tuser (\002level:\002 [userdb:get:level $tuser $chan])"
    }
    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
        
}

# -- public login command
proc userdb:pub:login {nick uhost hand chan arg} {
    if {[userdb:isLogin $nick]} {
        # -- already logged in
        reply pub $chan "uhh, you are already authenticated."
        return;
    }
    debug 0 "\002userdb:pub:login\002: started.. sending /WHOIS $nick"
    # -- attempt autologin
    putquick "WHOIS $nick"
}

# -- command: login
# login <user> <passphrase>
proc userdb:msg:login {nick uhost hand arg} {
    set user [join [lindex $arg 0]]
    set pass [join [lrange $arg 1 end]]
    if {$user eq "" && $pass eq ""} { 
        # -- TODO: make it configurable to allow self login
        putquick "WHOIS $nick"
        #reply notc $nick "\002usage:\002 login <user> <passphrase>"; 
        return;
    }

    if {$user eq "" || $pass eq ""} { 
        reply notc $nick "\002usage:\002 login \[user\] \[passphrase\]"; 
        return;
    }
    
    # -- check if user exists
    if {![userdb:isValiduser $user]} { reply notc $nick "\002(\002error\002)\002 who is $user?"; return; }
    
    # -- for security, we should only allow this if the client is in a common channel
    if {![onchan $nick]} {
        # -- client isn't on a common channel
        reply notc $nick "login failed. please join a common channel."
        return;
    }
    
    set cmd "login"
    
    # -- encrypt given pass
    set encrypt [userdb:encrypt $pass]
    
    # -- check against user
    set storepass [userdb:user:get pass user $user]
    
    # -- get correct case for user
    set user [userdb:user:get user user $user]
    
    # -- fail if password is blank
    if {$storepass eq ""} { 
        reply notc $nick "error: no password set for user $user -- please use autologin, and set password with: \002newpass\002"
        return;
    }
        
    # -- match encrypted passwords
    if {$encrypt eq $storepass} {
        # -- match successful, login
        debug 0 "userdb:msg:login: password match for $user, login successful"
        userdb:login $nick $uhost $user 1;  # -- send to common login code
                
        # -- create log entry for command use
        log:cmdlog BOT * 1 $user [userdb:user:get id curnick $nick] [string toupper $cmd] $user $nick!$uhost "" "" ""
        return;
    } else {
        # -- no password match
        debug 0 "userdb:msg:login password mismatch for $user, login failed"
        reply notc $nick "login failed."
    }
}

# -- command: moduser
# modifies existing user account
proc userdb:cmd:moduser {0 1 2 3 {4 ""}  {5 ""}} {
    global botnick
    variable dbusers; # -- dict to store users
    variable code2lang
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "moduser"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template
    
    # -- command: moduser
    
    # -- check for channel
    set first [lindex $arg 0]
    if {[string index $first 0] eq "#" || [string index $first 0] eq "*"} {
        set chan $first; set tuser [lindex $arg 1]; set ttype [lindex $arg 2]; set tvalue [lrange $arg 3 end]
    } else {
        set chan [userdb:get:chan $user $chan]; # -- determine chan
        set tuser [lindex $arg 0]; set ttype [lindex $arg 1]; set tvalue [lrange $arg 2 end]
    }
    set cid [db:get id channels chan $chan]
    set log "$chan [join $arg]"; set log [string trimright $log " "]
    
    # -- parse type
    set usage 0
    if {[cfg:get greet:self *]} { append xtra "|greet" }
    if {[string match "le*" $ttype] || [string match "lvl" $ttype] || [string match "access" $ttype]} { set ttype "level" } \
    elseif {[string match "au*" $ttype] || [string match "m*" $ttype]} { set ttype "automode" } \
    elseif {[string match "g*" $ttype] || [string match "w*" $ttype]} { set ttype "greet" } \
    elseif {[string match "x*" $ttype] || [string match "account" $ttype]} { set ttype "account" } \
    elseif {[string match "p*" $ttype]} { set ttype "password" } \
    else { set usage 1 }
    
    if {[llength $arg] < 3 && $ttype ne "password"} { set usage 1 }
    
    if {$usage} {
        reply $stype $target "\002usage:\002 moduser ?<chan|*>? <user> <level|automode|account|pass$xtra> <value>"
        return;
    }

    lassign [db:get id,chan channels chan $chan] cid chan;   # -- channel id (must come from db due to *)
    lassign [db:get id,user,curnick users user $tuser] tuid tuser tcurnick;  # -- get target user id and correct case username
    if {$tuid eq ""} { reply $type $target "\002(\002error\002)\002 who is $tuser?"; return; }
    
    set level [db:get level levels uid $uid cid $cid];       # -- level for source user
    set globlevel [db:get level levels uid $uid cid 1];      # -- level for source user
    set tlevel [db:get level levels uid $tuid cid $cid];     # -- glob level for target user
    set tgloblevel [db:get level levels uid $tuid cid 1];    # -- glob level for target user
    
    # -- only complain about missing access if not user centric attribute modification.
    if {$tlevel eq ""} {
        if {($ttype ne "pass" && $ttype ne "email" && $ttype ne "lang" && $ttype ne "greet" && $ttype ne "account")} {
            reply $type $target "\002(\002error\002)\002 user \002$tuser\002 has no access on $chan.";
            return;
        }
    }
    
    if {$tlevel >= $level && $globlevel ne 500 && $chan ne "*"} {
        # -- allow user to change own password && automode if level>=100
        if {[string tolower $tuser] eq [string tolower $user]} {
            if {($ttype ne "pass" && $ttype ne "automode" && $ttype ne "email" && $ttype ne "lang" && $ttype ne "greet")} {
                reply $type $target "\002(\002error\002)\002 cannot modify user $ttype (target level equal to or above your own)";  
                return;
            }
        }
    }
    
    if {$ttype eq "account"} {
        # -- modifying account (X username in GNUWorld)
        set tvalue [lindex $tvalue 0]
        if {$tlevel >= $level && $globlevel ne 500} {
            reply $type $target "\002(\002error\002)\002 cannot modify user $ttype (target level equal to or above your own)";
            return;
        }
        set eaccount [db:get xuser users user $tuser]
        if {[string match -nocase $eaccount $tvalue]} {
            reply $type $target "\002error:\002 what's the point?";
            return;
        }
        lassign [db:get user,xuser users xuser $tvalue] euser eaccount
        if {$euser ne ""} {
            reply $type $target "\002error:\002 user (\002$euser\002) already exists with account $eaccount.";
            return;        
        }
        # -- do the update!
        set db_tvalue [db:escape $tvalue]
        db:connect
        db:query "UPDATE users SET xuser='$db_tvalue' WHERE lower(user)='[string tolower $tuser]'"
        db:close
        dict set dbusers $tuid account $tvalue
    }
        
    if {$ttype eq "level"} {
        # -- modifying level
        set tvalue [lindex $tvalue 0]
        if {![regexp -- {^\d+$} $tvalue]} { reply $type $target "\002(\002error\002)\002 valid levels: 1-500"; return; }
        if {$tvalue < 1 || $tvalue > 500} { reply $type $target "\002(\002error\002)\002 valid levels: 1-500"; return; }
        if {$tvalue >= $level && $globlevel ne 500 && $chan ne "*"} {
            reply $type $target "\002(\002error\002)\002 cannot modify to a level at or above your own.";
            return;
        }
        if {$tvalue eq $tlevel} { reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
        # -- make the change
        db:connect
        set query [db:query "UPDATE levels SET level='$tvalue' WHERE cid=$cid AND uid=$tuid"]
        db:close
        
        # -- send a note to the user?
        if {[cfg:get note $chan] && [cfg:get note:level $chan]} {
            set note "Your access to $chan has been modified by $user (\002level:\002 $tvalue)"
            # -- notify the recipient if online
            set read "N"
            set to_nick [join [join [db:get curnick users user $tuser]]]
            set online 0;
            if {$to_nick ne ""} {
                # -- recipient is online
                # -- insert note as read if they're already online and get the /notice
                set read "Y"; set online 1;
            }
            db:connect
            set db_note [db:escape $note]
            db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, read, note) \
                    VALUES ('[clock seconds]', '$user', '$uid', '$tuser', '$tuid', '$read', '$db_note')"
            set rowid [db:last:rowid]
            db:close
            if {$online} {
                putquick "NOTICE $to_nick :(\002note\002 from $user -- \002id:\002 $rowid): $note"
                debug 0 "userdb:cmd:moduser: notified $tuser ($to_nick![getchanhost $to_nick]) that their access has been modified by $user (level $tvalue)"
            }
        }
        
    }
    
    if {$ttype eq "automode"} {
        # -- modifying automode
        set tvalue [lindex $tvalue 0]
        # -- get current mode
        set tmode [db:get automode levels uid $tuid cid $cid]
        switch -- $tvalue {
            none    { set automode "0"; }
            0       { set automode "0"; }
            1       { set automode "1"; }
            voice   { set automode "1"; }
            2       { set automode "2"; }
            op      { set automode "2"; }
            default { 
                reply $stype $starget "\002(\002error\002)\002 automode should be: none|voice|op";
                return;
            }
        }
        if {$automode eq $tmode} { reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
        # -- make the change
        db:connect
        set query [db:query "UPDATE levels SET automode='$automode' WHERE cid=$cid AND uid=$tuid"]
        db:close
    }
    
    if {$ttype eq "greet" && [cfg:get greet:self *]} {    
        # -- modifying welcome greeting
        set allow 0
        set tvalue [join [lrange $tvalue 0 end]]
        # -- allow user to modify their own
        if {[string tolower $tuser] eq [string tolower $user]} { set allow 1 }
        # -- allow user to modify someone lower than them (provided they are an admin)
        if {$level >= 400 && $level > $tlevel} { set allow 1 }
        if {$allow eq 0} { reply $type $target "\002(\002error\002)\002 insufficient access."; return; }
        if {$tvalue eq ""} {
            # -- delete greeting
            db:connect 
            db:query "DELETE FROM greets WHERE cid=$cid and uid=$uid"
            db:close
        } else {
            # -- check whether to update or insert
            set dbgreet [db:escape $tvalue]
            set res [db:get uid greets uid $tuid cid $cid]
            db:connect
            if {$res eq ""} {
                # -- insert new greeting
                db:query "INSERT INTO greets (cid,uid,greet) VALUES ('$cid','$tuid','$dbgreet')"
            } else {
                # -- update greeting
                db:query "UPDATE greets SET greet='$dbgreet' WHERE uid=$tuid AND cid=$cid"        
            }
            db:close
        }
    }

    if {$ttype eq "password"} {
        # -- modifying password
        if {$tgloblevel >= $globlevel && $globlevel ne 500} {
            reply $type $target "\002(\002error\002)\002 cannot modify password (level equal to or above your own)";  
            return;
        }
        set rand 0;
        if {$tvalue eq ""} {
            set rand 1; set xtra "";
            set newpass [randpass]; # -- random password
            if {$tcurnick ne ""} { set xtra "password sent via /notice" }
        } else { set newpass $tvalue }
        set xtra2 "password is $newpass"
        set encpass [userdb:encrypt $newpass]; # -- hashed random password
        userdb:user:set pass $encpass id $tuid
        dict set dbusers $tuid pass $encpass
        reply $type $target "done. $xtra"
        if {$tcurnick ne ""} {
            reply notc $tcurnick "\002password changed\002 by $nick ($user). to login: \002/msg $botnick login $tuser $newpass\002"
            reply notc $tcurnick "then, to change password: \002/msg $botnick newpass <newpass>\002"
        } else {
            if {$rand} { 
                # -- send random pass tor requestor, as the target isn't authed
                reply notc $nick "random password for $tuser is: $newpass"
            }
        }
        return;
    }

    debug 1 "userdb:cmd:moduser: chan: $chan -- cid: $cid -- tuser: $tuser -- tuid: $tuid --\
            ttype: $ttype -- tvalue: $tvalue (user: $user)"
    reply $type $target "done."
        
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    return;
}

# -- command: set
# changes username settings (for your own user)
proc userdb:cmd:set {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    variable code2lang
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 
    
    set cmd "set"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get id,user users curnick $nick] uid user
    # -- end default proc template

    # -- command: moduser
        
    # -- check for optional chan, but it only applies to setting a greet
    set first [string index [lindex $arg 0] 0]
    if {$first eq "#" || $first eq "*"} {
        lassign $arg chan ttype
        set tvalue [join [lrange $arg 2 end]]
        if {($ttype ne "greet" || [string index $ttype 0] ne "g") \
            && ($ttype ne "automode" && [string match $tvalue "au*"] ne $tvalue)} {
                reply $type $target "\002error:\002 channel only applies to greet and automode. see: \002help set\002"
                return;
        } 
    } else {
        # -- no chan given
        set ttype [lindex $arg 0]
        set tvalue [join [lrange $arg 1 end]]
        set chan [userdb:get:chan $user $chan]; # -- automatically determine the channel if not provided
    }
        
    # -- parse type
    if {[cfg:get greet:self *]} { set xtra "|greet" }
    if {[string match "e*" $ttype]} { set ttype "email" } \
    elseif {[string match "la*" $ttype]} { set ttype "lang" } \
    elseif {[string match "p*" $ttype]} { set ttype "pass" } \
    elseif {[string match "g*" $ttype]} { set ttype "greet" } \
    elseif {[string match "au*" $ttype]} { set ttype "automode" } \
    else {
        reply $stype $starget "\002usage:\002 set ?chan? <lang|email|automode|pass${xtra}> <value>"
        return;
    }
    
    set cid [db:get id channels chan $chan]
    set level [db:get level levels uid $uid cid $cid]
    
    if {$ttype eq "greet"} {
        debug 0 "userdb:cmd:set: user $user ($nick![getchanhost $nick]) set greet (chan: $chan)"
        # -- check whether to update or insert
        set dbgreet [db:escape $tvalue]
        set res [db:get uid greets uid $uid cid $cid]
        db:connect
        if {$res eq ""} {
            # -- insert new greeting
            db:query "INSERT INTO greets (cid,uid,greet) VALUES ('$cid','$uid','$dbgreet')"
        } else {
            # -- update greeting
            db:query "UPDATE greets SET greet='$dbgreet' WHERE uid=$uid AND cid=$cid"        
        }
        db:close
    }
    
    if {$ttype eq "automode"} {
        # -- modifying automode
        set tvalue [lindex $tvalue 0]
        if {$level < 100 && $tvalue eq "op"} {
            reply $stype $starget "\002(\002error\002)\002 automode cannot be set to \002op\002 yourself for level $tlevel.";
        }
        if {$level < 25 && $tvalue eq "voice"} {
            reply $stype $starget "\002(\002error\002)\002 automode cannot be set to \002voice\002 yourself for level $tlevel.";
        }        
        # -- get current mode
        set amode [db:get automode levels uid $uid cid $cid]
        switch -- $tvalue {
            none    { set automode "0"; }
            0       { set automode "0"; }
            1       { set automode "1"; }
            voice   { set automode "1"; }
            2       { set automode "2"; }
            op      { set automode "2"; }
            default { 
                reply $stype $starget "\002(\002error\002)\002 automode should be: none|voice|op";
                return;
            }
        }
        if {$automode eq $amode} { reply $type $target "\002(\002error\002)\002 what's the point?"; return; }
        # -- make the change
        db:connect
        set query [db:query "UPDATE levels SET automode='$automode' WHERE cid=$cid AND uid=$uid"]
        db:close
    }
           
    if {$ttype eq "pass"} { 
        set encpass [userdb:encrypt $tvalue];     # -- encrypt password
        debug 0 "userdb:cmd:set: user $user ($nick![getchanhost $nick]) set password"
        userdb:user:set pass $encpass user $user; # -- make the change
    }
        
    if {$ttype eq "email"} {    
        # -- modifying e-mail address
        set tvalue [lindex $tvalue 0]
        # -- validate e-mail address
        if {![regexp -nocase {^[A-Za-z0-9\._%+-]+@[A-Za-z0-9\._%+-]+$} $tvalue]} { reply $type $target "\002(\002error\002)\002 invalid e-mail address."; return; }
        # -- make the change
        debug 0 "userdb:cmd:set: user $user ($nick![getchanhost $nick]) set email=$tvalue"
        userdb:user:set email $tvalue user $user
    }
    
    if {$ttype eq "lang"} { 
        # -- modifying languages
        # note: first one should be 'primary' in case language support is added later

        # -- validate language list (should be two char codes separated by space or comma)
        if {![regexp -- {^(?:[A-Za-z]{2}[,\s]?)+$} $tvalue]} {
            reply $type $target "\002(\002error\002)\002 invalid language list. used two character language codes, space or comma delimited."
            return;
        }
        set langlist [string trimright $tvalue " "]
        # -- replace commas with space
        regsub -all {,} $langlist { } langlist
        
        # -- ensure the language is valid from our table
        foreach lang $langlist {
            if {![info exists code2lang([string tolower $lang])]} {
                reply $type $target "language [string toupper $lang] unknown."
                return;
            }
        }
        
        set langlist [string toupper $langlist]
        # -- make the change
        debug 0 "userdb:cmd:set: user $user ($nick![getchanhost $nick]) set languages=$tvalue"
        userdb:user:set languages $langlist user $user
    }
        
    reply $type $target "done."
    # -- create log entry for command use
    if {$ttype ne "pass"} {
        set output [join $arg]
    } else {
        # -- don't reveal the password
        set output "pass"
    }
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
    return;
    
}

# -- command: logout
# logout <user> <passphrase>
proc userdb:msg:logout {nick uhost hand arg} {
    set cmd "logout"
    set tuser [lindex $arg 0]
    set pass [lrange $arg 1 end]

    lassign [db:get id,curnick,user users curnick $nick] uid curnick user

    # -- track whether self logout or needs a pass
    set self 0;

    if {$tuser ne ""} {
        # -- client wants to logout a specific user (probably someone else)
        if {[string match -nocase $tuser $user]} {
            # -- user is themselves
            set self 1
        } else {
            # -- user is someone else
            if {![userdb:isValiduser $tuser]} { reply notc $nick "\002(\002error\002)\002 who is $tuser?"; return; }

            # -- allow remote logout without password, if user is global level 500
            set glevel [db:get level levels uid $uid cid 1]
            if {$glevel >= 500} {
                # -- bot master, allow without password
                lassign [db:get id,curnick,curhost users user $tuser] tuid tcurnick tcurhost
                if {$tcurnick eq ""} {
                    reply notc $nick "user $tuser is not authed."; 
                    return;
                }
                debug 0 "userdb:msg:logout: successful forced logout of $tuser by $user ($nick!$uhost)"
                userdb:logout $tcurnick $tcurhost; # -- send to common logout code
                reply notc $nick "successful logout for user $tuser.";     
                if {[onchan $tcurnick]} {
                    reply notc $tcurnick "forced logout by user $user.";     
                }
                log:cmdlog BOT * 1 $tuser $tuid [string toupper $cmd] $user "$nick!$uhost" "" "" ""    
                return;
            } else {
                # -- not a bot master, requires a password
                if {$pass eq ""} { reply notc $nick "\002usage:\002 logout \[user\] \[passphrase\]"; return; }
            }
        }
    } else { 
        # -- self logout
        set tuser $user
        set self 1;
    }

    # -- check against user
    lassign [db:get id,user,curnick,pass users user $tuser] tuid tuser tcurnick storepass
    
    if {$self eq 0} {
        # -- logout for another user
        if {$tcurnick eq ""} {
            reply notc $nick "user $tuser is not authed."; 
            return;
        }
        # -- encrypt given pass
        set encrypt [userdb:encrypt $pass]
    
        # -- match encrypted passwords
        if {$encrypt eq $storepass} {
            # -- match successful, login
            debug 0 "userdb:msg:logout: password match for $tuser, logout successful"
            set tnick $tnick
            userdb:logout $nick $uhost; # -- send to common logout code
        } else {
            # -- no password match
            debug 0 "userdb:msg:logout password mismatch for user: $tuser, logout failed ($nick!$uhost)"
            reply notc $nick "logout failed."        
            return;    
        }

    } else {
        # -- self logout, no password required
        if {$tcurnick eq ""} {
            reply notc $nick "not currently authenticated."; 
            return;
        }
        debug 0 "userdb:msg:logout: password match for $tuser, logout successful"
        set tnick $nick
    }

    userdb:logout $tnick $uhost; # -- send to common logout code    
    reply notc $nick "logout successful.";             
    log:cmdlog BOT * 1 $tuser $tuid [string toupper $cmd] $tuser "$nick!$uhost" "" "" ""     
    return;
    
}


# -- command: newpass
# newpass <passphrase>
proc userdb:msg:newpass {nick uhost hand arg} {
    set cmd "newpass"
    set newpass [lrange $arg 0 end]
    if {$newpass eq ""} { reply notc $nick "\002usage:\002 newpass <passphrase>"; return; }
    
    # -- check if user is logged in
    lassign [db:get id,user users curnick $nick] uid user
    if {$user eq ""} { reply notc $nick "\002(\002error\002)\002 perhaps not. login first."; return; }
     
    # -- encrypt given pass
    set encrypt [userdb:encrypt $newpass]
        
    debug 1 "userdb:msg:newpass: updating password for user: $user ($nick!$uhost)"
        
    # -- update lastnick and lasthost
    userdb:user:set pass $encrypt user $user
    reply msg $nick "password changed."; 

    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] "" "$nick!$uhost" "" "" ""
}

#putlog "\[@\] Armour: loading user database..."


# obtain user db value
# get <item> where <source> = <value>
# example: userdb:user:get user nick Empus
# supports multiple columns in one query: userdb:user:get id,user,email nick Empus
proc userdb:user:get {item source value {silent ""}} {
    # -- safety net
    if {$item eq "" || $source eq "" || $value eq ""} {
        debug 0 "\002(error)\002 userdb:user:get: missing param (item: $item -- source: $source -- value: $value)"
        return;
    }
    
    debug 5 "userdb:user:get: userlist get $item where $source=$value"; # -- TODO: remove debug line
    
    switch -- $item {
        nick { set item "curnick" }
        host { set item "curhost" }
    }
    switch -- $source {
        nick { set source "curnick" }
        host { set source "curhost" }
    }
    
    db:connect
    set dbvalue [db:escape $value]
    set row [db:query "SELECT $item FROM users WHERE lower($source)='[string tolower $dbvalue]'"]
    db:close
    set result [lindex $row 0]; # -- return one value/row
    if {$result eq ""} { set lvl 4 } else { set lvl 3 }
    if {$silent eq ""} { debug $lvl "userdb:user:get: userlist get $item where $source=$value" }
    return $result
}


# -- change user db item
# set <item> = <value> where <source> = <equal>
# example:
# userdb:user:set level 1 userid 10
proc userdb:user:set {item value source equal {silent ""}} {
    # -- item should never be "user"
    if {$item eq "user"} { 
        debug 0 * "\002(error)\002 userdb:user:set: item should not be \'user\'"
        return ""
    }
    db:connect
    set db_item [db:escape $item]
    set db_value [db:escape $value]
    set db_source [db:escape $source]
    set db_equal [db:escape $equal]
    db:query "UPDATE users SET $db_item='$db_value' WHERE lower($db_source)='[string tolower $db_equal]'"
    db:close    
    if {$silent eq ""} { debug 3 "userdb:user:set: userlist set $item=$value where $source=$equal" }
    return;
}

# -- get the level for a user in a channel
# channel defaults to * (global) if not provided
proc userdb:get:level {user {chan ""}} {
    db:connect
    # -- check user first
    if {[regexp -- {^\d+} $user]} {
        # -- userid
        set uid $user
    } else {
        set dbuser [string tolower [db:escape $user]]
        set uid [lindex [db:query "SELECT id FROM users WHERE lower(user)='$dbuser'"] 0]
        if {$uid eq ""} { return 0; }
    }
    set glob 0
    if {$chan eq "" || $chan eq "*"} {
        # -- check global level
        set glob 1
    } else {
        set dbchan [db:escape $chan]
        set cid [lindex [db:query "SELECT id FROM channels WHERE lower(chan)='$dbchan'"] 0]
        if {$cid eq ""} {
            set clevel 0
        } else {
            set clevel [lindex [db:query "SELECT level FROM levels WHERE uid='$uid' AND cid='$cid'"] 0]
        }
    }
    set glevel [lindex [db:query "SELECT level FROM levels WHERE cid='1' AND uid='$uid'"] 0]
    db:close
    if {$glob} {
        # -- only care about global level
        if {$glevel eq ""} { set glevel 0; }
        return $glevel
    } else {
        # -- return the highest
        if {$glevel > $clevel} { return $glevel } else { return $clevel }
    }
}

# -- get the most logical channel for a user, when chan not given
# -- returns the channel with the highest level, else the config default chan, else the channel given
proc userdb:get:chan {user chan} {
    variable dbchans;   # -- dict to store channels
    variable dbusers;   # -- dict to store users

    set cid [dict keys [dict filter $dbchans script {id dictData} { expr {[dict get $dictData chan] eq $chan} }]]
    if {$cid ne ""} { return $chan }; # -- use the chan given, if registered

    set uid [dict keys [dict filter $dbusers script {id dictData} { expr {[dict get $dictData user] eq $user} }]]
    if {$uid eq ""} { return [cfg:get chan:def *] }; # -- return default chan, if user not authed
    

    # -- user is authed and channel not registered
    debug 0 "userdb:get:chan: user $user is authed, but channel $chan is not registered"
    set rows [db:get cid,level levels uid $uid]; # -- GET cid,level FROM levels WHERE uid=<uid>
    set level 0; set chan "";
    foreach row $rows {
        lassign $row cid lvl
        if {$lvl > $level} { set level $lvl; set chan [dict get $dbchans $cid]; }
    }
    if {$chan eq "" || $chan eq "*"} { 
        # -- return default channel
        return [cfg:get chan:def *] 
    } else { 
        return $chan 
    }
}


# -- check if nick is logged in?
proc userdb:isLogin {nick} {
    # -- do this silently (no putloglev in userdb:user:get)
    set user [userdb:user:get user curnick $nick silent]
    if {$user eq ""} { return 0; }
    # -- logged in
    return 1;
}

# -- check if user is valid?
proc userdb:isValiduser {user} {
    # -- do this silently (no putloglev in userdb:user:get)
    set user [userdb:user:get id user $user silent]
    if {$user eq ""} { return 0; }
    # -- validuser
    return 1;
}

# -- encrypt password (basic md5)
proc userdb:encrypt {pass} {
    variable cfg
    switch -- [cfg:get md5 *] {
        md5 { set encrypt [exec md5 -q -s $pass] }
        md5sum { set encrypt [lindex [exec echo $pass | md5sum] 0] }
    }
    return $encrypt;
}


# -- nickname channel join
proc userdb:join {nick uhost hand chan} {
    global botnick userdb
    variable cfg
    variable nickdata
    
    if {$nick eq $botnick} { return; }

    set lnick [string tolower $nick]
    
    # -- check mode if already logged in
    lassign [db:get user,id users curnick $nick] user uid
    set cid [db:get id channels chan $chan]
    if {$user ne ""} { 
        # -- user already logged in
        if {$cid ne ""} {
            # -- get automode
            set automode [db:get automode levels cid $cid uid $uid]
            set gautomode [db:get automode levels cid 1 uid $uid]
            if {$gautomode ne "" && $gautomode > $automode} { set automode $gautomode }; # -- let global chan automode take precedence
            switch -- $automode {
                0 { set return 1; }
                1 { pushmode $chan +v $nick; }
                2 { pushmode $chan +o $nick; }
            }
            flushmode $chan 
            
            # -- check for greet here too, otherwise it only works when not yet logged in
            debug 1 "userdb:join: checking for greet for user: $user ($nick!$uhost) -- chan: $chan"
            userdb:greet $chan $nick $user $uid
        }
    } else {
        # -- nick is not logged in
        # -- check for umode +x
        set host [lindex [split $uhost @] 1]
        set xuser ""
        if {[regexp -- [cfg:get xregex *] $host -> xuser]} {
            # -- user is umode +x
            dict set nickdata $lnick account $xuser; # -- update dict
        } else {
            # -- check if we know the xuser from nickdata
            if {[dict exists nickdata $lnick account]} {
                set xuser [dict get $nickdata $lnick account]
            }
        }
        # -- attempt login
        if {$xuser ne "" && $xuser ne 0} {
            lassign [db:get user,curnick users xuser $xuser] user lognick
            if {$user eq ""} { return; }; # -- no user with this account
            # -- TODO: make replacing prior logins, an optional config feature (if $lognick eq "")
            # -- begin autologin
            debug 1 "userdb:join: autologin begin for $user ($nick!$uhost) -- chan: $chan"
            userdb:login $nick $uhost $user 0 $chan;  # -- use common login code
        }
    }
}

# -- common login code
proc userdb:login {nick uhost user {manual "0"} {chan ""}} {
    variable dbusers; # -- dict to store users in memory

    lassign [db:get id,curnick,curhost users user $user] uid curnick curhost
    
    if {$curnick eq $nick && $manual} { reply msg $nick "uhh, you're already logged in. \002try: logout\002"; return; }
    
    set luser [string tolower $user]
    set lastseen [unixtime]

    db:connect
    set res [db:query "UPDATE users SET curnick='[db:escape $nick]', curhost='$uhost', \
        lastnick='[db:escape $curnick]', lasthost='[db:escape $curhost]', lastseen='$lastseen' WHERE lower(user)='$luser'"]
    db:close

    # -- update dbusers in memory
    dict set dbusers $uid curnick $nick;
    dict set dbusers $uid curhost $uhost;
    dict set dbusers $uid lastnick $curnick;
    dict set dbusers $uid lasthost $curhost;
    dict set dbusers $uid lastseen $lastseen;

        
    if {!$manual} { set ltype "autologin" } else { set ltype "login" }; # -- login type
    lassign [db:get id,pass users user $user] uid dbpass
    
    debug 0 "userdb:login: $ltype successful for user $user ($nick!$uhost) -- uid: $uid -- chan: $chan"
    
    # -- check for notes, if plugin loaded
    if {[lsearch [info commands] "arm:cmd:note"] < 0} {
        # -- notes not loaded
        reply notc $nick "$ltype successful.";
    } else {
        # -- notes loaded
        db:connect
        set count [lindex [join [db:query "SELECT count(*) FROM notes \
            WHERE to_u='$user' AND read='N'"]] 0]
        db:close
        if {$count eq 1} { reply notc $nick "$ltype successful. 1 unread note."; } \
        elseif {$count > 1 || $count eq 0} { reply notc $nick "$ltype successful. $count unread notes."; }
    }
    
    # -- tell them to use newpass if there is no password set
    if {$dbpass eq "" && [info exists cfg(alert:nopass)]} {
        if {[cfg:get alert:nopass *]} {
            reply notc $nick "password not set. use 'newpass' to set a password, before manual logins can work."
        }
    }

    # -- get automode
    db:connect
    set rows [db:query "SELECT cid,automode FROM levels WHERE uid=$uid"]
    foreach row $rows {
        lassign $row cid automode
        set gautomode [db:get automode levels cid 1 uid $uid]
        if {$automode eq "" || ($gautomode ne "" && $gautomode > $automode)} { set automode $gautomode }; # -- let global chan automode take precedence
        if {$chan eq 0 || $chan eq ""} { set tchan [join [db:get chan channels id $cid]] } else { set tchan $chan }; # -- otherwise, use the channel provided
        switch -- $automode {
            0       { continue; }
            1       { set themode "+v"; }
            2       { set themode "+o"; }
            default { continue; }
        }
        debug 3 "userdb:login: sending automode: MODE $tchan $themode $nick"
        putquick "MODE $tchan $themode $nick"
    }
    db:close

    # -- check whether to send channel greeting 
    if {$chan ne 0 && $chan ne ""} { userdb:greet $chan $nick $user $uid } 
    
    # -- update training data after join
    if {[info commands "train:data"] ne "" && $chan ne "" && $chan ne 0} {
        train:debug 2 "userdb:login: $nick!$uhost seen joining $chan"
        # -- send the data to be written
        train:data joins $uid [clock seconds]
    }
}

# -- check whether to send channel greeting
proc userdb:greet {chan nick user uid} {
    if {$uid ne ""} {
        set cid [db:get id channels chan $chan]; # -- reset the cid for the actual joining chan (due to automode code above)
        db:connect
        # -- default to channel greeting first
        if {$cid eq ""} { set cid 0 }; # -- safety net
        set query "SELECT greet FROM greets WHERE uid=$uid AND cid=$cid";
        set greet [join [lindex [db:query $query] 0]]
        db:close
        if {$greet eq ""} {
            # -- try for global greeting
            db:connect
            set query "SELECT greet FROM greets WHERE uid=$uid AND cid=1";
            set greet [join [lindex [db:query $query] 0]]
            db:close        
        }
        if {$greet ne ""} {
            # -- check for variables
            if {[info commands fn:query] ne ""} {
                debug 0 "\002userdb:greet:\002 fortnite tcl loaded"
                # -- fortnite.tcl loaded
                set greet [fn:greet $chan $user $greet]; # -- update with fortnite greet variables
            }
            regsub -all {%B} $greet \x02 greet; # -- bold text
            # -- output the greeting!
            debug 1 "userdb:greet: sending greeting to $nick in $chan"
            putquick "PRIVMSG $chan :\[$nick\] $greet" 
        }
    }
}

# -- common logout code
proc userdb:logout {nick {uhost ""}} {
    variable dbusers; # -- dict to store users in memory
    db:connect
    set lnick [string tolower $nick]
    set row [lindex [db:query "SELECT id,user,curnick,curhost FROM users WHERE lower(curnick)='[db:escape $lnick]'"] 0]
    lassign $row uid user curnick curhost
    if {$user ne ""} {
        # -- log them out
        set lastseen [clock seconds]
        set db_curnick [db:escape $curnick]
        # -- update db
        set res [db:query "UPDATE users SET lastnick='$db_curnick', lasthost='$curhost', lastseen='$lastseen', curnick=null, curhost=null \
            WHERE lower(user)='[string tolower $user]'"]
        
        # -- update dict
        dict set dbusers $uid curnick ""
        dict set dbusers $uid curhost ""
        dict set dbusers $uid lastnick $curnick
        dict set dbusers $uid lasthost $curhost
        dict set dbusers $uid lastseen $lastseen
    }
    db:close    
}

# -- nickname signoff
proc userdb:signoff {nick uhost handle chan {text ""}} {
    # -- send to common proc userdb:unset:vars
    userdb:unset:vars part $nick $uhost $chan
}

# -- nickname channel part
proc userdb:part {nick uhost handle chan {text ""}} {
    # -- send to common proc userdb:unset:vars
    userdb:unset:vars part $nick $uhost $chan
}

# -- nickname kicked from chan
proc userdb:kick {nick uhost handle chan vict reason} {
    # -- send to common proc userdb:unset:vars
    set victuhost [getchanhost $vict]
    userdb:unset:vars kick $vict $victuhost $chan
}

# -- generic handler to unset variables when a client:
# - is kicked
# - quits
# - changes nick
# - parts all common chans
proc userdb:unset:vars {type nick uhost chan} {
    global botnick
    
    if {$nick eq $botnick} {
        # -- still on some channels common with me, leave data
        return;
    }

    variable flood:text;      # -- array to track the lines for a text pattern (by nick,pattern)    
    variable data:ipnicks;    # -- stores a list of nicks on a given IP (by IP,chan)
    variable data:nickip;     # -- stores the IP address for a nickname (by nick)
    variable data:hostnicks;  # -- stores a list of nicks on a given host (by host,chan)
    variable data:nickhost;   # -- stores the hostname for a nickname (by nick)
    variable data:kicks;      # -- stores queue of nicks to kick from a channel (by chan)
    variable scan:list;       # -- the list of nicknames to scan in secure mode:
                              #        leave,*    :  nicks already scanned and left
                              #        nicks,*    :  nicks being scanned
                              #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
    variable data:captcha;    # -- holds captcha data for nick (by nick,chan)  
    variable nick:jointime;   # -- stores the timestamp a nick joined a channel (by chan,nick)
    variable jointime:nick;   # -- stores the nick that joined a channel (by chan,timestamp)
       
    variable nickdata;        # -- dict: stores data against a nickname
                              #           nick
                              #              ident
                              #           host
                              #           ip
                              #           uhost
                              #           rname
                              #           account
                              #           signon
                              #           idle
                              #           idle_ts
                              #           isoper
                              #           chanlist
                              #           chanlist_ts

    set nick [split $nick];
    if {![oncommon $nick $chan]} { dict unset nickdata [string tolower $nick] };  # -- remove dict for nick data
    
    set host [lindex [split $uhost @] 1]
    set lchan [string tolower $chan]

    debug 0 "userdb:unset:vars: $type in $chan for $nick!$uhost"

    # -- remove trackers for the jointime to a channel
    if {[info exists nick:jointime($lchan,$nick)]} {
        set ts [get:val nick:jointime $lchan,$nick]
        if {[info exists jointime:nick($lchan,$ts)]} {
            debug 4 "userdb:unset:vars: $type in $chan removing jointime:nick($lchan,$ts)"
            unset jointime:nick($lchan,$ts)
        }
        debug 4 "userdb:unset:vars: $type in $chan removing nick:jointime($lchan,$nick)"
        unset nick:jointime($lchan,$nick)
    }
        
    # -- scan:list:
    #      data,*  - data list of those being scanned
    #      nicks,* - list of nicks
    #      leave,* - nicks of those already scanned and being left 
    foreach entry [array names scan:list] {
        lassign [split $entry ,] ttype tchan
        if {$tchan ne $chan} { continue; }
        set ltchan [string tolower $tchan]
        if {$ttype in "nicks leave"} {
            set pos [lsearch -exact [get:val scan:list $ttype,$ltchan] $nick]
            if {$pos ne -1} {
                debug 4 "userdb:unset:vars: $type in $chan removing $nick from \$scan:list($ttype,$ltchan)"
                set scan:list($ttype,$ltchan) [lreplace [get:val scan:list $ttype,$ltchan] $pos $pos]
            }
        } elseif {$ttype eq "data"} {
            set x 0
            foreach data [get:val scan:list data,$ltchan] {
                if {[lindex $data $x] eq $nick} {
                    # -- remove entry
                    debug 4 "userdb:unset:vars: $type in $chan removing $nick from \$scan:list(data,$ltchan)"
                    set scan:list(data,$ltchan) [lreplace [get:val scan:list data,$ltchan] $x $x]
                } else {
                    # -- send the next one to the scanner (so we don't have to wait for autologin timer result)
                    lassign $data tsnick tschan tsfull tsclicks tsident tsip tshost tsxuser tsrname
                    scan $tsnick $tschan $tsfull $tsclicks $tsident $tsip $tshost $tsxuser $tsrname
                }
                incr x
            }
        }
    }
    
    # -- remove nick from global kicklist if exists
    if {[info exists data:kicks($lchan)]} {
        set pos [lsearch -exact [get:val data:kicks $lchan] $nick]
        if {$pos ne -1} {
            # -- nick within
            debug 4 "userdb:unset:vars: $type in $chan removing $nick from \$data:kicks($lchan)"
            set data:kicks($lchan) [lreplace [get:val data:kicks $lchan] $pos $pos]
            if {[get:val data:kicks $lchan] eq ""} { unset data:kicks($lchan) }
        }
    }
        
    # -- textflud -- counts of lines matching blacklist text entries, for a nick
    if {[info exists flood:text] && ![oncommon $nick $chan]} {
        foreach i [array names flood:text] {
            set tnick [lindex [split $i ,] 0]
            set tvalue [lindex [split $i ,] 1]
            if {$tnick eq $nick} {
                debug 4 "userdb:unset:vars: $type in $chan removing $nick from \$flood:text($tnick,$tvalue)"
                unset flood:text($tnick,$tvalue)
            }
        }
    }
    
    # -- stores the IP address of a nickname
    if {[info exists data:nickip($nick)]} {
        set ip [get:val data:nickip $nick]
        if {[info exists data:ipnicks($ip,$lchan)]} {
            # -- stores the nicknames on an IP
            set pos [lsearch -exact [get:val data:ipnicks $ip,$lchan] $nick]
            if {$pos ne "-1"} {
                debug 4 "userdb:unset:vars: $type from $chan removing $nick from \$data:ipnicks($ip,$lchan)"
                set data:ipnicks($ip,$lchan) [lreplace [get:val data:ipnicks $ip] $pos $pos]
                if {[get:val data:ipnicks $ip,$lchan] eq ""} { unset data:ipnicks($ip,$lchan) }
            }
        }
        debug 4 "userdb:unset:vars: $type in $chan removing $nick from data:nickip($nick)"
        unset data:nickip($nick)
    }
    
    # -- stores the host address of a nickname
    # -- needed outside of eggdrop due to chanmode +D
    if {[info exists data:nickhost($nick)] && ![oncommon $nick $chan]} {
        set host [get:val data:nickhost $nick]
        if {[info exists data:hostnicks($host)]} {
            # -- stores the nicknames on a host
            set pos [lsearch -exact [get:val data:hostnicks $host] $nick]
            if {$pos ne "-1"} {
                debug 4 "userdb:unset:vars: $type from $chan removing $nick from \$data:hostnicks($host)"
                set data:hostnicks($host) [lreplace [get:val data:hostnicks $host] $pos $pos]
                if {[get:val data:hostnicks $host] eq ""} { unset data:hostnicks($host) }
            }
        }
        debug 4 "userdb:unset:vars: $type in $chan removing $nick from data:nickhost($nick)"
        unset data:nickhost($nick)
    }
    
    # -- remove CAPTCHA response expectation
    if {[info exists data:captcha($nick,$chan)]} {
        debug 3 "userdb:unset:vars: $type in $chan is removing data:captcha($nick,$chan)"
        unset data:captcha($nick,$chan)
    }
    
    if {[userdb:isLogin $nick] && ![oncommon $nick $chan]} {
        # -- user is authenticated
        debug 0 "userdb:unset:vars: $nick no longer on a common channel, begin autologout"
        set user [userdb:user:get user nick $nick]
        userdb:logout $nick $uhost; # -- send logout to common code
        debug 2 "userdb:unset:vars: autologout complete for $user ($nick!$uhost)"
    }
}

# -- nickname change
proc userdb:nick {nick uhost hand chan newnick} {
    
    variable flood:text;      # -- array to track the lines for a text pattern (by nick,pattern)    
    variable data:ipnicks;    # -- stores a list of nicks on a given IP (by IP,chan)
    variable data:nickip;     # -- stores the IP address for a nickname (by nick)
    variable data:hostnicks;  # -- stores a list of nicks on a given host (by host,chan)
    variable data:nickhost;   # -- stores the hostname for a nickname (by nick)
    variable data:kicks;      # -- stores queue of nicks to kick from a channel (by chan)
    variable scan:list;       # -- the list of nicknames to scan in secure mode:
                              #        leave,*    :  nicks already scanned and left
                              #        nicks,*    :  nicks being scanned
                              #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname    
    variable data:captcha;    # -- holds captcha data for nick (by nick,chan)
    variable nickdata;        # -- dict: stores data against a nickname
                              #           nick
                              #              ident
                              #           host
                              #           ip
                              #           uhost
                              #           rname
                              #           account
                              #           signon
                              #           idle
                              #           idle_ts
                              #           isoper
                              #           chanlist
                              #           chanlist_ts    
    
    lassign [db:get id,user users curnick $nick] nid user
        
    set host [lindex [split $uhost @] 1]
    set lchan [string tolower $chan]
    set lnick [string tolower $nick]
    set lnewnick [string tolower $newnick]
    if {[dict exists $nickdata $lnick nick]}        { dict set nickdata $lnewnick nick $newnick }
    if {[dict exists $nickdata $lnick ident]}       { dict set nickdata $lnewnick ident [dict get $nickdata $lnick ident] }
    if {[dict exists $nickdata $lnick host]}        { dict set nickdata $lnewnick host [dict get $nickdata $lnick host] }
    if {[dict exists $nickdata $lnick ip]}          { dict set nickdata $lnewnick ip [dict get $nickdata $lnick ip] }
    if {[dict exists $nickdata $lnick uhost]}       { dict set nickdata $lnewnick uhost [dict get $nickdata $lnick uhost] }
    if {[dict exists $nickdata $lnick rname]}       { dict set nickdata $lnewnick rname [dict get $nickdata $lnick rname] }
    if {[dict exists $nickdata $lnick account]}     { dict set nickdata $lnewnick account [dict get $nickdata $lnick account] }
    if {[dict exists $nickdata $lnick signon]}      { dict set nickdata $lnewnick signon [dict get $nickdata $lnick signon] }
    if {[dict exists $nickdata $lnick idle]}        { dict set nickdata $lnewnick idle [dict get $nickdata $lnick idle] }
    if {[dict exists $nickdata $lnick idle_ts]}     { dict set nickdata $lnewnick idle_ts [dict get $nickdata $lnick idle_ts] }
    if {[dict exists $nickdata $lnick isoper]}      { dict set nickdata $lnewnick isoper [dict get $nickdata $lnick isoper] }
    if {[dict exists $nickdata $lnick chanlist]}    { dict set nickdata $lnewnick chanlist [dict get $nickdata $lnick chanlist] }
    if {[dict exists $nickdata $lnick chanlist_ts]} { dict set nickdata $lnewnick chanlist_ts [dict get $nickdata $lnick chanlist_ts]}
    dict unset dictdata $lnick; # -- remove the old dict key data
    
    # -- remove nick from hostnicks if exists
    if {[info exists data:nickhost($nick)]} {
        set ip [get:val data:nickhost $nick]
        if {![info exists data:hostnicks($host,$lchan)]} { set data:hostnicks($host,$lchan) $newnick } else {
            set pos [lsearch -exact [list [get:val hostnicks $host,$lchan]] $nick]
            putlog "\002userdb:nick:\002 nick: $nick -- newnick: $nick -- chan: $chan -- pos: $pos"
            if {$pos ne -1} {
                # -- nick within
                debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating data:hostnicks($host,$lchan)"
                set data:hostnicks($host,$lchan) [lreplace [list [get:val hostnicks $host,$lchan]] $pos $pos $newnick]
            }
        }
        debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating data:nickhost($nick)"
        set data:nickhost($newnick) [get:val data:nickhost $nick]
        unset data:nickhost($nick)
    }

    # -- remove nick from ipnicks if exists
    if {[info exists data:nickip($nick)]} {
        set ip [get:val data:nickip $nick]
        if {![info exists data:ipnicks($ip,$lchan)]} { set data:ipnicks($ip,$lchan) $newnick } else {
            set pos [lsearch -exact [list [get:val data:ipnicks $ip,$lchan]] $nick]
            if {$pos ne -1} {
                # -- nick within
                debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating data:ipnicks($ip,$lchan)"
                putlog "\002userdb:nick:\002 lreplace: [get:val data:ipnicks $ip,$lchan] $pos $pos $newnick]"
                set data:ipnicks($ip,$lchan) [lreplace [list [get:val data:ipnicks $ip,$lchan]] $pos $pos $newnick]
            }
        }
        debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating data:nickip($nick)"
        set data:nickip($newnick) [get:val data:nickip $nick]
        unset data:nickip($nick)
    }
    
    # -- replace nick in global kicklist if exists
    foreach chan [array names data:kicks] {
            set pos [lsearch -exact [list [get:val data:kicks $chan]] $nick]
            if {$pos ne -1} {
                # -- nick within
                debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating data:kicks($chan)"
                set data:kicks($chan) [lreplace [list [get:val data:kicks $chan]] $pos $pos $newnick]
            }
    }
    
    # -- scan:list(nicks,*) - list of those being scanned
    if {[info exists scan:list(nicks,$lchan)]} {
        set pos [lsearch -exact [list [get:val scan:list nicks,$lchan]] $nick]
        if {$pos ne -1} {
            debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating scan:list(nicks,$lchan)"
            set scan:list(nicks,$lchan) [lreplace [list [get:val scan:list nicks,$lchan]] $pos $pos $newnick]
        }
    }
    
    # -- scan:list(leave,*) - list of those already scanned but being left hidden for review (secure mode)
    if {[info exists scan:list(leave,$lchan)]} {
        set pos [lsearch -exact [list [get:val scan:list leave,$lchan]] $nick]
        if {$pos ne -1} {
            debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating scan:list(leave,$lchan)"
            set scan:list(leave,$lchan) [lreplace [list [get:val scan:list leave,$lchan]] $pos $pos $newnick]
        }
    }
    
    # -- textflud -- counts of lines matching blacklist text entries, for a nick
    foreach i [array names flood:text] {
        set tnick [lindex [split $i ,] 0]
        set tvalue [lindex [split $i ,] 1]
        if {$tnick eq $nick} {
            debug 4 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating flood:text($tnick,$tvalue)"
            set flood:text($newnick,$tvalue) [get:val flood:text $tnick,$tvalue]
            unset flood:text($tnick,$tvalue)
        }
    }
    
    # -- update CAPTCHA response expectation
    if {[info exists data:captcha($nick,$chan)]} {
        debug 3 "userdb:nick: nickchange ($nick to $newnick) in $chan is updating data:captcha($nick,$chan)"
        set data:captcha($newnick,$chan) [get:val data:captcha $nick,chan]
        unset data:captcha($nick,$chan)
    }

    if {[userdb:isLogin $nick]} {
        # -- begin login follow
        set user [userdb:user:get user curnick $nick]
        # -- update curnick
        userdb:user:set curnick $newnick user $user
        debug 1 "userdb:nick: changed nickname for $user to $newnick (authentication)"
    }
}

# -- proc for generic response (RAW 352)
# -- add handling per ircd type
# -- this isn't returned on ircu (Undernet) for our special /WHOs that specify a 'querytype'
proc userdb:raw:genwho {server cmd arg} {
    variable cfg
    #server cmd mynick type ident ip server nick away :rname
    
    # -- ircd types:
    set ircd [cfg:get ircd *]
    if {$ircd eq "1"} {
        # -- ircu (Undernet)
        # -- do nothing, as ircu will already return raw 354 for extended WHO
    } elseif {$ircd eq "2"} {      
        # -- IRCnet
        #irc.psychz.net 352 cori * _mxl ipv4.pl ircnet.hostsailor.com Maxell H :2 0PNH oskar@ipv4.pl
        lassign $arg mynick type ident host server nick away hopcount sid
        set rname [lrange $arg 9 end]
        # -- NOTE:  The above raw example doesn't appear to provide an actual IP;
        # --        A DNS lookup would slow us down; be doubled up from real scans; and isn't needed for autologin
        set ip 0;
        set account 0;  # -- TODO: where do we get an ACCOUNT from in IRCnet /WHO response?;
        # -- send it to userdb:who
        # -- NOTE: the possible downside to this workaround, is additional processing for autologin on every /WHO response
        userdb:who $ident $ip $host $nick $account
    }
}

# -- return from RAW 354 (Undernet/ircu extended WHO)
proc userdb:raw:who {server cmd arg} {
    variable selfregister;   # -- the data for a username self-registration:
                             #        coro,$nick:        the coroutine for a nickname
    set arg [split $arg]
    # mynick type ident ip host nick xuser
    lassign $arg mynick type ident ip host nick xuser
    if {$type ne "101" && $type ne "103"} { return; };    # -- querytype 101 = autologin
                                                          # -- querytype 102 = scans
                                                          # -- querytype 103 = register (username)
    if {$type eq "103"} {
        # -- username self register (cmd: register)
        if {[info exists selfregister(coro,$nick)]} {
            # -- yield the results to coroutine
            $selfregister(coro,$nick) $xuser
        }
    }                                                    
    # -- send it to the generic proc
    userdb:who $ident $ip $host $nick $xuser
}

# -- generic WHO response handler
proc userdb:who {ident ip host nick xuser} {
    global botnick

    set uhost "$ident@$host"
    set nuh "$nick!$uhost"
    if {$nick eq $botnick} { return; }
    if {($xuser eq "0" || $xuser eq "")} { return; }
    if {[userdb:isLogin $nick]} { return; }
    
    lassign [db:get user,curnick,lastseen users xuser $xuser] user curnick lastseen

    # -- only do autologin if no-one is logged into this bot user account
    if {$curnick eq ""} {
        debug 5 "\002userdb:who:\002 nick: $nick -- xuser: $xuser -- user: $user -- curnick: $curnick -- lastseen: $lastseen"
        if {$user eq ""} { return; }; # -- no such user
        if {$lastseen ne ""} {
            set timeago [userdb:timeago $lastseen]
            set days [lindex $timeago 0]
            if {$days >= 120} {
                # -- Over 120 days since last login (safety net)
                debug 0 "\002userdb:who\002: autologin failed for $user: not logged in for $timeago"
                # -- this needs checks to prevent multiple reminders to the same nick, until they manually login
                # -- update trackers when: quit, leave all chans (part or kick), change nicknames
                #reply notc $nick "autologin failed, please login manually. (last login: $days days ago)"
                return;
            }
        }
        # -- begin autologin!
        debug 0 "\002userdb:who:\002 autologin begin for $user ($nick!$uhost)"
        userdb:login $nick $uhost $user;  # -- send login to common code
    }
}


proc userdb:raw:account {server cmd arg} {
    variable userdb
    variable nickdata
    global botnick
    
    set arg [split $arg]
    set nick [lindex $arg 1]
    if {$nick eq $botnick} { return; }
    set lnick [string tolower $nick]
    set xuser [lindex $arg 2]
    dict set nickdata $lnick account $xuser

    if {[userdb:isLogin $nick]} { return; }; # -- already logged in

    # -- attempt autologin
    lassign [db:get user,lastseen users xuser $xuser] user lastseen
    if {$user eq ""} { return; }
    set timeago [userdb:timeago $lastseen]
    set days [lindex $timeago 0]
    if {$days >= 120} {
        # -- Over 120 days since last login (safety net)
        debug 1 "userdb:raw:account autologin failed for $user: not logged in for $timeago"
        reply notc $nick "autologin failed, please login manually. (last login: $days days ago)"
        return;
    }

    # -- begin autologin!
    set uhost [getchanhost $nick]
    if {$uhost eq ""} {
        set uhost [dict get $nickdata $lnick uhost]
    }
    if {$uhost ne ""} {
        userdb:login $nick $uhost $user;  # -- send login to common code
    }
}

# -- check if command is allowed for nick
proc userdb:isAllowed {nick cmd chan type} {
    variable userdb;

    # -- check channels we don't allow commands
    set list [split [cfg:get chan:nocmd *] ,]
    foreach channel $list {
        if {[string tolower $channel] eq [string tolower $chan]} {
            debug 0 "userdb:isAllowed: $chan does not allow use of bot commands (chan:nocmd) -- chan: $chan -- $nick: $nick -- cmd: $cmd"
            return 0;
        }
    }
    
    # -- get username
    lassign [db:get id,user users curnick $nick] uid user
    set cid [db:get id channels chan $chan]

    # -- -- revert to default chan if the provided one isn't registered
    if {$cid eq ""} {
        set chan [cfg:get chan:def *]
        set level [userdb:get:level $user $chan]
    }
    
    if {$user eq ""} {
        set islogin 0; set level 0; set globlevel 0; set uid 0;
    } else { 
        set islogin 1
        set level [db:get level levels uid $uid cid $cid]
        set globlevel [db:get level levels uid $uid cid 1]
    }

    # -- safety fallback
    if {![info exists userdb(cmd,$cmd,$type)]} { set req 500 } else { set req $userdb(cmd,$cmd,$type) }
        
    if {$globlevel >= $level} { set level $globlevel }; # -- apply the global level if it's higher chan local chan

    if {$req ne 0} {
        # -- is user logged in?
        if {!$islogin} { return 0 }
    }  else { return 1; }
    
    if {$level >= $req} {
        # -- cmd allowed
        return 1
    } else {
        # -- cmd not allowed
        return 0;
    }
}

# -- return the channel to use, when not specified in a msg/dcc command
proc userdb:userchan {$user} {
    variable cfg
    db:connect
    set dbuser [db:escape [string tolower $user]]
    set uid [lindex [db:query "SELECT id FROM users WHERE lower(user)='$dbuser'"] 0]
    
    # -- return detaulf it the user is invalid
    if {$uid eq ""} { db:close; return [cfg:get chan:def *]; }
    
    # -- get their channels
    set rows [db:query "SELECT cid,level FROM channels WHERE uid='$uid'"]
    set count 0; set highest(chan) ""; set highest(last) 0
    set global(is) 0; set global(level) 0;
    foreach row $rows {
        incr count
        lassign $row cid level
        if {$cid eq 1} { set global(is) 1; set global(level) $level }
        set chan [lindex [db:query "SELECT chan FROM channels WHERE id='$cid'"] 0]
        # -- track the [non-global] channel where the user has the highest access
        if {$level > $highest(last) && $cid != 1} { set highest(chan) $chan }
    }
    
    # -- if there's only one chan they have access to, just use the default
    if {$count eq 1} { db:close; return [cfg:get chan:def *] }
    
    # -- otherwise (they have access to multiple chans), return the one with highest level
    return $highest(chan);
}



# -- start autologin (who every 20s)
proc userdb:init:autologin {} {
    global server
    variable cfg
    # -- only continue if autologin chan set
    set chanlogin [cfg:get chan:login *]
    set chanlogin [join $chanlogin ,]
    if {$chanlogin ne ""} {
        utimer [cfg:get autologin:cycle *] arm::userdb:init:autologin
    }
    # -- only send the /WHO if connected to server
    if {$server ne "" && $chanlogin ne "" && [cfg:get ircd *] eq 1} {
        putquick "WHO $chanlogin %nuhiat,101"
    }
}

# -- kill timers on rehash
proc userdb:kill:timers {} {
    set ucount 0
    set count 0
    foreach utimer [utimers] {
        # putloglev d * "userdb:killtimers: utimer: $utimer"
        # -- kill only autologin timer
        if {[lindex $utimer 1] eq "arm::userdb:init:autologin"} { incr ucount; catch { killutimer [lindex $utimer 2] } }
    }
    foreach timer [timers] {
        # putloglev d * "userdb:killtimers: timer: $timer"
        # -- kill only autologin timer
        if {[lindex $timer 1] eq "arm::userdb:init:autologin"} { incr count; catch { killtimer [lindex $timer 2] } }
    }
    debug 0 "\002userdb:kill:timers:\002 killed $count timers and $ucount utimers"
}

# -- users into memory
proc userdb:db:load {} {
    if {[info exists dbusers]} { unset dbusers }
    variable dbusers; # -- dict to store users
    debug 4 "\002userdb:db:load:\002 started"
    # -- sqlite3 database
    db:connect          
    set results [db:query "SELECT id, user, xuser, email, curnick, curhost, lastnick, \
        lasthost, languages, pass FROM users"]
    db:close
    set ucount 0;
    foreach row $results {
        incr ucount
        lassign $row id user xuser email curnick curhost lastnick lasthost languages pass
        dict set dbusers $id user $user
        dict set dbusers $id account $xuser
        dict set dbusers $id email $email
        dict set dbusers $id curnick $curnick
        dict set dbusers $id curhost $curhost
        dict set dbusers $id lastnick $lastnick
        dict set dbusers $id lasthost $lasthost
        dict set dbusers $id languages $languages
        dict set dbusers $id pass $pass
        debug 4 "\002userdb:db:load:\002 id: $id -- user: $user -- xuser: $xuser"
    }
    debug 0 "\002userdb:db:load:\002 loaded $ucount users into memory"
}

# -- common code to delete a user
proc userdb:deluser {user uid} {   
    variable dbusers; # -- dict to store users 
    # -- ok to delete the user
    db:connect
    set db_user [db:escape $user]
    # -- retain whitelist & blacklist entries; IDB entries
    debug 3 "userdb:deluser: deleting user record: $user (uid: $uid)"
    db:query "DELETE FROM users WHERE user='$db_user'"
    debug 3 "userdb:deluser: deleting user level access: $user (uid: $uid)"
    db:query "DELETE FROM levels WHERE uid=$uid"
    debug 3 "userdb:deluser: deleting user recipient notes: $user (uid: $uid)"
    db:query "DELETE FROM notes WHERE to_id=$uid"; # -- leave remaining notes from this user to others
    debug 3 "userdb:deluser: deleting user greets: $user (uid: $uid)"
    db:query "DELETE FROM greets WHERE uid=$uid"; 
    catch { db:query "SELECT count(*) FROM idb" } err
    if {$err ne "no such table: idb"} {
        # -- IDB loaded
        #debug 0 "userdb:deluser: deleting user IDB entries: $user (uid: $uid)"
        #db:query "DELETE FROM idb WHERE user_id=$uid"; # -- TODO: deal with IDBs? (schema needs updating to support multi-chan)
    }    
    db:close

    # -- remove user from memory 
    dict unset dbusers $uid
    
    # -- deal with training plugin
    if {[info commands arm::train:deluser] ne ""} {
        # -- training plugin loaded
        debug 3 "userdb:deluser: passing user deletion request to training plugin (user: $user -- uid: $uid)"
        train:deluser $user $uid
    }
    debug 0 "userdb:deluser: deleted user: $user (id: $uid)"
}

# -- load the userlist to memory
userdb:db:load

# -- killtimers
userdb:kill:timers

# -- start autologin
userdb:init:autologin

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
    elseif {$years eq 1} { append output "$years year, " }

    if {$days eq 0 || $days > 1} { append output "$days days, " } \
    elseif {$days eq 1} { append output "$days day, " }

    append output "$hours:$mins:$secs"

    return $output;
}


# -- check if string is Integer?
proc userdb:isInteger {arg} {
    if {[string length $arg] eq 0} {return 0}
    set ctr 0
    while {$ctr < [string length $arg]} {
        if {![string match \[0-9\] [string index $arg $ctr]]} {return 0}
        set ctr [expr $ctr + 1]
    }
    return 1
}


# -- check if channel is valid?
proc userdb:isValidchan {chan} {
    set lchan [string tolower $chan]

    set cid [dict keys [dict filter $dbchans script {id dictData} { expr {[string tolower [dict get $dictData chan]] eq $lchan} }]]
    if {$cid eq ""} { return $res 0 } else { set res 1; }
        
    return $res
}

proc userdb:init:logout {type} {
    # -- logout all users   
    debug 2 "userdb:init:logout: beginning global logout sequence..."
    db:connect
    set rows [db:query "SELECT user,curnick,curhost FROM users WHERE curnick!='' AND curhost!=''"]
    foreach row $rows {
        lassign $row user curnick curhost
        set db_curnick [db:escape $curnick]
        set db_curhost [db:escape $curhost]
        db:query "UPDATE users SET curnick='', curhost='', lastnick='$db_curnick', lasthost='$db_curhost', \
            lastseen='[clock seconds]' WHERE user='$user'" 
        debug 0 "userdb:init:logout: deauthenticated user: $user ($curnick!$curhost)"           
    }
    db:close
    return;
}

# -- handle auto logouts from ZNC server disconnects
proc userdb:znc {nick uhost hand text} {
    # Disconnected from IRC. Reconnecting...
    if {$nick ne "*status"} { return; }
    if {$text eq "Disconnected from IRC. Reconnecting..."} {
        debug 0 "userdb:znc: detected server disconnection. initiating autologout of all users"
        userdb:init:logout
    }
}

putlog "\[@\] Armour: loaded user database support."

}
# -- end of namespace

# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-17_dnslookup.tcl
#
# dns resolver with coroutines
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# -- require dns from tcllib
if {[catch {package require dns} fail]} {
    putlog "\[@\] Armour: error loading dns library. error: $fail"
    return false
}

set dns(debug) 1
bind dcc n score { arm::coroexec arm::dcc:cmd:score }
bind dcc n lookup { arm::coroexec arm::dcc:cmd:lookup }

# -- RBL score lookup from DCC
# -- useful for testing
proc dcc:cmd:score {hand idx text} {
    lassign $text ip type
    putlog [rbl:score $ip]
}

# -- DNS lookup from DCC
# -- useful for testing
proc dcc:cmd:lookup {hand idx text} {
    lassign $text ip type
    putlog "lookup: [dns:lookup $ip $type]"
}

proc rbl:score {ip {manual "0"}} {
    variable cfg
    variable scan:rbls; # -- array to store list of DNSBLs
    set start [clock clicks]
    # -- reverse the ip
    for {set i 0} {$i < 4} {incr i} {lappend rip [lindex [split $ip {.}] end-$i]}; set rip [join $rip {.}]
    set total 0
    set desc ""; set point ""; set info ""; set therbl "";
    foreach rbl [array names scan:rbls] {
        set onlymanual [lindex [get:val scan:rbls $rbl] 2]
        #putlog "\002rbl:score\002: rbl: $rbl -- manual: $manual -- onlymanual: $onlymanual"
        if {!$manual && $onlymanual} { continue; }; # -- discard if this RBL is for manual scans only
        set lookup "$rip.$rbl"
        set response [dns:lookup $lookup A]; # -- the actual DNS resolution
        if {$response eq "error"} { continue; }
        lassign [get:val scan:rbls $rbl] desc point
        #putlog "\002rbl:score\002: response: $response"
        set info [lindex $response 11]
        incr total [expr round($point)]
        set therbl $rbl
    }
    if {$total eq 0} {
        debug 3 "rbl:score: total score: $total (runtime: [runtime $start])"
    } else {
        debug 3 "rbl:score: total score: $total rbl: $therbl desc: $desc info: $info (runtime: [runtime $start])"
    }
    
    # {{+1.0 dnsbl.swiftbl.org SwiftRBL {{DNSBL. 80.74.160.3 is listed in SwiftBL (SOCKS proxy)}}} {+1.0 rbl.efnetrbl.org {Abusive Host} NULL}}
    set output [list]
    lappend output $ip
    lappend output "$total $therbl {$desc} $onlymanual {$info}"
    return $output
}

proc dns:lookup {host {type ""}} {
    set start [clock clicks]
    
    if {[string toupper $type] eq ""} { set type "A" }; # -- force uppercase

    # -- perform lookup
    # debug 3 "arm:dns:lookup: lookup: $host -type $type"
    # -- force 1sec timeout and Cloudflare DNS
    # -- TODO: make timeout and NS configurable
    set tok [::dns::resolve $host -type $type -timeout 1000 -server 1.1.1.1 -command [info coroutine]]
    yield

    # -- get status (ok, error, timeout, eof)
    set status [::dns::status $tok]
    set error [::dns::error $tok]
    set iserror 0
    
    if {$status eq "error"} {
        set what "failure"; set iserror 1
    } elseif {$status eq "eof"} {
        set what "eof"; set iserror 1
    } elseif {$status eq "timeout"} {
        set what "timeout"; set iserror 1
    }
    if {$iserror} {
        # -- return error
        debug 3 "dns:lookup: dns resolution $what for $host took [runtime $start]"
        ::dns::cleanup $tok
        return "error"
    }

    # -- fetch entire result
    set result [join [::dns::result $tok]]
    
    #  name google.com type TXT class IN ttl 2779 rdlength 82 rdata {v=spf1 include:_netblocks.google.com ip4:216.73.93.70/31 ip4:216.73.93.72/31 ~all}
    set typ [lindex $result 3]
    set class [lindex $result 5]
    set ttl [lindex $result 7]
    set resolve [lindex $result 11]

    # -- cleanup token
    ::dns::cleanup $tok
    
    debug 3 "arm:dns:lookup: dns resolution success for $host took [runtime $start]"
    
    if {$type eq "*"} { 
        # debug 3 "arm:dns:lookup:  final result: $result"
        return $result
    } else {
        # debug 3 "arm:dns:lookup: final result: $resolve"
        return $resolve
    }
}

putlog "\[@\] Armour: loaded asynchronous dns resolver."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-18_captcha.tcl
#
# CAPTCHA -- to assist screening suspicious clients
#            API provided by www.textcaptcha.com
#
# -- responses provided in trimmed, lowercase, md5 format
# -- must match by applying the same changes
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- prerequisites (Tcllibc)
package require Tcl 8.6
package require json
package require http
package require md5

# -- warning: there is currently an issue using https
#package require tls
#::http::register https 443 ::tls::socket

# -- run the test
proc captcha:query {} {
    variable cfg
    variable captcha
    http::config -useragent "mozilla" 

    set url [cfg:get captcha:url *]
    #catch {set tok [http::geturl $url]} error
    coroexec http::geturl $url -keepalive 1 -timeout 3000 -command [info coroutine]
    set tok [yield]
    
    set error ""; # -- TODO: fix generic error handling
    #if {[string match -nocase "*couldn't open socket*" $error]} {
    #    debug 0 "\002captcha:query:\002 could not open socket to: $url"
    #    http::cleanup $tok
    #    return ""
    #} 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002captcha:query:\002 connection to $url has timed out."
        http::cleanup $tok
        return ""
    } elseif {$status eq "error"} {
        debug 0 "\002captcha:query:\002 connection to $url has error."
        http::cleanup $tok
        return ""
    }
    
    set token $tok
    set data [http::data $tok]
    
    # -- deal with the data
    set captcha(parsed) [json::json2dict $data]
    putlog "\002captcha(parsed):\002 $captcha(parsed)"
    set question [dict get $captcha(parsed) q]
    set captcha(answers) [lindex $captcha(parsed) 3]
    debug 3 "captcha:query: \002question:\002 $question"
    foreach answer $captcha(answers) {
        debug 3 "captcha:query: \002answer:\002 $answer"
    }
    
    http::cleanup $tok
    return $captcha(parsed);
}

# -- check if text matches a hashed response
proc captcha:match {text hash} {
    variable captcha
    set texthash [string tolower [::md5::md5 -hex [string trim [string tolower $text]]]]
    if {$texthash eq $hash} { return 1 } else { return 0 }
}

# -- match a given string against all possible answers
proc captcha:matchfull {text} {
    variable captcha
    set texthash [string tolower [::md5::md5 -hex [string trim [string tolower $text]]]]
    foreach answer $captcha(answers) {
        debug 3 "::captcha::matchfull: answer: $answer -- texthash: $texthash"
        if {$texthash eq $answer} { debug 3 "::captcha::matchfull: \002match!\002"; return 1 }
    }
    # -- no match!
    debug 3 "::captcha::matchfull: no match!"
    return 0
}

# -- captcha:scan
# common code for setting up the CAPTCHA
proc captcha:scan {nick uhost chan {id ""}} {
    variable cfg;
    variable data:captcha;  # -- holds captcha data for nick (by <nick>,chan)
                            # -- also holds attempt count (by <nick>,<chan>,attempt)
    
    set lchan [string tolower $chan]
    
    # -- send the client a question and wait for a reply
    # -- if no reply received in N time (configurable), kick(ban) client
    # -- if incorrect reply received, kick(ban) client
    if {[cfg:get captcha $chan]} {
        set response [captcha:query]
        if {$response eq ""} {
            debug 3 "\002captcha:scan\002: response error, reverting to manual handling."
            return 1; # -- there was some kind of error, revert to manual handling
        } else {
            set data:captcha($nick,$lchan) $response
            set reattempt [info exists data:captcha($nick,$lchan,attempts)]
            if {!$reattempt} { set data:captcha($nick,$lchan,attempts) 1 }; # -- only if not set already
            set question [dict get $response q]
            
            if {[binds arm::captcha:msg:response*] eq ""} {
                # -- bind not loaded, add bind
                # we do this for safety so it's not always listening for ALL messages
                bind msgm - * arm::captcha:msg:response
            }
            
            # -- send the question to the client!
            debug 3 "\002captcha:scan\002: sending question to $nick for $chan: $question"
            putquick "PRIVMSG $nick :\002Attention!\002 To talk in $chan please answer the following question correctly: $question"
            
            utimer [cfg:get captcha:time $chan] "arm::captcha:check $nick $uhost $chan $id"; # -- time limit for captcha
            
            if {[cfg:get captcha:opnotc $chan] && ![cfg:get paranoid:ctcp $chan] && !$reattempt} { 
                putquick "NOTICE @$chan :Armour: $nick!$uhost looks suspicious; sent CAPTCHA question for verification -- \002/whois $nick\002"
            }
        }
    }
    return 0; # -- manual handling required
}


# -- captcha:check
# checks for expired CAPTCHAs
proc captcha:check {nick uhost chan {id ""}} {
    variable cfg;
    variable data:captcha;   # -- holds captcha data for nick (by nick,chan)
    variable data:kicknicks; # -- tracking nicknames recently kicked from chan (by 'chan,nick')
    
    set lchan [string tolower $chan]
    set dokick 0; set dokb 0;
    if {[info exists data:captcha($nick,$chan)]} {
        # -- expired entry! client did not respond
        set action [string tolower [cfg:get captcha:expired $chan]]
        if {[cfg:get captcha:expired:ops $chan] ne "" && $action ne "manual"} {
            reply notc @$chan "Armour: $nick!$uhost has \002not responded\002 with a CAPTCHA response -- taking action!" 
        }
        if {$action eq "manual"} {
            # -- only alert ops for manual action
            reply notc @$chan "Armour: $nick!$uhost waiting manual action (\002CAPTCHA not received\002) -- \002/whois $nick\002"
            # -- maintain a list so we don't scan this client again
            putlog "\002captcha:check:\002 adding $nick to scan:list(leave,$lchan)"
            scan:cleanup $nick $lchan leave
        } elseif {$action eq "kick"} {
            # -- just kick the user
            set dokick 1;
        } elseif {$action eq "kickban"} {
            # -- kickban the user
            set dokb 1;
        } else {
            # -- invalid config option
            putlog "\002captcha:check:\002 invalid cfg(captcha:expired) option: $action (must be: manual|kick|kickban)" 
        }
        unset data:captcha($nick,$lchan);          # -- response tracker
        unset data:captcha($nick,$lchan,attempts); # -- attempt counter
    }
    
    # -- check whether to kick client
    if {$dokick} {
        lassign [split [cfg:get paranoid:klimit $chan] :] lim secs
        if {![info exists data:kicknicks($lchan,$nick)]} {
            set data:kicknicks($lchan,$nick) 1
            utimer $secs "unset arm::data:kicknicks($chan,$nick)"
        } else {
            incr data:kicknicks($lchan,$nick)
        }
        if {[get:val data:kicknicks $lchan,$nick] <= $lim} {
            # -- ok to kick the user, threshold not met
            putquick "KICK $chan $nick :[cfg:get captcha:expired:kick $chan]"
        } else {
            # -- upgrade the kick to kickban!
            set dokb 1;
        }
    }
    
    # -- send kickban for client
    if {$dokb} {
        lassign [split $uhost @] ident host
        set duration [cfg:get captcha:expired:bantime $chan]
        kickban $nick $ident $host $chan $duration [cfg:get captcha:expired:kick $chan]
    }
    
    if {[array names data:captcha] eq ""} { 
        # -- unbind; safety net so we're not always listening for ALL messages
        if {[binds arm::captcha:msg:response*] ne ""} {
            putlog "\002captcha:check:\002 no more waiting responses: unbind msgm - * arm::captcha:msg:response"
            unbind msgm - * arm::captcha:msg:response
        }
    }
}

# -- captcha:msg:response
# processes the CAPTCHA responses from clients (via PRIVMSG)
proc captcha:msg:response {nick uhost hand arg} {
    variable cfg;
    variable data:captcha;   # -- holds captcha data for nick (by nick,chan)
    variable data:ctcp;      # -- stores whether we're waiting for a CTCP VESION reply (by chan,nick)
    variable data:kicknicks; # -- tracking nicknames recently kicked from chan (by 'chan,nick')
    
    foreach entry [array names data:captcha] {
        lassign [split $entry ,] tnick chan
        if {$tnick ne $nick} { continue; }
        putlog "\002captcha:msg:response: started!\002 nick: $nick -- uhost: $uhost -- chan: $chan -- arg: $arg"
        set lchan [string tolower $chan]
        set mode [get:val chan:mode $chan]
        if {$mode ne "secure"} { return; }
        set response [join [split $arg]]
        set match [captcha:matchfull [string tolower $response]]
        set action [string tolower [cfg:get captcha:wrong $chan]]
        set dokick 0; set dokb 0;
        if {$match} {
            # -- correct answer!
            putlog "\002captcha:msg:response:\002 correct answer from $nick on $chan"
            if {[cfg:get captcha:ack $chan]} {
                if {[cfg:get captcha:ack:msg $chan] ne ""} { putquick "PRIVMSG $nick :[cfg:get captcha:ack:msg $chan]" }; # -- send ack for correct response
                if {[cfg:get captcha:ack:ops $chan] ne ""} {
                    reply notc @$chan "Armour: $nick!$uhost has submitted a \002correct\002 CAPTCHA response" 
                }
            }
            voice:give $chan $nick; # -- voice the user        
        } else {
            # -- incorrect answer!
            putlog "\002captcha:msg:response:\002 incorrect answer from $nick on $chan"
            
            # -- check if they are allowed multiple attempts
            set succeed 0; # -- track whether we successfully obtained and send the CAPTCHA
            set aattempts [cfg:get captcha:wrong:attempts $lchan];      # -- allowed attempts
            set cattempts [get:val data:captcha $nick,$lchan,attempts]; # -- current attempts
            set rattempts [expr $aattempts - $cattempts];               # -- remaining attempts
            if {$cattempts < $aattempts} {
                # -- send them another captcha for another attempt
                if {$rattempts eq 1} { set xtra "This is your last attempt." } else { set xtra "You have $rattempts remaining." }
                putlog "\002captcha:msg:response:\002 $nick in $chan is allowed a CAPTCHA reattempt!"
                putquick "PRIVMSG $nick :\002\[INFO\]\002 Please read the next question \002carefully\002. $xtra"
                incr data:captcha($nick,$lchan,attempts); # -- bump the attempt counter
                set succeed [captcha:scan $nick $uhost $lchan]
                # -- maintain a list so we don't scan this client again
                putlog "\002captcha:msg:response:\002 adding $nick to scan:list(leave,$lchan)"
                scan:cleanup $nick $lchan leave
                return;
            }
            
            if {([cfg:get captcha:ack:ops $chan] ne "" && $action ne "manual") || !$succeed} {
                reply notc @$chan "Armour: $nick!$uhost has submitted an \002incorrect\002 CAPTCHA response -- taking action!" 
            }
            if {$action eq "manual"} {
                # -- only alert ops for manual action
                reply notc @$chan "Armour: $nick!$uhost waiting manual action (\002CAPTCHA not received\002) -- \002/whois $nick\002"
                # -- maintain a list so we don't scan this client again
                putlog "\002captcha:msg:response:\002 adding $nick to scan:list(leave,$lchan)"
                scan:cleanup $nick $lchan leave
            } elseif {$action eq "kick"} {
                # -- just kick the user
                set dokick 1;
            } elseif {$action eq "kickban"} {
                # -- kickban the user
                set dokb 1;
            } else {
                # -- invalid config option
                putlog "\002captcha:msg:response:\002 invalid cfg(captcha:expired) option: $action (must be: manual|kick|kickban)" 
            }
        }
        
        # -- check whether to kick client
        if {$dokick} {
            lassign [split [cfg:get paranoid:klimit $chan] :] lim secs
            if {![info exists data:kicknicks($lchan,$nick)]} {
                set data:kicknicks($lchan,$nick) 1
                utimer $secs "unset arm::data:kicknicks($lchan,$nick)"
            } else {
                incr data:kicknicks($lchan,$nick)
            }
            if {[get:val data:kicknicks $lchan,$nick] <= $lim} {
                # -- ok to kick the user, threshold not met
                putquick "KICK $chan $nick :[cfg:get captcha:wrong:kick $chan]"
            } else {
                # -- upgrade the kick to kickban!
                set dokb 1;
            }
        }
        
        # -- send kickban for client
        if {$dokb} {
            lassign [split $uhost @] ident host
            set duration [cfg:get captcha:wrong:bantime $chan]
            kickban $nick $ident $host $chan $duration [cfg:get captcha:wrong:kick $chan]
        }
        
        unset data:captcha($nick,$lchan);          # -- response tracker
        unset data:captcha($nick,$lchan,attempts); # -- attempt counter
        
        # -- kill any existing timers
        foreach t [utimers] {
            lassign $t id string tid
            lassign $string theproc tnick
            if {$theproc eq "arm::captcha:check" && $nick eq $tnick} {
                putlog "\002captcha:msg:response:\002 killing existing response timer for nick: $nick on chan: $chan"
                killutimer $tid
            }
        }
        
        if {[array names data:captcha] eq ""} { 
            # -- unbind; safety net so we're not always listening for ALL messages
            if {[binds arm::captcha:msg:response*] ne ""} {
                putlog "\002captcha:msg:response:\002 no more waiting responses: unbind msgm - * arm::captcha:msg:response"
                unbind msgm - * arm::captcha:msg:response
            }
        }

        # -- remove VERSION reply expectation
        foreach t [utimers] {
            lassign $t secs proc timerid id
            if {[lindex $proc 0] eq "arm::scan:ctcp"} {
                lassign $proc proc nick ident host chan
                if {[info exists data:ctcp($lchan,$nick)]} {
                    # -- we're waiting for a CTCP VERSION reply from this nick in this chan
                    putlog "\002captcha:msg:response:\002 removing expectation of VERSION reply from $nick!$uhost on $chan"
                    killutimer $timerid
                    unset data:ctcp($lchan,$nick)
                }
            } 
        }        
        break; # -- only one active channel CAPTCHA at a time?  TODO: this will cause problems
    }
}

putlog "\[@\] Armour: loaded text CAPTCHA support"

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-19_ircbl.tcl
#
# IRCBL support functions (www.ircbl.org)
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- prerequisites (Tcllibc)
package require Tcl 8.6
#package require json
package require http 2
package require tls 1.7



# -- run the test
proc ircbl:query:coro {cmd ip type {comment ""}} {
    variable cfg
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]
    
    set ip [join $ip "\n"]
    if {$type eq ""} { set type [cfg:get ircbl:type *] }; # -- add default entry type
    
    if {$cmd eq "add"} {
        # -- adding an entry
        if {$comment eq ""} { set comment [cfg:get ircbl:add:comment *] }
        #set query [http::formatQuery key [cfg:get ircbl:key *] ip $ip network [cfg:get ircbl:net *] \
        set query [http::formatQuery key [cfg:get ircbl:key *] ip $ip bl_type [cfg:get ircbl:type *] comment $comment]
    } elseif {$cmd eq "del"} {
        set query [http::formatQuery key [cfg:get ircbl:key *] ip $ip bl_type [cfg:get ircbl:type *] network [cfg:get ircbl:net *]]
    } else {
        # -- invalid cmd
        debug 0 "\002ircbl:query:\002 error: no such command: $cmd"
        return; # -- TODO: error code
    }

    #catch {set tok [http::geturl [cfg:get ircbl:url:$cmd *] -query $query -keepalive 1]} error
    coroexec http::geturl [cfg:get ircbl:url:$cmd *] -query $query -keepalive 1 -timeout 3000 -command [info coroutine]
    set tok [yield]

    set error ""; # -- TODO: fix error handling
    #debug 5 "ircbl: checking for errors...(error: $error)"
    #if {[string match -nocase "*couldn't open socket*" $error]} {
    #    debug 0 "\002ircbl:query:\002 could not open socket to: [cfg:get ircbl:url:$cmd *]"
    #    http::cleanup $tok
    #    return ""
    #} 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002ircbl:query:\002 connection to [cfg:get ircbl:url:$cmd *] has timed out."
        http::cleanup $tok
        return ""
    } elseif {$status eq "error"} {
        debug 0 "\002ircbl:query:\002 connection to [cfg:get ircbl:url:$cmd *] has error."
        http::cleanup $tok
        return ""
    }
    
    set token $tok
    set data [http::data $tok]
    putlog "\002ircbl(data):\002 $data"
    set success 0

    regsub -all { <br>} $data {} data; # -- strip ' <br>'

    debug 0 "\002ircbl:query:\002 type: $type -- data: $data"
        
    if {$cmd eq "add"} {
        if {[string match -nocase "Success: * ips. bl_type: $type *" $data]} {
            # -- successful add!
            set response "done."
            debug 0 "\002ircbl:query:\002 add success: ip=$ip, bl_type=$type, comment='$comment'"
            set success 1
        } elseif {[string match -nocase "*error: ip already covered by an existing RBL listing*" $data]} {
            # -- failed add!
            set response "\002(\002error\002)\002 add failure (\002entry already exists\002)."
            debug 0 "\002ircbl:query:\002 add failure (already exists): ip=$ip, bl_type=$type, comment='$comment'"            
        } 
    
    } elseif {$cmd eq "del"} {
        if {[string match -nocase "Deleted * entries and deactivated * entries*" $data]} {
            # -- successful del!
            set response "done."
            debug 0 "\002ircbl:query:\002 del success: ip=$ip, bl_type=$type, comment='$comment'"
            set success 1
        } elseif {[string match -nocase "*: entry was added by someone else: *" $data]} {
            # -- failed del!
            set response "\002(\002error\002)\002 del failure (\002entry added by another user\002)."
            debug 0 "\002ircbl:query:\002 del failure (added by other user): ip=$ip, bl_type=$type"
        } elseif {[string match -nocase "*error: ip not listed: *" $data]} {
            # -- failed del!
            set response "\002(\002error\002)\002 del failure (\002not found\002)."a
            debug 0 "\002ircbl:query:\002 del failure (IP not listed): ip=$ip, bl_type=$type"
        } 
    }
    http::cleanup $tok
    
    if {![info exists response]} {
        set response "\002(\002info\002)\002 unknown response: $data"
        debug 0 "\002(\002info\002)\002 unknown response: $data "
    }
    
    if {$success} { return "1 [list $response]" } else { return "0 [list $response]" }
}



putlog "\[@\] Armour: loaded IRCBL support functions."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-20_ipqs.tcl
#
# IP Quality Score support functions (www.ipqualityscore.com)
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- load the command
#                       plugin   level req.   binds enabled  
set addcmd(ipqs)     {  ipqs     1            pub msg dcc    }


# -- prerequisites (Tcllibc)
package require Tcl 8.6
package require json
package require http 2
package require tls 1.7

# -- run the fraud test
# returns:
#    -1 for a connection or API error
#     0 for a pass result
#     1 for a fraud result
proc ipqs:query {ip} {
    variable cfg
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]
    
    set cfgurl [cfg:get ipqs:url *]
    set url "$cfgurl/[cfg:get ipqs:key *]/$ip"

    #catch {set tok [http::geturl $url -keepalive 1]} error
    coroexec http::geturl $url -keepalive 1 -timeout 3000 -command [info coroutine]
    set tok [yield]

    set error ""; # -- TODO: fix generic error check
    #debug 5 "ipqs: checking for errors...(error: $error)"
    #if {[string match -nocase "*couldn't open socket*" $error]} {
    #    debug 0 "\002ipqs:query:\002 could not open socket to: $cfgurl"
    #    http::cleanup $tok
    #    return -1
    #} 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002ipqs:query:\002 connection to $cfgurl has timed out."
        http::cleanup $tok
        return -1
    } elseif {$status eq "error"} {
        debug 0 "\002ipqs:query:\002 connection to $cfgurl has error."
        http::cleanup $tok
        return -1
    }
    
    set token $tok
    set data [http::data $tok]
    debug 3 "\002ipqs:\002 data: $data"
    set json [::json::json2dict $data]
    #debug 3 "\002ipqs:\002 json: $json"
    foreach {name object} $json {
        set out($name) $object
        debug 6 "\002ipqs:\002 name: $name object: $object"
    }
    http::cleanup $tok
    if {[info exists out(success)]} {
        if {$out(success) eq "false"} {
            debug 0 "\002ipqs:query:\002 error: $out(message)"
            return -1
        }
    }

    set match 0; set isproxy 0; set isfraud 0
    if {$out(proxy) eq "true" && $out(fraud_score) >= [cfg:get ipqs:minscore *]} {
        # -- IP is a proxy
        debug 0 "\002ipqs:query:\002 IP $ip is a proxy (AS$out(ASN) -- ISP: $out(ISP))"
        set match 1; set isproxy 1;
        # -- TODO special handling?
    } 
    if {$out(fraud_score) >= [cfg:get ipqs:minscore *]} {
        # -- score meets minimum for to be fraudulent
        debug 0 "\002ipqs:query:\002 IP $ip looks fraudulent (score: $out(fraud_score) -- AS$out(ASN) -- ISP: $out(ISP))"
        set match 1; set isfraud 1;
    }
    
    return "$match $isfraud $isproxy $out(fraud_score) [list $json]"

}

# -- command: ipqs
# usage: ipqs <ip>
# checks the IP Quality Score (www.ipqualityscore.com)
proc ipqs:cmd:ipqs {0 1 2 3 {4 ""}  {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5]  type stype target starget nick uh hand source chan arg 
    
    set cmd "ipqs"
    lassign [db:get id,user users curnick $nick] uid user
    if {$chan eq ""} { set chan [userdb:get:chan $user $chan]; }; # -- predict chan when not given
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }; 
    set ip [lindex $arg 0]; 
    if {$ip eq ""} { reply $stype $starget "usage: ipqs: <ip>"; return; };
    # -- command: ipqs    

    set cid [db:get id channels chan $chan]
    
    # -- IP Quality Score (www.ipqualityscore.com) -- fraud check
    lassign [ipqs:query $ip] match isfraud isproxy fraud_score json

    debug 3 "\002ipqs:cmd:ipqs:\002 ip: $ip -- match: $match -- isfraud: $isfraud -- isproxy: $isproxy -- fraud_score: $fraud_score"

    # -- IP is either a proxy or has high fraud rating
    foreach {name object} $json {
        #debug 3 "\002ipqs:cmd:ipqs:\002 $name -- $object"
        set out($name) $object
    }
    
    if {$match eq -1} { reply $type $target "\002error\002: $out(message)"; return; }
    
    reply $type $target "\002\[IPQS\]\002 \002ip:\002 $ip -- \002proxy:\002 $out(proxy) -- \002bot:\002 $out(bot_status) -- \002tor:\002 $out(tor) -- \002score:\002 $out(fraud_score) -- \002ASN:\002 $out(ASN) -- \002ISP:\002 $out(ISP)"
    
    # -- create log entry
    log:cmdlog BOT $chan $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

putlog "\[@\] Armour: loaded IPQS (www.ipqualityscore.com) support functions."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-21_support.tcl
#
# core script support functions
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# -- provide the output for a list entry
# -- used many times by arm:cmd:scan to avoid repetition
proc list:return {chan {list ""} {method ""} {value ""}} {
    variable entries;    # -- dict: blacklist and whitelist entries    
    variable flood:id;  # -- the id of a given cumulative pattern (by method,value)

    set lchan [string tolower $chan]

    # -- allow ID to be used instead of chan and other params
    if {[regexp -- {^\d+} $chan]} {
        set id $chan
        set chan [dict get $entries $id chan]
        set list [dict get $entries $id type]
        set method [dict get $entries $id method]
        set value [dict get $entries $id value]
    } else {
        # -- there can only be one unique combination of this expression
        set id [lindex [dict filter $entries script {id dictData} {
            expr {[string tolower [dict get $dictData chan]] eq [string tolower $chan] && [dict get $dictData type] eq $list \
                && [dict get $dictData method] eq $method && [dict get $dictData value] eq $value}
        }] 0]
    }   
    set ts [dict get $entries $id ts]
    set modifby [dict get $entries $id modifby]
    set action [dict get $entries $id action]
    set limit [dict get $entries $id limit]
    set hits [dict get $entries $id hits]
    set depends [dict get $entries $id depends]
    set reason [dict get $entries $id reason]

    putlog "list:return: id: $id (depends: $depends) -- chan: $chan -- list: $list -- method: $method -- value: $value"
    
    set flags [list]
    foreach i "noident onlykick nochans manual captcha disabled onlysecure silent ircbl notsecure" {
        if {[dict get $entries $id $i] eq 1} {
            if {$i eq "disabled"} { lappend flags "\002$i\002" } else { lappend flags $i }
        }
    }

    if {$depends ne ""} { set dep "(\002depends:\002 [join $depends ,]) " } else { set dep "" }
    set flags [join $flags ","]
    if {$flags ne ""} { set xtra "\002flags:\002 $flags " } else { set xtra "" }
        
    # -- interpret action
    switch -- $action {
        O   { set action "op"      }
        V   { set action "voice"   }
        B   { set action "kickban" }
        K    { set action "kickban" }
        A   { set action "accept"  }
    }
    
    # -- change response if method is text
    if {$method eq "text"} { set method "match"; set reasontext "reply"} else { set reasontext "reason" }
    
    # -- return response
    if {$limit eq "1:1:1" || $limit eq ""} {
        # -- no custom limit set
        return "\002list match:\002 ${list}list \002$method:\002 [lindex $value 0] (\002id:\002 $id $dep\002chan:\002 $chan\
             \002action:\002 $action \002hits:\002 $hits $xtra\002added:\002 [userdb:timeago $ts] ago\
             \002by:\002 $modifby \002$reasontext:\002 $reason)" 
    } else {
        # -- custom limit set
        set exlimit [split $limit :]
        lassign $exlimit joins secs hold
        if {$secs eq $hold} { set limit "$joins:$secs" } else { set limit "$joins:$secs:$hold" }
        return "\002list match:\002 ${list}list \002$method:\002 [lindex $value 0] (\002id:\002 $id $dep\002chan:\002 $chan\
             \002action:\002 $action \002hits:\002 $hits \002limit:\002 $limit $xtra\002added:\002 [userdb:timeago $ts] ago\
             \002by:\002 $modifby \002$reasontext:\002 $reason)" 
    }
}

proc list:action {id} {
    variable entries; # -- dict: blacklist and whitelist entries
    set action [dict get $entries $id action]
    # -- interpret action
    switch -- $action {
        O   { set action "op"       }
        V   { set action "voice"    }
        B   { set action "kickban"  }
        A   { set action "accept"   }
        D   { set action "deny"     }
    }
    return $action;
}

proc list:mode {id} {
    variable entries; # -- dict: blacklist and whitelist entries
    variable dbchans; # -- dict: database of channels
    
    set action [dict get $entries $id action]
    set cid [dict get $entries $id cid]
    set chan [dict get $dbchans $cid chan]
    if {[get:val chan:mode $chan] eq "secure" && $action eq "A"} { set action "V" }; # -- force ACCEPT to mean VOICE when in secure mode
    
    # -- interpret action
    switch -- $action {
        O       { set mode "+o" }
        V       { set mode "+v" }
        A       { set mode ""   }
        default { set mode ""   }
    }
    return $mode;
}

# -- start the secure mode '/who' timer
proc mode:secure {} {
    global server
    variable cfg
    variable chan:mode;  # -- the operational mode of the registered channel (by chan)
    variable scan:list;  # -- the list of nicknames to scan in secure mode:
                         #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                         #        nicks,*    :  the nicks being scanned
                         #        who,*      :  the current wholist being constructed
                         #        leave,*    :  those already scanned and left
                               
    # -- don't sent /WHO if bot still has data in serverqueue
    if {[queuesize] > 9} {
            debug 3 "\002mode:secure:\002 server queue not empty, not sending /WHO (but restarting mode:secure)"
            utimer [cfg:get queue:secure *] arm::mode:secure
            return;    
    }
                               
    # -- restart without /WHO if previous scan not yet complete
    foreach entry [array names scan:list data,*] {
        if {[get:val scan:list $entry] ne ""} {
            #debug 3 "\002mode:secure:\002 scan:list($entry) still has scan data to process, not sending /WHO (but restarting mode:secure)"
            foreach dataset [get:val scan:list $entry] {
                lassign $dataset nick chan
                debug 0 "\002mode:secure:\002 scan:list($entry) still has scan data to process, \002removing\002: [get:val scan:list $entry]"
                scan:cleanup $nick $chan 0; # -- TODO: is this the right course of action? could happen if a nick leaves too quickly.
                                            #          bot was getting stuck under this condition; trying this as a possible fix.
            }
            utimer [cfg:get queue:secure *] arm::mode:secure
            return;
        }
    }
    # -- only start the timer again if it's not already running
    set restart 1
    foreach utimer [utimers] {
        set theproc [lindex $utimer 1]
        if {$theproc eq "arm::mode:secure"} {
            # -- arm:secure is already running
            debug 3 "\002mode:secure:\002 utimer already exists, not restarting"
            set restart 0
            break;
        }
    }
    
    if {$restart} {
        if {$server eq ""} { utimer [cfg:get queue:secure *] arm::mode:secure; return; }; # -- wait until connected to server
        set clist [list]
        foreach chan [channels] {
            set lchan [string tolower $chan]
            set mode [lindex [array get chan:mode $lchan] 1]
            if {![botisop $chan]} { continue; }; # -- do not scan if bot not on chan
            if {$mode eq "secure"} { lappend clist $chan }
        }
        set nlist [join $clist ,]
        if {$nlist ne ""} {
            debug 5 "mode:secure: starting /WHO for channels: [join $clist]"
            putquick "WHO $nlist cd%cnuhiartf,102"
        }
        utimer [cfg:get queue:secure *] arm::mode:secure; # -- restart
    }
    
}


proc ctcp:action { nick uhost hand dest keyword text } { 
    # -- only process channel actions 
    if {[string index $dest 0] != "#"} { return; }
    pubm:process $nick $uhost $hand $dest $text
}

proc notc:all {nick uhost hand text {dest ""}} {
    # -- pass to pubm:all -- saves on code repetition
    pubm:process $nick $uhost $hand $dest $text
}

proc pubm:all {nick uhost hand chan text} {
    # -- pass to pubm:all -- saves on code repetition
    pubm:process $nick $uhost $hand $chan $text
}

proc pubm:process {nick uhost hand chan text} {
    global botnick
    variable cfg
    variable entries;       # -- dict: blacklist and whitelist entries
    variable nick:newjoin;  # -- state: tracking recently joined client (by nick)
    variable nick:override; # -- state: tracking exemption for client (by nick) from 'exempt' command
    variable nickdata;      # -- dict: stores data against a nickname
                            #             nick
                            #              ident
                            #             host
                            #             ip
                            #             uhost
                            #             rname
                            #             account
                            #             signon
                            #             idle
                            #             idle_ts
                            #             isoper
                            #             chanlist
                            #             chanlist_ts
    
    if {$nick eq $botnick} { return; }
    
    set cmode [get:val chan:mode $chan];              # -- operational channel mode
    if {$cmode eq "" || $cmode eq "off"} { return; }; # -- stop if mode is off
    
    # -- tidy nick
    set nick [split $nick]

    set ident [lindex [split $uhost @] 0]
    set host [lindex [split $uhost @] 1]
    set lchan [string tolower $chan]
    set lnick [string tolower $nick]

    # -- exempt if opped on common chan
    if {[isop $nick]} { return; }

    # -- exempt if voiced on common chan
    if {[isvoice $nick]} { return; }
    
    # -- exempt if umode +x
    if {[string match -nocase "*.[cfg:get xhost:ext *]" $host]} { return; }
    
    # -- exempt if local IP space
    if {[dict exists $nickdata $lnick ip]} { 
        set ip [dict get $nickdata $lnick ip]; # -- use dict data if we have it
        if {[ip:isLocal $ip] eq 1} { return; }
    } elseif {[ip:isLocal $host] eq 1 } { return; }; # -- see if host is IP
    
    # -- exempt if resolved ident
    # -- TODO: configurable?
    if {![string match "~*" $ident]} { return; }
    
    # -- exempt if manual override (cmd: exempt)
    if {[info exists nick:override($nick)]} { return; }
    
    # -- check if nick has newly joined (last 20 seconds)
    if {[info exists nick:newjoin($nick)]} { set newcomer 1 } else { set newcomer 0 }

    # -- take action on channel name repeats (spam) - or website spam for newcomers
    set match 0
    foreach word $text {
        if {[string index $word 0] eq "#" && [string tolower $word] ne [string tolower $chan]} { incr match }
    }
    if {$match > 2 || ($newcomer && [regexp -- {(?:https?\://|www\.[A-Za-z_\d-]+\.)} $text])} {
        # -- spammer match!
        debug 1 "pubm:all: spam detected from [join $nick]!$uhost (\002matches:\002 $match)"
        kickban $nick $ident $host $chan [cfg:get ban:time $chan] "Armour: spam is not tolerated."
        return;
    }; # -- end of channel name repeats
    
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
            debug 1 "pubm:all: annoyance detected from [join $nick]!$uhost (\002repeats:\002 $repeat($word))"
            kickban $nick $ident $host $chan [cfg:get ban:time $chan] "Armour: annoyances are not tolerated."
            # -- automatic blacklist entries
            if {[cfg:get auto:black $chan]} {

                # -- there can only be one unique combination of this expression
                set id [lindex [dict filter $entries script {id dictData} {
                    expr {[dict get $dictData chan] eq $chan && [dict get $dictData type] eq "black" \
                        && [dict get $dictData method] eq "host" && [dict get $dictData value] eq $host}
                }] 0]

                if {$id eq ""} {
                    # -- add automatic blacklist entry
                    set reason "(auto) annoyances are not tolerated"
                    debug 1 "pubm:all: adding auto blacklist entry: type: B -- method: host -- value: $host -- modifby: Armour -- action: B -- reason: $reason"
                    # -- add the list entry (we don't need the id)
                    set tid [db:add B $chan host $host Armour B "" $reason]
                }
            }
            return;
        }
    }; # -- end of word repeat
    
    # -- kickban on coloured profanity for all, or any profanity for newly joined clients (last 20seconds)
    if {[regexp -- {\x3} $text] || $newcomer} {
        # -- colour codes used in text
        foreach word [cfg:get badwords $chan] {
            if {[string match -nocase $word $text]} {
                # -- badword match!
                debug 1 "pubm:all: badword detected from [join $nick]!$uhost (\002mask:\002 $word)"
                kickban $nick $ident $host $chan [cfg:get ban:time $chan] "Armour: abuse is not tolerated."
                return;
            }
        }
    }
    
    if {$newcomer && [regexp -- {\x3} $text]} {
        # -- colour codes used in text
        debug 1 "pubm:all: colour detected from newcomer [join $nick]!$uhost (\002mask:\002 $word)"
        kickban $nick $ident $host $chan [cfg:get ban:time $chan] "Armour: tone it down a little"
        return;
    }
    
    # -- check string length (if newcomer)
    set length [string length $text]
    if {$newcomer && $length > 200} {
        # -- client is a newcomer (joined less than 20secs ago) & string length over 200 chars
        debug 1 "pubm:all: excessive string detected from newcomer [join $nick]!$uhost (\002length:\002 $length chars)"
        kickban $nick $ident $host $chan [cfg:get ban:time $chan] "Armour: excess strings not yet tolerated from you."
        return;
    }
}


# -- adapt:unset
# clear adaptive regex tracking for a pattern
proc adapt:unset {type exp} {
    variable adapt:n;   # -- array: tracking adaptive regex for: nick
    variable adapt:i;   # -- array: tracking adaptive regex for: ident
    variable adapt:ni;  # -- array: tracking adaptive regex for: nick!ident
    variable adapt:nir; # -- array: tracking adaptive regex for: nick!ident/rname
    variable adapt:nr;  # -- array: tracking adaptive regex for: nick/rname
    variable adapt:ir;  # -- array: tracking adaptive regex for: ident/rname
    variable adapt:r;   # -- array: tracking adaptive regex for: rname
    
    switch -- $type {
        nick             { set array "adapt:n"   }
        ident            { set array "adapt:i"   }
        nick!ident       { set array "adapt:ni"  }
        nick!ident/rname { set array "adapt:nir" }
        nick/rname       { set array "adapt:nr"  }
        ident/rname      { set array "adapt:ir"  }
        rname            { set array "adapt:r"   }
    }

    if {[info exists [set array]($exp)]} {
        debug 3 "adapt:unset: removing adaptive regex tracker (type: $type array: $array exp: [join $exp])"
        unset [set array]($exp)
    }
}

# -- arm:flud:unset
# clear floodnet track
proc flud:unset {chan id snick} {
    variable flud:count;     # -- the count of a given cumulative pattern (by id)
    variable flud:nickcount; # -- the IDs that have already been matched for a given nick (by chan,nick)
                             # -- avoids double matching (first from channel join, second from /WHO result)

    # -- remove ID from count list
    if {[info exists flud:count($id)]} {
        debug 3 "flud:unset: removing floodnet tracker flud:count([join $id])"
        unset flud:count($id)
    }

    # -- remove ID from nickcount list
    if {[info exists flud:nickcount($chan,[split $snick])]} {
        debug 3 "flud:unset: flud:nickcount($chan,[split $snick]): [get:val flud:nickcount $chan,$snick]"
        set ids [join [get:val flud:nickcount $chan,$snick]]
        if {$ids ne ""} {
            set x [lsearch $ids $id]
            debug 3 "flud:unset: removing floodnet tracker flud:nickcount($chan,$snick)"
            set ids [lreplace $ids $x $x]; # -- remove ID from list
        }
        if {$ids eq ""} { unset flud:nickcount($chan,[split $snick]) } \
        else { set flud:nickcount($chan,$snick) $ids }
    }
}

# -- flood:text:unset
# clear cumulative text entry tracker
proc flood:text:unset {value} {
    variable flood:text
    if {[info exists flood:text($value)]} {
        debug 5 "flood:text:unset: removing floodnet tracker flood:text($value)"
        unset flood:text($value)
    }
}

# -- flood:line:decr
# decrease cumulative text entry count
proc flood:line:decr {value} {
    variable flood:line
    # -- value is a nick or a channel, depending on counter type
    if {[info exists flood:line($value)]} {
        set val [get:val flood:line $value]
        debug 5 "flood:line:decr: decreasing flood:line tracker flood:line($value) -- current: $val"
        incr flood:line($value) -1
        if {[get:val flood:line $value] == 0} {
            debug 5 "flood:line:decr: removing nil flood:line tracker flood:line($value)"
            unset flood:line($value)
        }
    }
}

# -- remove the temp channel lock after a channel line flood
proc flood:line:unmode {chan} {
    variable cfg
    regsub -all {\+} [cfg:get flood:line:chan:mode $chan] {-} unmode
    # -- NOTE: we don't need to make the removal dependant on the flood continuing at this time
    #          as it can be safe to assume that the channel lock should prevent further floods
    putnow "MODE $chan $unmode"
}


# -- unset netsplit tracker
proc split:unset {value} {
    variable cfg
    variable data:netsplit;  # -- state: tracks the presence of a netsplit
    if {[info exists data:netsplit($value)]} {
        debug 2 "arm:split:unset: unsetting netsplit([join $value]) after [cfg:get split:mem *] mins"
        unset data:netsplit($value)
    }
}

# -- newjoin:unset
# clear newjoin trackers
proc newjoin:unset {nick chan} {
    variable nick:newjoin;  # -- state: tracks that a nick has recently joined a channel (by chan,nick)
    variable nick:jointime; # -- stores the timestamp a nick joined a channel (by chan,nick)
    variable jointime:nick; # -- stores the nick that joined a channel (by chan,timestamp)
    
    # -- remove associated newjoin state for nick on chan
    if {[info exists nick:newjoin($chan,$nick)]} {
        debug 4 "newjoin:unset: removed newjoin tracker newjoin:nick($chan,[join $nick]) for nick: $nick"
        unset nick:newjoin($chan,$nick)
    }
    
    # -- remove associated newjoin state for nick on chan
    if {[info exists nick:jointime($chan,$nick)]} {
        debug 4 "newjoin:unset: removed newjoin timestamp tracker nick:jointime($chan,[join $nick]) for nick: $nick"
        unset nick:jointime($chan,$nick)
    }   
    
    # -- remove associated jointime for nick on chan
    foreach ts [array names jointime:nick] {
        set tnick [get:val jointime:nick $chan,$ts]
        if {$nick eq $tnick} { 
            debug 4 "newjoin:unset: removed newcomer jointime (timestamp) tracker join:time($chan,$ts) for nick: $nick"
            unset jointime:nick($chan,$ts) 
        }
    }   
}

# -- kill adaptive pattern timer unset
proc adapt:preclear {regexp} {
    set ucount 0
    foreach utimer [utimers] {
        lassign $utimer secs timer id count
        lassign $timer func ltype pattern
        if {$func != "adapt:unset"} { continue; }
        debug 4 "adapt:preclear: function: $func pattern: $pattern utimerID: $id"
        if {$pattern == [join $regexp]} {
            # -- kill the utimer
            incr ucount
            debug 3 "adapt:preclear: match! killing utimerID: $id"
            killutimer $id
        } 
    }
    debug 3 "adapt:preclear: killed $ucount utimers"
}

# -- kill floodnet counter timer unset
proc flud:preclear {value} {
    debug 4 "flud:preclear: started for flud value: $value"
    set ucount 0
    foreach utimer [utimers] {
        lassign $utimer secs timer id count
        lassign $timer func result
        if {$func != "flud:unset"} { continue; }
        # -- pattern is second arg of timer call (count is second)
        debug 4 "flud:preclear: function: $func value: $result utimerID: $id"
        if {$value == $result} {
            # -- kill the utimer
            incr ucount
            debug 3 "flud:preclear: match! killing utimerID: $id"
            killutimer $id
        } 
    }
    debug 3 "flud:preclear: killed $ucount utimers"
}

# -- generic utimer preclear
proc preclear:utimer {tfunc {value ""}} {
    debug 4 "preclear:utimer started for utimer: $value"
    set ucount 0
    foreach utimer [utimers] {
        lassign $utimer secs timer id count
        lassign $timer func var
        if {$func != $tfunc} { continue; }
        if {$value == "" || $var == $value} {
            # -- kill the utimer
            incr ucount
            debug 1 "preclear:utimer: match! killing utimerID: $id (func: $func -- value: $value)"
            killutimer $id
        }
    } 
    debug 3 "preclear:utimer killed $ucount utimers"
}

# -- generic timer preclear
proc preclear:timer {tfunc {value ""}} {
    debug 4 "preclear:timer started for timer: $value"
    set count 0
    foreach timer [timers] {
        lassign $timer secs thetimer id count
        lassign $thetimer func var
        if {$func ne $tfunc} { continue; }
        if {$value eq "" || $var eq $value} {
        # -- kill the timer
            incr count
            debug 3 "preclear:timer match! killing timerID: $id (func: $func -- value: $value)"
            killtimer $id
        }
    } 
    debug 3 "preclear:timer killed $count timers"
}

# -- work out how to know if this is a full channel scan, or channel join
# -- and determine the channel itself!
# -- TODO: this proc isn't actually used; to confirm, but can likely be deleted
proc chan:predict {snick} {
    variable cfg
    variable scan:full;       # -- tracks data for full channel scan by chan,key (for handling by arm::scan after /WHO):
                              #    chan,state :  tracks enablement
                              #    chan,count :  the count of users being scanned
                              #    chan,type  :  the type for responses
                              #    chan,target:  the target for responses
                              #    chan,start :  the start time for runtime calc
    variable nick:joinclicks; # -- the list of click references from channel joins (by nick)
    variable nick:clickchan;  # -- the channel associated with a join time in clicks (by clicks)
    set nick [join $snick]
    putlog "\002 chan:predict: 1 \002"
    # -- channel joins
    set fullclick 0; set firstfchan ""
    foreach i [array names scan:full "*,state"] {
        set chan [lindex [split $i ,] 0]
        set sstart [lindex [array get scan:full "$chan,start"] 1]
        if {$fullclick eq 0} { set fullclick $sstart; set firstfchan $chan } \
        elseif {$sstart < $fullclick} { set fullclick $sstart; firstfchan $chan }
    }
    # -- channel joins
    set firstjoin 0; set firstjchan ""
    foreach i [array names nick:joinclicks($snick)] {
        if {$firstjoin == 0} { set firstjoin $i; set firstjchan [get:val nick:clickchan $firstjoin]; } \
        elseif {$i < $firstjoin} { set firstjoin $i set firstjchan [get:val nick:clickchan $firstjoin]; }
    }
    set full 0;  # -- tells arm::who whether the chan associated with its scan is a full channel scan
    if {$fullclick != 0} {
        putlog "\002 chan:predict: 2 \002"
        # -- there is a full chan scan
        if {$firstjoin != 0} {
            putlog "\002 chan:predict: 3 \002"
            # -- there is an unprocessed join from nick, find the earliest
            if {$fullclick < $firstjoin} {
                putlog "\002 chan:predict: 4 \002"
                # -- channel scan was first
                set chan $firstfchan; set full 1; set clicks $firstjoin
            } else {
                #-- join was first
                putlog "\002 chan:predict: 5 \002"
                set chan $firstjchan; set clicks $fullclick
            }
        } else {
            # -- no channel join
            putlog "\002 chan:predict: 6 \002"
            set chan $firstfchan; set full 1; set clicks $fullclick
        }
    } elseif {$firstjoin != 0} {
        putlog "\002 chan:predict: 7 \002"
        # -- no chan scan, but there is a join
        set chan $firstjchan
        set clicks $firstjoin
    } else {
        putlog "\002 chan:predict: 8 \002"
        # -- no chan scan, no channel join
        # -- this shouldn't even happen!  apply default chan as safety net
        #set chan [db:get chan channnels id 2]; # -- channel id 2 (1 is global *); TODO
        set chan [cfg:get chan:def *]
        set clicks 0
    }
    debug 3 "chan:predict: channel predicted from nick: $snick -- $chan $full $clicks"
    return "$chan $full $clicks";
}


proc report {type target string {chan ""} {chanops "1"}} {
    variable cfg
    variable scan:full; # -- stores data when channel scan in progress (arrays: chan,<chan> and count,<chan>)
    
    set prichan [db:get id channels id 2]; # -- channel id 2 (1 = global):  TODO -- support default chan from config
    
    # -- obtain the right chan for opnotice
    # -- TODO: properly support multiple channels
    if {[info exists scan:full]} {
        # -- full channel scan under way
        set list [lsort [array names scan:full]]
        foreach channel $list {
            set chan [lindex [split $channel ,] 1]    
        }
        if {![info exists chan]} { set chan $prichan }
    } elseif {$chan eq ""} { set chan $prichan }

    set rchan [cfg:get chan:report $chan]
    
    if {$type eq "white"} {
        if {[cfg:get notc:white $chan]} { putquick "NOTICE $target :$string"}
        if {[cfg:get opnotc:white $chan]} { putquick "NOTICE @$chan :$string"}
        if {[cfg:get dnotc:white $chan] && $rchan ne ""} { putquick "NOTICE $rchan :$string"}
    } elseif {$type eq "black"} {
        if {[cfg:get notc:black $chan]} { putquick "NOTICE $target :$string" }
        if {$chanops && ([cfg:get opnotc:black $chan] || [get:val chan:mode $chan] eq "secure")} { putquick "NOTICE @$chan :$string" }
        if {([cfg:get dnotc:black $chan] || [get:val chan:mode $chan] eq "secure") && $rchan ne ""} { putquick "NOTICE $rchan :$string" }
    } elseif {$type eq "text"} {
        if {[cfg:get opnotc:text $chan]} { putquick "NOTICE @$chan :$string" }
        if {[cfg:get dnotc:text $chan] && $rchan ne ""} { putquick "NOTICE $rchan :$string" }
    } elseif {$type eq "operop"} {
        if {[cfg:get opnotc:operop $chan]} { putquick "NOTICE @$chan :$string" }
        if {[cfg:get dnotc:operop $chan] && $rchan ne ""} { putquick "NOTICE $rchan :$string" }
    } elseif {$type eq "debug"} {
        if {$rchan ne ""} { putquick "NOTICE $rchan :$string" }
    }
}


# -- remove value from a list
# - be very careful making changes to this proc
proc list:remove {list value} {
    set value [split $value]
    upvar 1 $list var
    #ebug 4 "list:remove: removing $value from $list"
    if {![info exists var]} {
        debug 1 "list:remove: \002(error)\002 variable $list does not exist!"
        return;
    }
    set idx [lsearch $var $value]
    if {$idx != "-1"} {
        set var [lreplace $var $idx $idx]
        debug 4 "\002list:remove:\002 removed $value from $list"
    }
}

# -- kill all timers and utimers
# -- used on startup and rehash
proc kill:timers {} {
    # -- kill existing timers
    set ucount 0
    set count 0
    foreach utimer [utimers] {
        incr ucount
        debug 1 "kill:timers: killing utimer: $utimer"
        killutimer [lindex $utimer 2] 
    }
    foreach timer [timers] {
        incr count
        debug 1 "kill:timers: killing timer: $timer"
        killtimer [lindex $timer 2] 
    }
    debug 1 "kill:timers: killed $ucount utimers and $count timers"
}

# -- voice the nick
proc voice:give {chan nick} {
    variable cfg
    variable voicelist; # -- store list of nicks to stack voice on chan
    putlog "\002voice:give:\002 voicing $nick on $chan"
    # -- stack voice?
    if {[cfg:get stackvoice $chan]} { lappend voicelist($chan) $nick } else {
        # -- single voice
        putserv "MODE $chan +v $nick" -next
    }    
}

# -- stack the voice modes
proc voice:stack {} {
    variable cfg
    variable voicelist; # -- array: list of nicks that need to be stack voiced (by chan)
    foreach chan [array names voicelist] {
        while {$voicelist($chan) ne ""} {
            #putlog "\002voice:stack:\002 voicing $voicelist($chan)"
            # -- voice stack workaround (pushmode doesn't work as client not in chan yet)
            set length [llength $voicelist($chan)]
            if {$length >= 6} { set modes "+vvvvvv" } else { set modes "+[string repeat "v" $length]" }
            debug 2 "voice:stack: executing: MODE $chan $modes [join [lrange $voicelist($chan) 0 5]]"
            putquick "MODE $chan $modes [join [lrange $voicelist($chan) 0 5]]"
            set voicelist($chan) [lreplace $voicelist($chan) 0 5]
        }       
    }
    utimer [cfg:get stack:secs *] arm::voice:stack
}

# -- build longtypes (ltypes) -- adaptive regex
# -- ltypes
array set adapt:ltypes {
    n   {nick}
    ni  {nick!ident}
    nir {nick!ident/rname}
    nr  {nick/rname}
    i   {ident}
    ir  {ident/rname}
    r   {rname}
}

# -- calculate runtime
proc runtime {{start ""}} {
    if {$start eq ""} { return "unknown" }; # -- start time not known
    set end [clock clicks]
    return "[expr ($end-$start)/1000/1000.0] sec"
}

# -- ctcp version response
proc ctcp:version {nick uhost hand dest keyword args} {
    putquick "NOTICE $nick :\001VERSION Armour [cfg:get version *] (rev: [cfg:get revision]) -- https://www.armour.bot -- Empus <empus@undernet.org>\001"
    return 1;
}

# -- sending join data to external scripts for integration
proc integrate {nick uhost hand chan extra} {
    # -- pass join arguments to other standalone scripts
    foreach proc [cfg:get integrate:procs $chan] {
        debug 0 "arm:integrate: passing data to external script proc $proc: $nick $uhost $hand $chan $extra"
        $proc $nick $uhost $hand $chan $extra
    }
}

# -- obtain a hostmask to use (for bans)
proc getmask {nick {xuser "0"} {ident ""} {host ""}} {
    if {$xuser ne 0} {
        # -- user is authed
        set mask "*!*@$xuser.[cfg:get xhost:ext *]";
    } else {
        # -- user is not authed
        set uhost [getchanhost $nick]
        if {$uhost ne ""} {
            lassign [split $uhost @] ident host
        } 
        if {[string match "~*" $uhost]} { set mask "*!~*@$host" } else {
            # -- include ident in the banmask, where ~ is not present?
            if {[cfg:get ban:idents *]} {
                set mask "*!$ident@$host"
            } else { set mask "*!*@$host" }
        }
    }
    return $mask; # -- return the banmask
}

# -- return whether a mask was recently banned in a channel
proc ischanban {chan mask} {
    #variable data:chanban;  # -- state: tracks recently banned masks for a channel (by 'chan,mask')
    set exists [get:val data:chanban $chan,$mask]
    if {$exists eq 1} { return 1 } else { return 0 }
}

# -- ensure IP is valid
proc isValidIP {ip} {
    # -- TODO: add support for IPv6
    if {![regexp -- {(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)} $ip]} { 
        return 0; 
    }
    return 1;
}

# -- cleanup some vars when finished scan
# -- restart '/names -d' timer if this was last nick in the scan list
proc scan:cleanup {nick chan {leave ""}} {
    variable scan:list;    # -- the list of nicknames to scan in secure mode:
                           #        data,*     :  a list to be scanned: nick chan full clicks ident ip host xuser rname
                           #        nicks,*    :  the nicks being scanned
                           #        who,*      :  the current wholist being constructed
                           #        leave,*    :  those already scanned and left
    variable exempt;       # -- state: stores scan exemption for a client (by nick)
    variable captchasent;  # -- state: where a captcha has already been sent (by chan,nick)
    variable captchaflag;  # -- state: where a captcha flag is enabled for a matched pattern (by chan,nick)
    
    if {[info exists exempt($nick)]} { unset exempt($nick) }
    if {[info exists captchasent($chan,$nick)]} { unset captchasent($chan,$nick) }
    if {[info exists captchaflag($chan,$nick)]} { unset captchaflag($chan,$nick) }

    set lchan [string tolower $chan]
    
    set idx 0
    foreach list [get:val scan:list data,$lchan] {
        set lnick [lindex $list 0]
        if {$nick eq $lnick} {
            # -- removing scanlist entry
            set scan:list(data,$lchan) [lreplace [get:val scan:list data,$lchan] $idx $idx]
            putlog "\002scan:cleanup:\002 removed $nick from scan:list(data,$lchan)"
        }
        incr idx
    }
    
    if {$leave eq ""} {
        # -- remove the nick from the paranoid scanlist
        list:remove scan:list(leave,$lchan) $nick;  # -- remove from scan leave list
        list:remove scan:list(nicks,$lchan) $nick;  # -- remove from scan nick list
    } else {
        # -- leave the client to prevent future scans
        if {$nick ni [get:val scan:list leave,$lchan]} { lappend scan:list(leave,$lchan) $nick; }; # -- add to leave list
    }
}


# -- add log entry
proc log:cmdlog {source chan chan_id user user_id cmd params bywho target target_xuser wait} {
    variable cfg
    db:connect
    set db_chan [db:escape $chan]
    set db_user [db:escape $user]
    set db_params [db:escape $params]
    set db_bywho [db:escape $bywho]
    set db_target [db:escape $target]
    set db_target_xuser [db:escape $target_xuser]
    db:query "INSERT INTO cmdlog (timestamp, source, chan, chan_id, user, user_id,\
        command, params, bywho, target, target_xuser, wait) \
        VALUES ('[clock seconds]', '$source', '$db_chan', $chan_id, '$db_user', '$user_id', '$cmd',\
        '$db_params', '$db_bywho', '$db_target', '$db_target_xuser', '$wait')"
    db:close
    
    set xtra ""
    if {$params ne ""} { append xtra " $params" }
    if {$user ne ""} { append xtra " (\002user:\002 $user)" }

    if {[cfg:get chan:report $chan] ne ""} { putquick "PRIVMSG [cfg:get chan:report $chan] :\002cmd:\002 [string tolower $cmd]$xtra" }
    return;
}

# -- generate a random password
# -- arm:randpass [length] [chars]
# -- length to use is provided by config option if not provided
# -- chars to randomise are defaulted if not provided
proc randpass {{length ""} {chars ")(*&^%$\#@!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz)(*&^%$\#@!"}} {
    variable cfg
    if {$length eq ""} { set length [cfg:get randpass *] }
    set range [expr {[string length $chars]-1}]
    set text ""
    for {set i 0} {$i < $length} {incr i} {
       set pos [expr {int(rand()*$range)}]
       append text [string range $chars $pos $pos]
    }
    return $text
}

# -- eggdrop will report parting user as still in chan with 'onchan'
# need to loop through results and exclude that parting chan to get true result
proc oncommon {nick exclude} {
    set onchan 0
    foreach chan [channels] {
        if {[onchan $nick $chan] && $chan ne $exclude} { set onchan 1 }
    }
    return $onchan
}

# -- helper proc to increase the hit count of a list entry in a nested dict
proc hits:incr {id} {
    variable entries;  # -- dict: blacklist and whitelist entries
    #putlog "entry id: [dict get $entries $id hits]"
    dict with entries $id {incr hits}
    #putlog "\002new\002 entry id: [dict get $entries $id hits]"
}

# -- common code to setup vars for commands
proc proc:setvars {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    set type $0
    if {$type eq "pub"} {
        set nick $1; set uh $2; set hand $3; set chan $4; set arg $5; set target $chan; set source "$nick!$uh"
        if {[cfg:get help:notc $chan]} { set starget $nick; set stype "notc" } else { set stype "pub"; set starget $chan }
    }
    if {$type eq "msg"} {
        set nick $1; set uh $2; set hand $3; set arg $4; set target $nick; set source "$nick!$uh"
        set stype "notc"; set starget $nick; set chan [cfg:get chan:def *];
    }
    if {$type eq "dcc"} {
        set hand $1; set idx $2; set arg $3; set target $idx; set nick $hand; set source "$hand/$idx"
        set stype "dcc"; set starget $idx; set uh $idx; set chan [cfg:get chan:def *];
    }    
    
    #debug 0 "\002proc:setvars\002: $1 $2 $3 $4 $5"
    #debug 0 "\002proc:setvars\002: arg: $arg"
    return "$type $stype $target $starget $nick $uh $hand $source $chan [list $arg]"
}

# -- coroutine debug
proc corotrace {} {
    trace add execution [info coroutine] enter {corodebug:log ENTER}
    trace add execution [info coroutine] leave {corodebug:log LEAVE}
    trace add command [info coroutine] delete {corodebug:log DELETE}
}
proc corodebug:log {op cmd args} { debug 5 "$op $cmd < [backtrace]" }
proc backtrace {} {
    set b ""
    set lvl [info level]
    for {set i -2} {$i > -$lvl} {incr i -1} {
        lappend b [info frame $i]
    }
    join $b " < "
}
# -- end coroutine debug

# -- safer (and shorter helper proc) for eggdrop 'onchan' when chan doesn't exist
proc onValidchan {nick chan} {
    if {![validchan $chan]} { return 0; }
    if {[onchan $nick $chan]} { return 1 } else { return 0; }
}

# -- languages
array set code2lang {
    ar    {    Arabic      }
    ae    {    Arabic      }
    ca    {    Catalan     }
    de    {    German      }
    dk    {    Danish      }
    en    {    English     }
    es    {    Spanish     }
    fr    {    Francais    }
    gr    {    Greek       }
    hu    {    Hungarian   }
    it    {    Italian     }
    mk    {    Macedonian  }
    nl    {    Dutch       }
    no    {    Norsk       }
    pt    {    Portuguese  }
    ro    {    Romanian    }
    sv    {    Svenska     }
    tr    {    Turkce      }
    yu    {    Serbain     }
    rs    {    Serbain     }
    sw    {    Swedish     }
    ur    {    Urdu        }
    ph    {    Philipines  }
}
array set lang2code {
    arabic        {ar}
    catalan       {ca}
    german        {de}
    danish        {dk}
    english       {en}
    spanish       {es}
    francais      {fr}
    greek         {gr}
    hungarian     {hu}
    italian       {it}
    macedonian    {mk}
    dutch         {nl}
    norsk         {no}
    portuguese    {pt}
    romanian      {ro}
    svenska       {sv}
    turkce        {tr}
    serbain       {yu}
    swedish       {sw}
    urdu          {ur}
    philipines    {ph}
}

# -- checks if IP is localhost or rfc1918
# -- avoid IPv6 and hostnames
proc ip:isLocal {ip} {
    if {$ip eq "0::"} { return 1; }
    if {[string match "*:*" $ip] eq 1} { return 0; }; # -- cidr:match will fail on IPv6
    if {![regexp -- {^\d+\.\d+\.\d+\.\d+} $ip]} { return 0; }; # -- must be IPv4; ensure this is not a hostname
    if {$ip eq "127.0.0.1"} { return 1; }
    if {[cidr:match $ip "10.0.0.0/8"]     } { return 1 }
    if {[cidr:match $ip "172.16.0.0/12"]  } { return 1 }
    if {[cidr:match $ip "192.168.0.0/16"] } { return 1 }
    return 0;
}

# -- escape special chars in array
proc escape {value} {
    regsub -all {\[} $value {\\[} nvalue
    regsub -all {\]} $nvalue {\\]} nvalue
    regsub -all {\{} $nvalue {\\{} nvalue
    regsub -all {\}} $nvalue {\\}} nvalue
    if {$value ne $nvalue} { quote:debug 2 "escape: value $value is now $nvalue" }
    return $nvalue;
}

# -- check if nick is allowed to be opped (strictop) or voiced (strictvoice) in chan
proc strict:isAllowed {mode chan nick} {
    global botnick
    variable nickdata; # -- dict: stores data against a nickname
                       #           nick
                       #           ident
                       #           host
                       #           ip
                       #           uhost
                       #           rname
                       #           account
                       #           signon
                       #           idle
                       #           idle_ts
                       #           isoper
                       #           chanlist
                       #           chanlist_ts
    variable entries;  # -- dict: blacklist and whitelist entries
    variable dbchans;  # -- dict to store channel db data
    variable chan:id;  # -- the id of a registered channel (by chan)
    
    set lchan [string tolower $chan]

    if {[string match -nocase $botnick $nick]} { return 1 }; # -- always allow bot to be opped & voiced
    
    if {$mode eq "op"} {
        # -- strictop
        set cmode "strictop"; set action "O"; set rlvl 100
    } elseif {$mode eq "voice"} {
        # -- strictvoice
        set cmode "strictvoice"; set action "V"; set rlvl 25
    }
    
    set id [get:val chan:id $chan]
    if {![dict exists $dbchans $id $cmode]} { return 1; }; # -- allowed if not set
    set curmode [dict get $dbchans $id $cmode]
    if {$curmode eq "on"} {
        # -- strict mode is on, check access
        set user [db:get user users curnick $nick]
        if {$user ne ""} {
            set level [userdb:get:level $user $chan]
            set glevel [userdb:get:level $user *]
        } else { set level 0; set glevel 0; }
        
        # -- get all whitelist user, host, and chan entries with op|voice action
        set ids [dict keys [dict filter $entries script {id dictData} {
            expr {[dict get $dictData chan] eq $chan && [dict get $dictData type] eq "white" \
                && [dict get $dictData action] eq $action && ([dict get $dictData method] eq "user"\
                || [dict get $dictData method] eq "host" || [dict get $dictData method] eq "chan")}
        }]]
        
        set match 0
        set ltnick [string tolower $nick]
        set tuhost [getchanhost $nick]
        set thost [lindex [split $tuhost @] 1]
        if {[dict exists $nickdata $ltnick account] eq 1} { set account [dict get $nickdata $ltnick account] } \
        else { set account 0 }
        foreach id $ids {
            set method [dict get $entries $id method]
            set value [dict get $entries $id value]
            putlog "\002strict:isAllowed\002: chan: $chan -- mode: $mode - matching method: $method -- value: $value -- account: $account"
            if {$method eq "host"} {
                if {[string match -nocase $value $nick!$tuhost]} { set match 1; break; } \
                elseif {[string match -nocase $value $thost]} { set match 1; break; }
            } elseif {$method eq "user"} {
                if {[string match -nocase $value $account]} { set match 1; break; }
            } elseif {$method eq "chan"} {
                if {[onchan $nick $value]} { set match 1; break; }
            }
        }            
        if {$level < $rlvl && $glevel < $rlvl && $match eq 0} {
            # -- user not allowed to be opped|voiced in chan
            return 0;
        }
    }
    return 1; # -- default to allowed
}

debug 0 "\[@\] Armour: loaded support functions."

}
# -- end namespace


# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-22_update.tcl
#
# script autoupdate
#
# Provides the ability for the bot to periodically check for new script updates
# 'update' command to check, install, restore the last script backup, or list github branches
#
# usage:
#     update <check|install|restore|branches> [branch]
#
# Handling where multiple Armour bots run from a common eggdrop install directory:
#
# Features:
#   - create first time use backup of entire armour directory (safety net)
#   - compare new sample config with existing values, retaining existing where they differ
#   - automatically detect an installed update from another bot and apply it locally
#   - prevent one bot from downloading updates if another bot already has a download in progress
#
# New configuration options:
#   - whether to periodically check for updates (hourly)
#   - whether to send notes to global 500 users when new updates are found
#   - whether to automatically install new updates (or require manual install via 'update' command)
#   - what Github branch to check and apply updates from (default: master)
#   - age (in days) of old script backups to periodically delete (hourly)
#   - debug mode to download and stage updates but not automatically apply them
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

package require tls
package require http
package require json


# -- run hourly update check
bind cron - "0 * * * *" arm::update:cron

# -- github dependency
source ./armour/packages/github.tcl

# -- cronjob to run periodic update check
proc update:cron {minute hour day month weekday} {
    set debug [cfg:get update:debug]

    # -- flush periodic script backups older than N days
    set flush [cfg:get update:flush]
    set flushed 0
    # -- find staging script and backup directories last modified >N days ago
    set stagingdirs [exec find ./armour/backup -maxdepth 1 -name armour-* -type d -mtime +$flush]
    set backupdirs [exec find ./armour/backup -maxdepth 1 -name backup-* -type d -mtime +$flush]
    foreach scriptdir "$stagingdirs $backupdirs" {
        if {[string match "armour-*" $scriptdir]} { set dirtype "new script staging" } \
        else { set dirtype "old script backup" }
        if {!$debug} {
            incr flushed
            exec rm -rf $scriptdir
            debug 0 "\002update:cron:\002 deleted $dirtype directory: \002$scriptdir\002"
        } else {
            debug 0 "\002update:cron:\002 debug \002enabled\002 -- not deleting $dirtype directory: \002$scriptdir\002"
        }
    }
    if {$flushed > 0} {
        set out "deleted \002$flushed\002 backup and staging directories (older than \002$flush\002 days)"
        debug 0 "\002update:cron:\002 $out"
        update:note "\002Armour\002 $out" ""
    }

    # -- check for automatic update
    if {[cfg:get update] eq 0} {
        debug 4 "\002update:cron:\002 periodic update check disabled in config setting: \002cfg(update)\002"
        return;
    }

    # -- check for update
    set branch [cfg:get update:branch]
    lassign [update:check $branch $debug] success ghdata output
    if {$success eq "0"} {
        # -- http error
        debug 0 "\002update:cron:\002 update check failed (error: [lrange $data 1 end])"
        return;
    } else {
        # -- version data
        set output [join $output]
        set version [dict get $ghdata version]
        set revision [dict get $ghdata revision]
        set gversion [dict get $ghdata gversion]
        set grevision [dict get $ghdata grevision]
        set update [dict get $ghdata update]
        set newversion [dict get $ghdata newversion]
        set newrevision [dict get $ghdata newrevision]
        set branch [dict get $ghdata branch]
    }

    # -- check for available update
    if {$update eq 0} {
        debug 0 "\002update:cron:\002 no update available. currently running \002version:\002 $version (\002revision:\002 $revision)"
        return;
    }

    # -- updated version available
    debug 0 "\002update:cron:\002 $output"

    # -- check for automatic update
    if {[cfg:get update:auto] eq 0} {
        debug 0 "\002update:cron:\002 automatic update disabled in config setting: \002cfg(update:auto)\002"
        return;
    }

    # -- begin the automatic update!
    dict set ghdata response ""; # -- null the value because no nick is receiving the response
    update:download $ghdata;     # -- use default branch
    return;
}

# -- command: update
# usage: update <check|install|restore|branches> [branch]
# check: check for update, with optional github branch
# install: install update, with optional github branch
# restore: restore last script backup
# branches: show available github branches
proc arm:cmd:update {0 1 2 3 {4 ""} {5 ""}} {
    variable ghdata
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    set cmd "update"
    lassign [db:get id,user users curnick $nick] uid user
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    # -- end cmd proc template

    lassign $arg action branch
    if {$branch eq "" || $branch eq "-f" || $branch eq "-t"} { set branch [cfg:get update:branch] }; # -- revert to config branch (default of master)

    if {$action ne "check" && $action ne "install" && $action ne "restore" && $action ne "branches" \
        && $action ne "c" && $action ne "i" && $action ne "r" && $action ne "b"} {
        reply $stype $starget "usage: update <check|install|restore|branches> \[branch\]"
        return;
    }

    # -- allow '-t' to be used to specify test mode (debug), even if not set in config
    if {[lsearch $arg "-t"] >= 0} { 
        debug 0 "\002update:\002 debug mode overriden to be \002enabled\002"
        set debug 1 
    } else {
        set debug [cfg:get update:debug]
        debug 0 "\002update:\002 debug mode obtained from config: \002$debug\002"
    }

    # -- get the data
    lassign [update:check $branch $debug] success ghdata output
    if {$success eq "0"} {
        # -- error
        set error [join $ghdata]
        if {$error eq "404"} { set error "branch not found" }
        reply $type $target "\002error:\002 update check failed ($error)"
        return;
    } else {
        # -- version data
        set output [join $output]
        set version [dict get $ghdata version]
        set revision [dict get $ghdata revision]
        set gversion [dict get $ghdata gversion]
        set grevision [dict get $ghdata grevision]
        set update [dict get $ghdata update]
        set newversion [dict get $ghdata newversion]
        set newrevision [dict get $ghdata newrevision]
        set branch [dict get $ghdata branch]
        set filecount [dict get $ghdata filecount]
    }

    # -- check for available update
    if {$action eq "check" || $action eq "c"} {
        reply $type $target $output; # -- send the output to the user
    } elseif {$action eq "install" || $action eq "i"} {
        # -- install script update
        if {$update eq 0 && [lsearch $arg "-force"] eq "-1" && [lsearch $arg "-f"] eq "-1"} {
            reply $type $target "no update available. currently running \002version:\002 $version (\002revision:\002 $revision -- \002branch:\002 $branch)"
            return;
        }
        
        # -- ensure script is not already downloading
        if {[file isfile ./armour/backup/.lock]} {
            reply $type $target "\002error:\002 script download is already in progress, please try again later."
            return;
        }

        # -- start the install... download first
        debug 0 "\002cmd:update:\002 starting script upgrade to \002version:\002 $gversion (\002revision:\002 $grevision -- \002branch:\002 $branch)"
        reply $type $target "starting script upgrade to \002version:\002 $gversion (\002revision:\002 $grevision -- \002branch:\002 $branch)"
        dict set ghdata response [list $type $target]
        update:download $ghdata

    } elseif {$action eq "restore" || $action eq "r"} {
        # -- restore script backup

        # -- ensure script is not already downloading
        if {[file isfile ./armour/backup/.lock]} {
            reply $type $target "\002error:\002 script download is in progress, please try again later."
            return;
        } else { exec touch ./armour/backup/.lock }

        set start [unixtime]

        # -- find backup
        set backup [lindex $arg 1]
        set backups [lsort -decreasing [exec find ./armour -name backup-*]]
        set avail [list]
        foreach bak $backups {
            regsub -all {^./armour/backup/backup-} $bak "" bakstrip
            lappend avail $bakstrip
        }
        if {$backup eq ""} {
            # -- no backup given, find last backup
            set lastbackup [lindex $backups 0]
            if {$lastbackup eq ""} {
                reply $type $target "\002error:\002 script backup not found."
                return;
            }
        } else {
            if {![regexp {^(\d+)$} $backup -> backupts] && ![regexp {^backup-(\d+)$} $backup -> backupts]} {
                reply $type $target "\002error:\002 invalid backup timestamp."
                return;
            }
            if {![file isdirectory ./armour/backup/backup-$backupts]} {
                # -- backup not found, show available backups
                if {$backups ne "" && $avail ne ""} {
                    reply $type $target "\002error:\002 backup not found. available backups: \002[join $avail ,]\002"
                    return;
                } else {
                    reply $type $target "\002error:\002 backup not found."
                    return;
                }
            }
        }

        # -- restore backup
        debug 0 "\002cmd:update:\002 restoring backup: $backupts"
        update:copy ./armour/backup/backup-$backupts ./armour $debug

        set runtime [expr [unixtime] - $start]
        # -- TODO: fix versions and revisions
        debug 0 "\002cmd:update:\002 script \restore complete\002 (\002runtime:\002 $runtime secs\002)"
        if {$debug} { set mode "tested" } else { set mode "complete" }
        update:note "\002Armour\002 script \002v$ver\002 (\002revision:\002 $rev) restore $mode (\002runtime:\002 $runtime)" $ghdata

        reply $type $target "script \002[cfg:get version]\002 (\002revision:\002 [cfg:get revision])\
            installation $mode (\002runtime:\002 $runtime secs -- \002new config settings:\002 $new)"

        # -- remove the lock file
        debug 0 "\002cmd:update:\002 removing lock file"
        catch { exec rm ./armour/backup/.lock }

        if {!$debug} {
            # -- TODO: fix version & revision
            putnow "QUIT :Loading Armour \002[cfg:get version] (revision: \002[cfg:get revision]\002)"
            restart; # -- restart eggdrop to ensure full script load
        } else {
            reply $type $target "\002info:\002 debug mode enabled, restore not actually applied."
        }

    } elseif {$action eq "branches" || $action eq "b"} {
        # -- list available branches
        lassign [update:github "https://api.github.com/repos/empus/armour/branches" "get branches" $type $target] success extra json
        if {!$success} { return; }; # -- error
        set count 0
        foreach branch $json {
            incr count
            set bname [dict get $branch name]
            set commit [dict get $branch commit]
            set url [dict get $commit url]
            # -- get the commit details to show last commit timestamp
            lassign [update:github $url "get commit data" $type $target] success extra json
            set scommit [dict get $json commit]
            set author [dict get $scommit author]
            #set aname [dict get $author name]
            set commitdate [dict get $author date]
            reply $type $target "\002branch:\002 $bname -- \002url:\002 https://github.com/empus/armour/tree/$bname --\
                \002commit:\002 [userdb:timeago [clock scan $commitdate]] ago"
        }
        if {$count > 1} {
            reply $type $target "found \002$count\002 branches."
        } 
    } 

    # -- create log entry for command use
    log:cmdlog BOT * 1 $user $uid [string toupper $cmd] $arg $source "" "" ""
}

# -- abstraction for github API queries
proc update:github {url desc type target} {
    http::register https 443 [list ::tls::socket -tls1.2 true]
    http::config -useragent "mozilla" 
    variable github
    set headers [list Accept application/json Authorization [list Bearer $github(token)]]
    debug 0 "\002update:github:\002 headers: $headers"
    set errcode [catch {set tok [::http::geturl $url -headers $headers -timeout 10000]} error]
    debug 0 "\002update:github:\002 errcode: $errcode -- error: $error"
    set success 1;
    # -- check for errors
    if {$errcode} { set success 0; set errout "error: $error" }
    set status [::http::status $tok]
    if {$status ne "ok"} { set success 0; set errout "status: $status" }
    set data [::http::data $tok]
    ::http::cleanup $tok
    set httpcode [lindex [split $data :] 0]
    if {[regexp -- {^[0-9]+$} $httpcode]} { set success 0; set errout "http code: $httpcode" }
    if {!$success} {
        debug 0 "\002update:check:\002 failed to $desc from github ($extra)"
        reply $type $target "failed to $desc from github (extra)"
    }
    # -- return the response
    set json [json::json2dict $data]
    return [list $success $errcode $json]
}

# -- github API requests get rate limited more strictly without authentication
# -- https://developer.github.com/v3/#rate-limiting
# -- storing tokens in plaintext within github repositories result in automatic expiry of the access token

# -- check for update
proc update:check {branch {debug 0}} {
    variable github
    set url "https://raw.githubusercontent.com/empus/armour/${branch}/.version"
    http::register https 443 [list ::tls::socket -tls1.2 true]
    http::config -useragent "mozilla" 
    set errcode [catch {set tok [::http::geturl $url -timeout 10000]} error]
    debug 0 "\002update:check:\002 errcode: $errcode -- error: $error"
    # -- check for errors
    if {$errcode} {
        debug 0 "\002update:check:\002 failed to get version info from github (error: $error)"
        return "0 $error";    
    }
    set status [::http::status $tok]
    if {$status ne "ok"} {
        ::http::cleanup $to
        debug 0 "\002update:check:\002 failed to get version info from github (status: $status)"
        return "0 $status";
    }
    set data [::http::data $tok]
    ::http::cleanup $tok
    set httpcode [lindex [split $data :] 0]
    if {[regexp -- {^[0-9]+$} $httpcode]} {
        # -- http error code
        debug 0 "\002update:check:\002 failed to get version info from github (http code: $httpcode)"
        return "0 $httpcode";
    }

    # -- version data
    set lines [split $data \n]
    foreach line $lines {
        set tag [lindex $line 0]
        set value [lrange $line 1 end]
        if {$tag eq "version"} {
            set gversion $value
        } elseif {$tag eq "revision"} {
            set grevision $value
        } elseif {$tag eq "filecount"} {
            set filecount $value
        } elseif {$tag eq "token"} {
            set github(token) [string reverse "${value}_tap_buhtig"]
        }
    }

    debug 4 "\002update:check:\002 retrieved version info from github (version: $gversion -- revision: $grevision)"
    set version [cfg:get version]
    set revision [cfg:get revision]
    regsub -all {v} $version "" version
    set ordered [lsort -decreasing "$version $gversion"]
    dict set ghdata version $version
    dict set ghdata revision $revision
    dict set ghdata gversion $gversion
    dict set ghdata grevision $grevision
    dict set ghdata update 0
    dict set ghdata status current
    dict set ghdata newversion 0
    dict set ghdata newrevision 0
    dict set ghdata branch $branch
    dict set ghdata filecount $filecount
    dict set ghdata debug $debug
    set output ""; set sendnote 0
    debug 0 "\002update:check:\002 version: $version -- revision: $revision -- gversion: $gversion -- grevision: $grevision"
    if {$version eq $gversion} {
        # -- same version
        if {$revision < $grevision} {
            # -- github has a newer revision of same version
            dict set ghdata update 1
            dict set ghdata status "outdated"
            dict set ghdata newrevision 1
            set sendnote 1
            set output "revision update (\002$grevision\002) of version \002v$version\002 available! \002current revision:\002 $revision"
        } else {
            # -- local version is up to date
            dict set ghdata status "current"
            set output "currently running the \002latest\002 available version (\002v$version\002 -- \002revision:\002 $revision)"
        }
    } elseif {[lindex $ordered 0] eq $version} {
        # -- local version is newer
        dict set ghdata status "newer"
        set output "currently running a \002newer\002 version (\002v$version\002 -- \002revision:\002 $revision) than is available on \
            github (\002version:\002 v$gversion -- \002revison:\002 $grevision -- \002branch:\002 $branch)"
    } else {
        # -- github has an newer version
        dict set ghdata status "outdated"
        dict set ghdata update 1
        dict set ghdata newversion 1
        set sendnote 1
        set output "version update (\002v$gversion\002) available! \002current version:\002 v$version"
    }

    if {$output ne ""} {
        debug 0 "\002update:check:\002 $output"
        if {$sendnote} { update:note "\002Armour\002 script $output" $ghdata }; # -- send note to all global >=500 users, if enabled in config
    }
    return "1 [list $ghdata] [list $output]"
}

proc update:note {note ghdata} {
    if {[cfg:get update:notes] eq 0} {
        # -- notes disabled
        debug 5 "\002update:note:\002 automatic notes disabled"
        return;
    }

    # -- check for automatic upgrades
    if {[cfg:get update:auto] eq 1} {
        # -- automatic upgrades enabled
        append note " -- commencing automatic upgrade."
        update:install
    } else {
        append note " -- to install, use: \002update install\002"
    }

    db:connect
    set uids [db:query "SELECT uid FROM levels WHERE level >= 500 AND cid=1"]
    db:close
    foreach tuid $uids {
        # -- notify the recipient if online
        set read "N"
        lassign [db:get user,curnick users id $tuid] to_user to_nick
        set online 0;
        if {$to_nick ne ""} {
            # -- recipient is online
            # -- insert note as read if they're already online and get the /notice
            set read "Y"; set online 1;
        }
        db:connect
        set db_note [db:escape $note]; 
        
        # -- avoid sending the same note twice
        if {$ghdata ne ""} {
            set ver [dict get $ghdata gversion]
            set rev [dict get $ghdata grevision]
            set imatch "script \002v$ver\002 (\002revision:\002 $rev)"
            set dmatch "script \002v$ver\002 update downloaded"
            set exist [db:query "SELECT id FROM notes WHERE from_u='Armour' AND to_u='$to_user' \
                AND note LIKE '%$imatch%' OR note LIKE '%$dmatch%'"]
            if {$exist ne ""} {
                # -- note already exists, don't send it twice
                debug 0 "\002update:note:\002 note already exists for $to_user ($to_nick![getchanhost $to_nick])"
                db:close
                continue;
            }
        } 
        db:query "INSERT INTO notes (timestamp, from_u, from_id, to_u, to_id, read, note) \
                VALUES ('[clock seconds]', 'Armour', '0', '$to_user', '$tuid', '$read', '$db_note')"
        set rowid [db:last:rowid]
        if {$online} {
            reply notc $to_nick "(\002note\002 from Armour -- \002id:\002 $rowid): $note"
            debug 0 "update:note: notified $to_user ($to_nick![getchanhost $to_nick]) about new script update available."
        }
        db:close
    }
}

# -- download the updated script from github
proc update:download {ghdata} {
    variable github
    set branch [dict get $ghdata branch]
    set filecount [dict get $ghdata filecount]
    set gversion [dict get $ghdata gversion]
    set grevision [dict get $ghdata grevision]
    lassign [dict get $ghdata response] type target

    # -- begin automatic script install
    debug 0 "\002update:install:\002 starting automatic script install (branch: $branch)"

    # -- create lock file to prevent concurrent downloads (incl. from multiple bots from same eggdrop directory)
    set start [unixtime]
    exec touch ./armour/backup/.lock
    exec echo $start > ./armour/backup/.lock

    # -- download the script from github
    ::github::github update empus armour ./armour/backup/armour-$start $arm::github(token) $branch

    # -- wait for the download to complete
    # TODO: consider doing this with total bytes instead of number of files (see: update:dirsize proc)
    global armupdate
    dict set armupdate start $start
    dict set armupdate filecount 80; # TODO: remove hard-coded value
    dict set armupdate ghdata $ghdata
    dict set armupdate response [list $type $target]
    update:every 500 {
        global armupdate
        set start [dict get $armupdate start]
        set filecount [dict get $armupdate filecount]
        if {[file isdirectory ./armour/backup/armour-$start]} {
            set dirfiles [string trimleft [exec find ./armour/backup/armour-$start | wc -l]]
            dict set armupdate dirfiles $dirfiles
            set pc [expr int([expr ${dirfiles}.0/${filecount}.0*100])]
            arm::debug 0 "\002update:install:\002 downloaded $dirfiles of $filecount files ($pc%)"
            if {$dirfiles >= $filecount} {
                arm::update:install $armupdate
                unset armupdate
                break
           }
        }
    }
}

# -- install the downloaded script
proc update:install {update} {
    variable scan:rbls;  # -- configured RBLs to scan
    variable scan:ports; # -- configured ports to scan

    if {![file isfile ./armour/backup/.lock]} {
        # -- prevent loops
        debug 4 "\002update:install:\002 lock file \002doesn't exist\002, so we can't continue"
        return
    }

    if {![file isfile ./armour/backup/.install]} {
        exec touch ./armour/backup/.install
    } else {
        debug 0 "\002update:install:\002 \002install already in progress, exiting to avoid loop\002"
        return;
    }

    # -- create a true directory backup, as a one time safety net
    if {![file isfile ./armour/backup/armour.tbz2]} {
        debug 0 "\002update:install:\002 \002armour.tbz2\002 doesn't exist... creating \002one time backup\002 of entire directory."
        catch { exec tar -cjpf armour.tbz2 armour }
        catch { exec mv armour.tbz2 ./armour/backup }
    }

    variable userdb
    set start [dict get $update start]; set end [unixtime]
    set ghdata [dict get $update ghdata]
    set gversion [dict get $ghdata gversion]
    set grevision [dict get $ghdata grevision]
    set debug [dict get $ghdata debug]
    set dirfiles [dict get $update dirfiles]
    arm::debug 0 "\002update:install:\002 script \002v$gversion\002 update downloaded (\002$dirfiles\002 files downloaded in \002[expr {$end - $start}] secs\002)"
    arm::update:note "\002Armour\002 script \002v$gversion\002 update downloaded (\002$dirfiles\002 files downloaded in \002[expr {$end - $start}] secs\002)" $ghdata
    debug 0 "\002update:install:\002 begin script installation"
    set response [dict get $update response]

    # -- grab names set in arm-01_depends.tcl
    set dbname $::arm::dbname;
    set confname $::arm::confname;

    # -- TODO: remove after dev testing
    if {[file isfile ./armour/armour.conf.sample.TEMP]} { 
        exec cp ./armour/armour.conf.sample.TEMP ./armour/backup/armour-$start/armour.conf.sample
    }

    # -- backup current db
    set dbfile "./armour/db/${dbname}.db"
    debug 0 "\002update:install:\002 backing up sqlite db: $dbfile -> ${dbfile}.bak.$start"
    if {!$debug} { exec cp $dbfile ${dbfile}.bak.$start }

    # -- backup current config file
    set conffile "./armour/${confname}.conf"
    debug 0 "\002update:install:\002 backing up config file: $conffile -> ${conffile}.bak.$start"
    if {!$debug} { exec cp $conffile ${conffile}.bak.$start }

    # -- read new sample config
    set sampleconf "./armour/backup/armour-$start/armour.conf.sample"
    debug 0 "\002update:install:\002 processing config file: $sampleconf"
    set fd [open $sampleconf r]
    set confdata [read $fd]
    set lines [split $confdata \n]
    close $fd
    # -- new conf file
    set newconf "./armour/backup/armour-$start/${confname}.conf"
    set fd [open $newconf w]

    set linecount 0; set unchanged 0; set changed 0; set new 0; set newsettings [list]; set startports 1; set startrbls 1; set startfiles 1;
    # -- print the header with version
    debug 4 "\002update:install:\002 prefixing new config file with version info"
    set ver [dict get $ghdata gversion]
    set rev [dict get $ghdata grevision]
    regsub -all {^(\d{4})(\d{2})(\d{2})(\d{2})} $rev {\1-\2-\3} nicerev; # -- convert to YYYY-MM-DD
    puts $fd "# ------------------------------------------------------------------------------------------------"
    puts $fd "# armour.conf v$ver - $nicerev"

    # -- loop over the lines in the sample config file
    foreach line $lines {
        incr linecount

        # -- escape brackets in set commands
        if {[regexp {^set} $line]} {
            regsub -all {\[} $line {\\[} line
            regsub -all {\]} $line {\\]} line
        }

        if {[regexp {^#} $line] || $line eq "" || $line eq "\r" || [regexp {^\}} $line] || [regexp {^source} $line] \
            || [regexp {^\s*$} $line] || [regexp {^if} $line] || [regexp {^set realname} $line] || [regexp {^namespace eval arm} $line]} {
            # -- output comments, blank lines, if statements, script loads, and closing braces
            puts $fd $line
            continue
        }
        if {[regexp {^set cfg\(([^\)]+)\)\s+"?([^\"]*)"?.*$} $line -> var val]} {
            # -- set new config value
            set curval [cfg:get $var]
            variable cfg
            if {![info exists cfg($var)]} { incr new; lappend newsettings $var; }; # -- new config setting
            if {$curval eq $val} {
                # -- value is unchanged
                incr unchanged
                debug 5 "\002update:install:\002 unchanged config value: $var = $val"
                puts $fd $line
            } else {
                incr changed
                debug 1 "\002update:install:\002 using existing config value: $var = $curval"
                regsub -all {\[} $curval {\\[} curval
                regsub -all {\]} $curval {\\]} curval
                puts $fd "set cfg($var) \"$curval\""
            }
            continue
        } elseif {[regexp {^set addcmd\(([^\)]+)\)\s+(.+)$} $line -> cmd config]} {
            # -- command configuration
            if {[regexp {\{\s*([^\s]+)\s+(\d+)\s+([^\}]+)\s*\}(.*)$} $config -> plugin lvl binds rest]} {
                foreach bind $binds {
                    set usenew 0; set bindlist [list]
                    # -- msg, pub, dcc
                    if {![info exists userdb(cmd,$cmd,$bind)]} { 
                        # -- new command
                        set usenew 1
                    } else { 
                        # -- existing command
                        set req $userdb(cmd,$cmd,$bind)
                        if {$req eq $lvl} {
                            # -- level is unchanged, use new config; whitespace or comments may be new
                            set usenew 1
                        } else {
                            # -- level is different, use existing config
                        }
                    }
                }
                if {!$usenew} {
                    # -- use existing config
                    set bindlist [join $bindlist " "]
                    debug 1 "\002update:install:\002 existing command config: $cmd (types: $bindlist -- level: $req)"
                    puts $fd "set addcmd($cmd)		\{	$plugin		$req		$bindlist \}$rest"
                } else {
                    # -- use new config
                    debug 1 "\002update:install:\002 new command config: $cmd (type: $bind -- level: $lvl)"
                    puts $fd $line
                }
            } else {
                debug 0 "\002update:install:\002 \002WARNING:\002 adding unknown command config: $line"
                puts $fd $line
            }

            # -- handle migrating old config mechanism for:
            #      - scan:ports
            #      - scan:rbls
            #      - plugins

        } elseif {[regexp -- {^set addport\(([^\)]+)\)\s+"?([^\"]*)"?.*$} $line -> sport sdesc]} {
            # -- check for existing config for this port
            if {$startports} {
                # -- first port entry
                if {[array names scan:ports] ne ""} {
                    # -- existing scan:port config; add all ports but only do this on the first loop
                    foreach port [array names scan:ports] {
                        lassign [array get scan:ports $port] port desc
                        debug 1 "\002update:install:\002 using \002existing\002 portscan config (port: $port -- desc: $desc)"
                        puts $fd "set addport($port) \"$desc\""
                        array set scan:ports [list $port $desc]
                    }
                } else {
                    # -- no existing scan:ports config
                    debug 1 "\002update:install:\002 using \002sample config\002 for port scanner (port: $sport -- desc: $sdesc)"
                    array set scan:ports [list $sport $sdesc]
                    puts $fd $line
                }
                set startports 0
            } 
        } elseif {[regexp -- {^set addrbl\(([^\)]+)\)\s+"?([^\"]*)"?.*$} $line -> srbl svalue]} {
            # -- check for existing config for this DNSBL
            if {$startrbls} {
                # -- first port entry
                if {[array names scan:rbls] ne ""} {
                    # -- existing scan:ports config; add all RBLs but only do this on the first loop
                    foreach rbl [array names scan:rbls] {
                        lassign [array get scan:rbls $rbl] rbl value
                        lassign $value desc score auto;
                        debug 1 "\002update:install:\002 using \002existing\002 DNSBL config (port: $rbl -- desc: $desc)"
                        puts $fd "set addrbl($srbl) \"[list $desc] $score $auto\""
                        array set scan:rbls [list $rbl [list $desc] $score $auto]
                    }
                } else {
                    # -- no existing scan:rbls config
                    lassign $svalue desc score auto;
                    debug 1 "\002update:install:\002 using \002sample config\002 for DNSBL scanner (port: $srbl -- desc: $sdesc)"
                    array set scan:rbls [list $srbl [list $sdesc] $score $auto]
                    puts $fd $line
                }
                set startrbls 0
            } 
        } elseif {[regexp -- {^set addplugin\(([^\)]+)\)\s+"?([^\"]*)"?.*$} $line -> plugin file]} {
            # -- handle plugins
            if {$startplugins} {
                # -- first plugin entry
                if {[info exists files] && $files ne ""} {
                    # -- existing plugins config; add all plugins but only do this on the first loop
                    foreach plugin [array names plugins] {
                        lassign [array get plugins $plugin] plugin file
                        debug 1 "\002update:install:\002 using \002existing\002 plugin config (plugin: $plugin -- file: $file)"
                        puts $fd "set addplugin($plugin) \"$file\""
                        array set plugins [list $plugin $file]
                    }
                } else {
                    # -- no existing plugins config
                    debug 1 "\002update:install:\002 using \002sample config\002 for plugins (plugin: $plugin -- file: $file)"
                    array set plugins [list $plugin $file]
                    puts $fd $line
                }
                set startplugins 0
            }

        } else {
            puts $fd $line
            debug 4 "\002update:install:\002 \002WARNING:\002 adding unknown line from sample config: $line -- not comment or blank line"
        }
    }; # -- end of foreach line

    close $fd
    debug 0 "\002update:install:\002 config file updated with $linecount lines (\002$new\002 \002new\002 config settings, \
        \002$changed\002 values retained, \002$unchanged\002 unchanged)"
    if {$new eq 1} { set settext "setting" } else { set settext "settings" }
    if {$new ne 0} { debug 0 "\002update:install:\002 \002$new\002 new config $settext: [join $newsettings]\002" }

    # -- create backups
    debug 0 "\002update:install:\002 creating backup of previous script files and db"
    set backupts [unixtime]
    debug 0 "\002update:install:\002 creating backup directory: ./armour/backup/backup-$backupts"
    exec mkdir ./armour/backup/backup-$backupts

    # -- do the backup file copies
    update:copy ./armour ./armour/backup/backup-$backupts $debug

    # -- rename most recent version specific script file, or use armour.tcl
    set file [lindex [lsort -decreasing [exec find ./armour/backup/armour-$start -maxdepth 1 -name armour-*.tcl]] 0]
    if {$file ne ""} {
        debug 0 "\002update:install:\002 renaming version specific script file: $file -> ./armour/backup/armour-$start/armour.tcl"
        exec mv $file ./armour/backup/armour-$start/armour.tcl
    }
 
    # -- copy new files into place
    # note that removed or renamed files should be handled during migrations (db:upgrade proc)
    update:copy ./armour/backup/armour-$start ./armour $debug

    set runtime [expr [unixtime] - $start]
    debug 0 "\002update:install:\002 script \002installation complete\002 (\002runtime:\002 $runtime secs\002)"
    if {$debug} { set mode "tested" } else { set mode "complete" }

    # -- form the note
    set out "\002Armour\002 script \002v$ver\002 (\002revision:\002 $rev) installation $mode (\002runtime:\002 $runtime secs"
    set note $out
    if {$new ne 0} { append note " -- \002$new new config $settext:\002 [join $newsettings]\)" } else { append note "\)" }

    # -- send note to all global 500 users
    update:note $out $ghdata

    # -- send response back to client, if called from 'update install' command
    lassign $response type target
    if {$target ne ""} {
        reply $type $target "$out\)"
        if {$new ne 0} { reply $type $target "\002info:\002 check \002$new\002 new config $settext: \002[join $newsettings ", "]\002" }
    }

    # -- remove the lock file
    debug 0 "\002update:install:\002 removing lock file"
    catch { exec rm ./armour/backup/.lock }
    catch { exec rm ./armour/backup/.install }

    if {!$debug} {
        #reply $type $target "restarting..."
        putnow "QUIT :Loading Armour \002[cfg:get version] (revision: \002[cfg:get revision]\002)"
        restart; # -- restart eggdrop to ensure full script load
    } else {
        reply $type $target "\002info:\002 debug mode enabled, update not actually applied."
    }
}

# -- copy files from one directory to another
# backup: copying from working directory to backup directory
# restore: copy from backup to working directory
proc update:copy {from to {debug 0}} {
    debug 0 "\002update:copy:\002 copying files from $from to $to"
    if {[string match *backup* $to]} { set isbackup 1 } else { set isbackup 0 }
    if {[string match *backup* $from]} { set isrestore 1 } else { set isrestore 0 }
    if {!$debug || $isbackup} {
        foreach file [exec find $from -maxdepth 1 -name *.tcl] { exec cp $file $to }
        foreach file [exec find $from -maxdepth 1 -name *.sh] { exec cp $file $to }
        foreach file [exec find $from -maxdepth 1 -name *.conf] { exec cp $file $to }
        foreach file [exec find $from -maxdepth 1 -name *.md] { exec cp $file $to }
        foreach file [exec find $from -maxdepth 1 -name *.sample] { exec cp $file $to }
    }
    debug 0 "\002update:copy:\002 copying directories from $from to $to"
    if {!$debug || $isbackup} {
        catch { exec cp -R $from/help $to }
        catch { exec cp -R $from/plugins $to }
        catch { exec cp -R $from/packages $to }
    }
    debug 0 "\002update:copy:\002 copying optional directories from $from to $to"
    if {!$debug || $isbackup} {
        if {[file isdirectory $from/emails]} { catch { exec cp -R $from/emails $to } }
        if {[file isdirectory $from/db]} { catch { exec cp -R $from/db $to } }
    }
}

# -- periodically invoke a script or command
# https://wiki.tcl-lang.org/page/every
proc update:every {interval script} {
    global everyIds
    if {$interval eq {cancel}} {
        after cancel $everyIds($script)
        return
    }
    set everyIds($script) [after $interval [namespace code [info level 0]]]
    set rc [catch {uplevel #0 $script} result]
    if {$rc eq [catch break]} {
        after cancel $everyIds($script)
        set rc 0
    } elseif {$rc eq [catch continue]} {
        # Ignore - just consume the return code
        set rc 0
    }
    # TODO: Need better handling of errorInfo etc...
    return -code $rc $result
}

# -- create backup directory if it doesn't exist
if {![file isdirectory ./armour/backup]} {
    debug 0 "\002update:install:\002 creating backup directory"
    catch { exec mkdir ./armour/backup }
}


debug 0 "\[@\] Armour: loaded script updater." 

# ------------------------------------------------------------------------------------------------
}; # end of namespace
# ------------------------------------------------------------------------------------------------# ------------------------------------------------------------------------------------------------
# Armour: merged from arm-23_init.tcl
#
# script initialisation (array clean & timer inits)
#
# ------------------------------------------------------------------------------------------------
# secure eggdrop by unbinding unwanted commands
# ------------------------------------------------------------------------------------------------

unbind msg - hello *msg:hello
unbind msg - ident *msg:ident

# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- rebind for generic userdb proc
proc init:autologin {} { userdb:init:autologin }

# -- bot response proc
# -- send text responses back to irc client
proc reply {type target text} {
    switch -- $type {
        notc { set med "NOTICE"  }
        pub  { set med "PRIVMSG" }
        msg  { set med "PRIVMSG" }
        dcc  {
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

# -- create service host regex (for umode +x)
set cfg(xregex) "(\[^.\]+).[cfg:get xhost:ext *]"
regsub -all {\.} [cfg:get xregex *] {\\.} cfg(xregex)


# -- load scan ports
if {[info exists addport]} {
    foreach entry [array names addport] {
        lassign [array get addport $entry] port desc
        array set scan:ports [list $port $desc]
        debug 3 "\[@\] Armour: loaded port scan: port: $port -- desc: $desc"
    }
}

# -- load scan ports
if {[info exists addrbl]} {
    foreach entry [array names addrbl] {
        lassign [array get addrbl $entry] rbl value
        lassign $value desc score auto
        array set scan:rbls [list $rbl$ [list $desc] $auto]
        debug 3 "\[@\] Armour: loaded DNSBL scan: RBL: $rbl -- desc: $desc -- score: $score -- auto: $auto"
    }
}


# -- load lists into memory
debug 0 "\[@\] Armour: loading lists into memory..."
db:load

# -- load channels into memory
debug 0 "\[@\] Armour: loading channels into memory..."
db:load:chan

# ---- unset all vars on a rehash, to start fresh

# -- avoid doubling up when the bot rehashes more than once
if {[info exists vars]} { unset vars }

# -- unset existing exempt array
lappend vars nick:exempt

# -- unset existing adaptive regex tracking arrays
lappend vars adapt
lappend vars adaptn
lappend vars adaptni
lappend vars adaptnir
lappend vars adaptnr
lappend vars adapti
lappend vars adaptir
lappend vars adaptr
# -- unset floodnet tracking counters
lappend vars flud:count
lappend vars flud:nickcount
lappend vars floodnet

# -- unset text type blacklist counters
lappend vars flood:text

# -- unset line flood counters
lappend vars flood:line

# -- unset nicks on host tracking array
lappend vars data:hostnicks

# -- unset nicks on ip tracking array
lappend vars data:ipnicks

# -- unset host on nick tracking array
lappend vars nickhost

# -- unset ip on nick tracking array
lappend vars data:nickip

# -- unset scanlist for /endofwho
lappend vars scan:list

# -- unset pranoid coroutine array for arm:scan:continue
lappend vars paranoid

# -- unset channel lock array (recently set chanmode +r)
lappend vars chanlock

# -- unset realname tracker
lappend vars fullname

# -- unset kick reason array (tracks cumulative floodnet blacklist reason)
lappend vars kreason

# -- unset existing setx array (newly umode +x clients)
lappend vars nick:setx

# -- unset tracking for jointime based on chan,nick
lappend vars nick:jointime

# -- unset exnisting newjoin array (temp array to identify newcomers in channel)
lappend vars nick:newjoin

# -- unset tracking holding the nick based on chan,jointime
lappend vars jointime:nick

# -- unset wholist (tracks users between /WHO's)
lappend vars wholist

# -- unset temporary exemption overrides (from 'exempt' command)
lappend vars nick:override

# -- unset netsplit memory (track's users lost in netsplits)
lappend vars data:netsplit

# -- unset list of masks to ban for a channel (by chan)
lappend vars data:bans

# -- unset list of nicknames to kick for a channel (by chan)
lappend vars data:kicks

# -- tracks the most recently banned ban for a given entry ID
lappend vars data:idban

# --- unset global banlist array
#lappend vars gblist

# -- unset trackers from 'black' command
lappend vars data:black

# -- now do the safe unsets
foreach var $vars {
    if {[info exists $var]} { 
        debug 4 "\[@\] Armour: unsetting variable: $var"
        unset $var
    }
}
unset vars

# -- create empty to stop complaining untli a user is seen
if {![info exists nickdata]} { set nickdata "" };

# -- kill existing eggdrop timers (utimers and timers)
kill:timers

# -- kill any tcl timers ('after' cmd)
foreach id [after info] { after cancel $id }

# -- start /names -d (if secure mode)
mode:secure

# -- start voice stack timer
utimer [expr [cfg:get queue:secure *] / 2] arm::voice:stack; # -- offset the voice timer from the /who (in mode:secure); 
                                                     
# -- start floodnet mode queue timer (attempts to stack bans during floodnet)
flud:queue; 

# -- load dronebl package if required
if {[cfg:get dronebl] eq 1} { 
    namespace eval dronebl {
        set rpckey $arm::cfg(dronebl:key)
    }
    source ./armour/packages/libdronebl.tcl 
}

# -- start autologin
init:autologin


# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------


# ------------------------------------------------------------------------------------------------
# plugin loader
# ------------------------------------------------------------------------------------------------
foreach plugin [array names addplugin] {
    lassign $plugin name file
    arm::debug 0 "Armour: loading plugin $name ... (file: $file)"
    catch {source $file} error
    if {$error ne ""} {
        arm::debug 0 "\002(plugin load error)\002:$name\: $::errorInfo"
    }
}
# ------------------------------------------------------------------------------------------------
arm::loadcmds; # -- load all commands (incl. plugins)
# ------------------------------------------------------------------------------------------------

arm::debug 0 "\[@\] Armour: loaded [arm::cfg:get version *] (empus@undernet.org)"

