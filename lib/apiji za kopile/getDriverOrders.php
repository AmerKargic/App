<?php
$GLOBALS['check_login'] = false;
require_once __DIR__ . '/../core/bootstrap.php';

$kup_id = intval($_GET['kup_id'] ?? 0);

if (!$kup_id) {
    respond(['success' => 0, 'message' => 'Invalid driver ID']);
}

try {
    $query = "
        SELECT sb.oid, sb.box_number, wd.kup_email, wd.kup_adresa, wd.kup_naziv,
               sp.ean, c.Naziv_BIH AS product_name, c.MPC_BIH AS price
        FROM z_scanned_boxes sb
        INNER JOIN z_web_dok wd ON wd.oid = sb.oid
        LEFT JOIN z_scanned_products sp ON sp.oid = sb.oid
        LEFT JOIN Cjenovnik c ON c.EAN = sp.ean
        WHERE sb.kup_id = ? AND sb.synced = 0
    ";

    $stmt = $mysqli->prepare($query);
    $stmt->bind_param("i", $kup_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $orders = [];

    while ($row = $result->fetch_assoc()) {
        $orders[] = $row;
    }

    respond(['success' => 1, 'orders' => $orders]);
} catch (Exception $e) {
    respond(['success' => 0, 'message' => 'Error fetching orders: ' . $e->getMessage()]);
}
?>