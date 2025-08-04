<?php
$GLOBALS['check_login'] = false;
ob_start(); // Start output buffering
require_once __DIR__ . '/../core/bootstrap.php';

// Create a log file
$logFile = "../logs/location_sync.log";
if (!file_exists("../logs/")) {
    mkdir("../logs/", 0755, true);
}

try {
    // Get raw input
    $raw_input = file_get_contents("php://input");
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Raw input: $raw_input\n", FILE_APPEND);

    // Decode JSON input
    $data = json_decode($raw_input, true);

    if ($data === null) {
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Invalid JSON data received\n", FILE_APPEND);
        respond(['success' => false, 'message' => 'Invalid JSON data']);
    }

    // Log the decoded data
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Decoded data: " . print_r($data, true) . "\n", FILE_APPEND);

    // Extract authentication parameters
    $kupId = intval($data['kup_id'] ?? 0);
    $hash1 = $data['hash1'] ?? '';
    $hash2 = $data['hash2'] ?? '';

    // Validate authentication
    $authResult = $android->isLoggedUser($kupId, 0, $hash1, $hash2);

    if (!$authResult['success']) {
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Auth failed\n", FILE_APPEND);
        respond(['success' => false, 'message' => 'Authentication failed']);
    }

    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Auth successful\n", FILE_APPEND);

    // Process locations
    $locations = $data['locations'] ?? [];
    if (empty($locations)) {
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "No locations to process\n", FILE_APPEND);
        respond(['success' => false, 'message' => 'No locations to process']);
    }

    $success = 0;
    $failed = 0;

    foreach ($locations as $location) {
        $latitude = isset($location['latitude']) ? floatval($location['latitude']) : null;
        $longitude = isset($location['longitude']) ? floatval($location['longitude']) : null;
        $timestamp = $location['timestamp'] ?? date('Y-m-d H:i:s');

        if ($latitude === null || $longitude === null) {
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Invalid latitude or longitude\n", FILE_APPEND);
            $failed++;
            continue;
        }

        try {
            // Prepare the SQL statement
            $stmt = $mysqli->prepare("
                INSERT INTO user_locations (kup_id, latitude, longitude, timestamp)
                VALUES (?, ?, ?, ?)
            ");

            if (!$stmt) {
                file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Failed to prepare statement: " . $mysqli->error . "\n", FILE_APPEND);
                $failed++;
                continue;
            }

            // Bind parameters and execute the statement
            $stmt->bind_param("idds", $kupId, $latitude, $longitude, $timestamp);
            $result = $stmt->execute();

            if ($result) {
                $success++;
            } else {
                file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Failed to execute statement: " . $stmt->error . "\n", FILE_APPEND);
                $failed++;
            }

            $stmt->close();
        } catch (Exception $e) {
            $failed++;
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Error: " . $e->getMessage() . "\n", FILE_APPEND);
        }
    }

    // Send response
    $response = [
        'success' => true,
        'message' => "Processed $success locations, failed $failed",
        'locations_synced' => $success,
        'locations_failed' => $failed
    ];

    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Response: " . json_encode($response) . "\n", FILE_APPEND);

    ob_end_clean(); // Clean the output buffer
    respond($response);

} catch (Exception $e) {
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Critical error: " . $e->getMessage() . "\n", FILE_APPEND);
    ob_end_clean(); // Clean the output buffer in case of an error
    respond(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}
?>