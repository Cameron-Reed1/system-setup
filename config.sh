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
    printf """Usage: $0 [action] [<component>..]

action: edit | apply | reset | show\n"""
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


function for_config_item() {
    local component="$1"
    local cb="$2"

    local config=$("$UTIL_DIR"/runComponent.sh $component get_var config)
    if [ -z "$config" ]; then
        printf "INFO: $component has no config defined\n"
        return 0
    fi

    local cfg_arr
    IFS=',' read -r -a cfg_arr <<< "$config"
    for entry in "${cfg_arr[@]}"; do
        local first="${entry%:*}"
        local second="${entry##*:}"

        case "$second" in
            /*)
                ;;
            ~/*)
                second=$(printf "$second" | sed -e "s|^~|$HOME|");;
            ~*)
                exit_with_err "Referencing other user's home directory is unsupported";;
            *)
                second="$XDG_CONFIG_HOME/$second";;
        esac

        first="$CONFIG_DIR/$first"

        "$cb" "$first" "$second"
    done
}


function edit_single() {
    local component="$1"
    local path="$2"
    [[ "$path" =~ "^${CONFIG_DIR}.*" ]] && return -1;
    local base=$(basename "$path")
    local name="${base%.*}"
    local ext="${base##*.}"

    local template="${name}-XXXXXXXXXX"
    if [ "$ext" != "$base" ]; then  # ext and name will both be $base if there is no .
        template="${template}.${ext}"
    fi

    local tmp
    if [ -f "$path" ]; then
        tmp=$(mktemp --tmpdir "$template")
    elif [ -d "$path" ]; then
        tmp=$(mktemp -d --tmpdir "$template")
    else
        return -1
    fi

    copy "$path" "$tmp"
    $EDITOR "$tmp"

    if diff -r "$path" "$tmp" > /dev/null 2>&1; then
        # No changes were made
        rm -r "$tmp"
        return 0
    fi

    copy "$tmp" "$path"
    rm -r "$tmp"

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

function edit_multiple() {
    local component="$1"

    local template="${component}-XXXXXXXXXX"
    local tmp_dir=$(mktemp -d --tmpdir "$template")

    function _cb1() {
        copy "$1" "$tmp_dir/$(basename "$1")"
    }
    for_config_item $component _cb1

    $EDITOR "$tmp_dir"

    local changed=0
    function _cb2() {
        if ! diff -r "$tmp_dir/$(basename "$1")" "$1" > /dev/null 2>&1; then
            changed=1
        fi
        copy "$tmp_dir/$(basename "$1")" "$1"
    }
    for_config_item $component _cb2

    rm -r "$tmp_dir"
    if [ "$changed" -eq 0 ]; then
        return 0;
    fi

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
        printf "Editing $component\n"
        local config=$("$UTIL_DIR"/runComponent.sh $component get_var config)
        if [ -z "$config" ]; then
            printf "No config available for $component\n"
            continue
        fi

        local cfg
        IFS="," read -r -a cfg <<< "$config"
        if [ "${#cfg[@]}" -eq 0 ]; then
            continue
        elif [ "${#cfg[@]}" -eq 1 ]; then
            local path="${cfg[0]}"
            path="${path%:*}"
            edit_single $component "$CONFIG_DIR/$path"
        else
            edit_multiple $component
        fi
    done
}


function apply_component() {
    function _cb() {
        copy "$1" "$2"
    }

    for_config_item $1 _cb
    "$UTIL_DIR"/runComponent.sh $1 manual_config
    "$UTIL_DIR"/runComponent.sh $1 post_config
}

function action_apply() {
    for component in "${COMPONENTS[@]}"; do
        apply_component $component
    done
}


function reset_component() {
    function _cb() {
        copy "$2" "$1"
    }

    for_config_item $1 _cb
}

function action_reset() {
    for component in "${COMPONENTS[@]}"; do
        reset_component $component
    done
}


function action_show() {
    for component in "${COMPONENTS[@]}"; do
        function _cb() {
            local first="$1"
            local second="$2"
            if diff "$first" "$second" > /dev/null 2>&1; then
                printf "\t$first -> $second\n"
            else
                printf "\t$first -> $second [diff]\n"
            fi
        }
        printf "$component:\n"
        for_config_item $component _cb
        printf "\n"
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
    reset)
        action_reset;;
    show)
        action_show;;
    *)
        printf "Invalid action: $ACTION\n"
        usage
        exit 1;;
esac
