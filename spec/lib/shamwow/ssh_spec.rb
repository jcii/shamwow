require 'rspec'
require_relative '../../../lib/shamwow/ssh'
require_relative '../../../lib/shamwow/db/sshdata'

describe 'Ssh' do
  before(:context) do
    #
    # Arrange
    @time_now = Time.now
  end

  it 'should parse lsb release for the OS version' do
    #
    # Arrange
    ssh = Shamwow::Ssh.new
    allow(ssh).to receive(:_save_ssh_data)
    allow(Time).to receive(:now).and_return(@time_now)
    #
    # # Act
    ssh._parse_lsb_release('foo', 'DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=12.04
DISTRIB_CODENAME=precise
DISTRIB_DESCRIPTION="Ubuntu 12.04.5 LTS"')
    #
    # Assert
    expect(ssh).to have_received(:_save_ssh_data).with("foo", {:os=>"Ubuntu 12.04.5 LTS",:os_polltime=>@time_now})
  end

  it 'should catch errors parsing lsb release' do
    #
    # Arrange
    ssh = Shamwow::Ssh.new
    allow(ssh).to receive(:_save_ssh_data)
    allow(Time).to receive(:now).and_return(@time_now)
    #
    # Act & Assert
    expect { ssh._parse_lsb_release('foo', '') }.to raise_error(NoMethodError)
    expect { ssh._parse_lsb_release('foo', "\n") }.to raise_error(NoMethodError)
  end

  it 'should parse a centos 6.4 /etc/issue' do
    #
    # Arrange
    ssh = Shamwow::Ssh.new
    allow(ssh).to receive(:_save_ssh_data)
    allow(Time).to receive(:now).and_return(@time_now)
    #
    # # Act
    ssh._parse_issue('foo', 'CentOS release 6.4 (Final)
Kernel \r on an \m
')
    #
    # Assert
    expect(ssh).to have_received(:_save_ssh_data).with('foo', {:os=>"CentOS release 6.4 (Final)",:os_polltime=>@time_now})
  end

  it 'should parse a Debian 5 /etc/issue' do
    #
    # Arrange
    ssh = Shamwow::Ssh.new
    allow(ssh).to receive(:_save_ssh_data)
    allow(Time).to receive(:now).and_return(@time_now)
    #
    # # Act
    ssh._parse_issue('foo', 'Debian GNU/Linux 5.0 \n \l
')
    #
    # Assert
    expect(ssh).to have_received(:_save_ssh_data).with('foo', {:os=>"Debian GNU/Linux 5.0",:os_polltime=>@time_now})
  end

  it 'should parse an Ubuntu /etc/issue' do
    #
    # Arrange
    ssh = Shamwow::Ssh.new
    allow(ssh).to receive(:_save_ssh_data)
    allow(Time).to receive(:now).and_return(@time_now)
    #
    # # Act
    ssh._parse_issue('foo', 'Ubuntu 12.04.5 LTS \n \l
')
    #
    # Assert
    expect(ssh).to have_received(:_save_ssh_data).with('foo', {:os=>"Ubuntu 12.04.5 LTS",:os_polltime=>@time_now})
  end


end