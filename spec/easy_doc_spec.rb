require File.dirname(__FILE__) + '/../lib/easy_doc.rb'
require 'tmpdir'
require 'fileutils'

describe EasyDoc do
  before(:all) do
    @mpath = Dir.mktmpdir("#{Time.now.to_f.to_s.gsub(/\./,"")}_easy_doc_spec_mkd" )
    @hpath = Dir.mktmpdir("#{Time.now.to_f.to_s.gsub(/\./,"")}_easy_doc_spec_html")
    open(@mpath+'/index.mkd','w') {|f| f.puts "# hi" }
  end

  before do
    @e = EasyDoc.new(@mpath,@hpath)
  end

  it 'can take markdown files' do
    @e.markdown_files.should include('index.mkd')
  end

  it 'can render markdown file' do
    @e.render
    File.exist?(@hpath+'/index.html').should be_true
    File.read(@hpath+'/index.html').should   match('<h1>hi</h1>')
  end

  it 'can take checksums' do
    File.exist?(@mpath+'/.easy-doc_checksums').should be_true
  end

  it 'can re-render edited markdown files' do
    open(@mpath+'/index.mkd','w') {|f| f.puts "# hi\n('.v.')" }
    @e.render
    File.read(@hpath+'/index.html').should match("<p>\\('\\.v\\.'\\)</p>")
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
    open(@mpath+'/index.mkd','w') {|f| f.puts "# yey\n('.v.')" }
    @e.render
    File.read(@hpath+'/index.html').should match("\\^q\\^")
  end

  after(:all) do
    FileUtils.remove_entry_secure @mpath
    FileUtils.remove_entry_secure @hpath
  end
end
