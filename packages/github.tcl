#!/usr/bin/env tclsh
# file github/github.tcl
#https://wiki.tcl-lang.org/page/github%3A%3Agithub
#
#Version 1.1 - added a timer in seconds between files & folders

# -- updated by Empus (mail@empus.net) to support custom branches, github API token, and error handling

# chicken and egg problem we need non-standard packages tls and json ...
package require tls
package require http
::http::register https 443 ::tls::socket

namespace eval ::github {
    variable libdir [file normalize [file join [file dirname [info script]] ..]]
    if {[lsearch $::auto_path $libdir] == -1} {
        lappend auto_path $libdir
    }
} 

# -- debug level (0-3)
set ::github::debug 2

# I already placed the json folder below of the github folder
package require json
package provide github::github 0.2
package provide github 0.2

proc ::github::debug {level msg} {
    variable debug
    if {$level <= $debug} {
        putlog "\002\[A\]\002 $msg"
    }
}

# Tcl package download
proc ::github::github {cmd owner repo folder token {branch "master"}} {
    variable libdir
    ::github::debug 0 "\002::github::github:\002 downloading \002$owner/$repo\002 (\002branch:\002 $branch) to \002$folder\002"
    set url https://api.github.com/repos/$owner/$repo/contents/?ref=$branch
    download $url $folder $token $branch
}

# Folder download
proc ::github::download {url folder token branch {debug true}} {
    ::github::debug 1  "\002::github:download:\002 fetching folder contents -- \002$url\002 to \002$folder\002"
    if {![file exists $folder]} {
        file mkdir $folder
    }
    set sfiles ""
    set dfiles ""
    if {$token eq ""} {
        set headers [list]
    } else { set headers [list Authorization [list Bearer $token]] }
    set success 1
    set errcode [catch {set tok [::http::geturl $url -headers $headers -timeout 10000]} error]
    if {$errcode} { set success 0; set errout "error: $error" }
    set status [::http::status $tok]
    if {$status ne "ok"} { set success 0; set errout "status: $status" }
    set data [http::data $tok]
    set httpcode [http::ncode $tok]
    ::http::cleanup $tok
    if {$httpcode ne "200"} {
        set success 0; 
        set errout "http code: $httpcode" 
        ::github::debug 0 "\002::github:download:\002 error \002$httpcode\002 on file: $url"
    }
    if {!$success} {
        ::github::debug 0 "\002::github:download:\002 Github download error ($errout)"
        return;
    }
    set d [json::json2dict $data]
    if {[dict exists $d message]} {
        if {[dict get $d message] eq "Bad credentials"} {
            ::github::debug 0 "\002::github:download:\002 Github download error (\002Bad credentials\002)"
            return;
        }
    }
    ::github::debug 3 "\002::github:download:\002 json: $d"
    set l [llength $d]
    set files [list]
    for {set i 0} {$i < $l} {incr i 1} {
        set dic [dict create {*}[lindex $d $i]]
        set file [dict get $dic download_url]
        set type [dict get $dic type]
        if {$file eq "null" &&  $type eq "dir"} {
            set file [dict get $dic url]
            #set file [regsub ".ref=$branch" $file ""]
        }
        if {$type eq "file"} {
            lappend sfiles $file
        } else {
            lappend dfiles $file
        }
    }
    if {$sfiles != ""} {
        files $sfiles $folder 0 $dfiles $branch $token
        return
    }
    if {$dfiles != ""} {
        dirs $dfiles $folder 0 $branch $token
    }
}

# Folders make
proc ::github::dirs {dirs dir num branch {token ""}} {
    set file [lindex $dirs $num]
    set file2 [regsub ".ref=$branch" $file ""]; # -- remove the ref ext when writing the directory
    set nfolder [file join $dir [file tail $file2]]
    ::github::debug 1 "\002::github::dirs:\002 writing directory: \002$nfolder\002"
    download $file $nfolder $token $branch
    set counter [expr $num + 1]
    if {[lindex $dirs $counter] != ""} {
        ::github::dirs $dirs $dir $counter $branch $token
    }
}

# Files make
proc ::github::files {files dir num dirs branch {token ""}} {
    set item [lindex $files $num]
    set file [lindex $item 0]
    set fname [file tail $file]
    set fname [file join $dir $fname]
    set fname [regsub ".ref=$branch" $fname ""]; # -- remove the ref ext when writing the directory
    ::github::debug 2 "\002::github::files:\002 downloading file: \002$file\002 and saving as: \002$fname\002"
    set f [open $fname w]
    fconfigure $f -translation 
    if {$token eq ""} {
        set headers [list]
    } else { set headers [list Authorization [list Bearer $token]] }
    set tok [http::geturl $file -headers $headers -channel $f]
    set Stat [::http::status $tok]
    flush $f
    close $f
    http::cleanup $tok
    set counter [expr $num + 1]
    if {[lindex $files $counter] != ""} {
        ::github::files $files $dir $counter $dirs $branch $token
    } else {
        if {$dirs != ""} {
            dirs $dirs $dir 0 $branch $token
        }
    }
}

putlog "\[@\] Armour: loaded Github support."