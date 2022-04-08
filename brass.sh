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
  xcodeDir=$(xcode-select -p)
}
#>

check() {
  #< This checks for flags
  while getopts 'ZXxs:iruzp:d:tfnlaw:bq' flag; do
    case "${flag}" in
      Z) brewSystem="1";;
      X) xcodeCall "$@";;
      x) xcodeUpdate;;
      s) user="$OPTARG"; brewUser;;
      i) brewInstall;;
      r) brewRemove;;
      u) brewUpdate;;
      z) brewReset;;
      p) package="$OPTARG"; brewPackage;;
      d) package="$OPTARG"; brewRmPackage;;
      t) brewResetPackage="1";;
      f) brewForcePackage="1";;
      n) noWarnning="1";;
      l) headless;;
      a) ifAdmin="1";;
      w) dialog=$(echo "$@" | awk -F "-w" '{print $2}' | awk -F"-" '{print $1}'); set=$(echo "$@" | awk -F"$dialog" '{print $2}'); notify;;
      b) brewDebug;;
      q) brassUpdate;;
      *) help;;
    esac
  done
}

#< Brew Functions
brewUser () {
  # Checks to see who should run brew
  #Checks to see if the $user variable is specifed
  if [[ -z $user ]]; then
    user=$consoleUser
    echo "No user defined. Continuing as $user"
  fi
  # Checks to see if user is present
  if id "$user" &>/dev/null; then
    printf "User found: $user\n"
  else
    echo "$suer not found"
  fi
  # Checks to see if sudo priviledges are required
  if [[ $user != $consoleUser ]] && [ "$EUID" -ne 0 ] ;then
    echo "Running brew as another user requires sudo priviledges"
    exit
  fi
  # Use proper env varables
  if [[ -z $brewSystem ]]; then
    echo "User Mode"
    userEnv
  else
    echo "System Mode"
    sysEnv
  fi
  brewCheck
  if [[ ! -z $ifAdmin ]]; then
    ifAdmin
  fi
}
brewCheck() {
  if [[ $(stat $brewPath | awk '{print $5}') != $user ]] && [[ -d $brewPath ]]; then
    echo "$user does not own $brewPath"
    if [[ -z $headless ]]; then
      read -p "Would you like for $user to take ownership of $brewPath? [Y/N] " yn
      case $yn in
          [Yy]* ) userDo sudo chown -R $user: $brewPath;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    else
      echo "setting $user to own $brewPath"
      userDo sudo chown -R $user: $brewPath
    fi
  fi
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
brewInstall() {
  brewUser
  if [[ -f $brewBinary ]]; then
    echo "brew is installed as $user"
  else
    if [[ -z $brewSystem ]]; then
      mkdir -p $brewPath
      curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C $brewPath
    else
      echo "install brew as system"
      brewSysInstall
    fi
  fi
  brewCheck
}
brewRemove() {
  brewUser
  if [[ -d $brewPath ]]; then
    if [[ -z $brewSystem ]]; then
      echo "removing $brewPath"
      rm -r $brewPath
    else
      echo "uninstall bew as system"
      brewSysRemove
    fi
  else
    echo "No brew installation found"
  fi
}
brewUpdate() {
  brewUser
  printf "brewUpdate: Enabled.\nUpdating brew\n"
  brewDo update
}
brewReset(){
  brewUser
  brewRemove
  brewInstall
}
brewPackage () {
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
  #< If $brewResetPackage is enabled, it will reinstall the brew package If $brewResetPackage is not enabled, it will install the package if it's not installed
  if [[ -z $brewResetPackage ]]; then
    #< Checks to see if package is installed. If so, skip installation
    if [[ ! -z $(brewDo list | grep -w $package) ]]; then
      echo "$package is installed"
    else
      #< Installs the package with the force flag
      printf "$package is not installed from brew\n\n"
      if [[ -z $brewForcePackage ]]; then
        brewDo install $package
      else
        brewDo install -f $package
      fi
      #>
    fi
    #>
  else
    #< Runs brewResetPackage
    echo "brewResetPackage enabled"
    brewResetPackage
    #>
  fi
  #>
  #brewOwnPackage
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
brewResetPackage() {
  brewPackageProcess=$(echo $packageName | awk -F".app" '{ print $1 }')
  pkill -9 -f $brewPackageProcess
  brewRmPackage
  brewEnv
  brewDo install -f $package
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
#>
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
#>
#< Script Functions
userDo() {
  if [[ $consoleUser == $user ]]; then
      "$@"
  else
    /usr/bin/sudo -i -u $user "$@"
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
headless() {
  headless="1"
  if [ "$EUID" -ne 0 ];then
    echo "Headless mode must run as root"
    exit
  fi
  warning
  noSudo
}
ifAdmin() {
  ifAdmin="1"
  if [[ $userClass == "admin" ]]; then
    printf "Brew admin enabled: $consoleUser is an admin user. Running brew as $consoleUser\n"
    user=$consoleUser
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
notify() {
  notifyTitle="brass"
  notifyTimeout="10"
  applescriptCode="display dialog \"$dialog\" buttons {\"Okay\"} giving up after $notifyTimeout with title \"$notifyTitle\""
  /usr/bin/osascript -e "$applescriptCode" &> /dev/null
  unset dialog
}
brassUpdate() {
  brassBinary=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && echo "$(pwd)/bras*")
  brassData=$(cat $brassBinary)
  brassGet=$(curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/master/brass.sh)
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
#>
#< xcode funtions
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
#< logic
if [[ -z $@ ]]; then
  #< Checks to see if brass is installed
  if [[ ! -f /usr/local/bin/brass ]]; then
    echo "Installing brass to /usr/local/bin/brass"
    #brassUpgrade
    #chmod +x /usr/local/bin/brass
    printf "done.\n\n"
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
  echo done
fi
#>
#>
