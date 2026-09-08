#!/usr/bin/env ruby
# frozen_string_literal: true

version, tag, sums_path = ARGV
abort "usage: render_formula.rb VERSION TAG SHA256SUMS" unless ARGV.length == 3

semver = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\z/
abort "invalid semantic version: #{version}" unless semver.match?(version)
abort "invalid release tag: #{tag}" unless /\A[0-9A-Za-z][0-9A-Za-z._-]*\z/.match?(tag)

targets = [
  ["darwin", "arm64"],
  ["darwin", "x64"],
  ["linux", "arm64"],
  ["linux", "x64"]
].freeze
expected_files = targets.to_h do |platform, arch|
  filename = "wigolo-#{version}-#{platform}-#{arch}.tar.gz"
  [[platform, arch], filename]
end

checksums = {}
File.foreach(sums_path).with_index(1) do |line, line_number|
  line = line.chomp
  next if line.empty?

  match = /\A([0-9a-fA-F]{64})  (\S+)\z/.match(line)
  abort "malformed checksum at line #{line_number}" unless match

  digest, filename = match.captures
  abort "duplicate checksum for #{filename}" if checksums.key?(filename)

  checksums[filename] = digest.downcase
end

unexpected = checksums.keys - expected_files.values
abort "unexpected checksum for #{unexpected.first}" unless unexpected.empty?

missing = expected_files.values - checksums.keys
abort "missing checksum for #{missing.first}" unless missing.empty?

download_base = "https://github.com/KnockOutEZ/wigolo/releases/download/#{tag}"

puts <<~RUBY
  class Wigolo < Formula
    desc "Local-first web intelligence for AI agents"
    homepage "https://github.com/KnockOutEZ/wigolo"
    license "AGPL-3.0-only"
    version "#{version}"

    on_macos do
      on_arm do
        url "#{download_base}/#{expected_files.fetch(["darwin", "arm64"])}"
        sha256 "#{checksums.fetch(expected_files.fetch(["darwin", "arm64"]))}"
      end
      on_intel do
        url "#{download_base}/#{expected_files.fetch(["darwin", "x64"])}"
        sha256 "#{checksums.fetch(expected_files.fetch(["darwin", "x64"]))}"
      end
    end

    on_linux do
      on_arm do
        url "#{download_base}/#{expected_files.fetch(["linux", "arm64"])}"
        sha256 "#{checksums.fetch(expected_files.fetch(["linux", "arm64"]))}"
      end
      on_intel do
        url "#{download_base}/#{expected_files.fetch(["linux", "x64"])}"
        sha256 "#{checksums.fetch(expected_files.fetch(["linux", "x64"]))}"
      end
    end

    def install
      prefix.install "wigolo/bin", "wigolo/libexec"
    end

    test do
      assert_match version.to_s, shell_output("\#{bin}/wigolo --version")
    end
  end
RUBY
