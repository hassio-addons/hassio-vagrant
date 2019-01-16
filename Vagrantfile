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

::Vagrant.require_version '>= 2.1.0'
# Identify OS Platform
module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? && !OS.mac?
  end
end

module HassioCommunityAddons
  # Manages the Vagrant configuration
  # @author Franck Nijhof <frenck@addons.community>
  class Vagrant
    # Class constructor
    def initialize
      unless `vboxmanage list extpacks`.include? \
        'Oracle VM VirtualBox Extension Pack'
        raise ::Vagrant::Errors::VagrantError.new, \
              'Could not find VirtualBox Extension Pack! Did you install it?'
      end

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
      return true if %w[y yes].include? result
      return false if %w[n no].include? result

      print "\nInvalid input. Try again...\n"
      confirm(message, default)
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
        machine_shares machine
        machine_provision machine
        machine_cleanup_on_destroy machine unless @config['keep_config']
      end
    end

    # Configures a VM's generic options
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_config(machine)
      machine.vm.hostname = @config['hostname']
      machine.vm.network 'private_network', type: 'dhcp'
      machine.vm.network(
        'public_network',
        type: 'dhcp',
        bridge: @config['bridge']
      )
    end

    # Configures the Virtualbox provider
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    # rubocop:disable Metrics/MethodLength
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
          vbox.customize ['modifyvm', :id, '--usb', 'on', '--usbehci', 'on']
          if OS.windows?
            vbox.customize ['modifyvm', :id, '--audio', 'dsound',
                            '--audiocontroller', 'hda',
                            '--audioin', 'on',
                            '--audioout', 'on']
          elsif OS.mac?
            vbox.customize ['modifyvm', :id, '--audio', 'coreaudio',
                            '--audiocontroller', 'hda',
                            '--audioin', 'on',
                            '--audioout', 'on']
          else
            # someone needs to add other os commands
          end
      end
    end
    # rubocop:enable Metrics/MethodLength
    # Configures a VM's shares
    #
    # @param [Vagrant::Config::V2::Root] machine Vagrant VM root config
    def machine_shares(machine)
      @config['shares'].each do |src, dst|
        machine.vm.synced_folder(
          src,
          dst,
          create: true,
          type: share_type,
          SharedFoldersEnableSymlinksCreate: false
        )
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
      config_directory = File.join(File.dirname(__FILE__), 'config')
      machine.trigger.after :destroy do |trigger|
        trigger.name = 'Cleanup'
        trigger.info = 'Cleaning up Home Assistant configuration'
        trigger.run = {
          inline: "find '#{config_directory}' -mindepth 1 -maxdepth 1" \
            ' -not -name ".gitkeep" -exec rm -rf {} \;'
        }
      end
    end

    # Run this thing!
    def run
      ::Vagrant.configure('2') do |config|
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
