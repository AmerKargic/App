<?php

class RetailFlow {
    private $db; 
    private $android; 

    public function __construct($db, $android) {
        $this->db = $db;
        $this->android = $android;
   
    }


    private function createNotification($recipientKupId, $title, $body, array $payload = [], $type='retail') {
        $payloadJson = json_encode($payload, JSON_UNESCAPED_UNICODE);
        $stmt = $this->db->prepare("INSERT INTO z_notifications (recipient_kup_id, title, body, payload_json, type) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("issss", $recipientKupId, $title, $body, $payloadJson, $type);
        $stmt->execute();
    }

    private function precheckRetail($oid) {
        $oid = intval($oid);
        $stmt = $this->db->prepare("SELECT oid, br_kutija, mag2_id, pos_id FROM z_web_dok WHERE oid = ? LIMIT 1");
        $stmt->bind_param("i", $oid);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($res->num_rows === 0) return ['ok'=>false, 'msg'=>'Order not found'];

        $row = $res->fetch_assoc();
        $boxes = intval($row['br_kutija'] ?? 0);
        $mag2  = intval($row['mag2_id'] ?? 0);

        // Define retail strictly by mag2_id > 0 (as traženo)
        $isRetail = ($mag2 > 0) ? 1 : 0;
        $default_pos_id = 0;

        // If you still want to try default_pos_id, keep this (won't affect isRetail):
        $w = $this->db->prepare("SELECT default_pos_id FROM web_skladista WHERE ID_Skladiste = ? LIMIT 1");
        $w->bind_param("i", $mag2);
        $w->execute();
        $wr = $w->get_result();
        if ($wr && $wr->num_rows) {
            $ws = $wr->fetch_assoc();
            $default_pos_id = intval($ws['default_pos_id'] ?? 0);
        }

        // Allowed retail: support both possible keys
        $allowedRetail = false;
        $magArr = $this->android->data['Magacini_ID_array'] ?? ($this->android->data['Magacini_ID'] ?? []);
        if (is_array($magArr)) {
            $allowedRetail = isset($magArr[(string)$mag2]) || isset($magArr[$mag2]);
        }

        // Map default_pos_id -> tblKupci.IDKupac (retail kup_id)
        $storeKupId = 0;
        if ($default_pos_id > 0) {
            $q = $this->db->prepare("SELECT IDKupac FROM tblKupci WHERE ID = ? LIMIT 1");
            $q->bind_param("i", $default_pos_id);
            $q->execute();
            $qr = $q->get_result();
            if ($qr && $qr->num_rows) $storeKupId = intval($qr->fetch_assoc()['IDKupac']);
        }

        return [
            'ok'=>true,
            'isRetail'=>($isRetail===1),
            'allowedRetail'=>$allowedRetail,
            'br_kutija'=>$boxes,
            'store_kup_id'=>$storeKupId,
            'mag2_id'=>$mag2
        ];
    }

    public function requestRetailApproval($oid) {
        $driverId = $this->android->_g('kup_id','int');
        if (!$driverId || !$oid) return ['success'=>0,'message'=>'Invalid params'];

        $pre = $this->precheckRetail($oid);
        if (!$pre['ok']) return ['success'=>0,'message'=>$pre['msg']];

        // Decide requirement: by isRetail (mag2_id>0) and allowedRetail
        $retailRequired = ($pre['isRetail'] && $pre['allowedRetail']) ? 1 : 0;

        // Upsert into z_driver_orders: set retail_required and isretail
        $ins = $this->db->prepare("
            INSERT INTO z_driver_orders (oid, driver_id, retail_required, isretail)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                retail_required = VALUES(retail_required),
                isretail = GREATEST(isretail, VALUES(isretail)),
                updated_at = NOW()
        ");
        $isretailVal = $pre['isRetail'] ? 1 : 0;
        $ins->bind_param("iiii", $oid, $driverId, $retailRequired, $isretailVal);
        $ins->execute();

        if ($retailRequired) {
            // Notify driver + retail store (if mapped)
            $this->createNotification($driverId, 'Zahtjev za maloprodaju', "Narudžba #$oid zahtijeva sken u maloprodaji.", ['oid'=>$oid,'role'=>'driver'], 'retail');
            if ($pre['store_kup_id'] > 0) {
                $this->createNotification($pre['store_kup_id'], 'Narudžba čeka prihvat', "Skenirajte kutije za narudžbu #$oid.", ['oid'=>$oid,'role'=>'retail'], 'retail');
            }
            return ['success'=>1,'retail_required'=>1,'message'=>'Maloprodaja je potrebna'];
        } else {
            return ['success'=>1,'retail_required'=>0,'message'=>'Maloprodaja nije potrebna'];
        }
    }

    public function retailScanBox($code, $oidOptional = 0) {
        $retailId = $this->android->_g('kup_id','int');
        if (!$retailId) return ['success'=>0,'message'=>'Not logged in'];

        if (!preg_match('/^KU(\d+)KU(\d+)$/i', $code, $m)) {
            return ['success'=>0,'message'=>'Invalid barcode'];
        }
        $boxNumber = intval($m[1]); $oidFromCode = intval($m[2]);
        if ($oidOptional && $oidOptional != $oidFromCode) return ['success'=>0,'message'=>'OID mismatch'];
        $oid = $oidFromCode;

        $ins = $this->db->prepare("INSERT IGNORE INTO z_retail_scanned_boxes (oid, box_number, retail_id) VALUES (?,?,?)");
        $ins->bind_param("iii", $oid, $boxNumber, $retailId);
        $ins->execute();

        // Make sure driver order row reflects that retail is required (if mag2_id > 0)
        $pre = $this->precheckRetail($oid);
        $retailRequired = ($pre['isRetail'] && $pre['allowedRetail']) ? 1 : 0;
        $up = $this->db->prepare("
            INSERT INTO z_driver_orders (oid, driver_id, retail_required, isretail)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                retail_required = GREATEST(retail_required, VALUES(retail_required)),
                isretail = GREATEST(isretail, VALUES(isretail)),
                updated_at = NOW()
        ");
        // we don't know driver_id here; write a neutral row with driver_id=0 only if no driver row exists?
        // Better: update all driver rows for this oid.
        $upAll = $this->db->prepare("UPDATE z_driver_orders SET retail_required = GREATEST(retail_required, ?), isretail = GREATEST(isretail, ?) WHERE oid = ?");
        $rr = $retailRequired ? 1 : 0;
        $ir = $pre['isRetail'] ? 1 : 0;
        $upAll->bind_param("iii", $rr, $ir, $oid);
        $upAll->execute();

        $need = 0; $have = 0;
        $q1 = $this->db->prepare("SELECT br_kutija FROM z_web_dok WHERE oid = ? LIMIT 1");
        $q1->bind_param("i",$oid); $q1->execute(); $rs1 = $q1->get_result();
        if ($rs1 && $rs1->num_rows) $need = intval($rs1->fetch_assoc()['br_kutija']);
        $q2 = $this->db->prepare("SELECT COUNT(*) c FROM z_retail_scanned_boxes WHERE oid = ?");
        $q2->bind_param("i",$oid); $q2->execute(); $rs2 = $q2->get_result();
        if ($rs2 && $rs2->num_rows) $have = intval($rs2->fetch_assoc()['c']);

        return ['success'=>1,'message'=>'Box recorded','scanned'=>$have,'required'=>$need];
    }

    public function retailAccept($oid) {
        $need = 0; $have = 0;
        $q1 = $this->db->prepare("SELECT br_kutija FROM z_web_dok WHERE oid = ? LIMIT 1");
        $q1->bind_param("i",$oid); $q1->execute(); $rs1 = $q1->get_result();
        if ($rs1 && $rs1->num_rows) $need = intval($rs1->fetch_assoc()['br_kutija']);
        $q2 = $this->db->prepare("SELECT COUNT(*) c FROM z_retail_scanned_boxes WHERE oid = ?");
        $q2->bind_param("i",$oid); $q2->execute(); $rs2 = $q2->get_result();
        if ($rs2 && $rs2->num_rows) $have = intval($rs2->fetch_assoc()['c']);

        if ($need <= 0 || $have < $need) {
            return ['success'=>0,'message'=>"Retail scanned $have/$need boxes"];
        }

        // Optionally flag retail_required in driver orders (kept as 1 to indicate this flow existed)
        $this->db->query("UPDATE z_driver_orders SET retail_required = GREATEST(retail_required, 1), isretail = GREATEST(isretail, 1), updated_at = NOW() WHERE oid = ".intval($oid));

        return ['success'=>1,'message'=>'Retail accepted'];
    }

    public function getNotifications() {
        $kupId = $this->android->_g('kup_id','int');
        if (!$kupId) return ['success'=>0,'message'=>'Not logged in'];
        $stmt = $this->db->prepare("SELECT id, title, body, payload_json, type, created_at FROM z_notifications WHERE recipient_kup_id = ? AND read_at IS NULL ORDER BY created_at DESC LIMIT 50");
        $stmt->bind_param("i", $kupId);
        $stmt->execute();
        $res = $stmt->get_result();
        $rows = [];
        while ($r = $res->fetch_assoc()) $rows[] = $r;
        return ['success'=>1,'notifications'=>$rows];
    }

    public function markNotificationRead($id) {
        $kupId = $this->android->_g('kup_id','int');
        if (!$kupId || !$id) return ['success'=>0,'message'=>'Invalid'];
        $stmt = $this->db->prepare("UPDATE z_notifications SET read_at = NOW() WHERE id = ? AND recipient_kup_id = ? AND read_at IS NULL");
        $stmt->bind_param("ii", $id, $kupId);
        $stmt->execute();
        return ['success'=>1];
    }
} 
?>