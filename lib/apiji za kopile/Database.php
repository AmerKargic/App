<?php

require_once(dirname(dirname(__FILE__)). '/webshop/incs/config008.php');

class Database {
    public $conn; 

    public function __construct(){
        $this->conn = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_DATABASE);

        if ($this->conn->connect_error) {
            die(json_encode(['success' => false, 'error' => 'DB connection failed: ' . $this->conn->connect_error]));
        }
        
    }
    public function clean($input){
        return $this-> conn->real_escape_string(trim($input));
    }
}




?>