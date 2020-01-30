#!/usr/bin/env tclsh
package require http
package require tls
package provide dronebl 1.3

###############################################################################
#                                                                             #
# DroneBL TCL library by rojo -- version 1.3                                  #
#                                                                             #
# Stick your RPC key into the set rpckey line at the top of dronebl.tcl.      #
# Then "source path/to/dronebl.tcl" in your eggdrop conf, TCL script or       #
# tclsh session.                                                              #
#                                                                             #
# This library provides the following methods:                                #
#                                                                             #
# ::dronebl::submit string                                                    #
#    string="[bantype] host/ip [host/ip [host/ip [host/ip...]]]"              #
# -- submits a new IP to the DroneBL as type [bantype] (optional; default: 1) #
# -- returns true if submission was successful; false if not                  #
#                                                                             #
# ::dronebl::remove string                                                    #
#    string="id [id [id [id...]]]"                                            #
# -- de-lists an entry with ID [id]                                           #
# -- returns true if submission was successful; false if not                  #
#                                                                             #
# ::dronebl::lookup string                                                    #
#    string="[options] addr/range [addr/range [addr/range [addr/range...]]]   #
#    optional switches:                                                       #
#      -active    -- shows only active listings (default)                     #
#      -inactive  -- shows only listings that have expired or been removed    #
#      -all       -- shows listings regardless of active status               #
#      -limit int -- requests a list of up to [int] matches (default: 10)     #
# -- queries the DroneBL for listings matching the ip, resolved host or range #
# -- returns a nested list.  Main list contains one match per line.  Each     #
#    line contains {id ip type listed timestamp}                              #
#                                                                             #
# ::dronebl::records [string]                                                 #
#    string="[options]" (optional)                                            #
#    optional switches:                                                       #
#      -active    -- shows only active listings (default)                     #
#      -inactive  -- shows only listings that have expired or been removed    #
#      -all       -- shows listings regardless of active status               #
#      -limit int -- requests a list of up to [int] matches (default: 10)     #
# -- queries the DroneBL for the most recent listings added by your key       #
# -- returns a nested list.  Main list contains one match per line.  Each     #
#    line contains {id ip type listed timestamp}                              #
#                                                                             #
# ::dronebl::classes [string]                                                 #
#    string="classid" (optional)                                              #
# -- grabs the DroneBL ban classes and their descriptions                     #
# -- returns a nested list.  Main list contains one class per line.  Each     #
#    line contains {class description}.  If [classid] is specified, the list  #
#    returned contains only the class with classid [classid].                 #
#                                                                             #
# ::dronebl::key                                                              #
# -- returns your RPC key                                                     #
#                                                                             #
# ::dronebl::lasterror                                                        #
# -- returns the details of the last error sent by the DroneBL service        #
#                                                                             #
# ::dronebl::tabulate list                                                    #
# -- expects a nested list as is returned from ::dronebl::lookup or           #
#    ::dronebl::records                                                       #
# -- returns a simple list where each element is a formatted line suitable    #
#    for human-readable output                                                #
#                                                                             #
# ::dronebl::display list                                                     #
# -- expects a nested list as is returned from ::dronebl::lookup or           #
#    ::dronebl::records                                                       #
# -- outputs the list to the console in tabular format                        #
# -- returns nothing significant                                              #
#                                                                             #
# ::dronebl::args2text string                                                 #
#    string="element [element [element [element...]]]"                        #
# -- returns "element, element, element and element"                          #
#                                                                             #
###############################################################################
#                                                                             #
# Can also be run by command with one of the following commands:              #
# within tclsh: dronebl (args)                                                #
# on an Eggdrop partyline (requires +n access): .dronebl (args)               #
# from a script: ::dronebl::dcc (args)                                        #
#                                                                             #
# args can be any of the following:                                           #
#                                                                             #
# - add [type] host/ip [host/ip [host/ip [host/ip...]]]                       #
#   ... where "type" is optional.  Defaults to ban type 1 (testing class).    #
#                                                                             #
# - lookup [options] addr/range [addr/range [addr/range [addr/range...]]]     #
#   ... where the ip can contain *? wildcards and [1-255] ranges.             #
#   ... optional switches:                                                    #
#      -active    -- shows only active listings (default)                     #
#      -inactive  -- shows only listings that have expired or been removed    #
#      -all       -- shows listings regardless of active status               #
#      -limit int -- requests a list of up to [int] matches (default: 10)     #
#   ... outputs a tabular formatted list of matches                           #
#                                                                             #
# - records [options]                                                         #
#   ... queries the DroneBL for the most recent listings added by your key    #
#   ... optional switches:                                                    #
#      -active    -- shows only active listings (default)                     #
#      -inactive  -- shows only listings that have expired or been removed    #
#      -all       -- shows listings regardless of active status               #
#      -limit int -- requests a list of up to [int] matches (default: 10)     #
#   ... outputs a tabular formatted list of matches                           #
#                                                                             #
# - classes [classid]                                                         #
#   ... queries the DroneBL to show ban classes and their descriptions.       #
#   ... defaults to showing all classes unless [classid] is specified.        #
#                                                                             #
# - key                                                                       #
#   ... shows the value set for $::dronebl::rpckey                            #
#                                                                             #
###############################################################################

# for portability, simulate eggdrop procs and junk
if {![llength [info commands putlog]]} {
	proc putlog {what} {
		# convert IRC ctrl codes to ANSI esc codes
		array set fgcolors {00 37 01 30 02 34 03 32 04 31 05 33 06 35 07 33 08 33 09 32 10 36 11 36 12 34 13 31 14 37 15 37}
		array set bgcolors {00 47 01 40 02 44 03 42 04 41 05 43 06 45 07 43 08 43 09 42 10 46 11 46 12 44 13 41 14 47 15 47}
		while {[regexp {(\002|\003|\026|\037)} $what]} {
			# underline
			set what [regsub {\037} $what "\x1b\[4m"]
			set what [regsub {\037} $what "\x1b\[0m"]
			# reverse
			set what [regsub {\026} $what "\x1b\[7m"]
			set what [regsub {\026} $what "\x1b\[0m"]
			# bold
			set what [regsub {\002} $what "\x1b\[1m"]
			set what [regsub {\002} $what "\x1b\[0m"]
			# color
			if {[regexp {\003([0-9]{1,2}),([0-9]{1,2})} $what full fg bg]} {
				if {[string length $fg] < 2} {set fg "0$fg"}
				if {[string length $bg] < 2} {set bg "0$bg"}
				set what [regsub $full $what "\x1b\[$fgcolors($fg)m\x1b\[$bgcolors($bg)m"]
			} elseif {[regexp {\003([0-9]{1,2})} $what full fg]} {
				if {[string length $fg] < 2} {set fg "0$fg"}
				set what [regsub $full $what "\x1b\[$fgcolors($fg)m"]
			} elseif {[string match "*\003*" $what]} {
				set what [regsub {\003} $what "\x1b\[0m"]
			}
		}
		puts $what
	}
}
if {![llength [info commands utimer]]} { proc utimer {secs what args} { after [expr $secs * 1000] [eval $what $args]; return } }
if {![llength [info commands bind]]} { proc bind {bindtype userlevel trigger args} { eval "proc $trigger {args} { $args \$args }"; return } }
# end of compatibility

# prefer ::dns::resolve from tcllib over eggdrop's dnslookup
if {[catch {package require dns} 0]} {
	if {[llength [info commands dnslookup]]} {
		putlog "The DNS resolver in tcllib can return multiple IPs when a host has a round-robin array of IP addresses.  Consider installing tcllib and libudp-tcl.  Using Eggdrop's dnslookup as a failsafe for now."
		proc iplookup {what cmd args} {dnslookup $what $cmd $args}
	} else {
		putlog "No DNS resolver found.  Install tcllib and libudp-tcl."
		return
	}
} else {
	proc iplookup {what cmd args} {
		set tok [dns::resolve $what]
		while {[dns::status $tok] == "connect"} { dns::wait $tok }
		if {[dns::status $tok] == "ok"} {
			set ip [dns::address $tok]
			$cmd $ip $what 1 $args
		} else {
			::dronebl::lasterror [dns::error $tok]
			set ip 0
			$cmd $ip $what 0 $args
		}
		dns::cleanup $tok
		return $ip
	}
}

namespace eval dronebl {

# returns value set for $rpckey
proc key {} {
	if {![info exists [namespace current]::rpckey]} {
		return false
	}
	namespace upvar [namespace current] rpckey key
	return $key
}

# prepares ::http::config headers
proc setHTTPheaders {} {
	global version
	if {![info exists version]} {
		set http [::http::config -useragent "TCL [info patchlevel] HTTP library"]
	} else {
		set http [::http::config -useragent "Eggdrop $version / TCL [info patchlevel] HTTP library"]
	}
	return true
}

# performs DNS lookup if necessary and returns an IP
proc host2ip {ip {host 0} {status 0} {attempt 0}} {
	if {$ip == ""} {
		return 0
	} elseif {[regexp {^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}} $ip]} {
		return $ip
	} elseif { $attempt > 2 } {
		[namespace current]::lasterror "Unable to resolve $ip."
		return 0
	} else {
		iplookup $ip [namespace current]::host2ip [incr attempt]
	}
}

# performs a connection to the DroneBL RPC2 service and returns the response
proc talk { query } {
	[namespace current]::setHTTPheaders
	::http::register https 443 tls::socket
	set http [::http::geturl "https://dronebl.org/rpc2" -type "text/xml" -query $query]
	set data [::http::data $http]
	::http::unregister https
	return $data
}

# keeps track of the last error
proc lasterror {args} {
	global [namespace current]::err
	if {![info exists [namespace current]::err]} { set [namespace current]::err "" }
	if {$args != ""} { set [namespace current]::err $args }
	namespace upvar [namespace current] err _err
	return [concat $_err]
}

# parses DroneBL response for errors; returns true if none, false if errors found + populates lasterror
proc checkerrors {args} {
	if {[string match "*success*" $args]} {
		return true
	} else {
		if {[regexp {<code>(.+)</code>.+<message>(.+)</message>} $args - code message]} {
			set err "$code $message"
		} else {
			set err $args
		}
		[namespace current]::lasterror $err
		return false
	}
}

# generates query for submitting a host / IP to the DroneBL service
proc submit { hosts } {
	set key [[namespace current]::key]
	if {$key == ""} { return false }

	set query "<?xml version=\"1.0\"?>
<request key=\"$key\">"

	set bantype {type="1"}
	set hosts [split $hosts]
	if {[string is integer -strict [lindex $hosts 0]]} {
		set bantype "type=\"[lindex $hosts 0]\""
		set hosts [lreplace $hosts 0 0]
	}

	foreach host $hosts {

		if {[set ip [[namespace current]::host2ip $host]] == 0} { return false }

		foreach ip1 [split $ip] {
			set query "$query
	<add ip=\"$ip1\" $bantype />"
		}

	}

	set query "$query
</request>"

	return [[namespace current]::checkerrors [[namespace current]::talk $query]]
}

# generates query for setting an IP inactive in the DroneBL service
proc remove { ids } {
	set key [[namespace current]::key]
	if {$key == ""} { return false }

	set query "<?xml version=\"1.0\"?>
<request key=\"$key\">"

	foreach id [split $ids] {

		if {![string is integer -strict $id]} { [namespace current]::lasterror "$id is not an integer."; return false }

		set query "$query
	<remove id=\"$id\" />"

	}

	set query "$query
</request>"

	return [[namespace current]::checkerrors [[namespace current]::talk $query]]
}

# turns raw XML response from DroneBL into a list
proc listify { raw } {

	if {![[namespace current]::checkerrors $raw]} { return false }

	set res [regexp -linestop -inline -all {.+} $raw]
	set table {{ID IP {Ban type} Listed Timestamp}}

	foreach line $res {
		if {[regexp {ip="([^"]+)".+type="([^"]+)".+id="([^"]+)".+listed="([^"]+)".+timestamp="([^"]+)"} $line - ip type id listed timestamp]} {

			lappend table [list $id $ip $type $listed [clock format $timestamp -format {%Y.%m.%d %H:%M:%S}]]

		} elseif {[string match {<response type="success" />} $line]} {

			return {{{No matches.}}}

		}
	}

	return $table
}

# converts args to something more user friendly, inserting commas and "and" where appropriate
proc args2text { lst } {
	switch [llength $lst] {
		1 {
			return "\002$lst\002"
		}
		2 {
			set lst [join $lst "\002 and \002"]
			return "\002$lst\002"
		}
		default {
			set firstbunch [join [lreplace $lst end end] "\002, \002"]
			return "\002$firstbunch\002 and \002[lindex $lst end]\002"
		}
	}
}

# justifies table cells.  input: nested list; returns: simple list with each row justified into an aligned table row
proc tabulate { lst } {
	foreach row $lst {
		for {set i 0} {$i < [llength $row]} {incr i} {
			set col [lindex $row $i]
			if {![info exists width($i)] || $width($i) < [string length $col]} { set width($i) [string length $col] }
		}
	}
	for {set i 0} {$i < [llength $lst]} {incr i} {
		set row [lindex $lst $i]
		for {set j 0} {$j < [llength $row]} {incr j} {
			set col [lindex $row $j]
			while {[string length $col] < $width($j)} { set col "$col " }
			set row [lreplace $row $j $j $col]
		}
		set row [join $row " | "]
		set lst [lreplace $lst $i $i $row]
	}
	return $lst
}

# displays a table.  input: nested list; output: table of the data; returns: nothing
proc display { lst } {

	set rows [[namespace current]::tabulate $lst]
	for {set i 0} {$i < [llength $rows]} {incr i} {
		set row [lindex $rows $i]
		if {!$i && [llength $rows] > 1} { set row "\002\037$row\037\002" }
		putlog $row
	}
	return
}

# returns a nested list of matches where $ip is listed in the DroneBL
proc lookup { ips } {

	set key [[namespace current]::key]
	if {$key == ""} { return false }

	set switches [lsearch -all -regexp -inline $ips {^-+.*}]

	set listed {listed="1"}

	set limit {limit="10"}

	foreach thingy $switches {
		switch -regexp [string tolower $thingy] {
			-+active {
				set listed {listed="1"}
			}
			-+(u|i)n.+ {
				set listed {listed="0"}
			}
			-+.*(all|any) {
				set listed {listed="2"}
			}
			-+limit {
				if {[llength $ips] == 1} { set ips [split $ips] }
				set idx [expr [lsearch -exact $ips $thingy] + 1]
				set arg [lindex $ips $idx]
				if {[string is integer -strict $arg]} {
					set limit "limit=\"$arg\""
					set ips [lreplace $ips $idx $idx]
				}
				set ips [join $ips]
			}
		}
	}

	set query "<?xml version=\"1.0\"?>
<request key=\"$key\">"

	foreach ip [split $ips] {

		if {[lsearch -exact $switches $ip] != -1} { continue }

		if {[regexp -nocase {[a-z]} $ip] && [set ip [[namespace current]::host2ip $ip]] == 0} { return false }

		if {[string is integer -strict $ip]} {

			set query "$query
	<lookup id=\"$ip\" />"

		} else {

			foreach ip1 [split $ip] {

				set query "$query
	<lookup ip=\"$ip1\" $limit $listed />"

			}
		}

	}

	set query "$query
</request>"

	[namespace current]::setHTTPheaders
	return [[namespace current]::listify [[namespace current]::talk $query]]
}

# returns a nested list of records submitted via your RPC key
proc records {{txt ""}} {
	set key [[namespace current]::key]
	if {$key == ""} { return }

	set switches [lsearch -all -regexp -inline $txt {^-+.*}]

	set listed {listed="1"}

	set limit {limit="10"}

	foreach thingy $switches {
		switch -regexp [string tolower $thingy] {
			-+active {
				set listed {listed="1"}
			}
			-+(u|i)n.+ {
				set listed {listed="0"}
			}
			-+.*(all|any) {
				set listed {listed="2"}
			}
			-+limit {
				if {[llength $txt] == 1} { set txt [split $txt] }
				set idx [expr [lsearch -exact $txt $thingy] + 1]
				set arg [lindex $txt $idx]
				if {[string is integer -strict $arg]} {
					set limit "limit=\"$arg\""
					set txt [lreplace $txt $idx $idx]
				}
				set txt [join $txt]
			}
		}
	}


	set query "<?xml version=\"1.0\"?>
<request key=\"$key\">
	<records $listed $limit />
</request>"

	[namespace current]::setHTTPheaders
	return [[namespace current]::listify [[namespace current]::talk $query]]
}

# returns a nested list of {Class Description} {1 {Testing class.}} {2 {Sample data...}} etc.
proc classes {{txt ""}} {
	[namespace current]::setHTTPheaders
	::http::register https 443 tls::socket
	set http [::http::geturl "https://dronebl.org/classes?format=txt"]
	set data [::http::data $http]
	::http::unregister https
	set res [regexp -linestop -inline -all {.+} [::http::data $http]]

	set classlist {{Class Description}}

	foreach line $res {
		set words [split $line]
		set firstword [lindex $words 0]
		set words [join [lreplace $words 0 0]]
		if {$txt == "" || [lsearch [split $txt] $firstword] != -1} {
			lappend classlist [list $firstword $words]
		}
	}
	return $classlist
}

# user interface; proc bound to dcc / "dronebl" command
proc dcc { {hand nobody} {idx 0} {txt ""} } {
	if {!$idx && $txt == ""} { set txt $hand }
	set args [split [string tolower $txt]]
	switch -regexp [lindex $args 0] {
		(add|submit|insert) {
			set args [lreplace $args 0 0]
			if {[string is integer -strict [lindex $args 0]]} { set bantype [lindex $args 0] }
			if {[[namespace current]::submit $args]} {
				if {[info exists bantype]} {
					set args [lreplace $args 0 0]
				} else {
					set bantype 1
				}
				putlog "Success submitting [[namespace current]::args2text $args] to DroneBL as type \002$bantype\002."
			} else {
				putlog [[namespace current]::lasterror]
			}
			return
		}
		(remove|deactivate|delist|delete|unlist|del) {
			set args [lreplace $args 0 0]
			if {[[namespace current]::remove $args]} {
				set query [[namespace current]::lookup $args]
				[namespace current]::display $query
			} else {
				putlog [[namespace current]::lasterror]
			}
			return
		}
		(query|lookup|search|list|show|find) {
			set args [lreplace $args 0 0]
			if {[set query [[namespace current]::lookup $args]] == "false"} {
				putlog [[namespace current]::lasterror]
			} else {
				[namespace current]::display $query
			}
			return
		}
		class(es)? {
			set args [lreplace $args 0 0]
			if {[set query [[namespace current]::classes $args]] == "false"} {
				putlog [[namespace current]::lasterror]
			} else {
				[namespace current]::display $query
			}
			return
		}
		records {
			set args [lreplace $args 0 0]
			if {[set query [[namespace current]::records $args]] == "false"} {
				putlog [[namespace current]::lasterror]
			} else {
				[namespace current]::display $query
			}
			return
		}
		key {
			putlog "DroneBL RPC Key: [[namespace current]::key]"
			return
		}
		default {
			set output "
Usage: .dronebl command args

Commands:
\002add\002 \[type\] \002host/ip\002 \[host/ip \[host/ip \[host/ip...\]\]\]
   ... where \"type\" is optional.  Defaults to ban type 1 (testing class).

\002lookup\002 \[options\] \002addr/range\002 \[addr/range \[addr/range \[addr/range...\]\]\]
   ... where the ip can contain *? wildcards and \[1-255\] ranges.
   ... optional switches:
      -active    -- shows only active listings (default)
      -inactive  -- shows only listings that have expired or been removed
      -all       -- shows listings regardless of active status
      -limit int -- requests a list of up to \[int\] matches (default: 10)
   ... outputs a tabular formatted list of matches

\002records\002 \[options\]
   ... queries the DroneBL for the most recent listings added by your key
   ... optional switches:
      -active    -- shows only active listings (default)
      -inactive  -- shows only listings that have expired or been removed
      -all       -- shows listings regardless of active status
      -limit int -- requests a list of up to \[int\] matches (default: 10)
   ... outputs a tabular formatted list of matches

\002classes\002 \[classid\]
   ... queries the DroneBL to show ban classes and their descriptions.
   ... defaults to showing all classes unless \[classid\] is specified.

\002key\002
   ... shows the value set for \$::dronebl::rpckey
"
			foreach line [split $output "\n"] { putlog $line }
		}
	}
}

# runs on script load
proc init {} {
	set key [[namespace current]::key]
	if {$key == ""} { return }

	set query "<?xml version=\"1.0\"?>
<request key=\"$key\">
</request>"

	[namespace current]::setHTTPheaders
	set res [[namespace current]::talk $query]

	if {[regexp -nocase "success" $res]} {
		bind dcc n dronebl [namespace current]::dcc
		putlog "DroneBL library loaded.  RPCKey is valid."
	} else {
		package forget dronebl
		putlog "DroneBL RPCKey validation vailed.  Library not loaded."
	}
}

# break init out in a timer so vwait in ::http doesn't cause eggdrop to choke and puke
utimer 0 [namespace current]::init

}; # end namespace declaration
