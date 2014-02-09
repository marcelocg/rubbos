#! /usr/bin/python

import fnmatch
import os
import sys, string

for root, dirnames, filenames in os.walk(sys.argv[1]):
  for filename in fnmatch.filter(filenames, '*.txt'):
      print os.path.join(root, filename)
      with open(os.path.join(root, filename), 'r') as log:
            lines = log.readlines()
            workload = int(string.strip(string.split(lines[1])[1]))
            print 'Workload: ', workload
            servers = int(string.strip(string.split(string.split(lines[2], ":")[1])[0]))
            print 'Servers: ', servers
            instance = string.strip(string.split(lines[3], ":")[1])
            print 'Instance: ', instance
