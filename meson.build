project('nhopkg', 'c',
  version: '0.5.1',
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
