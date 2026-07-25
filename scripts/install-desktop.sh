#!/usr/bin/env bash

set -euo pipefail

readonly app_id="com.t3tools.t3code"
readonly app_name="T3 Code (Alpha)"

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'error: this installer currently supports Linux only\n' >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64)
    readonly app_arch="x64"
    ;;
  aarch64 | arm64)
    readonly app_arch="arm64"
    ;;
  *)
    printf 'error: unsupported architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repo_root="$(cd -- "${script_dir}/.." && pwd)"
readonly data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
readonly app_dir="${data_home}/t3code"
readonly applications_dir="${data_home}/applications"
readonly icon_dir="${data_home}/icons/hicolor/512x512/apps"
readonly installed_app="${app_dir}/T3-Code.AppImage"
readonly desktop_file="${applications_dir}/${app_id}.desktop"
readonly installed_icon="${icon_dir}/${app_id}.png"

for build_input in \
  "${repo_root}/apps/desktop/dist-electron/main.cjs" \
  "${repo_root}/apps/server/dist/client/index.html"; do
  if [[ ! -f "${build_input}" ]]; then
    printf 'error: required build output is missing: %s\n' "${build_input}" >&2
    printf 'run "vp run build:desktop" first, then rerun this installer\n' >&2
    exit 1
  fi
done

package_dir="$(mktemp -d "${TMPDIR:-/tmp}/t3code-install.XXXXXXXX")"
trap 'rm -rf -- "${package_dir}"' EXIT

package_path="${PATH}"
if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  if ! command -v ffmpeg >/dev/null 2>&1; then
    printf 'error: packaging requires ImageMagick (magick/convert) or ffmpeg\n' >&2
    exit 1
  fi

  converter_dir="${package_dir}/bin"
  mkdir -p -- "${converter_dir}"
  {
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      'if [[ "$#" != 4 || "$2" != "-resize" ]]; then' \
      '  printf "error: unsupported convert arguments\\n" >&2' \
      '  exit 1' \
      'fi' \
      'exec ffmpeg -loglevel error -y -i "$1" -vf "scale=$3" "$4"'
  } >"${converter_dir}/convert"
  chmod 0755 "${converter_dir}/convert"
  package_path="${converter_dir}:${package_path}"
fi

printf 'Packaging the existing desktop build for Linux (%s)...\n' "${app_arch}"
(
  cd -- "${repo_root}"
  PATH="${package_path}" node scripts/build-desktop-artifact.ts \
    --platform linux \
    --target AppImage \
    --arch "${app_arch}" \
    --output-dir "${package_dir}" \
    --skip-build
)

shopt -s nullglob
app_images=("${package_dir}"/T3-Code-*.AppImage)
shopt -u nullglob
if (( ${#app_images[@]} != 1 )); then
  printf 'error: expected one AppImage in %s, found %d\n' \
    "${package_dir}" "${#app_images[@]}" >&2
  exit 1
fi

mkdir -p -- "${app_dir}" "${applications_dir}" "${icon_dir}"
install -m 0755 -- "${app_images[0]}" "${installed_app}"
install -m 0644 -- "${repo_root}/apps/desktop/resources/icon.png" "${installed_icon}"

desktop_exec="${installed_app//\\/\\\\}"
desktop_exec="${desktop_exec//\"/\\\"}"

{
  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    "Name=${app_name}" \
    'Comment=Agentic coding, anywhere' \
    "Exec=\"${desktop_exec}\" %U" \
    "Icon=${app_id}" \
    'Terminal=false' \
    'Categories=Development;IDE;' \
    'StartupNotify=true' \
    'StartupWMClass=t3code' \
    'MimeType=x-scheme-handler/t3code;x-scheme-handler/t3code-dev;'
} >"${desktop_file}"
chmod 0644 "${desktop_file}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${applications_dir}"
fi

printf 'Installed %s\n' "${app_name}"
printf '  App:     %s\n' "${installed_app}"
printf '  Launcher: %s\n' "${desktop_file}"
