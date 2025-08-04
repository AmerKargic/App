<?php
require_once '../core/bootstrap.php';

$product_ean = trim($_GET['ean'] ?? '');
if (!$product_ean) respond(['success'=>0, 'message'=>'No product EAN']);

$stmt = $mysqli->prepare("SELECT ID FROM Cjenovnik WHERE EAN=? LIMIT 1");
$stmt->bind_param("s", $product_ean);
$stmt->execute();
$res = $stmt->get_result();
if (!$res || !$prod = $res->fetch_assoc()) {
    respond(['success'=>0, 'message'=>'Product not found']);
}
$pid = $prod['ID'];

// Which shelf?
$stmt2 = $mysqli->prepare("
  SELECT ws.shelf_name, ws.shelf_ean
  FROM warehouse_shelf_products wsp
  INNER JOIN warehouse_shelves ws ON ws.id = wsp.shelf_id
  WHERE wsp.product_id=?
  LIMIT 1
");
$stmt2->bind_param("i", $pid);
$stmt2->execute();
$res2 = $stmt2->get_result();
if ($res2 && $shelf = $res2->fetch_assoc()) {
    respond(['success'=>1, 'shelf'=>$shelf]);
} else {
    respond(['success'=>0, 'message'=>'No shelf found for this product']);
}
