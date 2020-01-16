#!/bin/sh

# script to generate a set of configuration files from template

if [ "$#" -ne "2" ]; then
	echo "usage: makeconf.sh <bot> \"<chan>\""
	echo "ensure channel is enclosed in \"#quotes\""
	exit
fi
cp armour.conf.sample $1.conf
cp ../bot.conf.sample ../$1.conf
cp ../db/EDITME.chan.sample ../db/$1.chan
cp ../db/EDITME.user.sample ../db/$1.user
sed -i '.bak' 's/EDITMECHAN/'$2'/g' $1.conf
sed -i '.bak' 's/EDITME/'$1'/g' $1.conf
rm $1.conf.bak
sed -i '.bak' 's/EDITME/'$1'/g' ../$1.conf
rm ../$1.conf.bak
echo 'done'
 
