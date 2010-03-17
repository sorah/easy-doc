require File.dirname(__FILE__) + '/../lib/easy_doc.rb'
require 'tmpdir'
require 'fileutils'
require 'thread'

describe EasyDoc do
  before(:all) do
    @mpath = Dir.mktmpdir("easy_doc_spec_mkd" )
    @hpath = Dir.mktmpdir("easy_doc_spec_html")
    open(@mpath+'/index.mkd','w') {|f| f.puts "# hi" }
  end

  before do
    @e = EasyDoc.new(@mpath,@hpath)
  end

  describe '#markdown_files' do
    it 'can take markdown files' do
      @e.markdown_files.should include('index.mkd')
    end
  end

  describe '#init_config' do
    it 'can reload config' do
      open(@mpath+"/config.yml",'w') do |f|
        f.puts 'piyo: foobar'
      end
      @e.init_config
      @e.config[:piyo].should == 'foobar'
    end
  end

  describe '#render' do
    it 'can render markdown file' do
      @e.render
      File.exist?(@hpath+'/index.html').should be_true
      File.read(@hpath+'/index.html').should   match('<h1>hi</h1>')
    end

    it 'must save checksums' do
      File.exist?(@mpath+'/.easy-doc_checksums').should be_true
    end

    it 'must not render not edited markdown file' do
      t = File.mtime("#{@hpath}/index.html")
      sleep 1 # TODO: Refactoring this.
      @e.render
      t.should == File.mtime("#{@hpath}/index.html")
    end

    it 'can re-render edited markdown files' do
      open(@mpath+'/index.mkd','w') {|f| f.puts "# hi\n\n('.v.')" }
      @e.render
      File.read(@hpath+'/index.html').should match("<p>\\('\\.v\\.'\\)</p>")
    end

    it 'can force render' do
      t = File.mtime("#{@hpath}/index.html")
      sleep 1 # TODO: Refactoring this.
      @e.render(true,true)
      t.should < File.mtime("#{@hpath}/index.html")
    end

    it 'can render with layout file' do
      open(@mpath+'/layout.erb','w') do |f|
        f.puts <<-EOF
<html>
<body>
^q^<br>
<%=body%>
</body>
</html>
      EOF
      end
      @e.render(true,true)
      File.read(@hpath+'/index.html').should match("\\^q\\^")
      FileUtils.rm(@mpath+'/layout.erb')
    end

    it 'can put messages' do
      g, $stdout = IO.pipe
      t = Thread.new do
        ["Checking changed markdown files","Rendering: index.mkd"].each do |m|
          s = g.gets
          s.should match(m)
        end
      end
      @e.render(false,true)
      t.join
      $stdout = STDOUT
    end

    it 'can render multiple languages' do
      open(@mpath+'/index.ja.mkd','w') do |f|
        f.puts "# Konnnitiha."
      end
      @e.render
      File.read(@hpath+'/index.ja.html').should match('<a href="index.html">default</a>')
      File.read(@hpath+'/index.html').should match('<a href="index.ja.html">ja</a>')
    end

    it 'can set default languages' do
      open(@mpath+'/config.yml','w') do |f|
        f.puts "default_lang: en"
      end
      @e.init_config
      @e.render
      File.read(@hpath+'/index.ja.html').should match('<a href="index.html">en</a>')
      File.read(@hpath+'/index.html').should match('en')
    end

    it 'can generate relative path in <a>' do
      Dir.mkdir(@mpath+'/foo')
      open(@mpath+'/foo/bar.mkd') do |f|
        f.puts "# Foo\n\n# bar\n\n cool"
      end
      open(@mpath+'/index.mkd','w') {|f| f.puts "# hi\n\n[foobar!](/foo/bar.mkd)" }
      @e.render
      File.read(@hpath+'index.html').should match('<a href="\./foo/bar.html">')
    end
  end

  describe '#delete_htmls' do
    it 'deletes deleted markdown file\'s html' do
      open(@mpath+'/hoge.mkd','w') {|f| f.puts "# hi"}
      @e.render
      File.exist?(@hpath+'/hoge.html').should be_true
      FileUtils.remove(@mpath+'/hoge.mkd')
      @e.delete_htmls
      File.exist?(@hpath+'/hoge.html').should be_false
    end
  end

  after(:all) do
    FileUtils.remove_entry_secure @mpath
    FileUtils.remove_entry_secure @hpath
  end
end
