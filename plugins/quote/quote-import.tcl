# -- quote import function
# -- for quote plugin for Armour
# -- Empus <empus@undernet.org>

# file format is specific where each quote is across two lines:

# <timestamp>
# <nick> 1 <quote>

# -- load script to bot after editing the below file name
set file "./armour/plugins/quote/quotes.txt"

proc quote:db:load {} {
	global file
	set fd [open $file r]
	set data [read $fd]
	set lines [split $data \n]
	::quotedb::db_connect
	set count 0
	foreach line $lines {
		set line [split $line]
		#3putlog "quote:db:load: line: $line"
		if {[regexp -- {^\d+$} [lindex $line 0]]} { 
			set ts [lindex $line 0]
			continue;
		} else {
			incr count
			set dbnick [::quotedb::db_escape [join [lindex $line 0]]]
			#putlog "dbnick: $dbnick"
			set dbuhost "user@host"
			set dbquote [::quotedb::db_escape [join [lrange $line 2 end]]]
			putlog "quote:db:load: inserting: count: $count nick: $dbnick timestamp: $ts quote: $dbquote"
			set query "INSERT INTO quotes (nick,uhost,timestamp,quote) \
					VALUES ('$dbnick','$dbuhost','$ts','$dbquote')"
			set res [::quotedb::db_query $query]
		}
	}
	::quotedb::db_close	
	putlog "quote:db:load: loaded $count quotes into db."
}

putlog "\[@\] loaded quote-ts loader"
