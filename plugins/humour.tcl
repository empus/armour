# ------------------------------------------------------------------------------------------------
# Humour API Commands - humorapi.com
# ------------------------------------------------------------------------------------------------
#
# Commands:
#
#   meme <query>            - fetch a random meme
#   gif <query>             - fetch a random gif
#   praise <nick> <reason>  - praise a nick
#   insult <nick> <reason>  - insult a nick
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# -- API configuration (noreg queries)
set cfg(humour:key) "cd2e8c2aa0a249429d9f7354b149d542";  # -- API key

set cfg(humour:allow) 3;    # -- who can use commands? (1-4)
                            #        1: all channel users
                            #        2: only voiced, opped, and authed users
                            #        3: only opped and authed channel users
                            #        4: only authed users   

set addcmd(meme)    {  arm       1          pub msg dcc  }; # -- requires humour plugin
set addcmd(gif)     {  arm       1          pub msg dcc  }; # -- requires humour plugin
set addcmd(praise)  {  arm       1          pub msg dcc  }; # -- requires humour plugin
set addcmd(insult)  {  arm       1          pub msg dcc  }; # -- requires humour plugin

# ------------------------------------------------------------------------------------------------
# -- binds

# -- prerequisite packages
package require json
package require http
package require tls

set cfg(humour:timeout) "5"; # -- http query timeout (secs)

# -- fetch meme
proc arm:cmd:meme {0 1 2 3 {4 ""} {5 ""}} {
    humour:cmd meme $0 $1 $2 $3 $4 $5
}

# -- fetch gif
proc arm:cmd:gif {0 1 2 3 {4 ""} {5 ""}} {
    humour:cmd gif $0 $1 $2 $3 $4 $5
}

# -- praise a nick
proc arm:cmd:praise {0 1 2 3 {4 ""} {5 ""}} {
    humour:cmd praise $0 $1 $2 $3 $4 $5
}

# -- insult a nick
proc arm:cmd:insult {0 1 2 3 {4 ""} {5 ""}} {
    humour:cmd insult $0 $1 $2 $3 $4 $5
}

# -- abstraction for all commands
proc humour:cmd {cmd 0 1 2 3 {4 ""} {5 ""}} {
    variable dbchans
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    lassign [db:get id,user users curnick $nick] uid user
    if {[string index [lindex $arg 0] 0] eq "#"} { set chan [lindex $arg 0] } \
    else { set chan [userdb:get:chan $user $chan] }; # -- predict chan when not given

    set cid [db:get id channels chan $chan]
    #if {$cid eq ""} { set cid 1 }; # -- default to global chan when command used in an unregistered chan

    set ison [arm::db:get value settings setting "humour" cid $cid]
    if {$ison ne "on"} {
        # -- humour not enabled on chan
        debug 1 "\002humour:cmd:\002 humour not enabled on $chan. to enable, use: \002modchan $chan humour on\002"
        return;
    }

    # -- ensure user has required access for command
	set allowed [cfg:get humour:allow]; # -- who can use commands? (1-5)
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

    # -- check for errors
    if {$cmd eq "meme"} {
        # -- fetching a meme 
        set list [list keywords [lindex $arg 0]]

    } elseif {$cmd eq "gif"} {
        # -- fetching a gif 
        set query [lrange $arg 0 end]
        if {$query eq ""} {
            reply $type $target "\002usage:\002 gif <query>"
            return;
        }
        set list [list query $query]

    } elseif {$cmd eq "praise" || $cmd eq "insult"} {
        # -- issuring praise or an insult
        set tnick [lindex $arg 0]
        set reason [lrange $arg 1 end]
        if {$tnick eq "" || $reason eq ""} {
            reply $type $target "\002usage:\002 cmd <nick> <reason>"
            return;
        }
        set list [list name $tnick reason $reason]

    } else { return; }; # -- safety net

    lassign [humour:http:query $cmd $list] iserror response
    if {$iserror eq 1} { 
        reply $type $target "\002error:\002 $response"
        return; 
    }

    # -- response
    if {$cmd eq "gif"} {
        set length [llength $response]; set rand [rand $length]
        set random [lindex $response $rand]
        set response [dict get $random url]
    }
    if {$cmd in "praise insult"} {
        reply $type $target "$response"
    } else {
        reply $type $target "\002$cmd:\002 $response"
    }
}

proc humour:http:query {type params} {
    variable cfg; # -- config vars
    
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]

    set timeout [expr [cfg:get humour:timeout] * 1000]; # -- config var is in seconds

    if {$type eq "meme"} {

        set url "https://api.humorapi.com/memes/random"
        if {[dict exists $params keywords]} {
            set keywords [dict get $params keywords]
        } else { set keywords "" }
        set query [http::formatQuery api-key [cfg:get humour:key] keywords $keywords]
        set url "$url?$query"

        catch { set tok [http::geturl $url -method GET -timeout $timeout] } error
        debug 0 "humour::http:query: error: $error"
        set iserror [humour:http:errors $url $tok $error]
        if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
        set data [http::data $tok]
        http::cleanup $tok
        debug 0 "\002humour::http:query:\002 API data: $data"

        # -- process data
        set json [json::json2dict $data]

        # -- example response
        # {
        #     "id": 50561,
        #     "url": "https://preview.redd.it/hg0zn2mhjsh01.png?width=640&crop=smart&auto=webp&s=f19b0a87edfc6c71b35ec9aceb64799cd532ff59",
        #     "type": "image/png"
        # }

        if {![dict exists $json id]} {
            # -- error
            set message [dict get $json message]
            return "1 [list $message]"
        }

        set id [dict get $json id]
        set description [dict get $json description]
        set url [dict get $$json url]
        set type [dict get $json type]

        return "0 [list $url $description]"

    } elseif {$type eq "gif"} {

        set url "https://api.humorapi.com/gif/search"
        set query [http::formatQuery api-key [cfg:get humour:key] query [dict get $params query]]
        set url "$url?$query"

        catch { set tok [http::geturl $url -method GET -timeout $timeout] } error
        debug 0 "humour::http:query: error: $error"
        set iserror [humour:http:errors $url $tok $error]
        if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
        set data [http::data $tok]
        http::cleanup $tok
        debug 0 "\002humour::http:query:\002 API data: $data"

        # -- process data
        set json [json::json2dict $data]

        if {![dict exists $json images]} {
            # -- error
            return "1 [list "no results returned."]"
        }

        return "0 [list [dict get $json images]]"

    } elseif {$type in "praise insult"} {

        set url "https://api.humorapi.com/$type"
        set query [http::formatQuery api-key [cfg:get humour:key] name [dict get $params name] reason [dict get $params reason]]
        set url "$url?$query"

        catch { set tok [http::geturl $url -method GET -timeout $timeout] } error
        debug 0 "humour::http:query: error: $error"
        set iserror [humour:http:errors $url $tok $error]
        if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
        set data [http::data $tok]
        http::cleanup $tok
        debug 0 "\002humour::http:query:\002 API data: $data"

        # -- process data
        set json [json::json2dict $data]

        if {![dict exists $json text]} {
            # -- error
            return "1 [list "no results returned."]"
        }

        return "0 [list [dict get $json text]]"

    }
}


# -- abstraction to check for HTTP errors
proc humour:http:errors {url tok error} {
    debug 0 "\002humour::http:errors:\002 checking for errors...(error: $error)"
    if {[string match -nocase "*couldn't open socket*" $error]} {
        debug 0 "\002humour::http:errors:\002 could not open socket to $url."
        http::cleanup $tok
        return "1 socket"
    } 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002humour::http:errors:\002 connection to $url has timed out."
        http::cleanup $tok
        return "1 timeout"
    } elseif {$status eq "error"} {
        debug 0 "\002humour::http:errors:\002 connection to $url has error."
        http::cleanup $tok
        return "1 connection"
    }
}

loadcmds; # -- reload the available commands
debug 0 "\002\[A\]\002 Loaded Humour API commands (meme gif)"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------
