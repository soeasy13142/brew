# frozen_string_literal: true

require "utils/shell"

RSpec.describe Utils::Shell do
  describe "::profile" do
    it "returns ~/.profile by default" do
      ENV["SHELL"] = "/bin/another_shell"
      expect(described_class.profile).to eq("~/.profile")
    end

    it "returns ~/.profile for sh" do
      ENV["SHELL"] = "/bin/sh"
      expect(described_class.profile).to eq("~/.profile")
    end

    it "returns ~/.profile for Bash" do
      ENV["SHELL"] = "/bin/bash"
      expect(described_class.profile).to eq("~/.profile")
    end

    it "returns /tmp/.zshrc for Zsh if ZDOTDIR is /tmp" do
      ENV["SHELL"] = "/bin/zsh"
      ENV["HOMEBREW_ZDOTDIR"] = "/tmp"
      expect(described_class.profile).to eq("/tmp/.zshrc")
    end

    it "returns ~/.zshrc for Zsh" do
      ENV["SHELL"] = "/bin/zsh"
      ENV["HOMEBREW_ZDOTDIR"] = nil
      expect(described_class.profile).to eq("~/.zshrc")
    end

    it "returns ~/.kshrc for Ksh" do
      ENV["SHELL"] = "/bin/ksh"
      expect(described_class.profile).to eq("~/.kshrc")
    end

    it "returns ~/.config/powershell/Microsoft.PowerShell_profile.ps1 for PowerShell" do
      ENV["SHELL"] = "/usr/bin/pwsh"
      expect(described_class.profile).to eq("~/.config/powershell/Microsoft.PowerShell_profile.ps1")
    end
  end

  describe "::from_path" do
    it "supports a raw command name" do
      expect(described_class.from_path("bash")).to eq(:bash)
    end

    it "supports full paths" do
      expect(described_class.from_path("/bin/bash")).to eq(:bash)
    end

    it "supports versions" do
      expect(described_class.from_path("zsh-5.2")).to eq(:zsh)
    end

    it "strips newlines" do
      expect(described_class.from_path("zsh-5.2\n")).to eq(:zsh)
    end

    it "returns nil when input is invalid" do
      expect(described_class.from_path("")).to be_nil
      expect(described_class.from_path("@@@@@@")).to be_nil
      expect(described_class.from_path("invalid_shell-4.2")).to be_nil
    end
  end

  specify "::sh_quote" do
    expect(described_class.send(:sh_quote, "")).to eq("''")
    expect(described_class.send(:sh_quote, "\\")).to eq("\\\\")
    expect(described_class.send(:sh_quote, "\n")).to eq("'\n'")
    expect(described_class.send(:sh_quote, "$")).to eq("\\$")
    expect(described_class.send(:sh_quote, "word")).to eq("word")
  end

  specify "::csh_quote" do
    expect(described_class.send(:csh_quote, "")).to eq("''")
    expect(described_class.send(:csh_quote, "\\")).to eq("\\\\")
    # NOTE: This test is different than for `sh`.
    expect(described_class.send(:csh_quote, "\n")).to eq("'\\\n'")
    expect(described_class.send(:csh_quote, "$")).to eq("\\$")
    expect(described_class.send(:csh_quote, "word")).to eq("word")
  end

  describe "::prepend_path_in_profile" do
    let(:path) { "/my/path" }

    it "supports tcsh" do
      ENV["SHELL"] = "/bin/tcsh"
      expect(described_class.prepend_path_in_profile(path))
        .to eq("echo 'setenv PATH #{path}:$PATH' >> #{described_class.profile}")
    end

    it "supports Bash" do
      ENV["SHELL"] = "/bin/bash"
      expect(described_class.prepend_path_in_profile(path))
        .to eq("echo 'export PATH=\"#{path}:$PATH\"' >> #{described_class.profile}")
    end

    it "supports fish" do
      ENV["SHELL"] = "/usr/local/bin/fish"
      ENV["fish_user_paths"] = "/some/path"
      expect(described_class.prepend_path_in_profile(path))
        .to eq("fish_add_path #{path}")
    end
  end

  describe "::shell_with_prompt" do
    it "returns zsh-specific prompt configuration" do
      ENV["SHELL"] = "/bin/zsh"
      expect(described_class.shell_with_prompt("test", preferred_path: "/bin/zsh", notice: "")).to eq(
        "PROMPT='%B%F{green}test%f %F{blue}$%f%b ' RPROMPT='[%B%F{red}%~%f%b]' /bin/zsh -f",
      )
    end

    it "returns generic shell prompt configuration" do
      ENV["SHELL"] = "/bin/bash"
      expect(described_class.shell_with_prompt("test", preferred_path: "/bin/bash", notice: "")).to eq(
        "PS1=\"\\[\\033[1;32m\\]brew \\[\\033[1;31m\\]\\w \\[\\033[1;34m\\]$\\[\\033[0m\\] \" /bin/bash",
      )
    end

    it "outputs notice when provided" do
      notice = "Test Notice"
      expect { described_class.shell_with_prompt("test", preferred_path: "/bin/bash", notice: notice) }
        .to output("#{notice}\n").to_stdout
    end
  end
end
