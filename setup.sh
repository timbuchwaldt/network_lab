#/bin/bash -eu
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:brightbox/ruby-ng -y
sudo apt-get update
sudo apt-get install -yq ruby2.5 ruby2.5-dev bird
sudo gem2.5 install tmuxinator
