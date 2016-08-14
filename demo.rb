#
# Sample script illustrating impact on memory usage when using lazy
# enumerators.
#
# NOTE: this doesn't work JRuby: https://github.com/jruby/jruby/pull/3814

require 'csv'

# calculates the total RSS usage of current Ruby process
def get_rss_usage()
  rss = 0
  open("/proc/#{Process.pid}/status").each do |line|
    if line.start_with?("Rss")
      pieces = line.split
      rss += pieces[1].to_i
    end
  end
  rss
end

# Generate a random data set
def generate_test_data()
  CSV.open("testdata.csv", "w") do |csv|
    (1..1_000_000).each do |i|
      csv << [rand(100), rand(10_000), rand(100_000)]
    end
  end
end

# Do some arbitrary processing on the csv data to calculate a value
def calculate(lazy: false)
  csv = CSV.open("testdata.csv")
  if lazy
    csv = csv.lazy
  end
  csv.map { |record|
    # convert to integers
    record.each_with_index do |val, i|
      record[i] = val.to_i
    end
    record
  }.select { |record|
    record[1] > 5000
   }.map { |record|
    record[0] += 1
    record
  }.reduce(0) { |acc, record|
    acc += record[0]
  }
end

cmd = ARGV[0]
if cmd == "generate_test_data"
  puts "Generating test data"
  generate_test_data()
elsif cmd == "calculate"
  lazy = ARGV[1]=="lazy"
  puts "Running in #{lazy ? "" : "non-"}lazy mode, calculating..."
  t_start = Time.now.to_f
  result = calculate(lazy: lazy)
  t_end = Time.now.to_f
  puts "Result: #{result}"
  puts "RSS memory usage: #{get_rss_usage()}"
  puts "Time: #{t_end - t_start}s"
else
  puts "specify one of these commands: generate_test_data calculate"
end
