<?php
require_once __DIR__ . '/../core/bootstrap.php';
require_once __DIR__ . '/../classes/AndroidResponse.php';

header('Content-Type: application/json');

$kup_id = intval($_POST['kup_id'] ?? 0);
$pos_id = intval($_POST['pos_id'] ?? 0);
$hash1 = trim($_POST['hash1'] ?? '');
$hash2 = trim($_POST['hash2'] ?? '');

if (!$kup_id || empty($hash1) || empty($hash2)) {
  echo json_encode([
    'success' => 0,
    'message' => 'Nedostaju parametri.'
  ]);
  exit;
}

// 👇 This is important: disable auto-login in constructor
$android = new AndroidResponse($mysqli, false);

// ✅ Validate session using isLoggedUser()
$result = $android->isLoggedUser($kup_id, $pos_id, $hash1, $hash2);

echo json_encode($result);
?>