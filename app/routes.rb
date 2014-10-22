module FleetAdapter

  API_VERSION = 'v1'

  module Routes
    autoload :Base, 'app/routes/base'
    autoload :Services, 'app/routes/services'
    autoload :Metadata, 'app/routes/metadata'
  end
end
