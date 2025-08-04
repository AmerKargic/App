<?php
$GLOBALS['check_login'] = false;
require_once __DIR__ . '/../core/bootstrap.php';

$email = $_POST['email'] ?? '';
$subject = "Your Package is Near!";
$message = $_POST['message'] ?? '';

if (empty($email) || empty($message)) {
    respond(['success' => 0, 'message' => 'Missing email or message']);
}

try {
    $headers = "From: no-reply@yourdomain.com\r\n";
    $headers .= "Content-Type: text/html; charset=UTF-8\r\n";

    if (mail($email, $subject, $message, $headers)) {
        respond(['success' => 1, 'message' => 'Email sent successfully']);
    } else {
        respond(['success' => 0, 'message' => 'Failed to send email']);
    }
} catch (Exception $e) {
    respond(['success' => 0, 'message' => 'Error sending email: ' . $e->getMessage()]);
}
?>