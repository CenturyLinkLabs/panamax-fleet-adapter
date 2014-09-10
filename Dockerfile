FROM centurylink/ruby-base:2.1.2

ADD . /var/app/fleet-adapter
WORKDIR /var/app/fleet-adapter
RUN bundle install

CMD ["ruby", "/var/app/fleet-adapter/fleet.rb"]
