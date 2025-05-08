#!/usr/bin/env bash


if [ -n "$TRACE" ]; then
    set -x
fi
set -o pipefail
export SHELLOPTS


export SETUP_DIR=${SETUP_DIR:-$(dirname $(realpath $0))}
export COMPONENT_DIR="${COMPONENT_DIR:-$SETUP_DIR/components}"
export CONFIG_DIR="${CONFIG_DIR:-$SETUP_DIR/config}"
export EXTRAS_DIR="${EXTRAS_DIR:-$SETUP_DIR/extras}"

function exit_with_err() {
    printf "$(caller | awk '{print $NF}'): $@\n" >&2
    exit -1
}

function install_aur_pkg() {
    if pacman -Q $1 > /dev/null; then
        return
    fi

    if [ -d $HOME/builds/$1 ]; then
        printf "Build directory for $1 already exists. Skipping installation\n"
        return
    fi
    mkdir -p $HOME/builds

    git clone https://aur.archlinux.org/$1.git $HOME/builds/$1
    ${EDITOR:-vim} $HOME/builds/$1/PKGBUILD
    read -p "Install $1? [y/N]: "

    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
        cd $HOME/builds/$1
        makepkg -ic
        cd -
    fi
}
export -f exit_with_err
export -f install_aur_pkg


COMPONENTS=()

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

    deps=$(./runComponent.sh $1 get_var dependencies)
    if [ -n "$deps" ]; then
        for dep in $deps; do
            add_component $dep
        done
    fi
}


function install_packages() {
    packages=()

    function add_package() {
        if [[ "$@" =~ ' ' ]]; then
            for pkg in "$@"; do add_package $pkg; done
        fi

        [[ " ${packages[@]} " =~ " $1 " ]] && return;
        pacman -Q $1 > /dev/null && return
        packages+=($1)
    }

    for component in "${COMPONENTS[@]}"; do
        pkgs=$(./runComponent.sh $component get_var packages)
        if [ -n "$pkgs" ]; then
            for pkg in $pkgs; do add_package $pkg; done
        fi
    done

    if [ -n "${packages[*]}" ]; then
        sudo pacman -S --needed --noconfirm ${packages[*]}
    fi

    for component in "${COMPONENTS[@]}"; do
        ./runComponent.sh $component post_install
    done

    for component in "${COMPONENTS[@]}"; do
        ./runComponent.sh $component manual_install
    done
}

function install_configs() {
    for component in "${COMPONENTS[@]}"; do
        ./runComponent.sh $component install_config
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
    printf "RUN_INSTALL_STEP: $RUN_INSTALL_STEP\nRUN_CONFIG_STEP: $RUN_CONFIG_STEP\nCOMPONENTS: ${COMPONENTS[*]}\n"
}

parse_opts "$@"

if [ "$RUN_INSTALL_STEP" -eq 1 ]; then
    install_packages
fi

if [ "$RUN_CONFIG_STEP" -eq 1 ]; then
    install_configs
fi
