# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tempfile"

class RenderFormulaTest < Minitest::Test
  RENDERER = File.expand_path("../script/render_formula.rb", __dir__)
  VERSION = "1.2.3-rc.1"
  TAG = "binary-v1.2.3-rc.1"
  CHECKSUMS = {
    "wigolo-#{VERSION}-darwin-arm64.tar.gz" => "a" * 64,
    "wigolo-#{VERSION}-darwin-x64.tar.gz" => "b" * 64,
    "wigolo-#{VERSION}-linux-arm64.tar.gz" => "c" * 64,
    "wigolo-#{VERSION}-linux-x64.tar.gz" => "d" * 64
  }.freeze

  def test_renders_complete_formula_for_exact_release_inputs
    stdout, stderr, status = render(checksum_text)

    assert status.success?, stderr
    assert_empty stderr
    assert_equal expected_formula, stdout
  end

  def test_rejects_a_missing_checksum_cell
    stdout, stderr, status = render(checksum_text(CHECKSUMS.to_a.drop(1)))

    refute status.success?
    assert_empty stdout
    assert_match(/missing checksum.*darwin-arm64/, stderr)
  end

  def test_rejects_a_duplicate_checksum_cell
    entries = CHECKSUMS.to_a + [CHECKSUMS.to_a.first]
    stdout, stderr, status = render(checksum_text(entries))

    refute status.success?
    assert_empty stdout
    assert_match(/duplicate checksum/, stderr)
  end

  def test_rejects_a_malformed_checksum_cell
    entries = CHECKSUMS.to_a
    entries[0] = [entries[0][0], "f" * 63]
    stdout, stderr, status = render(checksum_text(entries))

    refute status.success?
    assert_empty stdout
    assert_match(/malformed checksum/, stderr)
  end

  def test_rejects_an_unexpected_checksum_cell
    entries = CHECKSUMS.to_a + [["wigolo-#{VERSION}-windows-x64.zip", "e" * 64]]
    stdout, stderr, status = render(checksum_text(entries))

    refute status.success?
    assert_empty stdout
    assert_match(/unexpected checksum/, stderr)
  end

  def test_rejects_a_non_semantic_version_before_rendering
    stdout, stderr, status = render(checksum_text, version: '1.2"\nend')

    refute status.success?
    assert_empty stdout
    assert_match(/invalid semantic version/, stderr)
  end

  def test_rejects_a_tag_that_is_not_a_safe_exact_url_component
    stdout, stderr, status = render(checksum_text, tag: "release/tag")

    refute status.success?
    assert_empty stdout
    assert_match(/invalid release tag/, stderr)
  end

  private

  def render(contents, version: VERSION, tag: TAG)
    Tempfile.create("SHA256SUMS") do |file|
      file.write(contents)
      file.flush
      return Open3.capture3("ruby", RENDERER, version, tag, file.path)
    end
  end

  def checksum_text(entries = CHECKSUMS.to_a)
    entries.map { |filename, digest| "#{digest}  #{filename}" }.join("\n") + "\n"
  end

  def expected_formula
    <<~RUBY
      class Wigolo < Formula
        desc "Local-first web intelligence for AI agents"
        homepage "https://github.com/KnockOutEZ/wigolo"
        license "AGPL-3.0-only"
        version "#{VERSION}"

        on_macos do
          on_arm do
            url "https://github.com/KnockOutEZ/wigolo/releases/download/#{TAG}/wigolo-#{VERSION}-darwin-arm64.tar.gz"
            sha256 "#{"a" * 64}"
          end
          on_intel do
            url "https://github.com/KnockOutEZ/wigolo/releases/download/#{TAG}/wigolo-#{VERSION}-darwin-x64.tar.gz"
            sha256 "#{"b" * 64}"
          end
        end

        on_linux do
          on_arm do
            url "https://github.com/KnockOutEZ/wigolo/releases/download/#{TAG}/wigolo-#{VERSION}-linux-arm64.tar.gz"
            sha256 "#{"c" * 64}"
          end
          on_intel do
            url "https://github.com/KnockOutEZ/wigolo/releases/download/#{TAG}/wigolo-#{VERSION}-linux-x64.tar.gz"
            sha256 "#{"d" * 64}"
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
  end
end
