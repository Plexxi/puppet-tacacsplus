# == Class: tacacsplus
#
# Puppet module to manage TACACS+ PAM and NSS configuration.
#
# === Parameters
#
# Document parameters here.
#
# [server]
#   Address of TACACS+ servers.  Multiple entries may be set.
#   **Required**
# [secret]
#   Secret used for the TACACS+ server
#   **Required**
# [timeout]
#   Defaults to 2 seconds
#   *Optional*
# [login]
#   Authentication service.  May be one of (pap, chap, or login)
#   Defaults to login
#   *Optional*
# [service]
#   Service that the user info is located in.
#   Defaults to 'linuxlogin'
#   *Optional*
# [protocol]
#   Not really used but the service needs it.
#   Defaults to 'ssh'
#   *Optional*
# [pam_enable]
#   If enabled (pam_enable => true) enables the Tacacs+ PAM module.
#   *Optional* (defaults to true)
# [nsswitch]
#   If enabled (nsswitch => true) enables nsswitch to use
#   TACACS+ as a backend for password, group and shadow databases.
#   *Optional* (defaults to false)
#
# === Examples
#
#  class { 'tacacsplus':
#    server => [ '1.2.3.4', 'my.tacacs.com' ],
#    secret => 'mySecret',
#  }
#
# === Authors
#
# Matthew Morgan <matt.morgan@plexxi.com>
#
# === Copyright
#
# Copyright 2016 Matthew Morgan, Plexxi, Inc
#
class tacacsplus( 
  $server,
  $secret,
  $timeout    = 2,
  $login      = 'login',
  $service    = 'linuxlogin',
  $protocol   = 'ssh',
  $pam_enable = true,
  $nsswitch   = false,
) {
  exec { 'tacacs_name_restart':
       command => '/usr/sbin/service nscd restart',
  }
  if $pam_enable {
     file { '/etc/tacplus.conf':
       ensure  => file,
       owner   => 0,
       group   => 0,
       mode    => '0600',
       content => template('tacacsplus/tacplus.conf.erb'),
     }
     exec { 'tacacs_pam_auth_update':
       environment => ["DEBIAN_FRONTEND=editor",
                       "PLEXXI_AUTH_UPDATE=tacacs",
                       "PLEXXI_AUTH_ENABLE=1",
                       "EDITOR=/opt/plexxi/bin/px-auth-update"],
       command => '/usr/sbin/pam-auth-update',
     }
     if $nsswitch {
       file { '/etc/nss_tacplus.conf':
         ensure  => file,
         owner   => 0,
         group   => 0,
         mode    => '0600',
         content => template('tacacsplus/nss_tacplus.conf.erb'),
       }
       # setup/add tacplus to nsswitch.conf
       augeas { 'tacacs_nsswitch_add':
         context => "/files/etc/nsswitch.conf",
         onlyif  => "get /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[.='tacplus'] == ''",
         changes => [
           "ins service after /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[last()]",
           "set /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[last()] tacplus",
           "ins service after /files/etc/nsswitch.conf/*[self::database = 'group']/service[last()]",
           "set /files/etc/nsswitch.conf/*[self::database = 'group']/service[last()] tacplus"
         ],
         notify => Exec[tacacs_name_restart],
       }
     } else {
       # setup/add tacplus to nsswitch.conf
       augeas { 'tacacs_nsswitch_remove':
         context => "/files/etc/nsswitch.conf",
         changes => [
           "rm /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[.='tacplus']",
           "rm /files/etc/nsswitch.conf/*[self::database = 'group']/service[.='tacplus']",
         ],
         notify => Exec[tacacs_name_restart],
       }
     }
  } else {
     exec { 'tacacs_pam_auth_update':
       environment => ["DEBIAN_FRONTEND=editor",
                       "PLEXXI_AUTH_UPDATE=tacacs",
                       "PLEXXI_AUTH_ENABLE=0",
                       "EDITOR=/opt/plexxi/bin/px-auth-update"],
       command => '/usr/sbin/pam-auth-update',
     }
     augeas { 'tacacs_nsswitch_remove':
       context => "/files/etc/nsswitch.conf",
       changes => [
         "rm /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[.='tacplus']",
         "rm /files/etc/nsswitch.conf/*[self::database = 'group']/service[.='tacplus']",
       ],
       notify => Exec[tacacs_name_restart],
     }
  }
}
