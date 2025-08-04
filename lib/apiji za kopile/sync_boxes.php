<?php
$GLOBALS['check_login'] = false;

require_once __DIR__ . '/../core/bootstrap.php';

// Create a log file
$logFile = "../logs/box_sync.log";
if (!file_exists("../logs/")) {
    mkdir("../logs/", 0755, true);
}


try {

    // Ge
$raw_input = file_get_contents("php://input");

$data = json_decode($raw_input, true);
if ($data === null) {
    respond(['success' => false, 'message' => 'Invalid JSON data']);
}

    // Log the received data

    if (!is_array($data)) {
        respond(['success' => false, 'message' => 'Invalid JSON data']);
    }

    // Extract authentication parameters
    if (!empty($data['boxes']) && is_array($data['boxes'])) {
        $firstBox = $data['boxes'][0];
        $kupId = intval($firstBox['kup_id'] ?? 0);
        $posId = intval($firstBox['pos_id'] ?? 0);
        $hash1 = $firstBox['hash1'] ?? '';
        $hash2 = $firstBox['hash2'] ?? '';
    } else {
      
        respond(['success' => false, 'message' => 'Invalid data structure']);
    }

   

    // Validate authentication
    $authResult = $android->isLoggedUser($kupId, $posId, $hash1, $hash2);

    if (!$authResult['success']) {
       
        respond(['success' => false, 'message' => 'Authentication failed']);
    }



    // Process boxes
    $boxes = $data['boxes'] ?? [];
    if (empty($boxes)) {
        respond(['success' => false, 'message' => 'No boxes to sync']);
    }


    // Create tables if they don't exist
    $mysqli->query("
        CREATE TABLE IF NOT EXISTS `z_scanned_boxes` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `oid` int(11) NOT NULL,
          `box_number` int(11) NOT NULL,
          `box_barcode` varchar(50) NOT NULL,
          `scan_date` datetime NOT NULL,
          `komerc_id` int(11) NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `order_box` (`oid`,`box_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    $mysqli->query("
        CREATE TABLE IF NOT EXISTS `z_scanned_products` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `oid` int(11) NOT NULL,
          `box_number` int(11) NOT NULL,
          `ean` varchar(50) NOT NULL,
          `scan_date` datetime NOT NULL,
          `komerc_id` int(11) NOT NULL,
          PRIMARY KEY (`id`),
          KEY `box_idx` (`oid`,`box_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    $success = 0;
    $failed = 0;
    $productsSuccess = 0;
    $productsFailed = 0;

    // Process each box
    foreach ($boxes as $box) {
        $oid = intval($box['oid'] ?? 0);
        $boxNumber = intval($box['box_number'] ?? 0);
        $boxBarcode = $box['box_barcode'] ?? '';
        $timestamp = $box['timestamp'] ?? date('Y-m-d H:i:s');
        $products = $box['products'] ?? [];


        try {
            // Insert/update box
            $stmt = $mysqli->prepare("
                INSERT INTO z_scanned_boxes 
                (oid, box_number, box_barcode, scan_date, komerc_id) 
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                box_barcode = VALUES(box_barcode),
                scan_date = VALUES(scan_date)
            ");

            if (!$stmt) {
                $failed++;
                continue;
            }

            $scanDate = date('Y-m-d H:i:s');
            $stmt->bind_param("iissi", $oid, $boxNumber, $boxBarcode, $scanDate, $kupId);
            $result = $stmt->execute();

            if ($result) {
                $success++;

                // Clear existing products
                $deleteQuery = "DELETE FROM z_scanned_products WHERE oid = $oid AND box_number = $boxNumber";
                $mysqli->query($deleteQuery);

                // Insert new products
                if (!empty($products)) {
                    $productStmt = $mysqli->prepare("
                        INSERT INTO z_scanned_products 
                        (oid, box_number, ean, scan_date, komerc_id) 
                        VALUES (?, ?, ?, ?, ?)
                    ");

                    if ($productStmt) {
                        foreach ($products as $ean) {
                            $productStmt->bind_param("iissi", $oid, $boxNumber, $ean, $scanDate, $kupId);
                            $productResult = $productStmt->execute();

                            if ($productResult) {
                                $productsSuccess++;
                            } else {
                                $productsFailed++;
                            }
                        }
                        $productStmt->close();
                    }
                }
            }
            $stmt->close();
        } catch (Exception $e) {
            $failed++;
        }
    }

    $response = [
        'success' => true,
        'message' => "Synced $success boxes with $productsSuccess products",
        'boxes_synced' => $success,
        'boxes_failed' => $failed,
        'products_synced' => $productsSuccess,
        'products_failed' => $productsFailed
    ];

    respond($response);

} catch (Exception $e) {
    respond(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}


?>