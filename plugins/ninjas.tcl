# ------------------------------------------------------------------------------------------------
# API Ninjas
# ------------------------------------------------------------------------------------------------
#
# A collection of fun commands from api-ninjas.com API
#
# ------------------------------------------------------------------------------------------------
#
# Usage: 
#
# ------------------------------------------------------------------------------------------------
#
# Examples:
# 
#     joke
#     dad
#     history
#     fact
#     chuck
#     cocktail <name>
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

package require json
package require http 2
package require tls 1.7

# -- fetch random joke
proc arm:cmd:joke {0 1 2 3 {4 ""} {5 ""}} {
    ninjas:cmd joke $0 $1 $2 $3 $4 $5
}

# -- fetch random dad joke
proc arm:cmd:dad {0 1 2 3 {4 ""} {5 ""}} {
    ninjas:cmd dad $0 $1 $2 $3 $4 $5
}

# -- fetch random fact
proc arm:cmd:fact {0 1 2 3 {4 ""} {5 ""}} {
    ninjas:cmd fact $0 $1 $2 $3 $4 $5
}

# -- fetch interesting event that occurred on a date
proc arm:cmd:history {0 1 2 3 {4 ""} {5 ""}} {
    ninjas:cmd history $0 $1 $2 $3 $4 $5
}

# -- fetch random Chuck Norris joke
proc arm:cmd:chuck {0 1 2 3 {4 ""} {5 ""}} {
    ninjas:cmd chuck $0 $1 $2 $3 $4 $5
}

# -- fetch cocktails
proc arm:cmd:cocktail {0 1 2 3 {4 ""} {5 ""}} {
    ninjas:cmd cocktail $0 $1 $2 $3 $4 $5
}


# -- abstraction for all commands
proc ninjas:cmd {cmd 0 1 2 3 {4 ""} {5 ""}} {
    variable dbchans
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    lassign [db:get id,user users curnick $nick] uid user
    if {[string index [lindex $arg 0] 0] eq "#"} { set chan [lindex $arg 0] } \
    else { set chan [userdb:get:chan $user $chan] }; # -- predict chan when not given

    set cid [db:get id channels chan $chan]
    #if {$cid eq ""} { set cid 1 }; # -- default to global chan when command used in an unregistered chan

    set ison [arm::db:get value settings setting "ninjas" cid $cid]
    if {$ison ne "on"} {
        # -- ninjas not enabled on chan
        debug 1 "\002ninjas:cmd:\002 ninjas not enabled on $chan. to enable, use: \002modchan $chan ninjas on\002"
        return;
    }

    # -- ensure user has required access for command
	set allowed [cfg:get ninjas:allow]; # -- who can use commands? (1-5)
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
    
    set cmd [string tolower $cmd]

    if {$cmd in "history cocktail"} {
        set dict [list text [lrange $arg 0 end]]
    } else { set dict "" }
    set text [lindex $dict 1]

    if {$cmd eq "cocktail" && $text eq ""} {
        reply $type $target "\002error:\002 usage: cocktail <name>"
        return;
    }

    # -- check for errors
    lassign [ninjas:query $cmd $dict] iserror response
    if {$iserror eq 1} { 
        reply $type $target "\002error:\002 $response"
        return; 
    }


    if {$cmd eq "history"} {
        if {$text eq ""} { 
            set response "$nick: today in history (\002[dict get $response year]-[dict get $response month]-[dict get $response day]\002): [dict get $response event]"
        } else {
            set response "$nick: in history on \002[dict get $response year]-[dict get $response month]-[dict get $response day]\002: [dict get $response event]"
        }
    } elseif {$cmd eq "cocktail"} {
        #putlog "dict: $response -- length: [llength $response] -- rand: [expr [llength $response] - 1]"
        set length [expr [llength $response] - 1]
        if {$length eq 0} { set rand 0 } else { set rand [rand $length]}
        set dict [lindex $response $rand]; # -- return a random cocklist from the list
        #putlog "dict now: $dict"
        set ingredients [join [dict get $dict ingredients] ", "]
        reply $type $target "$nick: \002[dict get $dict name]:\002 $ingredients"
        reply $type $target "$nick: [dict get $dict instructions]"
        return;
    } else { set response "$nick: $response" }

    reply $type $target $response;

}

# -- send API query
proc ninjas:query {cmd {dict ""}} {

    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]

    #set query [http::formatQuery categories $categories difficulties $difficulty limit $limit]
    #query query ""
    if {$cmd eq "joke"} {
        # -- fetch random joke
        set url "https://api.api-ninjas.com/v1/dadjokes"
    } elseif {$cmd eq "dad"} {
        # -- fetch dad joke
        set url "https://api.api-ninjas.com/v1/dadjokes"  
    } elseif {$cmd eq "fact"} {
        # -- fetch random fact
        set url "https://api.api-ninjas.com/v1/facts"  
    } elseif {$cmd eq "chuck"} {
        # -- fetch random Chuck Norris joke
        set url "https://api.api-ninjas.com/v1/chucknorris"
    } elseif {$cmd eq "history"} {
        # -- fetch interesting event from history
        set url "https://api.api-ninjas.com/v1/historicalevents"
        set unixtime [clock seconds]
        set year [clock format $unixtime -format "%Y"]
        set month [clock format $unixtime -format "%m"]
        set day [clock format $unixtime -format "%d"]
        if {[join [lindex $dict 1]] ne ""} {
            # -- find historical events by description
            set query [::http::formatQuery text "[join [dict get $dict text]]"]
        } else {
            # -- find historical events by day
            set query [::http::formatQuery month $month day $day]
        }
        set url "$url?$query"
    } elseif {$cmd eq "time"} {
        # -- fetch worldtime
        set city [dict get $dict city]
        set url "https://api.api-ninjas.com/v1/worldtime?city=$city"
    } elseif {$cmd eq "cocktail"} {
        set query [::http::formatQuery name "[join [dict get $dict text]]"]
        set url "https://api.api-ninjas.com/v1/cocktail"
        set url "$url?$query"
    }

    catch {set tok [http::geturl $url \
        -method GET \
        -headers [list "X-Api-Key" [cfg:get ninjas:key]] \
        -timeout 5000 -keepalive 0]} error

    # -- connection handling abstraction
    set iserror [ninjas:errors $url $tok $error]
    if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
    
    set output [http::data $tok]
    #debug 3 "\002ninjas:query: API response:\002 $output"
    http::cleanup $tok

    # -- check for error message in JSON response
    if {$cmd in "joke dad fact"} {
        set data [join [json::json2dict $output]]
    } elseif {$cmd in "chuck history time cocktail"} {
        set data [json::json2dict $output]
    }
    
    if {$data eq ""} {
        debug 0 "\002ninjas:query:\002 blank JSON response"
        return [list 1 "no returned data."]
    }

    if {$cmd in "joke dad chuck"} {
        set out [dict get $data joke]
    } elseif {$cmd eq "fact"} {
        set out [dict get $data fact]
    } elseif {$cmd eq "history"} {
        set rand [rand [expr [llength $data] - 1]]
        set out [lindex $data $rand]; # -- return random index
    } elseif {$cmd in "time cocktail"} {
        set out $data
    }
    return [list 0 $out]

}


# -- abstraction to check for HTTP errors
proc ninjas:errors {url tok error} {
    debug 0 "\002ninja:errors:\002 checking for errors...(error: $error)"
    if {[string match -nocase "*couldn't open socket*" $error]} {
        debug 0 "\002ninjas:errors:\002 could not open socket to $url."
        http::cleanup $tok
        return "1 socket"
    } 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002ninjas:errors:\002 connection to $url has timed out."
        http::cleanup $tok
        return "1 timeout"
    } elseif {$status eq "error"} {
        debug 0 "\002ninjas:errors:\002 connection to $url has error."
        http::cleanup $tok
        return "1 connection"
    }
}

# ------------------------------------------------------------------------------------------------

putlog "\[@\] Armour: Loaded plugin: ninjas"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------
