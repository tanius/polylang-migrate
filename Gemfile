# Bundler configuration file.
#
# See http://gembundler.com/gemfile.html for the Gemfile file format incl. version specifiers. See
# http://gembundler.com/ for documentation on Bundler.
#
# On updating gems. Note that `gem update` will update all gems listed in Gemfile, and all their dependencies, to
# their newest version compatible with the gem dependency requirements. This can still leave some gems below their
# latest released version - see `bundler outdated`. That is because gems in Gemfile, or their non-listed dependent ones,
# desire so. You can look all these conditions up in Gemfile.lock. For example, rails-admin requires
# "sass-rails (~> 3.1)", so bundler will stick with 3.1.6 even though sass-rails 3.2.5 is already released.
#
# On bundler and gem. This file is only used by bundler ("bundle install", "bundle update" etc.), not by the gem
# command ("gem install gemname"). So when specifying a special gem source like github here, this would not be used
# when installing with the gem command (defaulting to use rubygems.org, incapable of using github at all). And in
# case that additionally, these sources contain gems with the same version number but different content, even a
# "bundle update" afterwards might not get the right version. It has happened!
#
# @author matthias

source 'http://rubygems.org'


# --- Core --- #

# Ruby on Rails itself.
gem 'rails'

# Debugging.
# gem 'ruby-debug'

# --- Application needs --- #

# XML handling library.
gem 'nokogiri'
