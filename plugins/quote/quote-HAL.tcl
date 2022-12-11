# -- HAL quote import function
# -- for quote plugin for Armour
# -- Empus <empus@undernet.org>

# file format is specific where each quote is across two lines:

# <timestamp>
# <nick> 1 <quote>

# -- load script to bot after editing the below file name
set file "./armour/plugins/quote/quotes-HAL.txt"

proc quote:db:load {} {
	global file
	set fd [open $file r]
	set data [read $fd]
	set lines [split $data \n]
	::quotedb::db_connect
	set count 0
	foreach line $lines {
		putlog "quote:db:load: line: $line"
		if {[regexp -- {^(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)\s+.*\[\d*/\d*\]\s<(\w+)>\s(.+)$} $line -> ts user quote]} { 
			set ts [clock scan $ts]
			set dbuhost "user@host"
			set dbnick [::quotedb::db_escape $user]
			set dbquote [::quotedb::db_escape "<$dbnick> $quote"]
			putlog "quote:db:load: inserting: count: $count nick: $dbnick timestamp: $ts quote: $dbquote"
			set query "INSERT INTO quotes (nick,uhost,timestamp,quote) \
					VALUES ('$dbnick','$dbuhost','$ts','$dbquote')"
			set res [::quotedb::db_query $query]
			incr count
		}

	}
	::quotedb::db_close	
	putlog "quote:db:load: loaded $count quotes into db."
}

putlog "\[@\] loaded HAL quote-ts loader"
