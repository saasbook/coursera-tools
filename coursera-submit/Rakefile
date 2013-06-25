# Installs 'submit' and 'submit-config' commands

require 'rake'

task :default do
  cp 'submit', '/usr/bin/'
  chmod 111, '/usr/bin/submit'
  cp 'submit-config', '/usr/bin'
  chmod 111, '/usr/bin/submit-config'
end