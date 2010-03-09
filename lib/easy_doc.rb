require 'markdown'

class EasyDoc
  def initialize(mkd_path,html_path)
    raise ArgumentError, 'mkd_path is invalid' unless File.directory?(mkd_path) && html_path.kind_of?(String)
    raise ArgumentError, 'html_path is invalid' unless html_path.kind_of?(String)
    @mkd_path  = File.expand_path(mkd_path ).gsub(/\/$/,"")
    @html_path = File.expand_path(html_path).gsub(/\/$/,"")
  end

  def markdown_files
    Dir.glob("#{@mkd_path}/**/*.mkd").map{|x| mkd_local_path(x) }
  end

  def mkd_local_path(path)
    path.gsub(/^#{Regexp.escape(@mkd_path)}/,'')
  end

  def mkd_expand_path(path)
    @mkd_path + '/' + path.gsub(/^\//,'')
  end

  def html_local_path(path)
    path.gsub(/^#{Regexp.escape(@html_path)}/,'')
  end

  def html_expand_path(path)
    @html_path + '/' + path.gsub(/^\//,'')
  end

  def calcuate_checksums
  end

  def save_checksums
  end

  def changed_markdown_files
  end

  def render(quiet=true)
  end
end
