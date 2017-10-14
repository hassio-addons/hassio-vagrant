# ==============================================================================
#
# Community Hass.io Add-ons: Vagrant
#
# ==============================================================================
# MIT License
#
# Copyright (c) 2017 Franck Nijhof
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ==============================================================================

require 'English'
require 'fileutils'
require 'vagrant'
require 'yaml'
require 'pp'

VAGRANT_API_VERSION = '2'.freeze
::Vagrant.require_version '>= 1.9.0'

module HassioCommunityAddons
  # Manages the Vagrant configuration
  # @author Franck Nijhof <frenck@addons.community>
  class Vagrant
    # Class constructor
    def initialize
      @config = YAML.load_file(
        File.join(File.dirname(__FILE__), 'configuration.yml')
      )
    end

    # Simple CLI Yes / No question
    #
    # @param [String] message Question to ask
    # @param [Boolean] default True, to default to yes, false to default to no
    # @return [Boolean] True if answered yes, false if answered no
    def confirm(message, default)
      print "#{message} [#{(default ? 'Y/n' : 'y/N')}]: "

      result = $stdin.gets.chomp.strip.downcase
      return default if result.empty?
      return true if %w(y yes).include? result
      return false if %w(n no).include? result

      print "\nInvalid input. Try again...\n"
      confirm(message, default)
    end

    # Checks/install required vagrant-triggers plugin
    def require_triggers_plugin
      return if ::Vagrant.has_plugin?('vagrant-triggers')

      print "A required vagrant plugin is missing: vagrant-triggers\n"
      confirm 'Shall I go ahead an install it?', true unless raise \
        ::Vagrant::Errors::VagrantError.new, 'Required plugin missing.'

      system 'vagrant plugin install vagrant-triggers' unless raise \
        ::Vagrant::Errors::VagrantError.new, 'Installation of plugin failed.'

      print "Restarting Vagrant to re-load plugin changes...\n"
      system 'vagrant ' + ARGV.join(' ')
      exit! $CHILD_STATUS.exitstatus
    end

    # Configures generic Vagrant options
    #
    # @param [Vagrant::Config::V2::Root] config Vagrant root config
    def vagrant_config(config)
      config.vm.box = @config['box']
      config.vm.post_up_message = @config['post_up_message']
    end

    # Defines a Vagrant virtual machine
    #
    # @param [Vagrant::Config::V2::Root] config Vagrant root config
    # @param [String] name Name of the machine to define
    def machine(config, name)
      config.vm.define name do |machine|
        machine_config machine
        machine_provider_virtualbox machine
        machine_provider_vmware machine
        machine_shares machine
        machine_provision machine
        machine_cleanup_on_destroy machine
      end
    end

    # Configures a VM's generic options
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_config(machine)
      machine.vm.hostname = @config['hostname']
      machine.vm.network 'public_network', type: 'dhcp'
      machine.vm.network 'private_network', type: 'dhcp'
    end

    # Configures the Virtualbox provider
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_provider_virtualbox(machine)
      machine.vm.provider :virtualbox do |vbox|
        vbox.name = @config['hostname']
        vbox.cpus = @config['cpus']
        vbox.customize ['modifyvm', :id, '--memory', @config['memory']]
        vbox.customize ['modifyvm', :id, '--nictype1', 'virtio']
        vbox.customize ['modifyvm', :id, '--nictype2', 'virtio']
        vbox.customize ['modifyvm', :id, '--nictype3', 'virtio']
        vbox.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
        vbox.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
      end
    end

    # Configures the VMware provider
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_provider_vmware(machine)
      %w(vmware_fusion vmware_workstation).each do |vmware|
        machine.vm.provider vmware do |vmw|
          vmw.vmx['displayName'] = @config['hostname']
          vmw.vmx['memsize'] = @config['memory']
          vmw.vmx['numvcpus'] = @config['cpus']
        end
      end
    end

    # Configures a VM's shares
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_shares(machine)
      @config['shares'].each do |src, dst|
        machine.vm.synced_folder src, dst, create: true, type: share_type
      end
    end

    # Determines the type of filesharing. SMB for windows, else NFS.
    def share_type
      RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/ ? 'smb' : 'nfs'
    end

    # Configures a VM's provisioning
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_provision(machine)
      machine.vm.provision 'fix-no-tty', type: 'shell' do |shell|
        shell.path = 'provision.sh'
      end
    end

    # Defines a VM cleanup task when destroying the VM
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_cleanup_on_destroy(machine)
      root_directory = File.dirname(__FILE__)
      machine.trigger.after :destroy do
        FileUtils.rm_rf(
          Dir.glob(File.join(root_directory, 'config/**'), File::FNM_DOTMATCH)
          .reject { |i| i =~ %r{(\/.|\/\.\.|\.gitkeep)$} }
        )
      end
    end

    # Run this thing!
    def run
      require_triggers_plugin
      ::Vagrant.configure(VAGRANT_API_VERSION) do |config|
        vagrant_config(config)
        machine(config, 'hassio')
      end
    end
  end
end

# Create a instance
hassio = HassioCommunityAddons::Vagrant.new

# Go!
hassio.run
