require 'rubygems'
require 'markdown' # rpeg-markdown
require 'yaml'
require 'digest/md5'
require 'erb'
require 'pathname'

class EasyDoc
  class MakeDirectoryError < Exception; end

  def initialize(mkd_path,html_path)
    raise ArgumentError, 'mkd_path is invalid' unless File.directory?(mkd_path) && html_path.kind_of?(String)
    raise ArgumentError, 'html_path is invalid' unless html_path.kind_of?(String)
    @mkd_path  = File.expand_path(mkd_path ).gsub(/\/$/,"")
    @html_path = File.expand_path(html_path).gsub(/\/$/,"")
    @config    = {
                   :default_lang => "default"
                 }

    YAML.parse_file(mkd_expand_path('config.yml')).each do |k,v|
      @config[k.to_sym] = v
    end if File.exist?(mkd_expand_path('config.yml'))
  end

  def render(quiet=true,force=false)
    puts "Checking changed markdown files..." unless quiet
    f = force ? markdown_files : changed_markdown_files
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

private

  def html_create_dir(p)
    f = p.split(/\//)
    f.pop
    return if f.length < 2
    f.length.times do |i|
      next if i < 2
      pp = html_expand_path(f[0..i].join('/'))
      if File.exist?(pp)
        raise MakeDirectoryError, "#{pp} isn't directory" unless File.directory?(pp)
      else
        Dir.mkdir(pp)
      end
    end
  end

  def render_file(f)
    mkd      = File.read(mkd_expand_path(f))
    title    = mkd.scan(/^# (.+)/).flatten[0]
    body     = Markdown.new(mkd).to_html
    body.gsub!(/<a href="(.+)">/) do |s|
      u = $1
      nu = if u =~ /^\//
            Pathname.new(mkd_expand_path(u.gsub(/^\//,""))) \
                    .relative_path_from(File.dirname(f))
           else; u
           end
      '<a href="'+nu+'">'
    end
    t = File.basename(f)
    lang_bar_ary = []
    Dir.glob("#{File.dirname(f)}/*.mkd") \
       .delete_if{|m| /#{Regexp.escape(File.basename(f))}(\.(.+))?\.mkd/ !~ m} \
       .map{|m| File.basename(m) }.each do |m|
      la = m.scan(/\.(.+)\.mkd$/).flatten
      l = la.size > 0 ? la[0] : @config[:default_lang]
      ls  = ""
      unless t == m
        ls << '<a href="'
        ls << m
        ls << '">'
        ls << l
        ls << '</a>'
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
    path.gsub(/^#{Regexp.escape(@mkd_path)}\//,'')
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
    r + (n.keys - o.keys)
  end


end
