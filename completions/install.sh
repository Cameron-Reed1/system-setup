#!/usr/bin/env bash


cd $(dirname $0)

sed "zsh/_manage" -e "s|__COMPONENT_DIR__|$HOME/system/components|" -e "s|__PATCH_DIR__|$HOME/system/patches|" | sudo tee "/usr/local/share/zsh/site-functions/_config" > /dev/null
sed "zsh/_manage" -e "s|__COMPONENT_DIR__|$HOME/system/components|" -e "s|__PATCH_DIR__|$HOME/system/patches|" | sudo tee "/usr/local/share/zsh/site-functions/_script" > /dev/null
sed "zsh/_setup_sh" -e "s|__COMPONENT_DIR__|$HOME/system/components|" | sudo tee "/usr/local/share/zsh/site-functions/_setup_sh" > /dev/null
