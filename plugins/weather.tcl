# ------------------------------------------------------------------------------------------------
# Weather Plugin
# ------------------------------------------------------------------------------------------------
#
# Weather information provided via API from https://www.openweathermap.org
#
# ------------------------------------------------------------------------------------------------
namespace eval arm {
# ------------------------------------------------------------------------------------------------


package require json
package require http 2
package require tls 1.7

# -- shortcut
proc arm:cmd:w {0 1 2 3 {4 ""} {5 ""}} { arm:cmd:weather $0 $1 $2 $3 $4 $5 }

# -- cmd: weather
proc arm:cmd:weather {0 1 2 3 {4 ""} {5 ""}} {
    variable dbchans
    lassign [proc:setvars $0 $1 $2 $3 $4 $5] type stype target starget nick uh hand source chan arg 

    set cmd "weather"

    lassign [db:get id,user users curnick $nick] uid user
    set chan [userdb:get:chan $user $chan]; # -- predict chan when not given

    set cid [db:get id channels chan $chan]
    if {$cid eq ""} { set cid 1 }; # -- default to global chan when command used in an unregistered chan

    set ison [arm::db:get value settings setting "weather" cid $cid]
    if {$ison ne "on"} {
        # -- weather not enabled on chan
        debug 1 "\002cmd:cmd:weather:\002 weather not enabled on $chan. to enable, use: \002modchan $chan weather on\002"
        return;
    }

    # -- ensure user has required access for command
	set allowed [cfg:get weather:allow]; # -- who can use commands? (1-5)
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

    set city [lrange $arg 0 end]
    if {$city eq "" && $uid eq ""} {
        reply $type $target "\002usage:\002 weather <city>"
        return;
    }
    set dbcity [join [db:get value settings setting city uid $uid]]
    if {$dbcity ne "" && $city eq ""} {
        set city $dbcity
    } elseif {$city eq "" && $dbcity eq ""} {
        reply $type $target "\002usage:\002 weather <city>"
        return;
    }

    set cfgUnits [cfg:get weather:units $chan]
    if {$cfgUnits eq "both"} {
        set units "metric"
    } else {
        set units $cfgUnits
    }

    set query [http::formatQuery q $city appid [cfg:get weather:key $chan] lang en units $units]

	if {[catch {http::geturl https://api.openweathermap.org/data/2.5/weather?$query} tok]} {
		debug 0 "\002cmd:cmd:weather:\002 socket error: $tok"
		return;
	}
	if {[http::status $tok] ne "ok"} {
		set status [http::status $tok]
		debug 0 "\002cmd:cmd:weather:\002 TCP error: $status"
		return;
	}
    set ncode [http::ncode $tok]
	if {$ncode ne 200} {
		set code [http::code $tok]
		http::cleanup $tok
		debug 0 "\002cmd:cmd:weather:\002 HTTP Error: $code"
        if {$ncode eq 404} {
            reply $type $target "\002error:\002 city not found: $city"
        } else {
            reply $type $target "\002error:\002 HTTP error: $code"
        }
		return;
	}

	set data [http::data $tok]
    http::cleanup $tok
	set parse [::json::json2dict $data]

    set sunrise [expr [join [dict get $parse sys sunrise]] + [join [dict get $parse timezone]]]
    set sunset [expr [join [dict get $parse sys sunset]] + [join [dict get $parse timezone]]]

	set sunrise [clock format $sunrise -format "%H:%M" -gmt 1]
	set sunset [clock format $sunset -format "%H:%M" -gmt 1]
    set city [join [dict get $parse name]]
	set country [join [dict get $parse sys country]]
    set temp [format "%.1f" [join [dict get $parse main temp]]]
	set humidity [join [dict get $parse main humidity]]
    set windspeed [format "%.1f" [join [dict get $parse wind speed]]]
	set cloudcover [join [dict get $parse clouds all]]
	#set dt [duration [expr [unixtime] - [dict get $parse dt]]]; # -- time since last update
	set clouds [dict get [lindex [dict get $parse weather] 0] description]
    set code [dict get [lindex [dict get $parse weather] 0] id]
    set emoji [weather:emoji $code]

    if {$cfgUnits eq "metric"} {
        reply $type $target "\002weather -\002 $city, $country: $emoji\002$temp\002 °C, \002$humidity\002 % humidity, \002$windspeed\002 km/h wind,\
            \002$cloudcover\002 % cloud cover (\002$clouds\002). Sunrise: \002$sunrise\002 / Sunset: \002$sunset\002"
    } elseif {$cfgUnits eq "imperial"} {
        reply $type $target "\002weather -\002 $city, $country: $emoji\002$temp\002 °F, \002$humidity\002 % humidity, \002$windspeed\002 mph wind,\
            \002$cloudcover\002 % cloud cover (\002$clouds\002). Sunrise: \002$sunrise\002 / Sunset: \002$sunset\002"
    } elseif {$cfgUnits eq "both"} {
        set tempF [format "%.1f" [expr ($temp * 9/5) + 32]]
        set windspeedMph [format "%.1f" [expr $windspeed * 0.621371]]
        reply $type $target "\002weather -\002 $city, $country: $emoji\002$temp\002 °C (\002$tempF\002 °F), \002$humidity\002 % humidity,\
            \002$windspeed\002 km/h (\002$windspeedMph\002 mph) wind, \002$cloudcover\002 % cloud cover (\002$clouds\002). Sunrise: \002$sunrise\002 / Sunset: \002$sunset\002"
    }
}

# -- return weather emojis by openweathermap.org code
proc weather:emoji {code} {
    set weatherEmojis {
        "200" "\U1F329"  "201" "\U1F329"  "202" "\U1F329"
        "210" "\U1F329"  "211" "\U1F329"  "212" "\U1F329"
        "221" "\U1F329"  "230" "\U1F329"  "231" "\U1F329"
        "232" "\U1F329"  "300" "\U1F327"  "301" "\U1F327"
        "302" "\U1F327"  "310" "\U1F327"  "311" "\U1F327"
        "312" "\U1F327"  "313" "\U1F327"  "314" "\U1F327"
        "321" "\U1F327"  "500" "\U1F326"  "501" "\U1F326"
        "502" "\U1F326"  "503" "\U1F326"  "504" "\U1F326"
        "511" "\U1F327"  "520" "\U1F326"  "521" "\U1F326"
        "522" "\U1F326"  "531" "\U1F326"  "600" "\U1F328"
        "601" "\U1F328"  "602" "\U1F328"  "611" "\U1F328"
        "612" "\U1F328"  "613" "\U1F328"  "615" "\U1F328"
        "616" "\U1F328"  "620" "\U1F328"  "621" "\U1F328"
        "622" "\U1F328"  "701" "\U1F32B"  "711" "\U1F32B"
        "721" "\U1F32B"  "731" "\U1F32B"  "741" "\U1F32B"
        "751" "\U1F32B"  "761" "\U1F32B"  "762" "\U1F32B"
        "771" "\U1F32C"  "781" "\U1F300"  "800" "\U1F31E"
        "801" "\U1F324"  "802" "\U2601"   "803" "\U1F325"
        "804" "\U1F325"
    }

    # -- return the emoji
    if {[dict exists $weatherEmojis $code]} {
        set emoji [dict get $weatherEmojis $code]
        return "$emoji  "
    } else {
        return ""
    }
}


putlog "\[A\] Armour: loaded plugin: weather"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------