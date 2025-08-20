<?php 
require_once __DIR__ . '/../core/bootstrap.php';

$raw_input = file_get_contents('php://input');
$data = json_decode($raw_input, true);
if(!is_array($data)) {
    respond(['success' => 0, 'message' => 'Invalid JSON input']);
}
$action = $data['action'] ?? '';
$plate = $data['plate'] ?? '';

if($action === 'get'){
    respond($truckApi->getTruck($plate));
}

if($action === 'take'){
 $driver_id  = $data['kup_id'] ?? null; 
 $driver_name = $data['NazivKupca'] ?? null;
 respond($truckApi->takeTruck($plate, $driver_id, $driver_name));
}

if ($action === 'return'){
    respond($truckApi->returnTruck($plate));
}

respond(['success' => 0, 'message' => 'Nepostojeća funkcija!!']);

?>