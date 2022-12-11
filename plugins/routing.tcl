# ------------------------------------------------------------------------------------------------
# Undernet Routing Committee Utility Bot
# ------------------------------------------------------------------------------------------------
#
# Alerts:
#   - alert when new (unknown) servers are detected, and auto-add
#   - alert significant increase or decrease of per-server client counters (based on >=% or >=N change)
#   - alert when servers split and merge
#   - alert when opers attempt manual /connect of servers
#   - alert when servers have connect blocks for removed servers (once per N cache time)
#   - alert when server connect blocks are added or removed
#   - alert when o:lines are added or removed
#   - alert when servers do not respond, likely indicating imminent netsplit
#   - also send alerts via email
#   - log all interesting events to DB (with filtered log search)
#
# Commands:
#   - add & modify & view server information (admins, contacts, preferred uplinks, link uptime)
#
#       serv add [server]
#       serv del [server]
#       serv mod [server] [hubs|type|admin|note] <value>
#       serv view [server]
#       serv log [view|search|last] <server|mask|N>
#
# ------------------------------------------------------------------------------------------------
# TODO:
# ------------------------------------------------------------------------------------------------
#
# Deal with netsplits during /stats.  If the last server in the queue splits it will not respond 
# to /stats, and therefore the script cycle will halt.  Solution TBD
#
# Alert climbing sendq between servers (except for immediately following a merge)
#
# When detecting imminent netsplits, handle detections from multiple servers-- it could be my server
# about to split!
#
# TODO Priorities:
#  - alert when inter-server sendq has increased since last scan (a potential approaching split)
#  - halt scans and alerts when network is >=N % fractured? TBD (maybe check /lusers after splits?)
#  - alert if client servers are not connected to appropriate hubs (US vs EU; or non-preferred)
#  - alert if servers utilise non-permitted F:lines
#  - alert if servers are running out-of-date ircu or iauthd-c
#  - alert if servers are not running appropriate iauthd-c config
#  - alert when non-rfc1918 oper masks use wide subnets
#  - alert when servers have been split for >N time
#  - introduce e-mail alerts to routing-staff@
#  - allow per-server alerts to be sent to respective server admins
#  - maniuplate DNS entries for round robins via commands (Cloudflare API)
#  - manipulate DNS entries for round robins automatically (i.e. after split for >N time) - TBD
#
# - commands:
#       - identify missing servers and absence time
#       - find servers not connected to appropriate hubs
#       - recall log activity (by all, server, type, user, nick)
#       - view '/STATS l' connection statistics for server<->server links (from a given server)
#
#   serv top
#   serv stats
#   serv dns [add|del|view] [entry] <value>
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


# ------------------------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------------------------

# -- alert channel
set cfg(routing:chan) "#routing-dev"

# -- username and password for /oper
set cfg(routing:oper:user) "routingbot"
set cfg(routing:oper:pass) "HXzxp1YykBC6DQ66Os9q"

# -- interval between individual /stats commands (miliseconds) - 250
set cfg(routing:int) 250

# -- enable channel alerts for client count fluctations? (0|1) - 1
set cfg(routing:alert) 1

# -- interval between /map check and usercount alerts? (secs) - 300
# -- minimum of 300
set cfg(routing:alert:int) 300

# -- enable alerts for removed servers? (0|1) - 1
set cfg(routing:alert:remserver) 1

# -- enable alerts for added & removed opers? (0|1) - 1
set cfg(routing:alert:opers) 1

# -- required % change in per-server client count for channel alerts
set cfg(routing:alert:perc) "15"

# -- required usercount change in per-server client count for channel alerts
set cfg(routing:alert:count) "50"

# -- do not send the same alert to channel more than once every N hours - 72
# -- this is per server per specific alert
set cfg(routing:alert:cache) "72"

# -- email from address
set cfg(routing:mail:from) "no-reply@empus.net"

# -- email to address
set cfg(routing:mail:to) "mail@empus.net"

# -- email subject for notifications
set cfg(routing:mail:subject) "Nerthus Notification"

# -- services (without .undernet.org) to avoid '/stats' scans
set cfg(routing:services) "channels chanfix dronescan uworld uworld.eu"


# -----------------------------------------------------------------------------
# command bindings        plugin        level req.    binds
# -----------------------------------------------------------------------------
set addcmd(serv)    {    arm            100            pub msg dcc    }



# ------------------------------------------------------------------------------------------------
# END CONFIG
# ------------------------------------------------------------------------------------------------

bind evnt - init-server { arm::coroexec arm::routing:raw:initserver }
bind raw - 381 { arm::coroexec arm::routing:raw:opered }
bind raw - 015 { arm::coroexec arm::routing:raw:map }
bind raw - 017 { arm::coroexec arm::routing:raw:endofmap }
bind raw - 364 { arm::coroexec arm::routing:raw:links }
bind raw - 365 { arm::coroexec arm::routing:raw:endoflinks }
bind raw - 211 { arm::coroexec arm::routing:raw:statsl }
bind raw - 213 { arm::coroexec arm::routing:raw:statsc }
bind raw - 243 { arm::coroexec arm::routing:raw:statso }
bind raw - 219 { arm::coroexec arm::routing:raw:endofstats }
bind raw - "NOTICE" { arm::coroexec arm::routing:raw:notice }
bind raw - "WALLOPS" { arm::coroexec arm::routing:raw:wallops }

loadcmds

# -- onconnect commands (/oper)
proc routing:raw:initserver {type} {
    set user [cfg:get routing:oper:user *]
    set pass [cfg:get routing:oper:pass *]
    debug 0 "routing:raw:initserver: sending /OPER $user \[REDACTED\]"
    putquick "OPER $user $pass"
    putquick "AWAY :inside the matrix."
}

# -- Your are now an IRC operator
proc routing:raw:opered {server cmd text} {
    global botnick
    debug 0 "routing:raw:opered: bot is now an IRC Operator.. setting umode +ws and starting /map"
    putquick "MODE $botnick +ws"; # -- need to see wallops and server notices
    utimer 30 arm::routing:map;   # -- give time to join channels and settle
}

# -- periodic /map
proc routing:map {} {
    global server;
    variable cfg
    variable initrouting; # -- time of initialisation start
    variable cycle_start; # -- ts to time a full cycle (MAP, LINKS, STATS l,c,o)
    set cycle_start [unixtime]

    if {[info exists initrouting]} {
        debug 0 "routing:map: \002initialisation begin\002"
        reply pub $cfg(routing:chan) "\002\[\002debug\002\]\002 initialisation \002begin\002"
    }

    # -- kill any existing /map timers
    foreach t [utimers] {
        lassign $t secs proc tid i
        debug 2 "routing:map: timer loop: tid: $tid -- proc: $proc -- secs: $secs"
        if {$proc eq "arm::routing:map"} {
            debug 1 "routing:map: killing routing:map timer: $tid"
            killutimer $tid
        }
    }
    set int [cfg:get routing:int]
    set reportchan [arm::cfg:get routing:chan *] 
    if {$server ne ""} {
        #reply msg $reportchan "\002\[\x0303debug\x03]\002 sending /MAP"
        after $int "arm::debug 2 \"routing:map: sending /MAP\""
        after $int "putquick \"MAP\""
    }
}

# -- interpret /map data for network map
proc routing:raw:map {server cmd text} {
    variable map; #-- dict for map data
    set mynick [lindex $text 0]

    set data [string trimleft $text "$mynick :"]
    regexp -- {^(\s*[`\|\-\s]*)((?:[A-Za-z0-9]+\.?)*)\s+(?:\((\d+)s\))?\s?\[(\d+)\sclients\]} $data -> draw serv secs clients
    regsub -all {\.undernet\.org} [string tolower $serv] {} serv
    debug 5 "routing:raw:map: draw: $draw -- server: \002$serv\002 -- secs: $secs -- clients: $clients" 

    if {[info exists map] && [dict exists $map $serv count]} {
        # -- previous count data in memory
        set prevclients [dict get $map $serv count]
        set change [expr $clients.0-$prevclients.0]; 
        if {[string index $change 0] eq "-"} {
            # -- drop in usercount
            set change [string range $change 1 end]
            set net [expr $prevclients - $clients]
            set change [format %0.2f [expr ($net.0/$prevclients.0)*100]]
            set var "\002dropped\002 by \002$net\002"; set what "clients-down"; set whatc "\002\[\x0304$what\x03\]\002"
        } else {
            if {$change eq "0.0"} {
                # -- no usercount change
                set var "lost zero"; set net 0
            } else {
                # -- increase in usercount
                set net [expr $clients - $prevclients]
                set change [format %0.2f [expr ($net.0/$prevclients.0)*100]]
                set var "\002increased\002 by \002$net\002"; set what "clients-up"; set whatc "\002\[\x0311$what\x03\]\002"
            }
        }
        lassign [split $change .] first second
        if {$second eq "0" || $second eq "00"} { set change $first }
        if {$change ne 0} { debug 0 "routing:raw:map: (map) $serv -- $var clients ($change% -- now: $clients)" }

        # -- channel alerts
        set reportchan [cfg:get routing:chan *]
        if {[cfg:get routing:alert:perc *] <= $change || [cfg:get routing:alert:count *] <= $net} {
            if {[cfg:get routing:alert *] && [botonchan $reportchan]}  {
                reply msg $reportchan "$whatc $serv \002--\002 $var clients \002(change:\002 $change% \002-- now:\002 $clients\002)\002"
            }
            routing:log $what "$serv -- $var clients (change: $change% -- now: $clients)"; # -- send to db logger
        }

    }
    dict set map $serv secs $secs
    dict set map $serv count $clients
}


# -- trigger to request /LINKS
proc routing:raw:endofmap {server cmd text} {
    set int [cfg:get routing:int]
    after $int "arm::debug 3 \"routing:raw:endofmap: requesting /LINKS\""
    set reportchan [cfg:get routing:chan]
    #reply msg $reportchan "\002\[\x0303debug\x03]\002 sending /LINKS"
    #after $int "arm::reply msg $reportchan \"\002\[\x0303debug\x03]\0022 sending /LINKS...\""
    after $int "putquick LINKS"
}

# -- interpret /links data, to store uplink data
# Oper.Undernet.Org 364 knottedEmp elysium.us.ix.undernet.org h44.us.undernet.org :5 P10 Sharktech Inc. - www.sharktech.net
proc routing:raw:links {server cmd text} {
    variable map; # -- dict for map data
    lassign $text mynick serv uplink depth
    regsub -all {\.undernet\.org} [string tolower $serv] {} serv
    regsub -all {\.undernet\.org} [string tolower $uplink] {} uplink
    set depth [string trimleft $depth :]
    set desc [lrange $text 5 end]
    debug 5 "routing:raw:links: updating \002server:\002 $serv -- \002uplink:\002 $uplink -- \002depth:\002 $depth -- \002desc:\002 $desc"
    dict set map $serv uplink $uplink;
    dict set map $serv depth $depth;
    dict set map $serv desc $desc
}

# -- log end of /links
proc routing:raw:endoflinks {server cmd text} {
    variable map; # -- dict of map data
    debug 3 "routing:raw:endoflinks: updated total of \002[llength [dict keys $map]]\002 servers"
    routing:db:update; # -- write map data to DB
}

# -- periodically write network map data to DB
proc routing:db:update {} {
    variable map; # -- dict of network map data
    db:connect
    set count 0; set autoadd 0;
    foreach serv [dict keys $map] {
        incr count
        set uplink [dict get $map $serv uplink]
        set uplink_ts [db:get open_ts routing_stats_l source $serv connection $uplink]
        set clients [dict get $map $serv count]
        set db_desc [db:escape [dict get $map $serv desc]]
        set dbserv [db:get server routing_servers server $serv]
        if {$dbserv ne ""} {
            # -- server exists in DB
            db:query "UPDATE routing_servers SET uplink='$uplink',uplink_ts='$uplink_ts',clients='$clients',desc='$db_desc' WHERE server='$serv'"
            incr count
        } else {
            # -- server doesn't exist in DB. auto-create
            if {[regexp -- {^h\d+\.[a-z]+$} $serv]} { set ishub "Y"; set servtype "hub" } else { set ishub "N"; set servtype "client" }
            set db_serv [db:escape $serv]
            set db_added_by [db:escape "Routing Bot (auto)"]
            db:query "INSERT INTO routing_servers (server,ishub,uplink,uplink_ts,added_ts,added_by,modif_ts,modif_by) \
                VALUES ('$db_serv','$ishub','$uplink','$uplink_ts','[unixtime]','$db_added_by','[unixtime]','$db_added_by');"
            incr autoadd
            set newserver($serv,$servtype,$uplink) 1; # -- track newly found servers
        }
    }
    set ncount [llength [array names newserver]]
    set reportchan [cfg:get routing:chan *]
    set toemail [cfg:get routing:mail:to]
    set file "[pwd]/tmp/newservers.tmp"
    set doalert 1
    if {$ncount > 5} {
        set doalert 0
        reply pub $reportchan "\002\[\x0303server-new\x03\]\002 detected \002$ncount new servers\002. results sent to: \002$toemail\002"
    } 
    set alertopers [cfg:get routing:alert:opers *]
    foreach server [array names newserver] {
        lassign [split $server ,] serv servtype uplink
        if {$alertopers && [botonchan $reportchan] && $doalert eq 1}  {
            reply pub $reportchan "\002\[$server-new\]\002 detected new server: \002$serv\002 (\002type:\002 $servtype -- \002uplink:\002 $uplink)\002" 
        }
        exec echo "\[server-new\] detected new server: $serv (type: $servtype -- uplink: $uplink)" >> $file; # -- write to temp file for email
    }

    # -- mailer
    if {[file exists $file]} { 
        debug 0 "routing:db:update: sending email listing newly found servers"
        # -- sort alphabetically to group servers (shell exec commands not working for some reason)
        set linesort [list]; set fd [open $file r]
        set lines [split [read $fd] \n]
        foreach line $lines {
            debug 0 "db:update: sorting line: $line"
            lappend linesort $line
        }
        set linesort [lsort $linesort]
        close $fd
        set fd [open $file.new w+]
        foreach line $linesort {
            debug 0 "db:update: writing line: $line"
            puts $fd "$line"
        }
        close $fd
        exec mail -s [cfg:get routing:mail:subject] $toemail < $file.new
        #exec rm -rf $file; catch { exec rm -rf $file.new }
    }; # -- end mailer

    db:close
    debug 0 "routing:db:update: written $count updates to existing servers in routing table."
    debug 0 "routing:db:update: automatically added $autoadd servers to routing table."
    debug 0 "routing:db:update: begin '/STATS l' loop for all non-service servers"
    #reply msg [cfg:get routing:chan] "\002\[\002debug\002\]\002 beginning '/STATS l' loop for all non-service servers"
    routing:statsl; # -- start /STATS l
}

# -- trigger the '/stats l' collection
proc routing:statsl {} {
    variable map;          # -- dict of network map data
    variable statlines;    # -- array to hold data from '/stats' responses
    variable stats;        # -- array to store the '/stats' return data
                           #      l,start   start time of first /stats l
                           #      l,count   count of servers to process via /stats l
                           #      l,last    store the last server before summarising results
                           #      l,cur     store the current server being processed via /stats l
    set nonservices ""
    set stats(l,cur) ""
    set services [cfg:get routing:services]
    foreach serv [dict keys $map] {
        # -- ignore network services
        if {$serv ni $services} {
            lappend nonservices $serv
        }
    }
    set stats(l,count) [llength $nonservices]
    set stats(l,last) [lindex $nonservices end-0]
    set stats(l,start) [clock seconds]
    set int [cfg:get routing:int]; set delay $int
    foreach nonservice $nonservices {
        after $delay "arm::dostats l $nonservice*"; # -- delay to avoid excess flood
        incr delay $int; # -- stagger the stats timers
    }
}

# -- periodically collect '/stats l' from every server
# -- note: this is intensive (35 x server commands as of 2021-08-30) -- ~62 secs to process
# h44.us.undernet.org 211 knottedEmp Connection SendQ SendM SendKBytes RcveM RcveKBytes :Open since
# h44.us.undernet.org 211 knottedEmp chat.undernet.org 0 7202244 325720 1187713 60241 :1505908
# h44.us.undernet.org 211 knottedEmp h11.eu.undernet.org 382 75586717 5817096 124361294 10022837 :6647386
# h44.us.undernet.org 219 knottedEmp l :End of /STATS report
proc routing:raw:statsl {server cmd text} {
    variable map;   # -- dict for map data
    variable links; # -- dict for link data
    variable stats; # -- array to store the '/stats' return data
                    #      l,start   start time of first /stats l
                    #      l,count   count of servers to process via /stats l
                    #      l,last    store the last server before summarising results
                    #      l,cur     store the current server being processed via /stats l
    set text [lrange $text 1 end]
    if {[string match "Connection SendQ SendM SendKBytes RcveM RcveKBytes :Open since" $text]} { return; }; # -- header row
    lassign $text connection sendq sendm sendkb receivem receivekb open_ts
    if {![string match "*.*" $connection]} { return; }; # -- only include server connection stats
    #debug 0 "routing:raw:statsl: updating '/stats l': (server: $server -- connection: $connection)"
    regsub -all {\.undernet\.org} [string tolower $server] {} serv
    set stats(l,cur) $serv; # -- update the current '/stats l' response server 
    regsub -all {\.undernet\.org} [string tolower $connection] {} connection
    set open_ts [string trimleft $open_ts :]
    dict set links $serv $connection [list sendq $sendq sendm $sendm sendkb $sendkb receivem $receivem receivekb $receivekb open_ts $open_ts]
    db:connect
    set exists [db:get connection routing_stats_l source $serv connection $connection]
    set unixtime [unixtime]
    if {$exists eq ""} {
        # -- no data for this connection -> insert
        db:query "INSERT INTO routing_stats_l (source,connection,sendq,sendm,sendkb,receivem,receivekb,open_ts,updated_ts) \
            VALUES ('$serv','$connection','$sendq','$sendm','$sendkb','$receivem','$receivekb','$open_ts','$unixtime')"
    } else {
        # -- existing connection data -> update
        db:query "UPDATE routing_stats_l SET sendq='$sendq',sendm='$sendm',sendkb='$sendkb',receivem='$receivem',\
            receivekb='$receivekb',open_ts='$open_ts',updated_ts='$unixtime' WHERE source='$serv' AND connection='$connection'";
    }
    db:query "UPDATE routing_servers SET uplink_ts='$open_ts' WHERE server='$serv' AND uplink='$connection'"
    debug 0 "routing:raw:statsl: updated '/stats l' data for server $serv (sendq: $sendq -- sendm: $sendm -- sendkb: $sendkb -- \
        receivem: $receivem -- receivekb: $receivekb -- open_ts: $open_ts -- updated_ts: $unixtime)"
    # -- TODO: how to delete old servlink connection data? (from dict and db)
    #db:close
}

# -- trigger the '/stats c' collection
# -- note: this is intensive (35 x server commands as of 2021-08-30) -- ~62 secs to process
proc routing:statsc {} {
    variable map;          # -- dict of network map data
    variable stats;        # -- array to store the '/stats' return data
                           #      c,start   start time of first /stats c
                           #      c,count   count of servers to process via /stats c
                           #      c,last    store the last server before summarising results
                           #      c,cur     store the current server being processed via /stats c
    set servers [dict keys $map]
    set file "[pwd]/tmp/stats.tmp"
    if {[file exists $file]} {
        exec rm -rf $file
    }
    set nonservices ""
    set services [cfg:get routing:services]
    foreach serv $servers {
        # -- ignore network services
        if {$serv ni $services} {
            lappend nonservices $serv
        }
    }
    set stats(c,cur) ""
    set stats(c,count) [llength $nonservices]
    set stats(c,last) [lindex $nonservices end-0]
    set stats(c,start) [clock seconds]
    set int [cfg:get routing:int]; set delay $int
    foreach nonservice $nonservices {
        after $delay "arm::dostats c $nonservice*"; # -- delay to avoid excess flood
        incr delay $int; # -- stagger the stats timers
    }
}

# -- periodically collect '/stats c' from every server
# -- note: this is intensive (39 x server commands as of 2021-08-30) -- ~70 secs to process
# elysium.us.ix.undernet.org 213 knottedEmp C h44.us.undernet.org * 4400 65535 * Server
# elysium.us.ix.undernet.org 213 knottedEmp C h51.us.undernet.org * 4400 65535 * Server
proc routing:raw:statsc {server cmd text} {
    variable statlines;    # -- array to hold data from '/stats' responses
    variable stats;        # -- array to store the '/stats' return data
                           #      c,start   start time of first /stats c
                           #      c,count   count of servers to process via /stats c
                           #      c,last    store the last server before summarising results
                           #      c,cur     store the current server being processed via /stats c
    if {[lindex $text 1] ne "C"} { return }; # -- safety net
    set target [lindex $text 2]
    set port [lindex $text 4]
    set class [lindex $text 7]
    regsub -all {\.undernet\.org} [string tolower $server] {} source
    set stats(c,cur) $source; # -- update the current '/stats c' response server 
    regsub -all {\.undernet\.org} [string tolower $target] {} target

    # -- look for new connect blocks
    db:connect
    set row [join [db:query "SELECT server,alert_ts FROM routing_stats_c WHERE server='$source' AND connect='$target' AND port='$port' AND class='$class'"]]
    lassign $row server alert_ts
    if {$server eq ""} {
        # -- new connect block found
        set seen [unixtime]
        debug 0 "routing:raw:statsc: inserting new connect block from server: $source (target: $target -- port: $port -- class: $class -- seen_ts $seen)"
        db:query "INSERT INTO routing_stats_c (server,connect,port,class,seen_ts) VALUES('$source','$target','$port','$class','$seen')"
        set statsline(c,new,$source,$target,$port,$class,$alert_ts) 1; # -- maintain list of new clines found
    } 

    # -- check if connect block is for unknown server
    set servers ""
    db:connect
    foreach dbserver [db:query "SELECT server FROM routing_servers"] {
        lappend servers $dbserver
    }
    set servers [join $servers]
    if {$target ni $servers} {
        debug 0 "routing:raw:statsc: \002$source\002 has connect block for unknown server: \002$target\002"
        set statlines(c,unknown,$source,$target,$port,$class,$alert_ts) 1; # -- maintain list of unknown target servers in clines
    }
    #db:close
    set statlines(c,all,$source,$target,$port,$class) 1; # -- maintain list of those found
}


# -- trigger the '/stats o' collection
proc routing:statso {} {
    variable map;          # -- dict of network map data
    variable stats;        # -- array to store the '/stats' return data
                           #      o,start   start time of first /stats o
                           #      o,count   count of servers to process via /stats o
                           #      o,last    store the last server before summarising results
                           #      o,cur     store the current server being processed via /stats o
    set servers [dict keys $map]
    set file "[pwd]/tmp/stats.tmp"
    if {[file exists $file]} {
        exec rm -rf $file
    }
    set nonservices ""
    set services [cfg:get routing:services]
    foreach serv $servers {
        # -- ignore network services
        if {$serv ni $services} {
            lappend nonservices $serv
        }
    }
    set stats(o,cur) ""
    set stats(o,count) [llength $nonservices]
    set stats(o,last) [lindex $nonservices end-0]
    set stats(o,start) [clock seconds]
    debug 3 "routing:statso: beginning '/STATS o' loop -- stats(o,last): $stats(o,last)"
    set int [cfg:get routing:int]; set delay $int
    foreach nonservice $nonservices {
        after $delay "arm::dostats o $nonservice*"; # -- delay to avoid excess flood
        incr delay $int; # -- stagger the stats timers
    }
}

# -- periodically collect '/stats o' from every server
# zorro.us.ix.undernet.org 243 knottedEmp O *@172.168.171.1 * Admin Admin
# zorro.us.ix.undernet.org 243 knottedEmp O *@172.16.164.1 * Admin Admin
# zorro.us.ix.undernet.org 243 knottedEmp O @10.0.0.0/8 * Admin Admin
proc routing:raw:statso {server cmd text} {
    variable statlines;    # -- array to hold data from '/stats' responses
    variable stats;        # -- array to store the '/stats' return data
                           #      o,start   start time of first /stats o
                           #      o,count   count of servers to process via /stats o
                           #      o,last    store the last server before summarising results
                           #      o,cur     store the current server being processed via /stats o
    lassign $text mynick otype host ast oper class
    if {$otype ne "O" && $otype ne "o"} { return; }; # -- safety net
    regsub -all {\.undernet\.org} [string tolower $server] {} serv
    set stats(o,cur) $serv; # -- update the current '/stats o' response server 
    db:connect
    set dbhost [db:escape $host]
    set row [db:query "SELECT oper FROM routing_stats_o WHERE otype='$otype' AND host='$host' AND oper='$oper' AND class='$class'"]
    if {$row eq ""} {
        # -- entry does not exist
        debug 0 "routing:raw:statso: found \002new oper\002: $oper (type: $otype -- host: $host -- class: $class)"
        set statlines(o,new,$serv,$otype,$host,$oper,$class) 1; # -- maintain list of new o:lines found
    }
    set statlines(o,all,$serv,$otype,$host,$oper,$class) 1; # -- maintain list of all o:lines found
}

# -- end of '/stats l|c|o'
# -- process results, send alerts, send summary alert emails
# h27.eu.undernet.org 219 knottedEmp c :End of /STATS report
# h27.eu.undernet.org 219 knottedEmp o :End of /STATS report
proc routing:raw:endofstats {server cmd text} {
    variable initrouting;  # -- time of initialisation start (bootstrap)
    variable cycle_start;  # -- ts to time a full cycle (MAP, LINKS, STATS l,c,o)
    variable statlines;    # -- array to hold data from '/stats' responses
    variable stats;        # -- array to store the '/stats' return data
                           #      l,start   start time of first /stats l
                           #      l,count   count of servers to process via /stats l
                           #      l,last    store the last server before summarising results
                           #      l,cur     store the current server being processed via /stats l
                           #      c,start   start time of first /stats c
                           #      c,count   count of servers to process via /stats c
                           #      c,last    store the last server before summarising results
                           #      c,cur     store the current server being processed via /stats c
                           #      o,start   start time of first /stats o
                           #      o,count   count of servers to process via /stats o
                           #      o,last    store the last server before summarising results
                           #      o,cur     store the current server being processed via /stats o

    regsub -all {\.undernet\.org} [string tolower $server] {} server
    set forcerestart 0;
    set file "[pwd]/tmp/stats.tmp"; # -- temp file for email body data

    set s [lindex $text 1]; # -- set '/stat' response type        
    if {[info exists stats($s,last)] && [info exists stats($s,cur)] && [lindex $text 1] eq $s} {
        #debug 0 "routing:raw:endofstats: stats($s,start): $stats($s,start) -- stats($s,count): $stats($s,count) -- stats($s,last): $stats($s,last) -- stats($s,cur): $stats($s,cur)"
        if {$stats($s,last) eq $stats($s,cur)} {
            debug 0 "routing:raw:endofstats: stats($s,last) is stats($s,cur) -- \002it's the last server\002"
            # -- the last server in the list of the '/stats' server loop
            set reportchan [cfg:get routing:chan *]
            set toemail [cfg:get routing:mail:to]
            set taken [expr [unixtime] - $stats($s,start)]; # -- time taken to process all servers
            set logstring "completed '/stats $s' from \002$stats($s,count)\002 servers (in \002$taken secs\002)."
            debug 0 "routing:raw:endofstats: $logstring"
            #reply msg $reportchan "\002\[\x0303debug\x03]\002 $logstring"
            # -- /stats l
            if {$s eq "l"} {
                # -- no need to do anything here

            # -- '/stats c' or '/stats o'
            } elseif {$s eq "c" || $s eq "o"} {
                # -- check if there was zero response from '/stats'
                set statlines_all($s) [array names statlines $s,all,*]
                set ncount [llength $statlines_all($s)]
                # -- if the response is empty it could have timed out due to high sendq (indicating an imminent netsplit)
                if {$ncount eq 0} {
                    # -- no responses from server
                    set logstring "\002\[\x0306no-response\x03\]\002 detected \002potential imminent netsplit\002 from server: \002$server\002 (/stats c)"
                    debug 0 "routing:raw:endofstats: $logstring"
                    reply pub $reportchan "$logstring"
                    routing:log no-response "detected potential imminent netsplit from server: $server (/stats $s)"
                    set forcerestart 1;
                } else {
                    # -- server responded with at least one entry from /stats

                    # -- process all new lines found
                    set statlines_new($s)  [array names statlines $s,new,*]
                    set ncount [llength $statlines_new($s)]
                    switch -- $s {
                        c { set atype "connect block"; set what "connect" }
                        o { set atype "o:line"; set what "oper" }
                    }
                    if {$ncount <= 5} {
                        # -- send alerts to reportchan
                        set chanalert 1
                    } else {
                        set chanalert 0
                        reply pub $reportchan "\002\[\x0308oper-add\x03\]\002 detected \002$ncount new ${atype}s\002. results sent to: \002$toemail\002"
                    }
                    db:connect
                    foreach line $statlines_new($s) {
                        if {$s eq "c"} {
                            # -- '/stats c' specific handling (new connect block found)
                            lassign [split $line ,] sline new source target port class alert_ts
                            set what "connect-add"; set whatc "\x0308$what\x03"
                            debug 0 "\[$what\] \002$source\002 has \002added\002 a new $rtype: \002$target\002 (\002port:\002 $port -- \002class:\002 $class\002)";
                            db:connect
                            db:query "INSERT INTO routing_stats_c (server,connect,port,class,seen_ts) \
                                VALUES ('$source','$target','$port','$class','[unixtime]')"
                            set added $target
                            set rtype $atypes
                            set extrac "(\002port:\002 $port -- \002class:\002 $class)\002"
                            set extra "(port: $port -- class: $class)"
                            set logstring "$source has added a new $rtype: $target $extra"

                        } elseif {$s eq "o"} {
                            # -- '/stats o' specific handling (new o:line found)
                            lassign [split $line ,] sline new source otype host oper class
                            set what "oper-add"; set whatc "\x0308$what\x03"
                            switch -- $otype {
                                o { set opertype "local" }
                                O { set opertype "global" }
                            }
                            set rtype "$opertype $atype"; set added $oper
                            set extrac "(\002mask:\002 $host -- \002class:\002 $class\002)"
                            set extra "(mask: $host -- class: $class)"
                            set logstring "$source has added a new $opertype o:line: $oper $extra"
                            debug 0 "\[$what\] \002$source\002 has \002added\002 a new $rtype: \002$added $extrac";
                            set dbhost [db:escape $host]
                            db:connect
                            db:query "INSERT INTO routing_stats_o (server,otype,host,oper,class,created_ts,lastseen_ts) \
                                VALUES ('$source','$otype','$dbhost','$oper','$class','[unixtime]','[unixtime]')"
                        }

                        if {$chanalert} {
                            if {[cfg:get routing:alert:opers *] && [botonchan $reportchan]}  {
                                reply pub $reportchan "\002\[$whatc\]\002 \002$source\002 has added a new $rtype: \002$added\002 $extrac" 
                            }
                        }

                        # -- logger
                        exec echo "\[$what\] $logstring" >> $file; # -- write to temp file for email
                        routing:log $what $logstring; # -- send to db logger

                    }; # -- end foreach new stats line entries

                    # -- '/stats c' specific handling
                    if {$s eq "c"} {
                        # -- process all clines with unknown servers
                        set clines_unknown [array names statlines $s,unknown,*]
                        set ucount [llength $clines_unknown]
                        db:connect
                        set cache [cfg:get routing:alert:cache]
                        set alertremserver [cfg:get routing:alert:remserver *]
                        set what "connect-unknown"; set whatc "\x0304$what\x03"; set rwhat "connect block"
                        set alerts [list]
                        set newalert 0;
                        foreach cline $clines_unknown {
                            lassign [split $cline ,] sline new source target port class alert_ts
                            # -- send the alert?
                            set doalert 0;
                            if {$alert_ts ne ""} {
                                # -- check if last alert was > cache time ago
                                set timeago [expr [unixtime] - $alert_ts]
                                set hours [expr $timeago / 60]
                                if {$hours >= $cache} { set doalert 1; }; # -- last alert was older than cache time
                            }
                            debug 0 "routing:raw:endofstats: source: $source -- unknown server: $target -- doalert: $doalert -- newalert: $newalert -- alert_ts: $alert_ts -- alertremserver: $alertremserver"
                            if {$alert_ts eq "" || $doalert eq 1} {
                                    # -- send the alert
                                    incr newalert
                                    db:connect
                                    db:query "UPDATE routing_stats_c SET alert_ts='[unixtime]' WHERE server='$source' AND connect='$target' AND port='$port' AND class='$class'"
                                    lappend alerts "\002\[$whatc\]\002 \002$source\002 has connect block for unknown server: \002$target\002"
                                    set logstring "$source has connect block for unknown server: $target"
                                    debug 0 "routing:raw:endofstats: $logstring"
                                    exec echo "\[$what\] $logstring" >> $file; # -- write to temp file for email
                                    routing:log $what $logstring; # -- send to db logger
                            } else {
                                set logstring "$source has connect block for unknown server: $target"
                                debug 0 "routing:raw:endofstats: $logstring -- but \002alert has been sent recently ($timeago secs)\002"
                            }
                        }; # -- end of foreach

                        # -- avoid excess floods
                        if {[llength $alerts] <= 5 && $alertremserver && [botonchan $reportchan]} {
                            foreach alertmsg $alerts {
                                reply pub $reportchan $alertmsg
                            }
                        } 
                        # -- end unknown servers
                    
                        # -- sending any new email alerts?
                        if {$newalert > 0} {
                            reply pub $reportchan "\002\[\x0304connect-unknown\x03\]\002 detected \002$ucount ${rwhat}s with unknown servers\002. sent \002$newalert\002 new alerts to: \002$toemail\002"
                        }

                        # -- end of clines with unknown servers
                    }; # -- end of '/stats c' specific handling

                    # -- now check if any blocks were removed
                    if {$s eq "c"} {
                        # -- c:line removal check
                        set what "connect"; set rwhat "connect block"
                        db:connect
                        set rows [db:query "SELECT server,connect,port,class FROM routing_stats_c"]
                        foreach row $rows {
                            lassign $row serv connect port class
                            if {![info exists statlines($s,all,$serv,$connect,$port,$class)]} {
                                # -- connect block has been removed
                                set statlines($s,removed,$serv,$connect,$port,$class) 1
                                # -- TODO: check that the server is on the network and responded (avoids false positive)
                            }
                        }
                    } elseif {$s eq "o"} {
                        # -- o:line removal check
                        set what "oper"; set rwhat "o:line"
                        db:connect
                        set rows [db:query "SELECT server,otype,host,oper,class FROM routing_stats_o"]
                        foreach row $rows {
                            lassign $row serv otype host oper class
                            if {![info exists statlines($s,all,$serv,$otype,$host,$oper,$class)]} {
                                # -- oper has been removed
                                # -- TODO: check that the server is on the network and responded (avoids false positive)
                                set statlines($s,removed,$serv,$otype,$host,$oper,$class) 1
                            }
                        }
                    }
                    set statlines_removed($s) [array names statlines $s,removed,*]
                    set rcount [llength $statlines_removed($s)]
                    if {$rcount <= 5} {
                        # -- send alerts to reportchan
                        set chanalert 1
                    } else {
                        reply pub $reportchan "\002\[\x0308$what-del\x03\]\002 detected \002$rcount removed ${rwhat}s\002. results sent to: \002$toemail\002"
                        set chanalert 0
                    }
                    set alerts [list]
                    foreach line $statlines_removed($s) {
                        if {$s eq "c"} {
                            # -- connect block removal
                            lassign [split $line ,] sline removed serv connect port class alert_ts
                            set what "connect-del"; set whatc "\x0308$what\x03"
                            set extrac "(\002port:\002 $port -- \002class:\002 $class\002)"
                            set extra  "(port: $port -- class: $class)"
                            debug 0 "routing:raw:endofstats: \[$what\] \002$serv\002 has \002removed\002 a connect block: $extra";
                            set logstring "$serv has removed a $rwhat: $connect $extra"
                            set removed $connect
                            db:connect
                            debug 0 "\002DELETE FROM routing_stats_c WHERE server='$serv' AND connect='$connect' AND port='$port' AND class='$class'\002"
                            db:query "DELETE FROM routing_stats_c WHERE server='$serv' AND connect='$connect' AND port='$port' AND class='$class'"
                            db:close
                        } elseif {$s eq "o"} {
                            # -- o:line removal
                            lassign [split $line ,] sline removed serv otype host oper class
                            set what "oper-del"; set whatc "\x0308$what\x03"
                            switch -- $otype {
                                o { set opertype "local" }
                                O { set opertype "global" }
                            }
                            set rwhat "$opertype $rwhat"; set removed $oper
                            set extra "(mask: $host -- class: $class)"
                            set extrac "(\002mask:\002 $host -- \002class:\002 $class\002)"
                            set logstring "$serv has removed a $opertype o:line: $oper (mask: $host -- class: $class)"
                            debug 0 "routing:log \[$what\] \002$serv\002 has \002removed\002 a $rwhat: \002$removed $extra";
                            db:connect
                            db:query "DELETE FROM routing_stats_o WHERE server='$serv' AND otype='$otype' AND host='$host' AND oper='$oper' AND class='$class'"
                            db:close
                        }

                        lappend alerts "\002\[$whatc\]\002 \002$serv\002 has \002removed\002 a $rwhat: \002$removed\002 $extrac" 

                        # -- logger
                        exec echo "\[$what\] $logstring" >> $file; # -- temp file for mailer
                        routing:log $what $logstring; # -- send to db logger
                    }; # -- end block removals

                    # -- avoid excess floods
                    if {[llength $alerts] <= 5} {
                        if {[botonchan $reportchan]} {
                            foreach alertmsg $alerts {
                                reply pub $reportchan $alertmsg
                            }
                        }
                    } else {
                        reply pub $reportchan "\002\[\x0308email-alert\x03\]\002 detected \002[llength $alerts] alertable events\002. all results sent to: \002$toemail\002"
                    }

                }; # -- end of server responses
            }; # -- end of '/stats c' or '/stats o'

            # -- cleanup
            unset stats($s,start)
            unset stats($s,cur)
            unset stats($s,last)
            unset stats($s,count)
            if {[info exists statlines]} { unset statlines }
            # -- /stats l
            if {$s eq "l"} {
                routing:statsc; # -- now do /stats c   

            # -- '/stats c'
            } elseif {$s eq "c"} {
                routing:statso; # -- now do /stats o

            # -- '/stats o'
            } elseif {$s eq "o"} {
                set forcerestart 1; # -- restart the cycle
            }

            if {$forcerestart} {
                
                # -- report initialisation complete
                if {[info exists initrouting]} {
                    reply pub $reportchan "\002\[\002debug\002\]\002 initialisation \002complete\002 ([expr [unixtime] - $initrouting] secs)"
                    unset initrouting
                }

                # -- mailer
                # -- send email once the last '/stats' results were returned
                if {[file exists $file]} { 
                    debug 0 "routing:raw:endofstats: sending email from '/stats $s' server loop"
                    # -- sort alphabetically to group servers (shell exec commands not working for some reason)
                    set linesort [list]; set fd [open $file r]
                    set lines [split [read $fd] \n]
                    foreach line $lines {
                        debug 0 "endofstats: sorting line: $line"
                        lappend linesort $line
                    }
                    set linesort [lsort $linesort]
                    close $fd
                    set fd [open $file.new w+]
                    foreach line $linesort {
                        debug 0 "endofstats: writing line: $line"
                        puts $fd "$line"
                    }
                    close $fd
                    exec mail -s [cfg:get routing:mail:subject] $toemail < $file.new
                    #exec rm -rf $file; catch { exec "rm -rf $file.new" }
                }; # -- end mailer

                set taken [expr [unixtime] - $cycle_start]; # -- time taken to process all servers
                debug 0 "routing:raw:endofstats:  full scan cycle took \002$taken secs\002."
                #reply pub $reportchan "\002\[\002debug\002\]\002 full scan cycle took \002$taken secs\002."
                # -- restart cycle: 
                # /MAP
                # /LINKS
                # /STATS l (loop per server)
                # /STATS c (loop per server)
                # /STATS o (loop per server)
                set delay [expr [cfg:get routing:alert:int] - $taken]
                if {$delay <= 0} {
                    set logstring "full scan cycle (\002$taken secs\002) was \002longer\002 than cfg(routing:alert:int)\
                    (\002[cfg:get routing:alert:int] secs\002), restarting routing:map \002now\002."
                    debug 0 "routing:raw:endofstats: $logstring"
                    reply pub $reportchan "\002\[\002debug\002\]\002 $logstring"
                    routing:map
                } else {
                    debug 0 "routing:raw:endofstats: full scan cycle ($taken secs) was \002shorter\002 than cfg(routing:alert:int)\
                    ([cfg:get routing:alert:int] secs), restarting routing:map \002in $delay secs\002."
                    utimer $delay arm::routing:map
                }
                return;
            }

        }; # -- end of last=current
    }; # -- end of stats match
}

# -- interpret server notices
# -- | Oper.Undernet.Org: *** Notice -- Net break: h44.us.undernet.org elysium.us.ix.undernet.org (Read error: Operation timed out)
# -- | Oper.Undernet.Org: *** Notice -- Net junction: h44.us.undernet.org elysium.us.ix.undernet.org
# -- | Oper.Undernet.Org: *** Notice -- Completed net.burst from elysium.us.ix.undernet.org.
# -- | Oper.Undernet.Org: *** Notice -- elysium.us.ix.undernet.org acknowledged end of net.burst.
proc routing:raw:notice {server cmd text} {
    debug 4 "routing:raw:notice: server: $server -- cmd: $cmd -- text: $text"
    if {[lindex $text 0] ne "*"} { return; }; # -- not a server notice
    set text [string trimleft [lrange $text 1 end] :]
    set rest [lrange $text 3 end]
    if {[string match "Net break: *" $rest]} {
        set what "net-break"; set whatc "\x0304net-break\x03"
        set reason [lrange $rest 4 end]; set reason [string trimleft $reason "("]; set reason [string trimright $reason ")"]
        set extra [string tolower "[lindex $rest 2] \002<->\002 [lindex $rest 3] -- (\002reason:\002 $reason)"]
    } elseif {[string match "Net junction: *" $rest]} {
        set what "net-junction"; set whatc "\x0303net-junction\x03"
        set serv [lindex $rest 3]
        regsub -all {\.undernet\.org} [string tolower $serv] {} serv
        set extra "[lindex $rest 2] \002<->\002 $serv"
    } elseif {[string match "Completed net.burst from *" $rest]} {
        set what "net-burst"; set whatc "\x0303net-burst\x03"
        set extra [lindex $rest 3]
        regsub -all {\.undernet\.org} [string tolower $extra] {} extra
    } elseif {[string match "* acknowledged end of net.burst." $rest]} {
        set what "net-burst-ack"; set whatc "net-burst-ack"
        set extra [lindex $rest 0]
        regsub -all {\.undernet\.org} [string tolower $extra] {} extra
    } else {
        # -- no notice match
        return;
    }
    regsub -all {\.undernet\.org} [string tolower $extra] "" extra; # -- shorten server names
    debug 0 "routing:raw:notice: $what: $extra"
    # -- send the alert?
    set reportchan [cfg:get routing:chan *]
    if {[cfg:get routing:alert *] && [botonchan $reportchan]}  {
        reply msg $reportchan "\002\[$whatc\]\002 $extra"
    }
    routing:log $what $extra
}


# -- interpret server WALLOPS
# -- | Wallops from h44.us.undernet.org: * Remote CONNECT elysium.us.ix* 0 from rVn
proc routing:raw:wallops {server cmd text} {
    debug 3 "routing:raw:wallops: server: $server -- cmd: $cmd -- text: $text"
    if {[string match "*!*" $server]} { return; }; # -- wallop sent by client instead of server
    regsub -all {\.undernet\.org} [string tolower $server] {} server; # -- shorten server name
    set text [lrange $text 1 end]
    if {[string match "Remote CONNECT *" $text]} {
        set connect [string tolower [lindex $text 2]]
        regsub -all {\.undernet\.org} [string tolower $connect] {} connect
        set bywho [lindex $text 5]
        set what "connect"; set whatc "\x0308connect\x03"
        set extra "$connect \002(from:\002 $server -- \002by:\002 $bywho\002)\002"
    } else {
        # -- no WALLOP match
        return;
    }
    # -- send the alert?
    set reportchan [cfg:get routing:chan *]
    if {[cfg:get routing:alert *] && [botonchan $reportchan]}  {
        reply msg $reportchan "\002\[$whatc\]\002 $extra"
    }
    routing:log $what $extra
}


# -- the main command
#   serv add [server]
#   serv del [server]
#   serv mod [server] [hub|admin|note] <value>
#   serv view [server]
#   serv top
#   serv stats
#   serv log [view|search|last] <server|mask|N>
#   serv dns [add|del|view] [entry] <value>
proc arm:cmd:serv {0 1 2 3 {4 ""} {5 ""}} {
    variable map; # -- dict of network map data
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    set cmd "serv"
    
    debug 1 "cmd:serv: $arg"
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get user,id users curnick $nick] user uid
    if {$type ne "chan"} { set chan [userdb:get:chan $user $chan]}; # -- find a logical chan
    set cid [db:get id channels chan $chan]
    set level [db:get level levels cid $cid uid $uid]
    set glevel [db:get level levels cid 1 uid $uid]
    # -- end default proc template
        
    set what [string tolower [lindex $arg 0]]
    if {$what eq ""} {
        replynow $type $starget "\002usage:\002 serv \[add|del|mod|view|top|stats|log|dns\] \[params\]"; 
        replynow $type $starget "\002usage:\002 need help? \002use:\002 help serv"
        return;
    }
    set rest [join [lrange $arg 1 end]]

    if {$what eq "add"} {
        # -- add a new server entry
        if {$rest eq ""} {
            replynow $type $starget "\002usage:\002 serv add \[server\]"; return;
        }
        set serv [string tolower [lindex $rest 0]]
        regsub -all {\.undernet\.org} [string tolower $serv] {} serv
        set dbserv [db:get server routing_servers server $serv]
        if {$dbserv ne ""} {
            replynow $type $target "server \002$dbserv\002 already exists."; return;
        }
        db:connect
        if {[regexp -- {^h\d+\.[a-z]+$} $serv]} { set ishub "Y" } else { set ishub "N" }
        set db_serv [db:escape $serv]
        set db_added_by [db:escape "$nick!$uh ($user)"]
        db:query "INSERT INTO routing_servers (server,ishub,added_ts,added_by,modif_ts,modif_by) \
            VALUES ('$db_serv','$ishub','[unixtime]','$db_added_by','[unixtime]','$db_added_by');"
        db:close
        replynow $type $target "added server: \002$serv\002"

    } elseif {$what eq "del" || $what eq "rem" || $what eq "d"} {
        # -- delete a server entry
        if {$rest eq ""} {
            replynow $type $starget "\002usage:\002 serv del \[server\]"; return;
        }
        set serv [string tolower [lindex $rest 0]]
        regsub -all {\.undernet\.org} [string tolower $serv] {} serv
        set dbserv [db:get server routing_servers server $serv]
        if {$dbserv eq ""} {
            replynow $type $target "server \002$serv\002 does not exist in database."; return;
        }
        db:connect
        set db_serv [db:escape $serv]
        db:query "DELETE FROM routing_servers WHERE server='$db_serv';"
        db:query "DELETE FROM routing_stats_o WHERE server='$db_serv';"
        db:query "DELETE FROM routing_stats_c WHERE server='$db_serv OR connect='$db_serv';"
        db:query "DELETE FROM routing_stats_l WHERE source='$db_serv' OR connection='$db_serv';"; # -- is this deletion necessary?
        dict remove $map $db_serv 
        db:close
        replynow $type $target "deleted server: \002$serv\002"

    } elseif {$what eq "mod" || $what eq "m"} {
        set serv [string tolower [lindex $rest 0]]
        set col [lindex $rest 1]
        set param ""
        switch -- $col {
            hubs     { set param "uplinks" }
            hub      { set param "uplinks" }
            uplink   { set param "uplinks" }
            uplinks  { set param "uplinks" }
            admin    { set param "contact" }
            admins   { set param "contact" }
            contact  { set param "contact" }
            note     { set param "comment" }
            notes    { set param "comment" }
            comment  { set param "comment" }
            comments { set param "comment" }
        }
        set rest [lrange $rest 2 end]
        if {$param eq "" || ($rest eq "" && $param ne "comment")} {
            replynow $type $starget "\002usage:\002 serv mod \[server\] \[hubs|contact|comment\] <value>"; return;
        }
        regsub -all {\.undernet\.org} $serv {} serv
        set dbserv [db:get server routing_servers server $serv]
        if {$dbserv eq ""} {
            replynow $type $target "server \002$serv\002 does not exist in database."; return;
        }
        if {$param eq "uplinks"} {
            # -- update the server's uplinks (hubs)
            set value [split $rest ,];  # -- convert to space delimited
            set value [string tolower $value]
            foreach hub [join $value] {
                if {![regexp -- {^h\d+\.[a-z]+$} $hub]} {
                    replynow $type $starget "\002error:\002 invalid hub: $hub"; return;
                }
            }
            set db_uplinks [db:escape $value]
            set db_modifby [db:escape "$nick!$uh ($user)"]
            db:query "UPDATE routing_servers SET uplinks='$db_uplinks',modif_ts='[unixtime]',modif_by='$db_modifby' WHERE server='$serv'"
            replynow $type $target "done."

        } elseif {$param eq "contact"} {
            # -- update the server's contact details (admins)
            set db_contact [db:escape $rest]
            set db_modifby [db:escape "$nick!$uh ($user)"]
            db:query "UPDATE routing_servers SET contact='$db_contact',modif_ts='[unixtime]',modif_by='$db_modifby' WHERE server='$serv'"
            replynow $type $target "done."          
        } elseif {$param eq "comment"} {
            # -- update the server's contact details (admins)
            set db_comment [db:escape $rest]
            set db_modifby [db:escape "$nick!$uh ($user)"]
            db:query "UPDATE routing_servers SET comment='$db_comment',modif_ts='[unixtime]',modif_by='$db_modifby' WHERE server='$serv'"
            replynow $type $target "done."          
        }

    } elseif {$what eq "view" || $what eq "v"} {
        # -- view an existing server
        if {$rest eq ""} {
            replynow $type $starget "\002usage:\002 serv view \[server\]"; return;
        }
        set serv [string tolower [lindex $rest 0]]
        regsub -all {\.undernet\.org} $serv {} serv
        set dbserv [db:get server routing_servers server $serv]
        if {$dbserv eq ""} {
            replynow $type $target "server \002$serv\002 does not exist in database."; return;
        }
        lassign [db:get id,server,contact,ishub,uplinks,clients,added_ts,added_by,modif_ts,modif_by,uplink,uplink_ts,comment,desc routing_servers server $dbserv] \
            sid dbserv contact ishub uplinks clients added_ts added_by modif_ts modif_by uplink uplink_ts comment desc
        
        if {$ishub eq "Y"} { set servtype "hub" } else { set servtype "leaf" }
        if {$uplinks eq ""} { set uplinks "(none)" } else { set uplinks [join $uplinks] }
        if {$uplink_ts eq ""} { set uplink_ts "(never)" } else { set uplink_ts "[userdb:timeago [expr [unixtime]-$uplink_ts]] ago" }
        if {$uplink eq ""} { set conn "(none)" } else { set conn "$uplink (\002since:\002 $uplink_ts -- \002clients:\002 $clients)"}
        if {$contact eq ""} { set contact "(none)" } 

        replynow $type $target "\002server:\002 $dbserv -- \002type:\002 $servtype -- \002contact:\002 $contact"
        replynow $type $target "\002uplinks:\002 $uplinks -- \002connection:\002 $conn"
        replynow $type $target "\002added by:\002 $added_by, [userdb:timeago $added_ts] ago -- \002last modified:\002 [userdb:timeago $modif_ts] ago (\002by:\002 $modif_by)"
        if {$comment ne ""} { replynow $type $target "\002comment:\002 $comment" }

    } elseif {$what eq "top" || $what eq "t"} {
        
    } elseif {$what eq "stats" || $what eq "s"} {
        
    } elseif {$what eq "log" || $what eq "l" || $what eq "showlog"} {
        # -- display activity & command log
        # usage: log [view|search|last] <server|mask|N>
        set cmd [lindex $rest 0]
        set params [lrange $rest 1 end]
        db:connect
        if {$cmd eq ""} {
            replynow $type $starget "\002usage:\002 serv log \[search|cmd|last\] <mask|command|N> <max>"; db:close; return;
        } elseif {$cmd eq "last"} {
            set last [lindex $rest 1]
            if {$last eq "" || ![regexp -- {^\d+$} $last]} {
                replynow $type $starget "\002error:\002 provide a number for last N logs.";
                return;
            }
            if {$last > 10} { set over 1 } else { set over 0 }
            set rows [db:query "SELECT ts,event,cmd,message,user,bywho FROM routing_log ORDER BY ts DESC LIMIT $last"]
        } elseif {$cmd eq "search"} {
            set over 0;
            lassign $rest cmd search max
            if {$max eq "" || ![regexp -- {^\d+$} $max] || $max > 10} { set max 10 } 
            regsub -all {\*} $search {%} dbsearch
            set dbsearch [string tolower $dbsearch]
            set rows [db:query "SELECT ts,event,cmd,message,user,bywho FROM routing_log \
                WHERE lower(message) LIKE '$dbsearch' OR lower(user) LIKE '$dbsearch' ORDER BY ts DESC LIMIT $max"]
        } elseif {$cmd eq "cmd"} {
            set over 0;
            lassign $rest cmd search max
            if {$max eq "" || ![regexp -- {^\d+$} $max] || $max > 10} { set max 10 } 
            regsub -all {\*} $search {%} dbsearch
            set dbsearch [string tolower $dbsearch]
            set rows [db:query "SELECT ts,event,cmd,message,user,bywho FROM routing_log \
                WHERE lower(event) LIKE '$dbsearch' OR lower(cmd) LIKE '$dbsearch' ORDER BY ts DESC LIMIT $max"]
        }
        set count 0
        foreach row $rows {
            incr count
            lassign $row ts event cmd message dbuser db_bywho
            if {$event eq "cmd"} {
                replynow $type $target "\002\[\002[clock format $ts -format "%y-%m/%d %H:%M"]\002\]\002 \002cmd:\002 $cmd -- \002params:\002 $message -- \002user:\002 $dbuser"
            } else {
                replynow $type $target "\002\[\002[clock format $ts -format "%y-%m/%d %H:%M"]\002\]\002 \002event:\002 $event -- \002message:\002 $message"
            }
        }
        if {$over} {
            replynow $type $target "displayed a maximum of \00210 results\002. please restrict your search."
        } else {
            replynow $type $target "displayed a total of \002$count\002 results."
        }
        db:close
        
    } elseif {$what eq "dns"} {
        
    }

    routing:log cmd "$what $rest $user $nick!$uh"; # -- send to DB logger
}

# -- abstraction, to be called by 'after' timers
proc dostats {type extra} {
    debug 3 "routing:stats$type: sending /STATS $type $extra"
    putquick "STATS $type $extra"
}

# -- reply 'now' so command responses are prioritised above other server queues
# -- EDIT: this isn't really helping; requires upcoming ircu enhancement!
proc replynow {type target text} {
    switch -- $type {
        pub { putnow "PRIVMSG $target :$text" }
        msg { putnow "PRIVMSG $target :$text" }
        dcc { putidx $target $text }
        default { debug 0 "\002error\002: replynow: unknown type $type" }
    }
}

# -- logger and alerter
proc routing:log {event rest} {
    db:connect
    debug 4 "routing:log: event: $event -- rest: $rest"
    if {$event eq "cmd"} {
        # -- bot command
        lassign $rest cmd params user nuh
        set db_params [db:escape $params]
        set db_cmd [db:escape $cmd]
        set db_bywho [db:escape $nuh]
        debug 0 "routing:log: logging: event: $event -- cmd: $cmd -- message: $params -- user: $user -- bywho: $nuh"
        db:query "INSERT INTO routing_log (ts,event,cmd,message,user,bywho) \
            VALUES ([unixtime],'$event','$db_cmd','$db_params','$user','$db_bywho')"
    } else {
        # -- normal activity or alert
        set db_message [db:escape $rest]
        debug 0 "routing:log: logging: event: $event -- message: $rest"
        db:query "INSERT INTO routing_log (ts,event,message) VALUES ([unixtime],'$event','$db_message')"
        
    }
    db:close
}

# -- server entres
arm::db:query "CREATE TABLE IF NOT EXISTS routing_servers (\
    id INTEGER PRIMARY KEY AUTOINCREMENT,\
    server TEXT NOT NULL,\
    contact TEXT,\
    ishub TEXT NOT NULL DEFAULT 'N',\
    uplinks TEXT,\
    clients INT DEFAULT '0',\
    added_ts INT NOT NULL,\
    added_by TEXT,\
    modif_ts INT NOT NULL,\
    modif_by TEXT,\
    uplink TEXT,\
    uplink_ts INT,\
    comment TEXT,\
    desc TEXT)"

# -- routing event logs (commands and alerts)
arm::db:query "CREATE TABLE IF NOT EXISTS routing_log (\
    ts INT NOT NULL,\
    event TEXT NOT NULL,\
    cmd TEXT,\
    message TEXT NOT NULL,\
    user TEXT,\
    bywho TEXT)"

# -- routing opers (tracking o:lines per server)
arm::db:query "CREATE TABLE IF NOT EXISTS routing_stats_o (\
    server TEXT NOT NULL,\
    otype TEXT NOT NULL,\
    host TEXT NOT NULL,\
    oper TEXT NOT NULL,\
    class TEXT,\
    created_ts TEXT,\
    lastseen_ts)"

# -- routing server connect blocks 
arm::db:query "CREATE TABLE IF NOT EXISTS routing_stats_c (\
    server TEXT NOT NULL,\
    connect TEXT NOT NULL,\
    port INT NOT NULL,\
    class TEXT NOT NULL,\
    seen_ts INT NOT NULL,\
    alert_ts INT)"

# -- server links (/stats l)
arm::db:query "CREATE TABLE IF NOT EXISTS routing_stats_l (\
    source TEXT NOT NULL,\
    connection TEXT NOT NULL,\
    sendq INT,\
    sendm INT,\
    sendkb INT,\
    receivem INT,\
    receivekb INT,\
    open_ts INT,\
    updated_ts INT)"

# -- ensure tmp directory exists 
if {![file exists tmp]} { exec mkdir tmp }

# -- check for minimum delay
if {[cfg:get routing:alert:int] < 300} {
    debug 0 "routing cfg error: routing:alert:int must be set to a min of 300. resetting to 300"
    set cfg(routing:alert:int) 300
}

# -- initialisation
set scount [db:query "SELECT count(*) FROM routing_servers"]
if {$scount eq "" || $scount eq 0} {
    # -- first initialisation
    set initrouting [unixtime]
} else {
    catch {
        if {[info exists initrouting]} { unset initrouting }
    }
}
# -- end init


putlog "\[@\] loaded Undernet Routing Committee plugin."

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------
