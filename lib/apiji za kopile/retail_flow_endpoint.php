<?php

require_once __DIR__ . '/../core/bootstrap.php';
require_once __DIR__ . '/../core/androidresponse.php';

require_once __DIR__ . '/../core/retail_flow.php';

$android = new AndroidResponse(null, true);
$flow = new RetailFlow($android->connection, $android);

// Accept JSON or form
$raw = file_get_contents('php://input');
$req = json_decode($raw, true);
if (!is_array($req)) $req = $_POST;

$action = $req['action'] ?? '';
$oid = intval($req['oid'] ?? 0);
$code = strval($req['code'] ?? '');
$id = intval($req['id'] ?? 0);

switch ($action) {
  case 'request_retail_approval':
    echo json_encode($flow->requestRetailApproval($oid)); break;
  case 'retail_scan_box':
    echo json_encode($flow->retailScanBox($code, $oid)); break;
  case 'retail_accept':
    echo json_encode($flow->retailAccept($oid)); break;
  case 'get_notifications':
    echo json_encode($flow->getNotifications()); break;
  case 'mark_notification_read':
    echo json_encode($flow->markNotificationRead($id)); break;
  default:
    echo json_encode(['success'=>0,'message'=>'Unknown action']);
}
?>