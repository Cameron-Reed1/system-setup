#!/usr/bin/env bash


cd $(dirname $0)

sed "zsh/_config" -e "s|__COMPONENT_DIR__|$HOME/system/components|" | sudo tee "/usr/local/share/zsh/site-functions/_config" > /dev/null
