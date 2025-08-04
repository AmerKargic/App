
<?php
require_once dirname(dirname(__FILE__)) . '/webshop/incs/config008.php';

require_once __DIR__ . '/Database.php';
require_once __DIR__ . '/AndroidResponse.php';

$db = new Database();
$android = new AndroidResponse($db->conn, $GLOBALS['check_login'] ?? true); // Pass the MySQLi connection, not the Database object
$mysqli = $db->conn;
function respond($data){
    header( 'Content-Type: application/json');
    echo json_encode($data);
    exit;
}   

?>