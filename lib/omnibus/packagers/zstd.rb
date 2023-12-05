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
  class Packager::ZSTD < Packager::Base
    id :zstd

    setup do
    end

    build do
      zip_file = windows_safe_path(Config.package_dir, zip_name)
      zip_source_path = "#{windows_safe_path(project.install_dir)}/*"
      cmd = <<-EOH.split.join(" ").squeeze(" ").strip
        tar --zstd -cf
        #{zip_file}
        #{zip_source_path}
      EOH
      shellout!(cmd)
    end

    # @see Base#package_name
    def package_name
      zip_name
    end

    # @see Base#debug_build?
    # The zip packager doesn't support debug packaging
    # HACK: This is needed to avoid failures when the Project#package_me method tries
    # to fetch the debug package produced by each packager,
    # as the Windows build uses both the MSI packager (which does have a debug package) and
    # the ZIP packager (which doesn't have a debug package).
    def debug_build?
      false
    end

    def zip_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}-#{safe_architecture}.tar.zst"
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
        @safe_architecture ||= shellout!("uname --processor").stdout.strip
      else
        @safe_architecture = val
      end
    end
    expose :safe_architecture
  end
end
