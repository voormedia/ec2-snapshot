module Ec2Snapshot
  class Volume
    attr_accessor :instance, :volume_id, :device_name, :mount_point, :file_system

    def initialize(instance, volume_id, device_name)
      @instance = instance
      @volume_id = volume_id
      @device_name = device_name
      init_mount_info
    end

    def requires_snapshot
      root_device = @instance.root_device_name
      raise Exception, "No root device could be found" unless root_device
      (root_device == @device_name and @instance.create_rootvol_snapshot) or (root_device != @device_name and @instance.create_datavol_snapshot)
    end

    def freeze_filesystem(&block)
      if @mount_point and @file_system == "xfs"
        puts "freezing XFS filesystem" if @instance.verbose
        Kernel.system("xfs_freeze -f #{@mount_point}")
      end
      
      begin
        yield
      rescue Exception => ex
        puts "exception thrown during snapshot creation: #{ex}" if @verbose
      ensure
        if @mount_point and @file_system == "xfs"
          puts "unfreezing XFS filesystem" if @instance.verbose
          Kernel.system("xfs_freeze -u #{@mount_point}")
        end
      end
    end

    def create_snapshot
      puts "creating and tagging snapshot" if @instance.verbose
      snapshot = @instance.ec2.create_snapshot(@volume_id, "#{@instance.hostname}: automated snapshot #{@device_name} (#{@volume_id})")
      # The only way to set the name of a snapshot is by creating a name tag for the snapshot
      @instance.ec2.create_tags(snapshot[:aws_id], { "Name" => "#{@instance.hostname} (#{@device_name})", "Hostname" => @instance.hostname })
    end

    def xfs_device_name
      # Required for Ubuntu Natty Narwhal and up, which uses xvdX, while Amazon uses sdX
      @device_name.gsub("/sd", "/xvd")
    end

    private

    def init_mount_info
      mounts = %x[cat /proc/mounts].split("\n")
      mounts.each do |mount|
        parts = mount.split(" ")
        if [@device_name, xfs_device_name].include?(parts.first)
          @mount_point = parts[1]
          @file_system = parts[2]
          break
        end
      end
    end
  end
end