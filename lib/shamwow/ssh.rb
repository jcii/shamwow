require 'net/ssh/multi'
require 'shamwow/db'
#Dir["shamwow/ssh/*.rb"].each {|file| require file; puts "#{file}" }
require 'shamwow/ssh/chef_version'
require 'shamwow/ssh/os_version'
require 'shamwow/ssh/chef_stacktrace'
require 'shamwow/ssh/chef_run'
require 'shamwow/ssh/chef_upgrade'
require 'shamwow/ssh/chef_start'
require 'shamwow/ssh/chef_stop'
require 'shamwow/ssh/chef_verify_running_version'
require 'shamwow/ssh/chef_chmod_stacktrace'
require 'shamwow/ssh/gem_list_ldap'
require 'shamwow/ssh/nrpe_upgrade_checkchef'
require 'shamwow/ssh/nrpe_get_checkchef_checksum'
require 'shamwow/ssh/chef_lsof_count'
require 'shamwow/ssh/chef_server_url'
require 'shamwow/ssh/chef_set_url_onpremises'

module Shamwow
  class Ssh

    def initialize(db)
      @db = db
      @taskcounts = {}
      @hosts = {}
      @debug = 1
      @tasks = {}
    end

    def create_session
      handler = Proc.new do |server|
        server[:connection_attempts] ||= 0
        if server[:connection_attempts] < 0
          server[:connection_attempts] += 1
          throw :go, :retry
        else
          save_error server.to_s, 'create_session', $ERROR_INFO
          throw :go
        end
      end
      @session = Net::SSH::Multi::Session.new
      @session.on_error = handler

      @session.concurrent_connections = 10
    end

    def add_host(host)
      # get persistant object
      _load_sshdata host
      # setup ssh session
      @session.use host, :timeout => 30, :password => $password, :user => $user, :keys => '/home/REDACTED/.ssh/id_rsa'
    end

    def count_hosts
      @session.servers.count
    end

    def execute(sshtasks)
      #_define_execs
      load_tasks(parse_tasks(sshtasks))
      lasttick = Time.now - 60
      block = Proc.new do |c|
        if Time.now > lasttick
          lasttick = Time.now + 60
          puts "#{Time.now}--Open connections: #{c.open_connections}"
        end
        c.busy?
      end
      begin
      @session.loop(15, &block)
      rescue
        puts $ERROR_INFO
        puts $ERROR_POSITION
      end


    end

    def save
      @hosts.each_value do |o|
        o.save
      end
      @taskcounts.each do |type, count|
        puts "Task type: #{type}: #{count}"
      end
    end

    def _load_sshdata(host)
      o = SshData.first_or_new({:hostname => host})
      @hosts["#{host}"] = o
    end

    def parse_tasks(sshtasks)
      tasks = []
      valid_task_names = SshTask.constants.select {|c| SshTask.const_get(c).is_a? Class}
      sshtasks.each do |name|
        tasks.push valid_task_names.select {|s| s.to_s == name }[0] unless nil?
      end
      tasks
    end

    def load_tasks(tasks)

      tasks.each do |task|
        @session.open_channel do |channel|
          channel.request_pty do |c, success|
            result = String.new
            raise "could not request pty" unless success
            #
            c.exec SshTask.const_get(task).command
            #
            # STDOUT...
            c.on_data do |c_, data|
              #host = channel[:host]
              if data =~ /\[sudo\]/ || data =~ /[Pp]assword/i
                c.send_data $password += "\n"
              else
                result = result.concat data
              end
            end
            #
            # STDERR...
            c.on_extended_data do |c_, data|
              if data =~ /\[sudo\]/ || data =~ /[Pp]assword/i
                c.send_data $password += "\n"
              else
                result = result.concat data
              end
            end
            #
            c.on_close do |c_, data|
              host = c[:host]
              attributes = SshTask.const_get(task).parse(host, result, @db)
              SshTask.const_get(task).save(@hosts, host, attributes)
              @taskcounts[task] ||=0
              @taskcounts[task] += 1
            end
          end
        end
      end
    end

    def _save_ssh_data(host, attributes)
      o = @hosts["#{host}"]
      o.attributes = attributes
      o.save
    end

    def save_error(host, action, message)
      @db.save_error(host, action, message)
    end
  end
end
