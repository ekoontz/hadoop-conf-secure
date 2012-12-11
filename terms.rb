#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'

load 'scpt.rb'

# Loads a YAML config file and generates a Mac OS X Applescript file that opens terminals for
# for hosts in the config file, tailing the file of each.
# usage: terms.rb <configfile.yaml>
# see example.yaml for an example config file.

if ARGV.size == 0
  abort "usage: terms.rb <configfile.yaml>"
end

conf = YAML.load_file ARGV.shift

nn1 = conf['nn1']
nn2 = conf['nn2']
nn1log = conf['nn1log']
dn1 = conf['dn1']
nn1log = conf['dn1log']
zk = conf['zk']

write_term_script "terms.scpt", [
                                 [conf['nn1'], conf['jnlog'],    "{250,1825,1500,540}", "jn",
                                  "cd hadoop-conf && make format-and-start-jn"],

                                 [conf['zk'],  nil,              "{1350,475,1800,420}", "zk",
                                  "cd hadoop-conf && make start-zk"],

                                 [conf['nn1'], conf['zkfc1log'], "{ 250,925,1500,420}", "zkfc1",
                                 "cd hadoop-conf && make start-zkfc"],

                                 [conf['dn1'], conf['dn1log'],   "{250,475, 1500,300}", "dn",
                                  "cd hadoop-conf && make format-and-start-dn"],

                                 [conf['nn1'], conf['nn1log'],   "{250,25,  1500,180}", "nn",
                                  "cd hadoop-conf && make format-and-start-master"],

                                 [conf['nn2'], conf['zkfc2log'], "{250,2725,1500,780}", "zkfc2",
                                  "ssh #{nn2} '. .bash_profile && cd hadoop-conf && make stop && make clean-logs && make start-zkfc'"],

                                 [conf['nn2'], conf['nn2log'],   "{250,2275,1500,660}", "nn2",
                                  "ssh #{nn2} '. .bash_profile && cd hadoop-conf && sleep 30 && make start-standby-nn-on-guest'"]


                                ]

