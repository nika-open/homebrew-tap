# Formula/nika.rb — pre-built binaries, multi-arch (macOS + Linux)
# Bumped by CI on each release (release.yml → bump homebrew tap) · manual fallback:
# scripts/release/update-formula.sh (in the nika engine repo)
class Nika < Formula
  desc "Workflow language for AI - audit pipelines before they run, trace after"
  homepage "https://nika.sh"
  version "0.125.2"
  license "AGPL-3.0-or-later"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/nika-open/nika/releases/download/v#{version}/nika-macos-arm64-#{version}.tar.gz"
      sha256 "fcd162d05c650ce43fa4650ed180b2d38eec90f26139a6034fd7a64705fbc86e"
    else
      url "https://github.com/nika-open/nika/releases/download/v#{version}/nika-macos-x64-#{version}.tar.gz"
      sha256 "97eef5c3d9df04c689210e934d951696e27e84addc5a567be008aa93ff18167a"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/nika-open/nika/releases/download/v#{version}/nika-linux-arm64-#{version}.tar.gz"
      sha256 "a01b124d62fd8ccdbde332e556518b76d6924a1fabd05e2f35f652a005bfeb7a"
    else
      url "https://github.com/nika-open/nika/releases/download/v#{version}/nika-linux-x64-#{version}.tar.gz"
      sha256 "097a5401374f70303a9efea3da7b1c51e5b7cd735f9218f418ba0e2078dd58de"
    end
  end

  def install
    bin.install "nika"
    generate_completions_from_executable(bin/"nika", "completions")
  end

  def caveats
    <<~EOS
      First 60 seconds:
        nika welcome                                    # what this machine has - where to start
        nika try 01-hello                               # offline proof - zero keys - nothing written
        nika init                                       # wire THIS repo (editor schema - AGENTS.md - Cursor rule)

      Fully local, no API key (install ollama first):
        ollama pull qwen3.5:4b
        nika try 01-hello --model ollama/qwen3.5:4b

      Editors and agents:
        nika wire cursor|claude|vscode                  # explicit MCP wiring (idempotent)
        nika compile hello my-first.nika               # write an offline workflow - then: nika check

      Agent plugin kit (skills - subagents - /nika:* commands - hooks - MCP, one bundle):
        claude plugin marketplace add nika-open/nika-plugins && claude plugin install nika@nika
        codex plugin marketplace add nika-open/nika-plugins && codex plugin add nika@nika
        nika doctor                                     # is the suite coherent? (binary - kits - keys)

      Learn: https://nika.sh - docs: https://docs.nika.sh
    EOS
  end

  test do
    # The binary self-reports its version.
    assert_match version.to_s, shell_output("#{bin}/nika --version")

    # A minimal nine-key workflow must pass static checking (the `check` ladder).
    # Identity is `nika: <kebab-id>` (nine keys).
    (testpath/"brew-smoke.nika").write <<~YAML
      nika: brew-smoke
      permits:
        exec: ["echo"]
      tasks:
        hello:
          exec: { command: ["echo", "hello"] }
    YAML
    assert_match "PLAN", shell_output("#{bin}/nika check #{testpath}/brew-smoke.nika")

    # The authoring command taught in caveats must produce a checkable program.
    system bin/"nika", "compile", "hello", testpath/"my-first.nika"
    assert_path_exists testpath/"my-first.nika"
    assert_match "PLAN", shell_output("#{bin}/nika check #{testpath}/my-first.nika")

    # The engine must also EXECUTE, not just statically check — an install that
    # can `check` but not `run` passes the line above yet is broken for users.
    # A one-task infer under the mock provider is hermetic (no network, no key,
    # no permits) and proves the run path end to end.
    (testpath/"brew-run-smoke.nika").write <<~YAML
      nika: brew-run-smoke
      tasks:
        greet:
          infer: { prompt: "say hello" }
    YAML
    assert_match "1/1 done",
      shell_output("#{bin}/nika run #{testpath}/brew-run-smoke.nika --model mock/echo")
  end
end
