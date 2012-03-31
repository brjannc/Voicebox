# Copyright (C) 2012 brjannc <brjannc at gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'cgi'
require 'date'
require 'haml'
require 'sinatra'
require 'yaml'

configure do
  # TODO: set up default config with some sample logs

  if File.readable?('config.yml')
    config = YAML::load_file('config.yml')

    # precompile all the format pattern regexes
    config['formats'].each do |format, patterns|
      patterns.update(patterns) { |k, v| Regexp.new(v) }
    end

    set :channels, config['channels']
    set :formats, config['formats']
    set :version, "0.1"
  end

  set :haml, :format => :html5
end

# match /<channel>/<date>[.format]
get %r{^/(\w+)/(\d{4}-\d{2}-\d{2})(?:\.(\w+))?$} do |channel, date, format|
  pass unless settings.channels.include?(channel)

  begin
    date = Date.parse(date)
  rescue
    pass
  end

  format = 'html' if format.nil?

  @log = channel_log(channel, date)
  pass unless File.readable?(@log)

  @log_format = settings.channels[channel]['log-format']

  case format
  when /html?/
    haml :date
  when /txt/
    send_file @log, :type => :text
  else
    pass
  end
end

get %r{^/(\w+)$} do |channel|
  pass unless settings.channels.include?(channel)

  haml :channel
end

# match /
get %r{^/$} do
  haml :index
end

helpers do
  def channel_log(channel, date)
    # TODO: error checking

    config = settings.channels[channel]
    date.strftime("#{config['log-directory']}/#{config['log-template']}")
  end

  def channel_logs(channel)
    # TODO: error checking

    config = settings.channels[channel]
    pattern = "#{config['log-directory']}/#{config['log-template']}".gsub(/(%[^%])+/, '*')
    Dir.glob(pattern).sort.reverse
  end

  def linkify(text)
    text.gsub %r{((https?://|www\.)([-\w\.]+)+(:\d+)?(/([-\w/_\.]*(\?\S+)?)?)?)}, %Q{<a href="\\1">\\1</a>}
  end

  def markup(line, format)
    line.chomp!

    tokens = line.partition(" ")
    timestamp = tokens[0]
    text = linkify(CGI.escapeHTML(tokens[2]))
    text_class = nil

    settings.formats[format].each do |type, pattern|
      if match = pattern.match(text)
        text_class = type

        # if this line is a message or action, colorize the nick
        if type == "message" || type == "action"
          nick = match[1]
          color = nick.sum(3) + 1
          text.sub!(nick, %Q{<span class="c#{color}">#{nick}</span>})
        end

        # if we found a match, we can break out early; the patterns should be mutually exclusive
        break
      end
    end

    # debugging
    if text_class.nil?
      puts "Unmatched text! #{line}"
      text_class = "message"
    end

  <<END
<span class="timestamp">#{timestamp}</span>
<span class="#{text_class}">#{text}</span>
END

  end
end
