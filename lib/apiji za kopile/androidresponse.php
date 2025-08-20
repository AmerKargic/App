<?php
require_once __DIR__ . '/../core/Database.php';

class AndroidResponse {
private $data = [];
private $db;
// dodavanje funkcija za bvozaca 

public function getDriverOrder($code) {
    $response = ['success' => 0, 'message' => 'Neispravan format barkoda.'];
    
    // Validate input barcode
    if (!preg_match('/^KU(\d+)KU(\d+)$/', $code, $matches)) {
        return $response;
    }

    $boxNumber = intval($matches[1]);
    $oid = intval($matches[2]);

    // Validate user access
    $driverId = $this->_g('kup_id', 'int');
    if (!$driverId || !$oid) {
        $response['message'] = 'Nedozvoljen pristup.';
        return $response;
    }

   
    try {
        // Get order data
        $orderStmt = $this->db->prepare("SELECT * FROM z_web_dok WHERE oid = ? LIMIT 1");
        if (!$orderStmt) {
            throw new Exception("Database error: " . $this->db->error);
        }
        
        $orderStmt->bind_param("i", $oid);
        $orderStmt->execute();
        $orderResult = $orderStmt->get_result();
        
        if (!$orderResult) {
            throw new Exception("Result error: " . $orderStmt->error);
        }
        
        $orderData = $orderResult->fetch_assoc();
        
        if (!$orderData) {
            return ['success' => 0, 'message' => 'Narudžba nije pronađena.'];
        }
        
        // Get customer data
        $kupacStmt = $this->db->prepare("
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
            throw new Exception("Customer query error: " . $this->db->error);
        }

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
                // Parse the position string (format: "long,lat")
                $positionParts = explode(',', $kupac['SkladistePosition']);
                if (count($positionParts) == 2) {
                    $latitude= trim($positionParts[0]);
                    $longitude = trim($positionParts[1]);
                    
                    // Add as separate fields - keep these for compatibility
                    $customerData['longitude'] = floatval($longitude);
                    $customerData['latitude'] = floatval($latitude);
                    $customerData['hasCoordinates'] = true;
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

        // Get order items
        $itemsStmt = $this->db->prepare("
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
            throw new Exception("Items query error: " . $this->db->error);
        }

        $itemsStmt->bind_param("i", $oid);
        $itemsStmt->execute();
        $itemsResult = $itemsStmt->get_result();

        if (!$itemsResult) {
            throw new Exception("Items result error: " . $itemsStmt->error);
        }

        // Build items array with proper data structure
        $items = [];
        while ($item = $itemsResult->fetch_assoc()) {
            $items[] = [
                'aid' => intval($item['aid']),
                'naziv' => $item['naziv'] ?? ('Artikal #' . $item['aid']),
                'kol' => floatval($item['kol']),
                'ean' => $item['EAN'] ?? '',
                'cijena' => floatval($item['cijena']),
                'mpc' => floatval($item['mpc'] ?? 0)
            ];
        }
        
        // Calculate if this is a return (negative amount)
        $treba_vratiti_novac = ($orderData['iznos'] < 0);
        
        // Success response
        return [
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
        ];

    } catch (Exception $e) {
        // Log error and return error response
        file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
        return ['success' => 0, 'message' => 'Greška u sistemu: ' . $e->getMessage()];
    }
}

public function scanDriverBox($code) {
    $response = ['success' => 0, 'message' => 'Neispravan format barkoda.'];

    // Validate input barcode
    if (!preg_match('/^ku(\d+)ku(\d+)$/', $code, $matches)) {
        return $response;
    }

    $boxNumber = intval($matches[1]);
    $oid = intval($matches[2]);

    $driverId = $this->_g('kup_id', 'int');
    if (!$driverId || !$oid || !$boxNumber) {
        $response['message'] = 'Nepotpuni podaci.';
        return $response;
    }

    try {
        // Check if the box is already scanned
        $checkStmt = $this->db->prepare("SELECT id FROM z_driver_scanned_boxes WHERE oid = ? AND box_number = ?");
        $checkStmt->bind_param("ii", $oid, $boxNumber);
        $checkStmt->execute();
        if ($checkStmt->get_result()->num_rows > 0) {
            $response['message'] = 'Kutija već skenirana.';
            return $response;
        }

        // Insert scanned box
        $insertStmt = $this->db->prepare("INSERT INTO z_driver_scanned_boxes (oid, box_number, driver_id) VALUES (?, ?, ?)");
        $insertStmt->bind_param("iii", $oid, $boxNumber, $driverId);
        $insertStmt->execute();

        $response = ['success' => 1, 'message' => 'Kutija označena skeniranom.'];
    } catch (Exception $e) {
        $response['message'] = 'Greška u sistemu: ' . $e->getMessage();
    }

    return $response;
}




private function _grabUserData($kup_id, $pos_id = 0) {
    $query = "
        SELECT G.NazivKupca, K.NazivPJ, G.level, 
               IFNULL(Komerc.Magacini_ID, '') AS Magacini_ID,
               Komerc.PristupProknjizi, Komerc.pravo_pregleda_svihmpkomercs
        FROM tblGlavna AS G
        LEFT JOIN tblKupci AS K ON K.IDKupac = G.IDKupac AND K.ID = ?
        LEFT JOIN tblKomercijalista AS Komerc ON Komerc.Kupac_ID = G.IDKupac
        WHERE G.IDKupac = ?
        LIMIT 1
    ";
 
    $stmt = $this->db->prepare($query);
    $stmt->bind_param("ii", $pos_id, $kup_id);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result && $row = $result->fetch_assoc()) {
        $this->data = $row;
        $this->data['kup_id'] = $kup_id;
        $this->data['pos_id'] = $pos_id;

        $this->data['Magacini_ID_array'] = [];
        if (!empty($row['Magacini_ID'])) {
            foreach (explode(',', $row['Magacini_ID']) as $id) {
                $id = trim($id);
                if ($id !== '') {
                    $this->data['Magacini_ID_array'][$id] = $id;
                }
            }
        }
    }
}
public function isLoggedUser($kup_id, $pos_id, $hash1, $hash2) {
    
    $this->isTried = false;
    $this->isLogged = false;

    // Avoid duplicate checks
    if ($this->isTried) {
        return ['success' => $this->isLogged ? 1 : 0];
    }

    // Sanitize input
    $kup_id = intval($kup_id);
    $pos_id = intval($pos_id);
    $hash1 = trim($hash1);
    $hash2 = trim($hash2);

    if (!$kup_id || empty($hash1) || empty($hash2)) {
        return ['success' => 0, 'message' => 'Nedostaju parametri.'];
    }
// Initialize country if not already set
   
    // Prepare query
    $stmt = $this->db->prepare(
        "
        SELECT kup_id, pos_id, hash1_keepactive, hash2_keepactive
        FROM tbl_users_sessions
        WHERE Drzava = ?
          AND kup_id = ?
          AND pos_id = ?
          AND hash1_keepactive = ?
          AND hash2_keepactive = ?
        LIMIT 1
    ");

    if (!$stmt) {
        return ['success' => 0, 'message' => 'Greška u pripremi upita.'];
    }

    $stmt->bind_param("siiss", $this->country, $kup_id, $pos_id, $hash1, $hash2);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $row = $result->fetch_assoc()) {
        if (
            $hash1 === $row['hash1_keepactive'] &&
            $hash2 === $row['hash2_keepactive'] &&
            intval($kup_id) === intval($row['kup_id'])
        ) {
            $this->isLogged = true;
            $this->_grabUserData($row['kup_id'], $row['pos_id']);
            return ['success' => 1, 'data' => ['options' => $this->data]];
        }
    }

    return ['success' => 0, 'message' => 'Sesija nije validna.'];
}

public function __construct($db, $check_login = true) {
    $this->db = $db;
    $this->country = 'BIH';
    $this->connection = $db;

    if ($check_login) {
        $auth = $this->isLoggedUser(
            $_POST['kup_id'] ?? 0,
            $_POST['pos_id'] ?? 0,
            $_POST['hash1'] ?? '',
            $_POST['hash2'] ?? ''
        );

        if (!$auth['success']) {
            echo json_encode(['success' => 0, 'message' => 'Niste prijavljeni.']);
            exit;
        }
    }
}


public function loginUser($email, $password) {
    $response = ['success' => false, 'message' => 'Neuspješna prijava.'];

    $email = strtolower(trim($email));
    $password = trim($password);

    if (empty($email) || empty($password)) {
        $response['message'] = 'Nedostaju podaci za prijavu.';
        return $response;
    }

    // Step 1: Get user by email
    $stmt = $this->db->prepare("
        SELECT IDKupac, Email1, NazivKupca, password_hash, level
        FROM tblGlavna
        WHERE Email1 = ? AND IskljucenKupac = 0
        LIMIT 1
    ");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if (!$result || !$user = $result->fetch_assoc()) {
        $response['message'] = 'Korisnik nije pronađen.';
        return $response;
    }

    // Step 2: Verify password
    if (!hash_equals($user['password_hash'], crypt($password, $user['password_hash']))) {
        $response['message'] = 'Pogrešna lozinka.';
        return $response;
    }

    $kup_id = intval($user['IDKupac']);

    // Step 3: Get POS (first available)
    $pos_id = 0;
    $pos_stmt = $this->db->prepare("SELECT ID FROM tblKupci WHERE IDKupac = ? LIMIT 1");
    $pos_stmt->bind_param("i", $kup_id);
    $pos_stmt->execute();
    $pos_result = $pos_stmt->get_result();
    if ($pos_row = $pos_result->fetch_assoc()) {
        $pos_id = intval($pos_row['ID']);
    }

    // Step 4: Generate session hashes
    $hash1 = bin2hex(random_bytes(8)) . time();
    $hash2 = bin2hex(random_bytes(22)); // ~44 characters

    // Step 5: Store session
    $insert_stmt = $this->db->prepare("
        INSERT INTO tbl_users_sessions (kup_id, pos_id, hash1_keepactive, hash2_keepactive, Drzava)
        VALUES (?, ?, ?, ?, ?)
    ");
    $insert_stmt->bind_param("iisss", $kup_id, $pos_id, $hash1, $hash2, $this->country);

    if (!$insert_stmt->execute()) {
        $response['message'] = 'Greška prilikom spremanja sesije.' . $insert_stmt->error;
       $check_login = false; 
        return $response;
    }

    // Step 6: Load user data and respond
    $this->_grabUserData($kup_id, $pos_id);

    $response['success'] = true;
    $response['message'] = 'Uspješno ste prijavljeni.';
    $response['data'] = [
        'kup_id' => $kup_id,
        'pos_id' => $pos_id,
        'email' => $user['Email1'],
        'name' => $user['NazivKupca'],
        'level' => $user['level'],
        'hash1' => $hash1,
        'hash2' => $hash2,
        'options' => $this->data  // includes roles, Magacini_ID_array, etc.
    ];
    $check_login = true; 
    return $response;
}

	public function _g($find, $type="string") {
			$rd = null;
			
			$val = (isset($this->data[$find])?$this->data[$find]:null);
			
			switch($type) {
				case "int":
					$rd = (is_null($val)?0:intval($val));
					break;
				case "float":
				case "double":
					$rd = (is_null($val)?0:floatval($val));
					break;
				case "string":
				default:
					$rd = (is_null($val)?"":$val);
					break;
			}
			
			return $rd;
		}


        ///// locking wishstock /////
        public function saveLockState() {
            
    $response = ['success' => 0, 'message' => 'Neuspješno zaključavanje.'];

    $aid = intval($_POST['aid'] ?? 0);
    $kup_id = intval($_POST['kup_id'] ?? 0);
    $pos_id = intval($_POST['pos_id'] ?? 0);
    $locked = intval($_POST['stock_wish_locked'] ?? -1);

    if (!$aid || !$kup_id || !$pos_id || ($locked !== 0 && $locked !== 1)) {
        $response['message'] = 'Nedostaju parametri ili neispravno zaključavanje.';
        return $response;
    }

   
    

    $query = "
        INSERT INTO z_web_favoriti (aid, kup_id, pos_id, stock_wish_locked)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE stock_wish_locked = VALUES(stock_wish_locked)
    ";

    $stmt = $this->db->prepare($query);
    $stmt->bind_param("iiii", $aid, $kup_id, $pos_id, $locked);

    if ($stmt->execute()) {
        $response['success'] = 1;
        $response['message'] = 'Zaključavanje uspješno.';
    } else {
        $response['message'] = 'Greška u bazi.';
    }

    return $response;
}
////////// ODRADI IS LOGGED KAKO SE POSTAVLJA I TO DA NE ZABORAVIM //////////

public function getProduct() {
    $rd = ['success' => 0, 'message' => 'Nismo pronašli proizvod!', 'data' => []];

    error_log("getProduct called with: " . json_encode($_POST));

    // Extract and sanitize input
    $kup_id = intval($_POST['kup_id'] ?? 0);
    $pos_id = intval($_POST['pos_id'] ?? 0);
    $hash1 = trim($_POST['hash1'] ?? '');
    $hash2 = trim($_POST['hash2'] ?? '');

    error_log("Parsed values - kup_id: $kup_id, pos_id: $pos_id");

    // Authenticate user
    $auth = $this->isLoggedUser($kup_id, $pos_id, $hash1, $hash2);

    if (!$auth['success']) {
        error_log("Authentication failed: " . json_encode($auth));
        return ['success' => 0, 'message' => 'Niste prijavljeni.', 'data' => []];
    }

    error_log("Authentication successful");

    // Use authenticated IDs from session data
    $kup_id = $this->_g('kup_id', 'int');
    $pos_id = $this->_g('pos_id', 'int');
    
    // Ensure user data is loaded
    if (empty($this->data) && $kup_id) {
        $this->_grabUserData($kup_id, $pos_id);
    }

    // Get product search parameters
    $aid = trim($_POST['aid'] ?? '');
    $ean = trim($_POST['ean'] ?? '');
    
    if (empty($ean) && empty($aid)) {
        error_log("Both EAN and AID are empty");
        return $rd;
    }

    error_log("Searching for - AID: '$aid', EAN: '$ean'");

    // Validate EAN length
    $length = strlen($ean);
    if ($length < 12 && empty($aid)) {
        $rd['message'] = "Neispravan barkod!";
        error_log("Invalid barcode length: $length");
        return $rd;
    }

    $or_ean = "";
    
    // Handle 12-digit EAN (add check digit)
    if ($length === 12) {
        $or_ean = "0" . $ean;
        $ean .= $this->calculateEANCheckDigit($ean);
        error_log("12-digit EAN converted to: $ean, alternative: $or_ean");
    }

    // Build product query
    $query = "
        SELECT 
            C.ID, 
            C.EAN, 
            C.Naziv_{$this->country} AS name, 
            B.Brand, 
            C.MPC_{$this->country} AS MPC,
            (ROUND((C.MPC_{$this->country} - ((C.MPC_{$this->country} * P.MPRabat_{$this->country}) / 100)) / 5, 2) * 5) AS MPC_jednokratno,
            D.description_chatgpt_specs AS description
        FROM 
            Cjenovnik AS C
            INNER JOIN Brand_Uredjaja AS B ON B.IDBrand = C.Brand
            INNER JOIN Podkategorija AS P ON P.IDPodkategorija = C.Podkategorija
            LEFT JOIN d_language_cjenovnik AS D ON D.id = C.ID
        WHERE " . (!empty($aid)
            ? "C.ID = '" . $this->db->real_escape_string($aid) . "'"
            : "C.EAN IN ('" . $this->db->real_escape_string($ean) . "'" . 
              (!empty($or_ean) ? ",'" . $this->db->real_escape_string($or_ean) . "'" : "") . ")") . "
        LIMIT 1
    ";

    error_log("Executing product query: " . $query);

    $result = $this->db->query($query);
    
    if (!$result) {
        error_log("Database error: " . $this->db->error);
        $rd['message'] = 'Greška u bazi podataka.';
        return $rd;
    }

    if ($result->num_rows === 0) {
        error_log("No product found for given criteria");
        return $rd;
    }

    // Get product data
    $rd['data'] = $result->fetch_assoc();
    error_log("Product found: " . $rd['data']['name'] . " (ID: " . $rd['data']['ID'] . ")");

    // Format prices
    $rd['data']['MPC'] = "na rate: " . number_format($rd['data']['MPC'], 2, ',', '.') . " KM";
    $rd['data']['MPC_jednokratno'] = "jednokratno: " . number_format($rd['data']['MPC_jednokratno'], 2, ',', '.') . " KM";
    
    // Get product images
    $rd['data']['images'] = $this->_get_images($rd['data']['ID']);  
    $rd['data']['image'] = $rd['data']['images'][0]['small'] ?? '';

    // Load total stock for non-maloprodaja stores
    $stock_vp = 0;
    $stock_query = "
        SELECT SUM(K.kol)
        FROM z_web_kol AS K
        INNER JOIN web_skladista AS S ON S.ID_Skladiste = K.mag_id
        WHERE S.Drzava = '{$this->country}' 
          AND K.art = " . intval($rd['data']['ID']) . " 
          AND (S.is_maloprodaja = 0 AND S.stanje_sum = 1 AND S.is_A = 1)
    ";
    
    $stock_result = $this->db->query($stock_query);
    if ($stock_result && $stock_result->num_rows > 0) {
        $row = $stock_result->fetch_row();
        $stock_vp = floatval($row[0] ?? 0);
    }

    error_log("Total VP stock: $stock_vp");

    // Load wishstock info for all stores
    $rd['data']['wishstock'] = [];

    $wishstock_query = "
        SELECT S.ID_Skladiste, S.mag, S.NazivMagacin, K.IDKupac, K.ID, K.NazivPJ,
               IFNULL(F.stock_wish, 0) AS stock_wish,
               IFNULL(F.stock_wish_locked, 0) AS stock_wish_locked,
               S.is_maloprodaja,
               IFNULL((
                   SELECT SUM(t.kol)
                   FROM z_web_kol AS t
                   WHERE t.mag_id = S.ID_Skladiste AND t.art = " . intval($rd['data']['ID']) . "
               ), 0) AS stock
        FROM web_skladista AS S
        INNER JOIN tblKupci AS K ON K.ID = S.default_pos_id
        LEFT JOIN (
            SELECT F.kup_id, F.pos_id, F.stock_wish, F.stock_wish_locked
            FROM z_web_favoriti AS F
            WHERE F.aid = " . intval($rd['data']['ID']) . "
        ) AS F ON F.kup_id = K.IDKupac AND F.pos_id = K.ID
        WHERE S.Drzava = '" . $this->db->real_escape_string($this->country) . "'
          AND IFNULL(S.default_pos_id, 0) > 0
          AND ((IFNULL(S.is_os_sredstva, 0) = 0 AND S.is_A = 1) OR (S.is_maloprodaja = 0 AND S.is_A = 0))
        ORDER BY S.is_maloprodaja ASC, S.mag ASC
    ";

    error_log("Executing wishstock query");

    $wishstock_result = $this->db->query($wishstock_query);
    
    if ($wishstock_result) {
        $seen = [];
        $wishstock_count = 0;
        
        while ($row = $wishstock_result->fetch_assoc()) {
            // Use VP stock for non-maloprodaja stores
            if (intval($row['is_maloprodaja']) == 0) {
                $row['stock'] = $stock_vp;
            }
            
            $key = $row['IDKupac'] . '_' . $row['ID']; // unique by user+POS

            if (!isset($seen[$key])) {
                $rd['data']['wishstock'][] = [
                    "kup_id" => intval($row['IDKupac']),
                    "pos_id" => intval($row['ID']),
                    "mag_id" => intval($row['ID_Skladiste']),
                    "name" => $row['NazivPJ'],
                    "stock" => floatval($row['stock']),
                    "stock_wish" => floatval($row['stock_wish']),
                    "stock_wish_locked" => intval($row['stock_wish_locked']),
                ];
                $seen[$key] = true;
                $wishstock_count++;
            }
        }
        
        error_log("Added $wishstock_count wishstock entries");
    } else {
        error_log("Wishstock query failed: " . $this->db->error);
    }

    $rd['success'] = 1;
    $rd['message'] = 'Proizvod pronađen!';
    
    error_log("Product lookup successful - returning data");
    
    return $rd;
}

// Helper method for getting product images
private function _get_images($product_id) {
   /* $images = [];
    
    // You'll need to implement this based on your image storage structure
    // For now, return empty array or default image
    $query = "SELECT image_url FROM product_images WHERE product_id = ? ORDER BY sort_order LIMIT 5";
    $stmt = $this->db->prepare($query);
    
    if ($stmt) {
        $stmt->bind_param("i", $product_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $images[] = [
                'small' => $row['image_url'],
                'large' => $row['image_url']
            ];
        }
    }
    
    // If no images found, return empty array
    if (empty($images)) {
        $images[] = ['small' => '', 'large' => ''];
    }
    
    return $images;*/
        return [['small' => '', 'large' => '']];

}

private function calculateEANCheckDigit($ean12) {
    $sum = 0;
    for ($i = 0; $i < 12; $i++) {
            $digit = (int)$ean12[$i];
            $sum += ($i % 2 === 0) ? $digit : $digit * 3;


        }
        $remainder = $sum % 10;
        return ($remainder === 0) ? 0 : (10 - $remainder);
        }

public function saveWishstock() {
    $response = ['success' => 0, 'message' => 'Neuspješno ažuriranje.'];

    $aid = intval($_POST['aid'] ?? 0);
    $stock_wish = floatval($_POST['stock_wish'] ?? 0);

    // You can either receive kup_id / pos_id from frontend...
    $kup_id = intval($_POST['kup_id'] ?? 0);
    $pos_id = intval($_POST['pos_id'] ?? 0);

    // Or load from session if you already have login logic:
    // $kup_id = $_SESSION['user_kup_id'] ?? 0;
    // $pos_id = $_SESSION['user_pos_id'] ?? 0;

    if (!$aid || !$kup_id || !$pos_id) {
        $response['message'] = 'Nedostaju podaci.';
        return $response;
    }

    // Save or update wishstock (if locked, frontend should've checked before)
    $query = "
        INSERT INTO z_web_favoriti (aid, kup_id, pos_id, stock_wish, stock_wish_locked)
        VALUES (?, ?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE stock_wish = VALUES(stock_wish)
    ";

    $stmt = $this->db->prepare($query);
    $stmt->bind_param("iiid", $aid, $kup_id, $pos_id, $stock_wish);

    if ($stmt->execute()) {
        $response['success'] = 1;
        $response['message'] = 'Ažurirano uspješno.';
    } else {
        $response['message'] = 'Greška u bazi.';
    }

    return $response;
}
}
?>