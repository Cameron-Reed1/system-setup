#!/usr/bin/env bash


export SETUP_DIR="${SETUP_DIR:-$(dirname "$(realpath "$0")")}"
export UTIL_DIR="${UTIL_DIR:-$SETUP_DIR/util}"
if [ ! -d "$UTIL_DIR" ]; then
    echo "\$UTIL_DIR must point to the util/ directory, but is set to $UTIL_DIR, which is not a directory"
    exit 1
fi
source "$UTIL_DIR/common"


COMPONENTS=()


function add_component() {
    if [[ "$1" =~ ' ' ]]; then
        exit_with_err "Invalid component name: '$1' contains a space"
    fi

    [[ " ${COMPONENTS[*]} " =~ " $1 " ]] && return;
    if [ ! -f "$COMPONENT_DIR/$1" ]; then
        echo "$1 component does not exist"
        return
    fi
    COMPONENTS+=("$1")

    deps=$("$UTIL_DIR"/runComponent.sh "$1" get_var dependencies)
    if [ -n "$deps" ]; then
        for dep in $deps; do
            add_component "$dep"
        done
    fi
}


function install_packages() {
    local packages=()

    function add_package() {
        if [[ "$*" =~ ' ' ]]; then
            for pkg in "$@"; do add_package "$pkg"; done
        fi

        [[ " ${packages[*]} " =~ " $1 " ]] && return;
        pacman -Q "$1" > /dev/null && return
        packages+=("$1")
    }

    for component in "${COMPONENTS[@]}"; do
        pkgs=$("$UTIL_DIR"/runComponent.sh "$component" get_var packages)
        if [ -n "$pkgs" ]; then
            for pkg in $pkgs; do add_package "$pkg"; done
        fi
    done

    if [ -n "${packages[*]}" ]; then
        sudo pacman -S --needed --noconfirm "${packages[@]}"
    fi

    for component in "${COMPONENTS[@]}"; do
        "$UTIL_DIR"/runComponent.sh "$component" manual_install
    done

    for component in "${COMPONENTS[@]}"; do
        "$UTIL_DIR"/runComponent.sh "$component" post_install
    done
}


function install_configs() {
    "$SETUP_DIR"/config.sh apply "${COMPONENTS[@]}"
}


function usage() {
    echo "Usage: $0 [<component>...]"
    exit 0
}


function parse_opts() {
    while [ -n "$1" ]; do
        case "$1" in
            -h|--help)
                usage;;
            -*)
                exit_with_err "Invalid option $1";;
            *)
                add_component "$1";;
        esac
        shift
    done

    if [ -z "${COMPONENTS[*]}" ]; then
        add_component "default"
    fi
}


parse_opts "$@"

echo -e "COMPONENTS: ${COMPONENTS[*]}\n\n"

install_packages
install_configs
