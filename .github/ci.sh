#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
BIN=$(pwd)/bin
EXT=""
$IS_WIN && EXT=".exe"
mkdir -p "$BIN"

is_exe() { [[ -x "$1/$2$EXT" ]] || command -v "$2" > /dev/null 2>&1; }

build_abc() {
  curl -o "abc.zip" -sL "https://github.com/berkeley-abc/abc/archive/$ABC_VERSION.zip"
  unzip abc.zip
  (cd abc-$ABC_VERSION && make ABC_USE_NO_READLINE=1 && cp abc$EXT $BIN/abc$EXT)
  output path $BIN/abc$EXT
}

build_cvc4() {
  curl -o cvc4.zip -sL "https://github.com/CVC4/CVC4-archived/archive/refs/tags/$CVC4_VERSION.zip"
  unzip cvc4.zip
  pushd CVC4-archived-$CVC4_VERSION
  if $IS_WIN ; then
    HOST=x86_64-w64-mingw32 ./contrib/get-win-dependencies
    ./configure --win64 --static production
  else
    ./contrib/get-antlr-3.4
    ./configure.sh production
  fi
  cd build
  cp bin/cvc4$EXT $BIN
  make
  popd
  output path $BIN/cvc4$EXT
}

build_yices() {
  LIBPOLY_VERSION="0.1.10"
  curl -o libpoly.zip -sL "https://github.com/SRI-CSL/libpoly/archive/refs/tags/v$LIBPOLY_VERSION.zip"
  unzip libpoly.zip
  mkdir install-root

  pushd libpoly-$LIBPOLY_VERSION
  cd build
  if $IS_WIN; then
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=../cmake/x86_64-w64-mingw32.cmake -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=../install-root
  else
    cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=../install-root
  fi
  make
  make install
  popd

  git clone https://github.com/ivmai/cudd
  pushd cudd
  ./configure CFLAGS=-fPIC --prefix=../install-root
  make
  make install
  popod

  curl -o yices.zip -sL "https://github.com/SRI-CSL/yices2/archive/refs/tags/Yices-$YICES_VERSION.zip"
  unzip yices.zip

  pushd yices2-Yices-$YICES_VERSION
  autoconf
  export CPPFLAGS="-I../install-root/include"
  export LDFLAGS="-L../install-root/lib"
  if $IS_WIN; then
    ./configure --enable-mcsat --host=x86_64-w64-mingw32 --build=x86_64-w64-mingw32
    cp configs/make.include.x86_64-w64-mingw32 configs/make.include.x86_64-pc-mingw64
  else
    ./configure --enable-mcsat
  fi
  make
  cp build/*/bin/* $BIN
  popd
  output path $BIN/yices$EXT
  output path $BIN/yices_smt2$EXT
}

build_z3() {
  curl -o z3.zip -sL "https://github.com/Z3Prover/z3/archive/refs/tags/z3-$Z3_VERSION.zip"
  unzip z3.zip
  (cd z3-z3-$Z3_VERSION && python scripts/mk_make.py && cd build && make && cp z3$EXT $BIN/z3$EXT)
  output path $BIN/z3$EXT
}

build_solvers() {
  #build_abc
  #build_cvc4
  build_yices
  #build_z3
  #export PATH="$BIN:$PATH"
  #echo "$BIN" >> "$GITHUB_PATH"
  #is_exe "$BIN" abc && is_exe "$BIN" cvc4 && is_exe "$BIN" yices && is_exe "$BIN" z3
}

output() { echo "::set-output name=$1::$2"; }
set_files() { output changed-files "$(files_since "$1" "$2")"; }
files_since() {
  changed_since="$(git log -1 --before="@{$2}")"
  files="${changed_since:+"$(git diff-tree --no-commit-id --name-only -r "$1" | xargs)"}"
  echo "$files"
}

COMMAND="$1"
shift

"$COMMAND" "$@"
