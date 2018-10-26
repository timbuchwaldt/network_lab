conf = {
	"routers": {
		"dus1r1": {
			"ip": "10.240.0.1/32",
			"connections": {"dus1r2": "172.16.0.1/24"}
		},
		"dus1r2": {
			"ip": "10.240.0.2/32",
			"connections": {"dus1r1": "172.16.0.2/24"}
		}
	}
}
File.truncate('up.sh', 0)

File.open("up.sh", 'a') do |file|
	# create routers
	file.puts "#/bin/bash -eu"
	conf[:routers].each do |name, config|
		file.puts "### ROUTER #{name}"
		file.puts "ip netns add #{name}"
		file.puts "ip netns exec #{name} ip link add name br0 type bridge"
		file.puts "ip netns exec #{name} ip link set up dev br0"
		# enable forwarding on all interfaces
		file.puts "ip netns exec #{name} bash -c 'for i in /proc/sys/net/ipv4/conf/*; do echo 1 > ${i}/forwarding; done'"
		file.puts "ip netns exec #{name} ip link set up dev lo"
		file.puts "ip netns exec #{name} ip addr add #{config[:ip]} dev lo"
	end

	created = []
	conf[:routers].each do |name, config|
		config[:connections].each do |peer, ip|
			link = "#{name}-#{peer}"
			unless created.include?(link)
				file.puts "ip link add #{link} type veth peer name #{peer}-#{name}"
				created << link
				created << "#{peer}-#{name}"
			end
			file.puts "ip link set #{link} netns #{name}"
			file.puts "ip netns exec #{name} ip link set up dev #{link}"
			file.puts "ip netns exec #{name} ip addr add #{ip} dev #{link}"
		end
	end
end

File.truncate('tmux.yaml', 0)
File.open("tmux.yaml", 'a') do |file|
	file.puts "name: netsim"
	file.puts "windows:"
	file.puts "  - shells:"
	file.puts "      panes:"
	conf[:routers].each do |name, config|
		file.puts "      - ip netns exec #{name} bash --init-file <(echo 'export PS1=#{name}:$PS1 && clear')"
	end
	file.puts "  - birds:"
	file.puts "      panes:"
	conf[:routers].each do |name, config|
		file.puts "      - bash -c 'ip netns exec #{name} bird -c /vagrant/config/#{name}/bird.conf -d -P /var/run/bird-#{name}.pid -s /var/run/bird-#{name}.ctl"
	end
end
