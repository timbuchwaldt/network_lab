# RFC 3849: 2001:DB8::/32 for docs

conf = {
	routers: {
		dus1r1: {
			loopback_ip: "10.240.0.1/32",
			loopback_ip6: "2001:DB8::103:1/127",
      connections: {dus1r2: {ip: "172.16.0.1/24"}, dus1sw1: {ip: "192.168.27.2/24", latency: "50ms"}, fra1r1: {ip: "172.16.1.2/24"}},
			features: [:bird],
		},
		fra1r1: {
			loopback_ip: "10.240.0.3/32",
			loopback_ip6: "2001:DB8::102:1/127",
			connections: {dus1r1: {ip: "172.16.1.1/24"}},
			features: [:bird],
		},
		dus1r2: {
			loopback_ip: "10.240.0.2/32",
			loopback_ip6: "2001:DB8::103:2/128",
			connections: {dus1r1: {ip: "172.16.0.2/24"}, dus1sw2: {ip: "192.168.27.1/24", latency: "23ms"}},
			features: [:bird],
		}
	},
	switches: {
		dus1sw1: {connections: {dus1r1: {}, dus1sw2: {latency: "5ms"}}},
		dus1sw2: {connections: {dus1r2: {}, dus1sw1: {}}},
	}
}


File.truncate('up.sh', 0)

File.open("up.sh", 'a') do |file|
	# create routers
	file.puts "#/bin/bash -eu"
	conf[:routers].each do |name, config|
		file.puts "### ROUTER #{name}"
		file.puts "ip netns add #{name}"
		# enable forwarding on all interfaces
		file.puts "ip netns exec #{name} bash -c 'for i in /proc/sys/net/ipv4/conf/*; do echo 1 > ${i}/forwarding; done'"
		file.puts "ip netns exec #{name} ip link set up dev lo"
		file.puts "ip netns exec #{name} ip addr add #{config[:loopback_ip]} dev lo"
		file.puts "ip netns exec #{name} ip -6 addr add #{config[:loopback_ip6]} dev lo"
	end
	conf[:switches].each do |name, config|
		file.puts "### SWITCH #{name}"
		file.puts "ip netns add #{name}"
		# create bridge
		file.puts "ip netns exec #{name} ip link add name br0 type bridge"
		file.puts "ip netns exec #{name} ip link set up dev br0"
		# enable forwarding on all interfaces
	end

	created = []
	conf[:routers].each do |name, router_config|
		router_config[:connections].each do |peer, config|
			link = "#{name}-#{peer}"
			unless created.include?(link)
				file.puts "ip link add #{link} type veth peer name #{peer}-#{name}"
				created << link
				created << "#{peer}-#{name}"
			end
			file.puts "ip link set #{link} netns #{name}"
			file.puts "ip netns exec #{name} ip link set up dev #{link}"
			file.puts "ip netns exec #{name} ip addr add #{config[:ip]} dev #{link}"
			if config[:latency]
				file.puts "ip netns exec #{name} tc qdisc add dev #{link} root netem delay #{config[:latency]}"
			end
		end
	end


	conf[:switches].each do |name, switch_config|
		switch_config[:connections].each do |peer, config|
			link = "#{name}-#{peer}"
			unless created.include?(link)
				file.puts "ip link add #{link} type veth peer name #{peer}-#{name}"
				created << link
				created << "#{peer}-#{name}"
			end
			file.puts "ip link set #{link} netns #{name}"
			file.puts "ip netns exec #{name} ip link set up dev #{link}"
			file.puts "ip netns exec #{name} ip link set #{link} master br0"
			if config[:latency]
				file.puts "ip netns exec #{name} tc qdisc add dev #{link} root netem delay #{config[:latency]}"
			end
		end
	end

end

File.truncate('tmux.yaml', 0)
File.open("tmux.yaml", 'a') do |file|
	file.puts "name: netsim"
	file.puts "windows:"
	file.puts "  - shells:"
	file.puts "      layout: tiled"
	file.puts "      panes:"
	conf[:routers].each do |name, config|
		file.puts "      - ip netns exec #{name} bash --init-file <(echo 'export PS1=#{name}:$PS1 && clear')"
	end
	file.puts "  - bird-clients:"
	file.puts "      layout: tiled"
	file.puts "      panes:"
	conf[:routers].each do |name, config|
		if config[:features].include?(:bird)
			file.puts "      - bash -c 'sleep 1 && ip netns exec #{name} birdc -s /var/run/bird-#{name}.ctl'"
		end
	end
	file.puts "  - bird-daemon:"
	file.puts "      panes:"
	conf[:routers].each do |name, config|
		if config[:features].include?(:bird)
			file.puts "      - bash -c 'ip netns exec #{name} bird -c /vagrant/config/#{name}/bird.conf -d -P /var/run/bird-#{name}.pid -s /var/run/bird-#{name}.ctl'"
		end
	end
end
