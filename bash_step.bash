#!/bin/bash
# This script is loaded by bootstrap_init.bash
# Depends on bsfl.bash (the Bash Shell Function Library)

##### UTILITY FUNCTIONS #####

# From http://stackoverflow.com/a/5196220/213191
# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
#
# Example:
#     step "Remounting / and /boot as read-write:"
#       try mount -o remount,rw /
#       try mount -o remount,rw /boot
#     next
step() {
    echo -n "[$(date +"%m-%d-%Y %T")] $@"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}
step_multi_line() {
    echo -ne "[$(date +"%m-%d-%Y %T")][BEGIN] $@ ...\n"

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
        echo -e "\n DYING HERE WITH EXIT_CODE: $EXIT_CODE...\n"
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
      echo -n "[$(date +"%m-%d-%Y %T")][ END ] $STATUS_LINE"
      STATUS_LINE=''
      [[ $STEP_OK -eq 0 ]] && echo_success || echo_failure;
    fi
    return $STEP_OK
}