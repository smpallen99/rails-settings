
class Settings < ActiveRecord::Base
  attr_accessible :var, :value, :target_type
  class SettingNotFound < RuntimeError; end

  @@defaults = Defaults.new

  def self.defaults
    @@defaults
  end

  def self.defaults=(defs)
    @@defaults = Defaults.new defs
  end

  # Support old plugin
  if defined?(SettingsDefaults::DEFAULTS)
    self.defaults = SettingsDefaults::DEFAULTS.with_indifferent_access
  end

  #get or set a variable with the variable as the called method
  def self.method_missing(method, *args)
    if self.respond_to?(method)
      super
    else
      method_name = method.to_s

      #set a value for a variable
      if method_name =~ /=$/
        var_name = method_name.gsub('=', '')
        value = args.first
        self[var_name] = value

      #retrieve a value
      else
        self[method_name]

      end
    end
  end

  def self.[]=(var_name, val)

  end
  #destroy the specified settings record
  def self.destroy(var_name)
    var_name = var_name.to_s
    begin
      target(var_name).value  # force exception if needed
      eval "Settings['#{var_name}'] = Settings.defaults['#{var_name}']"
      true
    rescue NoMethodError
      raise SettingNotFound, "Setting variable \"#{var_name}\" not found"
    end
  end

  #retrieve all settings as a hash (optionally starting with a given namespace)
  def self.all(starting_with=nil)
    options = starting_with ? { :conditions => "var LIKE '#{starting_with}%'"} : {}
    vars = target_scoped.find(:all, {:select => 'var, value'}.merge(options))

    result = {}
    vars.each do |record|
      result[record.var] = record.value
    end
    selected_defaults = defaults.select{ |k, v| k =~ /^#{starting_with}/ }
    selected_defaults = Hash[selected_defaults] if selected_defaults.is_a?(Array)
    selected_defaults.merge(result).with_indifferent_access
  end

  #get a setting value by [] notation
  def self.[](var_name)
    if var = target(var_name)
      var.value
    else
      if target_id.nil?
        defaults[var_name.to_s]
      else
        target_type.constantize.settings[var_name.to_s]
      end
    end
  end

  #set a setting value by [] notation
  def self.[]=(var_name, value)
    record = target_scoped.find_or_initialize_by_var(var_name.to_s)
    record.value = value
    record.save!
    value
  end

  def self.merge!(var_name, hash_value)
    raise ArgumentError unless hash_value.is_a?(Hash)

    old_value = self[var_name] || {}
    raise TypeError, "Existing value is not a hash, can't merge!" unless old_value.is_a?(Hash)

    new_value = old_value.merge(hash_value)
    self[var_name] = new_value if new_value != old_value

    new_value
  end

  def self.setup(&block)
    class_eval(&block)
  end

  def self.deep_parse!(hash, key=nil)
    hash.each do |k,v|
      if v.kind_of? Hash
        val = key ? "#{key}.#{k}" : k
        self.deep_parse!(v, val)
      else
        k = "#{key}.#{k}" if key
        self.defaults[k] = v
      end
    end
  end

  def self.file(path)
    data = File.read(path)
    yaml = ERB.new(data).result
    hash = YAML.load(yaml)
    self.deep_parse! hash
  end

  def self.target(var_name)
    target_scoped.find_by_var(var_name.to_s)
  end

  #get the value field, YAML decoded
  def value
    YAML::load(self[:value])
  end

  #set the value field, YAML encoded
  def value=(new_value)
    self[:value] = new_value.to_yaml
  end

  def value_before_type_cast
    value
  end

  def self.target_scoped
    Settings.scoped_by_target_type_and_target_id(target_type, target_id)
  end

  #Deprecated!
  def self.reload # :nodoc:
    self
  end

  def self.target_id
    nil
  end

  def self.target_type
    nil
  end
end
