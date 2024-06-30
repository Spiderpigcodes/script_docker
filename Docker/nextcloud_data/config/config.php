config/config.php<?php
$CONFIG = array (
  'instanceid' => 'oc12345',
  'passwordsalt' => 'randomsalt',
  'secret' => 'secret',
  'trusted_domains' => 
  array (
    0 => '10.10.1.253',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '21.0.1.1',
  'overwrite.cli.url' => 'http://10.10.1.253:8080',
  'overwritehost' => '10.10.1.253:8080',
  'overwriteprotocol' => 'http',
  'overwritewebroot' => '/',
  'overwritecondaddr' => '^10\\.10\\.1\\.253$',
  'logtimezone' => 'UTC',
  'default_language' => 'en',
  'default_locale' => 'en_US',
);
