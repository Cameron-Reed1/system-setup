#!/usr/bin/env bash


case $(basename "$0") in
    config|config.sh)
        SUB_CMD="config";;
    script|script.sh)
        SUB_CMD="script";;
    *)
        SUB_CMD="$1"
        shift;;
esac

if [ "$SUB_CMD" != "config" ] && [ "$SUB_CMD" != "script" ]; then
    echo "Invalid sub command '$SUB_CMD'" >&2
    exit 1
fi


export SETUP_DIR="${SETUP_DIR:-$(dirname "$(realpath "$0")")}"
export UTIL_DIR="${UTIL_DIR:-$SETUP_DIR/util}"
if [ ! -d "$UTIL_DIR" ]; then
    echo "\$UTIL_DIR must point to the util/ directory, but is set to $UTIL_DIR, which is not a directory"
    exit 255
fi
source "$UTIL_DIR/common"

if [ "$SUB_CMD" = "config" ]; then
    SUB_CMD_VAR="config"
    LOCAL_BASE_DIR="$CONFIG_DIR"
    SYSTEM_BASE_DIR="$XDG_CONFIG_HOME"
else
    SUB_CMD_VAR="scripts"
    LOCAL_BASE_DIR="$EXTRAS_DIR/scripts"
    SYSTEM_BASE_DIR="$HOME/scripts"
fi


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
    case $(basename "$0") in
        config|config.sh|script|script.sh)
            echo -e "Usage: $0 [action] [<component>..]\n\naction: edit | apply | reset | show";;
        *)
            echo -e "Usage: $0 [sub_cmd] [action] [<component>..]\n\nsub_cmd: config | script\naction: edit | apply | reset | show";;
    esac
}


function add_component() {
    valid_component "$1" || return
    [[ " ${COMPONENTS[*]} " =~ " $1 " ]] && return;
    COMPONENTS+=("$1")
}


function for_each_entry() {
    local component="$1"
    local cb="$2"

    local entries_str
    entries_str=$("$UTIL_DIR"/runComponent.sh "$component" get_var "$SUB_CMD_VAR")
    if [ -z "$entries_str" ]; then
        echo "INFO: $component has no $SUB_CMD_VAR defined"
        return 0
    fi

    local entries
    IFS=',' read -r -a entries <<< "$entries_str"
    for entry in "${entries[@]}"; do
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
                second="$SYSTEM_BASE_DIR/$second";;
        esac

        first="$LOCAL_BASE_DIR/$first"

        "$cb" "$first" "$second"
    done
}


function edit_single() {
    local component="$1"
    local path="$2"
    [[ "$path" =~ ^"${LOCAL_BASE_DIR}".* ]] || return 1;
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
    for_each_entry "$component" _cb1

    $EDITOR "$tmp_dir"

    local changed=0
    function _cb2() {
        if ! diff -r "$tmp_dir/$(basename "$1")" "$1" > /dev/null 2>&1; then
            changed=1
        fi
        copy "$tmp_dir/$(basename "$1")" "$1"
    }
    for_each_entry "$component" _cb2

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
        local entries_str
        entries_str=$("$UTIL_DIR"/runComponent.sh "$component" get_var "$SUB_CMD_VAR")
        if [ -z "$entries_str" ]; then
            echo "No $SUB_CMD_VAR available for $component"
            continue
        fi

        local entries
        IFS="," read -r -a entries <<< "$entries_str"
        if [ "${#entries[@]}" -eq 0 ]; then
            echo "No $SUB_CMD_VAR available for $component"
            continue
        elif [ "${#entries[@]}" -eq 1 ]; then
            local path="${entries[0]}"
            path="${path%:*}"
            edit_single "$component" "$LOCAL_BASE_DIR/$path" || echo "Failed to edit $SUB_CMD_VAR for $component"
        else
            edit_multiple "$component" || echo "Failed to edit $SUB_CMD_VAR for $component"
        fi
    done
}


function apply_component() {
    function _cb() {
        copy "$1" "$2"
        if [ "$SUB_CMD" = "script" ]; then
            chmod 755 "$2"
        fi
    }

    for_each_entry "$1" _cb
    if [ "$SUB_CMD" = "config" ]; then
        "$UTIL_DIR"/runComponent.sh "$1" manual_config
        "$UTIL_DIR"/runComponent.sh "$1" reload_config
    fi
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

    for_each_entry "$1" _cb
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
        for_each_entry "$component" _cb
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
    for_each_entry "$component" _cb1

    $EDITOR "$tmp_dir"

    mkdir -p "$PATCH_DIR/$component/"
    function _cb2() {
        diff -Naru "$2" "$tmp_dir/$(basename "$1")" >> "$PATCH_DIR/$component/$patch_name"
    }
    for_each_entry "$component" _cb2

    rm -r "$tmp_dir"
}

function action_mkpatch() {
    local component="$1"
    local patch_name="$2"

    valid_component "$component" || exit 255
    valid_patch_name "$patch_name" || exit_with_err "Invalid patch name: \"$patch_name\""

    local entries_str
    entries_str=$("$UTIL_DIR"/runComponent.sh "$component" get_var "$SUB_CMD_VAR")
    if [ -z "$entries_str" ]; then
        echo "No $SUB_CMD_VAR available for $component"
        return
    fi

    local entries
    IFS="," read -r -a entries <<< "$entries_str"
    if [ "${#entries[@]}" -eq 0 ]; then
        return
    elif [ "${#entries[@]}" -eq 1 ]; then
        local path
        function _cb() {
            path="$2"
        }
        for_each_entry "$component" _cb
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
