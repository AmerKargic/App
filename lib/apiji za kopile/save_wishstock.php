<?php
require_once __DIR__ . '/../core/bootstrap.php';
$response = new AndroidResponse($mysqli);

// Set response headers
header('Content-Type: application/json');

// Output saveWishstock result
echo json_encode($response->saveWishstock());
