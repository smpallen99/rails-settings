
class Defaults < ActiveSupport::HashWithIndifferentAccess
  def []=(var_name, value)
    super
    Settings[var_name] = value
  end
end
