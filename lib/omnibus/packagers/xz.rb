#
# Copyright 2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "pathname"
require "omnibus/packagers/windows_base"
require "fileutils"

module Omnibus
  class Packager::XZ < Packager::Base
    id :xz

    setup do
    end

    build do
      out_file = windows_safe_path(Config.package_dir, archive_name)
      log.info(log_key) { "Outputing xz package to #{out_file}" }
      out_source_path = "#{windows_safe_path(project.install_dir)}/*"
      cmd = <<-EOH.split.join(" ").squeeze(" ").strip
        tar -cJf
        #{out_file}
        #{out_source_path}
      EOH
      log.info(log_key) { "Running #{cmd}" }
      shellout!(cmd)
    end

    def debug_build?
      false
    end

    # @see Base#package_name
    def package_name
      archive_name
    end

    def archive_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}-#{safe_architecture}.tar.xz"
    end

    #
    # Set or return the architecture to set in the DEB control file
    #
    # @example
    #   safe_architecture 'all'
    #
    # @param [String] val
    #   A valid architecture for DEB control file
    #
    # @return [String]
    #   the architecture
    #
    def safe_architecture(val = NULL)
      if null?(val)
        @safe_architecture ||= Ohai["kernel"]["machine"]
      else
        @safe_architecture = val
      end
    end
    expose :safe_architecture
  end
end
