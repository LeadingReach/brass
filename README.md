# brass
### Brew As Script

brass is a utility designed to run brew on endpoints with multiple users.

## Disclaimer
This script requires sudo access for many of its functions. This script may modify the sudoers file.  Run this script at your own risk.

## Installation

```bash
/bin/bash -c "$(curl -fsSL https://github.com/LeadingReach/brass/blob/brass-local/brass.sh)"
```

## Usage
```bash
  admin@mac\$ brass install sl

    brass user: admin
    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    Installing sl
    done

```

###brass can use its own flags to specify which user should run brew.
###When using brass flags, the standard brew commands such as install and info no longer work.

```bash    
  user@mac\$ sudo brass -s admin

    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    done


  # Install a package as admin
  user@mac\$ sudo brass -s admin -p sl

    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    Installing sl
    done

  # Uninstall a package as admin
  user@mac\$ sudo brass -s admin -d sl

    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    Uninstalling /Users/admin.homebrew/Cellar/sl/5.02... (6 files, 37.5KB)
    done

  # Update xcode and brew, then install package sl as user admin with debug information
  user@mac\$ sudo brass -s admin -xup sl -b
```
###brass has the ability to manage the default homebrew prefix.
```
  # Install a package as admin with the default homebrew prefix
  user@mac\$ sudo brass -Zs admin -p sl

    System user found: admin
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    Installing sl
    done


  # Install a package as a user who doesn't own the default homebrew prefix
  user@mac\$ sudo brass -Zp sl

    System user found: user
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    user does not own /opt/homebrew
    Would you like for user to take ownership of /opt/homebrew? [Y/N] y
    Installing sl
    done


  # Install a package as a user who doesn't own the default homebrew prefix
  user@mac\$ sudo brass -nlZp sl

    System user found: user
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    user does not own /opt/homebrew
    user taking ownership of /opt/homebrew
    Installing sl
    done


  # Install a package as otheradmin unless console user is an admin
    admin@mac\$ sudo brass -as otheradmin -p sl

    System user found: otheradmin
    Brew admin enabled: admin is an admin user. Running brew as admin
    User Mode Enabled: Brew binary is located at /Users/carlpetry/.homebrew/bin/brew
    Installing sl
    done


  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix
    admin@mac\$ sudo brass -Zas otheradmin -p sl

    System user found: otheradmin
    Brew admin enabled: admin is an admin user. Running brew as admin
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    Installing sl
    done


  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix,
  # with no interaction, no warning, and display debug information.
    admin@mac\$ sudo brass -Znlas otheradmin -p sl -b


  # You can configure custom text to be displayed in a pop up window at any stage of the script
    admin@mac\$ brass -w Starting brew update. -u -w Brew update complete.

    #########BRASS#########
    #Starting brew update.#
    #######################

    brass user: carlpetry
    System user found: carlpetry
    User Mode Enabled: Brew binary is located at /Users/carlpetry/.homebrew/bin/brew
    brewUpdate: Enabled.
    Updating brew
    Already up-to-date.

    #########BRASS#########
    #Brew update complete##
    #######################


  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix,
  # with no interaction, no warning, and display debug information
  # while showing custom message before and after completion.
    admin@mac\$ brass -Znlas otheradmin -w Installing sl. -p sl -b -w done.

    System user found: otheradmin
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew

    #########BRASS#########
    ### Installing sl. ####
    #######################

    Installing sl

    #########BRASS#########
    ######## done #######*#
    #######################
```

## flags
```bash
  -Z: Run brew with default homebrew prefix

      # This will run all following operations as the admin user
      user@mac\$ sudo brass -Z
      System user found: admin
      System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew


  -s: Run as user. Root access is required.

      # This will run all following operations as the admin user
      user@mac\$ brass -s admin
      System user found: admin
      User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew

      # This will run all following operations as the admin user with the default homebrew refix
      user@mac\$ brass -Zs admin
      System user found: admin
      System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew


  -a: Run brew as console user if they are an admin. Run brew as a specified user if not. oot access is required.

      # this will run brew as the admin user even though otheradmin has been defined
      admin@mac\$ sudo brass -a otheradmin
        otheradmin user found.
        console user is a local administrator. Continuing as admin.
        User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew


  -n: Disables headless warnning.

      # This will run without any warnings
      admin@mac\$ sudo brass -na admin -u


  -l: NONINTERACTIVE mode

      # This will run reguardless of brew owner
      admin@mac\$ sudo brass -nls otheradmin
        otheradmin user found
        warning message Disabled
        headless mode enabled
        User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
        running as otheradmin


  -x: Checks for xcode updates.

      # This will check for an xcode update and then run as the admin user
      admin@mac\$ brass -xs admin


  -u: Checks for brew updates

      # This will check for a brew update
      admin@mac\$ brass -u


      # This will check as a brew update for the admin user
      user@mac\$ sudo brass -s admin -u


  -p: Installs a brew package

      # This will install the brew package sl
      admin@mac\$ brass -p sl


      # This will update brew and then install/update the package sl
      admin@mac\$ brass -up sl


      # This will run brew as admin user and then install/update package sl
      user@mac\$ sudo brass -s admin -up sl


  -d: Unnstalls a brew package

      # This will install the brew package sl
      admin@mac\$ brass -d sl


      # This will run brew as admin user and then uninstall package sl
      user@mac\$ sudo brass -s admin -d sl


  -t: Renstalls a brew package

      # This will reinstall the brew package sl
      admin@mac\$ brass -tp sl


      # This will update brew and then reinstall the package sl
      admin@mac\$ brass -utp sl


      # This will run brew as admin user and then reinstall package sl
      user@mac\$ sudo brass -s admin -utp sl


  -i: Installs brew

      # This will install brew to the users prefix
      admin@mac\$ brass -i
      # This will install brew to the default prefix
      admin@mac\$ brass -Zi


      # This will install brew as the admin user to the users prefix
      user@mac\$ sudo brass -s admin -i


      # This will install brew as the admin user with no warning and no interaction to the sers prefix
      user@mac\$ sudo brass -nls admin -i


  -r: Uninstalls brew

      # This will uninstall brew from the users prefix
      admin@mac\$ brass -u
      # This will uninstall brew from the default prefix
      admin@mac\$ brass -Zu


      # This will uninstall brew as the admin user from the users prefix
      user@mac\$ sudo brass -s admin -r


      # This will uninstall brew as the admin user with no warning and no interaction from he users prefix
      user@mac\$ sudo brass -nls admin -r


  -z: Reinstalls brew

      # This will reinstall brew to the users prefix
      admin@mac\$ brass -z

      # This will reinstall brew to the default prefix
      admin@mac\$ brass -Zz


      # This will reinstall brew as the admin user
      user@mac\$ sudo brass -z admin -s


      # This will reinstall brew as the admin user with no warning and no interaction
      user@mac\$ sudo brass -nlz admin -s

  -w: Displays GUI notification.

      # This will warn the user that brew is going to update with a popup window
      admin@mac\$ brass -w Updating brew -u

      # This will warn the user that brew is going to reinstall sl and then notify the user hen it is complete.
      admin@mac\$ brass -w reinstalling sl. This may take some time. -tp sl -w sl has been installed. Train away.


  -b: Shows debug information.

      # This will show debug information
      admin@mac\$ brass -b


      # This will update brew and then install package sl with debug information
      user@mac\$ brass -up sl -b


  -q: Checks for brass Updates

      # This will check for brass update
      admin@mac\$ brass -q
      brass update Enabled
      brass update available. Would you like to update to the latest version of brass? [Y/] y
      Installing brass to /usr/local/bin

      # This will check for brass update and update if found with no interaction.
      admin@mac\$ brass -lnq
      brass update Enabled
      brass update available.
      Installing brass to /usr/local/bin

  -h: Shows brass help

  -f: Shows brass flags
```


###  -X: Xcode management utility.
Using the -X flag enables the Xcode management utility.
```bash
    -o: Checks for the current installed version of Xcode

        # This will show the currently installed version of xcode installed.
        user@mac$ brass -Xo


    -l: Checks for the latest version of Xcode

        # This will check for the latest version of xcode available.
        user@mac$ brass -Xl


    -n: Installs the latest version of Xcode

        # This will install the latest version of xcode available.
        user@mac$ brass -Xn


    -r: Uninstalls Xcode

        # This will uninstall xcode
        user@mac$ brass -Xr


    -a: Updates to the latest version of Xcode

        # This will update to the latest version of xcode
        user@mac$ brass -Xa


    -h: Shows Xcode management utility help

        # This will show the help information for Xcode management utility
        user@mac$ brass -Xh
```
