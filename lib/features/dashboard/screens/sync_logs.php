<?php

$GLOBALS['check_login'] = false;

require_once __DIR__ . '/../core/bootstrap.php';

// Get JSON data
$raw_input = file_get_contents("php://input");
$data = json_decode($raw_input, true);

if (!is_array($data)) {
    respond(['success' => false, 'message' => 'Invalid JSON data']);
}

// Validate authentication - use your existing auth method
$kupId = intval($data['kup_id'] ?? 0);
$hash1 = $data['hash1'] ?? '';
$hash2 = $data['hash2'] ?? '';

// Use your existing authentication system (adjust according to your bootstrap.php setup)
$authResult = $android->checkUserAuth($kupId, $hash1, $hash2);
if (!$authResult['success']) {
    respond(['success' => false, 'message' => 'Authentication failed']);
}

// Process logs
$logs = $data['logs'] ?? [];
if (empty($logs)) {
    respond(['success' => false, 'message' => 'No logs to sync']);
}

$success = 0;
$failed = 0;

// Connect to database using your existing connection
global $db; // Assuming your bootstrap sets this up

foreach ($logs as $log) {
    $komercId = intval($log['komerc_id'] ?? 0);
    $dateReport = $log['date_report'] ?? null;
    $typeId = intval($log['type_id'] ?? 0);
    $text = $log['text'] ?? null;
    $oidId = isset($log['oid_id']) && $log['oid_id'] !== null ? intval($log['oid_id']) : null;
    $extraData = $log['extra_data'] ?? null;
    $latitude = isset($log['latitude']) && $log['latitude'] !== null ? floatval($log['latitude']) : null;
    $longitude = isset($log['longitude']) && $log['longitude'] !== null ? floatval($log['longitude']) : null;
    
    try {
        // Insert into database using your database structure
        $stmt = $db->prepare("
            INSERT INTO z_scan_report 
            (komerc_id, date_report, type_id, text, oid_id, extra_data, latitude, longitude) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->bind_param(
            "isisidd", 
            $komercId, 
            $dateReport, 
            $typeId, 
            $text, 
            $oidId, 
            $extraData,
            $latitude,
            $longitude
        );
        
        $result = $stmt->execute();
        
        if ($result) {
            $success++;
        } else {
            $failed++;
        }
    } catch (Exception $e) {
        $failed++;
        // Log error if you have a logging system
        error_log("Sync error: " . $e->getMessage());
    }
}

// Return response using your existing format
respond([
    'success' => ($failed == 0),
    'message' => "Synced $success logs, failed $failed",
    'synced' => $success,
    'failed' => $failed
]);
?>