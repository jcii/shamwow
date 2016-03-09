require 'rspec'
require_relative '../../../lib/shamwow/ssh'
require_relative '../../../lib/shamwow/db/sshdata'
describe 'Ssh' do

  it 'should parse lsb release for the OS version' do
    sshdata = instance_double("Shamwow::SshData", :hostname => 'foo')
    allow(Shamwow::SshData).to receive(:first_or_new) { sshdata }
    expect(sshdata).to receive(:attributes=).with({:os=>"Ubuntu 12.04.5 LTS"})
    o = Shamwow::Ssh.new
    o.add_host('foo')
    o._parse_lsb_release('foo', 'DISTRIB_DESCRIPTION="Ubuntu 12.04.5 LTS"')
  end

end