# Network Lab

This network lab provides an easy way to simulate complex networks. You can configure any topology of your liking in `generate.rb` and run it (it will probably currently complain about missing files, just create those until I cleaned it up).

You can then start a Vagrant VM (`vagrant up && vagrant ssh`). In there become root, switch to `/vagrant/` and run the included `setup.sh`.

Then you can run the `up.sh` script. This sets up the topology described in `generate.rb`. Using `tmuxinator start -p tmux.yaml` you get a shell into every defined router as well as running `bird` daemons and shells into each of those (mouse-mode in tmux is enabled so you can click the panes).

When you change anything on your topology you can use `CTRL-b X y` to exit the tmux session, then run `./down.sh && ./up.sh` to recreate the topology.

`generate.rb` also produces GraphViz: `ruby generate.rb && cat graph.dot|dot -Tpng -o out.png && open out.png`
