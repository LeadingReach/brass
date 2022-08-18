 #!/bin/bash

#< Enviroment variables
# brass_url - brass script URL
if [[ -f "/Library/brass/brass.yaml" ]] && [[ -n $(cat /Library/brass/brass.yaml | grep branch: | awk -F'branch: ' '{print $2}') ]]; then
  BRASS_BRANCH=$(cat /Library/brass/brass.yaml | grep branch: | awk -F'branch: ' '{print $2}')
  BRASS_URL="https://raw.githubusercontent.com/LeadingReach/brass/$BRASS_BRANCH/brass.sh"
else
  BRASS_URL="https://raw.githubusercontent.com/LeadingReach/brass/brass-local/brass.sh"
fi
# consoleUser - Get current logged in user
CONSOLE_USER=$(ls -l /dev/console | awk '{ print $3 }')

# userClass - Get if current logged in user is admin or standard
USER_CLASS=$(if groups "${CONSOLE_USER}" | grep -q -w admin; then
  echo "admin"
  else
  echo "standard"
fi)
#>

#< System requirements
# This allows err funtion to exit script whith in a subshell
set -E
trap '[ "$?" -ne 77 ] || exit 77' ERR
#>

#< Script Functions
script_check() {
  while getopts 'c:g:j:C:ZvVxs:iruzp:P:d:t:Q:f:nlae:bqhygMmUoOND:J:' flag; do
    case "${flag}" in
    # YAML Config Functions
      c) cfg="$OPTARG"; file="yes"; run_config; exit;; # Option to run brass from config yaml file
      C) cfg="$@"; run_config; exit;; # Option to run yaml functions directly from the CLI
      g) cfg="$OPTARG"; url="yes"; run_config; exit;; # Option to run brass from remote config yaml file
      j) token="$OPTARG";; # Option to select GitHub Secure Token to access yaml config files
      J) APP_DIR="$OPTARG"; dock_add;;
      t) secret="$OPTARG"; token=$(cat "${secret}");; # Option to pull GitHub Secure Token from a file to access yaml config files
    # CLI System Functions
      Z) system_runMode system; env_brew;; # Runs default system brew prefix
      V) VERBOSE_OVERIDE="true";;
      v) system_verbose yes;; # Shows verbose information
      x) xcode_update yes;; # Checks and updates xcode if available
      s) system_user "$OPTARG";; # Selects which user to run brew as
      l) system_force yes;; # Force pushes through brass configuration
      a) system_ifAdmin yes;; # Runs brew as
      n) noWarnning="1";;
    # CLI Brew Functions
      i) brew_install yes;;
      r) brew_uninstall yes;;
      u) brew_update yes;;
      z) brew_reset yes;;
      e) brewDo "$OPTARG";;
    # CLI Package Functions
      p) PACKAGE="$OPTARG"; package_install $PACKAGE;;
      P) PACKAGE="$OPTARG"; package_manage $PACKAGE;;
      d) PACKAGE="$OPTARG"; package_uninstall $PACKAGE;;
      D) PACKAGE="$OPTARG"; package_unmanage $PACKAGE;;
      M) package_update all;;
      m) package_update show;;
      U) package_update new;;
      o) package_update outdated;;
    # CLI Brass Functions
      N) notify_update;;
      b) brass_debug;;
      q) brass_update yes;;
      Q) BRASS_BRANCH="$OPTARG"; brass_changeBranch;;
    # CLI Help Functions
      g) flags;;
      y) yaml;;
      h) help;;
      *) help;;
    esac
  done
  if [ $OPTIND -eq 1 ]; then system_user; brewDo "$@"; fi
}
say() {
  printf "$(date): $@" >> "${LOG_FILE}"
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
user_command() {
  if [[ $CONSOLE_USER == ${SYSTEM_USER} ]]; then
      $@
  else
    sudo_check "to run as another user"
    /usr/bin/sudo -i -u ${SYSTEM_USER} $@
  fi
}
console_user_command() {
  if [[ $CONSOLE_USER == ${SYSTEM_USER} ]]; then
      "$@"
  else
    sudo_check "to run as another user"
    /usr/bin/sudo -i -u "${CONSOLE_USER}" "$@"
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
  if [[ "${SYSTEM_USER}" != "${CONSOLE_USER}" ]]; then
    # Checks to see if sudo binary is executable
    if [[ ! -x "/usr/bin/sudo" ]]
    then
      err "sudo binary is missing or not executable"
    fi

    # Checks to see if script has sudo priviledges
    if [ "$EUID" -ne 0 ];then
    err "sudo priviledges are reqired $@"
    fi

  else
    say "sudo priviledges are not required"
  fi
}
sudo_disable() {
  system_user
  SUDO_DIR=("SETENV:/bin/ln" "SETENV:/usr/sbin/chown" "SETENV:/usr/sbin/chmod" "SETENV:/bin/launchctl" "SETENV:/bin/rm" "SETENV:/usr/bin/env" "SETENV:/usr/bin/xargs" "SETENV:/usr/sbin/pkgutil" "SETENV:/bin/mkdir" "SETENV:/bin/mv" "SETENV:/usr/bin/pkill")
  for str in ${SUDO_DIR[@]}; do
    if [[ -z $(/usr/bin/sudo cat /etc/sudoers | grep "${str}" | grep "#brass") ]]; then
      STR_BINARY=$(echo "$str" | awk -F"/" '{print $(NF)}')
      echo "${SYSTEM_USER}         ALL = (ALL) NOPASSWD: $str  #brass" | sudo EDITOR='tee -a' visudo > /dev/null
    fi
  done
}
sudo_reset() {
  say "removing brass sudoers entries\n"
  sed -i '' '/#brass/d' /etc/sudoers &> /dev/null
}
run_config () {
  if [[ "${file}" == "yes" ]]; then
    cfg="$(parse_yaml ${cfg})"
  elif [[ "${url}" == "yes" ]]; then
      if [[ -n "${token}" ]]; then
        cfg="$(parse_yaml <(curl -H "Authorization: token ${token}" ${cfg}))"
      else
        cfg="$(parse_yaml <(curl -s ${cfg}))"
      fi
  else
    cfg=$(echo "${cfg}" | awk -F"\-C\ " '{print $2}' | tr ' ' '\n')
  fi
  while IFS= read -r line; do
    run=$(echo "${line}" | awk -F'=' '{print $1}')
    if [[ "${run}" == notify* ]]; then
      str=$(echo "${line}" | awk -F'=' '{print $2}')
    elif [[ "${run}" == user* ]]; then
      str=$(echo "${line}" | awk -F'user_command=' '{print $2}' | tr -d '"')
    elif [[ "${run}" == brew_run* ]]; then
      str=$(echo "${line}" | awk -F'brew_run=' '{print $2}' | sed -e 's/^"//' -e 's/"$//')
    else
      str=$(echo "${line}" | awk -F'=' '{print $2}' | tr -d '"')
    fi
    "${run}" "${str}"
  done < <(echo "${cfg}")''
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
conf_get() {
  if [[ "$@" == "yes" ]] && [[ ! "$EUID" -ne 0 ]]; then
    if [[ -f "/Library/brass/brass.yaml" ]]; then
      cfg="/Library/brass/brass.yaml"; file="yes"; run_config
    elif [[ -f "/Users/${CONSOLE_USER}/.brass/brass.yaml" ]]; then
      cfg="/Users/${CONSOLE_USER}/.brass/brass.yaml"; file="yes"; run_config
    fi
  elif [[ "$@" == "VERBOSE_OVERIDE" ]] && [[ ! "$EUID" -ne 0 ]]; then
    if [[ -f "/Library/brass/brass.yaml" ]]; then
      cfg="/Library/brass/brass.yaml"; file="yes"; run_config
    elif [[ -f "/Users/${CONSOLE_USER}/.brass/brass.yaml" ]]; then
      cfg="/Users/${CONSOLE_USER}/.brass/brass.yaml"; file="yes"; run_config
    fi
  fi
}
#>

#< System Functions
env_system() {
  if [[ `uname -m` == 'arm64' ]]; then
    BREW_PREFIX="/opt/homebrew"
    BREW_BINARY="/opt/homebrew/bin/brew"
    if [[ ! -x "$BREW_BINARY" ]]; then unset BREW_BINARY; else
      BREW_USER=$(ls -al "${BREW_BINARY}" | awk '{ print $3 }')
      BREW_REPO="/opt/homebrew"
      BREW_CELLAR="/opt/homebrew/Cellar"
      BREW_CASKROOM="/opt/homebrew/Caskroom"
      BREW_BIN="/opt/homebrew/bin"
    fi
  else
    BREW_PREFIX="/usr/local"
    BREW_BINARY="/usr/local/Homebrew/bin/brew"
    if [[ ! -x "${BREW_BINARY}" ]]; then unset BREW_BINARY; else
      BREW_USER=$(ls -al "${BREW_BINARY}" | awk '{ print $3 }')
      BREW_REPO="/usr/local/Homebrew"
      BREW_CELLAR="/usr/local/Cellar"
      BREW_CASKROOM="/usr/local/Caskroom"
      BREW_BIN="/usr/local/bin"
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
env_user() {
  ENV_USER=$(user_command printenv)
  echo "${ENV_USER}"
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
  # Skips function if user is already specified
  if [[ "${SYSTEM_USER_RAN}" != 1 ]]; then
    # Checks to see if a user has been specified
    if [[ "${SYSTEM_IFADMIN}" != "yes" ]]; then
      if [[ "${@}" ]]; then
        say "Continuing as ${@}\n"
        SYSTEM_USER="${@}"
      elif [[ -z "${@}" ]] && [[ -z "${SYSTEM_USER}" ]]; then
        say "No user specified. Continuing as ${CONSOLE_USER}\n"
        SYSTEM_USER="${CONSOLE_USER}"
      elif [[ -z "${@}" ]] && [[ "${SYSTEM_USER}" ]]; then
        say "System user is: ${SYSTEM_USER}\n"
      fi
    elif [[ -z "${SYSTEM_USER}" ]]; then
      say "No user specified. Continuing as ${CONSOLE_USER}\n"
      SYSTEM_USER="${CONSOLE_USER}"
    else
      say "System user is: ${SYSTEM_USER}\n"
    fi

    # Checks to see if the specified user is present
    if id "${SYSTEM_USER}" &>/dev/null; then
      say "System user found: ${SYSTEM_USER}\n"
    else
      say "${SYSTEM_USER} not found, creating ${SYSTEM_USER}. ctrl+c to cancel:  "; countdown
      sudo_check "to run brew as another user"
      system_user_make
      # err "${SYSTEM_USER} not found"
    fi

    # Checks to see if sudo priviledges are required
    if [[ "${SYSTEM_USER}" != "${CONSOLE_USER}" ]]; then
      sudo_check "to run brew as another user"
    fi

    # Checks to see if chache dir is set
    BREW_CACHE="/Users/${SYSTEM_USER}/Library/Caches/Homebrew"
    if [[ -d "${BREW_CACHE}" ]] && [[ $(stat "${BREW_CACHE}" | awk '{print $5}') != "${SYSTEM_USER}" ]]; then
      sudo chown -R "${SYSTEM_USER}": "${BREW_CACHE}"
    fi
    SYSTEM_USER_RAN="1"
  fi

}
system_user_make() {
  # Makes new user's UID
  uids=$( dscl . -list /Users UniqueID | awk '{print $2}' )
  uid=504
  while true; do
    if ! echo $uids | grep -F -q -w "$uid"; then
      break;
    fi
    uid=$(( $uid + 1))
    gid=$(( $uid + 1))
  done
  sudo mkdir -p "/Users/${SYSTEM_USER}"
  sudo dscl . -create "/Users/${SYSTEM_USER}"
  sudo dscl . -create "/Users/${SYSTEM_USER}" UserShell /bin/bash
  sudo dscl . -create "/Users/${SYSTEM_USER}" RealName "${SYSTEM_USER}"
  sudo dscl . -create "/Users/${SYSTEM_USER}" UniqueID "${uid}"
  sudo dscl . -create "/Users/${SYSTEM_USER}" PrimaryGroupID "${gid}"
  sudo dscl . -create "/Users/${SYSTEM_USER}" NFSHomeDirectory "/Users/${SYSTEM_USER}"
  sudo dscl . -append /Groups/admin GroupMembership "${SYSTEM_USER}"
  sudo chown -R "${SYSTEM_USER}": "/Users/${SYSTEM_USER}"
  say "successfully created ${SYSTEM_USER} with UID ${uid} and GID ${gid} with admin priviledges.\n"
}
system_ifAdmin() {
  if [[ "$1" == "yes" ]]; then
    if [[ "${USER_CLASS}" == "admin" ]]; then
      SYSTEM_IFADMIN="yes"
      say "Brew admin enabled: ${CONSOLE_USER} is an admin user. Running brew as ${CONSOLE_USER}\n"
      SYSTEM_USER="${CONSOLE_USER}"
      env_brew
    fi
  else
    SYSTEM_IFADMIN="false"
  fi
}
system_secret() {
  if [[ -z "$@" ]]; then
    token="${token}"
  fi
}
#>

#< Xcode Functions
env_xcode() {
  XCODE_PREFIX="/Library/Developer/CommandLineTools"
}
xcode_trick() {
  /usr/bin/sudo touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
}
xcode_untrick() {
  /usr/bin/sudo /bin/rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
}
xcode_check_installed() {
  if [[ "${XCODE_CHECK_INSTALLED}" != "yes" ]]; then env_xcode;
    if [[ ! -x "${XCODE_PREFIX}/usr/bin/git" ]]; then XCODE_INSTALLED="flase";
      printf "Xcode CommandLineTools directory not defined\n"
      printf "Installing Xcode CommandLineTools. ctrl+c to cancel:  "; countdown
      if [[ -d "${XCODE_PREFIX}" ]]; then rm -r "${XCODE_PREFIX}"; fi
      xcode_install yes
    else XCODE_INSTALLED="yes";
    fi; env_xcode
  fi; XCODE_CHECK_INSTALLED="yes"
}
xcode_installed_version() {
  # Sets xcode installed version variable
  if [[ -n "${XCODE_PREFIX}" ]]; then
    say "Checking for the installed version of xcode CommandLineTools\n"
    XCODE_INSTALLED_VERSION=$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | awk -F"version: " '{print $2}' | awk -v ORS="" '{gsub(/[[:space:]]/,""); print}' | awk -F"." '{print $1"."$2}')
    say "The installed version of xcode CommandLineTools is ${XCODE_INSTALLED_VERSION}\n"
  fi
}
xcode_latest_version() {
  if [[ -z "${XCODE_LATEST_VERSION}" ]]; then
    sudo_check "to check the latest version of xcode"
    xcode_trick &> /dev/null
    # Sets xcode latest version variable
    echo "Checking for the latest vesrion of xcode CommandLineTools. This may take some time."
    XCODE_LATEST_VERSION=$(/usr/bin/sudo /usr/sbin/softwareupdate -l | awk -F"Version:" '{ print $1}' | awk -F"Xcode-" '{ print $2 }' | sort -nr | head -n1)
    say "The latest version of xcode CommandLineTools is ${XCODE_LATEST_VERSION}\n"
    xcode_untrick &> /dev/null
  fi
}
xcode_install () {
  if [[ "${@}" == "yes" ]]; then
    env_xcode
    xcode_latest_version
    xcode_remove yes
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
    env_xcode
    xcode_installed_version
    xcode_latest_version
    # Compares the two xcode versions to see if the curently installed version is less than the latest versoin
    if echo "${XCODE_INSTALLED_VERSION}" "${XCODE_LATEST_VERSION}" | awk '{exit !( $1 < $2)}'; then
      printf "\nXcode is outdate, updating Xcode version ${XCODE_LATEST_VERSION} to ${XCODE_LATEST_VERSION}"
      xcode_install yes
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
      if [[ -z "${SYSTEM_MODE}" ]]; then
        say "System Mode Enabled: Brew binary is located at $BREW_BINARY\n"
        SYSTEM_MODE="System"
      fi
    else
      if [[ -z "${SYSTEM_MODE}" ]]; then
        say "System Mode Enabled\n"
        SYSTEM_MODE="System"
      fi
    fi
  else
    env_local
    if [[ -x "${BREW_BINARY}" ]]; then
      if [[ -z "${SYSTEM_MODE}" ]]; then
        say "User Mode Enabled: Brew binary is located at $BREW_BINARY\n"
        SYSTEM_MODE="User"
      fi
    else
      if [[ -z "${SYSTEM_MODE}" ]]; then
        say "User Mode Enabled\n"
        SYSTEM_MODE="User"
      fi
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
  env_brew
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
brewRun() {
  env_brew
  if [[ "$CONSOLE_USER" == "${SYSTEM_USER}" ]]; then
    echo "HERE $BREW_BINARY $BREW_PREFIX"
    if [ "$EUID" -ne 0 ] ;then
      eval "$BREW_PREFIX/bin/$@"
    else
      eval "/usr/bin/sudo -i -u $SYSTEM_USER $BREW_PREFIX/bin/$@"
    fi
  else
    eval "/usr/bin/sudo -i -u $SYSTEM_USER $BREW_PREFIX/bin/$@"
  fi
}
brew_check() {
  # Update brew enviroment variables
  system_user
  env_brew

  # Check to see if brew is installed
  if [[ -z "${BREW_BINARY}" ]]; then
    BREW_STATUS="not installed"
    printf "brew not fount at ${BREW_PREFIX}\nInstalling brew. Press ctrl+c to cancel. Timeout:  "; countdown
    brew_install yes
    env_brew
  fi

  # Checks to see if brew is owned by the correct user
  if [[ -d "${BREW_PREFIX}" ]] && [[ "${BREW_USER}" != "${SYSTEM_USER}" ]]; then
    echo "${SYSTEM_USER} does not own ${BREW_PREFIX}"
    printf "${SYSTEM_USER} will take ownership of ${BREW_PREFIX}. Press ctrl+c to cancel. Timeout:  "; countdown
    sudo_disable
    user_command /usr/bin/sudo /usr/sbin/chown -R ${SYSTEM_USER}: ${BREW_PREFIX}
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
        user_command mkdir -p "${BREW_PREFIX}"
        user_command curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "${BREW_PREFIX}"
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
    say "brew_update: Enabled. Updating brew\n"
    brewDo update
  fi
}
brew_tap() {
  if [[ -z "${BREW_TAP}" ]]; then
    BREW_TAP="$@"
  fi
  system_user
  if [[ -z "${BREW_TAP}" ]]; then
    err "nothing specified"
  fi
  brew_check
  cd /Users/"${SYSTEM_USER}"/
  env_package
  brewDo tap "${BREW_TAP}"
  env_package
}
brew_depends() {
  BREW_DEPENDS="$@"
  brew_check
  env_brew
  system_user
  if [[ -z $(brewDo list | grep -w "$BREW_DEPENDS") ]]; then
    package_install "${BREW_DEPENDS}"
  fi
  env_package
}
brew_run() {
  BREW_RUN="$@"
  system_user
  if [[ -z "${BREW_RUN}" ]]; then
    err "nothing specified"
  fi
  brew_check
  cd /Users/"${SYSTEM_USER}"/
  env_package
  brewRun "${BREW_RUN}"
  env_package
}
#>

#< Package Functions
env_package() {
  echo"disabled\n" &> /dev/null
#  if [[ -z $(ls "${BREW_PREFIX}/bin" | grep "${PACKAGE}") ]]; then
#    PACKAGE_DIR="$brew_caskroom/$PACKAGE"
#    PACKAGE_NAME=$(brewDo info "${PACKAGE}" | grep .app | awk -F"(" '{print $1}' | grep -v Applications)
#    PACKAGE_LINK="/Applications/${PACKAGE_NAME}"
#    #PACKAGE_OWNDER=$(stat "${PACKAGE_LINK}" | awk '{print $5}')
#  else
#    PACKAGED_DIR="${BREW_PREFIX}/bin/${PACKAGE}"
#    PACKAGE_NAME="${PACKAGE}"
#    #PACKAGE_OWNDER=$(stat "${PACKAGE_DIR}" | awk '{print $5}')
#    PACKAGE_LINK="${PACKAGE_DIR}"
#  fi
#
#  if [[ -n "${PACKAGE_LINK}" ]]; then
#    PACKAGE_INSTALLED="yes"
#  else
#    PACKAGE_INSTALLED="false"
#  fi
}
package_install() {
  PACKAGE_INSTALL="$@"
  system_user
  if [[ -z "${PACKAGE_INSTALL}" ]]; then
    err "no package specified"
  fi
  brew_check
  cd /Users/"${SYSTEM_USER}"/
  env_package
  if [[ -z $(brewDo list | grep -w "$PACKAGE_INSTALL") ]]; then
    say "Installing $PACKAGE_INSTALL\n"
    brewDo install $PACKAGE_INSTALL -f | grep -v "Operation not permitted"
  else
    say "Updating $PACKAGE_INSTALL\n"
    brewDo upgrade $PACKAGE_INSTALL | grep -v "Operation not permitted"
  fi
  env_package
}
package_manage() {
  PACKAGE_MANAGE="$@"
  system_user
  if [[ -z "${PACKAGE_MANAGE}" ]]; then
    err "no package specified"
  fi
  if [[ -d "/Library/brass/pkg" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="$PKG_MANAGED $(cat /Library/brass/pkg/"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls /Library/brass/pkg)
    if [[ -z "$(echo ${PKG_MANAGED} | grep "${PACKAGE_MANAGE}" )" ]]; then
      say "adding "${PACKAGE_MANAGE}".yaml to /Library/brass/pkg/\n"
      printf "package:\n\tinstall: ${PACKAGE_MANAGE}\n" > /Library/brass/pkg/"${PACKAGE_MANAGE}".yaml
    else
      say "${PACKAGE_MANAGE} is already managed\n"
    fi
  fi
}
package_unmanage() {
  PACKAGE_MANAGE="$@"
  system_user
  if [[ -z "${PACKAGE_MANAGE}" ]]; then
    err "no package specified"
  fi
  if [[ -d "/Library/brass/pkg" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="$PKG_MANAGED $(cat /Library/brass/pkg/"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls /Library/brass/pkg)
    if [[ ! -z "$(echo ${PKG_MANAGED} | grep "${PACKAGE_MANAGE}" )" ]]; then
      say "removing "${PACKAGE_MANAGE}".yaml to /Library/brass/pkg/\n"
      rm /Library/brass/pkg/"${PACKAGE_MANAGE}".yaml
    else
      say "${PACKAGE_MANAGE} is already managed\n"
    fi
  fi
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
package_update() {
  system_user
  sudo_disable
  if [[ "$@" == "all" ]]; then
    package_all
  elif [[ "$@" == "show" ]]; then
    package_show
  elif [[ "$@" == "outdated" ]]; then
    package_outdated
  elif [[ "$@" == "new" ]]; then
    package_new
  fi
}
package_outdated() {
  if [[ -d "/Library/brass/pkg" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="${PKG_MANAGED} $(cat /Library/brass/pkg/"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls /Library/brass/pkg)
    PKG_MANAGED="$(echo "${PKG_MANAGED}" | tr '\n' '\ ' | tr -s ' ')"
    PKG_OUTDATED=$(SYSTEM_VEROBSE="FALSE"; brewDo outdated)
    while IFS= read -r LINE; do
      if [[ " ${PKG_OUTDATED[*]} " =~ "${LINE}" ]]; then
        PKG_MANAGED_OUTDATED="${PKG_MANAGED_OUTDATED} ${LINE}"
      fi
    done < <(echo "${PKG_MANAGED}" | tr '\ ' '\n')
    if [[ -z "${PKG_MANAGED}" ]] && [[ -z "${PKG_OUTDATED}" ]]; then
      say "No managed packages found\n"
    elif [[ -z "${PKG_OUTDATED}" ]]; then
      printf "All packages are up to date\n"
    elif [[ ! -z "${PKG_OUTDATED}" ]]; then
      printf "Package updates available\n"
    else
      err "an error has occured\n"
    fi
  fi
}
package_all() {
  if [[ -d "/Library/brass/pkg" ]]; then
    if [[ $(package_outdated) != "All packages are up to date" ]]; then
     while IFS= read -r LINE; do
       PKG_MANAGED="$(cat /Library/brass/pkg/"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
       cfg="/Library/brass/pkg/${LINE}"; file="yes"; run_config
     done < <(ls /Library/brass/pkg)
   else
     say "No package updates available\n"
   fi
  fi
}
package_show() {
  if [[ -d "/Library/brass/pkg" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="${PKG_MANAGED} $(cat /Library/brass/pkg/"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls /Library/brass/pkg)
    PKG_MANAGED="$(echo "${PKG_MANAGED}" | tr '\n' '\ ' | tr -s ' ')"
    PKG_OUTDATED=$(SYSTEM_VEROBSE="FALSE"; brewDo outdated)
    while IFS= read -r LINE; do
      if [[ " ${PKG_OUTDATED[*]} " =~ "${LINE}" ]]; then
        PKG_MANAGED_OUTDATED="${PKG_MANAGED_OUTDATED} ${LINE}"
      fi
    done < <(echo "${PKG_MANAGED}" | tr '\ ' '\n')
    if [[ -z "${PKG_MANAGED}" ]]; then
      say "No managed packages found\n"
    elif [[ -z "${PKG_OUTDATED}" ]]; then
      printf "### All packages are up to date ###\n"
      printf "${PKG_MANAGED}\n" | tr ' ' '\n' | sed '/^[[:space:]]*$/d'
      printf "###################################\n"
    elif [[ ! -z "${PKG_OUTDATED}" ]]; then
      printf "### Outdated Packages ###\n"
      printf "${PKG_OUTDATED}\n" | tr ' ' '\n' | sed '/^[[:space:]]*$/d'
      printf "#########################\n"
    else
      err "an error has occured\n"
    fi
  fi
}
package_new() {
  if [[ -d "/Library/brass/pkg" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="$PKG_MANAGED $(cat /Library/brass/pkg/"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls /Library/brass/pkg)
    PKG_INSTALLED="$(brewDo list | grep -v "==>")"
    PKG_DIF=$(echo ${PKG_MANAGED[@]} ${PKG_INSTALLED[@]} ${PKG_INSTALLED[@]} | tr ' ' '\n' | sort | uniq -u)
    if [[ -z "${PKG_DIF}" ]]; then
      printf "There are no new packages to manage.\n"
    else
      echo "${PKG_DIF}"
      while IFS= read -r LINE; do
        if [[ " ${PKG_MANAGED[@]} " =~ " ${LINE} " ]]; then
          brewDo install "${LINE}" -f
        fi
      done < <(echo "$PKG_DIF" )
    fi
  fi
}
#>

#< Process Functions
process_kill() {
  if [[ -z "${PROCESS_KILL}" ]]; then
    PROCESS_KILL="${@}"
  fi
  if [[ "${PROCESS_KILL}" != "no" ]]; then
    system_user
    say "killing ${PROCESS_KILL} process"
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
  fi
}
notify_iconPath() {
  if [[ -z "$@" ]]; then
    notify_icon="caution"
  else
    notify_iconPath=$(echo "$@" | tr -d '"')
    notify_icon="POSIX file (\"$notify_iconPath\" as string)"
    curl "${notify_iconLink}" --output "${notify_iconPath}"
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
notify_update() {
  if [[ ! -d /Library/Application\ Support/Dialog ]]; then
    sudo_check "for swiftDialog\n"
    env_brew
    if [[ -d "${BREW_PREFIX}/install-tmp" ]]; then
      say "${BREW_PREFIX}/install-tmp found, removing."
      rm -r "${BREW_PREFIX}/install-tmp"
    fi
    say "creating ${BREW_PREFIX}/install-tmp"
    mkdir -p "${BREW_PREFIX}/install-tmp"
    REPO='bartreardon/swiftDialog'
    URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | awk -F\" '/browser_download_url.*.pkg/{print $(NF-1)}')
    PKG=$(echo $URL | awk -F"/" '{print $NF}')
    say "Downloading swiftDialog"
    wget "$URL" -P "${BREW_PREFIX}/install-tmp/"
    say "Installing swiftDialog"
    /usr/sbin/installer -pkg "${BREW_PREFIX}/install-tmp/${PKG}" -target /
    say "cleaning brew_depends\n"
    rm -r "${BREW_PREFIX}/install-tmp"
  fi

  if [[ -f /Library/brass/notify.yaml ]]; then
    PKG_STATUS="$(package_update outdated)"
    if [[ "${PKG_STATUS}" == "No managed packages found" ]] || [[ "${PKG_STATUS}" == "All packages are up to datee" ]]; then
      say "Package update not required\n"
    else
      echo "I SEE IT"
      cfg="/Library/brass/notify.yaml"; file="yes"; run_config
      DIALOG_REBOOT="$(/usr/local/bin/dialog -t "${notify_title}" -m "${notify_dialog}\n\n${PKG_STATUS}" --alignment center -i "${notify_iconPath}" --iconsize 90 --selecttitle "When would you like to update?" --selectvalues "Now,Remind me in 15 minutes" --selectdefault "Now" | grep "When would you like to update?" | head -n 1 | awk -F ": " '{print $2}')"
      if [[ -z "${DIALOG_REBOOT}" ]]; then
        err "error, nothing specified\n"
      # Checks to see if "Now" option has been selected
      elif [[ "${DIALOG_REBOOT}" == "Now" ]]; then
        DIALOG_REBOOT="$(/usr/local/bin/dialog --button1disabled -t "Application Update Altert" -m "### Updating System Applications. \nPlease ensure that your workstation is plugged into a power source." --alignment center -i "${notify_iconPath}" --iconsize 90 --progress --progresstext "Updating System Applications")" & package_update all
        killall Dialog
        DIALOG_REBOOT="$(/usr/local/bin/dialog -t "Application Update Altert" -m "### System Application Update Complete. \nAffected applications may need to quit and reopen." --alignment center -i "${notify_iconPath}" --iconsize 90)"
      fi
    fi

  else
    PACKAGE_UPDATE_STATUS=$(package_update outdated)
    if [[ "${PACKAGE_UPDATE_STATUS}" != "All packages are up to date" ]]; then
      say "All packages are up to date\n"
    else
      DIALOG_REBOOT="$(/usr/local/bin/dialog -t "test" -m "${PACKAGE_UPDATE_STATUS}" --alignment center)"
    fi
  fi
}
#>

#< Conf Functions
config_run() {
  if id "${CONF_USER}" &>/dev/null; then
    say "Config user found: ${CONF_USER}\n"
  else
    err "${CONF_USER} not found\n"
  fi

  if [[ ! -d "${CONF_DIR}" ]]; then
    say "Configuration directory not found. Creating ${CONF_DIR}\n"
    mkdir -p "${CONF_DIR}"
  else
    say "Configuration directory found.\n"
  fi

  if [[ ! -f "${CONF_FILE}" ]]; then
    say "Configuation file not found. Creating ${CONF_FILE}\n"
    touch "${CONF_FILE}"
  else
    say "Configuation file found. Overriding ${CONF_FILE}\n"
  fi

  printf "${CONF_CONTENTS}" > "${CONF_FILE}"
  say "$(cat "${CONF_FILE}")\n"
  chown -R "${CONF_USER}": "${CONF_DIR}"
}

config_user(){
  eval "CONF_USER=$(echo ${@})"
}

config_file(){
  eval "CONF_FILE=$(echo ${@})"
  CONF_DIR="$(echo ${CONF_FILE} | awk -F'/' 'BEGIN {OFS = FS} {$NF=""}1')"
}

config_contents(){
  eval "CONF_CONTENTS=$(echo ${@})"
  config_run
}
#>

#< Dock Functions
dock_update() {
  DOCKUTIL_BINARY="/notafile"
  REPO='kcrawford/dockutil'
  URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | awk -F\" '/browser_download_url.*.pkg/{print $(NF-1)}')
  PKG=$(echo $URL | awk -F"/" '{print $NF}')
  if [[ ! -f "${DOCKUTIL_BINARY}" ]]; then
    sudo_check "for dockutil\n"
    env_brew
    if [[ -d "${BREW_PREFIX}/install-tmp" ]]; then
      say "${BREW_PREFIX}/install-tmp found, removing."
      rm -r "${BREW_PREFIX}/install-tmp"
    fi
    say "creating ${BREW_PREFIX}/install-tmp"
    mkdir -p "${BREW_PREFIX}/install-tmp"
    say "Downloading ${PKG}"
    wget "$URL" -P "${BREW_PREFIX}/install-tmp/"
    say "Installing ${PKG}"
    /usr/sbin/installer -pkg "${BREW_PREFIX}/install-tmp/${PKG}" -target /
    say "cleaning brew_depends\n"
    rm -r "${BREW_PREFIX}/install-tmp"
  fi
}

dock_add() {
  if [[ -z "$APP_DIR" ]]; then
    APP_DIR="$@"
  fi
  console_user_command /usr/local/bin/dockutil --allhomes -a "$APP_DIR"
}
#>

#< Brass Functions
brass_log() {
  LOG_DATE=$(date +"%m-%d-%y")
  if [ "$EUID" -ne 0 ]; then
    LOG_FILE="/Users/${CONSOLE_USER}/.config/brass/log/brass_${LOG_DATE}.log"
    LOG_DIR="/Users/${CONSOLE_USER}/.config/brass/log"
  else
    LOG_FILE="/Library/brass/log/brass_${LOG_DATE}.log"
    LOG_DIR="/Library/brass/log"
  fi
  if [[ ! -d "${LOG_DIR}" ]]; then
    mkdir -p "${LOG_DIR}"
  fi
  if [[ ! -f "${LOG_FILE}" ]]; then
    touch "${LOG_FILE}"
  fi
  printf "$(date): $@\n" >> "${LOG_FILE}"
}
brass_update() {
  if [[ "$@" == "yes" ]]; then
    BRASS_BINARY="/usr/local/bin/brass"
    BRASS_DATA=$(cat "${BRASS_BINARY}")
    BRASS_GET=$(curl -H 'Cache-Control: no-cache, no-store' -fsSL "${BRASS_URL}")
    BRASS_DIF=$(echo ${BRASS_GET[@]} ${BRASS_DATA[@]} | tr ' ' '\n' | sort | uniq -u)
    if [[ -z "${BRASS_DIF}" ]]; then
      printf "brass is up to date.\n"
    else
      printf "brass upgrade available. Upgrading brass. Press ctrl+c to cancel. Timeout:  "; countdown
      brass_upgrade
    fi
  fi
}
brass_upgrade() {
  sudo_check "to install brass"
  curl -H 'Cache-Control: no-cache, no-store' -fsSL "${BRASS_URL}" --output /usr/local/bin/brass
  chmod +x /usr/local/bin/brass
  say "install complete.\n"
}
system_branch() {
  BRASS_BRANCH="$@"
  brass_changeBranch
}
brass_changeBranch() {
  BRASS_URL="https://raw.githubusercontent.com/LeadingReach/brass/$BRASS_BRANCH/brass.sh"
  BRASS_CONF_BRANCH=$(cat /Library/brass/brass.yaml | grep branch: | awk -F'branch: ' '{print $2}')
  if [[ "${BRASS_BRANCH}" != "${BRASS_CONF_BRANCH}" ]]; then
    BRASS_CONF=$(sed "s/$BRASS_CONF_BRANCH/$BRASS_BRANCH/g" /Library/brass/brass.yaml)
    echo "${BRASS_CONF}" > /Library/brass/brass.yaml
  fi
  brass_update yes
}
brass_debug() {
  env_brew
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
      BRASS LOG: ${LOG_DIR}

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

#< Script Logic
brass_log "#### BRASS START ####"
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
  sudo_reset
  exit
fi
if [[ ! -d /Library/brass/pkg ]]; then
  mkdir -p /Library/brass/pkg
fi
# Checks to see if xcode CommandLineTools is installed
if [[ "${XCODE_CHECK_INSTALLED}" != "yes" ]]; then
  xcode_check_installed
fi
system_runMode local
conf_get yes
script_check "$@"
sudo_reset
brass_log "##### BRASS END #####\n"
#>
