<?php
/**
 * ClipboardUpload Plugin - バックエンドアップロードエンドポイント
 *
 * テスト実行画面のクリップボード貼り付けボタンから呼ばれる。
 * base64画像データを受け取り、一時ファイル経由で tlAttachmentRepository に保存する。
 *
 * リクエスト (POST multipart/form-data):
 *   execution_id : int    - attachments.fk_id (executions.id)
 *   filename     : string - 保存ファイル名 (例: screenshot_20261021_123456.png)
 *   image        : file   - クリップボードから取得した画像 Blob
 *
 * レスポンス (JSON):
 *   {"status":"ok",  "filename":"..."}
 *   {"status":"error","message":"..."}
 */

// plugin.php 経由でインクルードされるため、
// config.inc.php と common.php はすでにロード済み。
// tlAttachmentRepository, tlInputParameter 等が使用可能。

header('Content-Type: application/json; charset=utf-8');

// ---------------------------------------------------------------
// 認証チェック：ログイン済みかつ attachments 機能が有効であること
// ---------------------------------------------------------------
if (!isset($_SESSION['currentUser'])) {
  echo json_encode(['status' => 'error', 'message' => '認証が必要です']);
  exit;
}

$attachCfg = config_get('attachments');
if (!$attachCfg->enabled) {
  echo json_encode(['status' => 'error', 'message' => '添付ファイル機能が無効です']);
  exit;
}

// ---------------------------------------------------------------
// 入力値の取得・検証
// ---------------------------------------------------------------
$executionId = isset($_POST['execution_id']) ? intval($_POST['execution_id']) : 0;
$filename    = isset($_POST['filename'])     ? trim($_POST['filename'])       : '';

if ($executionId <= 0) {
  echo json_encode(['status' => 'error', 'message' => 'execution_id が不正です']);
  exit;
}

if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
  $errCode = isset($_FILES['image']['error']) ? $_FILES['image']['error'] : -1;
  echo json_encode(['status' => 'error', 'message' => 'ファイルアップロードエラー (code=' . $errCode . ')']);
  exit;
}

// ---------------------------------------------------------------
// ファイル名のサニタイズ
// ---------------------------------------------------------------
// 空または不正な場合はタイムスタンプベースのファイル名を生成
if ($filename === '') {
  $ext      = _clipupload_mime_to_ext($_FILES['image']['type']);
  $filename = 'screenshot_' . date('Ymd_His') . '.' . $ext;
}

// パス区切り文字とNULLバイトを除去
$filename = basename(str_replace("\0", '', $filename));

// 拡張子チェック（png / jpg / gif のみ許可）
$ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
if (!in_array($ext, ['png', 'jpg', 'jpeg', 'gif'])) {
  echo json_encode(['status' => 'error', 'message' => '許可されていないファイル形式です（png/jpg/gif のみ）']);
  exit;
}

// ファイル名の正規表現チェック（config.inc.php の allowed_filenames_regexp に従う）
$pattern = trim($attachCfg->allowed_filenames_regexp);
if ($pattern !== '' && !preg_match($pattern, $filename)) {
  // 正規表現に合わない場合は短縮した自動生成名に差し替え
  // 例: scr_20261021143022.png（16文字+ドット+拡張子）
  $filename = 'scr_' . date('YmdHis') . '.' . $ext;
  // それでも合わない場合はチェックをスキップ（設定が特殊な環境への対処）
}

// ファイルサイズチェック
if ($_FILES['image']['size'] > TL_REPOSITORY_MAXFILESIZE) {
  $limitMb = round(TL_REPOSITORY_MAXFILESIZE / 1024 / 1024, 1);
  echo json_encode(['status' => 'error',
                    'message' => 'ファイルサイズが上限（' . $limitMb . 'MB）を超えています']);
  exit;
}

// ---------------------------------------------------------------
// MIMEタイプチェック（アップロードされた実際のファイルで確認）
// ---------------------------------------------------------------
$mimeType = _clipupload_detect_mime($_FILES['image']['tmp_name']);
if (!in_array($mimeType, ['image/png', 'image/jpeg', 'image/gif'])) {
  echo json_encode(['status' => 'error', 'message' => '画像ファイルではありません']);
  exit;
}

// ---------------------------------------------------------------
// tlAttachmentRepository 経由で保存
// ---------------------------------------------------------------
doDBConnect($db);
$docRepo = tlAttachmentRepository::create($db);

$fInfo = [
  'name'     => $filename,
  'type'     => $mimeType,
  'size'     => $_FILES['image']['size'],
  'tmp_name' => $_FILES['image']['tmp_name'],
  'error'    => UPLOAD_ERR_OK,
];

$opt = ['allow_empty_title' => true];
$tableRef = DB_TABLE_PREFIX . 'executions';

$result = $docRepo->insertAttachment($executionId, $tableRef, '', $fInfo, $opt);

if ($result->statusOK) {
  logAuditEvent(
    TLS('audit_attachment_created', '', $filename),
    'CREATE', $executionId, 'attachments'
  );
  echo json_encode(['status' => 'ok', 'filename' => $filename]);
} else {
  $msg = isset($result->msg) && $result->msg !== ''
       ? $result->msg
       : ('保存に失敗しました (code=' . $result->statusCode . ')');
  echo json_encode(['status' => 'error', 'message' => $msg]);
}

// ---------------------------------------------------------------
// ヘルパー関数
// ---------------------------------------------------------------

/**
 * MIMEタイプから拡張子を返す
 */
function _clipupload_mime_to_ext($mime)
{
  $map = ['image/png' => 'png', 'image/jpeg' => 'jpg', 'image/gif' => 'gif'];
  return isset($map[$mime]) ? $map[$mime] : 'png';
}

/**
 * ファイルの実際のMIMEタイプを検出する
 * fileinfo 拡張が使えない環境では先頭バイトで簡易判定する
 */
function _clipupload_detect_mime($tmpPath)
{
  if (function_exists('finfo_open')) {
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime  = finfo_file($finfo, $tmpPath);
    finfo_close($finfo);
    return $mime;
  }

  // フォールバック：マジックバイトで判定
  $fp    = fopen($tmpPath, 'rb');
  $bytes = fread($fp, 8);
  fclose($fp);

  if (substr($bytes, 0, 4) === "\x89PNG")      return 'image/png';
  if (substr($bytes, 0, 2) === "\xFF\xD8")     return 'image/jpeg';
  if (substr($bytes, 0, 6) === 'GIF87a'
   || substr($bytes, 0, 6) === 'GIF89a')       return 'image/gif';

  return 'application/octet-stream';
}
