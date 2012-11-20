require 'ec2_snapshot/utils'
require File.expand_path("../helper", __FILE__)

class UtilsTest < MiniTest::Unit::TestCase

  # freeze_filesystem
  def test_kernel_detection
    assert_equal true, Ec2Snapshot::Utils.running_supported_kernel?
  end

  def test_version_comparison
    assert_equal -1, Ec2Snapshot::Utils.version_compare('1.2.3', '1.2.3.4')
    assert_equal 1, Ec2Snapshot::Utils.version_compare('1.2.3.4', '1.2.3')
    assert_equal 0, Ec2Snapshot::Utils.version_compare('1', '1.0.0')
  end

  def test_can_run_fsfreeze
    assert_equal true, Ec2Snapshot::Utils.can_run_fsfreeze?
  end

end