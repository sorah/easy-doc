#
# easy-doc
# Author: Sora Harakami
# Licence: MIT Licence
# The MIT Licence {{{
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#   THE SOFTWARE.
# }}}
#
require 'rubygems'
require 'markdown' # rpeg-markdown
require 'yaml'
require 'digest/md5'
require 'erb'
require 'pathname'
require 'fileutils'

class EasyDoc
  class MakeDirectoryError < Exception; end

  def initialize(mkd_path,html_path)
    raise ArgumentError, 'mkd_path is invalid' unless File.directory?(mkd_path) && html_path.kind_of?(String)
    raise ArgumentError, 'html_path is invalid' unless html_path.kind_of?(String)
    @mkd_path  = File.expand_path(mkd_path ).gsub(/\/$/,"")
    @html_path = File.expand_path(html_path).gsub(/\/$/,"")
    init_config
  end

  def init_config
    @config    = { #Default config
                   :default_lang => "default"
                 }
    @changed_config = changed_config
    @config.merge!(load_config)
  end

  def render(quiet=true,force=false)
    puts "Checking changed markdown files..." unless quiet
    f = (force || @changed_config.include?(:default_lang)) ? markdown_files : changed_markdown_files
    f.each do |n|
      puts "Rendering: #{n}" unless quiet
      render_file(n)
    end
    self
  end

  def layout
    if File.exist?("#{@mkd_path}/layout.erb")
      File.read("#{@mkd_path}/layout.erb")
    else
      ### Default layout  ###
      return <<-EOB
<html>
  <head>
    <title><%= title %></title>
    <style type="text/css">
      .header {
        padding-bottom: 10px;
        border-bottom: 1px solid gray;
        margin-bottom: 10px;
      }

      .lang_bar {
        text-align: right;
        text-size: 11px;
      }

      .title {
        text-size: 24px;
        margin-top: 5px;
      }
    </style>
  </head>
  <body>
    <!-- Document rendered by easy_doc http://github.com/sorah/easy-doc -->
    <div class="header">
      <div class="lang_bar">
        <%= lang_bar %>
      </div>
      <span class="title"><%= title %></span>
    </div>
    <div class="doc_body">
      <%= body %>
    </div>
  </body>
</html>
      EOB
      ######### End #########
    end
  end

  def markdown_files(lp=true)
    Dir.glob("#{@mkd_path}/**/*.mkd").map{|x| lp ? mkd_local_path(x) : x }
  end

  def delete_htmls(quiet=true)
    fs = deleted_markdown_files
    fs.each do |f|
      h = f.gsub(/\.mkd$/,'.html')
      puts "Removing: #{h}" unless quiet
      FileUtils.remove(html_expand_path(h))
    end
  end

  attr_reader :config

private

  def html_create_dir(p)
    FileUtils.mkdir_p(html_expand_path(p).gsub(/\/[^\/]+$/,""))
  end

  def render_file(f,force_other_lang=false)
    mkd      = File.read(mkd_expand_path(f))
    title    = mkd.scan(/^# (.+)/).flatten[0]
    body     = Markdown.new(mkd).to_html
    body.gsub!(/<a href="(.+)">/) do |s|
      u = $1
      nu =
        if /^\// =~ u
          Pathname(mkd_expand_path(u)) \
            .relative_path_from( \
              Pathname(mkd_expand_path(File.dirname(f)
                                       .gsub(/\/\.$/,'')))).to_s \
            .gsub(/\.mkd$/,'.html')
        else
          u
        end
      "<a href='#{nu}'>"
    end
    t = File.basename(f)
    lang_bar_ary = []
     unless force_other_lang
      Dir.glob("#{mkd_expand_path(File.dirname(f))}/*.mkd") \
         .delete_if{|m| mkd_local_path(m) == f ||
                        /^#{Regexp.escape(t.gsub(/\..*mkd/,""))}/ !~ mkd_local_path(m)} \
         .each do |m|
        render_file(mkd_local_path(m),true)
      end
     end
    Dir.glob("#{mkd_expand_path(File.dirname(f))}/*.mkd") \
       .map{|m| File.basename(m) } \
       .delete_if{|m| /^#{Regexp.escape(t.gsub(/\..*mkd/,""))}/ !~ m}.each do |m|
      la = m.scan(/(\..+)?\.mkd$/).flatten
      l = la.include?(nil) ? @config[:default_lang] : la[0].gsub(/^\./,"")
      ls  = ""
      unless t == m
        ls += '<a href="'
        ls += m.gsub(/\.mkd/,".html")
        ls += '">'
      end
      ls += l
      unless t == m
        ls += '</a>'
      end
      lang_bar_ary << ls
    end
    lang_bar = lang_bar_ary.join(' | ')
    hl = f.gsub(/\.mkd$/,'.html')

    html_create_dir(hl)
    open(html_expand_path(hl),'w') do |f|
      f.puts ERB.new(layout()).result(binding)
    end
  end

  def calcuate_checksums
    a = markdown_files(false)
    h = {}
    a.each do |f|
      h[mkd_local_path(f)] = Digest::MD5.new.update(File.read(f)).to_s
    end
    h
  end

  def save_checksums(h=nil)
    if h.nil?
      h = calcuate_checksums
    end
    open("#{@mkd_path}/.easy-doc_checksums",'w') do |f|
      f.puts h.to_yaml
    end
    self
  end

  def load_checksums
    if File.exist?("#{@mkd_path}/.easy-doc_checksums")
      YAML.load_file("#{@mkd_path}/.easy-doc_checksums")
    else
      {}
    end
  end


  def mkd_local_path(path)
    path.gsub(/^#{Regexp.escape(@mkd_path)}\//,'').gsub(/^\.\//,"")
  end

  def mkd_expand_path(path)
    @mkd_path + '/' + path.gsub(/^\//,'')
  end

  def html_local_path(path)
    path.gsub(/^#{Regexp.escape(@html_path)}\//,'')
  end

  def html_expand_path(path)
    @html_path + '/' + path.gsub(/^\//,'')
  end

  def changed_markdown_files(sv=true)
    n = calcuate_checksums
    o = load_checksums
    r = []
    n.each do |f,c| # exists file
      if o[f] != c
        r << f
      end
    end
    save_checksums(n) if sv
    @changed_config.include?(:default_lang) ? markdown_files : r + (n.keys - o.keys)
  end

  def old_load_config
    h = {}
    if File.exist?(mkd_expand_path('.bup_config.yml'))
      YAML.load_file(mkd_expand_path('.bup_config.yml')).each do |k,v|
        h[k.to_sym] = v
      end
    end
    h
  end

  def changed_config
    o = old_load_config
    n = load_config(false)
    a = []
    n.each do |k,v|
      a << k unless v == o[k]
    end
    a
  end

  def load_config(s=true)
    h = {}
    if File.exist?(mkd_expand_path('config.yml'))
      YAML.load_file(mkd_expand_path('config.yml')).each do |k,v|
        h[k.to_sym] = v
      end
      FileUtils.copy(mkd_expand_path('config.yml'),mkd_expand_path('.bup_config.yml')) if s
    end
    h
  end

  def deleted_markdown_files(sv=false)
    n = calcuate_checksums
    o = load_checksums
    save_checksums(n) if sv
    o.keys - n.keys
  end
end
