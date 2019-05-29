# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com
  
  config.env.enable
  
  config.vm.box = "debian/jessie64"
  config.vm.hostname = ENV['HOST_NAME']

  config.vagrant.plugins = ["vagrant-hostmanager", "vagrant-env"]
  
  config.vm.network "private_network", type: "dhcp"

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = false
  cached_addresses = {}
  config.hostmanager.ip_resolver = proc do |vm, resolving_vm|
    if cached_addresses[vm.name].nil?
      if hostname = (vm.ssh_info && vm.ssh_info[:host])
        vm.communicate.execute("hostname -I | cut -d ' ' -f 2") do |type, contents|
          cached_addresses[vm.name] = contents.split("\n").first[/(\d+\.\d+\.\d+\.\d+)/, 1]
        end
      end
    end
    cached_addresses[vm.name]
  end

  config.vm.provider "virtualbox" do |vb|
    # Customize the amount of memory on the VM:
    vb.memory = "1024"
  end

  config.ssh.insert_key = false

  config.vm.provision :shell, keep_color: true, path: "Vagrant.provision.sh", args: [
    ENV['MYSQL_DB_NAME'], # MySQL db name
    ENV['MYSQL_DB_PASSWORD'], # MySQL password
    ENV['SERVER_NAME'], # Server name
    ENV['SERVER_ADMIN'], # Server admin
  ]

  # vagrant dir containing required files for provisioning
  config.vm.synced_folder "./vagrant", "/vagrant", disabled: true
end
