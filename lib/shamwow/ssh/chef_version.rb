
module Shamwow; module SshTask; class Chef_version
    #
    def self.command
      'chef-client --version'
    end
    #
    # commoon output from command
    #   ffi-yajl/json_gem is deprecated, these monkeypatches will be dropped shortly
    #   Chef: 11.16.4

    def self.parse(data)
      ver = data.match(/Chef: ([\w\.]+)/)[1]
      {
          :chefver => ver,
          :chefver_polltime => Time.now
      }
    end
  end

end;
end;