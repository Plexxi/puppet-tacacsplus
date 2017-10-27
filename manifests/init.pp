# == Class: tacacsplus
#
# Puppet module to manage TACACS+ PAM and NSS configuration.
#
# === Parameters
#
# Document parameters here.
#
# [server]
#   Array of structures { addr, secret} of TACACS+ servers
#   *Optional*
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
#    server => [ { addr => '1.2.3.4',
#                  secret => "secret1"
#                }
#                { addr => 'my.tacacs.com',
#                  secret => "secret2"
#                } ]
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
  $server     = [],
  $timeout    = 2,
  $login      = 'login',
  $service    = 'linuxlogin',
  $protocol   = 'ssh',
  $pam_enable = true,
  $nsswitch   = false,
) {

  validate_bool($pam_enable)
  validate_bool($nsswitch)
  
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
           "ins service before /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[1]",
           "set /files/etc/nsswitch.conf/*[self::database = 'passwd']/service[1] tacplus",
           "ins service before /files/etc/nsswitch.conf/*[self::database = 'group']/service[1]",
           "set /files/etc/nsswitch.conf/*[self::database = 'group']/service[1] tacplus"
         ],
         notify => Exec[tacacs_name_restart],
       }
     } else {
       # remove tacplus from nsswitch.conf
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
