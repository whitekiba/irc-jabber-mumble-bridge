require 'yaml'

class Language
  def initialize
    @lang = YAML.load_file(File.dirname(__FILE__) + '/../locale/english.yml')
  end
  def changeLanguage(lang)
    if @lang[:language] != lang
      @lang = YAML.load_file(File.dirname(__FILE__) + "/../locale/#{lang}.yml")
    end
  end
  def get(index)
    unless @lang[index].nil?
       @lang[index]
    else
      "unknown index or string"
    end
  end
end