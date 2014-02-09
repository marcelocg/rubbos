#! /usr/bin/python

import gspread, glob, string

gc = gspread.login(<USR>, <PWD>)
wks = gc.open("Rubbos Results").sheet1
workload_colums = {}
for idx, val in enumerate(wks.row_values(2)[1:]):
   if val <> None:
      workload_colums[int(val)] = (idx + 2)

print workload_colums

for file in glob.glob("*.txt"):
   with open(file, 'r') as log:
      lines = log.readlines()
      workload = int(string.strip(string.split(lines[1])[1]))
      servers = int(string.strip(string.split(string.split(lines[2], ":")[1])[0]))
      instance = string.strip(string.split(lines[3], ":")[1])
      
      try:
         cpu = float(string.strip(string.split(string.split(lines[7 + servers], ":")[2], "%")[0]))
      except ValueError:
         cpu = 0.0
      try:
         mem = float(string.strip(string.split(string.split(lines[7 + servers], ":")[3], "%")[0]))
      except ValueError:
         mem = 0.0

      count = string.split(lines[8 + servers], ":")[1]
      errors = string.split(lines[9 + servers])[1]
      resp = int(string.split(string.split(lines[10 + servers], ":")[1])[0])
      nth_percent = int(string.split(string.split(lines[11 + servers], ":")[1])[0])
      thrput = int(string.split(string.split(lines[12 + servers], ":")[1])[0])
      #print workload, servers, instance, cpu, mem, count, errors, resp, thrput

      instance_cell = wks.find(instance)
      base_row = instance_cell.row + (servers -1)
      base_col = workload_colums[workload]

      wks.update_cell(base_row, base_col, resp)
      wks.update_cell(base_row, base_col+1, nth_percent)
      wks.update_cell(base_row, base_col+2, thrput)
      wks.update_cell(base_row, base_col+3, "="+errors+"/"+count+"*100")
      wks.update_cell(base_row, base_col+4, "=100-"+str(cpu))
      wks.update_cell(base_row, base_col+5, mem)
      
