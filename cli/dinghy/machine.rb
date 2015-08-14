require 'dinghy/constants'
require 'json'

class Machine
  def up(options = {})
    if created?
      machine("start", machine_name)
    else
      machine("create", "-d", provider(options[:provider]), machine_name)
    end

    if command_failed?
      raise("There was an error bringing up the Vagrant box. Dinghy cannot continue.")
    end

    write_ssh_config!
  end

  def ssh(command)
    if command && !command.empty?
      machine("ssh", machine_name, "--", command)
      if command_failed?
        raise("Error executing command: #{command}")
      end
    else
      exec("docker-machine", "ssh", machine_name)
    end
  end

  def host_ip
    vm_ip.sub(%r{\.\d+$}, '.1')
  end

  def vm_ip
    inspect['Driver']['IPAddress']
  end

  def provider
    inspect['DriverName']
  end

  def inspect
    JSON.parse(`docker-machine inspect #{machine_name}`)
  end

  def ssh_config
    # TODO: syntesize the ssh config from docker-machine inspect
    ""
  end

  def write_ssh_config!
    File.open(ssh_config_path, 'wb') { |f| f.write(ssh_config) }
  end

  def status
    if created?
      `docker-machine status #{machine_name}`
    else
      "not created"
    end
  end

  def running?
    status == "running"
  end

  def mount(unfs)
    puts "Mounting NFS #{unfs.guest_mount_dir}"
    # TODO: this shouldn't be hard-coded, and should check that it's currently mounted
    ssh("sudo umount /Users || true")
    ssh("sudo mkdir -p #{unfs.guest_mount_dir}")
    ssh("sudo mount -t nfs #{host_ip}:#{unfs.host_mount_dir} #{unfs.guest_mount_dir} -o nfsvers=3,udp,mountport=19321,port=19321,nolock,hard,intr")
  end

  def halt
    machine("stop", machine_name)
  end

  def destroy(options = {})
    cd
    system "vagrant destroy #{options[:force] && '--force'}"
  end

  def command_failed?
    !$?.success?
  end

  def ssh_config_path
    # this is hard-coded inside the fsevents_to_vm plist, as well
    Pathname.new("#{HOME}/.dinghy/ssh-config")
  end

  def created?
    `docker-machine status #{machine_name} 2>&1`
    !command_failed?
  end

  def machine(*cmd)
    system("docker-machine", *cmd)
  end

  def machine_name
    'dinghy'
  end

  def provider(name)
    case name
    when "virtualbox"
      "virtualbox"
    when "vmware", "vmware_fusion", "vmwarefusion", "vmware_desktop"
      "vmwarefusion"
    when nil
      # TODO: autodetect?
      "virtualbox"
    else
      raise(ArgumentError, "unknown VM provider: #{name}")
    end
  end
end