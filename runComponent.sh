#!/usr/bin/env bash


COMPONENT="$1"
ACTION="$2"

VALID_VARS="dependencies packages"
VALID_ACTIONS="post_install manual_install install_config"


function run_if_exists() {
    if command -v $1 > /dev/null; then
        printf "Running $1 for component $COMPONENT\n"
        $1
    fi
}


function perform_action() {
    source $COMPONENT_DIR/$COMPONENT
    if [ "$ACTION" = "get_var" ]; then
        if [[ " $VALID_VARS " =~ " $1 " ]]; then
            printf "${!1}"
        else
            exit_with_err "Unknown variable: $1"
        fi
    elif [[ " $VALID_ACTIONS " =~ " $ACTION " ]]; then
        run_if_exists $ACTION
    else
        exit_with_err "Unknown action: $ACTION"
    fi
}


# if [ "$#" -ne 2 ]; then
#     exit_with_err "Incorrect number of arguments"
# fi

if [ ! -d "$COMPONENT_DIR" ]; then
    exit_with_err '$COMPONENT_DIR is not set or is not a directory'
fi

if [ ! -f "$COMPONENT_DIR/$COMPONENT" ]; then
    exit_with_err "Could not find component $COMPONENT"
fi

if [[ "$ACTION" =~ ' ' ]]; then
    exit_with_err "Invalid action: '$ACTION' contains a space"
fi

shift
shift
perform_action "$@"
