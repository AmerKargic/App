<?php
// filepath: c:\xampp\htdocs\appinternal\api\driver_order.php

// Logging setup
$logFile = __DIR__ . '/driver_log.txt';
file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "OrderData: " . json_encode($_POST) . "\n", FILE_APPEND);

// Include necessary files
require_once __DIR__ . '/../core/bootstrap.php';
file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "API hit\n", FILE_APPEND);

// Set up response headers and error reporting
header('Content-Type: application/json');
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Add this function near the top of your file, after the require statements
function reverseGeocode($lat, $lng) {
    global $logFile;
    
    try {
        // Use Google Maps Reverse Geocoding API
        $apiKey = "AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo"; // Your API key
        $url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=bs&region=ba";
        
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Reverse geocoding URL: $url\n", FILE_APPEND);
        
        // Make the API request
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        $response = curl_exec($ch);
        $curlError = curl_error($ch);
        curl_close($ch);
        
        if (!$response) {
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Reverse geocoding failed: " . ($curlError ?: "No response") . "\n", FILE_APPEND);
            return null;
        }
        
        // Parse response
        $data = json_decode($response, true);
        
        if ($data['status'] == 'OK' && !empty($data['results'])) {
            // Get the first (most precise) result
            $result = $data['results'][0];
            $formattedAddress = $result['formatted_address'];
            
            // Log success
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
                "Reverse geocoding successful: $formattedAddress\n", FILE_APPEND);
            
            return $formattedAddress;
        } else {
            // Log failure
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
                "Reverse geocoding failed: " . ($data['status'] ?? 'Unknown error') . "\n", FILE_APPEND);
            return null;
        }
    } catch (Exception $e) {
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
            "Reverse geocoding exception: " . $e->getMessage() . "\n", FILE_APPEND);
        return null;
    }
}

// Validate input barcode
$code = trim($_POST['code'] ?? '');
if (!preg_match('/^KU(\d+)KU(\d+)$/', $code, $matches)) {
    respond(['success' => 0, 'message' => 'Neispravan format barkoda.']);
}

$boxNumber = intval($matches[1]);
$oid = intval($matches[2]);

// Validate user access
$driverId = intval($_POST['kup_id'] ?? 0);
if (!$driverId || !$oid) {
    respond(['success' => 0, 'message' => 'Nedozvoljen pristup.']);
}

// Log validated data
file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Box: $boxNumber, OID: $oid, Driver: $driverId\n", FILE_APPEND);

try {
    // Get order data
    $orderStmt = $mysqli->prepare("SELECT * FROM z_web_dok WHERE oid = ? LIMIT 1");
    if (!$orderStmt) {
        throw new Exception("Database error: " . $mysqli->error);
    }
    
    $orderStmt->bind_param("i", $oid);
    $orderStmt->execute();
    $orderResult = $orderStmt->get_result();
    
    if (!$orderResult) {
        throw new Exception("Result error: " . $orderStmt->error);
    }
    
    $orderData = $orderResult->fetch_assoc();
    
    if (!$orderData) {
        respond(['success' => 0, 'message' => 'Narudžba nije pronađena.']);
    }
    
    // Get customer data
   $kupacStmt = $mysqli->prepare("
    SELECT 
        D.kup_naziv AS NazivKupca,
        D.kup_adresa AS Adresa1,
        O.Opstina,
        DRZ.ImeDrzave,
        D.kup_telefon AS Telefon1,
        D.kup_email AS Email,
        D.pos_id AS PosId,
        D.mag_id AS MagId,
        D.mag2_id AS Mag2Id,
        E.ID_Skladiste AS SkladisteId,
        E.Nazivmagacin AS SkladisteNaziv,
        E.VrstaMagacin AS SkladisteVrsta,
        E.is_maloprodaja AS IsMaloprodaja,
        E.google_position AS SkladistePosition,
        CASE 
            WHEN E.ID_Skladiste IS NOT NULL THEN E.ID_Skladiste 
            ELSE E2.ID_Skladiste 
        END AS ActualSkladisteId
    FROM 
        z_web_dok D
    LEFT JOIN 
        tblOpstina O ON O.IDOpstina = D.kup_opstina
    LEFT JOIN 
        tblDrzavaOznaka DRZ ON DRZ.IDDrzavaOznaka = D.Drzava
    LEFT JOIN
        web_skladista E ON E.ID_Skladiste = D.mag2_id
    LEFT JOIN
        web_skladista E2 ON E2.ID_Skladiste = D.mag_id
    WHERE 
        D.oid = ?
    LIMIT 1");
    
if (!$kupacStmt) {
    throw new Exception("Customer query error: " . $mysqli->error);
}

// Bind the order ID instead of customer ID
$kupacStmt->bind_param("i", $oid);
$kupacStmt->execute();
$kupacResult = $kupacStmt->get_result();

if (!$kupacResult) {
    throw new Exception("Customer result error: " . $kupacStmt->error);
}

    $kupac = $kupacResult->fetch_assoc();

    // Add debug logging for raw data
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Raw kupac data: " . json_encode($kupac) . "\n", FILE_APPEND);

    // First check if we have valid warehouse IDs
    $hasMagId = !empty($kupac['MagId']);
    $hasMag2Id = !empty($kupac['Mag2Id']);
    $hasSkladisteData = !empty($kupac['SkladisteId']) && !empty($kupac['SkladisteNaziv']);

    // Log the warehouse IDs for debugging
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
        "Warehouse IDs - MagId: " . ($hasMagId ? $kupac['MagId'] : 'empty') . 
        ", Mag2Id: " . ($hasMag2Id ? $kupac['Mag2Id'] : 'empty') . 
        ", SkladisteId: " . ($hasSkladisteData ? $kupac['SkladisteId'] : 'empty') . "\n", 
        FILE_APPEND);

    // Only check IsMaloprodaja if we have warehouse data
    $useRetailStoreData = $hasSkladisteData && !empty($kupac['IsMaloprodaja']) && $kupac['IsMaloprodaja'] == 1;

    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
        "Order #$oid is for " . ($useRetailStoreData ? "retail store (IsMaloprodaja=" . $kupac['IsMaloprodaja'] . ")" : "regular customer") . "\n", 
        FILE_APPEND);

    // Build customer data structure
    $customerData = [
        'adresa' => $kupac['Adresa1'] ?? '',
        'opstina' => $kupac['Opstina'] ?? '',
        'drzava' => $kupac['ImeDrzave'] ?? '',
        'telefon' => $kupac['Telefon1'] ?? '',
        'email' => $kupac['Email'] ?? '',
    ];

    // Then add type-specific fields
    if ($useRetailStoreData) {
        // This is a retail store with valid data
        $customerData['naziv'] = $kupac['SkladisteNaziv'] ?? '';
        $customerData['isMaloprodaja'] = true;
        $customerData['skladisteId'] = intval($kupac['SkladisteId'] ?? 0);
        $customerData['skladisteVrsta'] = $kupac['SkladisteVrsta'] ?? '';
        $customerData['posId'] = intval($kupac['PosId'] ?? 0);
        $customerData['magId'] = intval($kupac['MagId'] ?? 0);
        $customerData['mag2Id'] = intval($kupac['Mag2Id'] ?? 0);
        
        // Parse and add the Google position if available
        if (!empty($kupac['SkladistePosition'])) {
            // Log the position string
            file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
                "Found position string: " . $kupac['SkladistePosition'] . "\n", FILE_APPEND);
                
            // Parse the position string (format: "long,lat")
            $positionParts = explode(',', $kupac['SkladistePosition']);
            if (count($positionParts) == 2) {
                $latitude= trim($positionParts[0]);
                $longitude = trim($positionParts[1]);
                
                // Add as separate fields - keep these for compatibility
                $customerData['longitude'] = floatval($longitude);
                $customerData['latitude'] = floatval($latitude);
                $customerData['hasCoordinates'] = true;
                
                file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
                    "Parsed coordinates: lat=$latitude, lng=$longitude\n", FILE_APPEND);
                    
                // NEW: Try to reverse geocode the coordinates to get a street address
                $geoAddress = reverseGeocode($latitude, $longitude);
                if ($geoAddress) {
                    // Override the address with the geocoded one
                    $customerData['adresa'] = $geoAddress;
                    
                    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
                        "Updated address with geocoded value: $geoAddress\n", FILE_APPEND);
                }
            }
        } else {
            $customerData['hasCoordinates'] = false;
        }
    } else {
        // This is a regular customer or we don't have valid retail store data
        $customerData['naziv'] = $kupac['NazivKupca'] ?? '';
        $customerData['isMaloprodaja'] = false;
        $customerData['hasCoordinates'] = false;
        
        // Include these fields with default values for consistency
        $customerData['skladisteId'] = 0;
        $customerData['skladisteVrsta'] = '';
        $customerData['posId'] = intval($kupac['PosId'] ?? 0);
        $customerData['magId'] = intval($kupac['MagId'] ?? 0);
        $customerData['mag2Id'] = intval($kupac['Mag2Id'] ?? 0);
    }

    // Log the final customer data
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . 
        "Customer data: " . json_encode($customerData) . "\n", FILE_APPEND);

    // Get order items
   $itemsStmt = $mysqli->prepare("
    SELECT 
        A.aid, 
        A.kol, 
        A.cijena, 
        C.Naziv_BIH AS naziv, 
        C.EAN,
        C.MPC_BIH AS mpc


    FROM 
        z_web_dok_art A 
    LEFT JOIN 
        Cjenovnik C ON C.ID = A.aid
    WHERE 
        A.oid_id = ?
    ORDER BY 
        A.aid ASC");
    
if (!$itemsStmt) {
    throw new Exception("Items query error: " . $mysqli->error);
}

$itemsStmt->bind_param("i", $oid);
$itemsStmt->execute();
$itemsResult = $itemsStmt->get_result();

if (!$itemsResult) {
    throw new Exception("Items result error: " . $itemsStmt->error);
}

// Debug item count
$itemCount = $itemsResult->num_rows;
file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Found $itemCount items for order #$oid\n", FILE_APPEND);

// Build items array with proper data structure
$items = [];
while ($item = $itemsResult->fetch_assoc()) {
    // Log each item for debugging
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Item: " . json_encode($item) . "\n", FILE_APPEND);
    
    $items[] = [
        'aid' => intval($item['aid']),
        'naziv' => $item['naziv'] ?? ('Artikal #' . $item['aid']),
        'kol' => floatval($item['kol']),
        'ean' => $item['EAN'] ?? '',
        'cijena' => floatval($item['cijena']),
        'mpc' => floatval($item['mpc'] ?? 0)
    ];
}

// Log full items array
file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Final items array: " . json_encode($items) . "\n", FILE_APPEND);
    
    // Calculate if this is a return (negative amount)
    $treba_vratiti_novac = ($orderData['iznos'] < 0);
    
    // Success response
    respond([
        'success' => 1,
        'order' => [
            'oid' => $orderData['oid'],
            'broj_kutija' => intval($orderData['br_kutija']),
            'iznos' => floatval($orderData['iznos']),
            'napomena' => $orderData['nap'] ?? '',
            'napomenaVozac' => $orderData['nap_vozac'] ?? '',
            'trebaVratitiNovac' => $treba_vratiti_novac,
            'kupac' => $customerData,
            'stavke' => $items
        ]
    ]);

} catch (Exception $e) {
    // Log error and return error response
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    respond(['success' => 0, 'message' => 'Greška u sistemu: ' . $e->getMessage()]);
}
?>