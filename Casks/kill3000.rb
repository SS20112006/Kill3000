cask "kill3000" do
  version "1.0.0"
  sha256 "1f63ad4214f0887a0da401c7721f28eea9ff660ac73b6662e01ece2b9b06bf29"

  url "https://github.com/SS20112006/Kill3000/releases/download/v#{version}/Kill3000.zip"
  name "Kill3000"
  desc "Lightweight native macOS menu bar app to inspect and terminate local development servers"
  homepage "https://github.com/SS20112006/Kill3000"

  depends_on macos: ">= :sonoma"

  app "Kill3000.app"

  zap trash: [
    "~/Library/Caches/com.simaosousa.kill3000",
    "~/Library/Preferences/com.simaosousa.kill3000.plist",
  ]
end
