<?php
require_once __DIR__ . '/../core/bootstrap.php';

$response = new AndroidResponse($mysqli);
$db = $mysqli;

$rd = ['success' => 0, 'message' => 'Greška.'];

$oid = intval($_POST['oid'] ?? 0);
$lat = isset($_POST['lat']) ? floatval($_POST['lat']) : null;
$lng = isset($_POST['lng']) ? floatval($_POST['lng']) : null;

$kup_id = $response->_g('kup_id', 'int');
$pos_id = $response->_g('pos_id', 'int');

if (!$oid || !$kup_id || !$pos_id) {
    $rd['message'] = 'Nedostaju podaci.';
    respond($rd);
}

// 1. Provjera da li su sve kutije skenirane
$kutijeQ = $db->prepare("SELECT COUNT(*) FROM z_web_voznje_skenirano WHERE oid = ? AND pos_id = ?");
$kutijeQ->bind_param("ii", $oid, $pos_id);
$kutijeQ->execute();
$kutijeQ->bind_result($skenirane_kutije);
$kutijeQ->fetch();
$kutijeQ->close();

$ukupnoQ = $db->prepare("SELECT br_kutija, iznos FROM z_web_dokk WHERE oid = ?");
$ukupnoQ->bind_param("i", $oid);
$ukupnoQ->execute();
$ukupnoQ->bind_result($br_kutija, $iznos);
$ukupnoQ->fetch();
$ukupnoQ->close();

if ($skenirane_kutije < $br_kutija) {
    $rd['message'] = "Nisu sve kutije skenirane: $skenirane_kutije/$br_kutija.";
    respond($rd);
}

// 2. Kreiraj tabelu ako ne postoji
$db->query("CREATE TABLE IF NOT EXISTS z_web_voznje_preuzeto (
    id INT AUTO_INCREMENT PRIMARY KEY,
    oid INT NOT NULL,
    kup_id INT NOT NULL,
    pos_id INT NOT NULL,
    preuzeto_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    iznos DECIMAL(10,2),
    povrat DECIMAL(10,2),
    lat DECIMAL(10,6),
    lng DECIMAL(10,6),
    UNIQUE KEY (oid, pos_id)
)");

// 3. Upis preuzimanja
$povrat = $iznos < 0 ? abs($iznos) : 0;

$upsert = $db->prepare("REPLACE INTO z_web_voznje_preuzeto 
    (oid, kup_id, pos_id, iznos, povrat, lat, lng) 
    VALUES (?, ?, ?, ?, ?, ?, ?)");
$upsert->bind_param("iiidddd", $oid, $kup_id, $pos_id, $iznos, $povrat, $lat, $lng);
$upsert->execute();

$rd['success'] = 1;
$rd['message'] = 'Narudžba uspješno preuzeta.';
$rd['data'] = [
    'iznos' => $iznos,
    'povrat' => $povrat,
];

respond($rd);
