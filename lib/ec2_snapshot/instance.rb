require "date"
require "right_aws"

module Ec2Snapshot
  class Instance
    attr_accessor :ec2, :ec2_info, :create_rootvol_snapshot, :create_datavol_snapshot, :before, :after, :verbose

    def initialize(options = {})
      @ec2 = RightAws::Ec2.new(options[:aws_access_key], options[:aws_secret_access_key], :region => options[:aws_region], :logger => Logger.new('/dev/null'))
      @ec2_info = @ec2.describe_instances(instance_id).first
      @create_rootvol_snapshot = false
      @create_datavol_snapshot = false
      @before = options[:before]
      @after = options[:after]
      @verbose = options[:verbose] ? options[:verbose] : false
    end

    def enable_rootvol_snapshot
      @create_rootvol_snapshot = true
    end

    def enable_datavol_snapshot
      @create_datavol_snapshot = true
    end

    def create_snapshots
      volumes.each do |volume|
        next if not volume.requires_snapshot
        
        puts "preparing snapshot for volume #{volume.volume_id} (#{volume.device_name})" if @verbose
        custom_actions do
          volume.freeze_filesystem do
            volume.create_snapshot
          end
        end
      end
    end

    def delete_snapshots(cut_off_date = Date.today << 3)
      # This function requires a tag called Hostname to be set for each snapshot of the current instance
      @ec2.describe_snapshots(:filters => {'tag:Hostname' => hostname}).each do |snapshot|
        if Date.parse(snapshot[:aws_started_at]) <= cut_off_date
          puts "deleting snapshot #{snapshot[:aws_id]}" if @verbose
          @ec2.delete_snapshot(snapshot[:aws_id])
        end
      end
    end

    def custom_actions(&block)
      if @before
        puts "executing before command" if @verbose
        Kernel.system(@before)
      end
      begin
        yield
      rescue Exception => ex
        puts "exception thrown during snapshot creation: #{ex}" if @verbose
      ensure
        if @after
          puts "executing after command" if @verbose
          Kernel.system(@after)
        end
      end
    end

    def instance_id
      # See http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/index.html?AESDG-chapter-instancedata.html
      output = %x[wget -T 5 -t 1 -q -O - http://169.254.169.254/latest/meta-data/instance-id]
      raise Exception, "Failed to retrieve the current instance id" if output.empty?
      output
    rescue
      raise Exception, "Failed to retrieve the current instance id"
    end

    def hostname
      %x[cat /etc/hostname].chomp
    end

    def root_device_name
      @ec2_info[:root_device_name]
    end

    def volumes
      @ec2_info[:block_device_mappings].collect{ |v| Ec2Snapshot::Volume.new(self, v[:ebs_volume_id], v[:device_name]) }
    end
  end
end