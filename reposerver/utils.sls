{% from "reposerver/map.jinja" import reposerver with context %}


reposerver_utils:
  pkg:
    - installed
    - pkgs:
      - gnupg
      - reprepro
      - createrepo
      - apache2-utils
