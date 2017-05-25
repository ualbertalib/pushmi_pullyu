# create pushmi_pullyu container from source.
# entry point is bash to allow running of rake and other tests by a developer.

FROM ruby:2.3.4

RUN mkdir /app
WORKDIR /app

ADD Gemfile /app/
ADD pushmi_pullyu.gemspec /app/
ADD . /app
RUN cd /app && bundle install

CMD ["bundle", "exec", "pushmi_pullyu", "start", "-C", "/app/docker/files/pushmi_pullyu_config_docker.yml"]
