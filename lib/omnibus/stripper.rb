require "omnibus/sugarable"

module Omnibus
  class Stripper
    include Instrumentation
    include Logging
    include Util
    include Sugarable

    class << self
      # @see (stripper#new)
      def run!(project)
        new(project).run!
      end
    end

    #
    # The project to strip.
    #
    # @return [Project]
    #
    attr_reader :project

    #
    # Run the stripper against the given project. It is assumed that the
    # project has already been built.
    #
    # @param [Project] project
    #   the project to strip
    #
    def initialize(project)
      @project = project
    end

    #
    # Run the stripping operation. Stripping currently only available on Linux.
    #
    # TODO: implement other platforms windows, macOS, etc
    #
    # @return [true]
    #   if the checks pass
    #
    def run!
      measure("Stripping time") do
        log.info(log_key) { "Running strip on #{project.name}" }
        # TODO: properly address missing platforms / linux
        case Ohai["platform"]
        when "mac_os_x"
          log.warn(log_key) { "Currently unsupported in macOS platforms." }
        when "aix"
          log.warn(log_key) { "Currently unsupported in AIX platforms." }
        when "windows"
          strip_windows
        else
          strip_linux
        end
      end
    end

    #
    # The list of patterns to skip (ignore) stripping files on from the
    # project and softwares.
    #
    # @return [Array<String, Regexp>]
    #
    def strip_skip
      project.library.components.inject(project.strip_exclude_paths) do |array, component|
        array += component.strip_exclude_paths
        array
      end
    end

    def strip_linux
      path = project.install_dir
      log.debug(log_key) { "stripping on linux: #{path}" }
      symboldir = File.join(path, ".debug")
      log.debug(log_key) { "putting symbols here: #{symboldir}" }
      yield_shellout_results("find #{path}/ -type f -exec file {} \\; | grep 'ELF' | cut -f1 -d:") do |elf|
        log.debug(log_key) { "processing: #{elf}" }
        source = elf.strip

        next if strip_skip.any? { |exclude| File.fnmatch?(exclude, source, File::FNM_DOTMATCH) }

        debugfile = "#{source}.dbg"
        target = File.join(symboldir, debugfile)

        elfdir = File.dirname(debugfile)
        FileUtils.mkdir_p "#{symboldir}/#{elfdir}" unless Dir.exist? "#{symboldir}/#{elfdir}"

        log.debug(log_key) { "stripping #{source}, putting debug info into #{target}" }
        shellout!("objcopy --only-keep-debug #{source} #{target}")
        shellout!("strip --strip-debug --strip-unneeded #{source}")
        shellout("objcopy --add-gnu-debuglink=#{target} #{source}")
        shellout!("chmod -x #{target}")
      end
    end

    #
    # Strip symbol from binaries on Windows. Notice that this behavior differs from Linux.
    #
    # On Windows, DBG files are the original files, aka the un-stripped files.
    # On Linux, DBG files are just symbol files.
    #
    # On Windows, symbol files can be used for non-live debugging e.g. dlv core c:\share\agent.dbg "C:\Share\agent.DMP"
    # However, DLV cannot use the pure symbol files in live debugging:
    #
    #   C:\>dlv attach 6600 "C:\Program Files\Datadog\Datadog Agent\bin\agent.dbg"
    #   could not attach to pid 6600: decoding dwarf section info at offset 0x0: too short
    #
    #   C:\Program Files\Datadog\Datadog Agent\bin>dlv attach 4024
    #   could not attach to pid 4024: decoding dwarf section info at offset 0x0: too short
    #
    # To enable live debugging on Windows, we make DBG files on Windows the unstripped file.
    # To perform live debugging, one must manually replace the stripped file with unstripped
    # first, then can start debugging use DLV.
    #
    # To perform non-live debugging, the same command can be used, e.g. dlv core c:\share\agent.dbg "C:\Share\agent.DMP"
    #
    def strip_windows
      path = project.install_dir
      # log.debug(log_key) { "stripping on windows: #{path}" }
      log.info(log_key) { "stripping on windows: #{path}" }

      symboldir = File.join(path, ".debug")
      # log.debug(log_key) { "putting symbols here: #{symboldir}" }
      log.info(log_key) { "putting symbols here: #{symboldir}" }

      if project.windows_files_to_strip
        project.windows_files_to_strip.each do |elf|
          # log.debug(log_key) { "processing: #{elf}" }
          log.info(log_key) { "processing: #{elf}" }
          source = elf.strip

          log.info(log_key) { "processing source: #{source}" } # XXX

          debugfile = "#{source}.debug"
          #
          # Unlike Linux, we have a drive letter in front of the path. Need to drop it before
          # joining the path. So far the final path length will be less than 255, but need to
          # watch out.
          #
          debugfile = debugfile[2..debugfile.length-1] if debugfile[1] == ":"

          log.info(log_key) { "processing debugfile: #{debugfile}" } # XXX

          target = File.join(symboldir, debugfile)
          log.info(log_key) { "processing target: #{target}" } # XXX
          if target.legnth > 255
            log.error(log_key) { "target name is too long: #{target}" }
          end

          elfdir = File.dirname(target)
          log.info(log_key) { "processing elfdir: #{elfdir}" } # XXX
          FileUtils.mkdir_p "#{elfdir}" unless Dir.exist? "#{elfdir}"

          # log.debug(log_key) { "stripping #{source}, putting original file into #{target}" }
          log.info(log_key) { "stripping #{source}, putting original file into #{target}" }
          shellout!("cp #{source} #{target}")
          shellout!("strip --strip-debug --strip-unneeded #{source}")
        end

        zip_file = windows_safe_path(Config.package_dir, "#{project.package_name}.debug.zip")
        cmd = <<-EOH.split.join(" ").squeeze(" ").strip
          7z a -r
          #{zip_file}
          #{symboldir}\\*
        EOH
        shellout!(cmd)

        cmd = <<-EOH.split.join(" ").squeeze(" ").strip
          rm -rf
          #{symboldir}
        EOH
        shellout!(cmd)
      end
    end
  end
end
