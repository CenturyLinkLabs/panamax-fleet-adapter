FROM centurylink/ruby-base:2.1.2

RUN gem install sinatra fleet-api sinatra-contrib

ADD . /var/app/fleet-adapter

CMD ["ruby", "/var/app/fleet-adapter/fleet.rb"]
