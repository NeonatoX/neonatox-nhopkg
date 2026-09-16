# Configurar nhopkg.in → nhopkg
nhopkg_script = configure_file(
  input: 'nhopkg.in',
  output: 'nhopkg',
  configuration: conf
)

# Configurar scripts adicionales en /usr/bin
nhopkg_repos = configure_file(
  input: 'nhopkg-repos.in',
  output: 'nhopkg-repos',
  configuration: conf
)

nhouser = configure_file(
  input: 'nhouser.in',
  output: 'nhouser',
  configuration: conf
)

nhopkg_overlay = configure_file(
  input: 'nhopkg-overlay.in',
  output: 'nhopkg-overlay',
  configuration: conf
)

nhopkg_src = configure_file(
  input: 'nhopkg-src.in',
  output: 'nhopkg-src',
  configuration: conf
)

# Configurar librería en /usr/lib/nhopkg
libnhopkg = configure_file(
  input: 'libnhopkg.in',
  output: 'libnhopkg',
  configuration: conf
)

# Configurar librería de resolución de dependencias en /usr/lib/nhopkg
libnhopkg_udepsys = configure_file(
  input: 'libnhopkg_udepsys.in',
  output: 'libnhopkg_udepsys',
  configuration: conf
)

# Configurar librería de descargas (nhoget) en /usr/lib/nhopkg
libnhopkg_download = configure_file(
  input: 'libnhopkg_download.in',
  output: 'libnhopkg_download',
  configuration: conf
)

# Configurar librería criptográfica en /usr/lib/nhopkg
libnhopkg_crypto = configure_file(
  input: 'libnhopkg_crypto.in',
  output: 'libnhopkg_crypto',
  configuration: conf
)

# Configurar librería de usuarios/grupos (nhouser) en /usr/lib/nhopkg
libnhopkg_nhouser = configure_file(
  input: 'libnhopkg_nhouser.in',
  output: 'libnhopkg_nhouser',
  configuration: conf
)

# Configurar nhoget CLI
nhoget = configure_file(
  input: 'nhoget.in',
  output: 'nhoget',
  configuration: conf
)

# Configurar nhopicker CLI
nhopicker = configure_file(
  input: 'nhopicker.in',
  output: 'nhopicker',
  configuration: conf
)

# Instalar los scripts ejecutables
install_data(
  [nhopkg_script, nhopkg_repos, nhouser, nhopkg_overlay, nhopkg_src, nhoget, nhopicker],
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x'
)

# Instalar librería en libdir/nhopkg (/usr/lib/nhopkg)
install_data(
  [libnhopkg, libnhopkg_udepsys, libnhopkg_download, libnhopkg_crypto, libnhopkg_nhouser],
  install_dir: join_paths(get_option('libdir'), 'nhopkg'),
  install_mode: 'rw-r--r--'
)

# --- BusyBox symlinks setup script (always installed) ---
nhopkg_bb_setup = configure_file(
  input: 'nhopkg-bb-setup.in',
  output: 'nhopkg-bb-setup',
  configuration: conf
)

install_data(
  [nhopkg_bb_setup],
  install_dir: join_paths(get_option('libdir'), 'nhopkg'),
  install_mode: 'rwxr-xr-x'
)

# --- Static BusyBox (provider: download | build) ---
if busybox_provider == 'download'
  busybox_build = custom_target(
    'busybox-static',
    output: 'busybox',
    command: ['cp', busybox_file, '@OUTPUT@'],
    install: true,
    install_dir: join_paths(get_option('libdir'), 'nhopkg', 'bin'),
    install_mode: 'rwxr-xr-x',
  )

  meson.add_install_script(nhopkg_bb_setup)
elif busybox_provider == 'build'
  busybox_build = custom_target(
    'busybox-static',
    input: ['../scripts/nhopkg-build-busybox.sh', 'busybox.config'],
    output: 'busybox',
    command: [
      'sh', '@INPUT0@',
      '1.37.0',
      meson.current_build_dir(),
      meson.current_build_dir(),
      '@INPUT1@',
      musl_cc.full_path(),
    ],
    install: true,
    install_dir: join_paths(get_option('libdir'), 'nhopkg', 'bin'),
  )

  meson.add_install_script(nhopkg_bb_setup)
endif

# --- Static zstd (provider: download | build) ---
if zstd_provider == 'download'
  zstd_build = custom_target(
    'zstd-static',
    output: 'zstd',
    command: ['cp', zstd_file, '@OUTPUT@'],
    install: true,
    install_dir: join_paths(get_option('libdir'), 'nhopkg', 'bin'),
    install_mode: 'rwxr-xr-x',
  )
elif zstd_provider == 'build'
  zstd_build = custom_target(
    'zstd-static',
    input: '../scripts/nhopkg-build-zstd.sh',
    output: 'zstd',
    command: [
      'sh', '@INPUT@',
      '1.5.7',
      meson.current_build_dir(),
      meson.current_build_dir(),
      musl_cc.full_path(),
    ],
    install: true,
    install_dir: join_paths(get_option('libdir'), 'nhopkg', 'bin'),
  )
endif

# Configurar nhopkg.conf.in → nhopkg.conf
nhopkg_conf = configure_file(
  input: 'nhopkg.conf.in',
  output: 'nhopkg.conf',
  configuration: conf
)

# Instalar archivo de configuración en /etc/nhopkg/
install_data(
  nhopkg_conf,
  install_dir: join_paths(get_option('sysconfdir'), 'nhopkg')
)
