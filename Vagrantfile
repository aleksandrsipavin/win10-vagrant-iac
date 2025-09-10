# Vagrantfile — 5 Ubuntu VMs, bridged static IPs (no gateway) + NAT default route
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"   # Ubuntu 22.04 LTS

  BRIDGE  = ENV['VAGRANT_BRIDGE']&.strip      # e.g. your host Wi-Fi/Ethernet adapter

  NODES = {
    "ubuntunode1" => "192.168.10.120",
    "ubuntunode2" => "192.168.10.121",
    "ubuntunode3" => "192.168.10.122",
    #"ubuntunode4" => "192.168.10.123",
    #"ubuntunode5" => "192.168.10.124",
  }

  # Space saver: linked clones
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
  end

  # Fail fast if the public key file is missing (required for external SSH)
  unless File.exist?(File.join(__dir__, "asipavin.pub"))
    abort "Put your SSH public key in asipavin.pub (same folder as Vagrantfile)"
  end

  NODES.each do |name, ip|
    config.vm.define name do |m|
      m.vm.hostname = name

      # NAT is NIC1 by default (kept for Internet/default route)
      # Bridged NIC (NIC2) with static IP — NO gateway here
      m.vm.network "public_network",
        ip: ip,
        netmask: "255.255.255.0",
        bridge: BRIDGE

      # Resources + faster NIC type (virtio for both NICs)
      m.vm.provider "virtualbox" do |vb|
        vb.name   = name
        vb.cpus   = 2
        vb.memory = 4096
        vb.customize ["modifyvm", :id, "--nictype1", "virtio"] # NAT
        vb.customize ["modifyvm", :id, "--nictype2", "virtio"] # bridged
      end

      # Upload your SSH public key
      m.vm.provision "file", source: "asipavin.pub", destination: "/tmp/asipavin.pub"

      # Create 'asipavin' user w/ passwordless sudo + key-only SSH; ensure bridged has no default route
      m.vm.provision "shell", privileged: true, inline: <<-'SHELL'
        set -euo pipefail
        USERNAME="asipavin"
        id -u "$USERNAME" >/dev/null 2>&1 || adduser --disabled-password --gecos '' "$USERNAME"
        usermod -aG sudo "$USERNAME"

        install -d -m 700 -o "$USERNAME" -g "$USERNAME" /home/$USERNAME/.ssh
        if [ -s /tmp/asipavin.pub ]; then
          cat /tmp/asipavin.pub >> /home/$USERNAME/.ssh/authorized_keys
          sort -u /home/$USERNAME/.ssh/authorized_keys -o /home/$USERNAME/.ssh/authorized_keys
          chown -R "$USERNAME:$USERNAME" /home/$USERNAME/.ssh
          chmod 600 /home/$USERNAME/.ssh/authorized_keys
        else
          echo "asipavin.pub is empty or missing" >&2; exit 1
        fi

        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USERNAME
        chmod 440 /etc/sudoers.d/90-$USERNAME
        visudo -c -f /etc/sudoers.d/90-$USERNAME

        # Harden SSH: key-only for everyone, no root login
        install -d /etc/ssh/sshd_config.d
        cat >/etc/ssh/sshd_config.d/99-$USERNAME.conf <<'EOF'
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
EOF
        systemctl reload ssh || systemctl reload sshd || true

        # If UFW is enabled, allow SSH
        if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
          ufw allow OpenSSH || ufw allow 22/tcp
        fi

        # Defensive: ensure no default route via bridged NIC (enp0s8)
        ip -br a | grep -q 'enp0s8' && ip route del default dev enp0s8 2>/dev/null || true

        echo "=== Ready: login as $USERNAME@$(hostname -I | awk '{print $1}')"
      SHELL
    end
  end
end
