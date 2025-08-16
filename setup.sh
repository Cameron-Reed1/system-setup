#!/usr/bin/env bash


export SETUP_DIR="${SETUP_DIR:-$(dirname $(realpath $0))}"
export UTIL_DIR="${UTIL_DIR:-$SETUP_DIR/util}"
if [ ! -d "$UTIL_DIR" ]; then
    printf "\$UTIL_DIR must point to the util/ directory, but is set to $UTIL_DIR, which is not a directory"
    exit -1
fi
source "$UTIL_DIR/common"


COMPONENTS=()
DEPENDENCIES=()

RUN_INSTALL_STEP=0
RUN_CONFIG_STEP=0


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


function add_dependency() {
    if [[ "$1" =~ ' ' ]]; then
        exit_with_err "Invalid component name: '$1' contains a space"
    fi

    [[ " ${COMPONENTS[@]} " =~ " $1 " ]] && return;
    [[ " ${DEPENDENCIES[@]} " =~ " $1 " ]] && return;
    if [ ! -f "$COMPONENT_DIR/$1" ]; then
        printf "$1 component does not exist\n"
        return
    fi
    DEPENDENCIES+=($1)

    deps=$("$UTIL_DIR"/runComponent.sh $1 get_var dependencies)
    if [ -n "$deps" ]; then
        for dep in $deps; do
            add_dependency $dep
        done
    fi
}


function find_dependencies() {
    for component in "${COMPONENTS[@]}"; do
        local deps=$("$UTIL_DIR"/runComponent.sh $component get_var dependencies)
        if [ -n "$deps" ]; then
            for dep in $deps; do
                add_dependency $dep
            done
        fi
    done
}


function install_packages() {
    local all_components=()
    local packages=()

    for component in "${COMPONENTS[@]}"; do
        all_components+=($component)
    done
    for component in "${DEPENDENCIES[@]}"; do
        all_components+=($component)
    done

    function add_package() {
        if [[ "$@" =~ ' ' ]]; then
            for pkg in "$@"; do add_package $pkg; done
        fi

        [[ " ${packages[@]} " =~ " $1 " ]] && return;
        pacman -Q $1 > /dev/null && return
        packages+=($1)
    }

    for component in "${all_components[@]}"; do
        pkgs=$("$UTIL_DIR"/runComponent.sh $component get_var packages)
        if [ -n "$pkgs" ]; then
            for pkg in $pkgs; do add_package $pkg; done
        fi
    done

    if [ -n "${packages[*]}" ]; then
        sudo pacman -S --needed --noconfirm ${packages[*]}
    fi

    for component in "${all_components[@]}"; do
        "$UTIL_DIR"/runComponent.sh $component post_install
    done

    for component in "${all_components[@]}"; do
        "$UTIL_DIR"/runComponent.sh $component manual_install
    done
}


function install_configs() {
    for component in "${COMPONENTS[@]}"; do
        "$UTIL_DIR"/runComponent.sh $component install_config
    done
}


function usage() {
    printf """Usage: $0 [steps] [<component>...]

Steps:
    --packages
    --config
    --full\n"""
    exit 0
}


function parse_opts() {
    while [ -n "$1" ]; do
        case "$1" in
            --install|--packages)
                RUN_INSTALL_STEP=1;;
            --config)
                RUN_CONFIG_STEP=1;;
            --full)
                RUN_INSTALL_STEP=1
                RUN_CONFIG_STEP=1;;
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
find_dependencies

printf "RUN_INSTALL_STEP: $RUN_INSTALL_STEP\nRUN_CONFIG_STEP: $RUN_CONFIG_STEP\nCOMPONENTS: ${COMPONENTS[*]}\nDEPENDENCIES: ${DEPENDENCIES[*]}\n\n"

if [ "$RUN_INSTALL_STEP" -eq 1 ]; then
    install_packages
fi

if [ "$RUN_CONFIG_STEP" -eq 1 ]; then
    install_configs
fi
