#!/usr/bin/env ruby

# Collection of currently unused snippets related to polyglot2polylang.rb.
#
# @author matthias <matthias at ansorgs dot de>
# @licence GPL Version 3 (or at your option, any later version) http://www.gnu.org/licenses/gpl-3.0-standalone.html
#   Copyright (C) 2013 Matthias Ansorg. This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you
#   are welcome to redistribute it under certain conditions. Refer to the link above for licence details.


# Snippet to test content and title nodes if they use the Polyglot multilanguage tags.
# (This does this by using DOM, while the current mechanism simply uses regex.)

content_node = item.at_xpath('.//content:encoded')
if content_node.children.first.cdata? then
  content_as_html = Nokogiri::HTML::Document.parse(content_node.content)

  if content_as_html.xpath('.//lang_en | .//lang_it').size() > 0 then
    is_multilingual = true
  end
end

excerpt_node = item.at_xpath('.//excerpt:encoded')
if excerpt_node.children.first.cdata? then
  excerpt_as_html = Nokogiri::HTML::Document.parse(excerpt_node.content)

  if excerpt_as_html.xpath('.//lang_en | .//lang_it').size() > 0 then
    is_multilingual = true
  end
end

if title_node = item.at_xpath('.//title').xpath('.//lang_en | .//lang_it').size() > 0 then
   is_multilingual = true
end