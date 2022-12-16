# Armour Setup
Author: Empus [empus@undernet.org](mailto:empus@undernet.org])
Last Updated: 2022-12-06

## Prerequisites
The below are required to run Armour:
* eggdrop 1.8.4 (min)
* sqlite3
* TCL 8.6 (min)
* tcllib


## Eggdrop 

### Eggdrop Configuration

See **bot.conf.sample** for a template for the **eggdrop.conf** itself
This eggdrop configuration doesn't need to be used, but it will get you going fast on a new/dedicated bot for Armour

Ensure the `./db` directory is created in the eggdrop dir (eggdrop dbs will save here)

Once the new bot is online using the eggdrop sample template template, create your eggdrop account:
>```/msg <bot> createuser```


## Armour

### Armour Configuration

Edit the Armour configuration file as required. Crucially, this will define your default channels and sqlite3 DB path, but there are many more configuration options worth considering.  

Take note to set the md5 method for password security.  This will likely be md5sum for Linux machines, or md5 for others.

Now uncomment the last line in the eggdrop configuration file and rehash the bot to load Armour.

Note that the Armour TCL itself does not get loaded directly.  Load the Armour conf file and it will load the TCL for you and also create the database.


### Armour Setup

Once this is done, you can create your new Armour user which then provisions global and default channel access using the below command.  Use <user> to represent the name of your desired bot username, and <account> to represent your network username for autologin, if the network uses user accounts.  The below command only works once, when the user database is empty:

>```/msg <bot> inituser <user> [account]```

The bot will then generate a random password (sent via /notice) that you can use to login:

>```/msg <bot> login <user> <password>```

Then a new password can be set:

>```/msg <bot> newpass <newpassword>```

If the IRC network supports network user accounts (such as Undernet), the bot will now automatically authenticate you when you join channels.

And, you're done!


### Troubleshooting
Questions or problems? Ask in #Armour on Undernet, or post @ https://github.com/empus/armour/issues

