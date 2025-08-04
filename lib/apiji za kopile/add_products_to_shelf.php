<?php
require_once '../core/bootstrap.php';

$shelf_ean = trim($_POST['shelf_ean'] ?? '');
$product_ids = $_POST['product_ids'] ?? []; // array of product IDs

if (!$shelf_ean || !is_array($product_ids) || count($product_ids)==0) {
    respond(['success'=>0, 'message'=>'Missing shelf EAN or products']);
}

// Find shelf_id by EAN
$stmt = $mysqli->prepare("SELECT id FROM warehouse_shelves WHERE shelf_ean=? LIMIT 1");
$stmt->bind_param("s", $shelf_ean);
$stmt->execute();
$res = $stmt->get_result();
if (!$res || !$shelf = $res->fetch_assoc()) {
    respond(['success'=>0, 'message'=>'Shelf not found']);
}
$shelf_id = $shelf['id'];

// Add products to shelf (skip duplicates)
$added = 0;
foreach ($product_ids as $pid) {
    $pid = intval($pid);
    $stmt2 = $mysqli->prepare("INSERT IGNORE INTO warehouse_shelf_products (shelf_id, product_id) VALUES (?,?)");
    $stmt2->bind_param("ii", $shelf_id, $pid);
    if ($stmt2->execute()) $added++;
}
respond(['success'=>1, 'added'=>$added]);
