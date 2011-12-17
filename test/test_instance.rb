require 'ec2_snapshot/instance'
require 'ec2_snapshot/volume'
require File.expand_path("../helper", __FILE__)

class InstanceTest < MiniTest::Unit::TestCase
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

  # new
  def test_create_new_instance_should_fail_if_required_ec2_credentials_are_unavailable
    assert_raises NoMethodError do
      Ec2Snapshot::Instance.new(nil)
    end
  end

  def test_create_new_instance_should_not_fail_if_required_ec2_credentials_are_available
    assert_instance_of Ec2Snapshot::Instance, @instance
  end

  # enable_rootvol_snapshot
  def test_enable_rootvol_snapshot_should_return_true
    assert @instance.enable_rootvol_snapshot
  end

  def test_enable_rootvol_snapshot_should_set_instance_variable
    assert !@instance.create_rootvol_snapshot
    @instance.enable_rootvol_snapshot
    assert @instance.create_rootvol_snapshot
  end

  # enable_datavol_snapshot
  def test_enable_datavol_snapshot_should_return_true
    assert @instance.enable_datavol_snapshot
  end

  def test_enable_datavol_snapshot_should_set_instance_variable
    assert !@instance.create_datavol_snapshot
    @instance.enable_datavol_snapshot
    assert @instance.create_datavol_snapshot
  end

  # instance_id
  def test_instance_id_should_return_a_string
    assert_instance_of String, @instance.instance_id
  end

  def test_instance_id_should_return_output_of_wget_call
    assert_equal "output", @instance.instance_id
  end

  # hostname
  def test_hostname_should_return_a_string
    assert_instance_of String, @instance.hostname
  end

  def test_hostname_should_return_hostname
    assert_equal "output", @instance.instance_id
  end

  # root_device_name
  def test_root_device_name_should_return_a_string_if_device_name_is_found
    assert_instance_of String, @instance.root_device_name
  end

  def test_root_device_name_should_return_correct_metadata
    assert_equal "/dev/sda1", @instance.root_device_name
  end

  # volumes
  def test_volumes_should_return_an_array
    assert_instance_of Array, @instance.volumes
  end

  def test_volumes_should_return_volume_objects
    @instance.volumes.each do |vol|
      assert_instance_of Ec2Snapshot::Volume, vol
    end
  end

  def test_volumes_should_return_correct_number_of_volumes
    assert_equal 2, @instance.volumes.count
  end
end