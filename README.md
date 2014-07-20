# reposerver-saltstack-formula

This formula creates a basic structure for multiple _YUM_ and _APT_ repos
organized by prefixes (i.e. customers, teams, etc.). It could be easily
combined with nginx to have authenticated HTTP(S) access to those repos.


# How it does it work

All the relevant data is defined in pillar data files like this:

```yaml
reposerver:
  user: repouser
  group: repouser
  home: /var/www/repo
  prefixes:
    all:
      private: false
      distros:
        ubuntu:
          type: apt
          codenames: ['precise', 'trusty']
          architectures: ['i386', 'amd64', 'source']
          components: ['main']
        redhat:
          type: yum
          codenames: ['el6', 'el7']
          architectures: ['i386', 'x86_64', 'noarch', 'src' ]
        misc:
          type: plain
          components: ['main']
    mnp:
      distros:
        redhat: { codenames: ['el6'] }
```

Using this pillar data a tree structure will be created under
`/var/www/repo/public_html` to host the variety of repos ready to be served
with nginx or any other HTTP(S) server.

The repo types supported are:

* `apt` type repos will be managed using `reprepro`. This is the default when
  distro is `debian` or `ubuntu`. The formula creates `conf/distributions` and
  `conf/options` files based on pillar data.
* `yum` type repos will be managed using `createrepo`. This is the default when
  distro is `redhat`. The formula creates directories for each
  codename/architectures with a `repodata` empty directory.
* `plain` type repos are just a plain directory to store and serve files.

The result directory tree based on the previous pillar data is:

```
/var/www/
└── repo
    └── public_html
        ├── all
        │   ├── misc
        │   │   └── main
        │   ├── redhat
        │   │   ├── el6
        │   │   │   ├── i386
        │   │   │   │   └── repodata
        │   │   │   ├── noarch
        │   │   │   │   └── repodata
        │   │   │   ├── src
        │   │   │   │   └── repodata
        │   │   │   └── x86_64
        │   │   │       └── repodata
        │   │   └── el7
        │   │       ├── i386
        │   │       │   └── repodata
        │   │       ├── noarch
        │   │       │   └── repodata
        │   │       ├── src
        │   │       │   └── repodata
        │   │       └── x86_64
        │   │           └── repodata
        │   └── ubuntu
        │       └── conf
        │           ├── distributions
        │           └── options
        └── mnp
            ├── .htaccess
            └── redhat
                └── el6
                    ├── i386
                    │   └── repodata
                    ├── noarch
                    │   └── repodata
                    ├── src
                    │   └── repodata
                    └── x86_64
                        └── repodata
```

The formula installs the utility packages needed to manage repos:

* gnupg
* reprepro
* createrepo
* apache2-utils (for htpasswd)

At this moment, this formula has been tested in Ubuntu 12.04. YMMV swith other
distributions, mostly with RedHat based ones due to the lack of reprepro rpm
packages.


# Configuring nginx to serve the repos

To use nginx to serve the repos as HTTP you can use the nginx-saltstack-formula with this pillar data:

```
nginx:
  # Overrides map.jinja
  #lookup:
  #  version: xxx

  user: www-data
  group: www-data

  worker_processes: 4
  worker_connections: 512
  keepalive_timeout: 2

  sites:

    repo:
      state: enabled
      conf_filename: repo.conf
      template: minimal

      listen: '*:80'
      create_dirs: false
      user: repouser
      group: repouser

      server_name: repo
      root: /var/www/repo/public_html
      access_log: /var/log/nginx/repo_access.log
      error_log: /var/log/nginx/repo_error.log
      logrotate_files:
        - /var/log/nginx/repo_access.log
        - /var/log/nginx/repo_error.log
      extra_conf: |
        # Establish auth_basic when .htpasswd exists
        #
        # Snippet based on:
        # - http://serverfault.com/questions/522974/nginx-apply-basic-auth-only-if-an-htaccess-file-exists
        # - http://wiki.nginx.org/UserDir
        # Abusing unused error codes to perform an internal redirect
        # to a named location. This was the advice from nginx gurus.
          error_page 599 = @noauth;

          location ~ ^/(.+?)(/.*)?$ {
            set $htaccess_user_file $document_root/$1/.htaccess;
            if (!-f $htaccess_user_file) {
              return 599;
            }

            auth_basic "Restricted";
            auth_basic_user_file $htaccess_user_file;
            try_files $uri $uri/ =404;
            autoindex on;
          }

          location @noauth {
            try_files $uri $uri/ =404;
            autoindex on;
          }

    default:
      state: disabled
      conf_filename: default

    default.conf:
      state: disabled
      conf_filename: default.conf
```

The version for HTTPS should be easy as well and it can be the simple usage a of a "proxy_ssl" pattern with nginx.


# Usage

We are going to assume a configuration using the previous pillar data example.

## Create and delete a repo

_This has to be done from the salt-master (or salt-minion in masterless mode)_

To add a new repo for customer named XYZ needing a RedHat 6.5 and a plain repo:

```yaml
    [...]
    xyz:
      private: true
      distros:
        redhat:
          codenames: ['el6']
          architectures: ['i386', 'x86_64', 'noarch', 'src' ]
        misc:
          components: ['main']
```

Now apply the `state.sls reposerver.conf` function to the minion:

```
salt 'nameofminion' state.sls reposerver.conf
```

or, if you have a masterless configuration:

```
salt-call state.sls reposerver.conf
```

and you'll have this new directory tree:

```
[...]
        └── xyz
            ├── .htaccess
            ├── misc
            │   └── main
            └── redhat
                └── el6
                    ├── i386
                    │   └── repodata
                    ├── noarch
                    │   └── repodata
                    ├── src
                    │   └── repodata
                    └── x86_64
                        └── repodata
```

The .htaccess is empty and so far it's disallowing the access to the prefix according to the nginx suggested configuration. In order to allow access it's necessary to add users for that prefix.

If you need to delete the repo, you have to delete the correponding entries in the pillar data **and** delete the directory (which you can do using `salt 'nameofiminion' file remove /var/www/repo/public_html/xyz`).

## Add and delete an user

Adding an deleting users are considered non-salt configurations, so they can be
carried on by (authorized) users in the minions not depending on asking for a
change in the master.

To add the user bob to give him access to the `mnp` prefix:

```sh
htpasswd /var/www/repo/public_html/mnp/.htaccess bob
```

To delete the user bob:

```sh
htpasswd -D /var/www/repo/public_html/mnp/.htaccess bob
```

## Add and remove a .deb package

Adding an removing packages are considered non-salt configurations, so they can
be carried on by (authorized) users in the minions not depending on asking for
a change in the master.

Upload your deb package somewhere in the reposerver (e.g. /home/yourusername/foo.deb).

```sh
sudo -i -u repouser
cd /var/www/repo/all/ubuntu
reprepro includedeb precise /home/yourusername/foo.deb 
```

If you have configured gpg signing (recommended) you'll be asked to enter the
passphrase.

## Add and remove a .rpm package
TBD

## Sign a repo
TBD

## Change an user password
TBD

