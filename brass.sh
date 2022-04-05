#!/bin/bash
#<brass
#< enviroment variables
#< Architecture specific Directory varibales
if [[ `uname -m` == 'arm64' ]]; then
  brewUser=$(ls -al /opt/homebrew/bin/brew | awk '{ print $3; }')
  brewBinary="/opt/homebrew/bin/brew"
  brewDir="/opt/homebrew"
else
  brewUser=$(ls -al /usr/local/Homebrew/bin/brew | awk '{ print $3; }')
  brewBinary="/usr/local/Homebrew/bin/brew"
  brewDir="/usr/local/Homebrew"
fi
#>
#< Directory varibales
brewVar="/usr/local/var/homebrew"
brewLocal="/usr/local/Homebrew"
brewLocalBin="/usr/local/bin/brew"
brewCellar="$brewDir/Cellar"
brewCaskroom="$brewDir/Caskroom"
brewCache="$brewDir/Cache"
xcodeDir=$(xcode-select -p)
#>
#< Endpoint specific enviroment variables
# consoleUser - Get current logged in user
consoleUser=$(ls -l /dev/console | awk '{ print $3 }')
# userClass - Get if current logged in user is admin or standard
userClass=$(if groups "$consoleUser" | grep -q -w admin; then
  echo "admin"
  else
  echo "standard"
fi)
#>
#>
#< functions
check() {
  #< Checks to see if brass is installed
  if [[ ! -f /usr/local/bin/brass ]]; then
    echo "Installing brass to /usr/local/bin/brass"
    brassUpgrade
  fi
  #>
  #< Checks to see if xcode is installed
  if [[ ! -d $xcodeDir ]]; then
    printf "xcode directory not defined\n"
    while true; do
      read -p "Do you wish to install xcode? [Y/N] " yn
      case $yn in
          [Yy]* ) xcodeInstall;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  fi
  #>
  #< Chcks to see if brew is installed
  if [[ -z $brewDir ]]; then
    printf "brew directory not defined\n"
    while true; do
      read -p "Do you wish to install brew? [Y/N] " yn
      case $yn in
          [Yy]* ) brewInstall; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  fi
  #>
  #< This checks for flags
  while getopts 'Xx:mzup:od:IiRrs:bqnlafh' flag; do
    case "${flag}" in
      X) xcodeCall "$@";;
      x) xcodeUpdate;;
      m) user="$consoleUser"; ifAdmin=1; brewAsUser;;
      s) user="$OPTARG"; brewAsUser;;
      u) brewUpdate;;
      p) package="$OPTARG"; brewPackage;;
      o) brewOwnPackage=1;;
      d) package="$OPTARG"; brewRmPackage;;
      i) brewAsUser; brewInstall;;
      r) brewAsUser; brewRemove;;
      z) brewAsUser; brewReset;;
      b) brewDebug;;
      q) brassUpdate;;
      n) noWarnning="1";;
      l) headless="1";;
      a) ifAdmin="1";;
      f) flags;;
      h) help;;
      *) help;;
    esac
  done
  if [ $OPTIND -eq 1 ]; then brewAsUser; brewDo "$@"; fi
  #>
  #< This makes sure any sudo modificatoins are reversed
  forcePass
  #>
}
#< xcode funtions
xcodeCall() {
  #< Checks to see if xcode is installed
  if [[ ! -d $xcodeDir ]]; then
    printf "xcode directory not defined\n"
    while true; do
      read -p "Do you wish to install xcode? [Y/N] " yn
      case $yn in
          [Yy]* ) xcodeInstall;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  fi
  #>
  #< This checks for flags
  while getopts 'olnrah' flag; do
    case "${flag}" in
      o) xcodeCheckVersion ;;
      l) xcodeLatestVersion ;;
      n) xcodeInstall ;;
      r) xcodeRemove ;;
      a) xcodeUpdate;;
      h) xcodeHelp ;;
    esac
  done
  #>
}
xcodeCheckVersion() {
#< Checks for the currently installed version of xcode
  xcodeVersion=$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | awk -F"version: " '{print $2}' | awk -v ORS="" '{gsub(/[[:space:]]/,""); print}' | awk -F"." '{print $1"."$2}')
  printf "installed xcode Version $xcodeVersion\n"
#>
}
xcodeLatestVersion(){
#< Checks for the latest version of xcode
  #< Checks for sudo
  if [ "$EUID" -ne 0 ];then
    printf "sudo priviledges are reqired to check the latest version of xcode\n"
    exit
  fi
  #>
  #< Tricks apple software update
  /usr/bin/sudo /usr/bin/touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  printf "Checking for the latest version of xcode. This may take some time\n"
  #>
  #< Sets the variable
  xcodeLatestVersion=$(/usr/bin/sudo /usr/sbin/softwareupdate -l | awk -F"Version:" '{ print $1}' | awk -F"Xcode-" '{ print $2 }' | sort -nr | head -n1)
  printf "xcode latest version: $xcodeLatestVersion\n"
  #>
#>
}
xcodeInstall () {
#< Checks for the latest version of xcode
  #< Checks for the latest version of xcode
  xcodeLatestVersion
  #>
  #< Installs the latest version of xcode
  /usr/bin/sudo /usr/sbin/softwareupdate -i Command\ Line\ Tools\ for\ Xcode-$xcodeLatestVersion
  #>
  #< Prints xcode package info
  printf "\nXcode info:\n$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed 's/^/\t\t/')\n"
  exit 0
  #>
#>
}
xcodeRemove () {
  #< Checks to see if xcode directory is present
  if [[ -d /Library/Developer/CommandLineTools ]]; then
    printf "Uninstalling xcode\n"
    sudo rm -r /Library/Developer/CommandLineTools
  else
    printf "xcode not installed\n"
    exit 0
  fi
  #>
  #< Verifies that the uninstallation was sucsessful
  if [[ -d /Library/Developer/CommandLineTools ]]; then
    printf "error"
    exit 1
  else
    printf "xcode uninstalled\n"
  fi
  #>
}
xcodeUpdate() {
  #< Checks for the latest version of xcode
  xcodeLatestVersion
  #>
  #< Checks for the curently installed version of xcode
  xcodeCheckVersion
  #>
  #< Compares the two xcode versions to see if the curently installed version is less than the latest versoin
  if echo $xcodeVersion $xcodeLatestVersion | awk '{exit !( $1 < $2)}'; then
    printf "\nXcode is outdate, updating Xcode version $xcodeVersion to $xcodeLatestVersion"
    xcodeRemove
    xcodeInstall
  else
    printf "xcode is up to date.\n"
  fi
  #>
}
xcodeHelp() {
  # Prints xcode functions
  printf "xcodeMaster\n\\t-xv: Checks for installed version of xcode\n\t-xl: Checks for latest version of xcode available\n\t-xi: Installs the latest version of xcode\n\t-xu: Updates xcode to the latest version\n\t-xr: Removes xcode\n"
}
#>
#< brew functions
brewUser () {
#< Checks to see who should run brew
  #< Checks to see if the $user variable is specifed
  if [[ -z $user ]]; then
    #< if not - Checks to see if the user running the script owns brew
    if [[ $consoleUser == $brewUser ]]; then
      printf "console user $consoleUser\n"
      printf "Running brew as $brewUser\n"
      user=$consoleUser
    else
      #< Runs brew as another user
      brewAsUser
      #>
    fi
    #>
  fi
  #>
#>
}
brewAsUser() {
  #< Checks to see if brew is installed
  brewCheck
  #>
  #< Checks to see if user is present
  if id "$user" &>/dev/null; then
    printf "User found: $user\n"
  else
    if [[ -z $ifAdmin ]]; then
      printf "Running brass as $brewUser\n"
      user=$brewUser
    else
      printf "ifAdmin mode requies for a valid user to be specifed\n"
      exit
    fi
  fi
  #>
  #< Checks to see if script is being ran as root
  if [ "$EUID" -ne 0 ] && [[ $user != $consoleUser ]] ;then
    echo "Running brew as another user requires sudo priviledges"
    exit
  fi
  #>
  #< Checks to see if headless mode is enabled
  if [[ ! -z $headless ]] | [[ ! -z $ifAdmin ]]; then
    ifAdmin
    headless
    brewOwnDirs
  else
    #< Checks to see if user doesn't own brew
    if [[ $user != $brewUser ]]; then
      prompt() {
        printf "lol1\n"
      }
      read -p "$user does not own brew. $brewUser owns brew. Would you like for $user to take ownership of brew or use brew as $brewUser? [Own/As/Exit] " oae
      case $oae in
          [Oo]* ) brewOwnDirs;;
          [Aa]* ) prompt+=("$OPTARG");;
          [Ee]* ) exit;;
          * ) echo "Please answer own, as, or exit.";;
      esac
    fi
    #>
  fi
  #>
}
brewOwnDirs () {
  #< Sets directoris used by brew into an aray
  brewSetDirs=("$brewVar" "$brewLocal" "$brewLocalBin" "$brewDir" "$brewCache" "$brewCellar")
  #>
  #< Sets an action to be taken on each item in the arway
  for str in ${brewSetDirs[@]}; do
    #< Checks to see if the directory is owned by the user who will run brew
    if [[ $(stat $str | awk '{print $5}') != $user ]]; then
      #< Checks to see if the directory exsists
      if [ -d $str ]; then
        echo "$user owning $str"
        sudo chown -R $user: $str
      else
        mkdir -p "$str"
        echo "$user owning $str"
        sudo chown -R $user: $str
      fi
      #>
    fi
    #>
  done
  #>
}
brewRemove () {
  #< Moves into the brew users directory
  cd /Users/$user/
  #>
  #< Checks to see if noninteractive mode in enabled
  if [[ -z $headless ]]; then
    #< Sets uninstall command as Target user and initiates brew uninstall
    /usr/bin/sudo -u $user /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    #>
  else
    #< Sets uninstall command as Target user and inserts yes + return signal to initiate brew uninstall and uninstalls brew
    sudo -u $user echo -ne 'y\n' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    #>
  fi
  #>
}
brewInstall () {
  #< Checks to see if brew is installed
  if [ -d $brewBinary ]; then
    printf "brew already installed.\n"
    exit
  else
    printf "\nNo Homebrew installation detectd.\nInstalling Homebrew.\n"
  fi
  #>
  #< Moves into users directory
  printf "\nStarting brew install as $user\n"
  cd /Users/$user/
  #>
  #< Sets directory permissions
  brewOwnDirs
  #>
  #< Sets install command as Target user, inserts return signal to initiate brew install, and installs brew.
  /usr/bin/sudo -u $user NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "Brew install complete"
  #>
}
brewPackage () {
  #< Checks to see which user should run brew
  brewUser
  #>
  #< Checks to see if a package has been specifed
  if [[ -z $package ]]; then
    read -p 'Which package would you like to install? ' package
  fi
  #>
  #< Moves into users directory
  echo "Brew is owned by $user"
  cd /Users/$user/
  #>
  #< If $brewResetPackage is enabled, it will reinstall the brew package If $brewResetPackage is not enabled, it will install the package if it's not installed
  if [[ $brewResetPackage != 1 ]]; then
    #< Checks to see if package is installed. If so, skip installation
    if [[ ! -z $(brewDo list | grep $package) ]]; then
      echo "$package is installed"
    else
      #< Uses the brew user's enviroment variables
      eval $(/usr/bin/sudo -i -u $user printenv | grep -v "\-c")
      #>
      #< Installs the package with the force flag
      printf "$package is not installed from brew\n\n"
      brewDo install -f $package
      #>
    fi
    #>
  else
    #< Installs the package with the force flag
    echo "brewResetPackage enabled"
    brewDo install $package -f
    #>
  fi
  #>
  #< Sets package variables
  if [[ -z $(ls $brewCellar | grep $package) ]]; then
    packageDir="$brewCaskroom/$package"
    packageName=$(/usr/bin/sudo -i -u $user $brewBinary info $package | grep .app | awk -F"(" '{print $1}' | grep -v Applications)
    packageLink="/Applications/$packageName"
    packageOwner=$(stat $packageLink | awk '{print $5}')
  else
    packageDir="$brewCellar/$package"
    packageOwner=$(stat $packageDir | awk '{print $5}')
    packageLink=$packageDir
  fi
  #>
  #< Sets the console user to own the package if enabled
  if [[ ! -z $brewOwnPackage ]]; then
    printf "ownPackage: enabled\n"
    if [[ $consoleUser != $packageOwner ]]; then
      printf "Setting $consoleUser to own $packageLink\n"
      /usr/bin/sudo chown -R $consoleUser $packageLink
      /usr/bin/sudo chown -R $consoleUser $packageDir
    else
      printf "$consoleUser owns $packageLink\n"
    fi
  else
    #< Sets the brew user to own the package if they do not own it.
    if [[ $user != $packageOwner ]]; then
      printf "Setting $user to own $packageLink.\n"
      /usr/bin/sudo chown -R $user: $packageLink
      /usr/bin/sudo chown -R $user: $packageDir
    else
      printf "$user owns $packageLink.\n"
    fi
    #>
  fi
  #>
}
brewRmPackage () {
  brewUser
  if [[ -z $package ]]; then
    read -p 'Which package would you like to uninstall? ' package
  fi
  echo "Brew is installed as $user"
  cd /Users/$user/
  brewDo uninstall $package
}
brewUpdate () {
  brewUser
  printf "brewUpdate: Enabled.\nUpdating brew\n"
  brewDo update
  if [[ ! -z $package ]]; then
  # This upgrades the package
  printf "\nbrewUpdate: Enabled.\nUpdating $package\n"
  brewDo upgrade $package -f
  #notifyUser "$package has finished updateing. Please restart $package."
  fi
}
brewReset(){
  brewRemove
  brewInstall
}
brewCheck() {
  #< Checks to see if brew is installed
  if [[ -z $brewUser ]]; then
    if [[ -z $headless ]]; then
      printf "\n brew installation not found. Please install brew with brass -i\n"
      exit
    else
      brewInstall
    fi
  fi
  #>
}
brewDebug () {
# User information
	printf "\nDebug - User information:\n"
	printf "\tconsoleUser: $consoleUser\n"
	printf "\tuserClass: $consoleUser is $userClass\n"
	printf "\tbrewUser: brew will run as $user\n"
# Package information
	printf "\nDebug - Package Information\n"
	if [ -z "$package" ]
	then
		printf "\tNo package defined."
	else
		printf "\tpackage info: $package\n"
		brewDo info $package | sed 's/^/\t\t/'
		if [[ $brewOwnPackage == 1 ]]; then
			printf "\nbrewOwnPackage: Enabled.\n"
			printf "\tbrewPackageDir=$packageDir\n"
			printf "\tPermissions:\n$(ls -al $packageDir | sed 's/^/\t\t/')\n"
			printf "\tpackagePath=$packagePath\n"
			printf "\tPermissions:\n$(ls -al $packagePath | grep .app | sed 's/^/\t\t/')\n"
			printf "\tbrewPackageLink=$packageLink\n"
			printf "\tPermissions:\n$(ls -al $packageLink | sed 's/^/\t\t/')\n"
			printf "\tpackageOwner=$packageOwner\n"
		else
			printf "\nbrewOwnPackage: Disabled\n"
		fi
	fi
	# Xcode infomation
		printf "\nDebug - Xcode info:\n$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed 's/^/\t\t/')\n"
	# Check if brewReset is enabled
# Brew enviroment variables
	cd /Users/$user/
	printf "\nDebug - enviroment variables:\n"
	printf "\tbrewUser=$brewUser\n\tbrewBinary=$brewBinary\n\tbrewDir=$brewDir\n\tbrewCache=$brewCache\n"
	brewDo --env | awk -F"export" '{ print $2 }' | sed 's/^/\t\t/'
	printf "\nHOMEBREW_CACHE="
	brewDo --cache | sed 's/^/\t\t/'
	brewDo --cache | sed 's/^/\t\t/'
}
brewDo() {
  /usr/bin/sudo -i -u $user $brewBinary "$@"
}
#>
#< script functions
brassUpgrade() {
  #< Checks to see if script is being ran as root
  if [ "$EUID" -ne 0 ] && [[ $user != $consoleUser ]] ;then
    echo "Updating brass requires sudo priviledges"
    exit
  else
      /usr/bin/sudo curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/master/brass.sh > /usr/local/bin/brass
      printf "upgrade complete.\n"
  fi

}
brassUpdate() {
  brassBinary=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && echo "$(pwd)/bras*")
  brassData=$(cat $brassBinary)
  brassGet=$(curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/testing-update/brass.sh)
  brassDif=$(echo ${brassGet[@]} ${brassData[@]} | tr ' ' '\n' | sort | uniq -u)
  if [[ -z $brassDif ]]; then
    printf "brass is up to date.\n"
  else
    if [[ -z $headless ]]; then
      read -p "brass update available. Would you like to update to the latest version of brass? [Y/N] " yn
      case $yn in
          [Yy]* ) brassUpgrade;;
          [Nn]* ) printf "Skipping update\n";;
          * ) echo "Please answer yes or no.";;
      esac
    else
      if [[ -z $noWarnning ]]; then
        printf "brass update available. use flag -n to automatically install the latest version of brass\n"
      else
        brassUpgrade
      fi
    fi
  fi
  if [[ ! -z "${UPGRADE-}" ]]; then
    brassUpgrade
  fi
}
warning() {
  if [[ -z $noWarnning ]]; then
  	printf "\n#################################\nTHIS WILL MODIFY THE SUDOERS FILE\n#################################\n(It will change back after completion)\n"
    printf "Are you sure that you would like to continue? ctrl+c to cancel\n\nTimeout:  "
    sp="9876543210"
  	secs=$(perl -e 'print time(), "\n"')
  	((targetsecs=secs+10))
    while ((secs < targetsecs))
    do
      printf "\b${sp:i++%${#sp}:1}"
  		sleep 1
  		secs=$(perl -e 'print time(), "\n"')
    done
    sleep 1
  	printf "\nYou have been warned.\n"
    sleep 1
  fi
}
noSudo() {
  dirSudo=("/usr/sbin/chown" "/bin/launchctl" "$brewBinary")
  for str in ${dirSudo[@]}; do
    if [ -z $(/usr/bin/sudo cat /etc/sudoers | grep -e "$str""|""#brass") ]; then
      printf "Modifying /etc/sudoers to allow $user to run $str as root without a password\n"
      echo "$user         ALL = (ALL) NOPASSWD: $str #brass" | sudo EDITOR='tee -a' visudo
    else
      printf "etc/sudoers already allows $user to run $str as root without a password\n"
    fi
  done
}
forcePass() {
  if [ ! -z $headless ] && [ ! -z $(/usr/bin/sudo cat /etc/sudoers | grep -e "#brass") ]; then
    printf "removing brass sudoers entries\n"
    sed -i '' '/#brass/d' /etc/sudoers
  fi
}
headless() {
  if [ "$EUID" -ne 0 ];then
    echo "Headless mode must run as root"
    exit
  fi
  warning
  noSudo
}
ifAdmin() {
  #< Checks to see if ifAdmin mode is enabled
  if [[ $ifAdmin == 1 ]]; then
    if [[ $userClass == "admin" ]]; then
      printf "Brew admin enabled: $consoleUser is an admin user. Running brew as $consoleUser\n"
      user=$consoleUser
    fi
  fi
  #>
}
help () {
  echo "
  # Standard brew commands
  admin@mac\$ brass install sl
    running brew as admin


  # Standard brew commands as another user
  user@mac\$ sudo brass install sl
    running brew as admin


  brass can use its own flags to specify which user should run brew.
  When using brass flags, the standard brew commands such as install and info no longer work.

  admin@mac\$ brass -s admin
    user admin found


  user@mac\$ sudo brass -s admin
    user admin found


  # Install a package as admin
  user@mac\$ sudo brass -s admin -p sl
    user admin found
    brew is owned by admin
    sl is not installed from brew
    installing sl


  # Uninstall a package as admin
  user@mac\$ sudo brass -s admin -d sl
    user admin found
    brew is owned by admin
    uninstalling sl


  # Update xcode and brew, then install package sl as user admin with debug information
  user@mac\$ sudo brass -s admin -xup sl -b


  brass has the ability to change brews ownership.

  # Install a package as user
  user@mac\$ sudo brass -s user -p sl
    user found: user
    user does not own brew. admin owns brew. Would you like for user to take ownership of brew or use brew as admin? [Own/As/Exit] oae


  # Install a package as user with no interaction
  user@mac\$ sudo brass -s user -p sl
    user found: user
    user will take ownership of brew


  # Install a package as otheradmin unless console user is an admin
    admin@mac\$ sudo brass -as otheradmin -p sl
    user found: otheradmin
    admin is an admin. admin will take ownership of brew


  # Install a package as user with no interaction and no warning
  user@mac\$ sudo brass -ns user -p sl
    user found: user
    user will take ownership of brew
  "

}
flags() {
  echo "
  -s: Run as user. Root access is required.

      # This will run all following operations as the admin user
      user@mac\$ brass -s admin


  -a: Run brew as console user if they are an admin. Run brew as a specified user if not. Root access is required.

      # this will run brew as the admin user even though otheradmin has been defined
      admin@mac\$ sudo brass -A otheradmin
        otheradmin user found.
        console user is a local administrator. Continuing as admin.


  -m: Run brew as console user if they are an admin. No user must be specifed. Root access is required.

    # This will run brew as admin user
    admin@mac\$ sudo brass -m
      admin user found.
      console user is a local administrator. Setting brew to admin


  -n: Disables headless warnning.

      # This will run without any warnings
      admin@mac\$ sudo brass -na admin -u


  -l: NONINTERACTIVE mode

      # This will run reguardless of brew owner
      admin@mac\$ sudo brass -nls otheradmin -u
        otheradmin user found
        warning message Disabled
        headless mode enabled
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


  -o: Sets the currently logged in user as the owner of the package

      # This will install the sl package as admin, and then set user as owner of the sl package
      user@mac\$ brass -s admin -op sl
      user found: admin
      installing sl
      ownPackage: enabled
      setting user to own sl


  -i: Installs brew

      # This will install brew
      admin@mac\$ brass -i


      # This will install brew as the admin user
      user@mac\$ sudo brass -s admin -i


      # This will install brew as the admin user with no warning and no interaction
      user@mac\$ sudo brass -nls admin -i


  -r: Uninstalls brew

      # This will uninstall brew
      admin@mac\$ brass -u


      # This will uninstall brew as the admin user
      user@mac\$ sudo brass -s admin -r


      # This will uninstall brew as the admin user with no warning and no interaction
      user@mac\$ sudo brass -nls admin -r


  -z: Reinstalls brew

      # This will reinstall brew
      admin@mac\$ brass -z


      # This will reinstall brew as the admin user
      user@mac\$ sudo brass -z admin -s


      # This will reinstall brew as the admin user with no warning and no interaction
      user@mac\$ sudo brass -nlz admin -s


  -b: Shows debug information.

      # This will show debug information
      admin@mac\$ brass -b


      # This will update brew and then install package sl with debug information
      user@mac\$ brass -up sl -b


  -h: Shows brass help


  ###  -X: Xcode management utility.

  Using the -X flag enables the Xcode management utility.

    -o: Checks for the current installed version of Xcode

        # This will show the currently installed version of xcode installed.
        user@mac\$ brass -Xo


    -l: Checks for the latest version of Xcode

        # This will check for the latest version of xcode available.
        user@mac\$ brass -Xl


    -n: Installs the latest version of Xcode

        # This will install the latest version of xcode available.
        user@mac\$ brass -Xn


    -r: Uninstalls Xcode

        # This will uninstall xcode
        user@mac\$ brass -Xr


    -a: Updates to the latest version of Xcode

        # This will update to the latest version of xcode
        user@mac\$ brass -Xa


    -h: Shows Xcode management utility help

        # This will show the help information for Xcode management utility
        user@mac\$ brass -Xh
  "
}
#>
#>
#< logic
if [[ -z $@ ]]; then
  printf "use brass -h for more infomation.\n"
  exit
fi
check $@
#>
#>
