project('nhopkg', 'c',
  version: '1.1',
  license: 'GPL3+',
  default_options: [
    'prefix=/usr',
    'sysconfdir=/etc',
    'localstatedir=/var',
    'libdir=lib'
  ]
)

# === Opciones de configuración ===
binlocate = get_option('binlocate')
repo_version = get_option('repo-version')
repo_arch = get_option('repo-arch')

# Build default repo URLs from version + arch
_repo_base = 'https://neonatox.vegnux.com/repo'
_repo_url_core_default = _repo_base + '/' + repo_version + '/' + repo_arch + '/core'
_repo_url_extra_default = _repo_base + '/' + repo_version + '/' + repo_arch + '/extra'
_repo_url_multilib_default = _repo_base + '/' + repo_version + '/' + repo_arch + '/multilib'

# Allow full override via individual options; fall back to auto-built URLs
repo_url_core = get_option('repo-url-core')
if repo_url_core == ''
  repo_url_core = _repo_url_core_default
endif
repo_url_extra = get_option('repo-url-extra')
if repo_url_extra == ''
  repo_url_extra = _repo_url_extra_default
endif
repo_url_multilib = get_option('repo-url-multilib')
if repo_url_multilib == ''
  repo_url_multilib = _repo_url_multilib_default
endif

git_url = get_option('git-url')
libc_variant = get_option('libc')
use_busybox = get_option('use-busybox')
static_busybox = get_option('static-busybox')
static_zstd = get_option('static-zstd')
download_jobs = get_option('download-jobs')

# === Detección temprana del toolchain musl (por arquitectura del host) ===
# La arch de destino de los binarios estáticos es la del host donde corre
# nhopkg (host_machine), NO repo-arch (que describe el repo destino).
fs = import('fs')
sh_prog = find_program('sh')
fetch_tool_script = files('scripts' / 'nhopkg-fetch-tools.sh')

musl_candidates = {
  'x86_64':  ['musl-gcc', 'x86_64-linux-musl-gcc'],
  'aarch64': ['aarch64-linux-musl-gcc', 'musl-gcc'],
}.get(host_machine.cpu_family(), ['musl-gcc'])

musl_gcc_path = get_option('musl-gcc-path')
if musl_gcc_path != ''
  musl_cc = find_program(musl_gcc_path, required: false)
else
  musl_cc = find_program(musl_candidates, required: false)
endif

if musl_cc.found()
  message('musl toolchain detected: ' + musl_cc.full_path())
else
  warning('No musl compiler found (tried: ' + ' '.join(musl_candidates) + '). '
    + 'Static busybox/zstd will only use prebuilt assets when available; '
    + 'otherwise they are skipped and the system tools are used.')
endif

# === Assets precompilados del release tools (neonatox-live-boot) ===
_tools_base = 'https://github.com/NeonatoX/neonatox-live-boot/releases/download/tools-0.9.1'
_asset_segment = {
  'x86_64': 'x86_64',
  # 'aarch64': 'aarch64',  # aún sin asset publicado — cae a compilar o skip
}.get(host_machine.cpu_family(), '')

busybox_prebuilt = {
  'internal': 'busybox',
  'version': '1.37.0',
  'rev': 'r1',
  'sha256': '115d3e2e941eb736e8e867e238473ac475a8bd24cfbbc7ddc45a141f95923f89',
}
zstd_prebuilt = {
  'internal': 'zstd',
  'version': '1.5.6',
  'rev': 'r1',
  'sha256': '519a1e6ec6f34595a236283c637f9c9063e00fc53f043e1bcd9299b02e36139c',
}

_tools_cache = meson.current_build_dir() / '.nhopkg-tools'

# --- Resolución de proveedor + descarga anticipada (configure time) ---
busybox_provider = 'skip'
busybox_file = ''
if static_busybox != 'no' and _asset_segment != ''
  busybox_url = _tools_base + '/neonatox-busybox-' + busybox_prebuilt['version'] \
    + '-' + _asset_segment + '-' + busybox_prebuilt['rev'] + '.zip'
  busybox_cache = _tools_cache / 'busybox'
  busybox_dl = run_command(sh_prog, fetch_tool_script, busybox_url,
    busybox_prebuilt['internal'], busybox_cache, busybox_prebuilt['sha256'],
    check: false)
  if busybox_dl.returncode() == 0 and fs.is_file(busybox_cache)
    busybox_provider = 'download'
    busybox_file = busybox_cache
    message('BusyBox prebuilt fetched and verified: ' + busybox_cache)
  elif static_busybox == 'download'
    error('static-busybox=download: failed to fetch prebuilt ' + busybox_url)
  elif musl_cc.found()
    busybox_provider = 'build'
  else
    warning('static-busybox=auto: prebuilt fetch failed and no musl compiler — using system BusyBox')
  endif
elif static_busybox == 'build'
  if musl_cc.found()
    busybox_provider = 'build'
  else
    error('static-busybox=build: no musl compiler available')
  endif
elif static_busybox == 'download'
  error('static-busybox=download: no prebuilt asset for arch ' + host_machine.cpu_family())
elif static_busybox == 'auto' and musl_cc.found()
  busybox_provider = 'build'
elif static_busybox == 'auto'
  warning('static-busybox=auto: no prebuilt asset for arch ' + host_machine.cpu_family()
    + ' and no musl compiler — using system BusyBox')
endif

zstd_provider = 'skip'
zstd_file = ''
if static_zstd != 'no' and _asset_segment != ''
  zstd_url = _tools_base + '/neonatox-zstd-' + zstd_prebuilt['version'] \
    + '-' + _asset_segment + '-' + zstd_prebuilt['rev'] + '.zip'
  zstd_cache = _tools_cache / 'zstd'
  zstd_dl = run_command(sh_prog, fetch_tool_script, zstd_url,
    zstd_prebuilt['internal'], zstd_cache, zstd_prebuilt['sha256'],
    check: false)
  if zstd_dl.returncode() == 0 and fs.is_file(zstd_cache)
    zstd_provider = 'download'
    zstd_file = zstd_cache
    message('zstd prebuilt fetched and verified: ' + zstd_cache)
  elif static_zstd == 'download'
    error('static-zstd=download: failed to fetch prebuilt ' + zstd_url)
  elif musl_cc.found()
    zstd_provider = 'build'
  else
    warning('static-zstd=auto: prebuilt fetch failed and no musl compiler — using system zstd')
  endif
elif static_zstd == 'build'
  if musl_cc.found()
    zstd_provider = 'build'
  else
    error('static-zstd=build: no musl compiler available')
  endif
elif static_zstd == 'download'
  error('static-zstd=download: no prebuilt asset for arch ' + host_machine.cpu_family())
elif static_zstd == 'auto' and musl_cc.found()
  zstd_provider = 'build'
elif static_zstd == 'auto'
  warning('static-zstd=auto: no prebuilt asset for arch ' + host_machine.cpu_family()
    + ' and no musl compiler — using system zstd')
endif

# === Configuración específica según libc (glibc / musl) ===
if libc_variant == 'musl'
  nhohold = 'nhopkg musl gcc'
  active_repos = 'core extra'
  # multilib no aplica para musl
else
  nhohold = 'nhopkg glibc gcc'
  active_repos = 'core extra multilib'
endif

# === Configuración para sustitución en archivos .in ===
conf = configuration_data()

# Variables estándar de Meson
conf.set('prefix', get_option('prefix'))
conf.set('sysconfdir', get_option('sysconfdir'))
conf.set('localstatedir', get_option('localstatedir'))
conf.set('datadir', get_option('datadir'))

# Variables derivadas
pkgdatadir = join_paths(get_option('datadir'), meson.project_name())
conf.set('pkgdatadir', pkgdatadir)
conf.set('localedir', join_paths(get_option('prefix'), 'share', 'locale'))

# Variables para nhopkg.conf.in
conf.set('datarootdir', join_paths(get_option('prefix'), get_option('datadir')))
conf.set('PACKAGE', meson.project_name())
conf.set('NHOPKG_REPO_CORE', repo_url_core)
conf.set('NHOPKG_REPO_EXTRA', repo_url_extra)
conf.set('NHOPKG_REPO_MULTILIB', repo_url_multilib)
conf.set('NHOPKG_GIT_SOURCES', git_url)
conf.set('NHOPKG_GIT_BRANCH', get_option('git-branch'))
conf.set('BINLOCATE', binlocate)
conf.set('NHOHOLD', nhohold)
conf.set('NHOPKG_ACTIVE_REPOS', active_repos)
conf.set('NHOPKG_USE_BUSYBOX', use_busybox == 'yes' ? 'yes' : 'no')
conf.set('NHOPKG_DOWNLOAD_JOBS', download_jobs)

# Variables para nhopkg.in
conf.set('PACKAGE_NAME', meson.project_name())
conf.set('PACKAGE_VERSION', meson.project_version())
conf.set('RELEASEDATE', '2026')

# === Verificación de dependencias del sistema ===
required_tools = [
  'bash', 'tar', 'zstd', 'bsdtar', 'sha256sum', 'make',
  'grep', 'awk', 'sed', 'find', 'wget'
]

optional_tools = [
  'curl', 'gpg', 'ldconfig', 'gettext', '7z', 'git', 'svn', 'hg'
]

# Verificar herramientas requeridas
foreach tool : required_tools
  find_program(tool, required: true)
endforeach

# Verificar binlocate
find_program(binlocate == 'plocate' ? 'plocate' : 'locate', required: true)

# Advertir sobre herramientas opcionales
foreach tool : optional_tools
  if not find_program(tool, required: false).found()
    message('Advertencia: herramienta opcional no encontrada: ' + tool)
  endif
endforeach

# Herramientas para gestión de traducciones
xgettext_prog = find_program('xgettext', required: false)
msgmerge_prog = find_program('msgmerge', required: false)
msginit_prog = find_program('msginit', required: false)

# === Subdirectorios ===
subdir('src')
subdir('data')
subdir('po')

# === Run target: versioning cadence reminder ===
run_target('version-check',
  command: [find_program('bash'), meson.project_source_root() / 'scripts' / 'nhopkg-check-version.sh']
)
