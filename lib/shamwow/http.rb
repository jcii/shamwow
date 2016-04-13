require 'shamwow/db'
require 'net/http'
require 'json'

module Shamwow
  class Http
    def initialize
      @layer1 = []
      @layer2 = []
      @layer3 = []

    end

    def get(url)
      uri = URI(url)
      Net::HTTP.get(uri) # => String
    end

    def remove_header(data)
      data.gsub!(/^.+records\n/,'') || data
    end

    def parse_layer1(data)

      data.each_line do |l|
        next if l.match(/^\s*$/)
        line = l.chomp
        m = nil
        m = line.match(/^([\w\-_\.]+):\s+([\w\/:\-]+|Port-channel\s\d+)\s+(\w+)\s*(.*)$/)
        p line if m.nil?
        @layer1.push(m)
      end
      @layer1
    end

    def save_all_layer1()
      polltime = Time.now
      @layer1.each do |m|
        o = Layer1Data.first_or_create({:ethswitch => m[1], :interface => m[2]})
        o.attributes= { :linkstate => m[3], :description => m[4], :polltime => polltime }
        o.save
      end
    end

    def parse_layer2(data)
      data.each_line do |l|
        next if l.match(/^\s*$/)
        line = l.chomp

        m = nil
        m = line.match(/^([\w\-_\.]+):\s+([\w\/:\-\,]+|Port-channel\s\d+)\s+(\w+)\s+(\w+)$/)
        if m.nil?
          p line
        else
          @layer2.push(m)
        end
      end
      @layer2
    end

    def save_all_layer2()
      polltime = Time.now
      @layer2.each do |m|
        o = Layer2Data.first_or_create({:ethswitch => m[1], :interface => m[2], :macaddress => m[3]})
        prefix = m[3][0..5]
        o.attributes= { :macprefix => prefix, :vlan => m[4], :polltime => polltime }
        o.save
      end
    end

    def parse_layer3(data)
      data.each_line do |l|
        next if l.match(/^\s*$/)
        line = l.chomp

        m = nil
        #admin-fw.som1.marchex.com: ge-0/0/2.0 deadbeefdb95 10.30.10.83  db-bil1qa-a-r1.som1.marchex.com
        m = line.match(/^([\w\-_\.]+):\s+([\w\/:\-\,\._]+|Port-channel\s\d+)\s+(\w+)\s+([\d\.]+)\s+([\w\.\-_]+)$/)
        if m.nil?
          p line
        else
          @layer3.push(m)
        end
      end
      @layer3
    end

    def save_all_layer3()
      polltime = Time.now
      @layer3.each do |m|
        o = Layer3Data.first_or_create({:ipgateway => m[1], :port => m[2], :macaddress => m[3], :ipaddress => m[4]})
        prefix = m[3][0..5]
        o.attributes= {  :macprefix => prefix, :rdns => m[5], :polltime => polltime }
        o.save
      end
    end

    def parse_zenoss_snmp(text)
      nowtime = Time.now
      data = JSON.parse(text)
      data["nodes"].each do |n|
        o = SnmpNodeData.first_or_create( { :hostname => n["hostname"]})

        o.attributes={ :snmp_loc  => n["snmp_loc"],
                       :ip        => n["ip"],
                       :os_model  => n["os_model"],
                       :snmp_desc => n["snmp_desc"],
                       :serial    => n["serial"],
                       :snmp_name => n["snmp_name"],
                       :hw_make   => n["hw_make"],
                       :os_make   => n["os_make"],
                       :hw_model  => n["hw_model"],
                       :polltime  => nowtime
        }
        o.save
        ifaces = n["ifaces"]
        ifaces.each do |k,v|
          oi = o.snmp_node_iface.first_or_new({ :ifacename => k })
          oi.attributes= {
              #:SnmpNodeData_id => o.id,
              :macaddr => v["macaddr"],
              :description => v["description"],
              :speed => v["speed"],
              :ipaddr => v["ipaddr"],
              :state => v["state"],
              :admin_state => v["admin_state"],
              :type => v["type"],
              :polltime => nowtime
          }
          #o.SnmpNodeIface << oi
          begin
            oi.save
          rescue
            Shamwow::Ssh._save_error(n["hostname"], 'Http::parse_zenoss_snmp', "#{$ERROR_INFO} #{v}")
          end
        end
        o.save
      end
    end
  end
end

