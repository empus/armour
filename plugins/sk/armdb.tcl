# -- Armour sqlite DB functions
#
# Empus <empus@undernet.org>
#
# .... should have done this a long time ago!
#
# --



namespace eval armdb {

# -- database file location
# -- now load from config file
#set cfg(file) "./armour/db/sql/userdb.sqldb"

# -- load sqlite (or at least try)
if {[catch {package require sqlite3} fail]} {
	putlog "\[@\] error loading sqlite3 library.  unable to load Armour SQL DB functions."
	return false
}

# -- db connect
proc db_connect {} { sqlite3 armsql $::userdb(sqlite) }
# -- escape chars
proc db_escape {what} { return [string map {' ''} $what] }
proc db_last_rowid {} { armsql last_insert_rowid }

# -- query abstract
proc db_query {query} {
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
proc db_close {} { armsql close }

# -- connect attempt
if {[catch {db_connect} fail]} {
	putlog "\[@\] unable to create sqlite database.  check directory permissions."
	return false
}

# ---- create the tables

			
# -- user database
# U:id:user:xuser:level:curnick:curhost:lastnick:lasthost:lastseen:automode:pass:email:languages
db_query "CREATE TABLE IF NOT EXISTS users (\
			id INTEGER PRIMARY KEY AUTOINCREMENT,\
			user TEXT NOT NULL,\
			xuser TEXT,\
			level INTEGER NOT NULL,\
			email TEXT,\
			curnick TEXT,\
			curhost TEXT,\
			lastnick TEXT,\
			lasthost TEXT,\
			lastseen INTEGER,\
			automode INT NOT NULL DEFAULT 0,\
			languages TEXT NOT NULL DEFAULT 'EN',\
			pass TEXT NOT NULL\
			)"
			
# -- blacklist & whitelist entries
# list:id:type:value:timestamp:modifby:action:limit:hits:reason			
db_query "CREATE TABLE IF NOT EXISTS entries (\
			id INTEGER PRIMARY KEY AUTOINCREMENT,\
			list TEXT NOT NULL,\
			type TEXT NOT NULL,\
			value TEXT NOT NULL,\
			timestamp INT NOT NULL,\
			modifby TEXT NOT NULL,\
			action TEXT NOT NULL,\
			'limit' TEXT NOT NULL DEFAULT '1-1-1',\
			hits TEXT NOT NULL DEFAULT 0,\
			reason INTEGER NOT NULL\
			)"

# -- IDB (information database)
db_query "CREATE TABLE IF NOT EXISTS idb (\
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
db_query "CREATE TABLE IF NOT EXISTS notes (\
			id INTEGER PRIMARY KEY AUTOINCREMENT,\
			timestamp INTEGER NOT NULL,\
			from_u TEXT NOT NULL,\
			from_id INTEGER NOT NULL,\
			to_u TEXT NOT NULL,\
			to_id INTEGER NOT NULL,\
			note TEXT NOT NULL,\
			read TEXT NOT NULL DEFAULT 'N'\
			)"
			
# -- topics
# -- list of pre-set channel topics
db_query "CREATE TABLE IF NOT EXISTS topics (\
			id INTEGER PRIMARY KEY AUTOINCREMENT,\
			topic TEXT NOT NULL\
			)"


# -- generic command history log
db_query "CREATE TABLE IF NOT EXISTS cmdlog (\
			timestamp INTEGER,\
			source TEXT NOT NULL,\
			user TEXT NOT NULL,\
			user_id INTEGER,\
			command TEXT NOT NULL,\
			params TEXT,\
			bywho TEXT,\
			target TEXT,\
			target_xuser TEXT,\
			wait INTEGER\
			)"
			
db_close
			
}
