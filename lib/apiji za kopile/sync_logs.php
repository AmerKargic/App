<?php

// Tell AndroidResponse not to check login automatically
$GLOBALS['check_login'] = false;

// Include bootstrap which loads Database, AndroidResponse, and the respond() function
require_once __DIR__ . '/../core/bootstrap.php';

// Create log file for debugging
$logFile = "../logs/activity_sync.log";
if (!file_exists("../logs/")) {
    mkdir("../logs/", 0755, true);
}

try {
    // Get JSON data
    $raw_input = file_get_contents("php://input");
    $data = json_decode($raw_input, true);

    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Received data: " . substr(json_encode($data), 0, 500) . "\n", FILE_APPEND);

    if (!is_array($data)) {
        respond(['success' => false, 'message' => 'Invalid JSON data']);
    }

    // Validate authentication - use your existing auth method
    $kupId = intval($data['kup_id'] ?? 0);
    $posId = intval($data['pos_id'] ?? 0); 
    $hash1 = $data['hash1'] ?? '';
    $hash2 = $data['hash2'] ?? '';

    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Auth attempt with kup_id=$kupId, pos_id=$posId\n", FILE_APPEND);

    // Pass all 4 required parameters to isLoggedUser
    $authResult = $android->isLoggedUser($kupId, $posId, $hash1, $hash2);
    
    if (!$authResult['success']) {
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Auth failed for user $kupId\n", FILE_APPEND);
        respond(['success' => false, 'message' => 'Authentication failed']);
    }

    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Auth successful for user $kupId\n", FILE_APPEND);

    // Process logs
    $logs = $data['logs'] ?? [];
    if (empty($logs)) {
        respond(['success' => false, 'message' => 'No logs to sync']);
    }

    $success = 0;
    $failed = 0;

    foreach ($logs as $log) {
        $komercId = intval($log['komerc_id'] ?? 0);
        $dateReport = $log['date_report'] ?? date('Y-m-d H:i:s');
        $typeId = intval($log['type_id'] ?? 0);
        $text = $log['text'] ?? '';
        $oidId = isset($log['oid_id']) && $log['oid_id'] !== '' ? intval($log['oid_id']) : null;
        $extraData = $log['extra_data'] ?? null;
        
        // Handle null latitude/longitude
        $latitude = null;
        $longitude = null;
        
        if (isset($log['latitude']) && $log['latitude'] !== null && $log['latitude'] !== '') {
            $latitude = floatval($log['latitude']);
        }
        
        if (isset($log['longitude']) && $log['longitude'] !== null && $log['longitude'] !== '') {
            $longitude = floatval($log['longitude']);
        }
        
        try {
            // Debug the values we're trying to insert
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Inserting: komerc=$komercId, date=$dateReport, type=$typeId, text=$text, oid=$oidId, lat=$latitude, long=$longitude\n", FILE_APPEND);
            
            // Check if z_scan_report table has all these columns
            $checkSql = "SHOW COLUMNS FROM z_scan_report";
            $checkResult = $mysqli->query($checkSql);
            $columns = [];
            while ($col = $checkResult->fetch_assoc()) {
                $columns[] = $col['Field'];
            }
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Available columns: " . implode(", ", $columns) . "\n", FILE_APPEND);
            
            // Prepare the SQL statement with only columns that exist
            $sql = "INSERT INTO z_scan_report (";
            $values = " VALUES (";
            $types = "";
            $params = [];
            
            if (in_array('komerc_id', $columns)) {
                $sql .= "komerc_id, ";
                $values .= "?, ";
                $types .= "i";
                $params[] = &$komercId;
            }
            
            if (in_array('date_report', $columns)) {
                $sql .= "date_report, ";
                $values .= "?, ";
                $types .= "s";
                $params[] = &$dateReport;
            }
            
            if (in_array('type_id', $columns)) {
                $sql .= "type_id, ";
                $values .= "?, ";
                $types .= "i";
                $params[] = &$typeId;
            }
            
            if (in_array('text', $columns)) {
                $sql .= "text, ";
                $values .= "?, ";
                $types .= "s";
                $params[] = &$text;
            }
            
            if (in_array('oid_id', $columns)) {
                $sql .= "oid_id, ";
                $values .= "?, ";
                $types .= "i";
                $params[] = &$oidId;
            }
            
            if (in_array('extra_data', $columns)) {
                $sql .= "extra_data, ";
                $values .= "?, ";
                $types .= "s";
                $params[] = &$extraData;
            }
            
            if (in_array('latitude', $columns)) {
                $sql .= "latitude, ";
                $values .= "?, ";
                $types .= "d";
                $params[] = &$latitude;
            }
            
            if (in_array('longitude', $columns)) {
                $sql .= "longitude, ";
                $values .= "?, ";
                $types .= "d";
                $params[] = &$longitude;
            }
            
            // Remove trailing commas
            $sql = rtrim($sql, ", ") . ")";
            $values = rtrim($values, ", ") . ")";
            
            // Complete the SQL statement
            $sql .= $values;
            
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "SQL: $sql\n", FILE_APPEND);
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Types: $types\n", FILE_APPEND);
            
            // Prepare and execute
            $stmt = $mysqli->prepare($sql);
            
            if (!$stmt) {
                $failed++;
                file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Prepare failed: " . $mysqli->error . "\n", FILE_APPEND);
                continue;
            }
            
            if (!empty($params)) {
                // Only call bind_param if we have parameters to bind
                call_user_func_array([$stmt, 'bind_param'], array_merge([$types], $params));
            }
            
            $result = $stmt->execute();
            
            if ($result) {
                $success++;
                file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Log inserted successfully\n", FILE_APPEND);
            } else {
                $failed++;
                file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Failed to insert log: " . $stmt->error . "\n", FILE_APPEND);
            }
            
            $stmt->close();
        } catch (Exception $e) {
            $failed++;
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Error: " . $e->getMessage() . "\n", FILE_APPEND);
        }
    }

    // Return response using your existing respond() function from bootstrap
    respond([
        'success' => ($failed == 0) ? true : false,
        'message' => "Synced $success logs, failed $failed",
        'synced' => $success,
        'failed' => $failed
    ]);
    
} catch (Exception $e) {
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Fatal error: " . $e->getMessage() . "\n", FILE_APPEND);
    respond(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}
?>