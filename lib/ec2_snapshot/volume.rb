module Ec2Snapshot
  class Volume
    attr_accessor :instance, :volume_id, :device_name, :mount_point, :fsfreeze_support, :file_system

    def initialize(instance, volume_id, device_name, fsfreeze_support)
      @instance = instance
      @volume_id = volume_id
      @device_name = device_name
      @fsfreeze_support = fsfreeze_support
      init_mount_info
    end

    def requires_snapshot?
      root_device = @instance.root_device_name
      raise Exception, "No root device could be found" unless root_device
      (root_device == @device_name && @instance.create_rootvol_snapshot) || (root_device != @device_name && @instance.create_datavol_snapshot)
    end

    def can_snapshot?
      return @instance.ec2.describe_snapshots(:filters => { 'volume-id' => @volume_id, 'status' => 'pending' }).size == 0
    end

    def freeze_filesystem(&block)
      if @mount_point && @mount_point.eql?('/')
        puts '-> Root mount point detected. Performing simple fsync() instead of fsfreeze' if @instance.verbose
        Kernel.system('sync')
      elsif @fsfreeze_support && @mount_point && [ 'xfs', 'ext3', 'ext4', 'brtfs' ].include?(@file_system)
        puts "-> fsfreeze-supporting kernel detected. Freezing filesystem" if @instance.verbose
        Kernel.system("fsfreeze -f #{@mount_point}")
      else
        if @mount_point && @file_system == "xfs"
          puts "-> Freezing XFS filesystem" if @instance.verbose
          Kernel.system("xfs_freeze -f #{@mount_point}")
        end
      end      
      begin
        yield
      rescue Exception => ex
        puts "Exception thrown during snapshot creation: #{ex}" if @verbose
      ensure
        if @mount_point && @mount_point.eql?('/')
          puts "-> Root mount point detected. No unfreezing action performed for volume #{@volume_id}" if @instance.verbose
        elsif @fsfreeze_support && @mount_point && [ 'xfs', 'ext3', 'ext4', 'brtfs' ].include?(@file_system)
          puts "-> fsfreeze-supporting kernel detected. Unfreezing filesystem for volume #{@volume_id}" if @instance.verbose
          Kernel.system("fsfreeze -u #{@mount_point}")
        else
          if @mount_point && @file_system == "xfs"
            puts "-> Unfreezing XFS filesystem for volume #{@volume_id}" if @instance.verbose
            Kernel.system("xfs_freeze -u #{@mount_point}")
          end
        end      
      end
    end

    def create_snapshot
      puts "-> Creating && tagging snapshot for volume #{@volume_id}" if @instance.verbose
      # If there are pending snapshots skip running a snapshot for this volume
      snapshot = @instance.ec2.create_snapshot(@volume_id, "#{Ec2Snapshot::Utils.hostname}: automated snapshot of #{@device_name} (#{@volume_id})")
      puts "-> Snapshot #{snapshot[:aws_id]} created for volume #{@volume_id}" if @instance.verbose  
      # The only way to set the name of a snapshot is by creating a name tag for the snapshot
      @instance.ec2.create_tags(snapshot[:aws_id], { "Name" => "#{Ec2Snapshot::Utils.hostname} (#{@device_name})", "Hostname" => Ec2Snapshot::Utils.hostname })
      puts "-> Snapshot #{snapshot[:aws_id]} tagged for volume #{@volume_id}" if @instance.verbose  
    end

    private

    def init_mount_info
      mounts = %x[cat /proc/mounts].split("\n")
      mounts.each do |mount|
        parts = mount.split(" ")
        # Dereference UUID/label mounts to get actual device name
        device = '/dev' + ::File.expand_path(::File.readlink(parts.first),'/dev') rescue parts.first
        # Account for naming conventions in PVOPS kernels (sd -> xvd)
        if device.match("#{@device_name.sub('sd','(sd|xvd)')}")
          @mount_point = parts[1]
          @file_system = parts[2]          
          break
        end
      end
    end
  end
end