#!/usr/bin/env bash
# Packs a release tarball: the four packages, the setup scripts and the prebuilt archives.
#
#   ./tools/make_release.sh              into dist/
#   ./tools/make_release.sh /some/where  into that directory
#
# The archives in prebuilt/ carry the protocol, so the result builds and runs on a machine that
# has nothing but what the tarball holds.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-${HERE}/dist}"

VERSION="$(grep -oP 'project\(aidin_aft150_d50_driver VERSION \K[0-9.]+' \
  "${HERE}/aidin_aft150_d50_driver/CMakeLists.txt")"
[ -n "${VERSION}" ] || { echo "FAIL: could not read the version" >&2; exit 1; }

NAME="aidin-aft150-d50-ros2-${VERSION}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

echo "packing ${NAME}"

# Every architecture the release claims to support needs an archive, or the consumer finds out at
# CMake time on a machine they cannot fix it from.
SHIPPED=()
for dir in "${HERE}"/aidin_aft150_d50_driver/prebuilt/*/; do
  arch="$(basename "${dir}")"
  if [ -f "${dir}/libaft150_d50_comms.a" ]; then
    SHIPPED+=("${arch}")
  else
    echo "  [warning] prebuilt/${arch} has no archive and will ship empty"
  fi
done
[ "${#SHIPPED[@]}" -gt 0 ] || {
  echo "FAIL: no prebuilt archive at all. Build the archives before packing a release." >&2
  exit 1; }
echo "  architectures: ${SHIPPED[*]}"

mkdir -p "${STAGE}/${NAME}"
for item in aidin_aft150_d50_driver aidin_aft150_d50_hardware aidin_aft150_d50_description \
            aidin_aft150_d50_bringup scripts docs \
            README.md README.ko.md CHANGELOG.md; do
  [ -e "${HERE}/${item}" ] || { echo "FAIL: ${item} is missing" >&2; exit 1; }
  cp -r "${HERE}/${item}" "${STAGE}/${NAME}/"
done

# Build output from a local colcon run would otherwise travel with the source.
find "${STAGE}/${NAME}" -type d \( -name build -o -name install -o -name log -o -name .git \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

# A tarball that carries the protocol source defeats what the archive exists for, and the copy
# above takes whole directories, so this is checked rather than assumed.
if find "${STAGE}/${NAME}" -name 'aft150_d50_comms.cpp' -o -name 'aft150_d50_internal.hpp' \
   | grep -q .; then
  echo "FAIL: protocol source is in the tarball" >&2
  find "${STAGE}/${NAME}" -name 'aft150_d50_comms.cpp' -o -name 'aft150_d50_internal.hpp' >&2
  exit 1
fi
echo "  protocol source excluded: yes"

mkdir -p "${OUT}"
TARBALL="${OUT}/${NAME}.tar.gz"
tar czf "${TARBALL}" -C "${STAGE}" "${NAME}"

echo
ls -lh "${TARBALL}" | awk '{print "  " $5, $9}'
echo
echo "  unpack it, then:"
echo "    sudo apt install can-utils"
echo "    colcon build --packages-up-to aidin_aft150_d50_bringup"
