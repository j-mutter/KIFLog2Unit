#!/usr/bin/env ruby

require 'FileUtils'
require 'optparse'
require 'nokogiri'

class Testcase
	attr :name, true
	attr :time, true
	attr :description, true
	attr :status, true
	attr :message, true
	attr :error, true

	 def initialize
    @status = "PASS"
    @error = ""
  end

end


TEST_SUITE_NAME = "YOUR_TEST_SUITE_NAME"
verbose = false
needs_line_stripping = false  # becomes true if we're handling a log file created by dumping stdout to a file
re1='((?:2|1)\\d{3}(?:-|\\/)(?:(?:0[1-9])|(?:1[0-2]))(?:-|\\/)(?:(?:0[1-9])|(?:[1-2][0-9])|(?:3[0-1]))(?:T|\\s)(?:(?:[0-1][0-9])|(?:2[0-3])):(?:[0-5][0-9]):(?:[0-5][0-9]))'	# Time Stamp 1
re2='([+-]?\\d*\\.\\d+)(?![-+0-9\\.])'	# Float 1
re3='(\\s+)'	# White Space 1
re4='((?:[^\[]+))'	# Word 1
re5='(\\[.*?\\])'	# Square Braces 1
re6='(\\s+)'	# White Space 2
re=(re1+re2+re3+re4+re5+re6)

LINE_STRIP_REGEX=Regexp.new(re,Regexp::IGNORECASE);

failures_counter = 0


options = {}

optparse = OptionParser.new do|opts|
	opts.banner = "Usage: KIFLog2JUnit.rb -f INPUT_FILE -o OUTPUT_Directory"

	options[:input_file] = nil
	opts.on('-f', '--file INPUT_FILE', 'File to parse') do |input|
		options[:input_file] = input
	end

	options[:output_dir] = nil
	opts.on('-o', '--output OUTPUT_DIRECTORY', 'Output directory') do |output|
		options[:output_dir] = output
	end

	options[:verbose] = nil
	opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
		options[:verbose] = v
	end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end

end

optparse.parse!

verbose = true unless options[:verbose] == nil

# Handle options
if options[:input_file] == nil
	input_file = ARGV[0]
else
	input_file = options[:input_file]
end

if options[:output_dir] == nil
	output_dir = ARGV[1]
else
	output_dir = options[:output_dir]
end


if input_file == nil then abort("Fatal Error - Input file is required") end

if output_dir == nil
	puts "No output directory provided, defaulting to `pwd`/test-reports" if verbose
	output_dir = Dir.pwd + "/test-reports"
	FileUtils.mkpath output_dir unless File.exists? output_dir
	puts "PWD = #{output_dir}" if verbose
end


puts "Reading in #{input_file}" if verbose
puts "Outputing to #{output_dir}" if verbose

raise ArgumentError unless File.exists?(input_file)

@log = File.open(input_file)
file_timestamp = File.mtime(input_file)

#Find the start of the actual log by searching for the BEGIN KIF TEST RUN message
first_line = @log.readline
puts first_line if verbose
until first_line =~ /BEGIN KIF TEST RUN/ do
		first_line = @log.readline
		puts first_line if verbose
end
# See if we have to remove timestamps and junk...
if first_line =~ LINE_STRIP_REGEX
	puts "Encountered timestamps, enabling line stripping" if verbose
	needs_line_stripping = true
end

first_line.slice! first_line.scan(LINE_STRIP_REGEX).join("") if needs_line_stripping

n_scenarios = first_line.scan(/[\d]+/)[0].to_i;
puts "There are #{n_scenarios} scenarios in the log" if verbose

@tests = Array.new

1.upto(n_scenarios) do
	@testcase = Testcase.new
	line = @log.readline.strip
	line.slice! line.scan(LINE_STRIP_REGEX).join("") if needs_line_stripping
	divider_counter = 0
	#skip any empty lines between scenarios
	while line.empty? do
		line = @log.readline.strip
		line.slice! line.scan(LINE_STRIP_REGEX).join("") if needs_line_stripping
	end

	while divider_counter < 4 do
		if line.end_with?("-----------") 
			divider_counter = divider_counter + 1
		else
			#parse based on what section of the log we're in
			if divider_counter == 1
				# get the testcase description
				@testcase.description = @log.readline.strip
			end

			if divider_counter == 2
				# Look for failures
				if line.start_with?("FAIL ")
					@testcase.status = "FAIL"
					@testcase.message = line.scan(/(: )([^\n]*)$/)[0][1]
					failures_counter = failures_counter + 1
				end

				# if we've failed, make sure we have the whole message and/or error
				if @testcase.status == "FAIL"
					# if the line doesn't start with either PASS or FAIL, there was probably a newline in either the error or message
					if not line.start_with?("FAIL ") and not line.start_with?("PASS")
						if line.start_with?("FAILING ERROR")
							@testcase.error = line.scan(/(: )([^\n]*)$/)[0][1]
						# if we haven't assigned an error yet, this is more of the message
						elsif @testcase.error.empty?
							@testcase.message << "\n #{line}"
						# if we've assigned an error and we have a broken line, it's part of the error
						else
							@testcase.error << "\n #{line}"
						end
					end
				end
			end

			if divider_counter == 3
				# Get the total time from the summary
				@testcase.time = line.scan(/[\d\.]+/)[0].to_f
			end

		end
		line = @log.readline.strip
		line.slice! line.scan(LINE_STRIP_REGEX).join("") if needs_line_stripping
	end

	@tests << @testcase

end

xml_builder = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
	xml.testsuite(:errors => "0", :failures => failures_counter, :hostname => "mobilemini.local", :name => TEST_SUITE_NAME , :tests => n_scenarios, :timestamp => file_timestamp){
		@tests.each do |test|
			xml.testcase(:classname => TEST_SUITE_NAME, :name => test.description, :time => test.time){
				if test.status.eql?("FAIL")
					xml.failure test.error, :message => test.message, :type => "Failure"
				end
			}
		end
	}

end

puts "Final XML is: \n #{xml_builder.to_xml}" if verbose

output_filename = output_dir + "/"+ File.basename(File.expand_path(input_file), '.*') + ".xml"
puts "Saving to #{output_filename}" if verbose

@output = File.open(output_filename, 'w')
@output.write(xml_builder.to_xml)
@output.close


