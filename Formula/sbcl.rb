class Sbcl < Formula
  desc "Steel Bank Common Lisp system"
  homepage "http://www.sbcl.org/"
  url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.3.12/sbcl-1.3.12-source.tar.bz2"
  sha256 "8039ec01d04baad3ee3ebee7a830757dc488be33ca128f4a0592f8af701759c2"

  head "git://sbcl.git.sourceforge.net/gitroot/sbcl/sbcl.git"

  bottle do
    sha256 "b0eb170a32a7362c22248f95663177a0c3c4dbf4e17de7efa1eea7ac98257b10" => :sierra
    sha256 "86cae46ef9001dd322897368f4858044e10feef05f0df085be15b59f8ad932dd" => :el_capitan
    sha256 "94b9b75914e6b1b98f2adf21ea3bb409bf25922aa150026fa962ed3fbe7254b0" => :yosemite
  end

  fails_with :llvm do
    build 2334
    cause "Compilation fails with LLVM."
  end

  option "32-bit"
  option "with-internal-xref", "Include XREF information for SBCL internals (increases core size by 5-6MB)"
  option "with-ldb", "Include low-level debugger in the build"
  option "without-sources", "Don't install SBCL sources"
  option "without-core-compression", "Build SBCL without support for compressed cores and without a dependency on zlib"
  option "without-threads", "Build SBCL without support for native threads"

  # Current binary versions are listed at http://sbcl.sourceforge.net/platform-table.html
  resource "bootstrap64" do
    url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.2.11/sbcl-1.2.11-x86-64-darwin-binary.tar.bz2"
    sha256 "057d3a1c033fb53deee994c0135110636a04f92d2f88919679864214f77d0452"
  end

  resource "bootstrap32" do
    url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.1.6/sbcl-1.1.6-x86-darwin-binary.tar.bz2"
    sha256 "5801c60e2a875d263fccde446308b613c0253a84a61ab63569be62eb086718b3"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-base-target-features.diff"
    sha256 "e101d7dc015ea71c15a58a5c54777283c89070bf7801a13cd3b3a1969a6d8b75"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-make-doc.diff"
    sha256 "7c21c89fd6ec022d4f17670c3253bd33a4ac2784744e4c899c32fbe27203d87e"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-posix-tests.diff"
    sha256 "06908aaa94ba82447d64cf15eb8e011ac4c2ae4c3050b19b36316f64992ee21d"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-use-mach-exception-handler.diff"
    sha256 "089b8fdc576a9a32da0b2cdf2b7b2d8bfebf3d542ac567f1cb06f19c03eaf57d"
  end

  def write_features
    features = []
    features << ":sb-thread" if build.with? "threads"
    features << ":sb-core-compression" if build.with? "core-compression"
    features << ":sb-ldb" if build.with? "ldb"
    features << ":sb-xref-for-internals" if build.with? "internal-xref"

    File.open("customize-target-features.lisp", "w") do |file|
      file.puts "(lambda (list)"
      features.each do |f|
        file.puts "  (pushnew #{f} list)"
      end
      file.puts "  list)"
    end
  end

  def install
    write_features

    # Remove non-ASCII values from environment as they cause build failures
    # More information: https://bugs.gentoo.org/show_bug.cgi?id=174702
    ENV.delete_if do |_, value|
      ascii_val = value.dup
      ascii_val.force_encoding("ASCII-8BIT") if ascii_val.respond_to? :force_encoding
      ascii_val =~ /[\x80-\xff]/n
    end

    bootstrap = (build.build_32_bit? || !MacOS.prefer_64_bit?) ? "bootstrap32" : "bootstrap64"
    resource(bootstrap).stage do
      # We only need the binaries for bootstrapping, so don't install anything:
      command = "#{Dir.pwd}/src/runtime/sbcl"
      core = "#{Dir.pwd}/output/sbcl.core"
      xc_cmdline = "#{command} --core #{core} --disable-debugger --no-userinit --no-sysinit"

      cd buildpath do
        ENV["SBCL_ARCH"] = "x86" if build.build_32_bit?
        Pathname.new("version.lisp-expr").write('"1.0.99.999"') if build.head?
        system "./make.sh", "--prefix=#{prefix}", "--xc-host=#{xc_cmdline}"
      end
    end

    ENV["INSTALL_ROOT"] = prefix
    system "sh", "install.sh"

    if build.with? "sources"
      bin.env_script_all_files(libexec/"bin", :SBCL_SOURCE_ROOT => pkgshare/"src")
      pkgshare.install %w[contrib src]

      (lib/"sbcl/sbclrc").write <<-EOS.undent
        (setf (logical-pathname-translations "SYS")
          '(("SYS:SRC;**;*.*.*" #p"#{pkgshare}/src/**/*.*")))
        EOS
    end
  end

  test do
    (testpath/"simple.sbcl").write <<-EOS.undent
      (write-line (write-to-string (+ 2 2)))
    EOS
    output = shell_output("#{bin}/sbcl --script #{testpath}/simple.sbcl")
    assert_equal "4", output.strip
  end
end
