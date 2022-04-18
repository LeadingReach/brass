#!/bin/bash
#< System requirements
# Checks to see if bash is being used
if [ -z "${BASH_VERSION:-}" ]
then
  echo "Bash is required to interpret this script."
  exit 1
fi
#>

#< Script Functions
script_check() {
  while getopts 'c:g:j:C:Zvxs:iruzp:d:t:f:nlabqhyg' flag; do
    case "${flag}" in
      c) cfg="$OPTARG"; file="yes"; run_config; exit;;
      j) token="$OPTARG";;
      g) cfg="$OPTARG"; url="yes"; run_config; exit;;
      C) cfg="$@"; run_config; exit;;
      Z) system_runMode system; env_brew;;
      v) system_verbose yes;;
      x) xcode_update yes;;
      s) SYSTEM_USER="$OPTARG";;
      i) brew_install yes;;
      r) brew_uninstall yes;;
      u) brew_update yes;;
      z) brew_reset yes;;
      p) PACKAGE="$OPTARG"; package_install $PACKAGE;;
      d) PACKAGE="$OPTARG"; package_delete $PACKAGE;;
      n) noWarnning="1";;
      l) SYSTEM_FORCE yes;;
      a) SYSTEM_IFADMIN yes; shift;;
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
  if [[ ${SYSTEM_VEROBSE} == "yes" ]]; then
    printf "$@"
  fi
}
err() {
  printf '%s\n' "$1" >&2
  brass_debug
  sudo_reset
  exit 77
}
userDo() {
  if [[ $consoleUser == ${SYSTEM_USER} ]]; then
      "$@"
  else
    sudo_check "to run as another user"
    /usr/bin/sudo -i -u ${SYSTEM_USER} "$@"
  fi
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
  printf "\n"
  sleep 1
}
warning() {
  if [[ -z $noWarnning ]]; then
  	printf "\n#################################\nTHIS WILL MODIFY THE SUDOERS FILE\n#################################\n(It will change back after completion)\n"
    printf "Are you sure that you would like to continue? ctrl+c to cancel\n\nTimeout:  "; countdown
    sleep 1
  	printf "\nYou have been warned.\n"
    sleep 1
  fi
}
sudo_check() {
  # Checks to see if sudo binary is executable
  if [[ ! -x "/usr/bin/sudo" ]]
  then
    err "sudo binary not executable"
  fi

  # Checks to see if script has sudo priviledges
  if [ "$EUID" -ne 0 ];then
  err "sudo priviledges are reqired $@"
  fi
}
sudo_disable() {
  system_user
  dirSudo=("SETENV:/usr/sbin/chown" "SETENV:/bin/launchctl" "SETENV:/bin/rm" "SETENV:/usr/bin/env" "SETENV:/usr/bin/xargs" "SETENV:/usr/sbin/pkgutil" "SETENV:/bin/mkdir" "SETENV:/bin/mv")
  for str in ${dirSudo[@]}; do
    if [ -z $(/usr/bin/sudo cat /etc/sudoers | grep "$str" | grep "#brass") ]; then
      str_binary=$(echo "$str" | awk -F"/" '{print $(NF)}')
      say "Modifying /etc/sudoers to allow ${SYSTEM_USER} to run ${str_binary} as root without a password\n"
      echo "${SYSTEM_USER}         ALL = (ALL) NOPASSWD: $str  #brass" | sudo EDITOR='tee -a' visudo > /dev/null
    else
      say "etc/sudoers already allows ${SYSTEM_USER} to run $str as root without a password\n"
    fi
  done
}
sudo_reset() {
  say "removing brass sudoers entries\n"
  sed -i '' '/#brass/d' /etc/sudoers
}
run_config () {
  if [[ $file == "yes" ]]; then
    cfg="$(parse_yaml $cfg)"
  elif [[ $url == "yes" ]]; then
      if [[ -n $token ]]; then
        cfg="$(parse_yaml <(curl -H "Authorization: token $token" $cfg))"
      else
        cfg="$(parse_yaml <(curl -s $cfg))"
      fi
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
  done < <(echo "$cfg")''
  sudo_reset
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

#< System Functions
env_system() {
  if [[ `uname -m` == 'arm64' ]]; then
    BREW_PREFIX="/opt/homebrew" # changed from BREW_PATH
    BREW_BINARY="/opt/homebrew/bin/brew"
    if [[ ! -x "$BREW_BINARY" ]]; then unset BREW_BINARY; else
      BREW_USER=$(ls -al "${BREW_BINARY}" | awk '{ print $3 }')
      BREW_REPO="/opt/homebrew"
      BREW_CELLAR="/opt/homebrew/Cellar"
      BREW_CASKROOM="/opt/homebrew/Caskroom"
    fi
  else
    BREW_PREFIX="/usr/local" # changed from BREW_PATH
    BREW_BINARY="/usr/local/Homebrew/bin/brew"
    if [[ ! -x "${BREW_BINARY}" ]]; then unset BREW_BINARY; else
      BREW_USER=$(ls -al "${BREW_BINARY}" | awk '{ print $3 }')
      BREW_REPO="/usr/local/Homebrew"
      BREW_CELLAR="/usr/local/Cellar"
      BREW_CASKROOM="/usr/local/Caskroom"
    fi
  fi
}
env_local() {
  BREW_PREFIX="/Users/${SYSTEM_USER}/.homebrew"
  BREW_BINARY="/Users/${SYSTEM_USER}/.homebrew/bin/brew"
  if [[ ! -x "$BREW_BINARY" ]]; then unset BREW_BINARY; else
    BREW_USER=$(ls -al "${BREW_BINARY}" | awk '{ print $3 }')
    BREW_REPO="/Users/${SYSTEM_USER}/.homebrew"
    BREW_CELLAR="/Users/${SYSTEM_USER}/.homebrew/Cellar"
    BREW_CASKROOM="/Users/${SYSTEM_USER}/.homebrew/Caskroom"
  fi
}
system_verbose(){
  if [[ "${@}" == "yes" ]] || [[ -z "${@}" ]]; then
    SYSTEM_VEROBSE="yes"
  else
    SYSTEM_VEROBSE="false"
  fi
}
system_runMode() {
  if [[ "${@}" != "system" ]] || [[ -z "${@}" ]]; then
    SYSTEM_RUNMODE="local"
  else
    SYSTEM_RUNMODE="system"
  fi
}
system_force() {
  # Checks to see if system force is enabled
  if [[ "${@}" != "yes" ]] || [[ -z "${@}" ]]; then
    SYSTEM_FORCE="false"
  else
    SYSTEM_FORCE="true"
    sudo_disable
  fi
}
system_user() {
  # Checks to see if a user has been specified
  if [[ -z "${SYSTEM_USER}" ]]; then
    if [[ -z "${@}" ]]; then
      say "No user specified. Continuing as ${CONSOLE_USER}\n"
      SYSTEM_USER="${CONSOLE_USER}"
    else
      SYSTEM_USER="${@}"
    fi
    # Checks to see if the specified user is present
    if id "${SYSTEM_USER}" &>/dev/null; then
      say "System user found: ${SYSTEM_USER}\n"
    else
      err "${SYSTEM_USER} not found"
    fi

    # Checks to see if sudo priviledges are required
    if [[ "${SYSTEM_USER}" != "${CONSOLE_USER}" ]]; then
      sudo_check "to run brew as another user"
    fi
  fi
}
system_ifAdmin() {
  if [[ "$@" == "yes" ]]; then
    SYSTEM_IFADMIN="yes"
    if [[ ${USER_CLASS} == "admin" ]]; then
      say "Brew admin enabled: ${CONSOLE_USER} is an admin user. Running brew as ${CONSOLE_USER}\n"
      SYSTEM_USER="${CONSOLE_USER}"
    fi
  else
    SYSTEM_IFADMIN="false"
  fi
}
#>

#< Xcode Functions
env_xcode() {
  XCODE_PREFIX="/Library/Developer/CommandLineTools"
  if [[ ! -d "${XCODE_PREFIX}" ]]; then
    unset XCODE_PREFIX
  fi

  if [[ "${@}" == "check_installed_version" ]] && [[ -n "${XCODE_PREFIX}" ]]; then
    say "Checking for the installed version of xcode CommandLineTools\n"
    XCODE_INSTALLED_VERSION=$(xcode_installed_version)
    say "The installed version of xcode CommandLineTools is ${XCODE_INSTALLED_VERSION}\n"
  fi
  if [[ "${@}" == "check_latest_version" ]]; then
    echo "Checking for the latest vesrion of xcode CommandLineTools. This may take some time."
    XCODE_LATEST_VERSION=$(xcode_latest_version)
    say "The latest version of xcode CommandLineTools is ${XCODE_LATEST_VERSION}\n"
  fi

  if [[ -z "${XCODE_INSTALLED_VERSION}" ]]; then
    XCODE_INSTALLED_VERSION="did not check"
  fi

  if [[ -z "${XCODE_LATEST_VERSION}" ]]; then
    XCODE_LATEST_VERSION="did not check"
  fi
}
xcode_trick() {
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  /usr/bin/sudo /usr/bin/touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
}
xcode_untrick() {
  /usr/bin/sudo /bin/rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
}
xcode_check_installed() {
  if [[ "${XCODE_CHECK_INSTALLED}" != "yes" ]]; then env_xcode;
    if [[ ! -d "${XCODE_PREFIX}" ]]; then XCODE_INSTALLED="flase";
      printf "Xcode CommandLineTools directory not defined\n"
      printf "Installing Xcode CommandLineTools. ctrl+c to cancel:  "; countdown
      xcode_install
    else XCODE_INSTALLED="yes";
    fi; env_xcode
  fi; XCODE_CHECK_INSTALLED="yes"
}
xcode_installed_version() {
  if [[ -n "${XCODE_PREFIX}" ]]; then
    pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | awk -F"version: " '{print $2}' | awk -v ORS="" '{gsub(/[[:space:]]/,""); print}' | awk -F"." '{print $1"."$2}'
  fi
}
xcode_latest_version() {
  sudo_check "to check the latest version of xcode"
  xcode_trick
  echo $(/usr/bin/sudo /usr/sbin/softwareupdate -l | awk -F"Version:" '{ print $1}' | awk -F"Xcode-" '{ print $2 }' | sort -nr | head -n1)
  xcode_untrick
}
xcode_install () {
  if [[ "${@}" == "yes" ]]; then
    env_xcode check_latest_version
    xcode_trick
    /usr/bin/sudo /usr/sbin/softwareupdate -i Command\ Line\ Tools\ for\ Xcode-"${XCODE_LATEST_VERSION}"
    printf "\nXcode info:\n$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed 's/^/\t\t/')\n"
    xcode_untrick
  fi
}
xcode_remove () {
  if [[ "${@}" == "yes" ]]; then
    if [[ -d "${XCODE_PREFIX}" ]]; then
      printf "Uninstalling xcode\n"
      sudo rm -r "${XCODE_PREFIX}"
    else
      printf "xcode not installed\n"
    fi
  fi
}
xcode_update() {
  if [[ "${@}" == "yes" ]]; then
    env_xcode check_installed_version
    env_xcode check_latest_version
    # Compares the two xcode versions to see if the curently installed version is less than the latest versoin
    if echo "${XCODE_INSTALLED_VERSION}" "${XCODE_LATEST_VERSION}" | awk '{exit !( $1 < $2)}'; then
      printf "\nXcode is outdate, updating Xcode version ${XCODE_LATEST_VERSION} to ${XCODE_LATEST_VERSION}"
      xcode_remove
      xcode_install
    else
      printf "xcode is up to date.\n"
    fi
  fi
}
#>

#< Brew Functions
env_brew() {
  system_user
  if [[ "${SYSTEM_RUNMODE}" == "system" ]]; then
    env_system
    if [[ -x "${BREW_BINARY}" ]]; then
      say "System Mode Enabled: Brew binary is located at $BREW_BINARY\n"
    else
      say "System Mode Enabled\n"
    fi
  else
    env_local
    if [[ -x "${BREW_BINARY}" ]]; then
      say "User Mode Enabled: Brew binary is located at $BREW_BINARY\n"
    else
      say "User Mode Enabled\n"
    fi
  fi
  DIR_BREW=("${BREW_BINARY}" "${BREW_PREFIX}" "${BREW_REPO}" "${BREW_CELLAR}" "${BREW_CASKROOM}" "${BREW_UESR}")

  # Brew Debug info
  if [[ -z "${BREW_BINARY}" ]]; then
    BREW_STATUS="not installed"
  else
    BREW_STATUS="installed"
  fi

  if [[ -z "${BREW_RESET}" ]]; then
  BREW_RESET="flase"
  fi
}
brewDo() {
  if [[ "$CONSOLE_USER" == "${SYSTEM_USER}" ]]; then
    if [ "$EUID" -ne 0 ] ;then
      "${BREW_BINARY}" "$@"
    else
      /usr/bin/sudo -i -u "${SYSTEM_USER}" "${BREW_BINARY}" "$@"
    fi
  else
    /usr/bin/sudo -i -u "${SYSTEM_USER}" "${BREW_BINARY}" "$@"
  fi
}
brew_check() {
  # Update brew enviroment variables
  env_brew

  # Check to see if brew is installed
  if [[ -z "${BREW_BINARY}" ]]; then
    BREW_STATUS="not installed"
    printf "brew directory not defined\nInstalling brew. Press ctrl+c to cancel. Timeout:  "; countdown
    brew_install yes
    env_brew
  fi

  # Checks to see if brew is owned by the correct user
  if [[ -d "${BREW_PREFIX}" ]] && [[ "${BREW_USER}" != "${SYSTEM_USER}" ]]; then
    echo "${SYSTEM_USER} does not own ${BREW_PREFIX}"
    printf "${SYSTEM_USER} will take ownership of ${BREW_PREFIX}. Press ctrl+c to cancel. Timeout:  "; countdown
    userDo /usr/bin/sudo /usr/sbin/chown -R ${SYSTEM_USER}: ${BREW_PREFIX}
  fi
}
brew_install() {
  if [[ "$@" == "yes" ]]; then
    system_user
    env_brew
    if [[ -x "${BREW_BINARY}" ]]; then
      echo "brew is already installed to ${BREW_PREFIX}. Resetting brew. Press ctrl+c to cancel. Timeout:  "; countdown
      BREW_RESET="yes"
      if [[ "${SYSTEM_RUNMODE}" == "local" ]]; then
        brew_uninstall
      else
        brew_system_uninstall
      fi
    else
      if [[ "${SYSTEM_RUNMODE}" == "local" ]]; then
        userDo mkdir -p "${BREW_PREFIX}"
        userDo curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "${BREW_PREFIX}"
      else
        brew_system_install
      fi
    fi
    brew_check
  fi
}
brew_system_install () {
  sudo_check "to install homebrew"
  if [[ -x "${BREW_BINARY}" ]]; then
    BREW_STATUS="installed"
    printf "brew is already installed to ${BREW_PREFIX}. Resetting brew. Press ctrl+c to cancel. Timeout:  "; countdown
    BREW_RESET="yes"
    brew_system_uninstall
  fi
  cd /Users/"$SYSTEM_USER"/
  printf "Installing brew. Press ctrl+c to cancel. Timeout:  "; countdown
  echo -ne "y\n" | sudo -u "${SYSTEM_USER}" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "Brew install complete"
}
brew_uninstall() {
  if [[ "$@" == "yes" ]]; then
    system_user
    env_brew
    if [[ -d "${BREW_PREFIX}" ]]; then
      if [[ "${SYSTEM_RUNMODE}" == "system" ]]; then
        brew_system_uninstall
      else
        printf "Uninstalling brew from ${BREW_PREFIX}. Press ctrl+c to cancel. Timeout:  "; countdown
        rm -r "${BREW_PREFIX}"
      fi
    else
      echo "No brew installation found"
    fi
  fi
}
brew_system_uninstall () {
  cd /Users/"$SYSTEM_USER"/
  printf "Uninstalling brew from ${BREW_PREFIX}. Press ctrl+c to cancel. Timeout:  "; countdown
  /usr/bin/sudo -u "${SYSTEM_USER}" echo -ne 'y\n' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
}
brew_update() {
  if [[ "$@" == "yes" ]]; then
    brew_check
    say "brew_update: Enabled.\nUpdating brew\n"
    brewDo update
  fi
}
#>

#< Enviroment variables
# consoleUser - Get current logged in user
CONSOLE_USER=$(ls -l /dev/console | awk '{ print $3 }')

# userClass - Get if current logged in user is admin or standard
USER_CLASS=$(if groups "${CONSOLE_USER}" | grep -q -w admin; then
  echo "admin"
  else
  echo "standard"
fi)
#>

#< Package Functions
env_package() {
  if [[ -z $(ls "${BREW_PREFIX}/bin" | grep "${PACKAGE}") ]]; then
    PACKAGE_DIR="$brew_caskroom/$PACKAGE"
    PACKAGE_NAME=$(brewDo info "${PACKAGE}" | grep .app | awk -F"(" '{print $1}' | grep -v Applications)
    PACKAGE_LINK="/Applications/${PACKAGE_NAME}"
    #PACKAGE_OWNDER=$(stat "${PACKAGE_LINK}" | awk '{print $5}')
  else
    PACKAGED_DIR="${BREW_PREFIX}/bin/${PACKAGE}"
    PACKAGE_NAME="${PACKAGE}"
    #PACKAGE_OWNDER=$(stat "${PACKAGE_DIR}" | awk '{print $5}')
    PACKAGE_LINK="${PACKAGE_DIR}"
  fi

  if [[ -n "${PACKAGE_LINK}" ]]; then
    PACKAGE_INSTALLED="yes"
  else
    PACKAGE_INSTALLED="false"
  fi
}
package_install() {
  if [[ -z "${PACKAGE_INSTALL}" ]]; then
    PACKAGE_INSTALL="$@"
  fi
  system_user
  if [[ -z "${PACKAGE_INSTALL}" ]]; then
    err "no package specified"
  fi
  brew_check
  cd /Users/"${SYSTEM_USER}"/
  env_package
  brewDo install $PACKAGE_INSTALL -f
  env_package
}
package_uninstall() {
  if [[ -z "${PACKAGE_UNINSTALL}" ]]; then
    PACKAGE_UNINSTALL="$@"
  fi
  system_user
  if [[ -z "${PACKAGE_UNINSTALL}" ]]; then
    err "no package specified"
  fi
  brew_check
  cd /Users/"${SYSTEM_USER}"/
  env_package
  brewDo uninstall "${PACKAGE_UNINSTALL}"
  env_package
}
#>

#< Process Functions
process_kill() {
  if [[ -z "${PROCESS_KILL}" ]]; then
    PROCESS_KILL="${@}"
  fi
  if [[ "${PROCESS_KILL}" != "no" ]]; then
    system_user
    pkill -9 "${PROCESS_KILL}"
  fi
}
#>

#< Notify Functions
notify_title(){
  if [[ -z "$@" ]] ; then
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
    curl "$notify_iconLink" --output "$notify_iconPath"
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
    notify_run
}
notify_timeout() {
  if [[ -z "$@" ]]; then
    notify_timeout=10
  else
    notify_timeout=$(echo "$@" | tr -d '"')
  fi
}
notify_allowCancel() {
  if [[ "${@}" = "\"no"\" ]]; then
    notify_buttons="\"okay\""
  else
    notify_buttons="\"okay\", \"not now\""
  fi
}
notify_run() {
  notify_input=$(/usr/bin/osascript<<-EOF
    tell application "System Events"
    activate
    set myAnswer to button returned of (display dialog "$notify_dialog" buttons {$notify_buttons} giving up after $notify_timeout with title "$notify_title" with icon $notify_icon)
    end tell
    return myAnswer
    EOF)
    if [[ $notify_input == "not now" ]]; then
      err "user canceled"
    fi
    say "User user input: $notify_input\n"
    unset dialog
}
#>

#< Brass Functions
brass_update() {
  if [[ "$@" == "yes" ]]; then
    brassBinary=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && echo "$(pwd)/brass")
    brassData=$(cat $brassBinary)
    brassGet=$(curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh)
    brassDif=$(echo ${brassGet[@]} ${brassData[@]} | tr ' ' '\n' | sort | uniq -u)
    if [[ -z $brassDif ]]; then
      printf "brass is up to date.\n"
    else
      printf "brass upgrade available. Upgrading brass. Press ctrl+c to cancel. Timeout:  "; countdown
      brass_upgrade
    fi
  fi
}
brass_upgrade() {
  sudo_check "to install brass"
  curl -fsSL https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh --output /usr/local/bin/brass
  chmod +x /usr/local/bin/brass
  say "install complete.\n"
}
brass_debug() {
  if [[ "${BREW_STATUS}" == "not installed" ]]; then
    BREW_DEBUG="BREW_STATUS=${BREW_STATUS}"
  else
    BREW_DEBUG="BREW_STATUS=${BREW_STATUS}
      BREW_RESET=${BREW_RESET}
      BREW_USER=${BREW_USER}
      BREW_PREFIX=${BREW_PREFIX}
      BREW_REPO=${BREW_REPO}
      BREW_CELLAR=${BREW_CELLAR}
      BREW_CASKROOM=${BREW_CASKROOM}"
  fi



  printf "BRASS DEBUG:

    USER DEBUG:
      CONSOLE_USER=${CONSOLE_USER}
      USER_CLASS=${USER_CLASS}

    SYSTEM DEBUG:
      SYSTEM_VEROBSE=${SYSTEM_VEROBSE}
      SYSTEM_RUNMODE=${SYSTEM_RUNMODE}
      SYSTEM_FORCE=${SYSTEM_FORCE}
      SYSTEM_IFADMIN=${SYSTEM_IFADMIN}
      SYSTEM_USER=${SYSTEM_USER}

    XCODE DEBUG:
      XCODE_CHECK_INSTALLED=${XCODE_CHECK_INSTALLED}
      XCODE_INSTALLED=${XCODE_INSTALLED}
      XCODE_INSTALLED_VERSION=${XCODE_INSTALLED_VERSION}
      XCODE_LATEST_VERSION=${XCODE_LATEST_VERSION}

    BREW DEBUG:
      ${BREW_DEBUG}

    PACKAGE DEBUG:
      ${PACKAGE_DEBUG}
      \n"
}
#>

# This allows err funtion to exit script whith in a subshell
set -E
trap '[ "$?" -ne 77 ] || exit 77' ERR

if [[ -z $@ ]]; then
  if [[ ! -x /usr/local/bin/brass ]]; then
    printf "Installing brass to /usr/local/bin/brass Press ctrl+c to cancel. Timeout:  "; countdown
    sudo_check "to install brass"
    mkdir -p /usr/local/bin/
    brass_upgrade
    say "done.\n\n"
  else
    brass_update yes
  fi
  printf "use brass -h for more infomation.\n"
  exit
fi
# Checks to see if xcode CommandLineTools is installed
if [[ "${XCODE_CHECK_INSTALLED}" != "yes" ]]; then
  xcode_check_installed
fi
system_runMode local
system_ifAdmin true
env_brew
script_check $@
sudo_reset
