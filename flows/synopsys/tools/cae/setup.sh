#!/bin/bash
# File:        setup.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-13
# Description: UW CAE Linux machines only (page: flows/synopsys/track/cae.md). Installs what Track B2 needs next to CAE's Synopsys
#              modules into one folder: Python 3.10 with cocotb, KLayout, wrappers for StarRC, and env.sh.
#              Usage: flows/synopsys/tools/cae/setup.sh [--prefix <folder>]   (default /var/tmp/$USER/sb-tools)
#              Run it on the host (not inside synopsys-run). Running it again skips what is already installed.
set -euo pipefail

# --- pinned versions and downloads ---
# Python from conda-forge, with the conda of CAE's module conda-forge/26.3.2; the packages from PyPI
MAMBA=/srv/auto/apps/conda-forge/x86_64/26.3.2/bin/mamba
PYTHON_VERSION=3.10.22
COCOTB_VERSION=2.1.0
PIP_PACKAGES="cocotb==$COCOTB_VERSION find_libpython==0.5.1 pytest==9.1.1 pluggy==1.6.0 iniconfig==2.3.1 packaging==26.3
              tomli==2.5.0 exceptiongroup==1.3.1"
# KLayout: the RHEL 8 build from klayout.org and the AlmaLinux 8 libraries it needs that the CAE container lacks
KLAYOUT_VERSION=0.30.12
KLAYOUT_RPM="klayout-0.30.12-0.x86_64.rpm 39d72859eefb7d874a1cacd793380efb9fde432509ae14e4302b4283ca3f4c8d"
KLAYOUT_URL=https://www.klayout.org/downloads/CentOS_8
EL8_URLS="https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages
          https://vault.almalinux.org/8.10/AppStream/x86_64/os/Packages"
EL8_RPMS=(
    "flac-libs-1.3.2-9.el8_8.1.x86_64.rpm eb76f5c999ef91f886eb807b8619bb5edb96daa25d9b98421264ca03e84be79e"
    "gsm-1.0.17-5.el8.x86_64.rpm a4800b2b993d4029d30944898fa91e24535066a3aae0e9a31c8a8666157d3e5c"
    "http-parser-2.8.0-9.el8.x86_64.rpm e8d49cae087d18aff158f535d10e5d444ecb94d2da7f40584b6557cfefae9af4"
    "libasyncns-0.8-14.el8.x86_64.rpm aff7e9860de4670e44e7ad41ed6df350d8cd054796c2c5cc02a029175534fc2a"
    "libgit2-0.26.8-2.el8.x86_64.rpm fc2737819b578f2f08d8c2484f65839e265eaf6b1ccb8478a4cb0a4a7c525c8f"
    "libogg-1.3.2-10.el8.x86_64.rpm 3e1fca6cb166d9974a3ef8de5ca201c72bfa1ea40225db8e64dfc663a779ab12"
    "libsndfile-1.0.28-17.el8_10.x86_64.rpm 1129d63db1d9752d5be02c431e18855d5d62457c9efa0d042b090f11337990b8"
    "libvorbis-1.3.6-2.el8.x86_64.rpm 9ecabb1ee69662e028c90a90b24e094745849cda3f0bb6591450ad9194ded552"
    "opus-1.3-0.4.beta.el8.x86_64.rpm dd8b85732bf7235739f237735a318d621900dc7d315beda0764a1c05d9654408"
    "pulseaudio-libs-14.0-4.el8.x86_64.rpm 0759effeea606a6cec803335bb267a56098f454f1c60a6dd90692ed5864789d6"
    "pulseaudio-libs-glib2-14.0-4.el8.x86_64.rpm ace5fbe178efdf914e7a0fc0d89bec28ebb2d461e1dffcf9fc4405217272519a"
    "qt5-qtmultimedia-5.15.3-1.el8.x86_64.rpm 2f0cba1b132e9458232da38a8911bc57083a8271a01264101bad164afc95f913"
    "qt5-qtsvg-5.15.3-2.el8.x86_64.rpm fd1cb7c143f582045cf6b0775b22fc9cb6633348a0dc21797c5e1d4e0e80dd77"
    "qt5-qttools-libs-designer-5.15.3-6.el8.x86_64.rpm d5e75b4c0c6c8461a8bd955ea47e42759e4d55c223eb083f80e08ab57a1ea7d4"
    "qt5-qtxmlpatterns-5.15.3-1.el8.x86_64.rpm 9193c6a59bdcac7da9e34abd5c76f0fad304c76c0918566787a92749adfbbf6b"
    "ruby-libs-2.5.9-116.module_el8.10.0+4294+1072b022.x86_64.rpm 0baeea3e623bd9cb087ea9230f108d9967b78b427b1018739a69a4cd1129a8f0"
)

self=$(readlink -f "$0")
prefix=/var/tmp/$USER/sb-tools
check=0
while [ $# -gt 0 ]; do
    case $1 in
        --prefix) prefix=${2:?--prefix needs a folder}; shift 2 ;;
        --check) check=1; shift ;;      # used by the last step, inside the container
        -h|--help) sed -n '5,8p' "$0" | sed 's/^# *//'; exit 0 ;;
        *) echo "setup.sh: unknown option $1 (see --help)" >&2; exit 2 ;;
    esac
done
case $prefix in *" "*) echo "setup.sh: the folder name must not contain spaces: $prefix" >&2; exit 2 ;; esac

# --- check, inside the container: each tool starts ---
if [ $check = 1 ]; then
    "$prefix/py/bin/python3" -c 'import sys, cocotb; print("python", sys.version.split()[0], "cocotb", cocotb.__version__)'
    "$prefix/bin/klayout" -zz -v
    case :${LOADEDMODULES:-}: in
        *:synopsys/starrc/*) out=$("$prefix/bin/StarXtract" -v 2>&1 || true); grep -m1 -e '^Version' -e GLIBCXX <<< "$out" | sed 's/^/StarXtract /' ;;
        *) echo "StarRC module not loaded: StarXtract not checked" ;;
    esac
    exit 0
fi

# the folder holds only what this script writes
mkdir -p "$prefix"
prefix=$(cd "$prefix" && pwd)
if [ ! -f "$prefix/.sb-tools" ] && [ -n "$(ls -A "$prefix")" ]; then
    echo "setup.sh: $prefix is not empty and was not made by this script; choose a new folder with --prefix" >&2
    exit 1
fi
touch "$prefix/.sb-tools"
dl=$prefix/downloads
mkdir -p "$dl" "$prefix/bin"
start=$SECONDS
echo "setup.sh: installing into $prefix"

# fetch <file> <sha256> <base URL>...: download into downloads/ unless a copy with that checksum is there
fetch() {
    local file=$1 sha=$2 base; shift 2
    if [ -f "$dl/$file" ] && echo "$sha  $dl/$file" | sha256sum --check --status; then return; fi
    for base in "$@"; do
        if curl -fsSL --retry 3 -o "$dl/$file.part" "$base/${file//+/%2B}" &&
           echo "$sha  $dl/$file.part" | sha256sum --check --status; then
            mv -f "$dl/$file.part" "$dl/$file"
            return
        fi
    done
    echo "setup.sh: could not download $file with the expected checksum from: $*" >&2
    exit 1
}

# 1. Python and cocotb: make sim and make gls run python3 inside the container, which has no Python
py=$prefix/py/bin/python3
if "$py" -c "import sys, cocotb; sys.exit(sys.version.split()[0] != '$PYTHON_VERSION' or cocotb.__version__ != '$COCOTB_VERSION')" 2>/dev/null; then
    echo "1/3 Python $PYTHON_VERSION and cocotb $COCOTB_VERSION: already installed"
else
    echo "1/3 Python $PYTHON_VERSION (conda-forge) and cocotb $COCOTB_VERSION into $prefix/py"
    [ -x "$MAMBA" ] || { echo "setup.sh: $MAMBA not found (CAE module conda-forge/26.3.2)" >&2; exit 1; }
    rm -rf "$prefix/py"
    # package caches stay in the tools folder: the home folder is small
    CONDA_PKGS_DIRS=$dl/conda-pkgs "$MAMBA" create -y -q -p "$prefix/py" --override-channels -c conda-forge \
        "python=$PYTHON_VERSION" pip > "$dl/mamba.log" 2>&1 || { tail -20 "$dl/mamba.log"; exit 1; }
    # shellcheck disable=SC2086
    PIP_CACHE_DIR=$dl/pip "$py" -m pip install -q --disable-pip-version-check $PIP_PACKAGES
    rm -rf "$dl/conda-pkgs" "$dl/pip"    # about 1 GB, mostly the conda-forge index; not needed once installed
fi

# 2. KLayout (drc, lvs, GDS steps): not installed on CAE and not on conda-forge; the RHEL 8 RPM runs in the container
if [ "$(cat "$prefix/klayout/.version" 2>/dev/null)" = "$KLAYOUT_VERSION" ]; then
    echo "2/3 KLayout $KLAYOUT_VERSION: already installed"
else
    echo "2/3 KLayout $KLAYOUT_VERSION and ${#EL8_RPMS[@]} AlmaLinux 8 libraries into $prefix/klayout"
    # shellcheck disable=SC2086
    fetch $KLAYOUT_RPM $KLAYOUT_URL
    rpms=("${KLAYOUT_RPM%% *}")
    for r in "${EL8_RPMS[@]}"; do
        # shellcheck disable=SC2086
        fetch $r $EL8_URLS
        rpms+=("${r%% *}")
    done
    new=$prefix/klayout.new
    [ -d "$new" ] && chmod -R u+w "$new" && rm -rf "$new"
    mkdir -p "$new"
    for r in "${rpms[@]}"; do
        # rpm2cpio in Python (the host has none): skip the lead and both headers, unpack the xz or gzip payload
        (cd "$new" && "$py" - "$dl/$r" <<'EOF' | cpio -idm --quiet --no-absolute-filenames)
import lzma, struct, sys, zlib
data = open(sys.argv[1], "rb").read()
def skip_header(off):
    assert data[off:off + 3] == b"\x8e\xad\xe8", "not an RPM header"
    count, size = struct.unpack(">II", data[off + 8:off + 16])
    return off + 16 + 16 * count + size
off = skip_header(96)
off = skip_header((off + 7) & ~7)
payload = data[off:]
if payload[:6] == b"\xfd7zXZ\x00":
    sys.stdout.buffer.write(lzma.decompress(payload))
elif payload[:2] == b"\x1f\x8b":
    sys.stdout.buffer.write(zlib.decompress(payload, 31))
else:
    sys.exit("unknown RPM payload compression in " + sys.argv[1])
EOF
    done
    echo "$KLAYOUT_VERSION" > "$new/.version"
    [ -d "$prefix/klayout" ] && chmod -R u+w "$prefix/klayout" && rm -rf "$prefix/klayout"
    mv "$new" "$prefix/klayout"
fi

# 3. wrappers and env.sh (rewritten on every run)
echo "3/3 wrappers in $prefix/bin and $prefix/env.sh"
cat > "$prefix/bin/klayout" <<EOF
#!/bin/bash
# KLayout $KLAYOUT_VERSION from the RHEL 8 RPM (written by flows/synopsys/tools/cae/setup.sh); runs inside the CAE container only.
K=$prefix/klayout/usr
export LD_LIBRARY_PATH=\$K/lib64:\$K/lib64/klayout:\$K/lib64/pulseaudio\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export RUBYLIB=\$K/share/ruby:\$K/lib64/ruby\${RUBYLIB:+:\$RUBYLIB}
export RUBYOPT="--disable-gems\${RUBYOPT:+ \$RUBYOPT}"
[ -n "\${DISPLAY:-}" ] || export QT_QPA_PLATFORM=\${QT_QPA_PLATFORM:-offscreen}
exec \$K/bin/klayout "\$@"
EOF
for tool in StarXtract grdgenxo; do
    cat > "$prefix/bin/$tool" <<'EOF'
#!/bin/bash
# StarRC 2026.03 on CAE (written by flows/synopsys/tools/cae/setup.sh): its launcher puts the emsolver libstdc++ first on the
# library path, and that one lacks GLIBCXX_3.4.32. Preload the libstdc++ StarRC ships for itself, then run the
# real tool: the next one on PATH after this folder.
name=${0##*/}
self=$(cd "${0%/*}" && pwd -P)
real=
IFS=: read -ra dirs <<< "$PATH"
for d in "${dirs[@]}"; do
    [ -n "$d" ] && [ -x "$d/$name" ] && [ "$(cd "$d" && pwd -P)" != "$self" ] && { real=$d/$name; break; }
done
[ -n "$real" ] || { echo "$name: not found; load the StarRC module first: module load synopsys/starrc/2026.03" >&2; exit 127; }
lib=$(cd "${real%/*}/.." && pwd -P)/linux64_starrc/lib/shlib/libstdc++.so.6
[ -f "$lib" ] && export LD_PRELOAD=$lib${LD_PRELOAD:+:$LD_PRELOAD}
exec "$real" "$@"
EOF
done
chmod +x "$prefix/bin/"*
cat > "$prefix/env.sh" <<EOF
# Track B2 tools on the CAE machines (written by flows/synopsys/tools/cae/setup.sh). Source it after the module loads:
#   module load synopsys/suite/2026 synopsys/starrc/2026.03
#   source $prefix/env.sh
#   synopsys-run
export SB_TOOLS=$prefix
# this folder first on PATH, also when sourced again after a module load
_sb_path=
IFS=: read -ra _sb_dirs <<< "\$PATH"
for _sb_d in "\${_sb_dirs[@]}"; do
    case \$_sb_d in "\$SB_TOOLS/bin"|"\$SB_TOOLS/py/bin") ;; *) _sb_path=\$_sb_path:\$_sb_d ;; esac
done
export PATH=\$SB_TOOLS/bin:\$SB_TOOLS/py/bin\$_sb_path
unset _sb_path _sb_dirs _sb_d
# the modules come first: the suite has a python3 of its own, and the wrappers in bin/ run the StarRC module's tools
case :\${LOADEDMODULES:-}: in
    *:synopsys/suite/*:*synopsys/starrc/*|*:synopsys/starrc/*:*synopsys/suite/*) ;;
    *) echo "env.sh: load the modules first: module load synopsys/suite/2026 synopsys/starrc/2026.03" >&2 ;;
esac
EOF

echo "installed in $((SECONDS - start)) s; $(du -sh "$prefix" | cut -f1) in $prefix"
if command -v synopsys-run >/dev/null; then
    echo "check inside the container (synopsys-run):"
    synopsys-run bash "$self" --prefix "$prefix" --check
fi
echo "next: module load synopsys/suite/2026 synopsys/starrc/2026.03; source $prefix/env.sh; synopsys-run"
