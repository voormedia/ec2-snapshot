require 'ec2_snapshot/volume'
require File.expand_path("../helper", __FILE__)

class VolumeTest < MiniTest::Unit::TestCase
  def setup
    # mock system calls
    Ec2Snapshot::Instance.any_instance.stubs(:`).returns("output")
    Ec2Snapshot::Volume.any_instance.stubs(:`).returns("/dev/xvdf /srv xfs rw,noatime,attr2,delaylog,noquota 0 0")
    # mock right_aws init, return mock object and mock methods on that object
    m = MiniTest::Mock.new
    RightAws::Ec2.stubs(:new).returns(m)
    m.stubs(:describe_instances).returns([{:root_device_type=>"ebs", :root_device_name=>"/dev/sda1", :block_device_mappings=>[{:device_name=>"/dev/sda1", :ebs_volume_id=>"vol-id1", :ebs_status=>"attached", :ebs_attach_time=>"2011-12-06T14:48:27.000Z", :ebs_delete_on_termination=>true}, {:device_name=>"/dev/sdf", :ebs_volume_id=>"vol-id2", :ebs_status=>"attached", :ebs_attach_time=>"2011-12-06T14:48:27.000Z", :ebs_delete_on_termination=>false}]}])
    # init Ec2Snapshot::Instance to work with
    @instance = Ec2Snapshot::Instance.new({ :access_key => "accesskey", :secret_access_key => "secretkey", :region => "region" })
  end

  # xfs_device_name
  def test_xfs_device_name_should_return_a_string
    vol = Ec2Snapshot::Volume.new(@instance, "volume-id", "/dev/sdf")
    assert_instance_of String, vol.xfs_device_name
  end

  def test_xfs_device_name_should_replace_device_name
    vol = Ec2Snapshot::Volume.new(@instance, "volume-id", "/dev/sdf")
    assert_equal "/dev/xvdf", vol.xfs_device_name
  end

  # requires_snapshot
  def test_requires_snapshot_should_return_true_if_volume_is_rootvol_and_rootvol_should_be_snapshotted
    vol = Ec2Snapshot::Volume.new(@instance, "volume-id", "/dev/sda1")
    @instance.enable_rootvol_snapshot
    assert vol.requires_snapshot
  end

  def test_requires_snapshot_should_return_false_if_volume_is_rootvol_and_rootvol_shouldnt_be_snapshotted
    vol = Ec2Snapshot::Volume.new(@instance, "volume-id", "/dev/sda1")
    assert !vol.requires_snapshot
  end

  def test_requires_snapshot_should_return_true_if_volume_is_datavol_and_datavol_should_be_snapshotted
    vol = Ec2Snapshot::Volume.new(@instance, "volume-id", "/dev/sdf")
    @instance.enable_datavol_snapshot
    assert vol.requires_snapshot
  end

  def test_requires_snapshot_should_return_false_if_volume_is_datavol_and_datavol_shouldnt_be_snapshotted
    vol = Ec2Snapshot::Volume.new(@instance, "volume-id", "/dev/sdf")
    assert !vol.requires_snapshot
  end
end