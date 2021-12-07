#!/bin/bash
# Depends on the pboling fork of bsfl.bash (the Bash Shell Function Library):
# https://github.com/pboling/bsfl/blob/master/bsfl
#
##### UTILITY FUNCTIONS #####
#
# Inspiration from http://stackoverflow.com/a/5196220/213191
# Use step() or step_multi_line(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
#
# Example:
#     step "Remounting / and /boot as read-write:"
#       try mount -o remount,rw /
#       try mount -o remount,rw /boot
#     next
#

BASH_STEP_VERSION="0.0.2"

step() {
    printf "[$(date +"%m-%d-%Y %T")] $@"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}
step_multi_line() {
    printf "[$(date +"%m-%d-%Y %T")][BEGIN] $@ ...\n"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$

    STATUS_LINE="$@"
}
try() {
    # Check for `-b', `-cmd', `-d' arguments
    # Cannot use both, it is one or the other.
    # -b    => to run command in the background.
    # -cmd  => to run via bsfl's try -cmd function, includes -d
    # -d    => die (exit) on error
    local BG
    local IS_COMMAND
    local DIE_ON_ERROR

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -cmd ]] && { IS_COMMAND=1; DIE_ON_ERROR=1; shift; }
    [[ $1 == -d ]] && { DIE_ON_ERROR=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if has_value BG ; then
        "$@" &
    elif has_value IS_COMMAND ; then
       cmd "$@" # cmd is from bsfl.bash
    else
        "$@"
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            # The following command: `readlink -m' does not work on MacOS.
            # To allow building on Mac do
            #   unset LOG_STEPS
            # In whatever script you are running, and after it is set in scripts/libraries/config.bash.
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \`$*' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    if has_value DIE_ON_ERROR ; then
      if [[ "$EXIT_CODE" != "0" ]]; then
        printf "\n DYING HERE WITH EXIT_CODE: $EXIT_CODE...\n"
      fi
      die_if_false $EXIT_CODE "ERROR IN CMD: $@"
    fi
    return $EXIT_CODE
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }

    if [ -z "$STATUS_LINE" ] # test empty
    then
      [[ $STEP_OK -eq 0 ]] && echo_success || echo_failure;
    else
      printf "[$(date +"%m-%d-%Y %T")][ END ] $STATUS_LINE"
      STATUS_LINE=''
      [[ $STEP_OK -eq 0 ]] && echo_success || echo_failure;
    fi
    return $STEP_OK
}

function num_cores() {
  if ! is_integer $NUM_CORES; then
    if [[ $SYSTEM_TYPE == 'Darwin' ]]; then
      # Mac
      RESULT=$(sysctl hw.ncpu)
      NUM_CORES=${RESULT##* }
    else
      # Linux
      NUM_CORES=$(grep -c -i --color "model name" /proc/cpuinfo)
    fi
  fi
  if ! is_integer $NUM_CORES; then
    NUM_CORES=1
    echo "Unable to determine how many cores are availalbe, using $NUM_CORES"
  fi
  export NUM_CORES=$NUM_CORES
  return 0
}
function num_build_jobs() {
  if ! is_integer $JOBS_PER_CORE; then
    JOBS_PER_CORE=2
  fi
  num_cores
  if ! is_integer $BUILD_JOBS; then
    BUILD_JOBS=$(($NUM_CORES * $JOBS_PER_CORE))
  fi
  export BUILD_JOBS=$BUILD_JOBS
  return 0
}
function die_unless_has_exported_value_step() {
  step "[TEST] $1 has export val"
    die_unless_has_exported_value $1
  next
}
function die_unless_has_exported_value() {
  has_exported_value $1
  die_if_false $? "$1 is undefined."
}

function die_unless_has_value_step() {
  step "[TEST] $1 has value"
    die_unless_has_value $1
  next
}

function die_unless_has_value() {
  has_value $1
  die_if_false $? "$1 is undefined."
}
