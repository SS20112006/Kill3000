cask "kill3000" do
  version "1.0.0"
  sha256 "f5bf8932b84ca6b2cf4ead328d814e19acf01d2c6c89496604d7cad97b7ba34b"

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
