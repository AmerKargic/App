<?php
require_once __DIR__ . '/../core/bootstrap.php';
$response = new AndroidResponse($mysqli);

$oid = intval($_POST['oid'] ?? 0);
$driverId = $response->_g('kup_id', 'int');

if (!$oid || !$driverId) {
    respond(['success' => 0, 'message' => 'Neispravan pristup.']);
}

$stmt = $mysqli->prepare("SELECT driver_id FROM z_driver_scanned_boxes WHERE oid = ? AND driver_id != ? LIMIT 1");
$stmt->bind_param("ii", $oid, $driverId);
$stmt->execute();

$res = $stmt->get_result();

if ($res->num_rows > 0) {
    respond([
        'success' => 1,
        'conflict' => true,
        'message' => 'Drugi vozač je već skenirao kutije iz ove narudžbe.'
    ]);
} else {
    respond([
        'success' => 1,
        'conflict' => false,
        'message' => 'Nema konflikta. Možete nastaviti skeniranje.'
    ]);
}
