#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'
require 'timeout'

class WorkPersistenceProbe
  ROOT = File.expand_path('..', __dir__)
  HELPER = File.join(ROOT, 'scripts/fixtures/work-persistence-probe.swift')
  TIME_LIMIT = 60
  RSS_LIMIT_KB = 1_048_576

  def initialize(products:, output:)
    @products = File.expand_path(products)
    @output = File.expand_path(output)
    @output_created = false
    @child_counter = 0
    source_hashes = Dir.glob(File.join(ROOT, 'Core/WriteKit/**/*.swift')).sort.to_h do |path|
      [path, Digest::SHA256.file(path).hexdigest]
    end
    @report = { 'scope' => 'Work Kit staging interruption probe; no AppKit promotion or power-loss claim',
                'limits' => { 'childSeconds' => TIME_LIMIT, 'rssKiB' => RSS_LIMIT_KB,
                              'paragraphs' => 5_000, 'opaqueResourceBytes' => 32 * 1_024 * 1_024 },
                'sourceSHA256' => { HELPER => Digest::SHA256.file(HELPER).hexdigest,
                                    __FILE__ => Digest::SHA256.file(__FILE__).hexdigest }.merge(source_hashes),
                'commands' => [], 'classification' => 'incomplete' }
  end

  def command!(*argv)
    result = monitored_child(argv, interrupt: false)
    stdout = File.read(result.fetch('stdoutLog'))
    stderr = File.read(result.fetch('stderrLog'))
    @report['commands'] << result.merge('stdout' => stdout, 'stderr' => stderr)
    raise "Command failed (#{result['exitStatus']} signal=#{result['signal']}): #{argv.join(' ')}\n#{stderr}" unless result['exitStatus'] == 0
    stdout
  end

  def run
    FileUtils.mkdir_p(File.dirname(@output))
    Dir.mkdir(@output)
    @output_created = true
    binary = File.join(@output, 'work-persistence-probe')
    @report['productsDirectory'] = @products
    @report['productSHA256'] = %w[WriteKit FolioKit].to_h do |name|
      executable = File.join(@products, "#{name}.framework/Versions/A/#{name}")
      raise "Missing built framework executable: #{executable}" unless File.file?(executable)
      [executable, Digest::SHA256.file(executable).hexdigest]
    end
    sdk = command!('xcrun', '--sdk', 'macosx', '--show-sdk-path').strip
    compile = ['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '6',
               '-strict-concurrency=complete', '-warnings-as-errors', '-sdk', sdk, '-F', @products,
               '-framework', 'WriteKit', '-framework', 'FolioKit', '-Xlinker', '-rpath',
               '-Xlinker', @products, HELPER, '-o', binary]
    command!(*compile)

    Dir.mktmpdir('folio-work-persistence-probe-') do |root|
      source = File.join(root, 'Work.flwrbundle')
      staged = File.join(root, 'Interrupted.flwrbundle')
      retry_stage = File.join(root, 'Retry.flwrbundle')
      marker = File.join(root, 'writer-started')
      FileUtils.mkdir_p(staged)
      command!(binary, 'setup', root)
      FileUtils.mv(File.join(root, 'Original.flwrbundle'), source)
      @report['sourcePackageSHA256Before'] = package_digest(source)

      status = monitored_child([binary, 'write', source, staged, marker], marker: marker,
                               interrupt_path: File.join(staged, 'Work.sqlite'), interrupt: true)
      @report['interruption'] = status
      command!(binary, 'verify-source', source)
      # Only this runner's private staging directory is discarded.
      FileUtils.rm_rf(staged)
      FileUtils.mkdir_p(retry_stage)
      retry_status = monitored_child([binary, 'write', source, retry_stage,
                                      File.join(root, 'retry-started')], marker: nil, interrupt: false)
      @report['retry'] = retry_status
      raise 'Retry writer failed' unless retry_status['exitStatus'] == 0
      command!(binary, 'verify', source, retry_stage)
      save_report = retry_status.fetch('workSaveReport')
      raise 'Expected exactly one changed paragraph and run' unless save_report['changedParagraphs'] == 1 && save_report['changedRuns'] == 1
      resource_bytes = save_report.fetch('clonedResourceBytes') + save_report.fetch('copiedResourceBytes')
      raise 'Expected the staged save to account for the 32 MiB resource' unless resource_bytes >= 32 * 1_024 * 1_024
      raise 'Interruption was not observed while the writer was active' unless status['proved']
      @report['sourcePackageSHA256After'] = package_digest(source)
      raise 'Source package bytes changed during staging' unless @report['sourcePackageSHA256Before'] == @report['sourcePackageSHA256After']
      @report['classification'] = 'passed'
      @report['performance'] = save_report
    end
    write_report
    puts "Work persistence probe passed; report: #{File.join(@output, 'report.json')}"
  rescue StandardError => error
    @report['error'] = error.message
    write_report if @output_created
    warn error.message
    exit 1
  end

  private

  def monitored_child(argv, marker: nil, interrupt_path: nil, interrupt:)
    child_id = @child_counter
    @child_counter += 1
    stdout_path = File.join(@output, "child-#{child_id}.stdout.log")
    stderr_path = File.join(@output, "child-#{child_id}.stderr.log")
    out = File.open(stdout_path, 'w')
    err = File.open(stderr_path, 'w')
    pid = Process.spawn(*argv, out: out, err: err, pgroup: true)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rss_peak = 0
    killed = false
    status = nil
    begin
      loop do
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        raise "Child exceeded #{TIME_LIMIT}s: #{argv.join(' ')}" if elapsed > TIME_LIMIT
        status = Process.waitpid2(pid, Process::WNOHANG)&.last
        break if status
        begin
          rss = process_rss(pid)
        rescue StandardError
          status = Process.waitpid2(pid, Process::WNOHANG)&.last
          break if status
          raise
        end
        rss_peak = [rss_peak, rss].max
        raise "Child exceeded #{RSS_LIMIT_KB} KiB RSS" if rss > RSS_LIMIT_KB
        if interrupt && !killed && File.exist?(marker) && File.exist?(interrupt_path)
          Process.kill('KILL', -pid)
          killed = true
        end
        sleep 0.02
      end
    rescue StandardError => error
      @report['failedChild'] = { 'argv' => argv, 'pid' => pid, 'error' => error.message,
                                 'stdoutLog' => stdout_path, 'stderrLog' => stderr_path }
      raise
    ensure
      unless status
        begin
          Process.kill('KILL', -pid)
        rescue Errno::ESRCH
          nil
        ensure
          begin
            Process.waitpid(pid)
          rescue Errno::ECHILD
            nil
          end
        end
      end
      out.close
      err.close
    end
    result = { 'id' => child_id, 'argv' => argv, 'elapsedSeconds' => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
               'peakRSSKiB' => rss_peak, 'exitStatus' => status.exitstatus,
               'signal' => status.termsig, 'stdoutLog' => stdout_path, 'stderrLog' => stderr_path,
               'killSent' => killed }
    result['proved'] = !!(killed && status.signaled? && status.termsig == Signal.list.fetch('KILL'))
    if File.file?(stdout_path)
      output = File.read(stdout_path)
      report_line = output.lines.reverse.find { |line| line.start_with?('{') }
      result['workSaveReport'] = JSON.parse(report_line) if report_line
    end
    result
  end

  def process_rss(pid)
    value, error, status = Timeout.timeout(2) { Open3.capture3('ps', '-axo', 'pgid=,rss=') }
    raise "Unable to monitor child RSS: #{error}" unless status.success?
    value.lines.sum do |line|
      group, rss = line.split.map { |part| Integer(part, 10) }
      raise 'Malformed process sample' unless group && rss
      group == pid ? rss : 0
    end
  rescue Timeout::Error, ArgumentError => error
    raise "Unable to monitor child RSS: #{error.message}"
  end

  def package_digest(path)
    Dir.glob(File.join(path, '**', '*'), File::FNM_DOTMATCH).select { |item| File.file?(item) }
       .sort.to_h { |item| [item.delete_prefix(path + '/'), Digest::SHA256.file(item).hexdigest] }
  end

  def write_report
    FileUtils.mkdir_p(@output)
    File.write(File.join(@output, 'report.json'), JSON.pretty_generate(@report) + "\n")
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length < 1 || ARGV.length > 2
    warn 'Usage: ruby scripts/verify-work-persistence.rb PRODUCTS [OUTPUT_DIRECTORY]'
    exit 2
  end
  output = ARGV[1] || File.join(WorkPersistenceProbe::ROOT,
                               "build/work-persistence-probe-#{Time.now.utc.strftime('%Y%m%dT%H%M%S%N')}")
  WorkPersistenceProbe.new(products: ARGV[0], output: output).run
end
