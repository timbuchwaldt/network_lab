#/bin/bash -eu
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:brightbox/ruby-ng -y
sudo apt-get update
sudo apt-get install -yq ruby2.5 ruby2.5-dev bird bridge-utils
sudo gem2.5 install tmuxinator


cat <<EOF > /root/.tmux.conf
set -g mode-mouse on
set -g mouse-select-pane on
set -g mouse-select-window on
bind X confirm-before "kill-session -t ''"
EOF
