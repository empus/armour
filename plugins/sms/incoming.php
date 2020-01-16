<?php

  /*
	Incoming HTTP-API from www.smsglobal.com
        https://www.smsglobal.com/http-api/#incoming-sms

	Compatible with Armour 'smsbot' plugin
	Empus <empus@undernet.org>
  */

  // file location for Armour script to read from
  $file = '/home/armour/bots/armour/plugins/sms/data.log';


  // do not edit below

  if ($_SERVER["REQUEST_METHOD"] != "GET") {
	echo "error.";
        exit;
  }
  $to = $_GET['to'];
  $from = $_GET['from'];
  $msg = $_GET['msg'];
  $userfield = $_GET['userfield'];
  $date = $_GET['date'];
  if (empty($to) || empty($from) || empty($msg) || empty($userfield) || empty($date)) {
  	echo "error.";
        exit;
  }
  echo 'OK';
  $line = $to . "," . $from . "," . $userfield . "," . $date . "," . $msg . "\n";
  file_put_contents($file, $line, FILE_APPEND | LOCK_EX);

?>

