#!/usr/bin/ruby
# <xbar.title>M2 Load</xbar.title>
# <xbar.version>v1.0.0</xbar.version>
# <xbar.desc>CPU and memory load of another Mac, fetched over ssh, in the menu bar.</xbar.desc>
# <xbar.dependencies>ruby,ssh</xbar.dependencies>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.runInBash>false</swiftbar.runInBash>

plugin_path = File.realpath(__FILE__)
require File.join(File.dirname(plugin_path), "lib", "m2_load")

exit M2Load::Cli.new.run
