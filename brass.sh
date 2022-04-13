#!/bin/bash
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
#< User enviroment variables
userEnv(){
  brewPath="/Users/$user/.homebrew"
  brewBin="/Users/$user/.homebrew/bin/"
  brewBinary="/Users/$user/.homebrew/bin/brew"
  brewUser=$(ls -al $brewPath | awk '{ print $3; }')
  brewCellar="/Users/$user/.homebrew/Cellar"
  brewCaskroom="/Users/$user/.homebrew/Caskroom"
  xcodeDir=$(xcode-select -p)
  export PATH="$brewBin:$PATH"
  if [[ -z $(cat /Users/$user/.zprofile | grep $brewBin) ]]; then
    export PATH="$brewBin:$PATH"
    echo "Adding $brewBin to PATH"
    echo "export PATH="$brewBin:$PATH"" >> /Users/$user/.zprofile
  fi
}
#>
#< System enviroment variables
xcodeDir=$(xcode-select -p)
sysEnv() {
  #< Architecture specific Directory varibales
  if [[ `uname -m` == 'arm64' ]]; then
    brewUser=$(ls -al /opt/homebrew/bin/brew | awk '{ print $3; }')
    brewBinary="/opt/homebrew/bin/brew"
    brewPath="/opt/homebrew"
    brewCellar="/opt/homebrew/Cellar"
    brewCaskroom="/opt/homebrew/Caskroom"
  else
    brewUser=$(ls -al /usr/local/Homebrew/bin/brew | awk '{ print $3; }')
    brewBinary="/usr/local/Homebrew/bin/brew"
    brewPath="/usr/local/Homebrew"
  fi
  #>
}
#>
#< Script Functions
check() {
  xcodeCheck
  #< This checks for flags
  while getopts 'c:C:ZvXxs:iruzp:d:tfnlaw:bqhf' flag; do
    case "${flag}" in
      c) cfg="$OPTARG"; file="yes"; run_config; exit;;
      C) cfg="$@"; run_config; exit;;
      Z) system_runMode system;;
      v) system_verbose yes;;
      X) xcodeCall "$@";;
      x) xcode_update yes;;
      s) user="$OPTARG"; brewUser;;
      i) brew_install yes;;
      r) brew_uninstall yes;;
      u) brew_update yes;;
      z) brew_reset yes;;
      p) package="$OPTARG"; package_name $package;;
      d) package="$OPTARG"; package_delete $package;;
      t) package_reset yes;;
      f) package_force yes;;
      n) noWarnning="1";;
      l) brew_force yes;;
      a) ifAdmin="1";;
      w) dialog=$(echo "$@" | awk -F "-w" '{print $2}' | awk -F"-" '{print $1}'); set=$(echo "$@" | awk -F"$dialog" '{print $2}'); notifyFlag;;
      b) brass_debug;;
      q) brass_update yes;;
      f) flags;;
      h) help;;
      *) help;;
    esac
  done
  if [ $OPTIND -eq 1 ]; then brewUser; brewDo "$@"; fi
  #< This makes sure any sudo modificatoins are reversed
  if [[ ! -z $brew_force ]] || [[ ! -z $ifAdmin ]]; then
    forcePass
  fi
  #>
}
say() {
  if [[ ! -z $system_verbose ]]; then
    printf "$@"
  fi
}
err() {
  printf '%s\n' "$1" >&2
  exit 1
}
notifyFlag() {
  notify_title="brass"
  notify_timeout="10"
  applescriptCode="display dialog \"$dialog\" buttons {\"Okay\"} giving up after $notify_timeout with title \"$notify_title\""
  say "Displaying notification to user\n$dialog\n"
  /usr/bin/osascript -e "$applescriptCode" &> /dev/null
  say "Notification dismissed\n"
  unset dialog
}
userDo() {
  if [[ $consoleUser == $user ]]; then
      "$@"
  else
    /usr/bin/sudo -i -u $user "$@"
  fi
}
noSudo() {
  brewUser
  dirSudo=("/usr/sbin/chown" "/bin/launchctl" "$brewBinary")
  for str in ${dirSudo[@]}; do
    if [ -z $(/usr/bin/sudo cat /etc/sudoers | grep -e "$str""|""#brass") ]; then
      say "Modifying /etc/sudoers to allow $user to run $str as root without a password\n"
      echo "$user         ALL = (ALL) NOPASSWD: $str #brass" | sudo EDITOR='tee -a' visudo > /dev/null
    else
      say "etc/sudoers already allows $user to run $str as root without a password\n"
    fi
  done
}
forcePass() {
  if [[ -z $forcePass ]]; then
    say "removing brass sudoers entries\n"
    sed -i '' '/#brass/d' /etc/sudoers
  fi
  forcePass="1"
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
run_config () {
  if [[ $file != "yes" ]]; then
    echo cmd
    cfg="$(echo $cfg | tr ' ' '\n' | sed 1d)"
    echo "$cfg"
  else
    echo file
    cfg="$(parse_yaml $cfg)"
  fi
  while IFS= read -r line; do
    run=$(echo $line | awk -F'=' '{print $1}')
    if [[ $run == notify* ]]; then
      str=$(echo $line | awk -F'=' '{print $2}')
    else
      str=$(echo $line | awk -F'=' '{print $2}' | tr -d '"')
    fi
    $run $str
  done < <(echo "$cfg")
}
parse_yaml() {
  # Special thanks to https://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}
#>
#>
#< Notify Functions
notify_timeout() {
  if [[ -z "$@" ]]; then
    notify_timeout=10
  else
    notify_timeout="$@"
  fi
}
notify_title(){
  if [[ -z "$@" ]]; then
    notify_title=brass
  else
    notify_title="$@"
  fi
}
notify_iconPath() {
  if [[ -z "$@" ]]; then
    unset notify_iconPath
  else
    notify_iconPath=$(echo "$@" | tr -d '"')
  fi
}
notify_iconLink() {
  if [[ -z "$@" ]]; then
    unset notify_iconLink
  else
    notify_iconLink=$(echo "$@" | tr -d '"')
  fi
}
notify_dialog() {
  notify_dialog="$@"
  if [[ -z $notify_dialog ]]; then
    echo "$@"
    err "Dialog must be specified"
  else
    notify_dialog="$@"
  fi
  if [[ -n $notify_iconLink ]]; then
    curl "$notify_iconLink" --output "$notify_iconPath"
  fi
  if [[ ! -z $notify_iconPath ]]; then
    applescriptCode="display dialog $notify_dialog buttons {\"Okay\"} giving up after $notify_timeout with title $notify_title with icon POSIX file (\"$notify_iconPath\" as string)"
  else
    applescriptCode="display dialog $notify_dialog buttons {\"Okay\"} giving up after $notify_timeout with title $notify_title"
  fi
  /usr/bin/osascript -e "$applescriptCode" &> /dev/null
  unset dialog
}
#>
#< System Functions
system_runMode() {
  if [[ "$@" == "system" ]]; then
    system_runMode="yes"
  else
    unset $system_runMode
  fi
}
system_verbose() {
  if [[ "$@" == "yes" ]]; then
    system_verbose="yes"
  else
    unset $system_verbose
  fi
}
#>
#< User Functions
system_user() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    user="$@"
    brewUser
  fi
}
system_ifAdmin() {
  if [[ "$@" == "yes" ]]; then
    if [[ $userClass == "admin" ]]; then
      say "Brew admin enabled: $consoleUser is an admin user. Running brew as $consoleUser\n"
      user=$consoleUser
    fi
  fi
}
#>
#< Xcode Funtions
xcodeCall() {
  xcodeDir=$(xcode-select -p)
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
      a) xcode_update;;
      h) xcodeHelp ;;
    esac
  done
  #>
}
xcodeCheck() {
  #< Checks to see if xcode is installed
if [[ ! -d $xcodeDir ]]; then
  if [[ -z $ifAdmin ]]; then
    printf "xcode directory not defined\n"
    while true; do
      read -p "Do you wish to install xcode? [Y/N] " yn
      case $yn in
          [Yy]* ) xcodeInstall;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  else
    xcodeInstall
  fi
fi
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
xcode_update() {
  if [[ "$@" == "yes" ]]; then
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
  fi
  #>
}
xcodeHelp() {
  # Prints xcode functions
  printf "xcodeMaster\n\\t-xv: Checks for installed version of xcode\n\t-xl: Checks for latest version of xcode available\n\t-xi: Installs the latest version of xcode\n\t-xu: Updates xcode to the latest version\n\t-xr: Removes xcode\n"
}
#>
#< Brew Functions
brewUser() {
  if [[ -z $brewUser ]]; then
    # Checks to see who should run brew
    #Checks to see if the $user variable is specifed
    if [[ -z $user ]]; then
      user=$consoleUser
      say "brass user: $user\n"
    fi
    # Checks to see if user is present
    if id "$user" &>/dev/null; then
      say "System user found: $user\n"
    else
      err "$user not found"
    fi
    # Checks to see if sudo priviledges are required
    if [[ $user != $consoleUser ]] && [ "$EUID" -ne 0 ] ;then
      err "Running brew as another user requires sudo priviledges"
    fi
    # Use proper env varables
    if [[ -z $system_runMode ]]; then
      userEnv
      say "User Mode Enabled: Brew binary is located at $brewBinary\n"
    else
      sysEnv
      say "System Mode Enabled: Brew binary is located at $brewBinary\n"
    fi
    brewCheck
    if [[ ! -z $ifAdmin ]]; then
      ifAdmin
    fi
  fi
  brewUser="1"
}
brewCheck() {
  #< Checks to see if brew is installed
  if [[ -z $brewBinary ]]; then
    printf "brew directory not defined\n"
    while true; do
      read -p "Do you wish to install brew? [Y/N] " yn
      case $yn in
          [Yy]* ) brew_install; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  fi
  #>
  #< Checks to see if brew is owned by the correct user
  if [[ $(stat $brewPath | awk '{print $5}') != $user ]] && [[ -d $brewPath ]]; then
    echo "$user does not own $brewPath"
    if [[ -z $brew_force ]]; then
      read -p "Would you like for $user to take ownership of $brewPath? [Y/N] " yn
      case $yn in
          [Yy]* ) userDo sudo chown -R $user: $brewPath;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    else
      say "setting $user to own $brewPath\n"
      userDo sudo chown -R $user: $brewPath
    fi
  fi
  #>
}
brewDo() {
  if [[ $consoleUser == $user ]]; then
    if [ "$EUID" -ne 0 ] ;then
      $brewBinary "$@"
    else
      /usr/bin/sudo -i -u $user $brewBinary "$@"
    fi
  else
    /usr/bin/sudo -i -u $user $brewBinary "$@"
  fi
}
brew_install() {
  if [[ "$@" == "yes" ]]; then
    brewUser
    if [[ -f $brewBinary ]]; then
      say "brew is installed as $user\n"
    else
      if [[ -z $system_runMode ]]; then
        mkdir -p $brewPath
        curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C $brewPath
      else
        say "install brew as system\n"
        brewSysInstall
      fi
    fi
    brewCheck
  fi
}
brew_uninstall() {
  brewUser
  if [[ "$@" == "system" ]]; then
    if [[ -d $brewPath ]]; then
      if [[ -z $system_runMode ]]; then
        say "removing $brewPath\n"
        rm -r $brewPath
      else
        say "uninstall bew as system\n"
        brewSysRemove
      fi
    else
      echo "No brew installation found"
    fi
  fi
}
brew_update() {
  if [[ "$@" == "yes" ]]; then
    brewUser
    say "brew_update: Enabled.\nUpdating brew\n"
    brewDo update
  fi
}
brew_reset(){
  if [[ "$@" == "yes" ]]; then
    brewUser
    brew_uninstall
    brew_install
  fi
}
brew_force() {
  if [[ "$@" == "yes" ]]; then
    if [ "$EUID" -ne 0 ];then
      err "Error: brew_force mode must run as root"
    fi
    warning
    noSudo
  fi
}
brewOwnDirs() {
  #< Sets directoris used by brew into an aray
  brewSetDirs=("$brewPath")
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
brass_debug() {
  if [[ "$@" == "yes" ]]; then
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
  			printf "\tpackage_nameDir=$packageDir\n"
  			printf "\tPermissions:\n$(ls -al $packageDir | sed 's/^/\t\t/')\n"
  			printf "\tpackagePath=$packagePath\n"
  			printf "\tPermissions:\n$(ls -al $packagePath | grep .app | sed 's/^/\t\t/')\n"
  			printf "\tpackage_nameLink=$packageLink\n"
  			printf "\tPermissions:\n$(ls -al $packageLink | sed 's/^/\t\t/')\n"
  			printf "\tpackageOwner=$packageOwner\n"
  		else
  			printf "\nbrewOwnPackage: Disabled\n"
  		fi
  	fi
  	# Xcode infomation
  		printf "\nDebug - Xcode info:\n$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed 's/^/\t\t/')\n"
  	# Check if brew_reset is enabled
  # Brew enviroment variables
  	cd /Users/$user/
  	printf "\nDebug - enviroment variables:\n"
  	printf "\tbrewUser=$brewUser\n\tbrewBinary=$brewBinary\n\tbrewDir=$brewDir\n\tbrewCache=$brewCache\n"
  	brewDo --env | awk -F"export" '{ print $2 }' | sed 's/^/\t\t/'
  	printf "\nHOMEBREW_CACHE="
  	brewDo --cache | sed 's/^/\t\t/'
  	brewDo --cache | sed 's/^/\t\t/'
  fi
}
#< Brew System Functions
brewSysInstall () {
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
   yes | sudo -u $user /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "Brew install complete"
  #>
}
brewSysRemove () {
  #< Moves into the brew users directory
  cd /Users/$user/
  #>
  #< Checks to see if noninteractive mode in enabled
  if [[ -z $brew_force ]]; then
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
#>
#>
#< Package Functions
package_name() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package="$@"
    brewUser
    #< Checks to see if a package has been specifed
    if [[ -z $package ]]; then
      read -p 'Which package would you like to install? ' package
    fi
    #>
    brewCheck
    #< Moves into users directory
    cd /Users/$user/
    #>
    #< Sets package variables
    if [[ -z $(ls $brewPath/bin | grep $package) ]]; then
      packageDir="$brewCaskroom/$package"
      packageName=$(brewDo info $package | grep .app | awk -F"(" '{print $1}' | grep -v Applications)
      packageLink="/Applications/$packageName"
      packageOwner=$(stat $packageLink | awk '{print $5}')
    else
      packageDir="$brewPath/bin/$package"
      packageOwner=$(stat $packageDir | awk '{print $5}')
      packageLink=$packageDir
    fi
    #>
    #< If $package_reset is enabled, it will reinstall the brew package If $package_reset is not enabled, it will install the package if it's not installed
    if [[ -z $package_reset ]]; then
      #< Checks to see if package is installed. If so, skip installation
      if [[ ! -z $(brewDo list | grep -w $package) ]]; then
        printf "$package is installed\n"
      else
        #< Installs the package with the force flag
        say "$package is not installed from brew\n\n"
        if [[ -z $package_force ]]; then
          brewDo install $package
        else
          brewDo install -f $package
        fi
        #>
      fi
      #>
    else
      #< Runs package_reset
      say "package_reset enabled\n"
      package_reset
      #>
    fi
    #>
  fi
  #brewOwnPackage
}
package_delete() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    brewUser
    if [[ -z $package ]]; then
      read -p 'Which package would you like to uninstall? ' package
    fi
    say "Brew is installed as $user\n"
    cd /Users/$user/
    brewDo uninstall $package
  fi
}
package_force() {
  if [[ "$@" == "yes" ]]; then
    package_force="yes"
  else
    unset $package_force
  fi
}
package_reset() {
  if [[ "$@" == "yes" ]]; then
    package_reset="1"
    package_nameProcess=$(echo $packageName | awk -F".app" '{ print $1 }')
    pkill -9 -f $package_nameProcess
    package_delete
    brewEnv
    brewDo install -f $package
  fi
}
#>
#< Brass Functions
brass_update() {
  if [[ "$@" == "yes" ]]; then
    brassBinary=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && echo "$(pwd)/bras*")
    brassData=$(cat $brassBinary)
    brassGet=$(curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh)
    brassDif=$(echo ${brassGet[@]} ${brassData[@]} | tr ' ' '\n' | sort | uniq -u)
    if [[ -z $brassDif ]]; then
      printf "brass is up to date.\n"
    else
      if [[ -z $brew_force ]]; then
        read -p "brass update available. Would you like to update to the latest version of brass? [Y/N] " yn
        case $yn in
            [Yy]* ) brass_update;;
            [Nn]* ) printf "Skipping update\n";;
            * ) echo "Please answer yes or no.";;
        esac
      else
        if [[ -z $noWarnning ]]; then
          printf "brass update available. use flag -n to automatically install the latest version of brass\n"
        else
          brass_update
        fi
      fi
    fi
    if [[ ! -z "${UPGRADE-}" ]]; then
      brass_update
    fi
  fi
}
brass_update() {
  curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh > /usr/local/bin/brass
  printf "upgrade complete.\n"
}
help () {
  echo "
#  # Standard brew commands
#
#  admin@mac\$ brass install sl
#
#    brass user: admin
#    System user found: admin
#    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#    Installing sl
#    done
#
#  brass can use its own flags to specify which user should run brew.
#  When using brass flags, the standard brew commands such as install and info no longer work.
#
#  user@mac\$ sudo brass -s admin
#
#    System user found: admin
#    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#    done
#
#
#  # Install a package as admin
#  user@mac\$ sudo brass -s admin -p sl
#
#    System user found: admin
#    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#    Installing sl
#    done
#
#  # Uninstall a package as admin
#  user@mac\$ sudo brass -s admin -d sl
#
#    System user found: admin
#    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#    Uninstalling /Users/admin.homebrew/Cellar/sl/5.02... (6 files, 37.5KB)
#    done
#
#  # Update xcode and brew, then install package sl as user admin with debug information
#  user@mac\$ sudo brass -s admin -xup sl -b
#
#
#  brass has the ability to manage the default homebrew prefix.
#
#  # Install a package as admin with the default homebrew prefix
#  user@mac\$ sudo brass -Zs admin -p sl
#
#    System user found: admin
#    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#    Installing sl
#    done
#
#
#  # Install a package as a user who doesn't own the default homebrew prefix
#  user@mac\$ sudo brass -Zp sl
#
#    System user found: user
#    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#    user does not own /opt/homebrew
#    Would you like for user to take ownership of /opt/homebrew? [Y/N] y
#    Installing sl
#    done
#
#
#  # Install a package as a user who doesn't own the default homebrew prefix
#  user@mac\$ sudo brass -nlZp sl
#
#    System user found: user
#    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#    user does not own /opt/homebrew
#    user taking ownership of /opt/homebrew
#    Installing sl
#    done
#
#
#  # Install a package as otheradmin unless console user is an admin
#    admin@mac\$ sudo brass -as otheradmin -p sl
#
#    System user found: otheradmin
#    Brew admin enabled: admin is an admin user. Running brew as admin
#    User Mode Enabled: Brew binary is located at /Users/carlpetry/.homebrew/bin/brew
#    Installing sl
#    done
#
#
#  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix
#    admin@mac\$ sudo brass -Zas otheradmin -p sl
#
#    System user found: otheradmin
#    Brew admin enabled: admin is an admin user. Running brew as admin
#    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#    Installing sl
#    done
#
#
#  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix,
#  # with no interaction, no warning, and display debug information.
#    admin@mac\$ sudo brass -Znlas otheradmin -p sl -b
#
#
#  # You can configure custom text to be displayed in a pop up window at any stage of the script
#    admin@mac\$ brass -w Starting brew update. -u -w Brew update complete.
#
#    #########BRASS#########
#    #Starting brew update.#
#    #######################
#
#    brass user: admin
#    System user found: admin
#    User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#    brew_update: Enabled.
#    Updating brew
#    Already up-to-date.
#
#    #########BRASS#########
#    #Brew update complete##
#    #######################
#
#
#  # Install a package as otheradmin unless console user is an admin with the default homebrew prefix,
#  # with no interaction, no warning, and display debug information
#  # while showing custom message before and after completion.
#    admin@mac\$ brass -Znlas otheradmin -w Installing sl. -p sl -b -w done.
#
#    System user found: otheradmin
#    System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#
#    #########BRASS#########
#    ### Installing sl. ####
#    #######################
#
#    Installing sl
#
#    #########BRASS#########
#    ######## done #######*#
#    #######################
  "

}
flags() {
  echo "
#  -Z: Run brew with default homebrew prefix
#
#      # This will run all following operations as the admin user
#      user@mac\$ sudo brass -Z
#      System user found: admin
#      System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#
#
#  -s: Run as user. Root access is required.
#
#      # This will run all following operations as the admin user
#      user@mac\$ brass -s admin
#      System user found: admin
#      User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#
#      # This will run all following operations as the admin user with the default homebrew prefix
#      user@mac\$ brass -Zs admin
#      System user found: admin
#      System Mode Enabled: Brew binary is located at /opt/homebrew/bin/brew
#
#
#  -a: Run brew as console user if they are an admin. Run brew as a specified user if not. Root access is required.
#
#      # this will run brew as the admin user even though otheradmin has been defined
#      admin@mac\$ sudo brass -a otheradmin
#        otheradmin user found.
#        console user is a local administrator. Continuing as admin.
#        User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#
#
#  -n: Disables brew_force warnning.
#
#      # This will run without any warnings
#      admin@mac\$ sudo brass -na admin -u
#
#
#  -l: NONINTERACTIVE mode
#
#      # This will run reguardless of brew owner
#      admin@mac\$ sudo brass -nls otheradmin
#        otheradmin user found
#        warning message Disabled
#        brew_force mode enabled
#        User Mode Enabled: Brew binary is located at /Users/admin/.homebrew/bin/brew
#        running as otheradmin
#
#
#  -x: Checks for xcode updates.
#
#      # This will check for an xcode update and then run as the admin user
#      admin@mac\$ brass -xs admin
#
#
#  -u: Checks for brew updates
#
#      # This will check for a brew update
#      admin@mac\$ brass -u
#
#
#      # This will check as a brew update for the admin user
#      user@mac\$ sudo brass -s admin -u
#
#
#  -p: Installs a brew package
#
#      # This will install the brew package sl
#      admin@mac\$ brass -p sl
#
#
#      # This will update brew and then install/update the package sl
#      admin@mac\$ brass -up sl
#
#
#      # This will run brew as admin user and then install/update package sl
#      user@mac\$ sudo brass -s admin -up sl
#
#
#  -d: Unnstalls a brew package
#
#      # This will install the brew package sl
#      admin@mac\$ brass -d sl
#
#
#      # This will run brew as admin user and then uninstall package sl
#      user@mac\$ sudo brass -s admin -d sl
#
#
#  -t: Renstalls a brew package
#
#      # This will reinstall the brew package sl
#      admin@mac\$ brass -tp sl
#
#
#      # This will update brew and then reinstall the package sl
#      admin@mac\$ brass -utp sl
#
#
#      # This will run brew as admin user and then reinstall package sl
#      user@mac\$ sudo brass -s admin -utp sl
#
#
#  -i: Installs brew
#
#      # This will install brew to the users prefix
#      admin@mac\$ brass -i
#      # This will install brew to the default prefix
#      admin@mac\$ brass -Zi
#
#
#      # This will install brew as the admin user to the users prefix
#      user@mac\$ sudo brass -s admin -i
#
#
#      # This will install brew as the admin user with no warning and no interaction to the users prefix
#      user@mac\$ sudo brass -nls admin -i
#
#
#  -r: Uninstalls brew
#
#      # This will uninstall brew from the users prefix
#      admin@mac\$ brass -u
#      # This will uninstall brew from the default prefix
#      admin@mac\$ brass -Zu
#
#
#      # This will uninstall brew as the admin user from the users prefix
#      user@mac\$ sudo brass -s admin -r
#
#
#      # This will uninstall brew as the admin user with no warning and no interaction from the users prefix
#      user@mac\$ sudo brass -nls admin -r
#
#
#  -z: Reinstalls brew
#
#      # This will reinstall brew to the users prefix
#      admin@mac\$ brass -z
#
#      # This will reinstall brew to the default prefix
#      admin@mac\$ brass -Zz
#
#
#      # This will reinstall brew as the admin user
#      user@mac\$ sudo brass -z admin -s
#
#
#      # This will reinstall brew as the admin user with no warning and no interaction
#      user@mac\$ sudo brass -nlz admin -s
#
#  -w: Displays GUI notification.
#
#      # This will warn the user that brew is going to update with a popup window
#      admin@mac\$ brass -w Updating brew -u
#
#      # This will warn the user that brew is going to reinstall sl and then notify the user when it is complete.
#      admin@mac\$ brass -w reinstalling sl. This may take some time. -tp sl -w sl has been reinstalled. Train away.
#
#
#  -b: Shows debug information.
#
#      # This will show debug information
#      admin@mac\$ brass -b
#
#
#      # This will update brew and then install package sl with debug information
#      user@mac\$ brass -up sl -b
#
#
#  -q: Checks for brass Updates
#
#      # This will check for brass update
#      admin@mac\$ brass -q
#      brass update Enabled
#      brass update available. Would you like to update to the latest version of brass? [Y/N] y
#      Installing brass to /usr/local/bin
#
#      # This will check for brass update and update if found with no interaction.
#      admin@mac\$ brass -lnq
#      brass update Enabled
#      brass update available.
#      Installing brass to /usr/local/bin
#
#  -h: Shows brass help
#
#  -f: Shows brass flags
#
#
#  ###  -X: Xcode management utility.
#
#  Using the -X flag enables the Xcode management utility.
#
#    -o: Checks for the current installed version of Xcode
#
#        # This will show the currently installed version of xcode installed.
#        user@mac\$ brass -Xo
#
#
#    -l: Checks for the latest version of Xcode
#
#        # This will check for the latest version of xcode available.
#        user@mac\$ brass -Xl
#
#
#    -n: Installs the latest version of Xcode
#
#        # This will install the latest version of xcode available.
#        user@mac\$ brass -Xn
#
#
#    -r: Uninstalls Xcode
#
#        # This will uninstall xcode
#        user@mac\$ brass -Xr
#
#
#    -a: Updates to the latest version of Xcode
#
#        # This will update to the latest version of xcode
#        user@mac\$ brass -Xa
#
#
#    -h: Shows Xcode management utility help
#
#        # This will show the help information for Xcode management utility
#        user@mac\$ brass -Xh
  "
}
#>
#< logic
if [[ -z $@ ]]; then
  #< Checks to see if brass is installed
  if [[ ! -f /usr/local/bin/brass ]]; then
    echo "Installing brass to /usr/local/bin/brass"
    brass_update
    chmod +x /usr/local/bin/brass
    say "done.\n\n"
  fi
  #>
  printf "use brass -h for more infomation.\n"
  exit
fi
check $@
OPTIND=1
if [[ ! -z "$set" ]]; then
  check $set
else
  say "done\n"
fi
#>
