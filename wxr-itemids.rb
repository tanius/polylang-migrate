#!/usr/bin/env ruby

# Script to count and output the item IDs contained in a WordPress WXR file.
#
# Usage: wxr-itemids.rb wxrfile.xml
#
# @author matthias <matthias at ansorgs dot de>
# @licence GPL Version 3 (or at your option, any later version) http://www.gnu.org/licenses/gpl-3.0-standalone.html
#   Copyright (C) 2013 Matthias Ansorg. This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you
#   are welcome to redistribute it under certain conditions. Refer to the link above for licence details.

require 'rubygems'
require 'nokogiri'

wxr_infile = ARGV[0]
wxr_doc = Nokogiri::XML(File.open(wxr_infile))

items = wxr_doc.xpath("//channel//item")

puts 'Count of items found: ' + items.size.to_s

items.each do |item|
  puts item.at_xpath('.//wp:post_id').content
end
