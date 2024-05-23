# ------------------------------------------------------------------------------------------------
# OpenAI Plugin - ChatGPT integration
#
# Send requests to OpenAI via 'ask' command, and output answers
#
#   - Continue existing conversations with 'and' command
#   - Set user & channel specific response behaviour with 'askmode' command
#   - Generate images using 'image' command or naturaal language requests
#
# ------------------------------------------------------------------------------------------------
#
# Configuration set in Armour config file (e.g., armour.conf)
#
# ------------------------------------------------------------------------------------------------
#
# Commands: 
#
#   https://armour.bot/cmd/ask
#   https://armour.bot/cmd/and
#   https://armour.bot/cmd/askmode
#   https://armour.bot/cmd/image
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
#   @Empus | c image cat wearing sunglasses and a hat
#   @chief | https://chief.armour.bot/sJn27.png
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
#   @Empus | chief: make an image of a dog on a mountain and wearing a sombrero
#   @chief | Empus: https://chief.armour.bot/n5HN4.png
#
#   @Empus | chief: make a variation of image: https://chief.armour.bot/n5HN4.png
#   @chief | Empus: https://chief.armour.bot/pw7nU.png
#
# ------------------------------------------------------------------------------------------------
#
# Image Commands:
#
# @Empus | c image stats
# @chief | images: 4 -- first: 0 days, 00:55:15 ago -- last: 0 days, 00:11:58 ago
# @chief | top 10 authed requesters: Empus (3), MrBob (1)
#
# @Empus | c image top 3
# @chief | [image: 2] user: Empus -- date: 2023-11-28 -- votes: 3 -- url: https://chief.armour.bot/eFvD0.png -- prompt: cat wearing a sombrero
# @chief | [image: 4] user: MrBob -- date: 2023-11-28 -- votes: 1 -- url: https://chief.armour.bot/muedf.png -- prompt: a bear holding a beer
# @chief | [image: 6] user: Empus -- date: 2023-11-28 -- votes: 1 -- url: https://chief.armour.bot/omZw8.png -- prompt: a dog on a mountain wearing sunglasses
#
# @Empus | c image view 2
# @chief | [image: 2] user: Empus -- date: 2023-11-28 -- votes: 3 -- url: https://chief.armour.bot/eFvD0.png -- prompt: cat wearing a sombrero
#
# @Empus | c image rand
# @chief | [image: 3] user: Empus -- date: 2023-11-28 -- url: https://chief.armour.bot/0ekwZ.png -- prompt: a brown bear holding a beer
#
# @Empus | c image del 4
# @chief | done. deleted 1 image.
#
# @Empus | y image frog smoking a cigarette while wearing a French beret
# @chief | [id: 7] https://chief.armour.bot/3j1jg.png
#
# ------------------------------------------------------------------------------------------------






# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------
package require json
package require http 2
package require tls 1.7

bind cron - "0 * * * *" arm::ask:cron;          # -- hourly file cleanup cronjob, on the hour
bind cron - "30 */3 * * *" arm::ask:cron:image; # -- cronjob every 3 hours at 30mins past the hours

# -- cronjob to flush old files, to preserve disk space
# -- do not delete files referenced in quotes (if 'quote' plugin is used), or when voted
proc ask:cron {minute hour day month weekday} {
    set ageflush [cfg:get ask:expire]
    set ageflush [string trimright $ageflush "d"]; # -- legacy value support

    set now [clock seconds]
    db:connect
    set rows [db:query "SELECT id,type,timestamp,votes,file FROM openai"]
    set num [llength $rows]; set deleted 0; set preserved 0
    debug 0 "\002ask:cron:\002 found \002$num\002 files in database -- checking for expired files ($ageflush days)"
    foreach row $rows {
        lassign $row id type timestamp votes file
        set daysold [expr {($now-$timestamp)/86400}]
        set path [file join [cfg:get ask:path] $file]
        if {[info commands quote:cron] ne ""} {
            # -- plugin loaded, check if file's weblink is quoted
            set qcount [db:query "SELECT count(*) FROM quotes WHERE quote LIKE '%$file%'"]
        } else { set qcount 0 }

        if {![file exists $path]} {
                debug 0 "ask:cron: no such file! \002deleting\002 -- age: $daysold -- days: $path"
                db:query "DELETE FROM openai WHERE id=$id"
                incr deleted
        }

        if {$qcount > 0 || $votes > 0} {
            # -- file is quoted or voted! preserve it
            debug 0 "\002ask:cron:\002 preserving \002quoted or voted\002 file: $path"
            incr preserved
            continue;
        }

        if {$daysold > $ageflush} {
            debug 0 "ask:cron: deleting old entry: $path -- age: $daysold days"
            db:query "DELETE FROM openai WHERE id=$id"
            file delete $path
            incr deleted
        }
    }
    db:close
    if {$deleted > 0} { debug 0 "\002ask:cron:\002 deleted \002$deleted\002 expired files" }
    if {$preserved > 0} { debug 0 "\002ask:cron:\002 preserved \002$preserved\002 expired files (\002quoted or voted\002)" }
    debug 0 "\002ask:cron:\002 done. [expr {$num-$deleted}] files remaining."
}

# -- cronjob to output regular random images
proc ask:cron:image {minute hour day month weekday} { 
	variable dbchans; # -- dict containing channel data
	debug 1 "\002ask:cron:image:\002 starting -- minute: $minute -- hour: $hour -- month: $month -- weekday: $weekday"
	db:connect
	# -- output for each channel where imagerand is enabled
	set cids [db:query "SELECT cid FROM settings WHERE setting='imagerand' AND value='on'"]
	foreach cid $cids {
		set chan [dict get $dbchans $cid chan]
		if {![botonchan $chan]} { continue; }; # -- don't bother if not in chan
		set query "SELECT id,user,timestamp,file,votes,desc FROM openai WHERE cid='$cid' AND type='image' ORDER BY random() LIMIT 1"
		set row [join [db:query $query]]
		if {$row eq ""} { continue; }; # -- empty image db in chan
        set chan [db:get chan channels id $cid]
		lassign $row id tuser timestamp file votes
		set desc [join [lrange $row 5 end]]
        set weburl [cfg:get ask:site *]
        set weburl [string trimright $weburl "/"]
        set weburl "$weburl/$file"
        regexp {^\<(.*)\> } $desc -> dbnick
        set desc [lrange $desc 1 end]
        if {$tuser ne ""} { set extra1 " \002user:\002 $tuser --" } else { set extra1 " \002nick:\002 $dbnick --" }
        if {$votes ne 0} { set extra2 " -- \002votes:\002 $votes" } else { set extra2 "" }
        debug 0 "\002ask:cron:image\002 sending periodic random image to $chan: $weburl -- prompt: $desc"
        reply pub $chan "\002\[image:\002 $id\002\]\002$extra1 \002date:\002 [clock format $timestamp -format "%Y-%m-%d"]$extra2 -- \002url:\002 $weburl -- \002prompt:\002 $desc"
	}
	db:close
} 


# -- ask a question
proc arm:cmd:ask {0 1 2 3 {4 ""} {5 ""}} {
    variable ask
    variable dbchans
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    set cmd "ask"

    set arg [join [join $arg]]

    set speak 0; set userprefix 1;
    set what $arg
    # -- allow to continue a conversation if first character is '+' or '.'
    set first [string index $arg 0]
    set length [string length $arg]
    if {$first eq "+" || $first eq "."} {
        arm:cmd:and $0 $1 $2 $3 $4 [string range $arg 1 $length]
        return;
    } elseif {[string match "speak*" [lindex $arg 0]]} {
        # -- speak the response instead of in writing
        set speak 1; 
        set what [lrange $arg 1 end]
    } elseif {$first eq "-"} {
        # -- signal to not use the user's 'askmode' prefix
        set userprefix 0;
        set what [string range $arg 1 $length]
    }

    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]; # -- predict chan when not given

    set cid [db:get id channels chan $chan]
    if {$cid eq ""} { set cid 1 }; # -- default to global chan when command used in an unregistered chan

    # -- ensure user has required access for command
	set allowed [cfg:get ask:allow];    # -- who can use commands? (1-5)
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

    set ison [arm::db:get value settings setting "openai" cid $cid]
    if {$ison ne "on"} {
        # -- openai plugin loaded, but setting not enabled on chan
        debug 1 "\002cmd:ask:\002 openai not enabled on $chan. to enable, use: \002modchan $chan openai on\002"
        reply $type $target "\002error:\002 openai not enabled. to enable, use: \002modchan $chan openai on\002"
        return;
    }

    if {$what eq ""} {
        # -- command usage
        reply $type $target "\002usage:\002 ask <question>"
        return;
    }

    # -- check for blacklisted strings
    if {[ask:blacklist $chan $what]} {
        reply $type $target "I'm sorry $nick, I'm afraid I can't do that."
        return;
    }

    # -- check for image createion request (DALL-E)
    if {[cfg:get ask:image]} {
        set isimage 0
        regsub -all {\{} $what "" what; # -- remove curly braces
        regsub -all {\}} $what "" what; # -- remove curly braces
        debug 4 "arm:cmd:ask: what: $what"
        lassign [ask:image $what] isimage desc imagelink
        if {$isimage} {
            set ison [db:get value settings setting "image" cid $cid]
            if {$ison ne "on"} {
                # -- openai plugin not enabled on chan
                reply $type $target "\002error\002: openai images not enabled. to enable, use: \002modchan $chan image on\002"
                debug 1 "\002cmd:ask:\002 openai images not enabled on $chan. to enable, use: \002modchan $chan image on\002"
                return;
            }
            # -- image creation request
            #set cmd "image"
            if {$imagelink ne ""} { reply $type $target "$nick: sure, one moment.." }; # -- image variation
            #debug 3 "desc: $desc -- iamgelink: $imagelink"
            set response [ask:dalle $desc 1 "512x512" $imagelink]
            set iserror [lindex $response 0]
            set weburl [lindex $response 1]
            set response [lrange $response 1 end]
            if {$iserror eq 1} {
                regsub -all "%N%" $response "$nick" response
                reply $type $target "$response"
                return;
            }

            # -- add optional overlay and insert image to database
            set rowid [ask:abstract:insert image $nick $user $cid $weburl $desc]

            # -- send the image link
            reply $type $target "$nick: $response (\002id:\002 $rowid\002)\002"

            # -- create log entry for command use
            log:cmdlog BOT * $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
            return;
        }
    }

    # -- send the query to OpenAI
    debug 0 "\002cmd:ask:\002 $nick is asking ChatGPT in $chan: $what"
    set response [ask:query $what 1 [list $cid $uid] $type,[split $nick],$chan $speak $userprefix]; # -- send query to OpenAI
    debug 3 "\002cmd:ask:\002 response: $response"
    set iserror [string index $response 0]
    set response [string range $response 2 end]

    if {$iserror eq 1} {
        reply $type $target "\002openai error:\002 $response"
        return;
    }

    debug 3 "arm:cmd:ask: response: $response"
    set eresponse $response
    regsub -all {"} $response {\"} eresponse; # -- escape quotes in response
    append ask($type,[split $nick],$chan) ", {\"role\": \"assistant\", \"content\": \"$eresponse\"}"

    regsub -all {\{} $response {"} response; # -- fix curly braces
    regsub -all {\}} $response {"} response; # -- fix curly braces 
    
    debug 1 "\002cmd:ask:\002: OpenAI answer: $response"

    if {$speak} {
        set iserror [speak:query $eresponse]
        if {[lindex $iserror 0] eq 1} {
            reply $type $target "\002 speech error:\002 [lrange $iserror 1 end]"
            return;
        }
        set ref [lindex $iserror 1]
        set rowid [ask:abstract:insert speak $nick $user $cid $ref $what]
        reply $type $target "$nick: $ref (\002id:\002 $rowid\002)\002"
    } else {
        if {[string match "I'm sorry, but as a text-based AI, I cannot create images.*" $response] \
            || [string match "Creating images is beyond my current capabilities,* " $response]} {
            set response "Please adjust the wording of your request, if you want me to create an image."
        }
        reply $type $target "$nick: [encoding convertfrom utf-8 "$response"]"
    }

    ask:killtimer [split $type,[split $nick],$chan]; # -- kill any existing ask timer
    timer [cfg:get ask:mem *] "arm::ask:expire [split $type,[split $nick],$chan]"; # -- expire the conversation after N mins

    # -- create log entry for command use
    log:cmdlog BOT * $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""
}

# -- continue a conversation
proc arm:cmd:and {0 1 2 3 {4 ""} {5 ""}} {
    variable ask
    variable dbchans
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    set cmd "and"

    set arg [join [join $arg]]; # -- join the arg list

    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]; # -- predict chan when not given

    set cid [db:get id channels chan $chan]
    if {$cid eq ""} { set cid 1 }; # -- default to global chan when command sued in unregistered channel

    # -- ensure user has required access for command
	set allowed [cfg:get ask:allow];    # -- who can use commands? (1-5)
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

    # -- check for blacklisted strings
    if {[ask:blacklist $chan $what]} {
        reply $type $target "I'm sorry $nick, I'm afraid I can't do that."
        return;
    }

    if {![info exists ask($type,[split $nick],$chan)]} {
        reply $type $target "\002error:\002 no conversation to continue. use '\002ask\002' to start a conversation."
        return;
    }

    set speak 0
    if {[string match "speak*" [lindex $arg 0]]} {
        # -- speak the response instead of in writing
        set speak 1
        set what [lrange $arg 1 end]
    }

    set response [ask:query $what 0 [list $cid $uid] $type,[split $nick],$chan $speak]
    set iserror [string index $response 0]
    set response [string range $response 2 end]

    if {$iserror eq 1} {
        reply $type $target "\002openai error:\002 $response"
        return;
    }

    # -- add response to conversation history
    regsub -all {"} $response {\"} eresponse; # -- escape quotes
    append ask($type,[split $nick],$chan) ", {\"role\": \"assistant\", \"content\": \"$eresponse\"}"
    regsub -all {\{} $response {"} response; # -- fix curly braces
    regsub -all {\}} $response {"} response; # -- fix curly braces

    # -- output response
    debug 4 "\002OpenAI answer:\002 $response"

    if {$speak} {
        set iserror [speak:query $eresponse]
        if {[lindex $iserror 0] eq 1} {
            reply $type $target "\002speech error:\002 [lrange $iserror 1 end]"
            return;
        }
        set ref [lindex $iserror 1]
        reply $type $target "$nick: $ref"
    } else {
        set response [encoding convertfrom utf-8 $response]; # -- convert from utf-8
        reply $type $target "$nick: $response"
    }
    
    # -- create log entry for command use
    log:cmdlog BOT * $cid $user $uid [string toupper $cmd] [join $arg] $source "" "" ""

}

# -- describe an image to create (DALL-E)
proc arm:cmd:i {0 1 2 3 {4 ""} {5 ""}} { arm:cmd:image $0 $1 $2 $3 $4 $5 }
proc arm:cmd:image {0 1 2 3 {4 ""} {5 ""}} {
    ask:abstract:cmd image $0 $1 $2 $3 $4 $5; # -- send to abstraction proc
}

# -- abstraction for 'image' and 'speak' commands
# -- avoids code duplication
# -- 'cmd' will be "image" or "speak"
proc ask:abstract:cmd {cmd 0 1 2 3 {4 ""} {5 ""}} {
    variable dbchans
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    putlog "ask:abstract:cmd: started: $cmd -- type: $type -- nick: $nick -- chan: $chan -- arg: $arg"
    if {$cmd eq "image"} {
        if {![cfg:get ask:image]} { return; }; # -- DALL-E image creation disabled
        set plural "images"
    } else { set plural $cmd }

	lassign [db:get user,id users curnick $nick] user uid
	if {[string index [lindex $arg 0] 0] eq "#"} {
		# -- channel name given
		set chan [lindex $arg 0]
		set arg [lrange $arg 1 end]
	} else {
		# -- chan name not given, figure it out
		set chan [userdb:get:chan $user $chan]
	}

	set cid [db:get id channels chan $chan]
	set glevel [db:get level levels cid 1 uid $uid]
	set level [db:get level levels cid $cid uid $uid]

    # -- ensure user has required access for command
	set allowed [cfg:get ask:allow];    # -- who can use commands? (1-5)
                                        #        1: all channel users
									    #        2: only voiced, opped, and authed users
                                        #        3: only voiced when not secure mode, opped, and authed users
                        	            #        4: only opped and authed channel users
                                        #        5: only authed users with command access
    set allow 0
    if {$uid eq ""} { set authed 0 } else { set authed 1 }
    putlog "allowed: $allowed"
    if {$allowed eq 0} { return; } \
    elseif {$allowed eq 1} { set allow 1 } \
	elseif {$allowed eq 2} { if {[isop $nick $chan] || [isvoice $nick $chan] || $authed} { set allow 1 } } \
    elseif {$allowed eq 3} { if {[isop $nick $chan] || ([isvoice $nick $chan] && [dict get $dbchans $cid mode] ne "secure") || $authed} { set allow 1 } } \
    elseif {$allowed eq 4} { if {[isop $nick $chan] || $authed} { set allow 1 } } \
    elseif {$allowed eq 5} { if {$authed} { set allow [userdb:isAllowed $nick $cmd $chan $type] } }
    if {[userdb:isIgnored $nick $cid]} { set allow 0 }; # -- check if user is ignored
    putlog "allow: $allow -- nick: $nick -- chan: $chan -- cid: $cid -- authed: $authed"
    if {!$allow} { return; }; # -- client cannot use command

    set ison [db:get value settings setting $cmd cid $cid]
    if {$ison ne "on"} {
        # -- openai image setting not enabled on chan
        debug 1 "\002ask:abstract:cmd\002 openai $plural not enabled on $chan. to enable, use: \002modchan $chan $cmd on\002"
        reply $type $target "openai $plural not enabled. to enable, use: \002modchan $chan $cmd on\002"
        return;
    }

    if {$arg eq ""} {
        reply $type $target "\002usage:\002 $cmd <rand|+|view|search|del|top|stats|description> \[id|num\]"
        return;
    }

    # -- check file directory path
    if {$cmd in "image speak"} {
        set filedir [cfg:get ask:path]
        if {![file isdirectory $filedir]} {
            # -- directory doesn't exist
            debug 0 "\002ask:abstract:cmd\002 openai file directory \002cfg(ask:path)\002 doesn't exist: $filedir"
            reply $type $target "\002error:\002 openai file directory \002cfg(ask:path)\002 doesn't exist: $filedir"
            return;   

        } elseif {![file writable $filedir]} {
            # -- directory not writable 
            debug 0 "\002ask:abstract:cmd\002 openai file directory \002cfg(ask:path)\002 is not writable: $filedir"
            reply $type $target "\002error:\002 openai file directory \002cfg(ask:path)\002 is not writable: $filedir"
            return;   
        }
    }

    set what [lindex $arg 0]

    # -- check for blacklisted strings
    if {[ask:blacklist $chan $what]} {
        reply $type $target "I'm sorry $nick, I'm afraid I can't do that."
        return;
    }

	if {$what eq "rand" || $what eq "random" || $what eq "r"} {
		# -- show random
		db:connect
		set query "SELECT id,user,timestamp,file,votes,desc FROM openai WHERE cid='$cid' AND type='$cmd' ORDER BY random() LIMIT 1"
		set row [join [db:query $query]]
		db:close
		if {$row eq ""} {
			# -- empty db
			reply $type $target "\002error:\002 $cmd db empty."
			return;
		}
		lassign $row id tuser timestamp file votes
		set desc [join [lrange $row 5 end]]
        set weburl [cfg:get ask:site *]
        set weburl [string trimright $weburl "/"]
        set weburl "$weburl/$file"
        regexp {^\<(.*)\> } $desc -> dbnick
        set desc [lrange $desc 1 end]
        if {$tuser ne ""} { set extra1 " \002user:\002 $tuser --" } else { set extra1 " \002nick:\002 $dbnick --" }
        if {$votes ne 0} { set extra2 " -- \002votes:\002 $votes" } else { set extra2 "" }
        reply $type $target "\002\[$cmd:\002 $id\002\]\002$extra1 \002date:\002 [clock format $timestamp -format "%Y-%m-%d"]$extra2 -- \002url:\002 $weburl -- \002prompt:\002 $desc"

    } elseif {$what eq "view" || $what eq "v"} {
        # -- view
        set tids [lindex $arg 1]
        if {$tids eq ""} {
            reply $type $target "\002usage:\002 $cmd view <id>"
            return;
        }
        # -- loop over comma delimited ids
        set i 0
        foreach tid [split $tids ,] {
            if {$i eq 5} {
                # -- limit to 5 results
                reply $type $target "max of 5 results returned."
                return;
            }
            db:connect
            set query "SELECT id,user,timestamp,file,votes,desc FROM openai WHERE cid='$cid' AND id='$tid' AND type='$cmd'"
            set row [join [db:query $query]]
            db:close
            lassign $row id tuser timestamp file votes
		    set desc [join [lrange $row 5 end]]
            if {$id eq ""} {
                reply $type $target "\002error:\002 $cmd not found (\002id:\002 $tid)"
                continue;
            }
            set weburl [cfg:get ask:site *]
            set weburl [string trimright $weburl "/"]
            set weburl "$weburl/$file"
            regexp {^\<(.*)\> } $desc -> dbnick
            set desc [lrange $desc 1 end]
            if {$tuser ne ""} { set extra1 " \002user:\002 $tuser --" } else { set extra1 " \002nick:\002 $dbnick --" }
            if {$votes ne 0} { set extra2 " -- \002votes:\002 $votes" } else { set extra2 "" }
            reply $type $target "\002\[$cmd:\002 $id\002\]\002$extra1 \002date:\002 [clock format $timestamp -format "%Y-%m-%d"]$extra2 -- \002url:\002 $weburl -- \002prompt:\002 $desc"
            incr i
        }

    } elseif {$what eq "del" || $what eq "d" || $what eq "rem"} {
        # -- delete
        set tids [lindex $arg 1]
        if {$tids eq ""} {
            reply $type $target "\002usage:\002 $cmd del <id>"
            return;
        }
        # -- loop over comma delimited ids
        set i 0
        foreach tid [split $tids ,] {
            db:connect
            set query "SELECT id,user,timestamp,file,votes,desc FROM openai WHERE cid='$cid' AND id='$tid' AND type='$cmd'"
            set row [join [db:query $query]]
            db:close
            lassign $row id tuser timestamp file votes
		    set desc [join [lrange $row 5 end]]
            if {$id eq ""} {
                reply $type $target "\002error:\002 $cmd not found (\002id:\002 $tid)"
                continue;
            }
            set path "[cfg:get ask:path *]/$file"
            debug 0 "\002ask:abstract:cmd:\002 deleting $cmd: $path (id: $id)"
            exec rm -f $path; # -- delete file on disk
            db:connect
            db:query "DELETE FROM openai WHERE cid='$cid' AND id='$tid' AND type='$cmd'"
            db:close
            incr i
        }
        # -- output the result
        if {$i > 0} {
            if {$i eq 1} { set suffix $cmd } else { set suffix "${cmd}s" }; # -- handle plural
            reply $type $target "done. deleted \002$i\002 $suffix."
        } else {
            #reply $type $target "\002warn:\002 no entries deleted."
        }

    } elseif {$what eq "+" || $what eq "vote"} {
        # -- vote 
        set tids [lindex $arg 1]
        if {$tids eq ""} {
            reply $type $target "\002usage:\002 $cmd + <id>"
            return;
        }
        foreach tid [split $tids ,] {
            db:connect
            set query "SELECT votes FROM openai WHERE cid='$cid' AND id='$tid' AND type='$cmd'"
            set votes [join [db:query $query]]
            db:close
            if {$votes eq ""} {
                reply $type $target "\002error:\002 $cmd not found."
                return;
            }
            set votes [incr votes]
            db:connect
            db:query "UPDATE openai SET votes='$votes' WHERE cid='$cid' AND id='$tid' AND type='$cmd'"
            db:close
            debug 0 "ask:abstract:cmd: $nick voted for $cmd in $chan (id: $tid)"
            reply $type $target "done. (\002votes:\002 $votes)"
        }

    } elseif {$what eq "stats"} {
        # -- stats
		set tchan [lindex $arg 1]
		# -- allow stats to have optional channel (incl. * for global)
		set glob 0; set isuser 0;
		if {[string index $tchan 0] != "#" && $tchan != "*" && $tchan != ""} { set isuser 1; set tuser $tchan }; # -- stats for a single user
		if {$tchan ne "" && $isuser eq 0} {
			if {$tchan eq "*"} {
				# -- global
				if {$glevel < 400} {
					reply $type $target "access denied."
					return;
				}
				set glob 1
			} else {
				set tcid [db:get id channels chan $tchan]
				if {$tcid eq "" || $tcid eq 0} {
					reply $type $target "\002error:\002 no such channel."
					return;
				}
				set tlevel [db:get level levels cid $tcid uid $uid]
				if {$tlevel < 100 && $glevel < 100} {
				    reply $type $target "access denied."
					return;
				}				
			}
		}

		set query1 "SELECT count(id) FROM openai WHERE type='$cmd'"
		set query2 "SELECT user,count(*) as total FROM openai WHERE user!='' AND type='$cmd'"
		if {!$glob} { append query1 " AND cid='$cid'"; append query2 " AND cid='$cid'" }

		# -- stats for a single user;
		if {$isuser} {
			lassign [db:get id,user users user $tuser] tuid tuser
			if {$tuser eq ""} {
				reply $type $target "no such user."
				return;
			}
			append query1 " AND user='$tuser'"
			append query2 " AND user='$tuser'"
		}
		db:connect
		append query2 " GROUP BY user ORDER BY total DESC LIMIT 10"

		set res1 [db:query $query1]
		set count [lindex $res1 0]
		if {$count eq 0} {
			if {$isuser} {
				reply $type $target "no authenticated ${cmd}s from $tuser."
			} else {
				reply $type $target "$cmd db is empty."
			}
			db:close	
			return;
		}

		set top ""
		set res2 [db:query $query2]
		foreach pair $res2 {
			lassign $pair cuser ctotal
			append top "$cuser ($ctotal), "
		}
		set top [string trimright $top ", "]

		set query "SELECT timestamp FROM openai WHERE type='$cmd'"
		if {$glob eq 0} { set first "$query AND cid='$cid'"; set last "$query AND cid='$cid'" } \
		else { set first $query; set last $query }
		if {$isuser} {
			append first " AND uid='$tuid'"
			append last " AND user='$tuid'"
		}
		set first "$first ORDER BY timestamp ASC LIMIT 1"
		set last "$last ORDER BY timestamp DESC LIMIT 1"

		set first [join [lindex [db:query $first] 0]]
		set last [join [lindex [db:query $last] 0]]
		
		# -- TODO: move timeago locally to work in standalone
		set firstago [userdb:timeago $first]
		set lastago [userdb:timeago $last]
		reply $type $target "\002${cmd}s:\002 $count -- \002first:\002 $firstago ago -- \002last:\002 $lastago ago"
		if {$top ne "" && $isuser eq 0} {
			reply $type $target "\002top 10 authed requesters:\002 $top"
		}
        set now [clock seconds]
        set rows [db:query "SELECT id,type,timestamp,votes,file FROM openai WHERE cid=$cid AND type='$cmd'"]
        set num [llength $rows]; set quoted 0; set voted 0
        foreach row $rows {
            lassign $row dbid dbtype dbts dbvotes dbfile
            set daysold [expr {($now-$dbts)/86400}]
            if {[info commands quote:cron] ne ""} {
                # -- plugin loaded, check if file's weblink is quoted
                set qcount [db:query "SELECT count(*) FROM quotes WHERE quote LIKE '%$dbfile%'"]
            } else { set qcount 0 }
            if {$qcount > 0} { incr quoted }
            if {$dbvotes > 0} { incr voted }
        }
        db:close
        set expiry [string trimright [cfg:get ask:expire *] "d"]
        reply $type $target "\002expire age:\002 $expiry days -- \002preserving:\002 $quoted (quoted), $voted (voted)"

    } elseif {$what eq "search" || $what eq "s"} {
		# -- search
		set search [string tolower [lindex $arg 1]]
		set searchu [lindex $arg 2]
		debug 2 "ask:abstract:cmd: search $search $searchu"
		if {$search eq ""} {
			reply $stype $starget "\002usage:\002 $cmd search <pattern> ?-user|-nick <source>?"
			return;
		}
		# -- wrap the search in * for wildcard as a prompt will never be one word
		if {[string index $search 0] ne "*"} { set search "*$search" }
		set length [string length $search]
		if {[string index $search [expr $length - 1]] ne "*"} { set search "$search*" }
		regsub -all {\*} $search {%} search
		regsub -all {\?} $search {_} search
		
		set dbsearch [db:escape $search]
		if {$searchu eq "-user"} {
			set usearch [db:escape [string tolower [lindex $arg 3]]]
			set xtra "AND lower(desc) LIKE '[string tolower $dbsearch]' AND user LIKE '$usearch'"
		} elseif {$searchu eq "-nick"} {
			set nsearch [db:escape [string tolower [lindex $arg 3]]]
			set xtra "AND lower(desc) LIKE '[string tolower $dbsearch]' AND lower(desc) LIKE '<[string tolower $nsearch]> %'"
		} else {
			set xtra "AND lower(desc) LIKE '[string tolower $dbsearch]'"
		}
		db:connect
		set query "SELECT id,user,timestamp,file,votes,desc FROM openai WHERE type='$cmd' $xtra AND cid='$cid'"
		set res [db:query $query]
		db:close
		if {$res eq ""} {
			# -- empty db
			reply $type $target "no results found."
			return;
		}
		set i 0;
		set results [llength $res]
		foreach row $res {
			incr i
			lassign $row id tuser timestamp file votes
			set tdesc [join [lrange $row 5 end]]
			if {($type eq "pub" && $i eq "4") || ($type eq "msg" && $i eq "6") \
				|| ($i eq "11")} {
					reply $type $target "too many results found ($results), please refine search."
					return;
			}
            set weburl [cfg:get ask:site *]
            set weburl [string trimright $weburl "/"]
            set weburl "$weburl/$file"
            regexp {^\<(.*)\> } $tdesc -> dbnick
            set desc [lrange $tdesc 1 end]
            if {$tuser ne ""} { set extra1 " \002user:\002 $tuser --" } else { set extra1 " \002nick:\002 $dbnick --" }
            if {$votes ne 0} { set extra2 " -- \002votes:\002 $votes" } else { set extra2 "" }
            reply $type $target "\002\[$cmd:\002 $id\002\]\002$extra1 \002date:\002 [clock format $timestamp -format "%Y-%m-%d"]$extra2 -- \002url:\002 $weburl -- \002prompt:\002 $desc"
		}
		if {$i eq 1} {
			reply $type $target "search complete ($i result found)."
		} else {
			reply $type $target "search complete ($i results found)."
		}
	} elseif {$what eq "t" || $what eq "top"} {
        # -- top requestors
		if {![isop $nick $chan] && ![isvoice $nick $chan] && ($level < 400)} {
			reply $stype $starget "access denied."
			return;		
		}
		set num [lindex $arg 1]
		if {$num eq "" || $num eq 0} { set num 1 }; # -- number of results
		if {![regexp -- {^\d+$} $num]} {
			reply $stype $starget "\002usage:\002 $cmd top \[num\]"
			return;
		}
		set max 0
		if {$num > 5} { set max 1; set num 5; }

		debug 2 "ask:abstract:cmd: top vote scorers (num: $num)"
		db:connect
		set rows [db:query "SELECT id,user,timestamp,file,votes,desc FROM openai WHERE type='$cmd' AND cid='$cid' AND votes!='0' ORDER BY votes DESC LIMIT $num"]
		debug 2 "cask:abstract:cmd: rows: $rows"
		if {$rows eq ""} { 
			reply $stype $starget "no $cmd votes cast. \002usage:\002 $cmd + <id>"
			db:close
			return;
		}
		set count 0
		foreach row $rows {
			lassign $row dbid dbuser dbts dbfile dbvotes dbdesc
            set weburl [cfg:get ask:site *]
            set weburl [string trimright $weburl "/"]
            set weburl "$weburl/$dbfile"
            regexp {^\<(.*)\> } $dbdesc -> dbnick
            set dbdesc [lrange $dbdesc 1 end]
            if {$dbuser ne ""} { set extra1 " \002user:\002 $dbuser --" } else { set extra1 " \002nick:\002 $dbnick --" }
            if {$dbvotes ne 0} { set extra2 " -- \002votes:\002 $dbvotes" } else { set extra2 "" }
            reply $type $target "\002\[$cmd:\002 $dbid\002\]\002$extra1 \002date:\002 [clock format $dbts -format "%Y-%m-%d"]$extra2 -- \002url:\002 $weburl -- \002prompt:\002 $dbdesc"
			incr count;
		}

		if {$count < $num} { reply $stype $starget "\002info:\002 only $count ${cmd}s found with votes cast." }
		if {$max} { reply $stype $starget "maximum of 5 results displayed."; }
		db:close
        
    } else {
        # -- image
        set query [join $arg]
        if {$cmd eq "image"} {
            # -- image generation
            #regsub -all {"} $query {\\"} query; # -- escape quotes

            set iserror [ask:dalle $query 1 "512x512"]
            if {[lindex $iserror 0] eq 1} { 
                regsub -all "%N%" [lrange $iserror 1 end] "$nick" response
                reply $type $target $response
                return; 
            }
            set ref [lrange $iserror 1 end]
            
            # -- add optional overlay and insert image to database
            set rowid [ask:abstract:insert image $nick $user $cid $ref $query]

            # -- send the image link
            reply $type $target "$nick: $ref (\002id:\002 $rowid)"

        } elseif {$cmd eq "speak"} {
            # -- speak
            regsub -all {"} $query {\\"} query; # -- escape quotes
            set iserror [speak:query $query]
            if {[lindex $iserror 0] eq 1} { 
                reply $type $target "error: [lrange $iserror 1 end]"
                return; 
            }
            set ref [lindex $iserror 1]

            # -- add optional overlay and insert image to database
            set rowid [ask:abstract:insert speak $nick $user $cid $ref $query]

            # -- send the speak link
            reply $type $target "$nick: $ref (\002id:\002 $rowid)"
        }
    }

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
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }


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

# -- send ChatGPT API queries
proc ask:query {what first ids key {speak "0"} {userprefix "1"}} {
    variable ask
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]
    set ::http::defaultCharset utf-8

    # -- query config
    # -- set API URL based on service
    switch -- [cfg:get ask:service] {
        openai     { set cfgurl "https://api.openai.com/v1/chat/completions" }
        perplexity { set cfgurl "https://api.perplexity.ai/chat/completions" }
        default    { set cfgurl "https://api.openai.com/v1/chat/completions"}
    }
    set token [cfg:get ask:token *]
    set org [cfg:get ask:org *]
    set model [cfg:get ask:model *]
    set timeout [expr [cfg:get ask:timeout *] * 1000]

    # -- POST data
    # {
    #    "model": "gpt-3.5-turbo",
    #    "messages": [{"role": "user", "content": "What is the capital of Australia?"}],
    #    "temperature": 0.7
    # }

    debug 4 "ask:query: what: $what"
    
    regsub -all {"} $what {\\"} ewhat;           # -- escape quotes in question
    #putlog "ask:query: ewhat: $ewhat"
    #set ewhat $what
    set ewhat [encoding convertto utf-8 $ewhat]; # -- convert to utf-8
    #putlog "ask:query: ewhat now (utf8 convert): $ewhat"
    #set ewhat $what

    if {$first} {
        # -- first message in conversation

        # -- get any user & chan specific askmode
        lassign $ids cid uid
        db:connect
        set askmode ""
        if {$userprefix} {
            # -- apply user specific prefix, if exists
            set askmode [join [join [db:query "SELECT value FROM settings WHERE setting='askmode' AND cid='$cid' AND uid='$uid'"]]]
            if {$askmode eq ""} {
                # -- see if the user has a global default set
                set askmode [join [join [db:query "SELECT value FROM settings WHERE setting='askmode' AND cid='1' AND uid='$uid'"]]]
            }
        }
        db:close
        if {$speak} { set lines [cfg:get speak:lines *] } else { set lines [cfg:get ask:lines *] }; # -- how many max lines in output
        set prefix "Answer in $lines lines or less" 
        set system [cfg:get ask:prefix *]
        if {[regexp -- {Answer in \d+ lines or less.} $system]} { set system "" }; # -- remove old default prefix user hasn't changed
        if {$system ne ""} { set prefix "$prefix. $system" }
        if {$askmode ne ""} { set mode "$prefix. $askmode." } else { set mode "$prefix." }
        #set ask($key) "{\"role\": \"user\", \"content\": \"$mode $ewhat\"}"
        set systemrole [cfg:get ask:system *] 
        if {$systemrole ne ""} {
            # -- add system role instruction
            regsub -all {"} $systemrole {\\"} systemrole
            set ask($key) "{\"role\": \"system\", \"content\": \"$systemrole\"}, {\"role\": \"user\", \"content\": \"$mode $ewhat\"}"
        } else {
            set ask($key) "{\"role\": \"user\", \"content\": \"$mode $ewhat\"}"
        }

    } else {
        # -- continuing conversation
        append ask($key) ", {\"role\": \"user\", \"content\": \"$ewhat\"}"
    }

    set json "{\"model\": \"$model\", \"messages\": \[$ask($key)\], \"temperature\": [cfg:get ask:temp *]}"

    debug 5 "\002ask:query:\002 POST JSON: $json"

    catch {set tok [http::geturl $cfgurl \
        -method POST \
        -binary 1 \
        -query $json \
        -headers [list "Authorization" "Bearer $token" "OpenAI-Organization" "$org" "Content-Type" "application/json"] \
        -timeout $timeout \
        -keepalive 0]} error

    # -- connection handling abstraction
    set iserror [ask:errors $cfgurl $tok $error]
    if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
    
    set json [http::data $tok]
    debug 5 "\002ask:query:\002 response JSON: $json"
    set data [json::json2dict $json]
    http::cleanup $tok

    if {[dict exists $data error message]} {
        set errmsg [dict get $data error message]
        debug 0 "\002ask:query:\002 OpenAI error: $errmsg"
        if {[string match "*could not parse the JSON body of your request*" $errmsg]} {
            # -- request error; invalid chars
            #debug 0 "\002ask:query:\002 invalid request characters"
            return "0 sorry, I didn't understand some invalid request characters."
        } else {
            return "1 $errmsg"
        }
    }
    set choices [dict get $data choices]
    set message [dict get [join $choices] message]
    set content [dict get $message content]

    debug 5 "\002ask:query:\002 content: $content"
    return "0 $content"
}

proc ask:dalle {desc {num "1"} {size "512x512"} {image ""}} {
    variable ask:rate:count; # -- tracker of requests for rate limiting
    
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]
    
    set token [cfg:get ask:token *]
    set timeout [expr [cfg:get ask:timeout *] * 1000]

    regsub -all {"} $desc {\\"} desc; # -- escape quotes in query

    set limited 0

    # -- image variation
    if {$image ne ""} {
        # -- description included weblink of PNG image, for variation 

        # -- check if curl is installed
        if {[lindex [exec whereis curl] 1] eq ""} {
            return "1 [list "curl must be installed for image variations."]"
        }

        # -- check if ImageMagick is installed
        if {[lindex [exec whereis convert] 1] eq ""} {
            return "1 [list "ImageMagick must be installed for image variations."]"
        }

        # -- first get the image
        catch { set tok [http::geturl $image -method GET -timeout $timeout -binary 1] } error
        set iserror [ask:errors $image $tok $error]
        if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
        set imagedata [http::data $tok]
        http::cleanup $tok

        set tempfile "[randfile "png"].tmp.png"
        set path [string trimright [cfg:get ask:path *] "/"]
        set filepath "$path/$tempfile"
        set fd [open $filepath wb]
        puts $fd $imagedata
        close $fd

        debug 3 "ask:dalle: converting image: $filepath"
        exec convert $filepath -alpha on -background none -flatten $filepath.new
        
        # -- image edit
        #set url "https://api.openai.com/v1/images/edits"
        #set params [list -H "Authorization: Bearer $token" -F image=@$filepath.new -F prompt=$desc -F n=1 -F size=$size]
        #set params "-H \"Authorization: Bearer $token\" -F image=@$filepath.new -F prompt=\"$desc\" -F n=1 -F size=\"$size\""
        
        # -- image variation
        set url "https://api.openai.com/v1/images/variations"
        set size [cfg:get ask:image:size *]
        set params [list -H "Authorization: Bearer $token" -F image=@$filepath.new -F n=1 -F size=$size]
        
        catch {set data [exec curl --silent {*}$params $url]}
        exec rm $filepath
        exec rm "$filepath.new"

        catch {set tok [http::geturl $url -headers $headers -query $payload -timeout $timeout]} error
        
    } else {
        # -- generate new image
        
        # -- query config
        set url "https://api.openai.com/v1/images/generations"

        #curl https://api.openai.com/v1/images/generations \
        #    -H "Content-Type: application/json" \
        #    -H "Authorization: Bearer <api-key>" \
        #    -d '{
        #        "prompt": "A cute baby sea otter",
        #        "n": 1,
        #        "size": "512x512"
        #    }'


        # -- optional image generation rate limiting
        set limited 0
        set size [cfg:get ask:image:size *]
        set model [cfg:get ask:image:model *]
        set rate [cfg:get ask:image:rate *]
        incr ask:rate:count; # -- increase tracker

        if {$rate ne ""} {
            lassign [split $rate ":"] req mins hold
            debug 0 "ask:dalle: rate: $req -- mins: $mins -- hold: $hold"
            if {${ask:rate:count} < [expr $req + 1]} {
                # -- rate limit not met
                set model [cfg:get ask:image:model *]
                #timer $mins "arm::ask:rate:decr"; # -- decrease counter after 'mins' mins
                timer $mins "incr arm::ask:rate:count -1"; # -- decrease counter after 'mins' mins

            } else {
                if {${ask:rate:count} eq [expr $req + 1]} {
                    # -- rate limiting reached
                    debug 0 "\002ask:dalle:\002 rate limit reached. holding for $hold mins."
                    foreach t [timers] {
                        lassign $t tt tproc tid num
                        if {$tproc eq "incr arm::ask:rate:count -1"} {
                            # -- timer already exists
                            debug 0 "\002ask:dalle:\002 rate limit timer already exists -- killing: $tid"
                            killtimer $tid
                        }
                    }
                    debug 0 "\002ask:dalle:\002 starting rate limit decrease timer in $hold mins"
                    timer $hold "set arm::ask:rate:count 0"; # -- reset to zero after hold timer
                    #timer $hold "arm::ask:rate:decr"; # -- decrease counter after 'hold' mins
                    set msg "rate limit reached.. restricted for $hold mins."

                } elseif {${ask:rate:count} > [expr $req + 1]} {
                    # -- limit was previously hit
                    set idx [lsearch [timers] "*set arm::ask:rate:count 0*"]
                    if {$idx ne -1} { 
                        lassign [lindex [timers] $idx] tt tproc tid num
                        debug 0 "\002ask:dalle:\002 rate limit previously hit. time remaining: $tt mins."
                        set msg "rate limit reached.. $tt mins reamining."
                    }
                } 

                # -- check rate limit action (restrict, or use alternate model)
                set act [cfg:get ask:rate:act *]
                if {$act ne ""} {
                    # -- alternate model to reduce costs
                    set model $act
                    debug 0 "\002ask:dalle:\002 switching to alternate model: $model"
                    #set size "512x512"; # -- lower the size, too
                    set limited 1
                } else {
                    return "1 $msg"
                }
            }
        }
        # -- end rate limiting

        set headers [list "Authorization" "Bearer $token" "Content-Type" "application/json"]
        #set model [cfg:get ask:image:model *]
        set odesc $desc
        set desc [encoding convertto utf-8 $desc]; # -- convert to utf-8
        set query [json::dict2json [dict create prompt "\"$desc\"" n $num size "\"$size\"" model "\"$model\""]]
        debug 5 "ask:dalle: POST json: $query"
        catch {set tok [http::geturl $url \
            -method POST \
            -query $query \
            -headers $headers \
            -timeout $timeout \
            -keepalive 0]} error

        # -- connection handling abstraction
        set iserror [ask:errors $url $tok $error]
        if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
        
        set data [http::data $tok]
    }
    #set json [json::dict2json [dict create prompt "\"$desc\"" n $num size "\"$size\"" response_format "\"b64_json\""]]
    
    debug 5 "\002OpenAI DALLE response JSON:\002 $data"
    set dict [json::json2dict $data]
    http::cleanup $tok

    if {[dict exists $dict error message]} {
        set errmsg [dict get $dict error message]
        debug 0 "\002ask:dalle:\002 OpenAI error: $errmsg"
        set code [dict get $dict error code]
        if {$code eq "content_policy_violation"} {
            set errmsg "I'm sorry %N%, I'm afraid I can't do that."
        }
        return "1 $errmsg"
    }

    set data [join [dict get $dict data]]
    set url [dict get $data url]; # -- the generated image URL
    #set data [dict get $data b64_json]; # -- the generated base64 encoded image

    # -- fetch the image to save locally
    catch {set tok [http::geturl $url -method GET -timeout $timeout]} error
    # -- connection handling abstraction
    set iserror [ask:errors $url $tok $error]
    if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
    set data [http::data $tok]  
    http::cleanup $tok
    
    # -- save the image file locally
    set rand [randfile "png"]
    set path [string trimright [cfg:get ask:path *] "/"]
    set fd [open $path/$rand.png wb]
    puts $fd $data
    close $fd
    set weburl [string trimright [cfg:get ask:site *] "/"]
    set weburl "$weburl/$rand.png"
    if {$limited} { set weburl "$weburl (r)" }; # -- append (r) to denote rate limit restricted model

    debug 3 "\002ask:dalle:\002 generated image url: $weburl"
    return "0 $weburl"

}

# -- add optional iamge overlay, and insert to database
proc ask:abstract:insert {cmd nick user cid weburl query} {
    set path [string trimright [cfg:get ask:path *] "/"]
    set file [file tail $weburl]
    if {$cmd eq "image"} {
        # -- check if ImageMagick is installed and overlay enabled
        if {[lindex [exec whereis convert] 1] ne "" && [cfg:get ask:image:overlay]} {
            set overlay "\\<$nick\\> $query"
            debug 3 "ask:abstract:insert: adding text overlay: $overlay"
            #exec convert $path/$file -alpha on \( +clone -scale x8% -threshold 101% -channel A -fx "0.5" \) -gravity south -composite -fill white -pointsize 24 -annotate 0,0 '$overlay' $path/$file
            #exec convert $path/$file -alpha on \( +clone -scale x8% -threshold 101% -channel A -fx "0.5" \) -gravity south -composite -fill white -pointsize 24 -annotate 0,0 $overlay $path/$file
		    exec convert $path/$file \( -size 1024 -background rgba\(0,0,0,0.5\) -fill white -pointsize 24 caption:$overlay \) -gravity south -composite $path/$file
        }
    }
    # -- insert into db
    set query "<$nick> $query"; # -- prefix with nick
    db:connect
    set desc [db:escape $query]
    set ts [clock seconds]
    debug 0 "inserting into openai: type: $cmd -- cid: $cid -- user: $user -- timestamp: $ts -- file: $file -- desc: $desc"
    db:query "INSERT INTO openai (type,cid,user,timestamp,file,desc) VALUES ('$cmd', '$cid','$user','$ts','$file','$desc')"
    set rowid [db:last:rowid]
    db:close
    debug 0 "\002ask:abstract:insert:\002 $nick (user: $user) created $cmd (id: $rowid -- url: $weburl)"
    # -- return the rowid
    return $rowid
}

# -- check for image creation request
proc ask:image {request} {
    set image 0; set imagelink ""; set desc ""
    debug 4 "ask:image: request: $request"

    #regexp -nocase {^(?:create|make|design|produce|gen(?:erate)?) (?:an|a)?\s?(([^\s]+)?\s?(?:image|photo|pic(?:ture)?) .+)} $request orig desc
    #regexp -nocase {^(?:create|show|make|draw|design|produce|gen(?:erate)?) (?:me|us)?\s?(?:an|a)?\s?(([^\s]+)?\s?(?:image|photo|pic(?:ture)?) .+)} $request orig desc
    #set regex {^(?:create|show|make|edit|change|modify|draw|(?:re)?design|produce|gen(?:erate)?) (?:me|us|this|the|a)?\s?(?:an|a)?\s?(?:new)?\s?(([^\s]+)?\s?(?:image|photo|variation|pic(?:ture)?):? .+)}
    set regex {^(?:create|show|make|edit|change|modify|draw|(?:re)?design|produce|gen(?:erate)?) (?:me|us|this|the|a)?\s?(?:an|a)?\s?(?:new)?\s?(([^\s]+)?\s?(?:image|photo|variation|pic(?:ture)?):? (?:of||with|that|about)? (.+))}
    regexp -nocase $regex $request orig n1 n2 desc; # -- TODO: build a better pattern!
    
    if {$desc ne ""} { set image 1 }
    #if {$prefix ne ""} { set desc "$prefix $desc" }
    regexp {(https?://[^\s]+\.(?:png|jpeg|jpg))\s?(.*)} $desc -> imagelink desc
    debug 4 "\002ask:image:\002 desc: $desc -- imagelink: $imagelink"
    return "$image [list $desc $imagelink]"
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

# -- check if request string matches blacklist in given chan
proc ask:blacklist {chan query} {
    # -- check for blacklisted strings
    if {$chan in [cfg:get ask:blacklist:chans]} {
        if {[cfg:get ask:blacklist] ne ""} {
            foreach mask [cfg:get ask:blacklist] {
                if {[string match -nocase $mask $query]} {
                    debug 0 "\002ask:blacklist:\002 blacklisted string match in $chan: $mask"
                    return 1; # -- blacklist match
                }
            }
        }
    }
    return 0; # -- no blacklist match
}

# -- expire old conversations to avoid memory leaks
proc ask:expire {var} {
    variable ask
    set var [join $var ]
    if {[info exists ask($var)]} {
        debug 0 "\002ask:expire:\002 expiring ChatGPT conversation for $var"
        unset ask($var)
    }
}

# -- kill timers on rehash
proc ask:killtimer {var} {
    set var [join $var]
    foreach timer [timers] {
        if {[lindex $timer 1] eq "arm::ask:expire"} { 
            if {[lindex $timer 2] eq $var} {
                debug 0 "\002ask:killtimer:\002 killing ChatGPT ask timer for $var"
                killtimer [lindex $timer 2]
            }
        } 
    }
}

# -- credit to: thommey
# -- utf-8 conversion for JSON
# -- TODO: remove if no longer required
proc jsonstr {data} {
	set new ""
	for {set i 0} {$i < [string length $data]} {incr i} {
		set c [string index $data $i]
		set cc [::scan $c %c]
		if {$cc < 0x7e && $c ne "\\" && $cc >= 0x20 && $c ne "\""} {
			append new $c
		} else {
			append new "\\u[format %04x $cc]"
		}
	}
	return "\"$new\""
}

# -- generate a random file
# -- arm::randfile [length] [chars]
# -- length to use is provided by config option if not provided
# -- chars to randomise are defaulted if not provided
proc randfile {{ext "png"} {length ""} {chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"}} {
    set dir [cfg:get ask:path]
    if {$length eq ""} { set length 5 }
    set range [expr {[string length $chars]-1}]
    set avail 0
    while {!$avail} {
        set text ""
        for {set i 0} {$i < $length} {incr i} {
            set pos [expr {int(rand()*$range)}]
            append text [string range $chars $pos $pos]
        }
        if {![file exists "$dir/$text.$ext"]} { set avail 1; break; }
    }
    return $text
}

    set avail 0
    while {!$avail} {
        set length 5; # -- num of captcha ID chars
        set chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        set range [expr {[string length $chars]-1}]
        set code ""
        for {set i 0} {$i < $length} {incr i} {
        set pos [expr {int(rand()*$range)}]
        append code [string range $chars $pos $pos]
        }
        set existcode [db:get code captcha code $code]
        if {$existcode eq ""} { set avail 1; break }
    }

# -- create openai table
db:query "CREATE TABLE IF NOT EXISTS openai (\
	id INTEGER PRIMARY KEY AUTOINCREMENT,\
    type TEXT,\
	cid INTEGER NOT NULL DEFAULT '1',\
    user TEXT,\
	timestamp INT NOT NULL,\
    file TEXT NOT NULL,\
    votes INT NOT NULL DEFAULT '0',\
	desc TEXT NOT NULL
	)"
db:close

# -- require : in nick completion for botnick commands
# -- otherwise bot will be triggered when someone says something like "chief is sentient!"
if {[cfg:get ask:cmdnick *] eq 1} {
    set cfg(char:tab) 1
}

if {![info exists ask:rate:count]} { set ask:rate:count 0 }; # -- rate limit tracker


proc u2a s {
    set res {} 
    foreach i [split $s {}] {
        ::scan $i %c c
        if {$c < 128} {append res $i} else {append res \\u[format %04.4X $c]}
    }
    set res
}


putlog "\[@\] Armour: loaded OpenAI plugin (ask, and, askmode, image)"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------
