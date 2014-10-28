module FleetAdapter
  module Models
    class ServiceSorter
      require 'set'

      def self.sort(services)
        @services = services
        @unmarked = Array.new(@services)
        @temporary_marked = Set.new
        @sorted_services = []

        until @unmarked.empty?
          visit(@unmarked[-1])
        end

        return @sorted_services
      end


      def self.visit(n)
        if @temporary_marked.include?(n[:name])
          if get_service_names_for(n[:links]).include?(n[:name])
            raise "An image can not link to itself: #{n[:name]}"
          else
            raise "Circular import between #{n[:name]} and #{@temporary_marked}"
          end
        end

        if @unmarked.include?(n)
          @temporary_marked.add(n[:name])
          @services.each do |service|
            if get_service_names_for(service[:links]).include?(n[:name])
              n[:deployment][:count] = 1 if n[:deployment]

              exposed_ports = n[:ports].map do |exposed_port|
                { :port => exposed_port[:hostPort], :protocol=> (exposed_port[:protocol] || 'tcp') }
              end

              exposed_ports.merge!(n[:expose]).map { |exposed_port| {:port => exposed_port, :protocol => 'tcp'}} if n[:expose]

              min_port = exposed_ports.sort_by{ |exposed_port| exposed_port[:port] }.first

              service[:links].find{ |link| link[:name] == n[:name] }.merge!({:port => min_port[:port], :protocol => min_port[:protocol]})
              visit(service)
            end
          end
          @temporary_marked.delete(n[:name])
          @unmarked.delete(n)
          @sorted_services.insert(0, n)
        end

        return @sorted_services
      end
      private_class_method :visit



      def self.get_service_names_for(links)
        links ||= []
        links.map { |link| link[:name] }
      end
      private_class_method :get_service_names_for

    end
  end
end