require File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper')

class ForwardPortsActionTest < Test::Unit::TestCase
  setup do
    @mock_vm, @vm, @action = mock_action(Vagrant::Actions::VM::ForwardPorts)
    mock_config
  end

  context "checking for colliding ports" do
    setup do
      @forwarded_port = mock("forwarded_port")
      @forwarded_port.stubs(:hostport)
      @forwarded_ports = [@forwarded_port]

      @vm = mock("vm")
      @vm.stubs(:forwarded_ports).returns(@forwarded_ports)
      @vm.stubs(:running?).returns(true)
      vagrant_vm = mock("vagrant_vm")
      vagrant_vm.stubs(:vm).returns(@vm)
      vms = [vagrant_vm]
      Vagrant::ActiveList.stubs(:vms).returns(vms)

      mock_config do |config|
        config.vm.forwarded_ports.clear
        config.vm.forward_port("ssh", 22, 2222)
      end
    end

    should "ignore vms which aren't running" do
      @vm.expects(:running?).returns(false)
      @vm.expects(:forwarded_ports).never
      @action.prepare
    end

    should "not raise any errors if no forwarded ports collide" do
      @forwarded_port.expects(:hostport).returns(80)
      assert_nothing_raised { @action.prepare }
    end

    should "raise an ActionException if a port collides" do
      @forwarded_port.expects(:hostport).returns(2222)
      assert_raises(Vagrant::Actions::ActionException) {
        @action.prepare
      }
    end

    should "convert ports to strings prior to checking" do
      @forwarded_port.expects(:hostport).returns("2222")
      assert_raises(Vagrant::Actions::ActionException) {
        @action.prepare
      }
    end
  end

  context "execution" do
    should "clear all previous ports and forward new ports" do
      exec_seq = sequence("exec_seq")
      @action.expects(:clear).once.in_sequence(exec_seq)
      @action.expects(:forward_ports).once.in_sequence(exec_seq)
      @action.execute!
    end
  end

  context "forwarding ports" do
    should "create a port forwarding for the VM" do
      forwarded_ports = mock("forwarded_ports")

      Vagrant.config.vm.forwarded_ports.each do |name, opts|
        forwarded_ports.expects(:<<).with do |port|
          assert_equal name, port.name
          assert_equal opts[:hostport], port.hostport
          assert_equal opts[:guestport], port.guestport
          true
        end
      end

      @vm.expects(:forwarded_ports).returns(forwarded_ports)
      @vm.expects(:save).with(true).once
      @action.forward_ports
    end
  end

  context "clearing forwarded ports" do
    should "call destroy on all forwarded ports" do
      forwarded_ports = []
      5.times do |i|
        port = mock("port#{i}")
        port.expects(:destroy).with(true).once
        forwarded_ports << port
      end

      @vm.expects(:forwarded_ports).returns(forwarded_ports)
      @action.clear
    end
  end
end