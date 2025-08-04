<?php
require_once __DIR__ . '/../core/bootstrap.php';
$response = new AndroidResponse($mysqli);

$code = trim($_POST['code'] ?? '');
if (!preg_match('/^ku(\d+)ku(\d+)$/', $code, $matches)) {
    respond(['success' => 0, 'message' => 'Neispravan format barkoda.']);
}

$boxNumber = intval($matches[1]);
$oid = intval($matches[2]);

$driverId = $response->_g('kup_id', 'int');
if (!$driverId || !$oid || !$boxNumber) {
    respond(['success' => 0, 'message' => 'Nepotpuni podaci.']);
}

// Check already scanned
$checkStmt = $mysqli->prepare("SELECT id FROM z_driver_scanned_boxes WHERE oid = ? AND box_number = ?");
$checkStmt->bind_param("ii", $oid, $boxNumber);
$checkStmt->execute();
if ($checkStmt->get_result()->num_rows > 0) {
    respond(['success' => 0, 'message' => 'Kutija već skenirana.']);
}

// Insert
$insertStmt = $mysqli->prepare("INSERT INTO z_driver_scanned_boxes (oid, box_number, driver_id) VALUES (?, ?, ?)");
$insertStmt->bind_param("iii", $oid, $boxNumber, $driverId);
$insertStmt->execute();

respond(['success' => 1, 'message' => 'Kutija označena skeniranom.']);
