#! /usr/bin/python

import sys
from bs4 import BeautifulSoup


if len(sys.argv) <> 3:
  print 'Usage: scrape <inputfile> <outputfile>'
  sys.exit(2)


try:
  with open(sys.argv[1], 'r') as content_file:
    stats = content_file.read()
    soup = BeautifulSoup(stats, "html5lib")
    tag = soup.find(text="Runtime session Total").parent.parent.parent

    with open(sys.argv[2], 'a') as log_file:
      log_file.write( "Transaction Count.: " + tag.next_sibling.next_sibling.text + '\n')
      log_file.write( "Errors............: " + tag.next_sibling.next_sibling.next_sibling.text + '\n')
      log_file.write( "Avg. Response Time: " + tag.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.text )
      log_file.write( "Throughput........: " + tag.parent.next_sibling.contents[1].text )

except IOError, Argument:
  print 'Error opening input file: ', Argument
  sys.exit(2)
