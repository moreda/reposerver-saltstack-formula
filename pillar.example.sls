reposerver:
  user: repouser
  group: repouser
  home: /var/www/repo
  prefixes:
    all:
      private: false
      distros:
        ubuntu:
          codenames: ['precise', 'trusty']
          architectures: ['i386', 'amd64', 'source']
          components: ['main']
        redhat:
          codenames: ['el6', 'el7']
          architectures: ['i386', 'x86_64', 'noarch', 'src' ]
        misc:
          components: ['main']
    rcs:
      distros:
        redhat: { codenames: ['el6'] }
    xyz:
      private: true
      distros:
        redhat:
          codenames: ['el6']
          architectures: ['i386', 'x86_64', 'noarch', 'src' ]
        misc:
          components: ['main']
  gpg_keypair_id: 33A523F5
  gpg_keypair: |
      -----BEGIN PGP PUBLIC KEY BLOCK-----

      mQENBFO3L0MBCADKyEU3CITq1ya1h7Ypo4OZbP5gdv6zyC60rK2qNVDN5e9XL3+Y
      ...
      W/pHgZ8olOotN2xjHIp7WMgKytgNIzT3NEYOZwg=
      =+QFw
      -----END PGP PUBLIC KEY BLOCK-----
      -----BEGIN PGP PRIVATE KEY BLOCK-----

      lQO+BFO3L0MBCADKyEU3CITq1ya1h7Ypo4OZbP5gdv6zyC60rK2qNVDN5e9XL3+Y
      ...
      e1jICsrYDSM09zRGDmcI
      =arTg
      -----END PGP PRIVATE KEY BLOCK-----
