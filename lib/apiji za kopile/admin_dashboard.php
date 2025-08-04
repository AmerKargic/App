<?php
$GLOBALS['check_login'] = false;
require_once __DIR__ . '/../core/bootstrap.php';

header('Content-Type: application/json');

try {
    // Fetch active drivers
    $driversQuery = "
        SELECT ul.kup_id, ul.latitude, ul.longitude, ul.timestamp, g.NazivKupca AS driver_name
        FROM user_locations ul
        INNER JOIN tblGlavna g ON g.IDKupac = ul.kup_id
        GROUP BY ul.kup_id
        ORDER BY ul.timestamp DESC
    ";
    $driversResult = $mysqli->query($driversQuery);
    $drivers = [];

    while ($driver = $driversResult->fetch_assoc()) {
        $driverId = $driver['kup_id'];

        // Fetch orders for the driver
        $ordersQuery = "
            SELECT sb.oid, sb.box_number, wd.kup_email, wd.kup_adresa, wd.kup_naziv,
                   sp.ean, c.Naziv_BIH AS product_name, c.MPC_BIH AS price
            FROM z_scanned_boxes sb
            INNER JOIN z_web_dok wd ON wd.oid = sb.oid
            LEFT JOIN z_scanned_products sp ON sp.oid = sb.oid
            LEFT JOIN Cjenovnik c ON c.EAN = sp.ean
            WHERE sb.kup_id = ? AND sb.synced = 0
        ";
        $ordersStmt = $mysqli->prepare($ordersQuery);
        $ordersStmt->bind_param("i", $driverId);
        $ordersStmt->execute();
        $ordersResult = $ordersStmt->get_result();
        $orders = [];

        while ($order = $ordersResult->fetch_assoc()) {
            $orders[] = $order;
        }

        // Fetch route for the driver
        $routeQuery = "
            SELECT latitude, longitude, timestamp
            FROM user_locations
            WHERE kup_id = ?
            ORDER BY timestamp ASC
        ";
        $routeStmt = $mysqli->prepare($routeQuery);
        $routeStmt->bind_param("i", $driverId);
        $routeStmt->execute();
        $routeResult = $routeStmt->get_result();
        $route = [];

        while ($point = $routeResult->fetch_assoc()) {
            $route[] = $point;
        }

        // Fetch customers for the driver
        $customersQuery = "
            SELECT DISTINCT wd.kup_naziv AS name, wd.kup_adresa AS address, wd.kup_email AS email
            FROM z_web_dok wd
            INNER JOIN z_scanned_boxes sb ON sb.oid = wd.oid
            WHERE sb.kup_id = ?
        ";
        $customersStmt = $mysqli->prepare($customersQuery);
        $customersStmt->bind_param("i", $driverId);
        $customersStmt->execute();
        $customersResult = $customersStmt->get_result();
        $customers = [];

        while ($customer = $customersResult->fetch_assoc()) {
            $customers[] = $customer;
        }

        // Combine all data for the driver
        $drivers[] = [
            'driver_id' => $driverId,
            'driver_name' => $driver['driver_name'],
            'latitude' => $driver['latitude'],
            'longitude' => $driver['longitude'],
            'timestamp' => $driver['timestamp'],
            'orders' => $orders,
            'route' => $route,
            'customers' => $customers,
        ];
    }

    // Respond with the combined data
    respond(['success' => 1, 'drivers' => $drivers]);
} catch (Exception $e) {
    respond(['success' => 0, 'message' => 'Error fetching data: ' . $e->getMessage()]);
}
?>