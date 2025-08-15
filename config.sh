#!/usr/bin/env bash


export SETUP_DIR="${SETUP_DIR:-$(dirname $(realpath $0))}"
export UTIL_DIR="${UTIL_DIR:-$SETUP_DIR/util}"
if [ ! -d "$UTIL_DIR" ]; then
    printf "\$UTIL_DIR must point to the util/ directory, but is set to $UTIL_DIR, which is not a directory"
    exit -1
fi
source "$UTIL_DIR/common"


ACTION=""
DEFAULT_EDITOR=""
COMPONENTS=()

if command -v nvim > /dev/null; then
    DEFAULT_EDITOR="nvim"
elif command -v vim > /dev/null; then
    DEFAULT_EDITOR="vim"
elif command -v nano > /dev/null; then
    DEFAULT_EDITOR="nano"
fi

EDITOR="${EDITOR:-$DEFAULT_EDITOR}"


function usage() {
    printf """Usage: $0 [action] [components]

action: edit | apply\n"""
}


function add_component() {
    if [[ "$1" =~ ' ' ]]; then
        exit_with_err "Invalid component name: '$1' contains a space"
    fi

    [[ " ${COMPONENTS[@]} " =~ " $1 " ]] && return;
    if [ ! -f "$COMPONENT_DIR/$1" ]; then
        printf "$1 component does not exist\n"
        return
    fi
    COMPONENTS+=($1)
}


function edit_file() {
    local component="$1"
    local path="$2"
    [ ! -f "$path" ] || [[ "$path" =~ "^${CONFIG_DIR}.*" ]] && return -1;
    local base=$(basename "$path")
    local name="${base%.*}"
    local ext="${base##*.}"

    local template="${name}-XXXXXXXXXX"
    if [ -n "$ext" ]; then
        template="${template}.${ext}"
    fi
    local tmp_file=$(mktemp --tmpdir "$template")

    cp "$path" "$tmp_file"
    $EDITOR "$tmp_file"

    if diff "$path" "$tmp_file" > /dev/null 2>&1; then
        # No changes were made
        rm "$tmp_file"
        return 0
    fi

    mv "$tmp_file" "$path"

    local input=""
    while true; do
        read -p "Apply changes to ${component}? [Y/n] " input
        input=$(printf "$input" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//")

        if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ]; then
            apply_component $component
            return 0
        elif [ "$input" = "n" ] || [ "$input" = "N" ]; then
            return 0
        fi

        printf "\nInvalid input; try again\n"
    done
}


function edit_dir() {
    local component="$1"
    local path="$2"
    [ ! -d "$path" ] || [[ "$path" =~ "^${CONFIG_DIR}.*" ]] && return -1;
    local name=$(basename "$path")
    local template="${name}-XXXXXXXXXX"
    local tmp_dir=$(mktemp -d --tmpdir "$template")

    cp -r "$path/." "$tmp_dir"
    $EDITOR "$tmp_dir"

    if diff -r "$path" "$tmp_dir" > /dev/null 2>&1; then
        # No changes were made
        rm -r "$tmp_dir"
        return 0
    fi

    rm -r "$path" # To ensure that deleted files don't stick around
    mv "$tmp_dir" "$path"

    local input=""
    while true; do
        read -p "Apply changes to ${component}? [Y/n] " input
        input=$(printf "$input" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//")

        if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ]; then
            apply_component $component
            return 0
        elif [ "$input" = "n" ] || [ "$input" = "N" ]; then
            return 0
        fi

        printf "\nInvalid input; try again\n"
    done
}


function action_edit() {
    for component in "${COMPONENTS[@]}"; do
        local cfg=$("$UTIL_DIR"/runComponent.sh $component get_var config_path)
        if [ -z "$cfg" ]; then
            printf "No config available for $component"
            continue
        fi
        cfg=$(realpath "$CONFIG_DIR/$cfg") # get rid of potential '..'s

        if [ -f "$cfg" ]; then
            edit_file $component "$cfg"
        elif [ -d "$cfg" ]; then
            edit_dir $component "$cfg"
        fi
    done
}


function apply_component() {
    "$UTIL_DIR"/runComponent.sh $1 install_config
}

function action_apply() {
    for component in "${COMPONENTS[@]}"; do
        apply_component $component
    done
}




while [ -n "$1" ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0;;
        *)
            if [ -z "$ACTION" ]; then
                ACTION="$1"
            else
                add_component "$1"
            fi;;
    esac
    shift
done


case "$ACTION" in
    edit)
        action_edit;;
    apply)
        action_apply;;
    *)
        printf "Invalid action: $ACTION\n"
        usage
        exit 1;;
esac
