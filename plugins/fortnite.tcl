# -- Fornite plugin for Armour
#
# commands:
#   f <user> [all|solo|duo|trio|ltm] [epic|psn|xb1]
#
# greeting variable replacements:
#   %F:ACCOUNT      - account name
#   %F:LEVEL        - account level
#   %F:MATCHES      - matches played
#   %F:WINS         - wins
#   %F:WINRATE      - win percentage
#   %F:KILLS        - kills
#   %F:KD           - kills/deaths
#   %F:TOP3         - top3
#   %F:TOP5         - top5
#   %F:TOP10        - top10
#   %F:HOURS        - hours played
#   %F:KILLSPMIN    - kills per minute
#   %F:KILLSPMATCH  - kills per match
#   %F:OUTLIVED     - players outlived
#   %F:LASTMATCH    - last match completion time ago

# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------

package require http
package require tls
package require json
package require clock::iso8601

set cfg(fn:chan) "#hedonism"
set cfg(fn:api:key) "cff289ba-d604-4a4b-b2a5-9880517dfa6c"
set cfg(fn:url:stats) "https://fortnite-api.com/v2/stats/br/v2"

# -- cronjob to check recent matches (every 1 minute)
bind cron - {*/1 * * * *} { arm::coroexec arm::fn:cron }

# -- users and platforms
# -- TODO: move to DB with a command to attribute player handles to bot usernames
set cfg(fn:user:empus) "onemickl"
set cfg(fn:platform:empus) "epic"
set cfg(fn:user:ratler) "RatlerTV"
set cfg(fn:platform:ratler) "epic"
set cfg(fn:user:skill) "bag0chips"
set cfg(fn:platform:skill) "epic"
set cfg(fn:user:telac) "Telac_DK"
set cfg(fn:platform:telac) "epic"
set cfg(fn:user:jotun) "jotun420"
set cfg(fn:platform:jotun) "epic"
set cfg(fn:user:elpolako) "ThaEP_1221"
set cfg(fn:platform:elpolako) "epic"
set cfg(fn:user:friet) "freejayke"
set cfg(fn:platform:friet) "epic"
set cfg(fn:user:teuk) "teukrai"
set cfg(fn:platform:teuk) "epic"

#set cfg(fn:friends) "onemickl RatlerTV bag0chips Telac_DK Mammaloot GamerTozen jotun420 ThaEP_1221 freejayke sursoedsauce"; # -- other friend handles (i.e., non-authed or non-IRC) to include in common stats
#set cfg(fn:friends) "onemickl RatlerTV bag0chips Telac_DK Mammaloot ThaEP_1221 freejayke"; # -- other friend handles (i.e., non-authed or non-IRC) to include in common stats
set cfg(fn:friends) "onemickl RatlerTV bag0chips Telac_DK Mammaloot ThaEP_1221 insanelygreat teukrai"; # -- other friend handles (i.e., non-authed or non-IRC) to include in common stats
#set cfg(fn:friends) "onemickl bag0chips Telac_DK Mammaloot ThaEP_1221"; # -- other friend handles (i.e., non-authed or non-IRC) to include in common stats
#set cfg(fn:friends) "onemickl Telac_DK Mammaloot ThaEP_1221"; # -- other friend handles (i.e., non-authed or non-IRC) to include in common stats


# -----------------------------------------------------------------------------
# command bindings        plugin        level req.    binds
# -----------------------------------------------------------------------------
set addcmd(f)        {    fn            1            pub msg dcc    }



# ------------------------------------------------------------------------------------------------
# END CONFIG
# ------------------------------------------------------------------------------------------------

loadcmds; # -- load the command

# -- fortnite command
proc fn:cmd:f {0 1 2 3 {4 ""} {5 ""}} {
    variable cfg
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg
    set cmd "f"
    set allowed [userdb:isAllowed $nick $cmd $chan $type]
    
    # -- ensure user has required access for command
    if {![userdb:isAllowed $nick $cmd $chan $type]} { return; }
    lassign [db:get user,id users curnick $nick] user uid
    if {$type ne "chan"} { set chan [userdb:get:chan $user $chan]}; # -- find a logical chan
    set cid [db:get id channels chan $chan]
    set level [db:get level levels cid $cid uid $uid]
    set glevel [db:get level levels cid 1 uid $uid]
    # -- end default proc template

    set defchan $cfg(fn:chan)
    if {![string match -nocase $chan $defchan] && $type eq "chan"} { return; }; # -- only respond for fortnite chan
    set chan $defchan

    lassign $arg account gtype platform input
    if {$account eq ""} {
        reply $type $target "\002usage:\002 f <user> \[all|solo|duo|trio|ltm\] \[epic|psn|xb1\]"
        return;
    }
    if {$gtype eq ""} {
        set gtype "all"
    } else {
        if {$gtype ni "all solo solos duo duos trio trios squad squads ltm"} {
            reply $type $target "\002error:\002 game type must be one of: all, solo, duo, trio, squad, ltm"
            return;
        }
        switch -- $gtype {
            duos   { set gtype "duo" }
            trios  { set gtype "trio" }
            squads { set gtype "squad" }
        }
    }
    if {$platform eq ""} { 
        if {[cfg:get fn:platform:[string tolower $account]] ne ""} {
            debug 0 "fn:cmd:f: fn:platform:[string tolower $account] [cfg:get fn:platform:[string tolower $account]]"
            set platform [cfg:get fn:platform:[string tolower $account]]
        } else {
            set platform "epic"
        }
    } else {
        if {$platform ni "epic psn ps ps4 ps5 xb1 xbox"} {
            reply $type $target "\002error:\002 platform must be one of: epic, psn, xb1"
            return;
        }
        switch -- $platform {
            ps      { set platform "psn" }
            ps4     { set platform "psn" }
            ps5     { set platform "psn" }
            xbox    { set platform "xb1" }
        }
    }
    
    if {[cfg:get fn:user:[string tolower $account]] ne ""} {
        debug 0 "fn:cmd:f: fn:user:[string tolower $account] [cfg:get fn:user:[string tolower $account]]"
        set account [cfg:get fn:user:[string tolower $account]]
    }
    if {$input eq "" || $input eq "all"} { set input "overall" }; # -- default to totals

    set response [fn:query stats $account $platform]

    if {[lindex $response 0] eq 0} {
        # -- error!
        reply $type $target "\002error:\002 [join [lrange $response 1 end]]"
        return;
    }
    set json [lrange $response 1 end]
    #debug 3 "fn:cmd:fn: json: $json"
    set status [dict get $json status]
    if {$status ne "200"} {
        set error [dict get $json error]
        reply $type $target "\002error:\002 $error"
        return;
    }

    set data [dict get $json data]
    set obj_account [dict get $data account]
    set id [dict get $obj_account id]
    set name [dict get $obj_account name]

    set obj_battlepass [dict get $data battlePass]
    set level [dict get $obj_battlepass level]
    set progress [dict get $obj_battlepass progress]
    
    set image [dict get $data image]
    
    set obj_stats [dict get $data stats]

    # -- all platforms
    set obj_stats_all [dict get $obj_stats all]
   
    # score scorePerMin scorePerMatch wins top3 top5 top6 top10 top12 top25 kills killsPermin killsPerMatch deaths kd matches winRate minutesPlayed playersOutlived lastModified
    #debug 0 "\002gtype:\002 $gtype"
    # -- all platforms; all match totals
    if {$gtype eq "all"} {
        set obj_stats_all_overall [dict get $obj_stats_all overall]
        #putlog "obj_stats_all_overall keys: [dict keys $obj_stats_all_overall]"
        foreach key [dict keys $obj_stats_all_overall] {
            #debug 3 "fn:cmd:f: setting stats_all_overall($key): [dict get $obj_stats_all_overall $key]"
            set stats_all_overall($key) [dict get $obj_stats_all_overall $key]
        }
        foreach t {wins top3 top5 top6 top10 top12 top25 kills matches winRate kd minutesPlayed killsPerMin killsPerMatch playersOutlived lastModified} {
            if {![info exists stats_all_overall($t)]} { set stats_all_overall($t) 0 }
        }
        #putlog "keys in stats_all_overall: [array names stats_all_overall]"
    }

    # -- all platforms; solo matches
    if {$gtype eq "solo"} {
        set obj_stats_all_solo [dict get $obj_stats_all solo]
        if {$obj_stats_all_solo ne "null"} {
            foreach key [dict keys $obj_stats_all_solo] {
                #debug 3 "fn:cmd:f: setting stats_all_solo($key): [dict get $obj_stats_all_solo $key]"
                set stats_all_solo($key) [dict get $obj_stats_all_solo $key]
            }
            foreach t {wins top3 top5 top6 top10 top12 top25 kills matches winRate kd minutesPlayed killsPerMin killsPerMatch playersOutlived lastModified} {
                if {![info exists stats_all_solo($t)]} { set stats_all_solo($t) 0 }
            }
        } else { reply $type $target "\002error\002: no stats for \002$account\002 with game type \002$gtype\002"; return; }
        #putlog "keys in stats_all_solo: [array names stats_all_solo]"
    }

    # -- all platforms; duo matches
    if {$gtype eq "duo"} {
        set obj_stats_all_duo [dict get $obj_stats_all duo]
        if {$obj_stats_all_duo ne "null"} {
            foreach key [dict keys $obj_stats_all_duo] {
                #debug 3 "fn:cmd:f: setting stats_all_duo($key): [dict get $obj_stats_all_duo $key]"
                set stats_all_duo($key) [dict get $obj_stats_all_duo $key]
            }
            foreach t {wins top3 top5 top6 top10 top12 top25 kills matches winRate kd minutesPlayed killsPerMin killsPerMatch playersOutlived lastModified} {
                if {![info exists stats_all_duo($t)]} { set stats_all_duo($t) 0 }
            }
        } else { reply $type $target "\002error\002: no stats for \002$account\002 with game type \002$gtype\002"; return; }
        #putlog "keys in stats_all_duo: [array names stats_all_duo]"
    }

    # -- all platforms; trio matches
    if {$gtype eq "trio"} {
        set obj_stats_all_trio [dict get $obj_stats_all trio]
        #putlog "obj_stats_all_trio: $obj_stats_all_trio"
        if {$obj_stats_all_trio ne "null"} {
            foreach key [dict keys $obj_stats_all_trio] {
                #debug 3 "fn:cmd:f: setting stats_all_trio($key): [dict get $obj_stats_all_trio $key]"
                set stats_all_trio($key) [dict get $obj_stats_all_trio $key]
            }
            foreach t {wins top3 top5 top6 top10 top12 top25 kills matches winRate kd minutesPlayed killsPerMin killsPerMatch playersOutlived lastModified} {
                if {![info exists stats_all_trio($t)]} { set stats_all_trio($t) 0 }
            }
        } else { reply $type $target "\002error\002: no stats for \002$account\002 with game type \002$gtype\002"; return; }
        #putlog "keys in stats_all_trio: [array names stats_all_trio]"
    }

    # -- all platforms; squad matches
    if {$gtype eq "squad"} {
        set obj_stats_all_squad [dict get $obj_stats_all squad]
        if {$obj_stats_all_squad ne "null"} {
            foreach key [dict keys $obj_stats_all_squad] {
                #debug 3 "fn:cmd:f: setting stats_all_squad($key): [dict get $obj_stats_all_squad $key]"
                set stats_all_squad($key) [dict get $obj_stats_all_squad $key]
            }
            foreach t {wins top3 top5 top6 top10 top12 top25 kills matches winRate kd minutesPlayed killsPerMin killsPerMatch playersOutlived lastModified} {
                if {![info exists stats_all_squad($t)]} { set stats_all_squad($t) 0 }
            }
        } else { reply $type $target "\002error\002: no stats for \002$account\002 with game type \002$gtype\002"; return; }
        #putlog "keys in stats_all_squad: [array names stats_all_squad]"
    }

    # -- all platforms; ltm matches
    if {$gtype eq "ltm"} {
        set obj_stats_all_ltm [dict get $obj_stats_all ltm]
        if {$obj_stats_all_ltm ne "null"} {
            foreach key [dict keys $obj_stats_all_ltm] {
                #debug 3 "fn:cmd:f: setting stats_all_ltm($key): [dict get $obj_stats_all_ltm $key]"
                set stats_all_ltm($key) [dict get $obj_stats_all_ltm $key]
            }
            foreach t {wins top3 top5 top6 top10 top12 top25 kills matches winRate kd minutesPlayed killsPerMin killsPerMatch playersOutlived lastModified} {
                if {![info exists stats_all_ltm($t)]} { set stats_all_ltm($t) 0 }
            }
        } else { reply $type $target "\002error\002: no stats for \002$account\002 with game type \002$gtype\002"; return; }
        #putlog "keys in stats_all_ltm: [array names stats_all_ltm]"
    }

    if {$gtype eq "all"} {
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Total Matches Played:\002 $stats_all_overall(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_overall(wins) ($stats_all_overall(winRate)%) -- \002Kills:\002 $stats_all_overall(kills) (\002Kills/Deaths:\002 $stats_all_overall(kd)) -- \002Top 3:\002 $stats_all_overall(top3) -- \002Top 5:\002 $stats_all_overall(top5) -- \002Top 10:\002 $stats_all_overall(top10)"
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Total Hours Played:\002 [expr $stats_all_overall(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_overall(killsPerMin) -- \002Kills p/Match:\002 $stats_all_overall(killsPerMatch) -- \002Players Outlived:\002 $stats_all_overall(playersOutlived) -- \002Last Match Completed:\002 [userdb:timeago [clock::iso8601 parse_time $stats_all_overall(lastModified)]] ago."
        reply $type $target "\002\[\002$name\002\]\002 \002Total Matches Played:\002 $stats_all_overall(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_overall(wins) ($stats_all_overall(winRate)%) -- \002Kills:\002 $stats_all_overall(kills) (\002Kills/Deaths:\002 $stats_all_overall(kd)) -- \002Top 3:\002 $stats_all_overall(top3) -- \002Top 5:\002 $stats_all_overall(top5) -- \002Top 10:\002 $stats_all_overall(top10)"
        if {$stats_all_overall(lastModified) ne "0"} { set timeago "[userdb:timeago [clock::iso8601 parse_time $stats_all_overall(lastModified)]] ago." } else { set timeago "(never)" }
        reply $type $target "\002\[\002$name\002\]\002 \002Total Hours Played:\002 [expr $stats_all_overall(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_overall(killsPerMin) -- \002Kills p/Match:\002 $stats_all_overall(killsPerMatch) -- \002Players Outlived:\002 $stats_all_overall(playersOutlived) -- \002Last Match Completed:\002 $timeago"
    } elseif {$gtype eq "solo"} {
        debug 0 "stats_all_solo(lastModified): $stats_all_solo(lastModified)"
        if {$stats_all_solo(lastModified) ne "0"} { set timeago "[userdb:timeago [clock::iso8601 parse_time $stats_all_solo(lastModified)]] ago." } else { set timeago "(never)" }
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Solo Matches Played:\002 $stats_all_solo(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_solo(wins) ($stats_all_solo(winRate)%) -- \002Kills:\002 $stats_all_solo(kills) (\002Kills/Deaths:\002 $stats_all_solo(kd)) -- \002Top 3:\002 $stats_all_solo(top3) -- \002Top 5:\002 $stats_all_solo(top5) -- \002Top 10:\002 $stats_all_solo(top10)"
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Solo Hours Played:\002 [expr $stats_all_solo(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_solo(killsPerMin) -- \002Kills p/Match:\002 $stats_all_solo(killsPerMatch) -- \002Players Outlived:\002 $stats_all_solo(playersOutlived) -- \002Last Match Completed:\002 $timeago"
        reply $type $target "\002\[\002$name\002\]\002 \002Solo Matches Played:\002 $stats_all_solo(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_solo(wins) ($stats_all_solo(winRate)%) -- \002Kills:\002 $stats_all_solo(kills) (\002Kills/Deaths:\002 $stats_all_solo(kd)) -- \002Top 3:\002 $stats_all_solo(top3) -- \002Top 5:\002 $stats_all_solo(top5) -- \002Top 10:\002 $stats_all_solo(top10)"
        reply $type $target "\002\[\002$name\002\]\002 \002Solo Hours Played:\002 [expr $stats_all_solo(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_solo(killsPerMin) -- \002Kills p/Match:\002 $stats_all_solo(killsPerMatch) -- \002Players Outlived:\002 $stats_all_solo(playersOutlived) -- \002Last Match Completed:\002 $timeago"
    } elseif {$gtype eq "duo"} {
        if {$stats_all_duo(lastModified) ne "0"} { set timeago "[userdb:timeago [clock::iso8601 parse_time $stats_all_duo(lastModified)]] ago." } else { set timeago "(never)" }
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Duo Matches Played:\002 $stats_all_duo(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_duo(wins) ($stats_all_duo(winRate)%) -- \002Kills:\002 $stats_all_duo(kills) (\002Kills/Deaths:\002 $stats_all_duo(kd)) -- \002Top 3:\002 $stats_all_duo(top3) -- \002Top 5:\002 $stats_all_duo(top5) -- \002Top 10:\002 $stats_all_duo(top10)"
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Duo Hours Played:\002 [expr $stats_all_duo(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_duo(killsPerMin) -- \002Kills p/Match:\002 $stats_all_duo(killsPerMatch) -- \002Players Outlived:\002 $stats_all_duo(playersOutlived) -- \002Last Match Completed:\002 $timeago"
        reply $type $target "\002\[\002$name\002\]\002 \002Duo Matches Played:\002 $stats_all_duo(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_duo(wins) ($stats_all_duo(winRate)%) -- \002Kills:\002 $stats_all_duo(kills) (\002Kills/Deaths:\002 $stats_all_duo(kd)) -- \002Top 3:\002 $stats_all_duo(top3) -- \002Top 5:\002 $stats_all_duo(top5) -- \002Top 10:\002 $stats_all_duo(top10)"
        reply $type $target "\002\[\002$name\002\]\002 \002Duo Hours Played:\002 [expr $stats_all_duo(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_duo(killsPerMin) -- \002Kills p/Match:\002 $stats_all_duo(killsPerMatch) -- \002Players Outlived:\002 $stats_all_duo(playersOutlived) -- \002Last Match Completed:\002 $timeago"
    } elseif {$gtype eq "trio"} {
        if {$stats_all_trio(lastModified) ne "0"} { set timeago "[userdb:timeago [clock::iso8601 parse_time $stats_all_trio(lastModified)]] ago." } else { set timeago "(never)" }
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Trio Matches Played:\002 $stats_all_trio(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_trio(wins) ($stats_all_trio(winRate)%) -- \002Kills:\002 $stats_all_trio(kills) (\002Kills/Deaths:\002 $stats_all_trio(kd)) -- \002Top 3:\002 $stats_all_trio(top3) -- \002Top 5:\002 $stats_all_trio(top5) -- \002Top 10:\002 $stats_all_trio(top10)"
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Trio Hours Played:\002 [expr $stats_all_trio(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_trio(killsPerMin) -- \002Kills p/Match:\002 $stats_all_trio(killsPerMatch) -- \002Players Outlived:\002 $stats_all_trio(playersOutlived) -- \002Last Match Completed:\002 $timeago"
        reply $type $target "\002\[\002$name\002\]\002 \002Trio Matches Played:\002 $stats_all_trio(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_trio(wins) ($stats_all_trio(winRate)%) -- \002Kills:\002 $stats_all_trio(kills) (\002Kills/Deaths:\002 $stats_all_trio(kd)) -- \002Top 3:\002 $stats_all_trio(top3) -- \002Top 5:\002 $stats_all_trio(top5) -- \002Top 10:\002 $stats_all_trio(top10)"
        reply $type $target "\002\[\002$name\002\]\002 \002Trio Hours Played:\002 [expr $stats_all_trio(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_trio(killsPerMin) -- \002Kills p/Match:\002 $stats_all_trio(killsPerMatch) -- \002Players Outlived:\002 $stats_all_trio(playersOutlived) -- \002Last Match Completed:\002 $timeago"
    } elseif {$gtype eq "squad"} {
        if {$stats_all_squad(lastModified) ne "0"} { set timeago "[userdb:timeago [clock::iso8601 parse_time $stats_all_squad(lastModified)]] ago." } else { set timeago "(never)" }
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Squad Matches Played:\002 $stats_all_squad(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_squad(wins) ($stats_all_squad(winRate)%) -- \002Kills:\002 $stats_all_squad(kills) (\002Kills/Deaths:\002 $stats_all_squad(kd)) -- \002Top 3:\002 $stats_all_squad(top3) -- \002Top 5:\002 $stats_all_squad(top5) -- \002Top 10:\002 $stats_all_squad(top10)"
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002Squad Hours Played:\002 [expr $stats_all_squad(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_squad(killsPerMin) -- \002Kills p/Match:\002 $stats_all_squad(killsPerMatch) -- \002Players Outlived:\002 $stats_all_squad(playersOutlived) -- \002Last Match Completed:\002 $timeago"
        reply $type $target "\002\[\002$name\002\]\002 \002Squad Matches Played:\002 $stats_all_squad(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_squad(wins) ($stats_all_squad(winRate)%) -- \002Kills:\002 $stats_all_squad(kills) (\002Kills/Deaths:\002 $stats_all_squad(kd)) -- \002Top 3:\002 $stats_all_squad(top3) -- \002Top 5:\002 $stats_all_squad(top5) -- \002Top 10:\002 $stats_all_squad(top10)"
        reply $type $target "\002\[\002$name\002\]\002 \002Squad Hours Played:\002 [expr $stats_all_squad(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_squad(killsPerMin) -- \002Kills p/Match:\002 $stats_all_squad(killsPerMatch) -- \002Players Outlived:\002 $stats_all_squad(playersOutlived) -- \002Last Match Completed:\002 $timeago."       
    } elseif {$gtype eq "ltm"} {
        if {$stats_all_ltm(lastModified) ne "0"} { set timeago "[userdb:timeago [clock::iso8601 parse_time $stats_all_ltm(lastModified)]] ago." } else { set timeago "(never)" }
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002LTM Matches Played:\002 $stats_all_ltm(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_ltm(wins) ($stats_all_ltm(winRate)%) -- \002Kills:\002 $stats_all_ltm(kills) (\002Kills/Deaths:\002 $stats_all_ltm(kd)) -- \002Top 3:\002 $stats_all_ltm(top3) -- \002Top 5:\002 $stats_all_ltm(top5) -- \002Top 10:\002 $stats_all_ltm(top10)"
        debug 0 "fn:cmd:f: \002\[\002$name\002\]\002 \002LTM Hours Played:\002 [expr $stats_all_ltm(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_ltm(killsPerMin) -- \002Kills p/Match:\002 $stats_all_ltm(killsPerMatch) -- \002Players Outlived:\002 $stats_all_ltm(playersOutlived) -- \002Last Match Completed:\002 $timeago"
        reply $type $target "\002\[\002$name\002\]\002 \002LTM Matches Played:\002 $stats_all_ltm(matches) -- \002Level:\002 $level -- \002Wins:\002 $stats_all_ltm(wins) ($stats_all_ltm(winRate)%) -- \002Kills:\002 $stats_all_ltm(kills) (\002Kills/Deaths:\002 $stats_all_ltm(kd)) -- \002Top 3:\002 $stats_all_ltm(top3) -- \002Top 5:\002 $stats_all_ltm(top5) -- \002Top 10:\002 $stats_all_ltm(top10)"
        reply $type $target "\002\[\002$name\002\]\002 \002LTM Hours Played:\002 [expr $stats_all_ltm(minutesPlayed) / 60] -- \002Kills p/Min:\002 $stats_all_ltm(killsPerMin) -- \002Kills p/Match:\002 $stats_all_ltm(killsPerMatch) -- \002Players Outlived:\002 $stats_all_ltm(playersOutlived) -- \002Last Match Completed:\002 $timeago"
    }
}

proc fn:query {action account {platform "epic"}} {
     variable cfg
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]
    set headers [list Authorization $cfg(fn:api:key)]
    
    set query [http::formatQuery name $account accountType $platform]
    set url "$cfg(fn:url:$action)?$query"
    debug 5 "fn:query: url: $url"

    coroexec http::geturl $url -headers $headers -keepalive 1 -timeout 5000 -command [info coroutine]
    set tok [yield]

    set error ""; # -- TODO: fix error handling
    #debug 5 "fn:query: checking for errors...(error: $error -- tok: $tok)"
    #if {[string match -nocase "*couldn't open socket*" $error]} {
    #    debug 0 "\002fn:query:\002 could not open socket to: $cfg(fn:url:$action) *]"
    #    http::cleanup $tok
    #    return "0 [list "could not open socket"]";
    #} 

    # -- check for HTTP code 5xx responses
    set ncode [http::ncode $tok]
    debug 5 "fn:query: checking for ncode...(ncode: $ncode)"
    if {[string index $ncode 0] eq "5"} {
        debug 4 "\002fn:query\002: HTTP error code: $ncode"
        #reply msg $cfg(chan:report) "\002fn:query:\002 error code: \002$ncode\002 (\002action:\002 $action -- \002account:\002 $account)"
        return "0 [list "HTTP error code $ncode"]"
    } elseif {$ncode eq "404"} {
        debug 4 "\002fn:query\002: no such user found"
        return "0 [list "account not found."]"
    }

    set status [http::status $tok]
    debug 5 "fn:query: checking for status...(status: $status)"

    if {$status eq "timeout"} { 
        debug 0 "\002fn:query:\002 connection to $cfg(fn:url:$action) has timed out."
        http::cleanup $tok
        return "0 [list "connect timeout"]";
    } elseif {$status eq "error"} {
        debug 0 "\002fn:query:\002 connection to $cfg(fn:url:$action) has error."
        http::cleanup $tok
        return "0 [list "connect error"]";
    }
    
    set data [http::data $tok]
    debug 5 "fn:query: checking for data...(data: $data)"
    if {$data eq ""} {
        debug 0 "\002fn:query:\002 error: no data in HTTP response."
        return "0 [list "no data in HTTP response"]"
    }
    
    #exec echo $data > json.txt; # -- DEBUG
    set json [::json::json2dict $data]
    foreach {name object} $json {
        set out($name) $object
        #debug 0 "\002fn:query:\002 name: $name object: $object"
        if {$name eq "error"} {
            # -- error!
            return "0 $object"
        }
    }
    http::cleanup $tok
    return "1 $json"
}

proc fn:greet {chan user greet} {
    if {[string match "*%F:*" $greet] && [string match -nocase [cfg:get fn:chan $chan] $chan]} {
        # -- only do an API stats lookup if the greeting uses Fortnite variables
        debug 4 "\002fn:greet:\002 fortnite variables used and chan is $chan (fn:chan)"
        # %F:ACCOUNT      - account name
        # %F:LEVEL        - account level
        # %F:MATCHES      - matches played
        # %F:WINS         - wins
        # %F:WINRATE      - win percentage
        # %F:KILLS        - kills
        # %F:KD           - kills/deaths
        # %F:TOP3         - top3
        # %F:TOP5         - top5
        # %F:TOP10        - top10
        # %F:HOURS        - hours played
        # %F:KILLSPMIN    - kills per minute
        # %F:KILLSPMATCH  - kills per match
        # %F:OUTLIVED     - players outlived
        # %F:LASTMATCH    - last match completion time ago
        set response [fn:query stats [cfg:get fn:user:[string tolower $user]] [cfg:get fn:platform:[string tolower $user]]]
        if {[lindex $response 0] eq 0} {
            # -- error!
            debug 0 "fn:greet: fortnite API request failed: [join [lrange $response 1 end]]"
            return;
        }
        set json [lrange $response 1 end]
        set status [dict get $json status]
        if {$status ne "200"} {
            set error [dict get $json error]
            debug 0 "fn:greet: fortnite API request failed: $error"
            reply $type $target "\002error:\002 $error"
            return;
        }

        set data [dict get $json data]
        set obj_account [dict get $data account]
        set id [dict get $obj_account id]
        set name [dict get $obj_account name]

        set obj_battlepass [dict get $data battlePass]
        set level [dict get $obj_battlepass level]
        set progress [dict get $obj_battlepass progress]
        
        set image [dict get $data image]
        set obj_stats [dict get $data stats]

        # -- all platforms
        set obj_stats_all [dict get $obj_stats all]
    
        # -- all platforms; all match totals
        set obj_stats_all_overall [dict get $obj_stats_all overall]
        #putlog "obj_stats_all_overall keys: [dict keys $obj_stats_all_overall]"
        foreach key [dict keys $obj_stats_all_overall] {
            debug 5 "fn:cmd:f: setting stats_all_overall($key): [dict get $obj_stats_all_overall $key]"
            set stats_all_overall($key) [dict get $obj_stats_all_overall $key]
        }
        foreach t {wins top3 top5 top6 top12 top25 kills matches} {
            if {![info exists stats_all_overall($t)]} { set stats_all_overall($t) 0 }
        }
        # score scorePerMin scorePerMatch wins top3 top5 top6 top10 top12 top25 kills kllsPerMin killsPerMatch deaths kd matches winRate minutesPlayed playersOutlived lastModified
        regsub -all {%F:ACCOUNT} $greet "\002$name\002" greet
        regsub -all {%F:LEVEL} $greet "\002$level\002" greet
        regsub -all {%F:MATCHES} $greet "\002$stats_all_overall(matches)\002" greet
        regsub -all {%F:WINS} $greet "\002$stats_all_overall(wins)\002" greet
        regsub -all {%F:WINRATE} $greet "\002$stats_all_overall(winRate)\002" greet
        regsub -all {%F:KILLS} $greet "\002$stats_all_overall(kills)\002" greet
        regsub -all {%F:KD} $greet "\002$stats_all_overall(kd)\002" greet
        regsub -all {%F:TOP3} $greet "\002$stats_all_overall(top3)\002" greet
        regsub -all {%F:TOP5} $greet "\002$stats_all_overall(top5)\002" greet
        regsub -all {%F:TOP10} $greet "\002$stats_all_overall(top10)\002" greet
        regsub -all {%F:HOURS} $greet "\002[expr $stats_all_overall(minutesPlayed) / 60]\002" greet
        regsub -all {%F:KILLSPMIN} $greet "\002$stats_all_overall(killsPerMin)\002" greet
        regsub -all {%F:KILLSPMATCH} $greet "\002$stats_all_overall(killsPerMatch)\002" greet
        regsub -all {%F:OUTLIVED} $greet "\002$stats_all_overall(playersOutlived)\002" greet
        regsub -all {%F:LASTMATCH} $greet "\002[userdb:timeago [clock::iso8601 parse_time $stats_all_overall(lastModified)]]\002" greet
        debug 0 "fn:greet: updated greet for $user in $chan with any Fortnite variables"
    }
    return $greet
}

# -- cronjob to output gameplay results
proc fn:cron {minute hour day month weekday} {
    variable cfg
    variable globstats;    # -- track fortnite per user stats with global variable
    variable announceGame; # -- track last announcements per game timestamp to avoid repeats
    set start [clock clicks]
    set chan [cfg:get fn:chan]
    array set commonGame [list]; # -- list of handles last playing together (by lastModified)
    set listOfTSKeys [list];     # -- list of timestamp keys which store >2= users recently playing together
    if {![info exists globstats]} { set globstats [list] }
    if {![info exists stats_diff]} { set stats_diff [list] }
    set users ""
    #foreach nick [chanlist $chan] {
    #    set user [db:get user users curnick $nick]
    #    if {$user eq ""} { debug 5 "fn:cron: no user for nick: $nick"; continue; }; # -- not authed
    #    if {![info exists cfg(fn:user:[string tolower $user])]} { debug 0 "no handle: $user"; continue; }; # -- no associated fortnite handle
    #    if {[lsearch -nocase $users $user] eq -1} { lappend users $cfg(fn:user:[string tolower $user]) }; # -- cater to multiple nicks on same user
    #}

    debug 5 "fn:cron: cfg(fn:friends): $cfg(fn:friends)"
    # -- include additional non-IRC users
    foreach handle $cfg(fn:friends) {
        if {[info exists cfg(fn:user:[string tolower $handle])]} {
            if {[lsearch -nocase $users $cfg(fn:user:[string tolower $handle])] ne -1} { continue; }
        }
        set cfg(fn:user:[string tolower $handle]) $handle;
        set cfg(fn:platform:[string tolower $handle]) "epic"; 
        lappend users $handle
    }
    debug 5 "fn:cron: users: $users"
    foreach user $users {
        #debug 0 "fn:cron: user \002$user\002 has fortnite handle"
        set platform [cfg:get fn:platform:[string tolower $user]]
        set response [fn:query stats [cfg:get fn:user:[string tolower $user]] $platform]
        if {[lindex $response 0] eq 0} { continue; }; # -- http query error

        set json [lrange $response 1 end]
        set status [dict get $json status]
        if {$status ne "200"} { continue; }; # - http response error

        set data [dict get $json data]

        set obj_account [dict get $data account]
        set id [dict get $obj_account id]
        set name [dict get $obj_account name]  
        
        # -- get level
        set obj_battlepass [dict get $data battlePass]
        set level [dict get $obj_battlepass level]
        if {[dict exists $globstats $name level]} {
            if {$level ne [dict get $globstats $name level]} {
                # -- level has changed
                set val [dict get $globstats $name level]
                set diff [expr $level - $val];
                debug 0 "\002fn:cron:\002 name: $name -- key: level -- diff: $diff"
                #reply msg $cfg(chan:report) "\002fn:cron:\002 name: $name -- key: level -- diff: $diff"
                dict set stats_diff $name level $diff; # -- store the diff value                
            }
        }
        dict set globstats $name level $level; # -- update the global stat tracker
        # -- end level
        
        # -- get the stats for all platforms
        set obj_stats [dict get $data stats]
        set obj_stats_all [dict get $obj_stats all];                    # -- stats from all platforms (all/keyboardMouse/gamepad/touch)
        set obj_stats_all_overall [dict get $obj_stats_all overall];    # -- all platforms; all matches
        set obj_stats_all_solo [dict get $obj_stats_all solo];          # -- all platforms; solo amtches
        set obj_stats_all_duo [dict get $obj_stats_all duo];            # -- all platforms; duo matches
        set obj_stats_all_trio [dict get $obj_stats_all trio];          # -- all platforms; trio matches
        set obj_stats_all_squad [dict get $obj_stats_all squad];        # -- all platforms; squad matches
        set obj_stats_all_ltm [dict get $obj_stats_all ltm];            # -- all platforms; LTM matches

        foreach key [dict keys $obj_stats_all_overall] {
            if {[dict exists $globstats $name $key]} {
                # -- stat already tracked for user
                if {$key eq "lastModified"} {
                    # -- ISO8601 timestamp
                    set val_glob [dict get $globstats $name lastModified]
                    set val [clock::iso8601 parse_time [dict get $obj_stats_all_overall lastModified]]
                } else {
                    set val_glob [dict get $globstats $name $key]
                    set val [dict get $obj_stats_all_overall $key]
                }
                if {$val_glob ne $val && $key in "level kills wins top3 top5 top6 top10 top12 top25"} {
                    # -- new value is different to stored stat for user
                    set diff [expr $val - $val_glob];
                    debug 0 "\002fn:cron:\002 name: $name -- key: $key -- diff: $diff"
                    #reply msg $cfg(chan:report) "\002fn:cron:\002 name: $name -- key: $key -- diff: $diff"
                    dict set stats_diff $name $key $diff; # -- store the diff value 
                }
            }
            if {$key eq "lastModified"} { set val [clock::iso8601 parse_time [dict get $obj_stats_all_overall lastModified]] } \
            else { set val [dict get $obj_stats_all_overall $key] }
            debug 5 "\002fn:cron:\002 setting dict: globstats $name $key $val"
            dict set globstats $name $key $val; # -- update the global stat tracker 
        }

        # -- calculate last modifications to find what type of game the last one was
        if {![dict exists $obj_stats_all_solo lastModified]} { dict set globstats $name solo_lastmodif "" } \
        else { dict set globstats $name solo_lastmodif [clock::iso8601 parse_time [dict get $obj_stats_all_solo lastModified]] }
        if {![dict exists $obj_stats_all_duo lastModified]} { dict set globstats $name duo_lastmodif "" } \
        else { dict set globstats $name duo_lastmodif [clock::iso8601 parse_time [dict get $obj_stats_all_duo lastModified]] }
        if {![dict exists $obj_stats_all_trio lastModified]} { dict set globstats $name trio_lastmodif "" } \
        else { dict set globstats $name trio_lastmodif [clock::iso8601 parse_time [dict get $obj_stats_all_trio lastModified]] }
        if {![dict exists $obj_stats_all_squad lastModified]} { dict set globstats $name squad_lastmodif "" } \
        else { dict set globstats $name squad_lastmodif [clock::iso8601 parse_time [dict get $obj_stats_all_squad lastModified]] }
        if {![dict exists $obj_stats_all_ltm lastModified]} { dict set globstats $name ltm_lastmodif "" } \
        else { dict set globstats $name ltm_lastmodif [clock::iso8601 parse_time [dict get $obj_stats_all_ltm lastModified]] }

        set lastmodif [dict get $globstats $name lastModified]; # -- lastmodified overall
        if {$lastmodif eq [dict get $globstats $name solo_lastmodif]} { dict set globstats $name lastGame "Solo" } \
        elseif {$lastmodif eq [dict get $globstats $name duo_lastmodif]} { dict set globstats $name lastGame "Duo" } \
        elseif {$lastmodif eq [dict get $globstats $name trio_lastmodif]} { dict set globstats $name lastGame "Trio" } \
        elseif {$lastmodif eq [dict get $globstats $name squad_lastmodif]} { dict set globstats $name lastGame "Squad" } \
        elseif {$lastmodif eq [dict get $globstats $name ltm_lastmodif]} { dict set globstats $name lastGame "LTM" } \
        else { dict set globstats $name lastGame "unknown"; putlog "unknown game type for $name" }; # -- unknown game type (this shouldn't happen)
        
        # -- cater to missing entries in API response (i.e. missing wins/kills/matches)
        foreach t {wins top3 top5 top6 top10 top12 top25 kills matches} {
            if {![dict exists $globstats $name $t]} { dict set globstats $name $t 0 }
        }

        # -- build list of users against timestamps for those that played together recently
        if {[dict exists $globstats $name lastModified]} {
            set ts [dict get $globstats $name lastModified]
            if {$ts eq 0} { continue; }
            lappend commonGame($ts) $name
            if {[llength $commonGame($ts)] >= 1} {
                # -- at least 2 players authed in-channel played the last game together
                if {$commonGame($ts) ni $listOfTSKeys && $ts ni $listOfTSKeys} {
                    lappend listOfTSKeys $ts
                }
            }
        }
    }


    # -- now, process the data:
    # -- we know the list of timestamps keys that contain players who recently played together: listOfTSKeys(ts)
    # -- and, we know the users that played that game: commonGame(ts)
    # -- TEST DATA --
    #dict set stats_diff onemickl wins 1
    #dict set stats_diff onemickl level 1
    #dict set stats_diff onemickl kills 4
    #dict set stats_diff Mammaloot level 1
    #dict set stats_diff Mammaloot kills 10
    #dict set stats_diff Telac_DK level 1
    #dict set stats_diff Telac_DK kills 6
    # -- END TEST DATA --
    foreach ts $listOfTSKeys {
        debug 5 "looping listOfTSKeys: ts: $ts - common game pre-sorted users: $commonGame($ts)"
        #reply msg $cfg(chan:report) "looping listOfTSKeys: ts: $ts - common game pre-srted users: $commonGame($ts)"
        set users $commonGame($ts)
        if {[info exists announceGame]} {
            if {[dict exists $announceGame $ts]} { debug 5 "\002fn:cron: dict 'announceGame $ts' already exists!\002"; continue; }
        }
        set out ""; set outcome ""; set result "";

        # -- sort users by kills (descending)
        set killSorted ""; set userKills ""
        foreach user $users {
            if {![dict exists $stats_diff $user kills]} { dict set userKills $user 0 } \
            else { dict set userKills $user [dict get $stats_diff $user kills] }
        }
        set killSorted [dict keys [lsort -decreasing -integer -stride 2 -index 1 $userKills]]

        # -- process the users sorted by kills
        debug 0 "\002fn:cron:\002 new game detected (ts: $ts) -- users to process: \002[join $killSorted]\002 (API queries took \002[runtime $start]\002 msec)"
        #reply msg $cfg(chan:report) "\002fn:cron:\002 new game detected (ts: $ts) -- users to process: \002[join $killSorted]\002 (API queries took \002[runtime $start]\002 msec)"
        set outcomes [list]
        foreach user $killSorted {
            #putlog "looping users commonGame($ts): user: $user"
            if {[dict exists $stats_diff $user]} {
                debug 3 "fn:cron: looping \002$user\002 -- dict get stats_diff $user: [dict get $stats_diff $user]"
            }
            append out "\002$user\002"
            if {[dict exists $stats_diff $user]} {
                append out " ("
                foreach {key val} [dict get $stats_diff $user] {
                    if {$key in "wins top3 top5 top6 top10 top12 top25"} {
                        if {$key ni $outcomes} { lappend outcomes $key }
                        #reply msg $cfg(chan:report) "name: $user -- ts: $ts -- setting outcome: $key"
                        set outcome $key; 
                        continue;
                    }
                    append out "$key: \002+$val\002 "
                }
                set out [string trimright $out " "]
                append out ")"
            }
            regsub -all { \(\)$} $out "" out
            append out ", "
        }
        #putlog "test 3 - outcomes: \002$outcomes\002"
        set out [string trimright $out ", "]
        if {"wins" in $outcomes} { set result "\002\x0308Victory Royale\x03\002" } \
        elseif {"top3" in $outcomes} {set result "\002Top 3\002" } \
        elseif {"top5" in $outcomes} {set result "\002Top 5\002" } \
        elseif {"top6" in $outcomes} {set result "\002Top 6\002" } \
        elseif {"top10" in $outcomes} {set result "\002Top 10\002" } \
        elseif {"top12" in $outcomes} {set result "\002Top 12\002" } \
        elseif {"top25" in $outcomes} {set result "\002Top 25\002" } \
        else { set result "Average" }
        #putlog "out: \"$out\""
        if {![string match "*(*" $out]} {
            set result "\002\x0305Terrible\x03\002"
            set msg "with \002zero\002 kills or level bumps from anyone (\002[join $killSorted ", "]\002)" 
        } else { set msg "with $out" }; 
        #if {$out ne ""} { set msg "with $out" } else { set msg "with \002\x0305zero\x03\002 kills or level bumps from anyone (\002[join $killSorted ", "]\002)" }
        set game [dict get $globstats $user lastGame]
        if {[llength $out] ne 1} {
            debug 0 "fn:cron: \002\[Gameplay ($game) -\002 $result\002\]\002 $msg"                
            if {[llength [split $msg ","]] eq 1 && [string match "*insanelygreat*" $msg] eq 1} {
                # -- Poyan played without us
                set chan [cfg:get chan:report];
                #set chan "#phat";
            }
            reply msg $chan "\002\[Gameplay ($game) -\002 $result\002\]\002 $msg"
        }
        dict set announceGame $ts 1; # -- track announcement sent
    }
    unset listOfTSKeys
    unset commonGame
}

#if {[info exists announceGame]} { unset announceGame }

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------

putlog "\[@\] Fortnite support functions loaded."
