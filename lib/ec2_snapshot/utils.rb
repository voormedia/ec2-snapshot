require 'net/http'
require 'uri'

module Ec2Snapshot
  class Utils

    # The supported kernel version beyond which we support fsreeze
    SUPPORTED_KERNEL_VERSION = '2.6.29'

    def self.can_run_fsfreeze?
      return running_supported_kernel? && File.exists?('/sbin/fsfreeze')
    end

    def self.query_instance_region
        begin
            instance_az = nil
            Timeout.timeout(3) do
                instance_az = Net::HTTP.get(URI('http://169.254.169.254/latest/meta-data/placement/availability-zone/'))
            end            
            return instance_az[0...-1]
        rescue Exception => e
            raise "Cannot obtain this instance's Availability Zone."
        end
    end

    def self.query_instance_id
      begin
          instance_id = nil
          Timeout.timeout(3) do
              instance_id = Net::HTTP.get(URI('http://169.254.169.254/latest/meta-data/instance-id/'))
          end            
          return instance_id
      rescue Exception => e
          raise "Cannot obtain this instance's ID."
      end      
    end

    def self.hostname
      %x[/bin/hostname -f].chomp
    end

    private

    def self.version_compare(version1, version2)
      version1 = version1.split('-').first.split('.').map{|v| v.to_i }
      version2 = version2.split('-').first.split('.').map{|v| v.to_i }    
      # Adapt to different version lengths
      if version2.size > version1.size
        ((version1.size)...(version2.size)).each do |v|
          version1[v] = 0
        end
      elsif version2.size < version1.size
        ((version2.size)...(version1.size)).each do |v|
          version2[v] = 0
        end
      end
      (0...version1.size).each do |v|
        return version1[v] <=> version2[v] unless version1[v] == version2[v]
      end
      return 0
    end

    def self.running_supported_kernel?
      if ::RUBY_PLATFORM.match(/linux/)
        this_kernel = %x[/bin/uname -r].chomp
        return version_compare(this_kernel, SUPPORTED_KERNEL_VERSION) >= 1
      else
        return false
      end
    end

  end
end