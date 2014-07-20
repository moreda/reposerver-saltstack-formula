{% from "reposerver/map.jinja" import reposerver with context %}


include:
  - reposerver.user
  - reposerver.utils


{% set files_switch = salt['pillar.get']('reposerver:files_switch', ['id']) %}


{% set repo_home = salt['pillar.get']('reposerver:home', '/var/www/repo') %}
{% set repo_user = salt['pillar.get']('reposerver:user', 'repouser') %}
{% set repo_group = salt['pillar.get']('reposerver:group', 'repouser') %}
{% set default_repotypes = { 'ubuntu': 'apt',
                             'debian': 'apt',
                             'redhat': 'yum' } %}
{% set default_codenames = { 'ubuntu': ['precise', 'trusty'],
                             'debian': ['wheezy', 'jessie'],
                             'redhat': ['el6'] } %}
{% set default_architectures = { 'ubuntu': ['i386', 'amd64', 'source'],
                                 'debian': ['i386', 'amd64', 'source'],
                                 'redhat': ['i386', 'x86_64', 'noarch', 'src' ]
                               } %}
{% set default_components = { 'ubuntu': ['main'],
                              'debian': ['main'],
                              'misc': ['main'] } %}


# Create the root of the repos tree that is as well the home of the repouser
{{ repo_home }}:
  file:
    - directory
    - makedirs: true
    - user: {{ repo_user }}
    - group: {{ repo_group }}


# Install gpg keys needed to sign repos
{% if salt['pillar.get']('reposerver:gpg_keypair_id', 'none') != 'none' %}
# Add repouser gpg keypair
{{ repo_home }}/.gnupg/repo_keypair.gpg:
  file:
    - managed
    - makedirs: true
    - user: {{ repo_user }}
    - mode: 600
    - dir_mode: 700
    - contents_pillar: reposerver:gpg_keypair
    - require:
      - user: reposerver_user
      - group: reposerver_group
  cmd:
    - run
    - name: gpg --import {{ repo_home }}/.gnupg/repo_keypair.gpg
    - user: {{ repo_user }}
    - unless: >
        gpg --list-key {{ salt['pillar.get']('reposerver:gpg_keypair_id') }}
    - require:
      - file: {{ repo_home }}/.gnupg/repo_keypair.gpg
{% endif %}


# Main loop to create tree prefix -> distro -> codename -> architecture
{% for prefix in salt['pillar.get']('reposerver:prefixes', 'all') %}
{{ repo_home }}/public_html/{{ prefix }}:
  file:
    - directory
    - makedirs: true
    - user: {{ repo_user }}
    - group: {{ repo_group }}
    - dir_mode: 2775

  {% if salt['pillar.get']('reposerver:prefixes:' ~ prefix ~
                             ':private', true) %}
{{ repo_home }}/public_html/{{ prefix }}/.htaccess:
  file:
    - managed
    - makedirs: true
    - user: {{ repo_user }}
    - group: {{ repo_group }}
  {% endif %}

  {% for distro in salt['pillar.get']('reposerver:prefixes:' ~ prefix ~
                                        ':distros', []) %}
    {% if default_repotypes[distro] is defined %}
      {% set default_repotype = default_repotypes[distro] %}
    {% else %}
      {% set default_repotype = 'plain' %}
    {% endif %}
    {% set repotype = salt['pillar.get']('reposerver:prefixes:' ~ prefix ~
                                            ':distros:' ~ distro ~
                                            ':repotype',
                                          default_repotype) %}
    {% set codenames = salt['pillar.get']('reposerver:prefixes:' ~ prefix ~
                                            ':distros:' ~ distro ~
                                            ':codenames',
                                          default_codenames[distro]) %}
    {% set architectures = salt['pillar.get']('reposerver:prefixes:' ~ prefix ~
                                                ':distros:' ~ distro ~
                                                ':architectures',
                                              default_architectures[distro]) %}
    {% set components = salt['pillar.get']('reposerver:prefixes:' ~ prefix ~
                                             ':distros:' ~ distro ~
                                             ':components',
                                          default_components[distro]) %}


{{ repo_home }}/public_html/{{ prefix }}/{{ distro }}:
  file:
    - directory
    - user: {{ repo_user }}
    - group: {{ repo_group }}
    - dir_mode: 2775


    {% if repotype == 'apt' %}
      {% for file in ['distributions', 'options'] %}
{{ repo_home }}/public_html/{{ prefix }}/{{distro}}/conf/{{ file }}:
  file:
    - managed
    - makedirs: true
    - template: jinja
    - user: {{ repo_user }}
    - group: {{ repo_group }}
    - dir_mode: 2775
    {% for grain in files_switch if salt['grains.get'](grain) is defined -%}
    - source: salt://reposerver/files/{{ salt['grains.get'](grain) }}/var/www/repo/public_html/all/ubuntu/conf/{{ file }}.jinja
    {% endfor -%}
    - source: salt://reposerver/files/default/var/www/repo/public_html/all/ubuntu/conf/{{ file }}.jinja
    - context:
        name: {{ salt['pillar.get']('reposerver:prefixes:' ~ prefix ~':name', prefix) }}
        basedir: {{ repo_home }}/public_html/{{ prefix }}/ubuntu
        gnupghome: {{ repo_home }}/.gnupg
        gpg_keypair_id: {{ salt['pillar.get']('reposerver:gpg_keypair_id', 'none') }}
        codenames: {{ codenames }}
        architectures: {{ architectures }}
        components: {{ components }}
      {% endfor %}


    {% elif repotype == 'yum' %}
      {% for codename in codenames %}
        {% for architecture in architectures %}
{{ repo_home }}/public_html/{{ prefix }}/{{ distro }}/{{ codename }}/{{ architecture }}/repodata:
  file:
    - directory
    - makedirs: True
    - user: {{ repo_user }}
    - group: {{ repo_group }}
    - dir_mode: 2775
        {% endfor %} # architecture loop
      {% endfor %} # codename loop


    {% elif repotype == 'plain' %}
      {% for component in components %}
{{ repo_home }}/public_html/{{ prefix }}/{{ distro }}/{{ component }}:
  file:
    - directory
    - makedirs: True
    - user: {{ repo_user }}
    - group: {{ repo_group }}
    - dir_mode: 2775
      {% endfor %}
    {% endif %}


  {% endfor %} # distros loop
{% endfor %} # prefix loop
