<?php
require_once '../core/bootstrap.php';

$name = trim($_POST['shelf_name'] ?? '');
$ean = trim($_POST['shelf_ean'] ?? '');

if (!$name || !$ean || strlen($ean) != 13) {
    respond(['success'=>0, 'message'=>'Missing or invalid shelf name/EAN']);
}

$stmt = $mysqli->prepare("INSERT INTO warehouse_shelves (shelf_name, shelf_ean) VALUES (?, ?)");
$stmt->bind_param("ss", $name, $ean);
if ($stmt->execute()) {
    respond(['success'=>1, 'shelf_id'=>$stmt->insert_id]);
} else {
    respond(['success'=>0, 'message'=>'DB Error (duplicate EAN?)']);
}
