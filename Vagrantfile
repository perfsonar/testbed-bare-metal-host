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

$config = YAML.load(File.read("config.yaml"))

def get_with_default(config_bits, param)
  if config_bits == nil
    config_bits = {}
  end
  return config_bits.fetch(param, $config["defaults"].fetch(param, nil))
end


$box_interfaces = YAML.load(File.read("box-interfaces.yaml"))


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
      domain = get_with_default(host_config, "domain")

      if $domain != nil
        host.vm.hostname = "#{host_name}.#{$config["defaults"]["domain"]}"
      else
        host.vm.hostname = host_name
      end


      #
      # Network
      #

      route_table_base = 10
      route_table_num = route_table_base

      $config["net"].each_with_index do |value, index|
    
        host_if = value["bridge"]
        guest_if = $box_interfaces[host.vm.box][index]
        if guest_if == nil
          abort("Unable for find interface #{index} on #{host.vm.box}")
        end
        vc.vm.network "public_network", bridge: host_if, auto_config: false
    
        host.vm.provision "network-route-flush-#{guest_if}-#{route_table_num}", type: "shell", run: "once", inline: <<-SHELL
          if ip rule list | cut -d: -f1 | fgrep -q -x "#{route_table_num}"
          then
              ip route flush table #{route_table_num}
          fi
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
    
          gateway = net_entry["gateway"]
          next if gateway == nil
    
          host.vm.provision "network-routing-#{guest_if}-ipv#{family}", type: "shell", run: "once", inline: <<-SHELL

            # TODO: This doesn't make the changes permanent across reboots.
    
            defroute()
            {
                ip -#{family} route list table #{route_table_num} | egrep -e '^default '
            }
            OLD_GATEWAY=$(defroute)
            if [ -n "${OLD_GATEWAY}" ]
            then
                echo "Replacing existing default route ${OLD_GATEWAY}"
                ip -#{family} route del default table #{route_table_num}
            fi
    
            # Traffic sourced from this interface goes out the same way.
            ip -#{family} route add default via "#{gateway}" dev "#{guest_if}" table #{route_table_num}
            ip -#{family} rule add from #{addr} table #{route_table_num}
    
            # The global default route is via the first interface.
            if [ "#{route_table_num}" -eq "#{route_table_base}" ]
            then
                ip -#{family} route list | egrep -e '^default ' \
                  && ip -#{family} route del default
                ip -#{family} route add default via "#{gateway}" dev "#{guest_if}"
                echo "Global IPv#{family} default route via #{gateway} on #{guest_if}"
            fi
          SHELL
    
        end  # [ 4, 6 ].each do |family|

      end  # $config["net"].each do |key, value|

      host.vm.provision "hosts-scrub", type: "shell", run: "once", inline: <<-SHELL
        sed -i -e '/#{host.vm.hostname}/d' /etc/hosts
      SHELL


      #
      # Ansible
      #

      host.vm.provision "ansible-#{host.vm.hostname}", type:"shell", run: "always", inline: <<-SHELL

        set -e

        ANSIBLE_USER="#{get_with_default(host_config,"ansible")["user"]}"
        if ! getent passwd "${ANSIBLE_USER}" > /dev/null
        then
            useradd --system -c "Ansible" "${ANSIBLE_USER}"
        fi

        SSH_DIR=~ansible/.ssh
        mkdir -p "${SSH_DIR}"
        chmod 700 "${SSH_DIR}"
        chown "${ANSIBLE_USER}.${ANSIBLE_USER}" "${SSH_DIR}"

        AUTHORIZED_KEYS_BUILD="$(mktemp)"
        chmod 600 "${AUTHORIZED_KEYS_BUILD}"
        chown "${ANSIBLE_USER}.${ANSIBLE_USER}" "${AUTHORIZED_KEYS_BUILD}"

        cat > "${AUTHORIZED_KEYS_BUILD}" <<EOF
        #{get_with_default(host_config, "ansible")["keys"].join("\n")}
EOF
        sed -i -e 's/^[[:space:]]*//' "${AUTHORIZED_KEYS_BUILD}"

        mv -f "${AUTHORIZED_KEYS_BUILD}" "${SSH_DIR}/authorized_keys"

        # Disable SSH root login
        sed -i -e 's/PermitRootLogin.*$/PermitRootLogin no/g' /etc/ssh/sshd_config
        systemctl restart sshd

      SHELL

    end  # vc.vm.define name

  end  # $config["hosts"].each

end  # Vagrant.configure("2") do |vc|


# -*- mode: ruby -*-
# vi: set ft=ruby :
