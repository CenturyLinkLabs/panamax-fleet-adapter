module FleetAdapter

  module StringExtensions
    refine String do
      def sanitize
        gsub(/[\W_]/, '-').downcase
      end
    end
  end

end
