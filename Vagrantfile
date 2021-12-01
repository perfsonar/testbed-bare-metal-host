#
# Vagrantfile for perfSONAR Testbed Hosts
#

# Configuration lives in config.yaml

# -----------------------------------------------------------------------------

# No user-serviceable parts below this line.

require 'netaddr'
require 'yaml'

#
# Configuration
#

$config =    YAML.load(File.read("config.yaml"))
$config["testbed"] = YAML.load(File.read("testbeds/#{$config["testbed"]}.yaml"))

def get_with_default(config_bits, param)
  if config_bits == nil
    config_bits = {}
  end
  return config_bits.fetch(param, $config["defaults"].fetch(param, nil))
end



#
# VMs
#

# TODO: Disable VirtualBox guest extensions.  VMs don't need them.

Vagrant.configure("2") do |vc|

  vc.vm.provider "virtualbox" do |vbox|
    # The default E1000 has a security vulnerability.
    # TODO: This doesn't seem to have any effect.
    vbox.default_nic_type = "82543GC"
  end


  # The fisrt iteration will bump this to zero

  $hosts = $config.fetch("hosts", {}).to_a

  abort "No hosts defined in configuration" unless $hosts.length > 0

  # NB: Don't iterate over $hosts as a hash because it's lazy loaded.
  (0..$hosts.length-1).each do |host_number|

    host_name, host_config = $hosts[host_number]

    # Skip machines but preserve host numbering.
    next if get_with_default(host_config, "skip")

    vc.vm.define host_name do |host|

      # Don't allow upgrades to the VBox extensions.  The box has what
      # it has.
      if Vagrant.has_plugin?("vagrant-vbguest")
        host.vbguest.auto_update = false
      end

      host.vm.provider "virtualbox" do |vbox|
        # The default E1000 has a security vulnerability.
        vbox.default_nic_type = "82543GC"
        vbox.cpus = get_with_default(host_config, "cpus")
        vbox.memory = get_with_default(host_config, "memory")
      end

      host.vm.box = get_with_default(host_config, "box")
      if $config["testbed"].key?("domain")
        host.vm.hostname = "#{host_name}.#{$config["testbed"]["domain"]}"
      else
        host.vm.hostname = host_name
      end


      #
      # Network
      #

      route_table_base = 10
      route_table_num = route_table_base

      $config["testbed"]["net"].each do |key, value|
    
        host_if = value["bridge"]
        guest_if = key
        vc.vm.network "public_network", bridge: host_if, auto_config: false
    
        host.vm.provision "network-route-flush-#{guest_if}-#{route_table_num}", type: "shell", run: "once", inline: <<-SHELL
          ip route flush table #{route_table_num}
        SHELL
    
        [ 4, 6 ].each do |family|
    
          net_entry = value["ip"][family]
          next if net_entry == nil
    
          block = net_entry["block"]
          next if block == nil
    
          case family
          when 4
            net = NetAddr::IPv4Net.parse("#{block}")
          when 6
            net = NetAddr::IPv6Net.parse(block)
          else
            raise "Internal error: Unknown IP family #{family}"
          end
    
          # Addressing

          address_number = host_number + net_entry["base"]

          if address_number > (net.len - 2)
              if net.len > 0
                abort "Too many hosts for #{block}"
              else
                warn "Netblock #{block} is too large to validate host number.  Proceeding."
              end
          end
          
          addr = net.nth(address_number)

          host.vm.provision "network-#{guest_if}-ipv#{family}", type: "shell", run: "once", inline: <<-SHELL
            ip -#{family} address replace #{addr}#{net.netmask} dev #{guest_if}
            ip -#{family} address show dev #{guest_if}
          SHELL
    
          # Default Routes (later entries override earlier ones)
    
          default = net_entry["default"]
          next if default == nil
    
          host.vm.provision "network-routing-#{guest_if}-ipv#{family}", type: "shell", run: "once", inline: <<-SHELL
    
            defroute()
            {
                ip -#{family} route list table #{route_table_num} | egrep -e '^default '
            }
            OLD_DEFAULT=$(defroute)
            if [ -n "${OLD_DEFAULT}" ]
            then
                echo "Replacing existing default route ${OLD_DEFAULT}"
                ip -#{family} route del default table #{route_table_num}
            fi
    
            # Traffic sourced from this interface goes out the same way.
            ip -#{family} route add default via "#{default}" dev "#{guest_if}" table #{route_table_num}
            ip -#{family} rule add from #{addr} table #{route_table_num}
    
            # The global default route is via the first interface.
            if [ "#{route_table_num}" -eq "#{route_table_base}" ]
            then
                ip -#{family} route list | egrep -e '^default ' \
                  && ip -#{family} route del default
                ip -#{family} route add default via "#{default}" dev "#{guest_if}"
                echo "Global IPv#{family} default route via #{default} on #{guest_if}"
            fi
          SHELL
    
        end  # [ 4, 6 ].each do |family|

      end  # $config["testbed"].each do |key, value|

      host.vm.provision "hosts-scrub", type: "shell", run: "once", inline: <<-SHELL
        sed -i -e '/#{host.vm.hostname}/d' /etc/hosts
      SHELL


      #
      # perfSONAR
      #
      # TODO: Replace this with Ansible, which can detect Debian
      #

      host.vm.provision "perfSONAR", type:"shell", run: "once", inline: <<-SHELL

        set -e

        if [ ! -e "/etc/redhat-release" ]
        then
          echo "Only CentOS is supported at this time." 1>&2
          exit 1
        fi
 
        YUMMY="yum -y"
 
        ${YUMMY} install epel-release
        echo INST
        ${YUMMY} install "#{$config["perfsonar-repo"]}"
        echo DONE
 
        echo "Build config is #{host_config["repository"]}"
 
        case "#{host_config["repository"]}" in
          production)
            true  # Nothing to do here.
            ;;
          nightly-patch|nightly-minor|staging)
            ${YUMMY} install "perfSONAR-repo-#{host_config["repository"]}"
            ;;
          *)
            echo "Unknown repository '#{host_config["repository"]}'" 1>&2
            exit 1
        esac
 
        ${YUMMY} clean all
        ${YUMMY} update
        ${YUMMY} install perfsonar-toolkit
 
        # Disable SSH root login
        sed -i -e 's/PermitRootLogin.*$/PermitRootLogin no/g' /etc/ssh/sshd_config
        systemctl restart sshd

	# Install self-updating limit configuration
        ${YUMMY} install git
	git clone https://github.com/perfsonar/perfsonar-dev-mesh.git
	make -C perfsonar-dev-mesh/pscheduler install
	rm -rf perfsonar-dev-mesh

      SHELL

      #
      # Join the test meshes
      #

      # TODO: This appears to run for every host instead of just this one.

      meshes = get_with_default(host_config, "meshes")
      get_with_default(host_config, "meshes").each do |mesh|
        host.vm.provision "#{host_name}-mesh-#{mesh}", type: "shell", run: "once", inline: <<-SHELL
          psconfig remote --configure-archives add "#{mesh}"
        SHELL
      end

      if meshes.length > 0
        host.vm.provision "#{host_name}-psconfig-reload", type: "shell", run: "once", inline: <<-SHELL
          systemctl restart psconfig-pscheduler-agent
        SHELL
      end

    end  # vc.vm.define name

  end  # $config["hosts"].each

end  # Vagrant.configure("2") do |vc|


# -*- mode: ruby -*-
# vi: set ft=ruby :
