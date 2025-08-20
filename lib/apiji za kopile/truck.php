<?php

class TruckApi {
    private $db; 
    public function __construct($db) {
        $this->db = $db;
    }

    public function getTruck($plate) {
        $stmt = mysqli_prepare($this->db, 'SELECT * FROM vehicles WHERE plate = ?');
        mysqli_stmt_bind_param($stmt, "s", $plate);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);
        $truck  = mysqli_fetch_assoc($result);
        if (!$truck) {
            return ['success' => 0, 'message' => 'Kamion nije pronađen.'];
            
        }else { 
            return ['success' => 1, 'truck_data' => $truck];
        }
    }

    public function takeTruck($plate, $driver_id, $driver_name) {
        $stmt = mysqli_prepare($this->db, 'UPDATE vehicles SET current_driver_id = ?, current_driver_name = ? WHERE plate = ?'); 
        mysqli_stmt_bind_param($stmt, "iss", $driver_id, $driver_name, $plate);
        mysqli_stmt_execute($stmt);

        if (mysqli_stmt_affected_rows($stmt) > 0) {
            return ['success' => 1, 'message' => 'Kamion je uspješno preuzet.'];
        } else {
            return ['success' => 0, 'message' => 'Greška pri preuzimanju kamiona.'];
        }
    }
   
    public function returnTruck($plate){
        $stmt= mysqli_prepare ($this ->db, 'UPDATE vehicles SET current_driver_id = NULL, current_driver_name = NULL WHERE plate = ?');
        mysqli_stmt_bind_param($stmt, "s", $plate);
        mysqli_stmt_execute($stmt);

        if (mysqli_stmt_affected_rows($stmt) > 0) {
            return ['success' => 1, 'message' => 'Kamion je uspješno vraćen.'];
        } else {
            return ['success' => 0, 'message' => 'Greška pri vraćanju kamiona.'];
        }
    }
}
?>
