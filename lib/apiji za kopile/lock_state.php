<?php
require_once __DIR__ . '/../core/bootstrap.php';


$response = new AndroidResponse($mysqli);
$data = $response->saveLockState();
respond($data);

?>