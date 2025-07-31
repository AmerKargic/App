<?php

require_once '../db_connect.php';
require_once 'auth_check.php';

// Set content type
header('Content-Type: application/json');

// Get JSON data
$postData = file_get_contents('php://input');
$data = json_decode($postData, true);

if (!$data) {
    respond(['success' => 0, 'message' => 'Invalid JSON data']);
}

// Validate authentication
$kupId = intval($data['kup_id'] ?? 0);
$hash1 = $data['hash1'] ?? '';
$hash2 = $data['hash2'] ?? '';

if (!checkAuth($kupId, $hash1, $hash2)) {
    respond(['success' => 0, 'message' => 'Authentication failed']);
}

// Process boxes
$boxes = $data['boxes'] ?? [];
if (empty($boxes)) {
    respond(['success' => 0, 'message' => 'No boxes to sync']);
}

$success = 0;
$failed = 0;

foreach ($boxes as $box) {
    $oid = intval($box['oid'] ?? 0);
    $boxNumber = intval($box['box_number'] ?? 0);
    $boxBarcode = $box['box_barcode'] ?? '';
    $timestamp = $box['timestamp'] ?? date('Y-m-d H:i:s');
    
    try {
        // Insert into database
        $stmt = $mysqli->prepare("
            INSERT INTO z_scanned_boxes 
            (oid, box_number, box_barcode, scan_date, komerc_id) 
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE 
            scan_date = VALUES(scan_date)
        ");
        
        if (!$stmt) {
            $failed++;
            continue;
        }
        
        $stmt->bind_param(
            "iissi", 
            $oid, 
            $boxNumber, 
            $boxBarcode, 
            $timestamp, 
            $kupId
        );
        
        $result = $stmt->execute();
        
        if ($result) {
            $success++;
        } else {
            $failed++;
        }
        
        $stmt->close();
    } catch (Exception $e) {
        $failed++;
    }
}

// Return response
respond([
    'success' => ($failed == 0) ? 1 : 0,
    'message' => "Synced $success boxes, failed $failed",
    'synced' => $success,
    'failed' => $failed
]);

function respond($data) {
    echo json_encode($data);
    exit;
}
?>