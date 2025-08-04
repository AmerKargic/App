<?php
require_once __DIR__ . '/../core/bootstrap.php';

$response = new AndroidResponse($mysqli);
$db = $mysqli;

$rd = ['success' => 0, 'message' => 'Greška u slanju izvještaja.'];

// Obavezni podaci
$kup_id = $response->_g('kup_id', 'int');
$pos_id = $response->_g('pos_id', 'int');
$oidi = $_POST['oidi'] ?? ''; // CSV lista npr: "123,124,125"
$lat = isset($_POST['lat']) ? floatval($_POST['lat']) : null;
$lng = isset($_POST['lng']) ? floatval($_POST['lng']) : null;

if (!$kup_id || !$pos_id || empty($oidi)) {
    $rd['message'] = 'Nedostaju podaci.';
    respond($rd);
}

// Pretvori OIDe u array
$oids = array_filter(array_map('intval', explode(',', $oidi)));

if (empty($oids)) {
    $rd['message'] = 'Neispravna lista narudžbi.';
    respond($rd);
}

// Kreiraj tabelu ako ne postoji
$db->query("CREATE TABLE IF NOT EXISTS z_web_voznje_dan (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kup_id INT NOT NULL,
    pos_id INT NOT NULL,
    oidi TEXT,
    ukupno_iznos DECIMAL(12,2),
    ukupno_povrat DECIMAL(12,2),
    lat DECIMAL(10,6),
    lng DECIMAL(10,6),
    zavrseno_at DATETIME DEFAULT CURRENT_TIMESTAMP
)");

// Izračunaj ukupne iznose
$placeholders = implode(',', array_fill(0, count($oids), '?'));
$types = str_repeat('i', count($oids));
$stmt = $db->prepare("SELECT SUM(iznos), SUM(povrat) FROM z_web_voznje_preuzeto WHERE oid IN ($placeholders) AND pos_id = ?");
$stmt->bind_param($types . 'i', ...$oids, $pos_id);
$stmt->execute();
$stmt->bind_result($ukupno, $povrat);
$stmt->fetch();
$stmt->close();

// Ubaci u dnevni izvještaj
$save = $db->prepare("INSERT INTO z_web_voznje_dan 
    (kup_id, pos_id, oidi, ukupno_iznos, ukupno_povrat, lat, lng) 
    VALUES (?, ?, ?, ?, ?, ?, ?)");
$oidCsv = implode(',', $oids);
$save->bind_param("iisdddd", $kup_id, $pos_id, $oidCsv, $ukupno, $povrat, $lat, $lng);
$save->execute();

$rd['success'] = 1;
$rd['message'] = 'Kraj dana uspješno prijavljen.';
$rd['data'] = [
    'narudžbi' => count($oids),
    'ukupno' => $ukupno,
    'povrat' => $povrat,
];

respond($rd);
