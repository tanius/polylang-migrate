#!/usr/bin/env ruby

# Script to read a WordPress WXR file and create SQL code to that will create copies of these tags, in another
# language, and add the Polylang meta information accordingly for the language and the connection to the other
# translation.
#
# Usage: polylang-localize-tags.rb wxrfile.xml <next-term-id>
#
# The SQL-only approach in this script is better than generating a WXR file for importing new tags, and SQL for the
# meta information only. Because in that alternative, it can happen that some tags are not imported because of
# existing duplicates, and this will be silently ignored by the importer without any message. Assigning the metadata
# by SQL will then refer to wrong tag IDs, creating a big mess.
#
# @author matthias <matthias at ansorgs dot de>
# @licence GPL Version 3 (or at your option, any later version) http://www.gnu.org/licenses/gpl-3.0-standalone.html
#   Copyright (C) 2013 Matthias Ansorg. This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you
#   are welcome to redistribute it under certain conditions. Refer to the link above for licence details.

require 'rubygems'
require 'nokogiri'

wxr_infile = ARGV[0]
wxr_doc = Nokogiri::XML(File.open(wxr_infile))

next_term_id = ARGV[1].to_i

# Array of {en: <term_id>, it: <term_id>} hashes, connects the different language versions of tags.
tags = Array.new


# Traverse all tags and gather all relevant information from the XML structure.
tags_dom = wxr_doc.xpath('//channel//wp:tag')
tags_dom.each do |tag|

  # If the term does not belong to the post tag taxonomy, ignore it.
  if tag.xpath('.//wp:tag_slug').size == 0 then
    next
  end

  tags << {
    en: {
      id: tag.at_xpath('.//wp:term_id').content,
      slug: tag.at_xpath('.//wp:tag_slug').content,
      name: tag.at_xpath('.//wp:tag_name').content
    },
    it: {
      id: next_term_id,
      slug: tag.at_xpath('.//wp:tag_slug').content + '-it',
      name: tag.at_xpath('.//wp:tag_name').content
    }
  }

  next_term_id += 1
end



# Write a SQL file that adds the meta information to these tags.
File.open("#{wxr_infile}.tagmeta.sql", 'w') do |f|
  tags.each do |tag|

    # f.write("UPDATE wp_termmeta" +
    #         "  SET meta_key = '_translations', meta_value = 'a:2:{s:2:\"it\";i:#{tag_map[tag_slug_it]};s:2:\"en\";i:#{tag_map[tag_slug_en]};}'" +
    #         "  WHERE term_id = #{tag_map[tag_slug_en]} OR term_id = #{tag_map[tag_slug_it]};\n")

    # Only create the Italian tags, as the English ones already exist.
    f.write("INSERT INTO wp_terms (term_id, name, slug) VALUES ( #{tag[:it][:id]}, '#{tag[:it][:name].gsub(/'/,"''")}', '#{tag[:it][:slug].gsub(/'/,"''")}' );\n")
    f.write("INSERT INTO wp_term_taxonomy (term_id, taxonomy) VALUES ( #{tag[:it][:id]}, 'post_tag' );\n")
    f.write("INSERT INTO wp_termmeta (term_id, meta_key, meta_value) VALUES ( #{tag[:it][:id]}, '_language', 1561 );\n")

    # Add the connection to the other (original English) translation.
    f.write("INSERT INTO wp_termmeta (term_id, meta_key, meta_value) VALUES ( #{tag[:en][:id]}, '_translations', 'a:2:{s:2:\"it\";i:#{tag[:it][:id]};s:2:\"en\";i:#{tag[:en][:id]};}' );\n")
    f.write("INSERT INTO wp_termmeta (term_id, meta_key, meta_value) VALUES ( #{tag[:it][:id]}, '_translations', 'a:2:{s:2:\"it\";i:#{tag[:it][:id]};s:2:\"en\";i:#{tag[:en][:id]};}' );\n")

    f.write("\n")
  end
end
