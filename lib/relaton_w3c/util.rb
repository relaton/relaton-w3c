module RelatonW3c
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonW3c.configuration.logger
    end
  end
end
