<?php

require_once __DIR__ . '/../core/bootstrap.php';

try {
    $query = "
        SELECT ul.kup_id, ul.latitude, ul.longitude, ul.timestamp, g.NazivKupca AS driver_name
        FROM user_locations ul
        INNER JOIN tblGlavna g ON g.IDKupac = ul.kup_id
        WHERE ul.synced = 0
        GROUP BY ul.kup_id
        ORDER BY ul.timestamp DESC
    ";

    $result = $mysqli->query($query);
    $drivers = [];

    while ($row = $result->fetch_assoc()) {
        $drivers[] = $row;
    }

    respond(['success' => 1, 'drivers' => $drivers]);
} catch (Exception $e) {
    respond(['success' => 0, 'message' => 'Error fetching drivers: ' . $e->getMessage()]);
}
?>