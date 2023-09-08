# ------------------------------------------------------------------------------------------------
# OpenAI Plugin - ChatGPT integration
#
# Send requests to OpenAI via 'ask' command, and output answers
#
#   - Continue existing conversations with 'and' command
#   - Set user & channel specific response behaviour with 'askmode' command
#
# ------------------------------------------------------------------------------------------------
#
# Commands: 
#
#   https://armour.bot/cmd/ask
#   https://armour.bot/cmd/and
#   https://armour.bot/cmd/askmode
#
# ------------------------------------------------------------------------------------------------
#
# Examples:
#
#   @Empus | c ask Who won the World Series in 2020?
#   @chief | Empus: Los Angeles Dodgers.
#   @Empus | c and Where was it played?
#   @chief | Empus: The World Series in 2020 was played in Arlington, Texas at the Globe Life Field.
#
#   @Empus | c askmode act like an idiot
#   @chief | done. user-specific ask mode set for #armour. use 'askmode' on its own to clear.
#   @Empus | c ask what is the meaning of life?
#   @chief | Empus: No meaning. Just do stuff. Eat cake.
#
#   @Empus | c askmode
#   @chief | done. user-specific ask mode cleared for #armour.
#
# ------------------------------------------------------------------------------------------------
#
# Natural Conversations:
#
#     - If 'cfg(ask:cmdnick)' is enabled, all queries to the botnick will be sent to ChatGPT
#     - Continuing existing conversations still requires the 'and' prefix
#     - Note this means other Armour commands cannnot be called by botnick prefix
#
#   @Empus | chief: Who won the World Series in 2020?
#   @chief | Empus: Los Angeles Dodgers.
#   @Empus | chief: and where was it played?
#   @chief | Empus: The World Series in 2020 was played in Arlington, Texas at the Globe Life Field.
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------------------------

# -- debug level (0-3) - [1]
set cfg(ask:debug) 3

# ------------------------------------------------------------------------------------------------
package require json
package require http 2
package require tls 1.7

# -- ask a question
proc arm:cmd:ask {0 1 2 3 {4 ""}  {5 ""}} {
    variable ask
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    set cmd "ask"

    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]; # -- predict chan when not given

    set cid [db:get id channels chan $chan]
    putlog "chan: $chan -- cid: $cid -- uid: $uid"
    if {$cid eq ""} { set cid 1 }; # -- default to global chan when command used in an unregistered chan

    set ison [arm::db:get value settings setting "openai" cid $cid]
    if {$ison ne "on"} {
        # -- openai plugin not enabled on chan
        debug 0 "\002cmd:ask:\002 openai not enabled on $chan"
        return;
    }

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} {
        # -- check if opped
        if {$chan ne "*" && (![isop $nick $chan] || [cfg:get ask:ops *] eq 0)} {
            return;
        }
    }
    
    set what $arg

    if {$what eq ""} {
        # -- command usage
        reply $type $target "\002usage:\002 ask <question>"
        return;
    }

    debug 0 "\002ask:\002 $nick is asking ChatGPT in $chan: $what"
    set response [ask:query $what 1 [list $cid $uid] $type,[split $nick],$chan]; # -- send query to OpenAI
    putlog "response: $response"
    set iserror [lindex $response 0]
    set response [lrange $response 1 end]

    if {$iserror eq 1} {
        reply $type $target "\002error:\002 $response"
        return;
    }

    regsub -all {"} $response {\\"} eresponse; # -- escape quotes in response
    append ask($type,[split $nick],$chan) ", {\"role\": \"assistant\", \"content\": \"$eresponse\"}"

    regsub -all {\{} $response {"} response; # -- fix curly braces
    regsub -all {\}} $response {"} response; # -- fix curly braces 

    debug 1 "\002cmd:ask:\002: OpenAI answer: $response"
    reply $type $target "$nick: $response"
    
    ask:killtimer $type,[split $nick],$chan; # -- kill any existing ask timer
    timer [cfg:get ask:mem *] "arm::ask:expire $type,[split $nick],$chan"; # -- expire the conversation after N mins

    # -- create log entry for command use
    log:cmdlog BOT * $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- set response behaviour
# usage: askmode ?chan? <description>
proc arm:cmd:askmode {0 1 2 3 {4 ""}  {5 ""}} {
    variable ask
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    set cmd "askmode"
    
    lassign [db:get id,user users curnick $nick] uid user

    # -- check for channel
    set first [lindex $arg 0]; 
    if {[string index $first 0] eq "#"} {
        set chan $first; set askmode [lrange $arg 1 end];
    } elseif {$first eq "*"} {
        set chan "*"; set askmode [lrange $arg 1 end];
    } else {
        set chan [userdb:get:chan $user $chan]; # -- predict chan when not given
        set askmode [lrange $arg 0 end]
    }
    # -- end default proc template

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} {
        # -- check if opped
        if {$chan ne "*" && (![isop $nick $chan] || [cfg:get ask:ops *] eq 0)} {
            return;
        }
    }

    set cid [db:get id channels chan $chan]
    set ison [arm::db:get value settings setting "openai" cid $cid]
    if {$ison ne "on" && $chan ne "*"} {
        # -- openai plugin not enabled on chan
        debug 0 "\002cmd:ask:\002 openai not enabled on $chan"
        return;
    }

    # -- require login
    if {$user eq ""} {
        reply $type $target "\002error:\002 custom \002askmode\002 requires user authentication. use \002login\002"
        return;
    }

    db:connect

    if {$chan eq "*"} { set chantext "as global channel \002default\002" } else { set chantext "for \002$chan\002" }
    set curmode [db:query "SELECT value FROM settings WHERE setting='askmode' AND cid='$cid' AND uid='$uid'"]
    if {$askmode eq ""} {
        # -- user asking to clear askmode
        if {$curmode ne ""} {
            # -- user has existing askmode set for chan
            db:query "DELETE FROM settings WHERE setting='askmode' AND cid='$cid' AND uid='$uid'"
            reply $type $target "done. user-specific ask mode cleared $chantext"
            debug 0 "\002askmode:\002 $nick cleared askmode $chantext"
        } else {
            reply $type $target "\002usage:\002 askmode \[description\]"
            db:close
            return;
        }      
    } else {
        # -- user asking to set askmode
        set escaped [db:escape $askmode]
        if {$curmode eq ""} {
            # -- no existing askmode in db
             db:query "INSERT INTO settings (value,setting,cid,uid) VALUES ('$escaped', 'askmode', $cid, $uid)"
        } else {
            # -- existing askmode in db
            db:query "UPDATE settings SET value='$escaped' WHERE setting='askmode' AND cid='$cid' AND uid='$uid'"
        }
        reply $type $target "done. user-specific ask mode set $chantext. use '\002askmode\002' on its own to clear."
        debug 0 "\002askmode:\002 $nick set askmode $chantext to: $askmode"
    }
    db:close

    # -- create log entry for command use
    set cid [db:get id channels chan $chan]
    log:cmdlog BOT * $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""   

}

# -- continue a conversation
proc arm:cmd:and {0 1 2 3 {4 ""}  {5 ""}} {
    variable ask
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    set cmd "and"

    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]; # -- predict chan when not given

    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} {
        # -- check if opped
        if {$chan ne "*" && (![isop $nick $chan] || [cfg:get ask:ops *] eq 0)} {
            return;
        }
    }
    
    set cid [db:get id channels chan $chan]
    if {$cid eq ""} { set cid 1 }; # -- default to global chan when command sued in unregistered channel

    set ison [arm::db:get value settings setting "openai" cid $cid]
    if {$ison ne "on"} {
        # -- openai plugin not enabled on chan
        debug 0 "\002cmd:ask:\002 openai not enabled on $chan"
        return;
    }

    set what $arg

    if {$what eq ""} {
        # -- command usage
        reply $type $target "\002usage:\002 and <follow-up>"
        return;
    }

    if {![info exists ask($type,[split $nick],$chan)]} {
        reply $type $target "\002error:\002 no conversation to continue. use '\002ask\002' to start a conversation."
        return;
    }

    set response [ask:query $what 0 [list $cid $uid] $type,[split $nick],$chan]
    set iserror [lindex $response 0]
    set response [lrange $response 1 end]

    if {$iserror eq 1} {
        reply $type $target "\002error:\002 $response"
        return;
    }

    # -- add response to conversation history
    regsub -all {"} $response {\\"} eresponse; # -- escape quotes
    append ask($type,[split $nick],$chan) ", {\"role\": \"assistant\", \"content\": \"$eresponse\"}"
    regsub -all {\{} $response {"} response; # -- fix curly braces
    regsub -all {\}} $response {"} response; # -- fix curly braces 

    # -- output response
    debug 1 "\002ChatGPT answer:\002 $response"
    reply $type $target "$nick: $response"
    
    # -- create log entry for command use
    log:cmdlog BOT * $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""

}

# -- send ChatGPT API queries
proc ask:query {what first ids key} {
    variable ask
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]

    # -- query config
    set cfgurl [cfg:get ask:url *]
    set token [cfg:get ask:token *]
    set org [cfg:get ask:org *]
    set model [cfg:get ask:model *]

    # -- POST data
    # {
    #    "model": "gpt-3.5-turbo",
    #    "messages": [{"role": "user", "content": "What is the capital of Australia?"}],
    #    "temperature": 0.7
    # }

    regsub -all {"} $what {\\"} ewhat; # -- escape quotes in question
    if {$first} {
        # -- first message in conversation

        # -- get any user & chan specific askmode
        lassign $ids cid uid
        db:connect
        set askmode [join [join [db:query "SELECT value FROM settings WHERE setting='askmode' AND cid='$cid' AND uid='$uid'"]]]
        if {$askmode eq ""} {
            # -- see if the user has a global default set
            set askmode [join [join [db:query "SELECT value FROM settings WHERE setting='askmode' AND cid='1' AND uid='$uid'"]]]
        }
        db:close
        if {$askmode eq ""} { set mode [cfg:get ask:system *] } else { set mode "[cfg:get ask:system *]. $askmode." }
        set ask($key) "{\"role\": \"user\", \"content\": \"$mode $ewhat\"}"

    } else {
        # -- continuing conversation
        append ask($key) ", {\"role\": \"user\", \"content\": \"$ewhat\"}"
    }

    set json "{\"model\": \"$model\", \"messages\": \[$ask($key)\], \"temperature\": [cfg:get ask:temp *]}"

    debug 3 "\002ChatGPT POST JSON:\002 $json"

    catch {set tok [http::geturl $cfgurl \
        -method POST \
        -query $json \
        -headers [list "Authorization" "Bearer $token" "OpenAI-Organization" "$org" "Content-Type" "application/json"] \
        -timeout 10000 \
        -keepalive 0]} error

    # -- connection handling abstraction
    set iserror [ask:errors $cfgurl $tok $error]
    if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
    
    set json [http::data $tok]
    debug 3 "\002ChatGPT response JSON:\002 $json"
    set data [json::json2dict $json]
    http::cleanup $tok

    if {[dict exists $data error message]} {
        set errmsg [dict get $data error message]
        debug 0 "\002ask:query:\002 OpenAI error: $errmsg"
        return "1 $errmsg"
    }
    set choices [dict get $data choices]
    set message [dict get [join $choices] message]
    set content [dict get $message content]

    debug 0 "\002ask:query:\002 content: $content"

    if {[string match "*could not parse the JSON body of your request*" $content]} {
        # -- request error; invalid chars
        set content "sorry, I didn't understand some invalid request characters."
        debug 0 "\002ask:query:\002 invalid request characters"
    }

    return "0 $content"
}

# -- abstraction to check for HTTP errors
proc ask:errors {cfgurl tok error} {
    debug 0 "\002ask:errors:\002 checking for errors...(error: $error)"
    if {[string match -nocase "*couldn't open socket*" $error]} {
        debug 0 "\002ask:errors:\002 could not open socket to $cfgurl."
        http::cleanup $tok
        return "1 socket"
    } 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002ask:errors:\002 connection to $cfgurl has timed out."
        http::cleanup $tok
        return "1 timeout"
    } elseif {$status eq "error"} {
        debug 0 "\002ask:errors:\002 connection to $cfgurl has error."
        http::cleanup $tok
        return "1 connection"
    }
}

# -- expire old conversations to avoid memory leaks
proc ask:expire {var} {
    variable ask
    if {[info exists ask($var)]} {
        debug 0 "\002ask:expire:\002 expiring ChatGPT conversation for $var"
        unset ask($var)
    }
}

# -- kill timers on rehash
proc ask:killtimer {var} {
    foreach timer [timers] {
        if {[lindex $timer 1] eq "arm::ask:expire"} { 
            if {[lindex $timer 2] eq $var} {
                debug 0 "\002ask:killtimer:\002 killing ChatGPT ask timer for $var"
                killtimer [lindex $timer 2]
            }
        } 
    }
}


# -- require : in nick completion for botnick commands
# -- otherwise bot will be triggered when someone says something like "chief is sentient!"
if {[cfg:get ask:cmdnick *] eq 1} {
    set cfg(char:tab) 1
}

putlog "\[@\] Armour: loaded ChatGPT plugin (ask)"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------