#!/usr/bin/env bash


export SETUP_DIR="${SETUP_DIR:-$(dirname "$(realpath "$0")")}"
export UTIL_DIR="${UTIL_DIR:-$SETUP_DIR/util}"
if [ ! -d "$UTIL_DIR" ]; then
    echo "\$UTIL_DIR must point to the util/ directory, but is set to $UTIL_DIR, which is not a directory"
    exit 255
fi
source "$UTIL_DIR/common"


ACTION=""
DEFAULT_EDITOR=""
COMPONENTS=()

if command -v nvim > /dev/null; then
    DEFAULT_EDITOR="nvim"
elif command -v vim > /dev/null; then
    DEFAULT_EDITOR="vim"
elif command -v vi > /dev/null; then
    DEFAULT_EDITOR="vi"
elif command -v nano > /dev/null; then
    DEFAULT_EDITOR="nano"
fi

EDITOR="${EDITOR:-$DEFAULT_EDITOR}"


function usage() {
    echo -e "Usage: $0 [action] [<component>..]\n\naction: edit | apply | reset | show"
}


function add_component() {
    valid_component "$1" || return
    [[ " ${COMPONENTS[*]} " =~ " $1 " ]] && return;
    COMPONENTS+=("$1")
}


function for_config_item() {
    local component="$1"
    local cb="$2"

    local config
    config=$("$UTIL_DIR"/runComponent.sh "$component" get_var config)
    if [ -z "$config" ]; then
        echo "INFO: $component has no config defined"
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
                second="${second/\~/$HOME}";;
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
    [[ "$path" =~ ^"${CONFIG_DIR}".* ]] || return 1;
    local base
    base=$(basename "$path")
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
        return 1
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
        read -r -p "Apply changes to ${component}? [Y/n] " input
        input=$(echo "$input" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//")

        if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ]; then
            apply_component "$component"
            return 0
        elif [ "$input" = "n" ] || [ "$input" = "N" ]; then
            return 0
        fi

        echo -e "\nInvalid input; try again"
    done
}

function edit_multiple() {
    local component="$1"

    local template="${component}-XXXXXXXXXX"
    local tmp_dir
    tmp_dir=$(mktemp -d --tmpdir "$template")

    function _cb1() {
        copy "$1" "$tmp_dir/$(basename "$1")"
    }
    for_config_item "$component" _cb1

    $EDITOR "$tmp_dir"

    local changed=0
    function _cb2() {
        if ! diff -r "$tmp_dir/$(basename "$1")" "$1" > /dev/null 2>&1; then
            changed=1
        fi
        copy "$tmp_dir/$(basename "$1")" "$1"
    }
    for_config_item "$component" _cb2

    rm -r "$tmp_dir"
    if [ "$changed" -eq 0 ]; then
        return 0;
    fi

    local input=""
    while true; do
        read -r -p "Apply changes to ${component}? [Y/n] " input
        input=$(echo "$input" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//")

        if [ -z "$input" ] || [ "$input" = "y" ] || [ "$input" = "Y" ]; then
            apply_component "$component"
            return 0
        elif [ "$input" = "n" ] || [ "$input" = "N" ]; then
            return 0
        fi

        echo -e "\nInvalid input; try again"
    done
}


function action_edit() {
    for component in "${COMPONENTS[@]}"; do
        echo "Editing $component"
        local config
        config=$("$UTIL_DIR"/runComponent.sh "$component" get_var config)
        if [ -z "$config" ]; then
            echo "No config available for $component"
            continue
        fi

        local cfg
        IFS="," read -r -a cfg <<< "$config"
        if [ "${#cfg[@]}" -eq 0 ]; then
            echo "No config available for $component"
            continue
        elif [ "${#cfg[@]}" -eq 1 ]; then
            local path="${cfg[0]}"
            path="${path%:*}"
            edit_single "$component" "$CONFIG_DIR/$path" || echo "Failed to edit config for $component"
        else
            edit_multiple "$component" || echo "Failed to edit config for $component"
        fi
    done
}


function apply_component() {
    function _cb() {
        copy "$1" "$2"
    }

    for_config_item "$1" _cb
    "$UTIL_DIR"/runComponent.sh "$1" manual_config
}

function action_apply() {
    for component in "${COMPONENTS[@]}"; do
        apply_component "$component"
    done
}


function reset_component() {
    function _cb() {
        copy "$2" "$1"
    }

    for_config_item "$1" _cb
}

function action_reset() {
    for component in "${COMPONENTS[@]}"; do
        reset_component "$component"
    done
}


function action_show() {
    for component in "${COMPONENTS[@]}"; do
        function _cb() {
            local first="$1"
            local second="$2"

            echo -e "\t$first -> $second"
            diff -r "$first" "$second"
        }
        echo "$component:"
        for_config_item "$component" _cb
        echo
    done
}


function valid_patch_name() {
    if [ -z "$1" ] || [[ "$1" =~ ' ' ]] || [[ "$1" =~ '/' ]]; then
        return 1
    fi
    return 0
}

function mkpatch_single() {
    local component="$1"
    local path="$2"
    local patch_name="$3"
    local base
    base=$(basename "$path")
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
        return 1
    fi

    copy "$path" "$tmp"
    $EDITOR "$tmp"

    mkdir -p "$PATCH_DIR/$component/"
    diff -Naru "$path" "$tmp" > "$PATCH_DIR/$component/$patch_name"

    rm -r "$tmp"
}

function mkpatch_multiple() {
    local component="$1"
    local patch_name="$2"

    local tmp_dir
    tmp_dir=$(mktemp -d --tmpdir "${component}-XXXXXXXXXX")

    function _cb1() {
        copy "$2" "$tmp_dir/$(basename "$1")"
    }
    for_config_item "$component" _cb1

    $EDITOR "$tmp_dir"

    mkdir -p "$PATCH_DIR/$component/"
    function _cb2() {
        diff -Naru "$2" "$tmp_dir/$(basename "$1")" >> "$PATCH_DIR/$component/$patch_name"
    }
    for_config_item "$component" _cb2

    rm -r "$tmp_dir"
}

function action_mkpatch() {
    local component="$1"
    local patch_name="$2"

    valid_component "$component" || exit 255
    valid_patch_name "$patch_name" || exit_with_err "Invalid patch name: \"$patch_name\""

    local config
    config=$("$UTIL_DIR"/runComponent.sh "$component" get_var config)
    if [ -z "$config" ]; then
        echo "No config available for $component"
        return
    fi

    local cfg
    IFS="," read -r -a cfg <<< "$config"
    if [ "${#cfg[@]}" -eq 0 ]; then
        return
    elif [ "${#cfg[@]}" -eq 1 ]; then
        local path
        function _cb() {
            path="$2"
        }
        for_config_item "$component" _cb
        mkpatch_single "$component" "$path" "$patch_name"
    else
        mkpatch_multiple "$component" "$patch_name"
    fi
}

function action_patch() {
    local component="$1"
    local patch_name="$2"

    valid_component "$component" || exit 255
    valid_patch_name "$patch_name" || exit_with_err "Invalid patch name: \"$patch_name\""

    patch -d / -r - -p1 < "$PATCH_DIR/$component/$patch_name"
}

function action_unpatch() {
    local component="$1"
    local patch_name="$2"

    valid_component "$component" || exit 255
    valid_patch_name "$patch_name" || exit_with_err "Invalid patch name: \"$patch_name\""

    patch -R -d / -r - -p1 < "$PATCH_DIR/$component/$patch_name"
}


function add_components() {
    while [ -n "$1" ]; do
        case "$1" in
            -*)
                exit_with_err "Unknown argument: $1";;
            *)
                add_component "$1";;
        esac
        shift
    done
}

function parse_arguments() {
    while [ -z "$ACTION" ] && [ -n "$1" ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0;;
            -*)
                exit_with_err "Unknown argument: $1";;
            *)
                ACTION="$1";;
        esac
        shift
    done

    case "$ACTION" in
        edit|apply|reset|show)
            add_components "$@";;
        mkpatch|patch|unpatch)
            ;;
        *)
            echo "Invalid action: [$ACTION]"
            usage
            exit 1;;
    esac
}


parse_arguments "$@"
case "$ACTION" in
    edit)
        action_edit;;
    apply)
        action_apply;;
    reset)
        action_reset;;
    show)
        action_show;;
    mkpatch)
        action_mkpatch "${@:2}";;
    patch)
        action_patch "${@:2}";;
    unpatch)
        action_unpatch "${@:2}";;
    *)
        echo "Invalid action: $ACTION"
        usage
        exit 1;;
esac
