# brass
### Brew As Script

brass is a utility designed to run brew on endpoints with multiple users.

## Disclaimer
This script requires sudo access for many of its functions. This script may modify the sudoers file.  Run this script at your own risk.

## Installation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/master/brass.sh)"
```

## Usage
```bash
  # Standard brew commands
  admin@mac$ brass install sl
    running brew as admin

  # Standard brew commands as another user
  user@mac$ sudo brass install sl
    running brew as admin
```

brass can use its own flags to specify which user should run brew.
When using brass flags, the standard brew commands such as install and info no longer work.

```bash    
admin@mac$ brass -s admin
  user admin found


user@mac$ sudo brass -s admin
  user admin found


# Install a package as admin
user@mac$ sudo brass -s admin -p sl
  user admin found
  brew is owned by admin
  sl is not installed from brew
  installing sl


# Uninstall a package as admin
user@mac$ sudo brass -s admin -d sl
  user admin found
  brew is owned by admin
  uninstalling sl


# Update xcode and brew, then install package sl as user admin with debug information
user@mac$ sudo brass -s admin -xup sl -b

```
brass has the ability to change brews ownership.
```
# Install a package as user
user@mac$ sudo brass -s user -p sl
  user found: user
  user does not own brew. admin owns brew. Would you like for user to take ownership of brew or use brew as admin? [Own/As/Exit] oae


# Install a package as user with no interaction
user@mac$ sudo brass -ls user -p sl
  user found: user
  user will take ownership of brew


# Install a package as otheradmin unless console user is an admin
  admin@mac$ sudo brass -as otheradmin -p sl
  user found: otheradmin
  admin is an admin. admin will take ownership of brew


# Install a package as user with no interaction and no warning
user@mac$ sudo brass -nls user -p sl
  user found: user
  user will take ownership of brew
"

```

## flags
```bash
-s: Run as user. Root access is required.

    # This will run all following operations as the admin user
    user@mac$ brass -s admin


-a: Run brew as console user if they are an admin. Run brew as a specified user if not. Root access is required.

    # this will run brew as the admin user even though otheradmin has been defined
    admin@mac$ sudo brass -a otheradmin
      otheradmin user found.
      console user is a local administrator. Continuing as admin.


-m: Run brew as console user if they are an admin. No user must be specifed. Root access is required.

  # This will run brew as admin user
  admin@mac$ sudo brass -m
    admin user found.
    console user is a local administrator. Setting brew to admin


-n: Disables headless warnning.

    # This will run without any warnings
    admin@mac$ sudo brass -na admin -u


-l: NONINTERACTIVE mode

    # This will run reguardless of brew owner
    admin@mac$ sudo brass -nls otheradmin -u
      otheradmin user found
      warning message Disabled
      headless mode enabled
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


-o: Sets the currently logged in user as the owner of the package

    # This will install the sl package as admin, and then set user as owner of the sl package
    user@mac$ brass -s admin -op sl
    user found: admin
    installing sl
    ownPackage: enabled
    setting user to own sl


-i: Installs brew

    # This will install brew
    admin@mac$ brass -i


    # This will install brew as the admin user
    user@mac$ sudo brass -s admin -i


    # This will install brew as the admin user with no warning and no interaction
    user@mac$ sudo brass -nls admin -i


-r: Uninstalls brew

    # This will uninstall brew
    admin@mac$ brass -u


    # This will uninstall brew as the admin user
    user@mac$ sudo brass -s admin -r


    # This will uninstall brew as the admin user with no warning and no interaction
    user@mac$ sudo brass -nls admin -r


-z: Reinstalls brew

    # This will reinstall brew
    admin@mac$ brass -z


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
      brass update available. Would you like to update to the latest version of brass? [Y/N] y
      Installing brass to /usr/local/bin

      # This will check for brass update and update if found with no interaction.
      admin@mac$ brass -lnq
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
