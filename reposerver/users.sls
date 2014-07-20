{% from "reposerver/map.jinja" import reposerver with context %}


reposerver_user:
  user:
    - present
    - name: {{ salt['pillar.get']('reposerver:user', 'repouser') }}
    - home: {{ salt['pillar.get']('reposerver:home', '/var/www/repo') }}
    - createhome: False


reposerver_group:
  group:
    - present
    - name: {{ salt['pillar.get']('reposerver:group', 'repouser') }}
