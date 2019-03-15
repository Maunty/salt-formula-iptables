{% from "iptables/map.jinja" import defaults,schema,service with context %}

  {% if service.v4.enabled %}

iptables_packages_v4:
  pkg.installed:
  - names: {{ service.v4.pkgs }}

{% if service.v4.modules is defined %}
iptables_modules_v4_load:
  kmod.present:
  - persist: true
  - mods: {{ service.v4.modules }}
  - require:
    - pkg: iptables_packages_v4
{% endif %} 

{{ service.v4.persistent_config }}:
  file.managed:
  - user: root
  - group: root
  - mode: 640
  - source: salt://iptables/v{{ schema.epoch }}/files/v4_rules
  - template: jinja
  - require:
    - pkg: iptables_packages_v4

    {% if grains['os'] == 'Ubuntu' %}

iptables_services_v4_start:
  cmd.run:
  - name: find /usr/share/netfilter-persistent/plugins.d/[0-9]*-ip4tables -exec {} start \;
  - onlyif: test $(iptables-save | wc -l) -eq 0
  - require:
    - file: {{ service.v4.persistent_config }}
    - kmod: iptables_modules_v4_load

    {% endif %}

    {% if grains['os'] == 'SUSE' %}

/usr/lib/systemd/system/iptables.service:
  file.managed:
  - user: root
  - group: root
  - mode: 644
  - source: salt://iptables/v{{ schema.epoch }}/files/Suse/{{ service.v4.service }}.service
  - require:
    - pkg: iptables_packages_v4

/usr/lib/iptables/functions:
  file.managed:
  - user: root
  - group: root
  - mode: 644
  - source: salt://iptables/v{{ schema.epoch }}/files/Suse/functions
  - require:
    - pkg: iptables_packages_v4

/usr/lib/iptables/iptables.init:
  file.managed:
  - user: root
  - group: root
  - makedirs: True
  - mode: 755
  - source: salt://iptables/v{{ schema.epoch }}/files/Suse/{{ service.v4.service }}.init
  - require:
    - pkg: iptables_packages_v4

    {% endif %}

{{ service.v4.service }}:
  service.running:
  - enable: true
  - require:
    - file: {{ service.v4.persistent_config }}
{% if service.v4.modules is defined %}
    - kmod: iptables_modules_v4_load
{% endif %} 
  - watch:
    - file: {{ service.v4.persistent_config }}

iptables_tables_cleanup_v4:
  module.wait:
  - name: iptables_extra.remove_stale_tables
  - config_file: {{ service.v4.persistent_config }}
  - family: ipv4
  - require:
    - file: {{ service.v4.persistent_config }}
  - watch:
    - file: {{ service.v4.persistent_config }}
  {% else %}

    {% if grains['os'] == 'Ubuntu' %}

iptables_services_v4_stop:
  cmd.run:
  - name: find /usr/share/netfilter-persistent/plugins.d/[0-9]*-ip4tables -exec {} flush \;
  - onlyif: test $(which iptables-save) -eq 0 && test $(iptables-save | wc -l) -ne 0

{{ service.v4.persistent_config }}:
  file.absent:
  - require:
    - cmd: iptables_services_v4_stop

iptables_tables_flush_v4:
  module.wait:
  - name: iptables_extra.flush_all
  - family: ipv4
  - watch:
    - file: {{ service.v4.persistent_config }}

    {% endif %}

{% endif %}
