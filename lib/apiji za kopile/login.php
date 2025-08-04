<?php
$GLOBALS['check_login'] = false;

require_once __DIR__ . '/../core/bootstrap.php';

$raw_input = file_get_contents("php://input");
$data = json_decode($raw_input, true); // decode to array

if (!is_array($data)) {
    respond(['success' => false, 'message' => 'Neispravan JSON.']);
}

$email = isset($data['email']) ? trim(strtolower($data['email'])) : '';
$password = isset($data['password']) ? trim($data['password']) : '';

if (!$email || !$password) {
    respond(['success' => false, 'message' => 'Email i lozinka su obavezni.']);
}

$result = $android->loginUser($email, $password);
respond($result);
?>
