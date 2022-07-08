# brass
### Brew As Script

brass is a utility designed to run brew on endpoints with multiple users.

## Disclaimer
This script requires sudo access for many of its functions. This script may modify the sudoers file.  Run this script at your own risk.
This script has only been tested on macOS 12

## Installation

```bash
sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-dev/brass.sh)"
```

## Basic Usage
brass can act as a 1 to 1 stand in for brew. Use any brew command after brass and it will run brew in a user specific prefix.
```bash
  admin@mac$ brass install sl

    brass user: admin
    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    Installing sl
    done

```

### brass can use its own flags to specify which user should run brew.
### When using brass flags, the standard brew commands such as install and info no longer work.

```bash    
  user@mac$ sudo brass -s admin

    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    done


  # Install a package as admin
  user@mac$ sudo brass -s admin -p sl

    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    Installing sl
    done

  # Uninstall a package as admin
  user@mac$ sudo brass -s admin -d sl

    System user found: admin
    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
    Uninstalling /Users/admin.homebrew/Cellar/sl/5.02... (6 files, 37.5KB)
    done

  # Update xcode and brew, then install package sl as user admin with debug information
  user@mac$ sudo brass -s admin -xup sl -b
```
### brass has the ability to manage the default homebrew prefix.
``` bash
  # Install a package as admin with the default homebrew prefix
  user@mac$ sudo brass -Zs admin -p sl

    System user found: admin
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    Installing sl
    done


  # Install a package as a user who doesn't own the default homebrew prefix
  user@mac$ sudo brass -Zp sl

    System user found: user
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    user does not own /opt/homebrew
    Would you like for user to take ownership of /opt/homebrew? [Y/N] y
    Installing sl
    done


  # Install a package as a user who doesn't own the default homebrew prefix
  user@mac$ sudo brass -nlZp sl

    System user found: user
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    user does not own /opt/homebrew
    user taking ownership of /opt/homebrew
    Installing sl
    done
```
### More examples
```bash

  # Install a package as otheradmin unless console user is an admin
    admin@mac$ sudo brass -as otheradmin -p sl

    System user found: otheradmin
    Brew admin enabled: admin is an admin user. Running brew as admin
    User Mode Enabled: Brew binary is located at /Users/carlpetry/.homebrew/bin/brew
    Installing sl
    done


  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix
    admin@mac$ sudo brass -Zas otheradmin -p sl

    System user found: otheradmin
    Brew admin enabled: admin is an admin user. Running brew as admin
    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
    Installing sl
    done


  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix,
  # with no interaction, no warning, and display debug information.
    admin@mac$ sudo brass -Znlas otheradmin -p sl -b
```

## flags
```bash
  -Z: Run brew with default homebrew prefix

      # This will run all following operations as the admin user
      user@mac$ sudo brass -Z
      System user found: admin
      System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew


  -s: Run as user. Root access is required.

      # This will run all following operations as the admin user
      user@mac$ brass -s admin
      System user found: admin
      User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew

      # This will run all following operations as the admin user with the default homebrew refix
      user@mac$ brass -Zs admin
      System user found: admin
      System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew


  -a: Run brew as console user if they are an admin. Run brew as a specified user if not. oot access is required.

      # this will run brew as the admin user even though otheradmin has been defined
      admin@mac$ sudo brass -a otheradmin
        otheradmin user found.
        console user is a local administrator. Continuing as admin.
        User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew


  -n: Disables headless warnning.

      # This will run without any warnings
      admin@mac$ sudo brass -na admin -u


  -l: NONINTERACTIVE mode

      # This will run reguardless of brew owner
      admin@mac$ sudo brass -nls otheradmin
        otheradmin user found
        warning message Disabled
        headless mode enabled
        User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
        running as otheradmin


  -x: Checks for xcode updates.

      # This will check for an xcode update and then run as the admin user
      admin@mac$ brass -xs admin


  -u: Checks for brew updates

      # This will check for a brew update
      admin@mac$ brass -u


      # This will check as a brew update for the admin user
      user@mac$ sudo brass -s admin -u


  -p: Installs a brew package

      # This will install the brew package sl
      admin@mac$ brass -p sl


      # This will update brew and then install/update the package sl
      admin@mac$ brass -up sl


      # This will run brew as admin user and then install/update package sl
      user@mac$ sudo brass -s admin -up sl


  -d: Unnstalls a brew package

      # This will install the brew package sl
      admin@mac$ brass -d sl


      # This will run brew as admin user and then uninstall package sl
      user@mac$ sudo brass -s admin -d sl


  -t: Reinstalls a brew package

      # This will reinstall the brew package sl
      admin@mac$ brass -tp sl


      # This will update brew and then reinstall the package sl
      admin@mac$ brass -utp sl


      # This will run brew as admin user and then reinstall package sl
      user@mac$ sudo brass -s admin -utp sl


  -i: Installs brew

      # This will install brew to the users prefix
      admin@mac$ brass -i
      # This will install brew to the default prefix
      admin@mac$ brass -Zi


      # This will install brew as the admin user to the users prefix
      user@mac$ sudo brass -s admin -i


      # This will install brew as the admin user with no warning and no interaction to the sers prefix
      user@mac$ sudo brass -nls admin -i


  -r: Uninstalls brew

      # This will uninstall brew from the users prefix
      admin@mac$ brass -u
      # This will uninstall brew from the default prefix
      admin@mac$ brass -Zu


      # This will uninstall brew as the admin user from the users prefix
      user@mac$ sudo brass -s admin -r


      # This will uninstall brew as the admin user with no warning and no interaction from he users prefix
      user@mac$ sudo brass -nls admin -r


  -z: Reinstalls brew

      # This will reinstall brew to the users prefix
      admin@mac$ brass -z

      # This will reinstall brew to the default prefix
      admin@mac$ brass -Zz


      # This will reinstall brew as the admin user
      user@mac$ sudo brass -z admin -s


      # This will reinstall brew as the admin user with no warning and no interaction
      user@mac$ sudo brass -nlz admin -s


  -b: Shows debug information.

      # This will show debug information
      admin@mac$ brass -b


      # This will update brew and then install package sl with debug information
      user@mac$ brass -up sl -b


  -q: Checks for brass Updates

      # This will check for brass update
      admin@mac$ brass -q
      brass update Enabled
      brass update available. Would you like to update to the latest version of brass? [Y/] y
      Installing brass to /usr/local/bin

      # This will check for brass update and update if found with no interaction.
      admin@mac$ brass -lnq
      brass update Enabled
      brass update available.
      Installing brass to /usr/local/bin

  -h: Shows brass help

  -f: Shows brass flags
```

### -c/-C: brass yaml configuration
brass has the ability to to configured by a yaml config file.
Use -c to point brass towards your yaml file
Or use -C to pass through yaml variables straight into brass
```bash
    admin@mac$ brass -c "/path/to/configfile.yaml"

    admin@mac$ brass -C system_runMode="local" xcode_update="yes" notify_dialog="are you sure you would like to install sl?" notify_allowCancel="yes" notify_display="yes" package_name="sl"
```
You can use a url with -g
And pass through an authorization token with -j
```bash
    admin@mac$ brass -g https://raw.githubusercontent.com/bullshit/project/master/config.yaml

    admin@mac$ brass -j ghp_OWYNuN2JVYzP0Wd1quyUhU5vsoQRlMM3oCPuX -g https://raw.githubusercontent.com/bullshit/project/master/config.yaml
```
The yaml configuration is separated into seven categories.
brassconf.yaml example:    
```bash

    system:                         # to configure system Variables.
      runMode: local | system       # local runs brew un a user specific prefix, system runs brew in the default system prefix.
      verbose: yes | blank/no       # runs brass in verbose mode.
      user: username                # specifies which user should run brass.
      ifAdmin: yes | blank/no       # if the console user is an admin, it will ignore the specifed user and run as the console user.
      force: yes | blank/no         # will push through script configuration with no interaction.

    xcode:                          # to configure xcode
      update: yes | blank/no        # will install/update xcode CommandLineTools

    brew:                           # to configure brew variable
      install: yes | blank/no       # will install brew if it is not present.
      uninstall: yes | blank/no     # will uninstall brew if it is present.
      reset: yes | blank/no         # will reset brew if it is present.
      update: yes | blank/no        # will update brew.

    package:                        # to configure the brew package
      install: package | blank/no   # the package you would like to configure. will install the package if not found unless you use the delete function.
      delete: package | blank/no    # will delete package if present.
      reset: yes | blank/no         # will reinstall the package
      force: yes | blank/no         # will force install the package

    process:
      kill: process | blank  # this will kill a process with pkill -9

    user:
      command: whoami               # will run any bash command as the consoleUser

    brass:                          # to configure brass settings
      update: yes | blank/no        # update brass
      debug: ye | blank/no          # show brass debug information

    notify:                         # shows applescript notification. This can be set anywhere in the configuation file as many times as needed.
      title: Title | blank=brass    # title of the notification
      iconLink: "icon.url/icon.png" # this will download the icon to the specified path. Leave blank if not needed.
      iconPath: /path/icon | blank  # path to icon shown in notification. Leave blank if not needed. Spaces unsupported.
      dialog: Hello world           # Dialog to be displaed in the notification.
      timeout: 10 | blank=10        # how long the notification will stay up until the script contines.
      allowCancel: yes | blank/no   # this will allow the user to stop brass at the time of the notification. Good for delaying updates.
```
###  Brass system configuration
A brass.yaml configuration file can be stored in either the system directory or the user specific direcotry.
```
/Library/brass
/Users/$(whoami)/.brass
```
This configuration file will apply to all brass commands by default unless over ridden by a command or package configuration file.
#### Example brass.yaml
```
system:
  secret:
  runMode: local
  verbose: yes
  user: lcadmin
  ifAdmin: no
  force: yes

brass:
  update: yes
  debug: yes
```
### brass.yaml with notes
```
system:
  secret: *github auth token to pull configuration files from git*
  runMode: local # specifis that brass should use the default system brew prefix
  verbose: yes # Shows log fies
  user: admin # the user that will run brew commands
  ifAdmin: no # brass will ise the admin user reguardless of the system user's admin status
  force: yes # brass confguration will be applied if there are any comflics.

brass:
  update: yes # checks for brass update
  debug: yes # shows debug information
```
### Using brass to manage packages across several endpoints
brass can be used to install, manage, and update brew packages across several endpoints. There are very many ways to do so using and MDM like Jamf or JumpCloud. The method I perfer pushes packages that contain yaml configuration profiles to the /Library/brass/pkg folder and then runs brass to install new packages.
#### Work flow example
1) Create a package using software similar to Jamf Composer or KosalaHerath/macos-installer-builder that contains package yaml file(s) in /Library/brass/pkg
2) Use your MDM to distribute these packages to the intended endpoints
3) Run ```brass -m ``` on intended endpoints to look for and install any new packages.

You may also consider creating a policy that runs ```brass -M``` periodically to keep managed packages up to date.


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
