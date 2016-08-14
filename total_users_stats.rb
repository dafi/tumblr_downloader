#!/usr/bin/env ruby
# Extract some statistics from totalUsers.csv file
require 'date'

# 1 day
# 7 days (~1 week)
# 30 days (~1 month)
# 180 days (~6 months)
# 360 days (~1 year)
TEMPORAL_RANGE = [365, 180, 30, 7, 1].freeze

def show_stats(lines)
  (last_date, last_count) = date_count_from_line(lines.last)
  puts last_date.strftime("Last update %d/%m/%Y")

  # Add the oldest item (ie the first line) to temporal ranges
  oldest_date, = date_count_from_line(lines.first)
  temporal_range = [(last_date - oldest_date).to_i] + TEMPORAL_RANGE

  indexes = find_temporal_ranges(temporal_range, lines, last_date)

  print_statistics(indexes, last_count)
end

# Return the tuple date, count
def date_count_from_line(line)
  (date_str, _, count_str) = line.split(';')
  return Date.parse(date_str), count_str.to_i
end

def find_temporal_ranges(temporal_range, lines, last_date)
  indexes = {}

  lines.each do |l|
    (date, count) = date_count_from_line(l)
    days = (last_date - date).to_i
    added_closest_temporal_range(temporal_range, indexes, days, count)
  end

  return indexes
end

# add to indexes map the closest temporal range to days
def added_closest_temporal_range(temporal_range, indexes, days, count)
  index = temporal_range.index { |t| days >= t }
  if index
    range = temporal_range[index]
    indexes[range.to_s] = { 'days' => days, 'count' => count }
  end
end

def print_statistics(indexes, last_count)
  indexes.keys.reverse.each do |k|
    values = indexes[k]
    diff = last_count - values['count']
    puts sprintf "In %4d days passed from %5d to %5d (%+6d)",
      values['days'],
      values['count'],
      last_count,
      diff
  end
end

if ARGV.empty?
  puts 'Specify the csv files'
  exit
end

show_stats File.readlines(ARGV[0])
