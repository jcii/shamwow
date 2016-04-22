require 'net/ssh'
require 'shamwow/db'
require 'json'


module Shamwow
  class Knife
    def initialize
      @nodes = {}
      @@errors = []
      @@errortypes = {}
    end

    def get_status(fromhost)
      Net::SSH.start(fromhost, $user) do |ssh|
        ssh.exec!("knife status -F json 'fqdn:*'")
      end
    end

    def parse_status(output)
      nowtime = Time.now
      data = JSON.parse(output)
      data.each do |n|
        #p n
        o = KnifeData.first_or_new( { :name => n["name"] })

        o.attributes={ :chefenv => n["chef_environment"],
                       :ip => n["ip"],
                       :ohai_time => Time.at(n["ohai_time"]).to_datetime,
                       :platform => n["platform"],
                       :platform_version => n["platform_version"],
                       :polltime => nowtime }
        @nodes["#{n[:name]}"] = o
        o.save
      end
    end

    def get_knife_cookbooks(fromhost)
      Net::SSH.start(fromhost, $user) do |ssh|
        ssh.exec!("knife search node 'fqdn:pulley*' -a cookbooks -Fj")
      end
    end
    # {
    #     "results": 1,
    #     "rows": [
    #       {
    #           "pulleyserver1.sea1.marchex.com": {
    #             "cookbooks": {
    #                 "apt": {
    #                   "version": "1.9.0"
    #                 }
    def parse_cookbooks(output)
      nowtime = Time.now
      data = JSON.parse(output)
      data["rows"].each do |hash|
        (name, obj) = hash.first
        next if obj["cookbooks"].nil?
        o = KnifeData.first_or_new( { :name => name })
        obj["cookbooks"].each do |ckbk, attrs|
          c = o.cookbooks.first_or_new({ :name => ckbk })
          c.attributes = {
              :version => attrs["version"],
              :polltime => nowtime
          }
          c.save
        end
        o.attributes = { :polltime => nowtime }
        o.save
      end
    end


    def get_records
      @nodes
    end

    def save_records
      nodes.each_value do |o|
        o.save
      end

      @@errortypes.each do |type, count|
        puts "Error type: #{type}: #{count}"
      end
    end

    def expire_records(expire_time)
      stale = KnifeData.all(:polltime.lt => Time.at(Time.now.to_i - expire_time))
      puts "#{Time.now} Expiring #{stale.count} Knife status records"
      stale.destroy
    end
  end
end

