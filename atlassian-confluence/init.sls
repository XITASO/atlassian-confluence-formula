{% from 'atlassian-confluence/map.jinja' import confluence with context %}

include:
  - java

confluence-dependencies:
  pkg.installed:
    - pkgs:
      - libxslt

confluence:
  file.managed:
    - name: /etc/systemd/system/atlassian-confluence.service
    - source: salt://atlassian-confluence/files/atlassian-confluence.service
    - template: jinja
    - defaults:
        config: {{ confluence|json }}

  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: confluence

  group.present:
    - name: {{ confluence.group }}

  user.present:
    - name: {{ confluence.user }}
    - home: {{ confluence.dirs.home }}
    - gid: {{ confluence.group }}
    - require:
      - group: confluence
      - file: confluence-dir

  service.running:
    - name: atlassian-confluence
    - enable: True
    - require:
      - user: confluence

confluence-graceful-down:
  service.dead:
    - name: atlassian-confluence
    - require:
      - module: confluence
    - prereq:
      - file: confluence-install

confluence-install:
  archive.extracted:
    - name: {{ confluence.dirs.extract }}
    - source: {{ confluence.url }}
    - source_hash: {{ confluence.url_hash }}
    - if_missing: {{ confluence.dirs.current_install }}
    - options: z
    - keep: True
    - require:
      - file: confluence-extractdir

  file.symlink:
    - name: {{ confluence.dirs.install }}
    - target: {{ confluence.dirs.current_install }}
    - require:
      - archive: confluence-install
    - watch_in:
      - service: confluence

confluence-server-xsl:
  file.managed:
    - name: {{ confluence.dirs.temp }}/server.xsl
    - source: salt://atlassian-confluence/files/server.xsl
    - template: jinja
    - require:
      - file: confluence-tempdir

  cmd.run:
    - name: 'xsltproc --stringparam pHttpPort "{{ confluence.get('http_port', '') }}" --stringparam pHttpScheme "{{ confluence.get('http_scheme', '') }}" --stringparam pHttpProxyName "{{ confluence.get('http_proxyName', '') }}" --stringparam pHttpProxyPort "{{ confluence.get('http_proxyPort', '') }}" --stringparam pAjpPort "{{ confluence.get('ajp_port', '') }}" -o "{{ confluence.dirs.temp }}/server.xml" "{{ confluence.dirs.temp }}/server.xsl" server.xml'
    - cwd: {{ confluence.dirs.install }}/conf
    - require:
      - file: confluence-server-xsl
      - file: confluence-install

confluence-server-xml:
  file.managed:
    - name: {{ confluence.dirs.install }}/conf/server.xml
    - source: {{ confluence.dirs.temp }}/server.xml
    - require:
      - cmd: confluence-server-xsl
    - watch_in:
      - service: confluence

confluence-dir:
  file.directory:
    - name: {{ confluence.dir }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

confluence-home:
  file.directory:
    - name: {{ confluence.dirs.home }}
    - user: {{ confluence.user }}
    - group: {{ confluence.group }}
    - require:
      - file: confluence-dir
      - user: confluence
      - group: confluence
    - use:
      - file: confluence-dir

confluence-extractdir:
  file.directory:
    - name: {{ confluence.dirs.extract }}
    - use:
      - file: confluence-dir

confluence-tempdir:
  file.directory:
    - name: {{ confluence.dirs.temp }}
    - use:
      - file: confluence-dir

confluence-conf-standalonedir:
  file.directory:
    - name: {{ confluence.dirs.install }}/conf/Standalone
    - user: {{ confluence.user }}
    - group: {{ confluence.group }}
    - use:
      - file: confluence-dir

confluence-scriptdir:
  file.directory:
    - name: {{ confluence.dirs.scripts }}
    - use:
      - file: confluence-dir

{% for file in [ 'env.sh', 'start.sh', 'stop.sh' ] %}
confluence-script-{{ file }}:
  file.managed:
    - name: {{ confluence.dirs.scripts }}/{{ file }}
    - source: salt://atlassian-confluence/files/{{ file }}
    - user: {{ confluence.user }}
    - group: {{ confluence.group }}
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ confluence|json }}
    - require:
      - file: confluence-scriptdir
      - user: confluence
    - watch_in:
      - service: confluence
{% endfor %}

{% if confluence.get('crowd') %}
confluence-crowd-properties:
  file.managed:
    - name: {{ confluence.dirs.install }}/confluence/WEB-INF/classes/crowd.properties
    - require:
      - file: confluence-install
    - watch_in:
      - service: confluence
    - contents: |
{%- for key, val in confluence.crowd.items() %}
        {{ key }}: {{ val }}
{%- endfor %}
{% endif %}

{% for chmoddir in ['bin', 'work', 'temp', 'logs'] %}
confluence-permission-{{ chmoddir }}:
  file.directory:
    - name: {{ confluence.dirs.install }}/{{ chmoddir }}
    - user: {{ confluence.user }}
    - group: {{ confluence.group }}
    - recurse:
      - user
      - group
    - require:
      - file: confluence-install
    - require_in:
      - service: confluence
{% endfor %}

confluence-disable-ConfluenceAuthenticator:
  file.replace:
    - name: {{ confluence.dirs.install }}/confluence/WEB-INF/classes/seraph-config.xml
    - pattern: |
        ^(\s*)[\s<!-]*(<authenticator class="com\.atlassian\.confluence\.user\.ConfluenceAuthenticator"\/>)[\s>-]*$
    - repl: |
        {% if confluence.crowdSSO %}\1<!-- \2 -->{% else %}\1\2{% endif %}
    - watch_in:
      - service: confluence

confluence-enable-ConfluenceCrowdSSOAuthenticator:
  file.replace:
    - name: {{ confluence.dirs.install }}/confluence/WEB-INF/classes/seraph-config.xml
    - pattern: |
        ^(\s*)[\s<!-]*(<authenticator class="com\.atlassian\.confluence\.user\.ConfluenceCrowdSSOAuthenticator"\/>)[\s>-]*$
    - repl: |
        {% if confluence.crowdSSO %}\1\2{% else %}\1<!-- \2 -->{% endif %}
    - watch_in:
      - service: confluence

