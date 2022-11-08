#!/bin/bash

#< Enviroment variables
# brass directory
BRASS_DIR="/opt/brass/"
BRASS_CONF_FILE="brass.yaml"
# brass_url - brass script URL
if [[ -f "${BRASS_DIR}${BRASS_CONF_FILE}" ]] && [[ -n $(cat ${BRASS_DIR}${BRASS_CONF_FILE} | grep branch: | awk -F'branch: ' '{print $2}') ]]; then
  BRASS_BRANCH=$(cat ${BRASS_DIR}${BRASS_CONF_FILE} | grep branch: | awk -F'branch: ' '{print $2}')
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
  optspec=":g:j:ZvVxcs:iruzp:P:d:t:Q:f:nlae:bqhygMmUoOND:w:W:L-:"
  while getopts "$optspec" flag; do
    case "${flag}" in
    # YAML Config Functions
      c) package_all_enabled;;
      g) cfg="$OPTARG"; url="yes"; run_config; exit;; # Option to run brass from remote config yaml file
      j) token="$OPTARG";; # Option to select GitHub Secure Token to access yaml config files
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
      i) brew_install yes;; # Installs brew
      r) brew_uninstall yes;; # Uninstalls brew
      u) brew_update yes;; # Updates brew
      z) brew_reset yes;; # Uninstalls and reinstalls brew
      e) brewDo "$OPTARG";; # Run brew command
    # CLI Package Functions
      p) PACKAGE="$OPTARG"; package_install $PACKAGE;; # Installs a package
      P) PACKAGE="$OPTARG"; package_manage $PACKAGE;; # Adds app.yaml to /Library/pkg/pkg.yaml
      d) PACKAGE="$OPTARG"; package_uninstall $PACKAGE;; # Uninstalls a package
      D) PACKAGE="$OPTARG"; package_unmanage $PACKAGE;; # Removess app.yaml from /Library/pkg/pkg.yaml
      M) package_update all;;
      m) package_update show;;
      U) package_update new;;
      o) package_update outdated;;
      B) package_option "$OPTARG";;
      L) update_notification;;
    # CLI Brass Functions
      N) gui_update;;
      b) brass_debug;;
      q) brass_update yes;;
      Q) BRASS_BRANCH="$OPTARG"; brass_changeBranch;;
      O) dock_update;;
      w) APP_DIR="$OPTARG"; dock_add;;
      W) APP_DIR="$OPTARG"; dock_remove;;
    # CLI Help Functions
      g) flags;;
      y) yaml;;
      h) help;;
      -)
          case "${OPTARG}" in
            test=*) # Option to run brass from config yaml file
                val=${OPTARG#*=}
                opt=${OPTARG%=$val}
                daemon_check -e --name="com.mess.test.run" --binary="/usr/local/bin/brass" --args="-u" --day=tuesday --hour=11 --minute="57" --config=enabled;;

            verbose-level=*) # Option to run brass from config yaml file
                val=${OPTARG#*=}
                VERBOSE_LEVEL=${OPTARG#*=}
                opt=${OPTARG%=$val}
                verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                file="yes"
                run_config;;

            log)
                val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                system_log;;

              config-file=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  cfg=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  file="yes"
                  run_config;;

              config-command=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  cfg=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  eval "${cfg}";;

              config-url=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  cfg=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  url="yes"
                  run_config;;

              config-token=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  token=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2;;

              config-secret=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  secret=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  token=$(cat "${secret}");;

              *)
                  if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                      echo "Unknown option --${OPTARG}" >&2
                  fi
                  ;;
          esac;;
      h)
          echo "usage: $0 [-v] [--loglevel[=]<value>]" >&2
          exit 2
          ;;
      v)
          echo "Parsing option: '-${optchar}'" >&2
          ;;
      *)
          if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
              echo "Non-option argument: '-${OPTARG}'" >&2
          fi
          ;;
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
print_verbose() {
  if [[ ${SYSTEM_VEROBSE} == "yes" ]]; then
    printf "${VERBOSE_MESSAGE}\n"
  fi
}
verbose() {
  if [[ "${1}" == "level" ]] && [[ "${2}" == "0" ]] || [[ "${2}" == "1" ]] || [[ "${2}" == "2" ]]; then
    VERBOSE_MESSAGE="${3}"
    print_verbose
    if [[ "${2}" == "0" ]]; then
      printf "$(date): ${VERBOSE_MESSAGE}\n" >> "${LOG_FILE}"
      printf "${VERBOSE_MESSAGE}\n"
      print_verbose
    fi
    if [[ "${2}" == "1" ]]; then
      printf "$(date): ${VERBOSE_MESSAGE}\n" >> "${LOG_FILE}"
      if [[ "${VERBOSE_LEVEL}" == "1" ]] || [[ "${VERBOSE_LEVEL}" == "2" ]]; then
        printf "${VERBOSE_MESSAGE}\n"
        print_verbose
      fi
    fi
    if [[ "${2}" == "2" ]]; then
      if [[ "${VERBOSE_LEVEL}" == "2" ]]; then
        printf "$(date): ${VERBOSE_MESSAGE}\n" >> "${LOG_FILE}"
        print_verbose
      fi
    fi
  fi
}
err() {
  printf '%s\n' "$1" >&2
  printf "$(date): ERROR: $@" >> "${LOG_FILE}"
  brass_debug
  sudo_reset
  exit 77
}
user_command() {
  if [[ "${CONSOLE_USER}" == "${SYSTEM_USER}" ]]; then
    verbose level 2 "running $@ as ${SYSTEM_USER}"
      "$@"
  else
    sudo_check "to run as another user"
    verbose level 2 "running $@ as ${SYSTEM_USER}"
    /usr/bin/sudo -i -u "${SYSTEM_USER}" $@
  fi
}
console_user_command() {
  if [[ "${CONSOLE_USER}" == "${SYSTEM_USER}" ]]; then
    verbose level 2 "running $@ as ${SYSTEM_USER}"
      "$@"
  else
    sudo_check "to run as another user"
    verbose level 2 "running $@ as ${CONSOLE_USER}"
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
    verbose level 1 "sudo priviledges are not required\n"
  fi
}
sudo_disable() {
  system_user
  verbose level 2 "disabling sudo requirements\n"
  SUDO_DIR=("SETENV:/bin/ln" "SETENV:/usr/sbin/chown" "SETENV:/usr/sbin/chmod" "SETENV:/bin/launchctl" "SETENV:/bin/rm" "SETENV:/usr/bin/env" "SETENV:/usr/bin/xargs" "SETENV:/usr/sbin/pkgutil" "SETENV:/bin/mkdir" "SETENV:/bin/mv" "SETENV:/usr/bin/pkill")
  for str in ${SUDO_DIR[@]}; do
    if [[ -z $(/usr/bin/sudo cat /etc/sudoers | grep "${str}" | grep "#brass") ]]; then
      STR_BINARY=$(echo "$str" | awk -F"/" '{print $(NF)}')
      echo "${SYSTEM_USER}         ALL = (ALL) NOPASSWD: $str  #brass" | sudo EDITOR='tee -a' visudo > /dev/null
    fi
  done
}
sudo_reset() {
  verbose level 1 "removing brass sudoers entries\n"
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
    if [[ -f "${BRASS_DIR}${BRASS_CONF_FILE}" ]]; then
      cfg="${BRASS_DIR}${BRASS_CONF_FILE}"; file="yes"; run_config
    elif [[ -f "/Users/${CONSOLE_USER}/.brass/${BRASS_CONF_FILE}" ]]; then
      cfg="/Users/${CONSOLE_USER}/.brass/${BRASS_CONF_FILE}"; file="yes"; run_config
    fi
  elif [[ "$@" == "VERBOSE_OVERIDE" ]] && [[ ! "$EUID" -ne 0 ]]; then
    if [[ -f "${BRASS_DIR}${BRASS_CONF_FILE}" ]]; then
      cfg="${BRASS_DIR}${BRASS_CONF_FILE}"; file="yes"; run_config
    elif [[ -f "/Users/${CONSOLE_USER}/.brass/${BRASS_CONF_FILE}" ]]; then
      cfg="/Users/${CONSOLE_USER}/.brass/${BRASS_CONF_FILE}"; file="yes"; run_config
    fi
  fi
}
#>

#< System Functions
env_path(){
  if [[ -z $(cat /etc/paths.d/brass | grep "${BREW_BIN}") ]]; then
    verbose level 1 "${BREW_PREFIX} is not in path"
    if [ "$EUID" -ne 0 ];then
      verbose level 1 "sudo priviledges are reqired to add ${BREW_PREFIX} to path"
    else
      verbose level 1 "adding ${BREW_PREFIX}/bin to /etc/paths.d/brass"
      printf "${BREW_PREFIX}/bin\n" >> /etc/paths.d/brass
      if [ -x /usr/libexec/path_helper ]; then
        eval `/usr/libexec/path_helper -s`
      fi
    fi
  fi
}
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
  env_path
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
  env_path
}
env_user() {
  ENV_USER=$(user_command printenv)
  echo "${ENV_USER}"
}
system_log() {
  cat "${LOG_FILE}"
}
system_verbose(){
  if [[ "${1}" == "yes" ]] || [[ -z "${@}" ]]; then
    SYSTEM_VEROBSE="yes"
  else
    SYSTEM_VEROBSE="false"
  fi
}
system_runMode() {
  if [[ -z "${SYSTEM_RUNMODE}" ]] || [[ "${SYSTEM_RUNMODE}" != "${@}" ]] ; then
    unset SYSTEM_USER_RAN
    unset SYSTEM_RUNMODE
  fi
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
    brew_install
  fi
}
system_user() {
  # Skips function if user is already specified
  if [[ "${SYSTEM_USER_RAN}" != 1 ]]; then
    # Checks to see if a user has been specified
    if [[ "${SYSTEM_IFADMIN}" != "yes" ]]; then
      if [[ "${@}" ]]; then
        verbose level 1 "Continuing as ${@}\n"
        SYSTEM_USER="${@}"
      elif [[ -z "${@}" ]] && [[ -z "${SYSTEM_USER}" ]]; then
        verbose level 1 "No user specified. Continuing as ${CONSOLE_USER}\n"
        SYSTEM_USER="${CONSOLE_USER}"
      elif [[ -z "${@}" ]] && [[ "${SYSTEM_USER}" ]]; then
        verbose level 1 "System user is: ${SYSTEM_USER}\n"
      fi
    elif [[ -z "${SYSTEM_USER}" ]]; then
      verbose level 1 "No user specified. Continuing as ${CONSOLE_USER}\n"
      SYSTEM_USER="${CONSOLE_USER}"
    else
      verbose level 1 "System user is: ${SYSTEM_USER}\n"
    fi

    # Checks to see if the specified user is present
    if id "${SYSTEM_USER}" &>/dev/null; then
      verbose level 1 "System user found: ${SYSTEM_USER}\n"
    else
      verbose level 1 "${SYSTEM_USER} not found, creating ${SYSTEM_USER}. ctrl+c to cancel:  "; countdown
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
  sudo chown -R "${SYSTEM_USER}":staff "/Users/${SYSTEM_USER}"
  verbose level 1 "successfully created ${SYSTEM_USER} with UID ${uid} and GID ${gid} with admin priviledges.\n"
  brass_restart
}
system_ifAdmin() {
  if [[ "$1" == "yes" ]]; then
    if [[ "${USER_CLASS}" == "admin" ]]; then
      SYSTEM_IFADMIN="yes"
      verbose level 1 "Brew admin enabled: ${CONSOLE_USER} is an admin user. Running brew as ${CONSOLE_USER}\n"
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
  verbose level 2 "xcode commandlinetools prefix is ${XCODE_PREFIX}\n"
}
xcode_trick() {
  /usr/bin/sudo touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  verbose level 2 "added temp file for xcode commandlinetools update\n"
}
xcode_untrick() {
  /usr/bin/sudo /bin/rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  verbose level 2 "removed temp file for xcode commandlinetools update\n"
}
xcode_check_installed() {
  if [[ "${XCODE_CHECK_INSTALLED}" != "yes" ]]; then env_xcode;
    if [[ ! -x "${XCODE_PREFIX}/usr/bin/git" ]]; then XCODE_INSTALLED="flase";
      verbose level 1 "Xcode CommandLineTools directory not defined"
      verbose level 1 "Installing Xcode CommandLineTools. ctrl+c to cancel:  "; countdown
      if [[ -d "${XCODE_PREFIX}" ]]; then rm -r "${XCODE_PREFIX}"; fi
      xcode_install yes
    else XCODE_INSTALLED="yes";
    fi; env_xcode
  fi; XCODE_CHECK_INSTALLED="yes"
}
xcode_installed_version() {
  # Sets xcode installed version variable
  if [[ -n "${XCODE_PREFIX}" ]]; then
    verbose level 1 "Checking for the installed version of xcode CommandLineTools\n"
    XCODE_INSTALLED_VERSION=$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | awk -F"version: " '{print $2}' | awk -v ORS="" '{gsub(/[[:space:]]/,""); print}' | awk -F"." '{print $1"."$2}')
    verbose level 1 "The installed version of xcode CommandLineTools is ${XCODE_INSTALLED_VERSION}\n"
  fi
}
xcode_latest_version() {
  if [[ -z "${XCODE_LATEST_VERSION}" ]]; then
    sudo_check "to check the latest version of xcode"
    xcode_trick &> /dev/null
    # Sets xcode latest version variable
    echo "Checking for the latest vesrion of xcode CommandLineTools. This may take some time."
    XCODE_LATEST_VERSION=$(/usr/bin/sudo /usr/sbin/softwareupdate -l | awk -F"Version:" '{ print $1}' | awk -F"Xcode-" '{ print $2 }' | sort -nr | head -n1)
    verbose level 1 "The latest version of xcode CommandLineTools is ${XCODE_LATEST_VERSION}\n"
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
    verbose level 1 "\nXcode info:\n$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed 's/^/\t\t/')\n"
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
      verbose level 1 "\nXcode is outdate, updating Xcode version ${XCODE_LATEST_VERSION} to ${XCODE_LATEST_VERSION}"
      xcode_install yes
    else
      verbose level 1 "xcode is up to date.\n"
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
        verbose level 1 "System Mode Enabled: Brew binary is located at $BREW_BINARY\n"
        SYSTEM_MODE="System"
      fi
    else
      if [[ -z "${SYSTEM_MODE}" ]]; then
        verbose level 1 "System Mode Enabled\n"
        SYSTEM_MODE="System"
      fi
    fi
  else
    env_local
    if [[ -x "${BREW_BINARY}" ]]; then
      if [[ -z "${SYSTEM_MODE}" ]]; then
        verbose level 1 "User Mode Enabled: Brew binary is located at $BREW_BINARY\n"
        SYSTEM_MODE="User"
      fi
    else
      if [[ -z "${SYSTEM_MODE}" ]]; then
        verbose level 1 "User Mode Enabled\n"
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
      SYSTEM_VEROBSE="yes"
      verbose level 1 "brew is already installed to ${BREW_PREFIX}. Resetting brew.\n"
      echo "Press ctrl+c to cancel. Timeout:  "; countdown
      BREW_RESET="yes"
      if [[ "${SYSTEM_RUNMODE}" == "local" ]]; then
        verbose level 1 "Resetting local brew prefix\n"
        brew_uninstall
      else
        verbose level 1 "Resetting system brew prefix\n"
        brew_system_uninstall
      fi
    else
      if [[ "${SYSTEM_RUNMODE}" == "local" ]]; then
        verbose level 1 "Installing local brew prefix\n"
        user_command mkdir -p "${BREW_PREFIX}"
        # user_command curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "${BREW_PREFIX}"
        user_command git clone https://github.com/Homebrew/brew "${BREW_PREFIX}"
        eval "$(${BREW_PREFIX}/bin/brew shellenv)"
        user_command "${BREW_PREFIX}"/bin/brew update --force
        chmod -R go-w "$(${BREW_PREFIX}/bin/brew --prefix)/share/zsh"
      else
        verbose level 1 "Installing system brew prefix\n"
        brew_system_install
      fi
    fi
    brew_check
  fi
}
brew_system_install () {
  sudo_disable
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
    verbose level 1 "brew_update: Enabled. Updating brew\n"
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
  if [ "$EUID" -ne 0 ];then
    PKG_DIR="/Users/${CONSOLE_USER}/.config/brass/pkg/"
  else
    PKG_DIR="${BRASS_DIR}pkg/"
  fi

  if [[ ! -d "${PKG_DIR}" ]]; then
    mkdir -p "${PKG_DIR}"
  fi
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
    verbose level 1 "Installing $PACKAGE_INSTALL\n"
    brewDo install $PACKAGE_INSTALL -f | grep -v "Operation not permitted"
  else
    verbose level 1 "Updating $PACKAGE_INSTALL\n"
    brewDo upgrade $PACKAGE_INSTALL | grep -v "Operation not permitted"
  fi
  env_package
}
package_manage() {
  env_package
  PACKAGE_MANAGE="$@"
  system_user
  if [[ -z "${PACKAGE_MANAGE}" ]]; then
    err "no package specified"
  fi
  env_package
  if [[ -d "${PKG_DIR}" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="$PKG_MANAGED $(cat ${PKG_DIR}"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
      verbose level 1 "checking ${PKG_MANAGED}"
    done < <(ls "${PKG_DIR}")
    if [[ -z "$(echo ${PKG_MANAGED} | grep "${PACKAGE_MANAGE}" )" ]]; then
      verbose level 1 "adding "${PACKAGE_MANAGE}".yaml to ${PKG_DIR}\n"
      printf "package:\n\tinstall: ${PACKAGE_MANAGE}\n" > "${PKG_DIR}${PACKAGE_MANAGE}".yaml
      verbose level 1 "installing ${PACKAGE_MANAGE}\n"
      package_install "${PACKAGE_MANAGE}"
      PACKAGE_APP="$(brewDo list ${PACKAGE_MANAGE} | grep .app | awk -F"(" '{print $1}' | awk -F"/" '{print $NF}')"
        if [[ ! -z "${PACKAGE_APP}" ]]; then
          dock_add "/Applications/${PACKAGE_APP}"
        fi
    else
      verbose level 1 "${PACKAGE_MANAGE} is already managed\n"
    fi
  fi
}
package_unmanage() {
  PACKAGE_MANAGE="$@"
  env_package
  system_user
  if [[ -z "${PACKAGE_MANAGE}" ]]; then
    err "no package specified"
  fi
  if [[ -d "${PKG_DIR}" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="$PKG_MANAGED $(cat ${PKG_DIR}"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls "${PKG_DIR}")
    if [[ ! -z "$(echo ${PKG_MANAGED} | grep "${PACKAGE_MANAGE}" )" ]]; then
      verbose level 1 "removing "${PACKAGE_MANAGE}".yaml to ${PKG_DIR}\n"
      rm "${PKG_DIR}${PACKAGE_MANAGE}".yaml
    else
      verbose level 1 "${PACKAGE_MANAGE} is already managed\n"
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
  env_package
  if [[ -d "${PKG_DIR}" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="${PKG_MANAGED} $(cat ${PKG_DIR}"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls "${PKG_DIR}")
    PKG_MANAGED="$(echo "${PKG_MANAGED}" | tr '\n' '\ ' | tr -s ' ')"
    PKG_OUTDATED=$(SYSTEM_VEROBSE="FALSE"; brewDo outdated)
    while IFS= read -r LINE; do
      if [[ " ${PKG_OUTDATED[*]} " =~ "${LINE}" ]]; then
        PKG_MANAGED_OUTDATED="${PKG_MANAGED_OUTDATED} ${LINE}"
      fi
    done < <(echo "${PKG_MANAGED}" | tr '\ ' '\n')
    if [[ -z "${PKG_MANAGED}" ]] && [[ -z "${PKG_OUTDATED}" ]]; then
      verbose level 1 "No managed packages found\n"
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
  env_package
  if [[ -d "${PKG_DIR}" ]]; then
    if [[ "${1}" == "enabled" ]]; then
      /usr/local/bin/dialog -p -t "Application Update" -m "Updating applications. \n\nPlease wait for the update to complete." --alignment centre -i "${gui_icon}" --iconsize 40 --centreicon --button1text "Done" --button1disabled --progress --progresstext "Updating Applications" &
    fi
     while IFS= read -r LINE; do
       PKG_MANAGED="$(cat ${PKG_DIR}"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
       verbose level 1 "Checking for ${LINE} updates\n"
       echo "progresstext: Updating ${LINE}" | awk -F".yaml" '{print $1}' >> /var/tmp/dialog.log
       cfg="${PKG_DIR}${LINE}"; file="yes"; run_config
     done < <(ls "${PKG_DIR}")
     echo "progresstext: Finishing up" >> /var/tmp/dialog.log
     /usr/bin/sudo -i -u "${CONSOLE_USER}" "/Users/${CONSOLE_USER}/.homebrew/bin/brew" upgrade
     echo "progress: 100" >> /var/tmp/dialog.log; sleep 2; echo "button1: enable" >> /var/tmp/dialog.log; echo "progresstext: done" >> /var/tmp/dialog.log
  fi
}
package_all_enabled() {
  package_all enabled
}
package_show() {
  env_package
  if [[ -d "${PKG_DIR}" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="${PKG_MANAGED} $(cat ${PKG_DIR}"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls "${PKG_DIR}")
    PKG_MANAGED="$(echo "${PKG_MANAGED}" | tr '\n' '\ ' | tr -s ' ')"
    PKG_OUTDATED=$(SYSTEM_VEROBSE="FALSE"; brewDo outdated)
    while IFS= read -r LINE; do
      if [[ " ${PKG_OUTDATED[*]} " =~ "${LINE}" ]]; then
        PKG_MANAGED_OUTDATED="${PKG_MANAGED_OUTDATED} ${LINE}"
      fi
    done < <(echo "${PKG_MANAGED}" | tr '\ ' '\n')
    if [[ -z "${PKG_MANAGED}" ]]; then
      verbose level 1 "No managed packages found\n"
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
  env_package
  if [[ -d "${PKG_DIR}" ]]; then
    while IFS= read -r LINE; do
      PKG_MANAGED="$PKG_MANAGED $(cat ${PKG_DIR}"${LINE}" | grep "install:" | grep -v "no\|yes" | awk -F'install:' '{print $2}')"
    done < <(ls "${PKG_DIR}")
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
package_option() {
  if [[ ! -d "${BRASS_DIR}icns" ]]; then
    mkdir -p "${BRASS_DIR}icns"
  fi
  if [[ ! -f "${BRASS_DIR}icns/download.icns" ]]; then
    wget -P ${BRASS_DIR}icns https://findicons.com/icon/download/direct/93407/gnome_app_install/128/icns
    mv "${BRASS_DIR}icns/icns" "${BRASS_DIR}icns/download.icns"
  fi
  APPNAME="${1}"
  INSTALLNAME="Install ${APPNAME}"
  DIR="/Applications/${INSTALLNAME}.app/Contents/MacOS";
  if [[ -z $(brewDo list | grep "${APPNAME}") ]] && [[ -z $(/usr/bin/sudo -i -u "${CONSOLE_USER}" "/Users/${CONSOLE_USER}/.homebrew/bin/brew" list | grep "${APPNAME}") ]]; then
    verbose level 1 "adding installer for ${APPNAME}\n"
    if [ -d "/Applications/${INSTALLNAME}.app" ]; then
      verbose level 1 "Installer already present. Overriding\n"
      rm -r "/Applications/${INSTALLNAME}.app"
    fi
    mkdir -p "${DIR}"
    mkdir -p "/Applications/${INSTALLNAME}.app/Contents/Resources/"
    echo "#!/bin/bash
    echo \"clear\" > /var/tmp/dialog.log
    UPDATE_DIALOG="\$\(/usr/local/bin/dialog -t \"${APPNAME} Installer\" -m \"Installing ${APPNAME}. \\n\\nPlease wait for the installation to complete.\" --alignment centre -i \"/Library/Application Support/JAMF/bin/LR.png\" --iconsize 40 --centreicon --button1text \"Done\" --button1disabled --progress --progresstext \"Installing ${APPNAME}\"\)" &
    /usr/local/bin/brass -P ${APPNAME} -p ${APPNAME}
    echo \"button1: enable\" >> /var/tmp/dialog.log; echo \"progresstext: done\" >> /var/tmp/dialog.log; echo \"progress: 100\" >> /var/tmp/dialog.log
    rm -r \"/Applications/${INSTALLNAME}.app\"" > "${DIR}"/"${INSTALLNAME}"
    cp "${BRASS_DIR}icns/download.icns" "/Applications/${INSTALLNAME}.app/Contents/Resources/${INSTALLNAME}.icns"
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"
    \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
    <plist version=\"1.0\">
    <dict>
     <key>CFBundleIconFile</key>
     <string>${INSTALLNAME}.icns</string>
    </dict>
    </plist>" > "/Applications/${INSTALLNAME}.app/Contents/Info.plist"
    chmod +x "${DIR}"/"${INSTALLNAME}"
    chown -R "${CONSOLE_USER}": "/Applications/${INSTALLNAME}.app"
  else
    verbose level 1 "${APPNAME} is already installed\n"
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
    verbose level 1 "killing ${PROCESS_KILL} process"
    pkill -9 "${PROCESS_KILL}"
  fi
}
#>

#< GUI Functions
gui_title() {
  if [[ -z "$@" ]] ; then
    gui_title=brass
  else
    gui_title=$(echo "$@" | tr -d '"')
  fi
}
gui_iconLink() {
  if [[ -z "$@" ]]; then
    unset gui_iconLink
  else
    gui_iconLink=$(echo "$@" | tr -d '"')
  fi
}
gui_iconPath() {
  if [[ -z "$@" ]]; then
    gui_icon="caution"
  else
    gui_iconPath=$(echo "$@" | tr -d '"')
    gui_icon="POSIX file (\"$gui_iconPath\" as string)"
    if [[ ! -z "${gui_iconLink}" ]]; then
      curl "${gui_iconLink}" --output "${gui_iconPath}"
    fi
  fi
}
gui_dialog() {
    gui_dialog="$@"
    if [[ -z $gui_dialog ]]; then
      echo "$@"
      err "Dialog must be specified"
    else
      gui_dialog=$(echo "$@" | tr -d '"')
    fi
}
gui_timeout() {
  if [[ -z "$@" ]]; then
    gui_timeout=10
  else
    gui_timeout=$(echo "$@" | tr -d '"')
  fi
}
gui_allowCancel() {
  if [[ "${@}" = "\"no"\" ]]; then
    gui_buttons="\"okay\""
  else
    gui_buttons="\"okay\", \"not now\""
  fi
}
gui_update() {
  if [[ ! -d /Library/Application\ Support/Dialog ]]; then
    sudo_check "for swiftDialog\n"
    env_brew
    if [[ -d "${BREW_PREFIX}/install-tmp" ]]; then
      verbose level 1 "${BREW_PREFIX}/install-tmp found, removing."
      rm -r "${BREW_PREFIX}/install-tmp"
    fi
    verbose level 1 "creating ${BREW_PREFIX}/install-tmp"
    mkdir -p "${BREW_PREFIX}/install-tmp"
    REPO='bartreardon/swiftDialog'
    URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | awk -F\" '/browser_download_url.*.pkg/{print $(NF-1)}')
    PKG=$(echo $URL | awk -F"/" '{print $NF}')
    verbose level 1 "Downloading swiftDialog"
    wget "$URL" -P "${BREW_PREFIX}/install-tmp/"
    verbose level 1 "Installing swiftDialog"
    /usr/sbin/installer -pkg "${BREW_PREFIX}/install-tmp/${PKG}" -target /
    verbose level 1 "cleaning brew_depends\n"
    rm -r "${BREW_PREFIX}/install-tmp"
  fi
}
#>

#< Update Functions
update_gui() {
  if [[ "${1}" == "enabled" ]]; then
    if [[ "${UPDATE}" == "application" ]]; then
      gui_update
      daemon_check -e --name="com.brass.update.application" --binary="/usr/local/bin/brass" --args="--config-command=package_all_enabled" --day="${UPDATE_DAY}" --hour="${UPDATE_HOUR}" --minute="${UPDATE_MINUTE}" --config=enabled
    fi
  fi
}
update_system() {
  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
  <plist version=\"1.0\">
  <dict>
    <key>Label</key>
    <string>com.github.macadmins.Nudge</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Applications/Utilities/Nudge.app/Contents/MacOS/Nudge</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StartCalendarInterval</key>
    <array>
      <dict>
          <key>Hour</key>
          <integer>8</integer>
          <key>Minute</key>
          <integer>5</integer>
      </dict>
      <dict>
          <key>Hour</key>
          <integer>16</integer>
          <key>Minute</key>
          <integer>55</integer>
      </dict>
    </array>
   </dict>
   </plist>
  " > /Library/LaunchDaemons/
}
update_application() {
  if [[ "${1}" == "enabled" ]]; then
    UPDATE="application"
  fi
}
update_day() {
  UPDATE_DAY="${1}"
}
update_hour() {
  UPDATE_HOUR="${1}"
}
update_minute() {
  UPDATE_MINUTE="${1}"
}
update_title() {
  gui_title "${@}"
}
update_iconPath() {
  gui_iconPath "${@}"
}
update_dialog() {
  gui_dialog "${@}"
}
update_notification() {
  # Runs Dialog app and gives users options to update now, later, or reschedule
  verbose level 1 "Displaying user notification"
  if [[ -z "${UPDATE_WHEN}" ]]; then
    UPDATE_WHEN="$(/usr/local/bin/dialog -t "LeadingReach update Altert" -m "### It's time to update your workstation. \nPlease update as soon as convienent.\n\nAfter updateing you will have to enter your username and password to log in. \n\n_Please verify that your username and password is stored in 1Password._ \n\nYour username is: **\"$CONSOLE_USER\"**" --alignment center -i "${gui_iconPath}" --iconsize 90 --selecttitle "When would you like to update?" --selectvalues "Now,Remind me later, Reschedule Alerts" --selectdefault "Now" | grep "When would you like to update?" | head -n 1 | awk -F ": " '{print $2}')"
  fi

  # Checks to see if returned a valid response
  if [[ -z "${UPDATE_WHEN}" ]]; then
    err "result of update dialog not specified."
  # Checks to see if "Now" option has been selected
  elif [[ "${UPDATE_WHEN}" == "Now" ]]; then
    verbose level 1 "update now selected\n"
    package_all enabled
  # Checks if "Remind me later option has been selected"
  elif [[ "${UPDATE_WHEN}" == "Remind me later" ]]; then
    verbose level 1 "User selected Remind me later\n"
    # Sets notification to run again in 15 minues and alterts the user
    verbose level 1 "Displaying delay notification to user\n"
    update_delay & /usr/local/bin/dialog -t "Update Altert" -m "### You will be reminded in 15 minutes" --alignment center -i "${gui_iconPath}" --iconsize 90
  # Checks to see if "Reschedule Alerts" option was selected
  elif [[ "${UPDATE_WHEN}" == "Reschedule Alerts" ]]; then
    verbose level 1 "User selected reschedule alerts\n"
    # Gives user option to select a time in which they would like to be alerted
    UPDATE_WHEN_RESCHEDULE="$(/usr/local/bin/dialog -t "LeadingReach Reboot Altert" -m "When would you like to be alterted?" --alignment center -i "${gui_iconPath}" --iconsize 90 --selecttitle "Available altert times" --selectvalues "8:00,9:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00" --selectdefault "17:00" | grep "Available altert times" | head -n 1 | awk -F ": " '{print $2}')"
    # Islolateds hour variable
    UPDATE_HOUR="$(echo "${UPDATE_WHEN_RESCHEDULE}" | awk -F ":" '{print $1}')"
    # Isolates minute variable
    UPDATE_MINUTE="$(echo "${UPDATE_WHEN_RESCHEDULE}" | awk -F ":" '{print $2}' | sed 's/[^0-9]*//g')"
    verbose level 1 "Rescheduled for ${UPDATE_HOUR}:${UPDATE_MINUTE}\n"
    # Updates hour variable in update launch daemon
    sed -i'' -e "19s/.*/\ \ \ \ \ \ \<integer\>${UPDATE_HOUR}\<\/integer\>/" "${DAEMON_PATH}"
    # Updates minute variable in update launch daemon
    sed -i'' -e "21s/.*/\ \ \ \ \ \ \<integer\>${UPDATE_MINUTE}\<\/integer\>/" "${DAEMON_PATH}"
    echo "Hour is ${UPDATE_HOUR} and minute is ${UPDATE_MINUTE}"
    # Reloads launch daemon
    verbose level 1 "reloading launch daemon\n"
    daemon_reload
    # If the user selects a time before the curent hour, they will be alerted in 15 minutes to update
    if [[ $(date +%H) -lt "${UPDATE_HOUR}" ]]; then
      verbose level 1 "User scheduled time before curent time.\n"
      verbose level 1 "Curent hour is$(date +%H) and schedueld hour is ${UPDATE_HOUR}\n"
      verbose level 1 "Will display update delay notification.\n"
      update_delay & /usr/local/bin/dialog -t "Update Altert" -m "### Update altert has been successfully updated\n\nAll future alerts will run at the specified time.\n\nYou have schedueld a time before now.\n\nYou will be notifed to update in 15 minutes" --alignment center -i "/Library/Application Support/JAMF/bin/LR.png" --iconsize 90 & exit
    fi
  fi
}
update_delay() {
  # Waits 15 minutes and then notifes user to update
  sleep 900 && update_notification
}
#>

#< Daemon Functions
daemon_check() {
  optspec="e-:"
  while getopts "$optspec" flag; do
    case "${flag}" in
      e) verbose level 1 "daemon check run";;
      -)
          case "${OPTARG}" in
              verbose-level=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  VERBOSE_LEVEL=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level "${VERBOSE_LEVEL}";;
              name=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_name "${val}";;

              binary=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_binary "${val}";;

              args=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  DAEMON_ARGS=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_args "${val}";;

              day=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_day "${val}";;

              hour=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_hour "${val}";;

              minute=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_minute "${val}";;

              config=*) # Option to run brass from config yaml file
                  val=${OPTARG#*=}
                  opt=${OPTARG%=$val}
                  verbose level 2 "Parsing option: '--${opt}', value: '${val}\n'" >&2
                  daemon_config "${val}";;

              *)
                  if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                      echo "Unknown option --${OPTARG}" >&2
                  fi
                  ;;
          esac;;
      *)
          if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
              echo "Non-option argument: '-${OPTARG}'" >&2
          fi
          ;;
      *) help;;
    esac
  done
  if [ $OPTIND -eq 1 ]; then exit; fi
}
daemon_debug() {
  DAEMON_CONF_DEBUG=$(echo "
    <key>StandardOutPath</key>
      <string>${LOG_DIR}/${DAEMON_FILE}-sout.log</string>
    <key>StandardErrorPath</key>
      <string>${LOG_DIR}/${DAEMON_FILE}-eout.log</string>
    <key>RunAtLoad</key>
    <true/>")
}
daemon_name() {
  if [[ -z "$DAEMON_NAME" ]] && [[ -z "$@" ]] ; then
    err "nothing specified\n"
  else
    if [[ -z "$DAEMON_NAME" ]]; then
      DAEMON_NAME=$(echo "$@" | tr -d '"')
    fi
    DAEMON_FILE="${DAEMON_NAME}.plist"
    DAEMON_PATH="/Library/LaunchDaemons/${DAEMON_FILE}"
    DAEMON_ENV="UPDATE"
    DAEMON_ENV_STATUS="enabled"
    verbose level 2 "Daemon name:\t${DAEMON_NAME}"
    verbose level 2 "Daemon file:\t${DAEMON_FILE}"
    verbose level 1 "Daemon path:\t${DAEMON_PATH}"
    daemon_debug
    DAEMON_CONF_NAME=$(echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
    <plist version=\"1.0\">
    <dict>
      <key>Label</key>
      <string>${DAEMON_NAME}</string>")
    DAEMON_CONF_END=$(echo "
    </dict>
    </plist>")
    DAEMON_CONF=$(echo "${DAEMON_CONF_NAME}${DAEMON_CONF_DEBUG}${DAEMON_CONF_END}")
  fi
}
daemon_binary() {
  if [[ -z "${@}" ]] ; then
    err "no command specified\n"
  else
    DAEMON_BINARY=$(echo "${1}" | tr -d '"')
    verbose level 1 "Daemon binary:\t${DAEMON_BINARY}"
    DAEMON_CONF_BINARY=$(echo "
      <key>Program</key>
        <string>${DAEMON_BINARY}</string>")
    DAEMON_CONF=$(echo "${DAEMON_CONF_NAME}${DAEMON_CONF_BINARY}${DAEMON_CONF_DEBUG}${DAEMON_CONF_END}")
  fi
}
daemon_args() {
  if [[ -z "${@}" ]] ; then
    err "no command specified\n"
  else
    DAEMON_ARGS=$(echo "${1}" | tr -d '"')
    verbose level 1 "Daemon args:\t${DAEMON_ARGS}"
    DAEMON_CONF_ARGS=$(echo "
      <key>ProgramArguments</key>
      <array>
        <string>${DAEMON_BINARY}</string>
        <string>${DAEMON_ARGS}</string>
      </array>")
      DAEMON_CONF=$(echo "${DAEMON_CONF_NAME}${DAEMON_CONF_BINARY}${DAEMON_CONF_ARGS}${DAEMON_CONF_DEBUG}${DAEMON_CONF_END}")
  fi
}
daemon_day() {
  if [[ -z "$@" ]] ; then
    err "nothing specified\n"
  else
    if [[ "${@}" == "sunday" ]]; then
      DAEMON_DAY="0"
    elif [[ "${@}" == "monday" ]]; then
      DAEMON_DAY="1"
    elif [[ "${@}" == "tuesday" ]]; then
      DAEMON_DAY="2"
    elif [[ "${@}" == "wednesday" ]]; then
      DAEMON_DAY="3"
    elif [[ "${@}" == "thursday" ]]; then
      DAEMON_DAY="4"
    elif [[ "${@}" == "friday" ]]; then
      DAEMON_DAY="5"
    elif [[ "${@}" == "saturday" ]]; then
      DAEMON_DAY="6"
    else
      DAEMON_DAY=$(echo "$@")
    fi
    verbose level 1 "Daemon day:\t${DAEMON_DAY}"
  fi
}
daemon_hour() {
  if [[ -z "$@" ]] ; then
    err "nothing specified\n"
  else
    DAEMON_HOUR=$(echo "$@" | tr -d '"')
    verbose level 1 "Daemon hour:\t${DAEMON_HOUR}"
  fi
}
daemon_minute() {
  if [[ -z "$@" ]] ; then
    err "nothing specified\n"
  else
    DAEMON_MINUTE=$(echo "$@" | tr -d '"')
    verbose level 1 "Daemon minute:\t${DAEMON_MINUTE}"
    daemon_time
  fi
}
daemon_time() {
  if [[ -z "$DAEMON_DAY" ]] || [[ -z "$DAEMON_HOUR" ]] || [[ -z "$DAEMON_MINUTE" ]]; then
    err "Daemon time variable missing"
  else
    DAEMON_CONF_TIME=$(echo "
      <key>StartCalendarInterval</key>
          <array>
            <dict>
              <key>Weekday</key>
              <integer>${DAEMON_DAY}</integer>
              <key>Hour</key>
              <integer>${DAEMON_HOUR}</integer>
              <key>Minute</key>
              <integer>${DAEMON_MINUTE}</integer>
            </dict>
          </array>")
    DAEMON_CONF=$(echo "${DAEMON_CONF_NAME}${DAEMON_CONF_BINARY}${DAEMON_CONF_ARGS}${DAEMON_CONF_DEBUG}${DAEMON_CONF_TIME}${DAEMON_CONF_END}")
  fi
}
daemon_reload() {
  verbose level 1 "Reloading launch daemon\n"
  launchctl unload "${@}"
  launchctl load "${@}"
}
daemon_config() {
  if [[ "${@}" == "enabled" ]]; then
    echo "${DAEMON_CONF}" > "${DAEMON_PATH}"
    if [[ $(/usr/bin/plutil "${DAEMON_PATH}") == "${DAEMON_PATH}: OK" ]]; then
      verbose level 1 "Daemon check:\tPASS"
      daemon_reload "${DAEMON_PATH}"
    else
      verbose level 1 "Daemon check:\tFAIL"
      rm "${DAEMON_PATH}"
    fi
  fi
}
#>

#< Conf Functions
config_run() {
  if id "${CONF_USER}" &>/dev/null; then
    verbose level 1 "Config user found: ${CONF_USER}\n"
  else
    err "${CONF_USER} not found\n"
  fi

  if [[ ! -d "${CONF_DIR}" ]]; then
    verbose level 1 "Configuration directory not found. Creating ${CONF_DIR}\n"
    mkdir -p "${CONF_DIR}"
  else
    verbose level 1 "Configuration directory found.\n"
  fi

  if [[ ! -f "${CONF_FILE}" ]]; then
    verbose level 1 "Configuation file not found. Creating ${CONF_FILE}\n"
    touch "${CONF_FILE}"
  else
    verbose level 1 "Configuation file found. Overriding ${CONF_FILE}\n"
  fi

  printf "${CONF_CONTENTS}" > "${CONF_FILE}"
  verbose level 1 "$(cat "${CONF_FILE}")\n"
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
  DOCKUTIL_BINARY="/usr/local/bin/dockutil"
  REPO='kcrawford/dockutil'
  URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | awk -F\" '/browser_download_url.*.pkg/{print $(NF-1)}')
  PKG=$(echo $URL | awk -F"/" '{print $NF}')
  if [[ ! -f "${DOCKUTIL_BINARY}" ]]; then
    verbose level 1 "installing dockutil\n"
    sudo_check "for dockutil\n"
    env_brew
    if [[ -d "${BREW_PREFIX}/install-tmp" ]]; then
      verbose level 1 "${BREW_PREFIX}/install-tmp found, removing."
      rm -r "${BREW_PREFIX}/install-tmp"
    fi
    verbose level 1 "creating ${BREW_PREFIX}/install-tmp"
    mkdir -p "${BREW_PREFIX}/install-tmp"
    verbose level 1 "Downloading ${PKG}"
    wget "$URL" -P "${BREW_PREFIX}/install-tmp/"
    verbose level 1 "Installing ${PKG}"
    /usr/sbin/installer -pkg "${BREW_PREFIX}/install-tmp/${PKG}" -target /
    verbose level 1 "cleaning brew_depends\n"
    rm -r "${BREW_PREFIX}/install-tmp"
  fi
}
dock_add() {
  dock_update
  if [[ -z "$APP_DIR" ]]; then
    APP_DIR="$@"
  fi
  verbose level 1 "adding to dock $APP_DIR\n"
  console_user_command /usr/local/bin/dockutil --allhomes -a "$APP_DIR"
}
dock_remove() {
  dock_update
  if [[ -z "$APP_DIR" ]]; then
    APP_DIR="$@"
  fi
  verbose level 1 "removing from dock $APP_DIR\n"
  console_user_command /usr/local/bin/dockutil --allhomes -r "$APP_DIR"
}
#>

#< Brass Functions
brass_log() {
  LOG_DATE=$(date +"%m-%d-%y")
  if [ "$EUID" -ne 0 ]; then
    LOG_FILE="/Users/${CONSOLE_USER}/.config/brass/log/brass_${LOG_DATE}.log"
    LOG_DIR="/Users/${CONSOLE_USER}/.config/brass/log/"
  else
    LOG_FILE="${BRASS_DIR}log/brass_${LOG_DATE}.log"
    LOG_DIR="${BRASS_DIR}log"
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
  BRASS_UPGRADED="yes"
  verbose level 1 "install complete.\n"
}
system_branch() {
  BRASS_BRANCH="$@"
  brass_changeBranch
}
brass_changeBranch() {
  BRASS_URL="https://raw.githubusercontent.com/LeadingReach/brass/$BRASS_BRANCH/brass.sh"
  BRASS_CONF_BRANCH=$(cat ${BRASS_DIR}${BRASS_CONF_FILE} | grep branch: | awk -F'branch: ' '{print $2}')
  if [[ "${BRASS_BRANCH}" != "${BRASS_CONF_BRANCH}" ]]; then
    BRASS_CONF=$(sed "s/$BRASS_CONF_BRANCH/$BRASS_BRANCH/g" ${BRASS_DIR}${BRASS_CONF_FILE})
    echo "${BRASS_CONF}" > ${BRASS_DIR}${BRASS_CONF_FILE}
  fi
  brass_update yes
}
brass_restart() {
  RESTART_COMMAND="/bin/bash $(pwd)/$(basename "$0") ${SCRIPT_CHECK}"
  verbose level 1 "Restarting brass ${RESTART_COMMAND}"
  exec ${RESTART_COMMAND} && exit
}
brass_kill() {
  brass remove --force $(brass list --formula)
  verbose level 1 "removing formula"
  brewDo remove --force $(brewDo list --cask)
  verbose level 1 "removing casks"
  rm -r /opt/brass/pkg
  verbose level 1 "removing pkg"
  rm /etc/paths.d/brass
  verbose level 1 "removing paths"
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
    verbose level 1 "done.\n\n"
  fi
  if [[ "${BRASS_ENV}" == "enabled" ]]; then
    package_all enabled
  fi
  printf "use brass -h for more infomation.\n"
  sudo_reset
fi
if [[ ! -d "${BRASS_DIR}" ]]; then
  verbose level 1 "brass directory not found. Creating ${BRASS_DIR}\n"
  user_command mkdir -p "${BRASS_DIR}"
fi
if [[ ! -d ${BRASS_DIR}pkg ]]; then
  mkdir -p ${BRASS_DIR}pkg
fi
# Checks to see if xcode CommandLineTools is installed
if [[ "${XCODE_CHECK_INSTALLED}" != "yes" ]]; then
  xcode_check_installed
fi
system_runMode local
conf_get yes
verbose level 1 "$@"
SCRIPT_CHECK="$@"
script_check "$@"
#< Verbose level
#>
sudo_reset
verbose level 1 "$(date): ##### BRASS END #####\n"
#>
