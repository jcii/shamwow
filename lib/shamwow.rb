require 'shamwow/db'
require 'shamwow/ssh'
require 'shamwow/dns'
require 'shamwow/http'
require 'shamwow/version'
require 'shamwow/knife'
require 'slop'
require 'highline/import'
require 'json'

module Shamwow
  testlist = {}
  hosts = {}
  $expire_time = 14400 # 4hrs
  opts = Slop.parse do |o|
    o.on '-h', '--help' do
      puts 'HELP!'
      exit
    end
    o.string '--host',           'run on a hostname', default: nil
    o.string '--from',           'hosts from a file', default: nil
    o.bool   '--fromdb',         'hosts from hsots table', default: false
    o.string '--connection',     'postgres connection string', default: ENV['CONNECTIONSTRING']
    o.array  '--sshtasks',       'a list of sshtasks to execute', default: ['Chef_version'], delimiter: ','
    o.string '-u', '--user',     'the user to connect to using ssh', default: ENV['USER']
    o.string '-P', '--password', 'read password from args', default: nil
    o.bool   '-p', '--askpass',  'read password from stdlin', default: false
    o.bool   '--dns',            'poll dns'
    o.bool   '--ssh',            'poll ssh'
    o.bool   '--net',            'poll network engineerings website'
    o.bool   '--knife',          'poll knife status'
    o.bool   '--dbdebug',        'dumps ORM\'s raw sql', default: false
    o.on     '--version',        'print the version' do
      puts Slop::VERSION
      exit
    end
  end

  def load_config(file = 'config.json')
    @conf = JSON.parse(IO.read(file))
  end

  def get_config
    @conf
  end
  #
  # If a con
  if opts[:config]
    $config = load_config(opts[:configfile] || nil )
  end
  # read the password from stdin
  if opts[:askpass]
    $password = ask("Enter Password:") {|q| q.echo = false }
  end
  # the user used for ssh'ing
  unless opts[:user].nil?
    $user = opts[:user]
  end
  # the user's password for sudo
  unless opts[:password].nil?
    $password = opts[:password]
  end
  # a single host to scan from the cli
  unless opts[:host].nil?
    testlist[opts[:host]] = true
  end
  # from a file (each line is a hostname)
  unless opts[:from].nil?
    fh = File.open opts[:from], 'r'
    fh.each_line do |line|
      testlist[line.strip] = true
    end
  end

  # establish connection to postgres. If the schema doesn't
  # match, the ORM will attempt to update, or throw an error
  db = Shamwow::Db.new(opts[:connection], opts[:dbdebug])
  db.bootstrap_db

  if opts[:fromdb]
    # assuming all nodes from Chef will be ssh-reachable
    # KnifeData.all.each do |k|
    #   testlist[k[:name]] = true
    # end
    # hosts may override w/ ssh_scan == false
    hosts = Host.all
    hosts.each do |e|
      # only scan if ssh_scan == true
      testlist[e[:hostname]] = e[:ssh_scan]
    end
  end

  # polls dns servers for records
  if opts.dns?
    dns = Shamwow::Dns.new(db)
    out = dns.transfer_zone('REDACTED.com', 'REDACTED.com')
    dns.update_records(out)
    out = dns.transfer_zone('REDACTED.com', 'REDACTED.com')
    dns.update_records(out)
    out = dns.transfer_zone('REDACTED.com', 'REDACTEDcom')
    dns.update_records(out)
    out = dns.transfer_zone('REDACTED.com', 'REDACTED.com')
    dns.update_records(out)
    out = dns.transfer_zone('REDACTED.com', 'REDACTED.com')
    dns.update_records(out)
    dns.save_records
    dns.parse_all_records
    dns.expire_records($expire_time)
  end

  # executes ssh tasks in parallel
  if opts.ssh?
    ssh = Shamwow::Ssh.new(db)
    ssh.create_session

    testlist.each do |line, enabled|
      if enabled
        stripped = line.strip
        ssh.add_host(stripped)
      else
        o = hosts.first({:hostname => line})
        puts "#{Time.now}-Shamwow::Ssh: skipping host: #{line} because: #{o[:notes]}"
      end
    end

    puts "#{Time.now}-Shamwow::Ssh: session count #{ssh.count_hosts}"
    ssh.execute(opts[:sshtasks])
    ssh.save
    puts "#{Time.now}-Shamwow::Ssh: Done"
  end

  # this polls REDACTED's custom network management tool (RIP Erwin!)
  if opts.net?
    h = Shamwow::Http.new(db)
    layer1 = h.get('http://REDACTED.com/report/gni/dyn/data/01.proc-summaries/01.phy-link')
    parsed = h.parse_layer1(h.remove_header(layer1))

    puts "#{Time.now}-Shamwow::Http: Layer 1 record count: #{parsed.count}"
    h.save_all_layer1
    h.expire_l1_records($expire_time)
    #
    layer2 = h.get('http://REDACTED.com/report/gni/dyn/data/01.proc-summaries/02.mac-edge')
    parsed = h.parse_layer2(h.remove_header(layer2))
    puts "#{Time.now}-Shamwow::Http: Layer 2 record count: #{parsed.count}"
    h.save_all_layer2
    h.expire_l2_records($expire_time)
    #
    layer3 = h.get('http://REDACTED.com/report/gni/dyn/data/01.proc-summaries/03.arp-tabl.v2-ptr')
    parsed = h.parse_layer3(h.remove_header(layer3))
    puts "#{Time.now}-Shamwow::Http: Layer 3 record count: #{parsed.count}"
    h.save_all_layer3
    h.expire_l3_records($expire_time)
  end

  # polls knife status and cookbook, role, and runlist data from the nodes
  if opts.knife?
    k = Shamwow::Knife.new(db)
    k.load_data
    out = k.get_status('REDACTED.com')
    k.parse_status(out)
    out = k.get_attributes('REDACTED.com')
    k.parse_attributes(out)
    k.expire_records($expire_time)
  end

  db.finalize
end
