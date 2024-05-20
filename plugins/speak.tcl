# ------------------------------------------------------------------------------------------------
# Speak Plugin - Text-to-Speech integration
# ------------------------------------------------------------------------------------------------
#
# Supports two Text-to-Speech services:
#
#   elevenlabs: https://elevenlabs.io
#   openai:     https://openai.com 
#
# Send TTS requests via 'speak' command, and output audio file link
#
# Can also be used with 'ask' command prefixed with 'speak'
#
# Or, with natural language processing, 'speak' can be used as a prefix to a question
#
# ------------------------------------------------------------------------------------------------
# Examples:
#
#   @Empus | c speak why is the sky blue?
#   @chief | Empus: https://chief.armour.bot/2Nj9.mp3
#
#   @Empus | c ask speak why is the sky blue?
#   @chief | Empus: https://chief.armour.bot/sj6n.mp3
#
#   @Empus | chief: speak why is the sky blue?
#   @chief | Empus: https://chief.armour.bot/48Seo.mp3
#
# ------------------------------------------------------------------------------------------------



# ------------------------------------------------------------------------------------------------
namespace eval arm {
package require json
package require http 2
package require tls 1.7

# -- ask a question to respond with speech (audio file)
# -- send to abstraction proc (shared for 'image' and 'speak')
proc arm:cmd:speak {0 1 2 3 {4 ""}  {5 ""}} {
    ask:abstract:cmd speak $0 $1 $2 $3 $4 $5; # -- send to abstraction proc
}

# -- send ChatGPT API queries
proc speak:query {what} {
    variable ask
    http::config -useragent "mozilla" 
    http::register https 443 [list ::tls::socket -autoservername true]

    # -- query config

    set tts [cfg:get speak:service *]; # -- text-to-speech service (elevenlabs or openai)
    set timeout [expr [cfg:get speak:timeout *] * 1000]; # -- API query timeout (seconds)
    if {$tts eq "elevenlabs"} {
        # -- use elevenlabs.io text-to-speech
        set key [cfg:get speak:key *]
        set model [cfg:get speak:model *]
        set voice [cfg:get speak:voice *]
        set ewhat [split $what]
        dict set data text "\"$ewhat\""
        dict set data model_id "\"$model\""
        #dict set data language_id "\"en\""
        dict set data voice_settings [json::dict2json [list stability 0 similarity_boost 0 style 0 use_speaker_boost true]]
        set data [json::dict2json $data]

        set url "https://api.elevenlabs.io/v1/text-to-speech/${voice}?optimize_streaming_latency=0&output_format=mp3_44100_128"

        #debug 3 "speak:query: url: $url"
        regsub -all "\\\\n" $data " " data
        debug 3 "\002speak:query:\002 POST data: $data"

        catch {set tok [http::geturl $url \
            -method POST \
            -query $data \
            -headers [list "accept" "audio/mpeg" "xi-api-key" "$key" "Content-Type" "application/json"] \
            -timeout $timeout \
            -keepalive 0]} error
    
    } elseif {$tts eq "openai"} {
        # -- use openai.com text-to-speech

        # https://platform.openai.com/docs/guides/text-to-speech
        # curl https://api.openai.com/v1/audio/speech \
        #    -H "Authorization: Bearer $OPENAI_API_KEY" \
        #    -H "Content-Type: application/json" \
        #    -d '{
        #        "model": "tts-1",
        #        "input": "The quick brown fox jumped over the lazy dog.",
        #        "voice": "alloy"
        #    }' \
        #    --output speech.mp3
        set model "\"[cfg:get speak:openai:model *]\""
        set input "\"$what\""
        set voice "\"[cfg:get speak:openai:voice *]\""; # -- alloy, echo, fable, onyx, nova, shimmer
        set ext [cfg:get speak:openai:format *]
        set response_format "\"$ext\""; # -- mp3, opus, aac, flac
        set data [json::dict2json [list model $model input $input voice $voice response_format $response_format]]
        set url "https://api.openai.com/v1/audio/speech"

        #debug 3 "speak:query: url: $url"
        debug 3 "\002speak:query:\002 POST data: $data"

        catch {set tok [http::geturl $url \
            -method POST \
            -query $data \
            -headers [list "Authorization" "Bearer [cfg:get ask:token *]" "Content-Type" "application/json"] \
            -timeout $timeout \
            -keepalive 0]} error

    }

    # -- connection handling abstraction
    set iserror [speak:errors $url $tok $error]
    if {[lindex $iserror 0] eq 1} { return $iserror; }; # -- errors
    
    set output [http::data $tok]
    debug 3 "\002speak:query: API response:\002 $output"
    http::cleanup $tok

    # -- check for error message in JSON response
    catch { set detail [dict get [json::json2dict $output] detail] } error; # -- must catch error, otherwise json2dict fails on binary data
    if {$error eq "" && $detail ne ""} {
        debug 0 "\002speak:query:\002 detail: $detail"
        return "1 $detail"
    }

    set file [randfile "mp3"]
    set path [cfg:get ask:path *]
    set path [string trimright $path "/"]
    if {$tts ne "openai"} { set ext "mp3" }; # -- otherwise, use the openai 'response_format' param value
    set fd [open $path/$file.$ext wb]
    fconfigure $fd -translation binary -encoding binary
    puts -nonewline $fd $output
    close $fd

    set url [cfg:get ask:site *]
    set url [string trimright $url "/"]
    set ref "$url/$file.$ext"

    debug 3 "speak:query: saved text-to-speech file to: $ref"
    return "0 $ref"
}

# -- abstraction to check for HTTP errors
proc speak:errors {url tok error} {
    debug 0 "\002speak:errors:\002 checking for errors...(error: $error)"
    if {[string match -nocase "*couldn't open socket*" $error]} {
        debug 0 "\002speak:errors:\002 could not open socket to $url."
        http::cleanup $tok
        return "1 socket"
    } 
    
    set ncode [http::ncode $tok]
    set status [http::status $tok]
    
    if {$status eq "timeout"} { 
        debug 0 "\002speak:errors:\002 connection to $url has timed out."
        http::cleanup $tok
        return "1 timeout"
    } elseif {$status eq "error"} {
        debug 0 "\002speak:errors:\002 connection to $url has error."
        http::cleanup $tok
        return "1 connection"
    }
}



putlog "\[@\] Armour: Loaded plugin: speak"

# ------------------------------------------------------------------------------------------------
}; # -- end namespace
# ------------------------------------------------------------------------------------------------
