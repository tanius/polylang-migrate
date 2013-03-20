#!/usr/bin/env ruby

# Script to migrate a WordPress blog from the Polyglot plugin to using teh Polylang plugin, by modifying a WXR
# file exported from WordPress.
#
# Documentation:
#  http://ma.juii.net/blog/migrate-to-polylang
# Calling (alternatives):
#   polyglot2polylang.rb infile.wxr outfile.wxr next_post_id
#   polyglot2polylang.rb infile.wxr outfile.wxr next_post_id > log.txt
#
# Be sure to check your XML file with a syntax checker before feeding it to this script. Else, unexpected behavior
# can occur. For example, an unexpected closing tag with no corresponding opening tag will cause nokogiri to consider
# the current item as the last one, without any hint or warning. Which means that not all posts of the blog will be
# processed.
#
# For example, this will print parser errors on stdout, to ensure the document is well-formed HTML: xmllint --noout
#
# WordPress Polylang plugin is this one: http://wordpress.org/extend/plugins/polylang/
# WordPress Polyglot plugin is this one: http://fredfred.net/skriker/index.php/polyglot/lang/cs/ (no longer maintained)
#
# This script can be easily modified to convert also from any other multilingual plugin that works by introducing a
# special tag to mark multilingual content.
#
# Notes on the WXR file format:
# -- The wp:post_name tag contains the currently active "slug". If the URL is configured to include it, it will be
#    generated from this when importing. Which means that the content of tag "link" is just redundant and will not
#    be regarded.
# -- When importing a WXR file in WordPress, it is required that each item (post or page) has a title tag that's
#    different from all existing and previously imported item titles, or it will fail to import with
#    "Post “...” already exists.". This is also true if the original post only exists in the trashbin.
# -- When importing a WXR file and an item's wp:post_name is the same as an existing ones, WordPress will generate
#    a unique version by appending "-2" and similar.
# -- When changing a post's slug in WordPress, it generates 302 forwarders from the old to the new URL. In WXR files,
#    these are saved in one or multiple <wp:postmeta> tag groups which contain the <wp:meta_key>_wp_old_slug</wp:meta_key>
#    key.
#
# General notes:
# -- In XPath, paths starting with '//' refer to the whole document (in contradiction to some documentation!). If you
#    want to start the search at the current node instead, use './/' instead. When traversing the items, each item
#    is just a reference into the whole DOM tree, with item being its current node. That's why searching with an
#    '//' XPath only will find exactly the same result set for every item that is traversed.
#
# @author matthias <matthias at ansorgs dot de>
# @licence GPL Version 3 (or at your option, any later version) http://www.gnu.org/licenses/gpl-3.0-standalone.html
#   Copyright (C) 2013 Matthias Ansorg. This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you
#   are welcome to redistribute it under certain conditions. Refer to the link above for licence details.
#
# @todo Fix that, when converting pages to their language specific versions, the parent ID will still refer to
#   the old (multilanguage) version which finally gets deleted. So language-specific pages will be imported via WXR
#   as having no parent.
# @todo There is a bug in te WXR export: when the post's or page's title is multilanguage, it is exported as the
#   first language version instead (the same as it's shown in the WordPress backend). So, no <lang_xx> tags appear
#   inside the <title> tag in exported WXR files. Which means, title translations get lost in this process.
# @todo Add that this script will also generate language-specific copies of all categories and tags, and assign posts
#   to the proper language versions of these only. Until this is implemented, polylang-localize-tags.rb provides a
#   workaround. Currently, categories and tags are left unchanged, and have to be assigned to the default language (in
#   the Polylang settings screen) )to make them visible when editing a post. The problem is that they are not
#   translated then, and will disappear from "wrong language" posts and pages when editing them.
# @todo Fix the Polylang (or rather, Wordpress) bug that term metadata (from table wp_termsmeta), like language
#   identifiers and links to translations for categories and tags, are not saved in WXR exports. For that reason,
#   this script currently has to create SQL files to attach this information to terms.
# @todo Fix that newlines are missing in the output file, before tags created programmatically. Might be a bug in the
#   Nokogiri write_to()) function? For now, the workaround is to use "xmllint --format infile.xml > outfile.xml".

require 'rubygems'
require 'nokogiri'

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

## Convert a Polyglot compatible HTML string with <lang_en> and <lang_it> to its Italian version, without these tags.
def to_italian(html_string)
  # The regex literal syntax using %r{...} allows '/' in the regex without escaping.
  html_string = html_string.gsub( %r{<lang_en>.+?</lang_en>}m, '' )
  html_string = html_string.gsub( %r{</?lang_en>}, '' ) # Lone half-tags from corrupted documents.
  html_string = html_string.gsub( %r{</?lang_it>}, '' )
end

# Start of URL to construct the content of the guid tag for an item, by appending its item ID.
GUID_POST_BASE_URL = 'http://www.cottica.net/?p='
GUID_ATTACHMENT_BASE_URL = 'http://www.cottica.net/?attachment_id='

wxr_infile = ARGV[0]
wxr_outfile = ARGV[1]
wxr_doc = Nokogiri::XML(File.open(wxr_infile))

# Next free unique ID of a WordPress post that can be assigned.
next_post_id = ARGV[2].to_i

# Next free unique ID of a WordPress term that can be assigned.
next_term_id = ARGV[3].to_i

# Map to store translations of old post IDs to new (language dependent) ones. Access is via [id]['en'] and [id]['it'].
item_id_map = Hash.new

# Map to store translation information about what post or page ID is the parent of each media item.
parent_id_map = Hash.new

# Maps to map item IDs to the correct post titles and names ("slugs").
title_corrections = Hash.new
name_corrections = Hash.new


items = wxr_doc.xpath('//channel//item')
items.each do |item|

  puts '---------------------------------'

  # puts "Debug: Trying to convert to integer: item ID " + item.at_xpath('.//wp:post_id').content
  item_id = item.at_xpath('.//wp:post_id').content.to_i


  # puts 'Type: ' + item.class.name
  puts "Debug: Item with ID #{item_id}: \n"
  # puts item.to_xml
  # puts item.at_xpath('.//content:encoded').inner_html

  # Check if this is a multilingual item, that is, containing a <lang_*> tag.
  is_multilingual = !!( item.at_xpath('.//content:encoded').inner_html =~ %r{</?lang_..>} ) or
      !!( item.at_xpath('.//excerpt:encoded').inner_html =~ %r{</?lang_..>} ) or
      !!( item.at_xpath('.//title').inner_html =~ %r{</?lang_..>} )

  # Nothing to do except it's a multilingual item.
  if !is_multilingual then
    next
  end

  puts 'Debug: This is a multilingual post - going to replace it!'

  # Create the IDs for language-specific versions of this item.
  item_id_map[item_id] ||= {}
  item_id_map[item_id][:en] = next_post_id
  next_post_id += 1
  puts "Debug: item_id_map[#{item_id}][:en] = #{item_id_map[item_id][:en]}"
  item_id_map[item_id][:it] = next_post_id
  next_post_id += 1
  puts "Debug: item_id_map[#{item_id}][:it] = #{item_id_map[item_id][:it]}"



  # Create the metadata tag that links the language-specific items.
  item_translation_ids =
      "<wp:postmeta>
        <wp:meta_key>_translations</wp:meta_key>
        <wp:meta_value><![CDATA[a:2:{s:2:\"en\";i:#{item_id_map[item_id][:en]};s:2:\"it\";i:#{item_id_map[item_id][:it]};}]]></wp:meta_value>
      </wp:postmeta>"

  #
  # Create an English version of the item.
  #

  item_en = item.dup # Deep copy by default!
  item_en.at_xpath('.//wp:post_id').content = item_id_map[item_id][:en].to_s
  item_en.at_xpath('.//guid').content = GUID_POST_BASE_URL + item_id_map[item_id][:en].to_s

  # In the English translation, eliminate all <lang_it> tags and their content, and the <lang_en> tags while keeping their content.
  item_en.at_xpath('.//content:encoded').inner_html = wxr_doc.create_cdata( to_english(item_en.at_xpath('.//content:encoded').inner_html) )
  item_en.at_xpath('.//excerpt:encoded').inner_html = wxr_doc.create_cdata( to_english(item_en.at_xpath('.//excerpt:encoded').inner_html) )
  item_en.at_xpath('.//title').inner_html = to_english(item_en.at_xpath('.//title').inner_html)

  # Add the metadata to for language identification and linking language-specific versions.
  item_en << '<category domain="language" nicename="en"><![CDATA[English]]></category>'
  item_en << item_translation_ids.dup # Copy is needed: one node can only be used once in a DOM tree, but we need this for every language version.


  #
  # Create an Italian version of the item.
  #

  item_it = item.dup
  item_it.at_xpath('.//wp:post_id').content = item_id_map[item_id][:it].to_s
  item_it.at_xpath('.//guid').content = GUID_POST_BASE_URL + item_id_map[item_id][:it].to_s

  title_corrections[ item_id_map[item_id][:it] ] = item_it.at_xpath('.//title').inner_html
  name_corrections[ item_id_map[item_id][:it] ] = item_it.at_xpath('.//wp:post_name').content

  # Append "-it" to the link and post name tags to make them unique. English version keeps the original link, to not break URL references.
  item_it.at_xpath('.//link').content = item_it.at_xpath('.//link').content.sub(%r{(/?)$},'-italiano\1')
  item_it.at_xpath('.//wp:post_name').content += '-italiano'

  # In the Italian translation, eliminate all <lang_en> tags and their content, and the <lang_it> tags while keeping their content.
  item_it.at_xpath('.//content:encoded').inner_html = wxr_doc.create_cdata( to_italian(item_it.at_xpath('.//content:encoded').inner_html) )
  item_it.at_xpath('.//excerpt:encoded').inner_html = wxr_doc.create_cdata( to_italian(item_it.at_xpath('.//excerpt:encoded').inner_html) )

  # When importing a WXR file into WordPress, posts with a title that is the same as a previous one fail to be imported
  # (can be considered a bug). So we make the title of language specific posts artificially unique, where needed.
  item_it_orig_title = item_it.at_xpath('.//title').inner_html
  item_it.at_xpath('.//title').inner_html = to_italian(item_it.at_xpath('.//title').inner_html)
  if item_it.at_xpath('.//title').inner_html == item_it_orig_title then
    item_it.at_xpath('.//title').inner_html += ' (Italiano)'
    puts 'Debug: Italian version\'s title made unique by appending "(Italiano)".'
  end

  # Add the metadata to for language identification and linking language-specific versions.
  item_it << '<category domain="language" nicename="it"><![CDATA[Italiano]]></category>'
  item_it << item_translation_ids.dup


  puts 'Debug: link (orig):      ' + item.at_xpath('.//link').content
  puts 'Debug: link (en):        ' + item_en.at_xpath('.//link').content
  puts 'Debug: link (it):        ' + item_it.at_xpath('.//link').content

  puts 'Debug: post_name (orig): ' + item.at_xpath('.//wp:post_name').content
  puts 'Debug: post_name (en):   ' + item_en.at_xpath('.//wp:post_name').content
  puts 'Debug: post_name (it):   ' + item_it.at_xpath('.//wp:post_name').content

  puts 'Debug: guid (orig):      ' + item.at_xpath('.//guid').content
  puts 'Debug: guid (en):        ' + item_en.at_xpath('.//guid').content
  puts 'Debug: guid (it):        ' + item_it.at_xpath('.//guid').content


  # Add the language-specific versions before the original item, remove the original item.
  # ()The each() traversal loop automatically proceeds with the next sibling of the then unlinked item.)
  item.before( Nokogiri::XML::NodeSet.new(wxr_doc, [item_en, item_it]) )
  item.unlink
end


# Traverse items a second time, to adapt attachment items according to the ID change of their parent items (the posts
# they got attached to.)
items = wxr_doc.xpath('//channel//item')
items.each do |item|
  if item.at_xpath('.//wp:post_type').content != 'attachment'
    next
  end

  item_id = item.at_xpath('.//wp:post_id').content.to_i

  puts '---------------------------------'
  # puts 'Type: ' + item.class.name
  puts "Debug: Attachment item with ID #{item_id}: \n"
  # puts item.to_xml
  # puts item.at_xpath('.//content:encoded').inner_html

  parent_id = item.at_xpath('.//wp:post_parent').content.to_i

  # Test for a recorded ID change: there's nothing to do here if no ID change is recorded for this attachment item's parent.
  # (Do not test item_id_map[parent_id][:en] - not possible, as there might be no hash in the hash to access!)
  if item_id_map[parent_id] == nil
    # Only thing to do is record the mapping of attachment ID to parent ID, for generating corresponding SQL statements
    # for _all_ attachments lateron.
    parent_id_map[item_id] = parent_id
    next
  end

  # As an ID change entry was mapped for :en, it also means that the item was replaced by language specific versions,
  # as that's the only case that causes an ID change in this script. So we simply have to duplicate this attachment item as well.

  puts 'Debug: This is an attachment that belongs to a now-multilingual post - going to replace it!'

  # Create the IDs for language-specific versions of this item.
  item_id_map[item_id] ||= {}
  item_id_map[item_id][:en] = next_post_id
  next_post_id += 1
  puts "Debug: item_id_map[#{item_id}][:en] = #{item_id_map[item_id][:en]}"
  item_id_map[item_id][:it] = next_post_id
  next_post_id += 1
  puts "Debug: item_id_map[#{item_id}][:it] = #{item_id_map[item_id][:it]}"


  # Create the metadata tag that links the language-specific items.
  item_translation_ids =
      "<wp:postmeta>
        <wp:meta_key>_translations</wp:meta_key>
        <wp:meta_value><![CDATA[a:2:{s:2:\"en\";i:#{item_id_map[item_id][:en]};s:2:\"it\";i:#{item_id_map[item_id][:it]};}]]></wp:meta_value>
      </wp:postmeta>"


  #
  # Create an English version of the item.
  #

  item_en = item.dup # Deep copy by default!
  item_en.at_xpath('.//wp:post_id').content = item_id_map[item_id][:en].to_s
  item_en.at_xpath('.//wp:post_parent').content = item_id_map[parent_id][:en].to_s

  parent_id_map[ item_id_map[item_id][:en] ] = item_id_map[parent_id][:en]

  # Add the metadata to for language identification and linking language-specific versions.
  item_en << '<category domain="language" nicename="en"><![CDATA[English]]></category>'
  item_en << item_translation_ids.dup # Copy is needed: one node can only be used once in a DOM tree, but we need this for every language version.


  #
  # Create an Italian version of the item.
  #

  item_it = item.dup
  item_it.at_xpath('.//wp:post_id').content = item_id_map[item_id][:it].to_s
  item_it.at_xpath('.//wp:post_parent').content = item_id_map[parent_id][:it].to_s

  parent_id_map[ item_id_map[item_id][:it] ] = item_id_map[parent_id][:it]

  # Append "-italiano" to the link and post_name tags to make them unique.
  item_it.at_xpath('.//link').content = item_it.at_xpath('.//link').content.sub(%r{(/?)$},'-italiano\1')
  item_it.at_xpath('.//wp:post_name').content += '-italiano'

  # When importing a WXR file into WordPress, posts with a title that is the same as a previous one fail to be imported
  # (can be considered a bug). So we make the title of language specific posts artificially unique.
  item_it.at_xpath('.//title').content += ' (Italiano)'

  # Add the metadata to for language identification and linking language-specific versions.
  item_it << '<category domain="language" nicename="it"><![CDATA[Italiano]]></category>'
  item_it << item_translation_ids.dup


  puts 'Debug: link (orig):      ' + item.at_xpath('.//link').content
  puts 'Debug: link (en):        ' + item_en.at_xpath('.//link').content
  puts 'Debug: link (it):        ' + item_it.at_xpath('.//link').content

  puts 'Debug: post_name (orig): ' + item.at_xpath('.//wp:post_name').content
  puts 'Debug: post_name (en):   ' + item_en.at_xpath('.//wp:post_name').content
  puts 'Debug: post_name (it):   ' + item_it.at_xpath('.//wp:post_name').content

  # Add the language-specific versions before the original item, remove the original item.
  # (The each() traversal loop automatically proceeds with the next sibling of the then unlinked item.)
  item.before( Nokogiri::XML::NodeSet.new(wxr_doc, [item_en, item_it]) )
  item.unlink
end


# Write the modified XML document out to a XML file.
File.open(wxr_outfile, 'w') do |f|
  # See http://nokogiri.org/Nokogiri/XML/Node.html#method-i-write_to
  wxr_doc.write_xml_to(f, encoding: 'UTF-8', indent: 2)
end


# Write an additional file with complementing SQL statements to attach media library items to their correct parents
# (as this cannot be done by WordPress WXR imports in case of unresolvable timeouts.)
File.open("#{wxr_outfile}.attach.sql", 'w') do |f|

  parent_id_map.each do |media_item_id, parent_item_id|
    f.write("UPDATE wp_posts SET post_parent=#{parent_item_id} WHERE ID=#{media_item_id};\n")
  end

end


# Write an additional file with complementing SQL statements to help you adapt post names easily by editing and
# executing the resulting SQL file. This only applies to the second language, as the first language will keep the
# original post names (slugs) to not break URL compatibility.
File.open("#{wxr_outfile}.names.sql", 'w') do |f|

  name_corrections.each do |item_id, name|
    f.write("UPDATE wp_posts SET post_name='#{name}' WHERE ID=#{item_id};\n")
  end

end
