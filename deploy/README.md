----------------------------------------------------------------------------------------------------------------

 ![Armour](../armour.png)

----------------------------------------------------------------------------------------------------------------

# Deployment

Deploy files can be utilised to add additional Armour bots to an existing installation in a non-interactive way.

These `*.ini` files are used with the `../install.sh` script to change just the most important settings to
provide for a non-interactive deployment of new bots.

Copy a relevant example to a new `*.ini` file and then use it as input to the installer script:

```sh
cp undernet.ini.sample mybot.ini
cd ..
./install.sh -f deploy/mybot.ini
```

# Samples

| File           | Description
|----------------|------------
| `undernet.ini` | Undernet network. Defaults to X (GNUWorld) authentication service settings.
| `dalnet.ini`   | DALnet network. Defaults to NickServ authentication settings.


# Suggestions

If you would like to see additional network sample deployment files or any with different default settings,
please [contact me](https://armour.bot/contact).