#!/usr/bin/env ruby

# Script to split a WordPress WXR file into one that contains attachments and one for posts and pages.
#
# Both output files can be imported by WordPress after the splitting. This script is useful if importing the
# unsplit file gives you timeout errors (incl. 500 Internal Server Error). After the splitting, the attachments file
# might still lead to timeouts, but you can redo the import until it succeeds, while avoiding to upload the potentially
# big overhead of posts and pages every time. See http://ma.juii.net/blog/migrate-to-polylang for more background.
#
# @author matthias <matthias at ansorgs dot de>
# @licence GPL Version 3 (or at your option, any later version) http://www.gnu.org/licenses/gpl-3.0-standalone.html
#   Copyright (C) 2013 Matthias Ansorg. This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you
#   are welcome to redistribute it under certain conditions. Refer to the link above for licence details.

require 'rubygems'
require 'nokogiri'

wxr_infile = ARGV[0]
wxr_attachments_doc = Nokogiri::XML(File.open(wxr_infile))
wxr_posts_doc = wxr_attachments_doc.dup

wxr_attachments_outfile = wxr_infile.sub(/\.xml$/, '.attachments.xml')
wxr_posts_outfile = wxr_infile.sub(/\.xml$/, '.posts.xml')

# Delete post and pages items from the attachment document.
items = wxr_attachments_doc.xpath('//channel//item')
items.each do |item|
  if item.at_xpath('.//wp:post_type').content != 'attachment'
    item.unlink
  end
end

# Delete attachment items from the posts and pages document.
items = wxr_posts_doc.xpath('//channel//item')
items.each do |item|
  if item.at_xpath('.//wp:post_type').content == 'attachment'
    item.unlink
  end
end


# Write out the documents.

File.open(wxr_attachments_outfile, 'w') do |f|
  wxr_attachments_doc.write_xml_to(f, encoding: 'UTF-8', indent: 2)
end

File.open(wxr_posts_outfile, 'w') do |f|
  wxr_posts_doc.write_xml_to(f, encoding: 'UTF-8', indent: 2)
end
