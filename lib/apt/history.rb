require 'date'

module Apt
  class History
    FILEPATH = "/var/log/apt/history.log"

    attr_accessor :start_date, :commandline, :package, :action, :requested_by, :end_date

    def self.parse(reader)
      result = []
      current = nil

      reader.each do |line|
        line.chomp!
        if line.length == 0
          if current
            result <<= current
            current = nil
          end
          next
        end

        current = new unless current

        tag, data = line.split(/: /, 2)
        case tag
        when /^(Start|End)-Date$/
          r = tag.downcase.gsub("-","_").concat("=").to_sym
          d = DateTime.parse(data)
          current.send(r, d)
        when /^(Commandline|Requested-By)$/
          r = tag.downcase.gsub("-","_").concat("=").to_sym
          current.send(r, data)
        when /^(Install|Upgrade|Reinstall|Remove|Purge)$/
          current.package = data.split(/(?<=\)), /)
          current.action  = tag.downcase.to_sym
        end
      end

      return result
    end
  end
end

