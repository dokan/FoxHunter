#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "optparse"

AIRPORT = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport"

class FoxHunter
  def initialize(conf_file, target)
    @target = target
    @white_list = {
      :ssid  =>  ["SSID"],
      :bssid => []
    }

    unless conf_file.nil?
      open(conf_file).each do |line|
        line.chomp!
        line.slice!(/#.*$/)
        line.strip!
        
        next if line == ""
        
        if check_mac(line)
          @white_list[:bssid] << line.downcase
        else
          @white_list[:ssid] << line
        end
      end
    end
  end
  
  def get_foxes
    @time  = Time.now.strftime("%m/%d %H:%M:%S")
    @foxes = []
    
    IO.popen("#{AIRPORT} --scan") do |io|
      while line = io.gets
        line.strip! =~ /^(.+?)\s+(([a-f0-9]{2}:){5}[a-f0-9]{2})\s+(|-\d+)\s+(\S+)/
        if $1.nil?
          next
        end
        
        wireless = {
          :ssid    => $1,
          :bssid   => $2,
          :rssi    => $4,
          :channel => $5
        }

        if @target.nil?
          unless @white_list[:ssid].include?(wireless[:ssid]) || @white_list[:bssid].include?(wireless[:bssid])
            @foxes << wireless
          end
        else
          if check_mac(@target)
            if wireless[:bssid] == @target
              @foxes << wireless
            end
          else
            if wireless[:ssid] == @target
              @foxes << wireless
            end
          end
        end
      end
    end
  end
  
  def find_fox?
    return @foxes.size != 0
  end
  
  def print_foxes
    system("clear")
    puts @time
    
    @foxes.each do |fox|
      ssid_space = 32 - fox[:ssid].size
      puts "SSID  : #{fox[:ssid]}#{" " * ssid_space}\tRSSI  : #{fox[:rssi]}\tCHANNEL  : #{fox[:channel]}\tBSSID  : #{fox[:bssid]}"
    end
  end

  private
  def check_mac(target)
    target =~ /^([a-f0-9]{2}:){5}[a-f0-9]{2}$/i
  end
end

if __FILE__ == $0
  
  Signal.trap(:INT){
    puts
    exit(0)
  }
  
  conf_file = nil
  target = nil
  OptionParser.new do |parser|
    parser.on('-c [config file]', '--conf [config file]', 'Load config file') {|v| conf_file = v}
    parser.on('-t [SSID or BSSID]', '--target [SSID or BSSID]', 'Only check Target Fox') {|v| target = v}
    parser.parse!(ARGV)
  end

  if conf_file.nil? && target.nil?
    STDERR.puts("Load default config \"./white_list.conf\"")
    conf_file = "./white_list.conf"
  end
  
  fox_hunter = FoxHunter.new(conf_file, target)
  while true
    fox_hunter.get_foxes    
    fox_hunter.print_foxes if fox_hunter.find_fox?
  end
end
