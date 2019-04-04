require 'yaml'
require 'fileutils'
require 'pry'
require 'digest'

class AppGenerator

  def initialize
    @script_path = File.join(File.dirname(File.expand_path(__FILE__)))
  end

  def define_injects(app)
    result = ''
    css_path = "#{@script_path}/#{app}.css"
    result += " --inject #{css_path}" if File.exist? css_path
  
    js_path = "#{@script_path}/#{app}.js"
    result += " --inject #{js_path}" if File.exist? js_path
    result
  end

  def yaml
    YAML::load_file("#{@script_path}/apps.yml")
  end

  def yaml_changed?
    current_hash = Digest::MD5.hexdigest yaml_without_hash.to_s
    saved_hash = yaml['hash']
    current_hash != saved_hash
  end

  def yaml_without_hash
    current = yaml
    current['hash'] = ''
    current
  end

  def save_hash
    final_yaml = yaml
    current_hash = Digest::MD5.hexdigest yaml_without_hash.to_s
    final_yaml['hash'] = current_hash
    File.open("#{@script_path}/apps.yml", "w") { |file| file.write(final_yaml.to_yaml) }
  end

  def run
    return unless yaml_changed?

    home = ENV['HOME']
    
    app_folder = "#{home}/Applications/nativefier"
    
    FileUtils.rm_rf(app_folder)
    FileUtils.mkdir(app_folder)
    
    Dir.chdir(app_folder)
    
    FileUtils.mkdir("#{app_folder}/bin")
    
    yaml.map do |app,values|
      command = "nativefier #{define_injects(app)} #{values['url']} --name #{app}"
      values.each do |k,v|
        next if k == 'url'
        command += " --#{k}#{ v.nil? || v.empty? ? '' : ('=' + v)}"
      end
      puts command
      `#{command}`
      generated_folder = "#{app_folder}/#{Dir.glob("*#{app}-*").first}"
      generated_bin = "#{generated_folder}/#{app}"
    
      FileUtils.ln_sf(generated_bin,"#{app_folder}/bin")
      puts "linking ##{app}"
    end
    
    Dir.chdir(@script_path)
    
    Dir["#{app_folder}/*/**/main.js"].map do |file|
      FileUtils.cp("#{@script_path}/main.js",file)
    end

    save_hash
  end
end

AppGenerator.new.run