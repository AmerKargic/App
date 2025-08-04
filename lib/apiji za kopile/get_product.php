<?php 
require_once __DIR__ . '/../core/bootstrap.php';
file_put_contents(__DIR__ . "/log_get_product.txt", json_encode($_POST, JSON_PRETTY_PRINT));

$response = new AndroidResponse($mysqli);
$data = $response->getProduct();
respond($data);
?>