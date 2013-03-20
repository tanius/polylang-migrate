#!/usr/bin/env ruby

# Little script that can create a SQL script for converting WordPress post titles from one language to another,
# according to Polyglot compatible translations provided as an input file.
#
# This is a workaround for a bug in the Polyglot WordPress plugin, by which title translations get lost in WordPress
# WXR exports. For usage instructions, see http://ma.juii.net/blog/migrate-to-polylang
#
# @author matthias <matthias at ansorgs dot de>
# @licence GPL Version 3 (or at your option, any later version) http://www.gnu.org/licenses/gpl-3.0-standalone.html
#   Copyright (C) 2013 Matthias Ansorg. This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you
#   are welcome to redistribute it under certain conditions. Refer to the link above for licence details.
#
# @todo Currently, the functions will convert from en+it polylang markup to Italian resp. English only. Make these
#   generic instead (to_lang(string, lang)).

require 'rubygems'

TARGET_LANG = 'it'

# Name of a text file that contains polyglot strings, one per line.
polyglot_file = ARGV[0]

# Name of the file to create that will contain strings without the polyglot markup, for one language only.
depolyglot_file = ARGV[1]

## Convert a Polyglot compatible HTML string with <lang_en> and <lang_it> to its English version, without these tags.
def to_english(html_string)
  # The regex literal syntax using %r{...} allows '/' in the regex without escaping.
  # The 'm' modifier makes the regex match also \n, allowing to eliminate tags that span multiple lines.
  # The '?' makes the .+ non-greedy, as to match at the first possible closing tag rather than the last possible one,
  # which might eliminate whole sections of <lang_en> text as well.
  html_string = html_string.gsub( %r{<lang_it>.+?</lang_it>}m, '' )
  html_string = html_string.gsub( %r{</?lang_it>}, '' ) # Lone half-tags from corrupted documents.
  html_string = html_string.gsub( %r{</?lang_en>}, '' )
end

def to_italian(html_string)
  # The regex literal syntax using %r{...} allows '/' in the regex without escaping.
  html_string = html_string.gsub( %r{<lang_en>.+?</lang_en>}m, '' )
  html_string = html_string.gsub( %r{</?lang_en>}, '' ) # Lone half-tags from corrupted documents.
  html_string = html_string.gsub( %r{</?lang_it>}, '' )
end

# Read the input file into an array, chomp'ing off the the closing \n of each line.
# Source: http://stackoverflow.com/a/2698009/1270008
lines = open(polyglot_file).map { |line| line.chomp! }


# Write the SQL statements to convert the titles.
File.open(depolyglot_file, 'w') do |f|

  lines.each do |line|
    # Here we need to duplicate single quotation marks to escape them for SQL.
    f.write("UPDATE wp_posts SET post_title='#{to_italian(line).gsub(/'/,"''")}' WHERE post_title='#{to_english(line).gsub(/'/,"''")} (Italiano)';\n")
  end

end
