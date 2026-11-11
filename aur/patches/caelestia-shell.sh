# The dotfiles run the caelestia v2.5.0 QML on the official `quickshell` package (0.3.x), not quickshell-git.
sed -i 's/\bquickshell-git\b/quickshell/g' PKGBUILD
