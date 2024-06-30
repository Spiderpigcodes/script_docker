<?php
$CONFIG = array (
  'instanceid' => 'oc12345',
  'passwordsalt' => 'randomsalt',
  'secret' => 'secret',
  'trusted_domains' => 
  array (
    0 => '10.10.1.253',
    1 => '10.10.1.252',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '21.0.1.1',
  'overwrite.cli.url' => 'https://10.10.1.253:443',
  'overwritehost' => '10.10.1.253:443',
  'overwriteprotocol' => 'https',
  'overwritewebroot' => '/',
  'overwritecondaddr' => '^10\\.10\\.1\\.252$|^10\\.10\\.1\\.253$',
  'logtimezone' => 'UTC',
  'default_language' => 'en',
  'default_locale' => 'en_US',
);
