# Install Guide

## **TCL Packages Required:** 
>- min TCL 8.6
>- >sqlite3 tcllib

## **Eggdrop**
See **bot.conf.sample** for a template for the **eggdrop.conf** itself
This eggdrop configuration doesn't need to be used, but it will get you going fast on a new/dedicated bot for Armour

Once the new bot is online using the bot.conf.sample template, do:
>`/msg <bot> createuser`

## **Armour**
Edit the Armour configuration file as required. Crucially, this will define your sqlite3 DB path
Take note to set the md5 method for password security.  This will likely be md5sum for Linux machines, or md5 for others.

Now uncomment the last line in the eggdrop file and rehash the bot to load Armour
Note that the Armour TCL itself does not get loaded directly.  **Load the Armour \*.conf file** and it will load the TCL for you.
Loading this will create the DB and the necessary tables.

## **DB Insert**
Once the script is loaded, insert yourself into the sqlite3 db as defined in Armour conf file:

>`sqlite3 /path/to/armour-db.db`

>`INSERT INTO users (user,xuser,level,pass) VALUES('YOUR-USER','YOUR-X-ACCOUNT',500,'foo');`

>`.quit`

If autologin is setup and you are authed to X, the bot will soon automatically log you in.  If not, cycle the channel.
Once logged into the bot (it will send you a /notice), do: 
>`/msg <bot> newpass <pass>`

## **Support**
And, you're done!

Questions or problems? Ask in **\#Armour** on Undernet, or post to [GitHub Issues](https://github.com/empus/armour/issues)

- Empus [empus@undernet.org](empus@undernet.org)

  26-01-2022
