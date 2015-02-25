FROM ruby:2.1.2

RUN gem install selenium && selenium install && gem install selenium-webdriver 

ADD ./scripts/ /home/root/scripts

EXPOSE 4444 5999

ENTRYPOINT ["/home/root/scripts/mcu-load.rb"]
