require 'data_mapper'
module Shamwow

  class ErrorData
    include DataMapper::Resource

    property :id,           Serial
    property :timestamp,    DateTime
    property :hostname,     String
    property :action,       String
    property :message,      String,   :length => 200
  end

end