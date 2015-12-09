#!/bin/bash
if [[ -z $HAM_HOME ]]; then
    echo "E/HAM_HOME not set !"
    exit 1
fi
if [[ -z $USERNAME ]]; then
    export USERNAME=$USER
fi
if [[ -z $USER ]]; then
    export USER=$USERNAME
fi

# Serious BS from Cygwin...
export CYGWIN=nodosfilewarning

########################################################################
##  Tables
########################################################################
ni-hput() {
  eval export "NI_HASH_$1__""$2"='$3'
}

ni-hremove() {
  eval unset "NI_HASH_$1__""$2"
}

ni-hclear() {
    for h in $(ni-hkeys t); do
        ni-hremove $1 $h
    done
}

ni-hget() {
  eval echo '${'"NI_HASH_$1__$2"'#hash}'
}

ni-hkeys() {
  env | grep -E "^NI_HASH_$1__[[:alnum:]]*=" | sed -r "s/^NI_HASH_$1__(.*)=.*/\\1/g"
}

ni-hprint() {
  env | grep -E "^NI_HASH_$1__[[:alnum:]]*=" | sed "s/^NI_HASH_$1__//g"
}

########################################################################
##  Utils
########################################################################
complain()
# usage: complain ModuleName "Diagnostic Message"
#
# Display a message of the form `aglDevEnv.ModuleName: Diagnostic Message',
# then continue aglDevEnv execution.
{
  echo >&2 "E/$1: $2"
}

die()
# usage: die ModuleName "Message Saying Why"
#
# Display a diagnostic message, and cause the aglDevEnv to abort; this
# is the function dispatcher invoked by `require', when the specified
# "aglDevEnv.ModuleName" file cannot be sourced; it may also be invoked
# directly from any sourced "aglDevEnv.ModuleName" file, to diagnose
# any fatal condition.
{
  complain "$@"
  exit 1
}

errcheck()
{
	if [ $1 != 0 ]
	then
		die $2 "$3 (errcode $1)"
	fi
}

nativedir()
# usage: NativePathNameVariable=`nativedir "/MSYS/PathName"`
{
    DIRPATH="$1"
    case $HAM_OS in
        NT*)
            2>/dev/null cd "$DIRPATH"; pwd -W
            ;;
        *)
            # echo "$DIRPATH"
            echo $( cd "$DIRPATH" && pwd )
            ;;
    esac
}

unxpath()
# usage: NativePathNameVariable=`unxpath "/MSYS/PathName"`
#
# Determine the native Native path name equivalent for the POSIX style
# "/MSYS/PathName";  (CAVEAT:  the specified "/MSYS/PathName" *must*
# reference an existing *directory* on the MSYS or POSIX host).
{
    DIR=`nativedir "$1"`
    case $HAM_OS in
        NT*)
            BLA=${DIR//\\/\/}
            if test ${BLA//[a-zA-Z]:*/ABSWINPATH} = "ABSWINPATH"; then
                echo /${BLA//:\//\/}
            else
                echo $BLA
            fi
            ;;
        *)
            ABSPATH=${DIR}
            echo $ABSPATH
            ;;
    esac
}

thisscriptdir() {
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    echo `unxpath "$DIR"`
}

update_prompt() {
    TOOLSET_EXTRA=
    if [ "$BUILD_JNI" == "1" ]; then
        TOOLSET_EXTRA=" (jni)"
    fi

    if [ -z "$HAM_PROJECT_DIR" ]; then
        PROJECT_NAME=`basename "$WORK"`
    else
        PROJECT_NAME=`basename "$HAM_PROJECT_DIR"`
    fi

    export PS1='
\[\033[35m$PROJECT_NAME$TOOLSET_EXTRA\033[0m\] \w (\[\033[32m$USERNAME\033[0m\]) \[\033[0;36m$HAM_IMPORTED_TOOLSETS\033[0m\]
$ '
	# echo -e "\033]0;`pwd`\007"
  # export PS1="${AGL_TOOLSET_NAME}\$ "
}

upsearch() {
    test / == "$PWD" && return || test -e "$1" && echo "$PWD" && return || cd .. && upsearch "$1"
}

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER)
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

########################################################################
##  Toolsets
########################################################################
toolset_import() {
    export PATH=$PATH
    . ham-toolset-import.sh $1
    if [ $? != 0 ]; then
        return 1
    fi
}

toolset_import_once() {
    ALREADY_IMPORTED=`ni-hget HAM_IMPORTS $1`
    if [[ $ALREADY_IMPORTED = "1" ]]; then
        echo "I/Already imported '$1'."
    else
        . hat $1
    fi
}

toolset_dl() {
    export CWD=`pwd`
    export DIR="${HAM_HOME}/toolsets/$1"
    # export ARCH_URL="http://localhost:8123/data/toolsets/$2.7z"
    export ARCH_URL="http://cdn2.talansoft.com/toolsets/$2.7z"
    export DLFILENAME="_$2.7z"
    echo "=== Importing toolset '$1' from $DIR"
    pushd "${DIR}" > /dev/null
    if [ $? != 0 ]; then
        echo "Can't cd to the toolset's directory '$DIR'."
        return 1;
    elif [ -e "$DLFILENAME" ]; then
        echo "... Extracting $DLFILENAME"
        7z x -y "$DLFILENAME" | grep -v -e "\(7-Zip\|Processing\|Extracting\|^$\)" -
        popd
    elif [ ! -e "$DLFILENAME" ]; then
        echo "... Trying download from ${ARCH_URL}"
        wget -c --no-check-certificate $ARCH_URL -O"$DLFILENAME.wget"
        if [ $? != 0 ]; then
            echo "Download failed !"
            popd
            return 1;
        fi
        mv "$DLFILENAME.wget" "$DLFILENAME"
        echo "... Extracting $DLFILENAME"
        7z x -y "$DLFILENAME" | grep -v -e "\(7-Zip\|Processing\|Extracting\|^$\)" -
        popd
    fi
}

toolset_dl_cleanup() {
    export DLFILENAME="_$1.7z"
    if [ -e "$DLFILENAME" ]; then
        rm "$DLFILENAME"
    fi
}

toolset_info() {
    echo "======================================================="
    echo "=== Main Toolset ======================================"
    echo "======================================================="
    echo "HAM_IMPORTED_TOOLSETS = ${HAM_IMPORTED_TOOLSETS}"
    echo "HAM_TOOLSET = ${HAM_TOOLSET}"
    echo "HAM_TOOLSET_VER = ${HAM_TOOLSET_VER}"
    echo "HAM_TOOLSET_NAME = ${HAM_TOOLSET_NAME}"
    echo "HAM_TOOLSET_DIR = ${HAM_TOOLSET_DIR}"
    echo "======================================================="
    echo "=== Tools Version ====================================="
    echo -n "======================================================="
    echo "$HAM_TOOLSET_VERSIONS"
    echo "======================================================="
}

toolset_import_list() {
    for ARG in $@
    do
        . ham-toolset-import.sh $ARG || return 1
        export HAM_IMPORTED_TOOLSET=$ARG
    done
}

toolset_bak_mv() {
    if [ -e "$1" ]; then
        mv -f "$1" "$1__bak"
    fi;
}

toolset_bak_rm() {
    if [ -e "$1__bak" ]; then
        rm -Rf "$1__bak"
    fi;
}

# usage: toolset_check_and_dl_ver name loa version
# example: toolset_check_and_dl_ver repos nt-x86 v2
toolset_check_and_dl_ver() {
    TS_NAME=$1
    TS_LOA=$2
    TS_VER=$3
    TS_DIR="${HAM_HOME}/toolsets/${TS_NAME}/${TS_LOA}"
    TS_VER_NAME=${TS_NAME}_${TS_LOA}_${TS_VER}
    TS_VER_FILE_NAME=toolset_${TS_VER_NAME}
    if [ ! -e "${TS_DIR}/${TS_VER_FILE_NAME}" ]; then
        toolset_bak_mv ${TS_LOA}
        toolset_dl ${TS_NAME} ${TS_VER_NAME}
        if [ ! -e "${TS_DIR}/${TS_VER_FILE_NAME}" ]; then
            echo "E/Toolset '$TS_NAME': Can't find '${TS_VER_FILE_NAME}' in '${TS_DIR}'."
            return 1
        fi
        toolset_dl_cleanup ${TS_VER_NAME}
        toolset_bak_rm ${TS_LOA}
    fi
}

########################################################################
##  Environments
########################################################################
# Set HAM_OS first, its used by the script commands
if [[ $OS == Windows* ]]; then
    export HAM_OS=NT
    export HAM_BIN_LOA=nt-x86
    if [ -z $HOME ]; then
        export HOME=`unxpath "$USERPROFILE"`
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export HAM_OS=OSX
    export HAM_BIN_LOA=osx-x86
else
    UNAME_STR=`/bin/uname`
    MACHINE_TYPE=`/bin/uname -m`
    if [ "$UNAME_STR" == "Linux" ] && [ "$MACHINE_TYPE" == "x86_64" ]; then
        export HAM_OS=LINUX
        export HAM_BIN_LOA=lin-x64
    else
        echo "W/Unknown OS '$UNAME_STR' '$MACHINE_TYPE'"
    fi
    # exit 1
fi

if [[ -z $BUILD_BIN_LOA ]]; then
    export BUILD_BIN_LOA=$HAM_BIN_LOA
fi

if [[ -z $WORK ]]; then
    export WORK=`nativedir "$HAM_HOME/.."`
    if [ "$HAM_NO_VER_CHECK" != "1" ]; then
        echo "W/WORK not set, set to '$WORK' by default."
    fi
fi
export WORK=`unxpath "$WORK"`

if [[ -z $HOME ]]; then
    echo "E/HOME not set !"
    exit 1
fi
if [[ -z $HAM_OS ]]; then
    echo "E/HAM_OS not set !"
    exit 1
fi
if [[ -z $HAM_BIN_LOA ]]; then
    echo "E/HAM_BIN_LOA not set !"
    exit 1
fi
if [[ -z $BUILD_BIN_LOA ]]; then
    echo "E/BUILD_BIN_LOA not set !"
    exit 1
fi

# Make sure HAM_HOME has the proper unix format
export HAM_HOME=`unxpath "$HAM_HOME"`
