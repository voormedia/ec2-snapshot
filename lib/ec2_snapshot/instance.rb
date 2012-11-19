require "date"
require "right_aws"

module Ec2Snapshot
  class Instance
    attr_accessor :ec2, :ec2_info, :create_rootvol_snapshot, :create_datavol_snapshot, :before, :after, :verbose

    def initialize(options = {})
      @verbose = options[:verbose] ? options[:verbose] : false
      @ec2 = RightAws::Ec2.new(options[:aws_access_key], options[:aws_secret_access_key], :region => options[:aws_region], :logger => Logger.new('/dev/null'))
      @ec2_info = @ec2.describe_instances(Ec2Snapshot::Utils.query_instance_id).first
      @create_rootvol_snapshot = false
      @create_datavol_snapshot = false
      @devices = []
      @before = options[:before]
      @after = options[:after]
      @fsfreeze_support = Ec2Snapshot::Utils.can_run_fsfreeze?
      @skip_pending = options[:skip_pending]
    end

    def enable_rootvol_snapshot
      @create_rootvol_snapshot = true
    end

    def enable_datavol_snapshot
      @create_datavol_snapshot = true
    end

    def enable_devices_snapshot(devices)
      @devices = devices.split(',').map{|dev| dev.gsub(/^xv/,'s') }.compact.sort.uniq
    end

    def create_snapshots
      volumes.each do |volume|
        unless volume.requires_snapshot?  
          puts "-> Skipping volume #{volume.volume_id} due to command line option" if @verbose
          next
        end
        if (@skip_pending && (! volume.can_snapshot?))
          puts "-> Skipping snapshotting for volume #{volume.volume_id} since there are snapshots of this volume that have not been completed" if @verbose
          next
        end
        puts "-> Preparing snapshot for volume #{volume.volume_id} (#{volume.device_name})" if @verbose
        custom_actions do
          volume.freeze_filesystem do
            volume.create_snapshot
          end
        end
      end
    end

    def delete_snapshots(cut_off_date = Date.today << 3)
      volumes.each do |volume|
        # Skip rotation for volumes we have not specified
        next unless volume.requires_snapshot?
        # Get snapshots for each volume
        @ec2.describe_snapshots(:filters => { 'volume-id' => volume.volume_id, 'status' => 'completed' }).each do |snapshot|
          if Date.parse(snapshot[:aws_started_at]) <= cut_off_date
            puts "-> Deleting snapshot #{snapshot[:aws_id]} by date" if @verbose
            @ec2.delete_snapshot(snapshot[:aws_id])
          end
        end
      end
    end

    def rotate_snapshots(keep_only = 7)
      raise 'You cannot specify less than 1 snapshots to keep in rotation!' if keep_only < 1
      volumes.each do |volume|
        next unless volume.requires_snapshot?        
        snapshot_ordering = Array.new
        snapshots = Hash.new
        @ec2.describe_snapshots(:filters => { 'volume-id' => volume.volume_id, 'status' => 'completed' }).each do |snapshot|
          # Convert to unixtime in order to sort properly
          snapshot_timestamp = DateTime.parse(snapshot[:aws_started_at]).to_time.to_i
          snapshot_ordering << snapshot_timestamp
          # Keep the snapshot IDs in a hash
          snapshots[snapshot_timestamp] = snapshot[:aws_id]
        end
        snapshots_to_delete = snapshot_ordering.size - keep_only
        if snapshots_to_delete <= 0
          puts "-> Snapshot set is smaller than the minimum number of snapshots in rotation for #{volume.volume_id}. No rotation was performed" if @verbose
        else
          snapshot_ordering.sort.uniq[0...snapshots_to_delete].each do |hashkey|
              puts "-> Deleting snapshot #{snapshots[hashkey]} for volume #{volume.volume_id} by rotation" if @verbose
              @ec2.delete_snapshot(snapshots[hashkey])
          end
        end
      end
    end

    def custom_actions(&block)
      if @before
        puts "-> Executing before command" if @verbose
        Kernel.system(@before)
      end
      begin
        yield
      rescue Exception => ex
        puts "Exception thrown during snapshot creation: #{ex}" if @verbose
      ensure
        if @after
          puts "-> Executing after command" if @verbose
          Kernel.system(@after)
        end
      end
    end

    def root_device_name
      @ec2_info[:root_device_name]
    end

    def volumes
      if @devices.empty?
        @ec2_info[:block_device_mappings].collect{ |v| Ec2Snapshot::Volume.new(self, v[:ebs_volume_id], v[:device_name], @fsfreeze_support) }
      else
        @ec2_info[:block_device_mappings].collect{ |v| Ec2Snapshot::Volume.new(self, v[:ebs_volume_id], v[:device_name], @fsfreeze_support) if @devices.include?(v[:device_name]) }.compact
      end
    end

  end
end