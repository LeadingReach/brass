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
user_env() {
  brew_path="/Users/$user/.homebrew"; if [[ ! -d "$brew_path" ]]; then unset brew_path; else
  brew_bin="/Users/$user/.homebrew/bin/"
  brew_binary="/Users/$user/.homebrew/bin/brew"
  brew_user=$(ls -al $brew_path | awk '{ print $3; }')
  brew_cellar="/Users/$user/.homebrew/Cellar"
  brew_caskroom="/Users/$user/.homebrew/Caskroom"
  fi
}
#>
#< System enviroment variables
sys_env() {
  #< Architecture specific Directory varibales
  if [[ `uname -m` == 'arm64' ]]; then
    brew_user=$(ls -al /opt/homebrew/bin/brew | awk '{ print $3; }')
    brew_binary="/opt/homebrew/bin/brew"
    brew_path="/opt/homebrew"
    brew_cellar="/opt/homebrew/Cellar"
    brew_caskroom="/opt/homebrew/Caskroom"
  else
    brew_user=$(ls -al /usr/local/Homebrew/bin/brew | awk '{ print $3; }')
    brew_binary="/usr/local/Homebrew/bin/brew"
    brew_path="/usr/local/Homebrew"
  fi
  #>
}
#>
#< Script Functions
script_check() {
  while getopts 'c:u:C:ZvXxs:iruzp:d:t:f:nlaw:bqhyg' flag; do
    case "${flag}" in
      c) cfg="$OPTARG"; file="yes"; run_config; exit;;
      u) cfg="$OPTARG"; url="yes"; run_config; exit;;
      C) cfg="$@"; run_config; exit;;
      Z) system_runMode system;;
      v) system_verbose yes;;
      X) xcodeCall "$@";;
      x) xcode_update yes;;
      s) user="$OPTARG"; brew_user;;
      i) brew_install yes;;
      r) brew_uninstall yes;;
      u) brew_update yes;;
      z) brew_reset yes;;
      p) package="$OPTARG"; package_name $package;;
      d) package="$OPTARG"; package_delete $package;;
      t) package="$OPTARG"; package_reset $package;;
      f) package="$OPTARG"; package_force $package;;
      n) noWarnning="1";;
      l) system_force="yes";;
      a) system_ifAdmin yes; shift;;
      w) dialog=$(echo "$@" | awk -F "-w" '{print $2}' | awk -F"-" '{print $1}'); set=$(echo "$@" | awk -F"$dialog" '{print $2}'); notifyFlag;;
      b) brass_debug;;
      q) brass_update yes;;
      g) flags;;
      y) yaml;;
      h) help;;
      *) help;;
    esac
  done
  if [ $OPTIND -eq 1 ]; then brew_user; brewDo "$@"; fi
  sudo_reset
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
sudo_check() {
  if [ "$EUID" -ne 0 ];then
  err "sudo priviledges are reqired $@\n"
  exit
  fi
}
sudo_reset() {
  if [[ ! -z $system_force ]] || [[ ! -z $system_ifAdmin ]]; then
    say "removing brass sudoers entries\n"
    sed -i '' '/#brass/d' /etc/sudoers
  fi
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
    sudo_check "to run brew as another user"
    /usr/bin/sudo -i -u $user "$@"
  fi
}
noSudo() {
  system_user
  dirSudo=("/usr/sbin/chown" "/bin/launchctl" "/bin/rm" "SETENV:/usr/bin/env" "SETENV:/usr/bin/xargs" "SETENV:/usr/sbin/pkgutil")
  for str in ${dirSudo[@]}; do
    if [ -z $(/usr/bin/sudo cat /etc/sudoers | grep -e "$str""|""#brass") ]; then
      say "Modifying /etc/sudoers to allow $user to run $str as root without a password\n"
      echo "$user         ALL = (ALL) NOPASSWD: $str  #brass" | sudo EDITOR='tee -a' visudo > /dev/null
    else
      say "etc/sudoers already allows $user to run $str as root without a password\n"
    fi
  done
}
countdown() {
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
  if [[ $file == "yes" ]]; then
    cfg="$(parse_yaml $cfg)"
  elif [[ $url == "yes" ]]; then
    cfg="$(parse_yaml <(curl -s $cfg))"
  else
    cfg=$(echo "$cfg" | awk -F"\-C\ " '{print $2}' | tr ' ' '\n')
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
system_force() {
  if [[ "$@" == "yes" ]]; then
    sudo_check "to run in noninteractive mode"
    noSudo
  fi
}
#>
#< Notify Functions
notify_title(){
  if [[ -z "$@" ]]; then
    notify_title=brass
  else
    notify_title=$(echo "$@" | tr -d '"')
  fi
}
notify_iconLink() {
  if [[ -z "$@" ]]; then
    unset notify_iconLink
  else
    notify_iconLink=$(echo "$@" | tr -d '"')
    #curl "$notify_iconLink" --output "$notify_iconPath"
  fi
}
notify_iconPath() {
  if [[ -z "$@" ]]; then
    notify_icon="caution"
  else
    notify_iconPath=$(echo "$@" | tr -d '"')
    notify_icon="POSIX file (\"$notify_iconPath\" as string)"
  fi
}
notify_dialog() {
  notify_dialog="$@"
  if [[ -z $notify_dialog ]]; then
    echo "$@"
    err "Dialog must be specified"
  else
    notify_dialog=$(echo "$@" | tr -d '"')
  fi
}
notify_timeout() {
  if [[ -z "$@" ]]; then
    notify_timeout=10
  else
    notify_timeout=$(echo "$@" | tr -d '"')
  fi
}
notify_allowCancel() {
  notify_buttons="\"okay\", \"cancel\""
}
notify_display() {
  notify_run
}
notify_run() {
  notify_input=$(/usr/bin/osascript<<-EOF
    tell application "System Events"
    activate
    set myAnswer to button returned of (display dialog "$notify_dialog" buttons {$notify_buttons} giving up after $notify_timeout with title "$notify_title" with icon $notify_icon)
    end tell
    return myAnswer
    EOF)
    say "User user input: $notify_input\n"
    unset dialog
    if [[ $notify_input == "cancel" ]]; then
      exit
    fi
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
system_user() {
  if [[ -z $user ]]; then
    user=$consoleUser
  fi
  if id "$user" &>/dev/null; then
    say "System user found: $user\n"
  else
    err "$user not found"
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
system_foce() {
  if [[ "$@" == "yes" ]]; then
    system_foce="yes"
  else
    unset $system_foce
  fi
}
#>
#< Xcode Funtions
xcodeCall() {
  xcode_checkInstalled
  #< This checks for flags
  while getopts 'olnrah' flag; do
    case "${flag}" in
      o) xcode_checkInstalled ;;
      l) xcode_versionLatest ;;
      n) xcode_install ;;
      r) xcode_remove ;;
      a) xcode_update;;
      h) xcodeHelp ;;
    esac
  done
  #>
}
xcode_env() {
  xcode_path="/Library/Developer/CommandLineTools"; if [[ ! -d "$xcode_path" ]]; then unset xcode_path; else
  xcode_version=$(xcode_version)
  fi
}
xcode_checkInstalled() {
  xcode_env
  if [[ ! -d "$xcode_path" ]]; then
    printf "Xcode CommandLineTools directory not defined\n"
    if [[ -z $system_force ]]; then
      if [[ $EUID -ne 0 ]]; then
        xcode_install
      fi
      while true; do
        read -p "Would you like to install Xcode CommandLineTools? [Y/N] " yn
        case $yn in
            [Yy]* ) xcode_install;;
            [Nn]* ) echo "Xcode will not install. Exiting."; exit;;
            * ) echo "Please answer yes or no.";;
        esac
      done
    else
      printf "Installing Xcode CommandLineTools. ctrl+c to cancel:  "
      countdown
      xcode_install
    fi
  fi
  xcode_env
}
xcode_version() {
  pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | awk -F"version: " '{print $2}' | awk -v ORS="" '{gsub(/[[:space:]]/,""); print}' | awk -F"." '{print $1"."$2}'
}
xcode_versionLatest(){
  sudo_check "to check the latest version of xcode"
  /usr/bin/sudo /usr/bin/touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress  # Tricks apple software update
  /usr/bin/sudo /usr/sbin/softwareupdate -l | awk -F"Version:" '{ print $1}' | awk -F"Xcode-" '{ print $2 }' | sort -nr | head -n1
}
xcode_install () {
  /usr/bin/sudo /usr/sbin/softwareupdate -i Command\ Line\ Tools\ for\ Xcode-$(xcode_versionLatest)
  printf "\nXcode info:\n$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed 's/^/\t\t/')\n"
}
xcode_remove () {
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
    xcode_versionLatest
    #>
    #< Checks for the curently installed version of xcode
    xcode_checkInstalled
    #>
    #< Compares the two xcode versions to see if the curently installed version is less than the latest versoin
    if echo $xcodeVersion $xcode_versionLatest | awk '{exit !( $1 < $2)}'; then
      printf "\nXcode is outdate, updating Xcode version $xcodeVersion to $xcode_versionLatest"
      xcode_remove
      xcode_install
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
brew_env() {
  if [[ -z $system_runMode ]]; then
    user_env
    say "User Mode Enabled: Brew binary is located at $brew_binary\n"
  else
    sys_env
    say "System Mode Enabled: Brew binary is located at $brew_binary\n"
  fi
}
brew_user() {
  system_user
  say "brass user: $user\n"
  # Checks to see if sudo priviledges are required
  if [[ $user != $consoleUser ]]; then
    sudo_check "to run brew as another user"
  fi
  # Use proper env varables
  brew_env
  brew_check
}
brew_check() {
  if [[ -z $brew_path ]]; then
    printf "brew directory not defined\n"
    if [[ -z $system_force ]]; then
      while true; do
        read -p "Do you wish to install brew? [Y/N] " yn
        case $yn in
            [Yy]* ) brew_install yes; brew_env; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
      done
    else
      system_force yes
      brew_install yes
      brew_env
    fi
  fi
  #< Checks to see if brew is owned by the correct user
  if [[ $(stat $brew_path | awk '{print $5}') != $user ]] && [[ -d $brew_path ]]; then
    echo "$user does not own $brew_path"
    if [[ -z $system_force ]]; then
      read -p "Would you like for $user to take ownership of $brew_path? [Y/N] " yn
      case $yn in
          [Yy]* ) userDo sudo chown -R $user: $brew_path;;
          [Nn]* ) echo "Not owning $brew_path"; exit;;
          * ) echo "Please answer yes or no.";;
      esac
    else
      say "setting $user to own $brew_path\n"
      userDo sudo chown -R $user: $brew_path
    fi
  fi
  #>
}
brewDo() {
  if [[ $consoleUser == $user ]]; then
    if [ "$EUID" -ne 0 ] ;then
      $brew_binary "$@"
    else
      /usr/bin/sudo -i -u $user $brew_binary "$@"
    fi
  else
    /usr/bin/sudo -i -u $user $brew_binary "$@"
  fi
}
brew_install() {
  if [[ "$@" == "yes" ]]; then
    system_user
    if [[ -f $brew_binary ]]; then
      say "brew is installed as $user\n"
    else
      if [[ -z $system_runMode ]]; then
        mkdir -p $brew_path
        curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C $brew_path
      else
        say "install brew as system\n"
        brew_sysInstall
      fi
    fi
    brew_check
  fi
}
brew_uninstall() {
  brew_user
  if [[ "$@" == "yes" ]]; then
    if [[ -d $brew_path ]]; then
      if [[ -z $system_runMode ]]; then
        say "removing $brew_path\n"
        rm -r $brew_path
      else
        say "uninstall bew as system\n"
        brew_sysRemove
      fi
    else
      echo "No brew installation found"
    fi
  fi
}
brew_update() {
  if [[ "$@" == "yes" ]]; then
    brew_user
    say "brew_update: Enabled.\nUpdating brew\n"
    brewDo update
  fi
}
brew_reset(){
  if [[ "$@" == "yes" ]]; then
    brew_user
    brew_uninstall
    brew_install
  fi
}
brewOwnDirs() {
  brewSetDirs=("$brew_path")
  for str in ${brewSetDirs[@]}; do
    if [[ $(stat $str | awk '{print $5}') != $user ]]; then
      if [ -d $str ]; then
        echo "$user owning $str"
        sudo chown -R $user: $str
      else
        mkdir -p "$str"
        echo "$user owning $str"
        sudo chown -R $user: $str
      fi
    fi
  done
}
brass_debug() {
  if [[ "$@" == "yes" ]]; then
  # User information
  	printf "\nDebug - User information:\n"
  	printf "\tconsoleUser: $consoleUser\n"
  	printf "\tuserClass: $consoleUser is $userClass\n"
  	printf "\tbrew_user: brew will run as $user\n"
  # Package information
  	printf "\nDebug - Package Information\n"
  	if [ -z "$package_name" ]
  	then
  		printf "\tNo package defined."
  	else
  		printf "\tpackage info: $package_name\n"
  		brewDo info $package_name | sed 's/^/\t\t/'
  		if [[ $brewOwnPackage == 1 ]]; then
  			printf "\nbrewOwnPackage: Enabled.\n"
  			printf "\tpackage_nameDir=$package_nameDir\n"
  			printf "\tPermissions:\n$(ls -al $package_nameDir | sed 's/^/\t\t/')\n"
  			printf "\tpackagePath=$package_namePath\n"
  			printf "\tPermissions:\n$(ls -al $package_namePath | grep .app | sed 's/^/\t\t/')\n"
  			printf "\tpackage_nameLink=$package_nameLink\n"
  			printf "\tPermissions:\n$(ls -al $package_nameLink | sed 's/^/\t\t/')\n"
  			printf "\tpackageOwner=$package_nameOwner\n"
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
  	printf "\tbrew_user=$brew_user\n\tbrewBinary=$brew_binary\n\tbrewDir=$brewDir\n\tbrewCache=$brewCache\n"
  	brewDo --env | awk -F"export" '{ print $2 }' | sed 's/^/\t\t/'
  	printf "\nHOMEBREW_CACHE="
  	brewDo --cache | sed 's/^/\t\t/'
  	brewDo --cache | sed 's/^/\t\t/'
  fi
}
#< Brew System Functions
brew_sysInstall () {
  if [ -d $brew_binary ]; then
    printf "brew already installed.\n"
  else
    printf "\nNo Homebrew installation detectd.\nInstalling Homebrew.\nStarting brew install as $user\n"
    cd /Users/$user/
    brewOwnDirs
    yes | sudo -u $user /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "Brew install complete"
  fi
}
brew_sysRemove () {
  cd /Users/$user/
  if [[ -z $system_force ]]; then
    /usr/bin/sudo -u $user /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  else
    sudo -u $user echo -ne 'y\n' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  fi
}
#>
#>
#< Package Functions
package_env() {
  if [[ -z $(ls $brew_path/bin | grep $package) ]]; then
  packageDir="$brew_caskroom/$package"
  packageName=$(brewDo info $package | grep .app | awk -F"(" '{print $1}' | grep -v Applications)
  packageLink="/Applications/$packageName"
  packageOwner=$(stat $packageLink | awk '{print $5}')
else
  packageDir="$brew_path/bin/$package"
  packageOwner=$(stat $packageDir | awk '{print $5}')
  packageLink=$packageDir
fi
}
package_install() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package="$@"
    brew_user
    if [[ -z $package ]]; then
      read -p 'Which package would you like to install? ' package
    fi
    brew_check
    cd /Users/$user/
    package_env
    brewDo install $package
  fi
}
package_delete() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package="$@"
    brew_user
    if [[ -z $package ]]; then
      read -p 'Which package would you like to uninstall? ' package
    fi
    say "Brew is installed as $user\n"
    cd /Users/$user/
    package_env
    brewDo uninstall $package
  fi
}
package_force() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package="$@"
    brew_user
    if [[ -z $package ]]; then
      read -p 'Which package would you like to force install? ' package
    fi
    brew_check
    cd /Users/$user/
    package_env
    brewDo install $package -f
  fi
}
package_killProcess() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package_process="$@"
  fi
}
package_reset() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package="$@"
    brew_user
    pkill -9 $package_process
    package_delete $package
    brew_env
    brewDo install $package -f
  fi
}
package_resetAuto() {
  if [[ -n "$@" ]] && [[ "$@" != "no" ]]; then
    package="$@"
    brew_user
    package_nameProcess=$(echo $package | awk -F".app" '{ print $1 }')
    pkill -9 -f $package_nameProcess
    package_delete $package
    brew_env
    brewDo install $package -f
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
      if [[ -z $system_force ]]; then
        read -p "brass update available. Would you like to update to the latest version of brass? [Y/N] " yn
        case $yn in
            [Yy]* ) brass_upgrade;;
            [Nn]* ) printf "Skipping update\n";;
            * ) echo "Please answer yes or no.";;
        esac
      else
        brass_upgrade
      fi
    fi
    if [[ ! -z $quiet_force ]]; then
      brass_upgrade
    fi
  fi
}
brass_upgrade() {
  curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh --output /usr/local/bin/brass
  say "upgrade complete.\n"
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
#  -n: Disables force through warnning.
#
#      # This will run without any warnings
#      admin@mac\$ sudo brass -na admin -u
#
#
#  -l: NONINTERACTIVE force through mode
#
#      # This will run reguardless of brew owner
#      admin@mac\$ sudo brass -nls otheradmin
#        otheradmin user found
#        warning message Disabled
#        system_force mode enabled
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
#      admin@mac\$ brass -t sl
#
#
#      # This will update brew and then reinstall the package sl
#      admin@mac\$ brass -ut sl
#
#
#      # This will run brew as admin user and then reinstall package sl
#      user@mac\$ sudo brass -s admin -utp sl
#
#
#  -f: Force installs a brew package
#
#      # This will force install the brew package sl
#      admin@mac\$ brass -f sl
#
#
#      # This will update brew and then force install the package sl
#      admin@mac\$ brass -uf sl
#
#
#      # This will run brew as admin user and then force install package sl
#      user@mac\$ sudo brass -s admin -uf sl
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
#  -q: Shows brass flags
#
#  -y: Shows brass yaml configuration
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
yaml() {
  echo "
#  brass has the ability to to configured by a yaml config file.
#  The yaml configuration is seperated into seven categories.
#    admin@mac\$ brass -c \"/path/to/configfile.yaml\"
#
#  You can pass through yaml variables straight into brass
    admin@mac\$ brass -C system_runMode=\"local\" xcode_update=\"yes\" notify_dialog=\"are you sure you would like to install sl?\" notify_allowCancel=\"yes\" notify_display=\"yes\" #package_name=\"sl\"
#
#    brassconf.yaml example:         # you can name this what ever you would like
#
#    system:                         # to configure system Variables.
#      runMode: local | system       # local runs brew un a user specific prefix, system runs brew in the default system prefix.
#      verbose: yes | blank/no       # runs brass in verbose mode.
#      user: username                # specifies which user should run brass.
#      ifAdmin: yes | blank/no       # if the console user is an admin, it will ignore the specifed user and run as the console user.
#      force: yes | blank/no         # will push through the script configuration with no interaction.
#
#    xcode:                          # to configure xcode
#      update: yes | blank/no        # will install/update xcode CommandLineTools
#
#    brew:                           # to configure brew variable
#      install: yes | blank/no       # will install brew if it is not present.
#      uninstall: yes | blank/no     # will uninstall brew if it is present.
#      reset: yes | blank/no         # will reset brew if it is present.
#      update: yes | blank/no        # will update brew.
#
#    package:                        # to configure the brew package
#      name: package | blank/no      # the package you would like to configure. will install the package if not found unless you use the delete funtion.
#      delete: package | blank/no    # will delete package if present.
#      reset: yes | blank/no         # will reinstall the package
#      force: yes | blank/no         # will force install the package
#
#    brass:                          # to configure brass settings
#      update: yes | blank/no        # update brass
#      debug: ye | blank/no          # show brass debug information
#
#    notify:                         # shows applescript notification. This can be set anywhere in the configuation file as many times as needed.
#      title: Title | blank=brass    # title of the notification
#      iconPath: /path/icon | blank  # path to icon shown in notification. Leave blank if not needed. Spaces unsupported.
#      iconLink: \"icon.url/icon.png\" # this will download the icon to the specified path. Leave blank if not needed.
#      dialog: Hello world           # Dialog to be displaed in the notification.
#      timeout: 10 | blank=10        # how long the notification will stay up until the script contines.
#      allowCancel: yes | blank/no   # this will allow the user to stop brass at the time of the notification. Good for delaying updates.
#      display: yes | blank/no       # enables/disables the notification
    "
}
#>
#< logic
if [[ -z $@ ]]; then
  system_force="1"
  #< Checks to see if brass is installed
  if [[ ! -f /usr/local/bin/brass ]]; then
    echo "Installing brass to /usr/local/bin/brass"
    mkdir -p /usr/local/bin/
    curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh --output /usr/local/bin/brass
    chmod +x /usr/local/bin/brass
    say "done.\n\n"
  else
    xcode_checkInstalled
    script_check -q
  fi
  #>
  printf "use brass -h for more infomation.\n"
  exit
fi
script_check $@
OPTIND=1
if [[ ! -z "$set" ]]; then
  script_check $set
else
  say "done\n"
fi
#>
