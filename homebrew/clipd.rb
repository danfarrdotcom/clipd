class Clipd < Formula
  desc "Lightweight macOS menu bar app for recording GIFs and videos"
  homepage "https://github.com/danfarrdotcom/clipd"
  url "https://github.com/danfarrdotcom/clipd/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACE_HOLDER_SHA256"
  license "MIT"

  depends_on :macos
  depends_on arch: :arm64
  depends_on xcode: ["15.0", :build]

  def install
    system "make", "build"
    prefix.install "build/Release/Clipd.app"
  end

  def caveats
    <<~EOS
      To run Clipd:
        ln -s #{prefix}/Clipd.app /Applications/
        open /Applications/Clipd.app
    EOS
  end
end
