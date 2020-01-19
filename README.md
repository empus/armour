----------------------------------------------------------------------------------------------------------------
 armour.tcl v3.4.3 - 2020.01.16
----------------------------------------------------------------------------------------------------------------

 ![Armour](./armour.png)
 Anti abuse script for eggdrop bots on the Undernet IRC Network

 http://code.empus.net/armour/ -- empus@undernet.org

----------------------------------------------------------------------------------------------------------------
 BRIEF
----------------------------------------------------------------------------------------------------------------

The Rolling Stones said it well.  This bot script is the "Beast of Burden".  It does lots of stuff well, although
not everything perfectly.  For what it does well, we thank #phat of Undernet.  Dickheads hit that channel for 
years and from that, we thank them for this.  For what doesn't work well?  Let's ignore that.

Credits:

	- everyone in #phat of Undernet
	- [k] for literally encouraging me to trial anything I wanted to :>
	- thommey: for giving me insight once a year or so, that changed my world
	- the morons who thought they were annoying us, when really they gave us great pleasure!
	
........ and here we go:

At the heart of this script is a powerful whitelist and blacklist system supporting various methods.

There is a DNSBL lookup system as well as a port scanner to assist in the identification of insecure hosts.

There is also dynamic floodnet detection and some basic flood, spam and annoyance detection that apply to 
newcomers to a channel.

The entire script is highly configurable as I understand that not everyone needs things the same way. It does 
make for many config variables but I hope you'll welcome this approach.

To download the entire git repository use: ***git clone https://github.com/empus/armour***

Or alternatively visit ***http://code.empus.net/armour/*** to download the source.

If you have any bugs to report or enhancement suggestions, please post them on the '***Issues***' page or email me. 

I encourage you to read this README document as thoroughly as possible to best understand the functionality of
the Armour script, including the vast amount of flexible configuration values to tweak certain behaviour.

Any feedback or specific questions can be sent to me via e-mail.

I hope this script is of much use to you in your channels as it has been to myself and my friends on Undernet.

Regards,

- Empus <mail@empus.net>



----------------------------------------------------------------------------------------------------------------
 FOREWARD
----------------------------------------------------------------------------------------------------------------

This script began its life with a much, much, much smaller scope than what it is today.  When I started on this,
it was for a single channel and I had no intention on releasing the code publicly.

The script has grown immensely over time, and as more and more functionality came into it - the more people have
asked me when I will release it.  

I'm not overly proud of all of the code.  I'd really like to fix up some things, remove redundant code and add 
more efficiencies throughout.  Not having the foresight in the beginning of what it was going to become, it would 
be fair to say that certain things could have been done better.

Whitespace is inconsistent (and in fact, I even wrote a script to convert this some years back), there are many
global variables which could conflict with other scripts, and plenty of legacy code exists such as that 
supporting old file based databases.  Support for IPv6 was an afterthought, and supporting scans in more than 
one channel, will not be an easy enhancement.  With enough encouragement from others, maybe I'll get there!

Furthermore, there will likely be ***bugs***. In fact, I know there are.

However as time has gone on, I've begun to realise that if I keep postponing a public release because it is not
yet perfect -- it may never happen.

So here it is.  A public release of Armour, for all to use.

I very much so welcome suggestions for improvement.  I welcome bug reports.  Help me find them, and I'll try to
fix them :>



----------------------------------------------------------------------------------------------------------------
 INITIAL SETUP
----------------------------------------------------------------------------------------------------------------

Please refer to the separate file '***INSTALL.md***' for instructions on initial setup.



----------------------------------------------------------------------------------------------------------------
 CONFIGURATION
----------------------------------------------------------------------------------------------------------------

Each configuration value holds a brief description as well as the default value.  In most circumstances the
default value can be left.  For most configuration options if you are unsure of the best value to set, begin
with the default.

New configuration values can appear within new versions of Armour so be sure to read the '***UPDATING.md***' file
when new versions have been downloaded.



----------------------------------------------------------------------------------------------------------------
 WHITELISTS & BLACKLISTS
----------------------------------------------------------------------------------------------------------------

Armour has the ability to maintain both ***whitelists* and ***blacklists***.  The lists are stored to file and are saved
to disk periodically.

The script can run in one of three modes, outlined below:

	OFF:	The bot does not do any automated scans when a user joins the channel.  Manual scans can be done.

	ON:	The bot executes automated scans when a user joins the channel.  Manual scans can also be done.

	SECURE:	The bot maintains channel modes '+Dm' and scans invisible users periodically.  Users that fail 
		the scan can be left, or kickbanned as configured.  Users passing the scan, will be voiced, 
		making them visible to other users in the channel.  NOTE:  Channel mode +D may not exist on all 
		ircd's.  It does on Undernet.

		NOTE:	A channel operator manually setting channel modes +Dm, will result in the bot entering
			'secure' mode automatically.  Removing these modes will put it back to default mode.

The Armour mode is configurable and can be set on the fly with the 'mode' command.

If floodnet detection is enabled, this is done prior to ***whitelist*** & ***blacklist*** checking, with some intelligence 
to reduce false positive matches.  This is described in another section below.

***Whitelist*** scanning is always completed before ***blacklist** scanning commences.  Blacklists are not checked if a user
matches a whitelist.

List entries can be of multiple types, described below:

	host:	A host or IP address entry.  CIDR IP notation supported.  Wildcards supported.
	
		ex.	10.0.0.1		10.0.0.*			10.0.0.0/24
			*!foob?r@10.0.0.0/8	static.adsl.isp123.com		*!~*@static.adsl.isp123.com


		NOTE:	- Even if a client joins with an alpha hostname, entries matching IP addresses (and CIDR)
			will still catch them.


	user:	An authenticated username (ie. from CService).  Wildcards supported.

		ex.	Empus			*hack*


	rname:	The realname (or IRC name) of a client connection.  Wildcards supported.

		ex.	Bob			Mr?Bob				*fuck*


	regex:	A regular expression matching a client connection string in the format of: 

		nick!ident@host/realname

		ex.	^\w+\d{4,}!~[^/]+/Mr\sBob$


	country:A geographical country of the IP space, in two digit ISO 3166-1 format.  CYMRU TXT DNS 
		lookups used.  IP Address of client must be visible.

		ex.	CN


	asn:	Autonomous System Number of client IP space.  CYMRU TXT DNS lookups used. IP Address of client
		must be visible.

		ex.	AS1234			1234


	chan:	A channel the joining client is inside at the time of scan.  Channel must be visible (ie. not +s).
		Wildcards supported.

		ex.	#hackers		*hack*

--------
NOTES:	
--------
	- COUNTRY and ASN lookups cannot be done if the IP address for the client is unknown.


--------
ACTIONS:
--------

***WHITELIST*** and ***BLACKLIST*** entries have associated actions.

	A whitelist match can have the bot either:

		- 'accept' the user (do nothing except cease further scans)
		- 'voice' the user in the channel
		- 'op' the user in the channel

	A blacklist match only has one action:

		- 'ban' will kickban the user from the channel


***usage:*** add <white|black> <user|host|rname|regex|country|asn|chan|last> <value1,value2..> <accept|voice|op|ban> ?joins:secs:hold? [reason]


Multiple values can be given comma separated, for efficiency.


ex. 1		Add a username whitelist entry, and op the user

			add white user Empus op channel regular


ex. 2		Add a hostname blacklist entry for a spammer

			add black host *!~blah@static123.adsl.isp123.com ban stop spamming!


ex. 3		Add all Chinese IP space to blacklist

			add black country cn ban compromised host***


ex. 4		Add some RFC1918 IP space to the whitelist, and autoop all

			add white host 127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 op rfc1918 users


--------
NOTES:	
--------

	-	The 'reason' field is optional -- a default reason for the blacklist and whitelists can be set
		in the config file.

	-	With BLACKLIST entries, the 'action' is optional -- 'ban' is implied.

	-	The 'joins:secs:hold' field is only relevant to 'host' and 'regex' blacklist entries.  This field
		allows for such a blacklist entry to not be explicit, but rather cumulative -- whereby a certain
		join threshold must be met before action is taken.
		For example, a more broad pattern can be added but only triggered if 3 matching clients join in 
		2 seconds.
		The 'hold' value is measured in seconds and defines a 'hold open' window, for subsequent matches
		to be caught faster.

		ex.	'3:2:10' Would mean that 3 clients matching the mask or pattern must join within a 2 
			second time frame before action [on both clients] is taken.  This trigger window is then
			held open for 10 more seconds so any more joining clients within the next 10 seconds 
			that join (provided they match the pattern), will be acted against immediately, rather 
			than the 3:2 needing to be met again. Each new match will re-set the 10 sec holding window again.

		The 'hold' value is optional whereby 3:2 implies 3:2:2

		Leaving this optional field out, effectively would imply a value of '1:1:1'


		ex. 5		Add pattern for lower case nicks and lower case unresolved idents, where 3 join in 1
				second.

					add black regex ^[a-z]+!~[a-z]+@ ban 3:1 floodnet pattern


	-	The 'last' type is used to quickly add the last N joining users to the whitelist or blacklist dbs.
		A configured number of last joining IP addresses is kept in memory (default: last 20 seconds).

		ex. 6		Add the last 6 joining client IP's to the blacklist

					add black last 6


	-	There is an optional DroneBL plugin which can be integrated into Armour, for live submission, views
		and removals to the www.dronebl.org database.  This is covered in the plugin help.  Example below.

		ex. 7		Add the last 6 joining client IP's to DroneBL

					add dronebl last 6

		ex. 8		Add the IP 123.124.125.126 to DroneBL

					add dronebl 123.124.125.126




----------------------------------------------------------------------------------------------------------------
 DNSBL LOOKUPS
----------------------------------------------------------------------------------------------------------------

Where enabled and with a known joining client IP, DNSBL lookups can be done for action against positive match.

DNSBLs are configured with a short description and also a score assicated with the match.  Any total score >0 
will result in action taken against the client.  This methodology can be used for entries to be utilised as 
DNSWLs using negative scores.

	ex. 	Using two DNSBLs each having a score of '+1' and also a DNSWL entry with a score of '-2' means 
		that even if both DNSBL's return a hit, if there is a DNSWL match, it would have a 'neutralising'
		effect.

		NOTE:	This scenario would only whitelist the DNSBLs - not other blacklist or portscan actions.
			Waiting for all DNS responses back before processing any blacklists would result in
			slower performance when dealing with abuse.
		

DNSBLs are set in the config file, where multiple can be used.

DNSBL lookups can be bounced through a remotely connected Eggdrop bot via the botnet, where the 'remote' bot has
the '***remotescan.tcl***' script loaded.  This can be useful to protect the true location of a bot by not exposing
itself through the DNS queries.  This approach moreso useful prior to the use of coroutines in TCL8.6



----------------------------------------------------------------------------------------------------------------
 PORTSCANNER
----------------------------------------------------------------------------------------------------------------

Where enabled and with a known joining client IP, port scans can be done for action against positive match.

Ports to be scanned are set in the config file.  The number of open ports required for action to be taken, is
also configurable.

Port scans can be bounced through a remotely connected Eggdrop bot via the botnet, where the 'remote' bot has
the '***remotescan.tcl***' script loaded.  This can be useful to protect the true location of a bot by not exposing
itself through the port scans themselves.  As with DNSBL lookups, this approach was moreso useful prior to the
use of coroutines in TCL8.6

There is a configuration option to choose whether to scan all connecting clients (on known, non rfc1918 space),
or only those clients with an unresolved ident.



----------------------------------------------------------------------------------------------------------------
 DYNAMIC FLOODNET DETECTION
----------------------------------------------------------------------------------------------------------------

Utilising the ***whitelist*** and ***blacklist*** database, 'static positive' entries exist to match joining users.  When the 
optional '***joins:secs:hold***' threshold parameter is used, frequency limits can be applied so action is only taken 
when a certain limit is met (ie. identifying a group of floodbots joining).  These 'static cumulative' entries 
are effective, but require the entries to be created manually.

The 'dynamic floodnet detection' is a automated means of identifying common patterns of joinin clients, for the
purpose of floodnet control.

This system works by dynamically building regex patterns for joining clients, and taking action against those
which match said patterns, within a configured '***joins:secs:hold***' frequency.

The dynamic matching can be done against:

	nick
	nick!ident
	nick!ident/rname
	nick/rname
	ident
	ident/rname
	rname

	(Including multiple combinations of the above)

	NOTE:	Those requiring the matching of realname will naturally be slightly slower as these require a 
		/WHO response from the server.

Whilst not all joining floodbots tend to be of common patterns, employing this method does assist somewhat, rather
than manually managing the ***whitelist*** and ***blacklist*** databases.

When a floodnet is detected, the bot can optionally set the channel into a temporary lockdown with optional modes
(default being +mr).  The lockdown and stacked bans take precendece in the custom server queue, with kicks 
following.  Only after all kicks are complete plus a configured pause time, will the bot unlock the channel. 
The idea is to lock the channel for the least amount of possible, whilst removing the floodnet as best possible.



----------------------------------------------------------------------------------------------------------------
 AUTOMATIC BLACKLIST ADDITIONS
----------------------------------------------------------------------------------------------------------------

Optionally, the bot can be configured to automatically add ***blacklist*** entries for IP addresses of clients that
have been G-Lined from the network.

As inadvertant mistakes can sometimes lead to automatic G-Lines (ie. excessive connections from a shell), there
is provision to exclude G-Lines that match a particular reason mask (ie. Those automated ones from euworld)



----------------------------------------------------------------------------------------------------------------
 CONTROLLING THE BOT
----------------------------------------------------------------------------------------------------------------

The bot commands can be enabled for privmsg, dcc, and public use.  All commands are prefixed with a control 
prefix.  A bot can also be optionally commanded by calling its nickname (optionally requiring a ':' char using
nick completion)

	ex.	<@Empus> z say #armour hello world
		<@zen> hello world

		<@Empus> zen: save
		<@zen> saved 2 whitelist and 70 blacklist entries to db

If multiple bots exist in a common channel using different command prefixes, the control char '*' can optionally
be allowed to control all bots at once:

	ex.	<@Empus> * verify Empus
		<@shield> Empus is authenticated as Empus (level: 500)
		<@zen> Empus is authenticated as Empus (level: 500)
		<@chief> Empus is authenticated as Empus (level: 500)


In addition to all commands being able to be enabled/disabled through mediums public, privmsg, and dcc - it is
possible to manipulate which commands are accessible through those means too.  The 'add command' section of the 
configuration file can specify this through the use of the '***pub msg dcc***' column.  The level required for each 
command is also specified in this configuration file section.

Sending any command to the bot without args will generally, result in the syntax being sent back.

	ex.	<@Empus> z adduser
		<@zen> usage: adduser <user> <level> <pass> [xuser]

		NOTE:	Arguments encapsulated in <> are required, those in [] are optional.  This convention is
			used throughout the script.


Some commands can optionally be called via shortcuts, as specified in the configuration file.  Other values in
some commands can be abbreviated to the first letter.

	ex.	<@Empus> zen: add black host *!foo@bar.com ban stop spamming
		<@zen> added host blacklist entry (id: 79 value: *!foo@bar.com action: kickban reason: stop spamming)

		.. is the same as:

		<@Empus> z a b h *!foo@bar.com b stop spamming
		<@zen> added host blacklist entry (id: 79 value: *!foo@bar.com action: kickban reason: stop spamming)

Once familiarised, these shortcuts can introduce useful efficiencies when dealing with above.



----------------------------------------------------------------------------------------------------------------
 HELP FROM THE BOT
----------------------------------------------------------------------------------------------------------------

Available commands can be recalled by using the '***cmds***' command, or using '***help***' without any arguments. Only those
commands which a user has access to, will be returned.  This available commandlist will also include those from
any loaded plugins.

	ex.	<@Empus> z cmds
		<@zen> commands: ack add adduser asn ban black chanscan cmds country data deop devoice die do email
                       exempt help invite jump kb kick load mode moduser op push rehash reload rem remuser restart
		       save say scan scanport scanrbl search set sms stats status tell topic unban userlist verify
		       version view voice whois

	ex.	<@Empus> z help status
		<@zen> command: status -- level: 100 -- usage: status 
		<@zen> displays current bot status including uptimes, traffic usage, db states


Help topics are provided in '***help/*.help***' files.  Feel free to edit these as desired.  A schema of variables is
used within help topic files whereby:

                %B%     Bold text
                %LEVEL% Level required


----------------------------------------------------------------------------------------------------------------
 AUTOLOGIN
----------------------------------------------------------------------------------------------------------------

When adding users to the bot, an optional Channel Service (CService) username can be associated with the user.  
This is for the purpose of autologin.  When the bot sees these users join the channel, they will be automatically 
authenticated.

Optionally, the bot can periodically send a /WHO to a channel (or comma delimited list of channels), to find
users who have authenticated to Channel Services since joining the channel.

NOTE:  A client does not need to be usermode +x (host hiding) for the above to occur.

Manual login is always allowed, but a client must be in a common channel with the bot for this to be successful.



----------------------------------------------------------------------------------------------------------------
 SECURE MODE PARANOIA
----------------------------------------------------------------------------------------------------------------

When in mode '***secure***', the channel will be in mode +Dm and voice joining users when they have passed all scans,
effectively making them visible to the rest of the channel.

The cycle at which the '/NAMES -d' cycle is done, is configurable.  More frequent means a shorter wait, but can
potentially create bot lag.

The bot can stack modes on a timer also so several users can be voiced together.  This is much cleaner than
voicing each user individually (which can create many frequent voice lines in an active channel), but again, can
add a small delay to the time it takes before the user is voiced (and thus, is seen by others and can speak).

When in secure mode, there are paranoia settings to introduce further metrics to help determine which action to
take.  If there are more than N clones matched in a single scan, and the client signon time has an age less than 
a configured time, the bot can send a notice to the channel operators for manual review and not automatically
voice these clients. Alternatively it can automatically ban the clients.



----------------------------------------------------------------------------------------------------------------
 PLUGINS
----------------------------------------------------------------------------------------------------------------

Armour has been built with the ideal scenario of being a dedicated channel bot (ie. to not have other Eggdrop
scripts loaded on top) -- however it has been written with a means to include additional plugins.

These plugin scripts have also been written with an ability to run them in 'standalone' mode, meaning they do not
require Armour in order to work on another bot.

At the time of writing, the following plugins are publicly provided:

	sms:		An interface to the SMS Global (www.smsglobal.com) API for the sending of SMS' to a user 
			in the configured phone book.

	push:		An interface to the Pushover (www.pushover.net) API for the sending of push notifications
			to an iOS or Android device registered with the service.

	email:		Ability to send emails to users in the registered email directory.

	tell:		Ability to add reminders to the bot -- to remind yourself, or another person either in a
			channel in private, of something in particular.

	trakka:		Gives channel regulars 'scores' based on the amount of time they spend in the channel.
			Those users with high scores are deemed channel regulars which can bypass the secure mode
			paranoia behaviour described above.  The bot can optionally notify the channel [operators]
			when someone without a score joins the channel.

	dronebl:	An interface for DroneBL for the addition, viewing and removal of IP entries with the
			commands: add, view, rem
			
	aidle:		A simple channel anti-idle checker



----------------------------------------------------------------------------------------------------------------
 EXTERNAL SCRIPT INTEGRATION
----------------------------------------------------------------------------------------------------------------

Provision has been made to pass the joining client details to external procs (space delimited) only ***after*** a 
client has either passed all scans or had a WHITELIST action taken.

The data passed to these procs is in the following format: nick uhost hand chan



----------------------------------------------------------------------------------------------------------------
 CLOSING...
----------------------------------------------------------------------------------------------------------------

This script has evolved over a long period.  It's always improving.  There will be bugs.  I'm open to ideas.

If you have questions or feedback of any kind, please do contact me!

Cheers,

- Empus <mail@empus.net>
