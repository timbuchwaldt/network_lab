# RFC 3849: 2001:DB8::/32 for docs

conf = {
	routers: {
		dus1r1: {
			loopback_ip: "10.240.0.1/32",
			loopback_ip6: "2001:DB8::103:1/127",
			features: [:bird],
		},
		fra1r1: {
			loopback_ip: "10.240.0.3/32",
			loopback_ip6: "2001:DB8::102:1/127",
			features: [:bird],
		},
		dus1r2: {
			loopback_ip: "10.240.0.2/32",
			loopback_ip6: "2001:DB8::103:2/128",
			features: [:bird],
		}
	},
	switches: {
		dus1sw1: {},
		dus1sw2: {},
	},
	wires: [
		{
			a: "dus1r1",
			b: "dus1r2",
			a_ip: ["172.16.0.1/24", "2001:DB8:fefe::1/64"],
			b_ip: ["172.16.0.2/24", "2001:DB8:fefe::2/64"],
		},
		{
			a: "dus1r1",
			b: "dus1sw1",
			a_ip: ["192.168.27.2/24"],
		},
		{
			a: "dus1r2",
			b: "dus1sw2",
			a_ip: ["192.168.27.1/24"],
		},
		{
			a: "dus1r1",
			b: "fra1r1",
			a_ip: ["172.16.1.1/24"],
			b_ip: ["172.16.1.2/24"],
			latency: "20ms"
		},
		{
			a: "dus1sw1",
			b: "dus1sw2"
		}
	]
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

	conf[:wires].each do |wire|
		a = wire[:a]
		b = wire[:b]

		a_b = a + "_" + b
		b_a = b + "_" + a

		file.puts "ip link add #{a_b} type veth peer name #{b_a}"

		file.puts "ip link set #{a_b} netns #{a}"
		file.puts "ip link set #{b_a} netns #{b}"

		file.puts "ip netns exec #{a} ip link set up dev #{a_b}"
		file.puts "ip netns exec #{b} ip link set up dev #{b_a}"

		if wire[:a_ip]
			wire[:a_ip].each do |ip|
				file.puts "ip netns exec #{a} ip addr add #{ip} dev #{a_b}"
			end
		elsif conf[:switches][wire[:b].to_sym]
			# a side is a switch, add interface to bridge
			file.puts "ip netns exec #{a} ip link set #{a_b} master br0"
		end

		if wire[:b_ip]
			wire[:b_ip].each do |ip|
				file.puts "ip netns exec #{b} ip addr add #{ip} dev #{b_a}"
			end
		elsif conf[:switches][wire[:b].to_sym]
			# b side is a switch, add interface to bridge
			file.puts "ip netns exec #{b} ip link set #{b_a} master br0"
		end

		if wire[:latency]
			file.puts "ip netns exec #{a} tc qdisc add dev #{a_b} root netem delay #{wire[:latency]}"
			file.puts "ip netns exec #{b} tc qdisc add dev #{b_a} root netem delay #{wire[:latency]}"
		end
	end

	file.puts """
	cat <<EOF > /etc/hosts
127.0.0.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
	"""
	conf[:routers].each do |name, router_config|
		file.puts "#{router_config[:loopback_ip].split('/')[0]} #{name}"
		file.puts "#{router_config[:loopback_ip6].split('/')[0]} #{name}"
	end
file.puts "EOF"
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

File.truncate('graph.dot', 0)
File.open("graph.dot", 'a') do |file|
	file.puts "strict graph {"
	conf[:wires].each do |wire|
		if wire[:latency]
			file.puts "#{wire[:a]} -- #{wire[:b]}[label=\"#{wire[:latency]}\"]"
		else
			file.puts "#{wire[:a]} -- #{wire[:b]}"
		end
	end
	file.puts "}"

end
