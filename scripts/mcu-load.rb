#!/usr/bin/env ruby

require 'selenium-webdriver'
require 'net/http'
require 'optparse'

DEFAULT_INSTANCE_NUM = 1
DEFAULT_BUTTON_TIMEOUT_SEC = 10
DEFAULT_TEST_DURATION_SEC = 5
SELENIUM_HUB_URLS = ["http://localhost:4444/wd/hub"]
CHROME_SWITCHES = %w[ --use-fake-device-for-media-stream --use-fake-ui-for-media-stream]

def is_integer(arg)
  return arg =~ /\A\d+\z/
end

def is_present(arg)
  return !(arg.nil?)
end

def runTest
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage:  [options]"

    opts.on('-n', '--number NUMBER', 'number of clients to load') do |v|
      options[:number] = v 
    end
    opts.on('-h', '--host HOST', "host url") do |v| 
      options[:host] = v
    end
    opts.on('-d', '--duration DURATION_IN_SEC', "duration of test in seconds") do |v| 
      options[:duration] = v
    end

  end.parse!

  if !is_present(options[:host])
    print 'Enter host url: '
    options[:host] = gets.chomp
  end
  
  instance_num = is_integer(options[:number]) ? Integer(options[:number]) : DEFAULT_INSTANCE_NUM
  test_duration_sec = is_integer(options[:duration]) ? Integer(options[:duration]) : DEFAULT_TEST_DURATION_SEC
  url = options[:host]

  puts "*********** Options ***********"
  puts "Using instance number = #{instance_num}"
  puts "Test duration = #{test_duration_sec}"
  puts "Using host url = #{url}"
  puts "*********** Options ***********"

  $drivers = []

  http = Net::HTTP.new(SELENIUM_HUB_URLS)
  #http.read_timeout = 120000

  for hub in SELENIUM_HUB_URLS
    (1..instance_num).each do |n|

      driver = Selenium::WebDriver.for(:chrome, :url => hub, :switches => CHROME_SWITCHES)
      $drivers.push(driver)

      driver.get 'chrome://webrtc-internals'

      origWindow = driver.window_handles.last() ; printTitle()
      driver.execute_script("window.open('#{url}')")

      newWindow = driver.window_handles.last()
      driver.switch_to.window(newWindow) ; printTitle()

      # for apprtc.appspot.com
      # click(description: 'join',
      #       element: driver.find_elements(:id, 'confirm-join-button'),
      #       timeout: DEFAULT_BUTTON_TIMEOUT_SEC)
      
      puts "waiting for test duration of #{test_duration_sec} seconds..."
      sleep test_duration_sec

      driver.switch_to.window(origWindow) ; printTitle()

      click(description: 'create dump',
            element: driver.find_elements(:xpath, '//*[@id="content-root"]/details/summary'),
            timeout: DEFAULT_BUTTON_TIMEOUT_SEC)

      click(description: 'download dump',
            element: driver.find_elements(:xpath, '//*[@id="content-root"]/details/div/div/a/button'),
            timeout: DEFAULT_BUTTON_TIMEOUT_SEC)

#      closeWindows
    end
  end
end

def printTitle
  puts "driver operating on tab => #{$drivers[0].title}"
end

def click(options)
  description = options[:description] ? options[:description] : "NO DESCRIPTION"
  timeout = options[:timeout] ? options[:timeout] : DEFAULT_BUTTON_TIMEOUT_SEC
  element = options[:element][0]
  
  if element
    timeout_message = "Waited #{timeout} seconds but '#{description}' element still not displayed"
    wait = Selenium::WebDriver::Wait.new(:timeout => timeout, 
                                         :message => timeout_message)
    wait.until { element.displayed? }
    element.click()
  else
    abort("ABORT: Element with description '#{description}' not found!")
  end
end

def closeWindows
  for driver in $drivers
    for window in driver.window_handles()
      puts "closing window => #{window}"
      driver.switch_to.window(window)
      driver.close()
    end
  end
end

def shutdown
  puts 'Shutting down'
  for driver in $drivers 
    driver.quit()
  end
  exit
end

def waitForSigTerm
  trap('SIGTERM') {shutdown}
  trap('INT') {shutdown}
  loop {sleep 300000}
end  

runTest
waitForSigTerm
