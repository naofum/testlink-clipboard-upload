# ClipboardUpload プラグイン

テスト実行画面にクリップボードからの画像貼り付けアップロード機能を追加する TestLink プラグインです。

## 機能概要

### パターン①：実行結果入力時にエビデンスを添付（メイン機能）

- 実行レベルのファイル選択横に 📋 ボタンを表示
- ステップレベルのファイル選択横にも 📋 ボタンを表示（ステップごとに独立）
- ボタンをクリックするとモーダルが開き、**Ctrl+V**（Mac: **⌘+V**）で画像を貼り付け
- 「選択」ボタンを押すとフォームに画像を埋め込む
- 通常通りステータスを選択して保存ボタンを押すと、**実行結果と同時に**画像が添付される
- 1アクションで完結（保存→添付の2段階が不要）

### パターン②：実行履歴行への追加添付

- 実行履歴テーブルの各行（過去の実行結果）の 📎 ボタン横に 📋 ボタンを表示
- ボタンをクリックすると該当 execution_id に直接アップロード（fetch API）

### 共通

- Chrome / Firefox / Safari / Edge すべてのモダンブラウザに対応
- HTTPS 不要（`paste` イベント方式のため HTTP 環境でも動作）

---

## ディレクトリ構成

```
plugins/ClipboardUpload/
├── ClipboardUpload.php             ← プラグインメインクラス（登録のみ、フックなし）
├── pages/
│   └── upload.php                  ← パターン②用バックエンドアップロードAPI
├── templates/
│   └── clipboard_modal.tpl         ← モーダルUI・JSテンプレート（参照・配布用）
├── template_patch.diff             ← テンプレート修正の差分ファイル（参照用）
└── README.md                       ← 本ファイル
```

**Smarty テンプレートディレクトリへの配置（必須）:**

```
gui/templates/tl-classic/execute/
└── clipboard_modal.tpl             ← Smarty からインクルードされる実体
```

**修正が必要なコアファイル:**

```
gui/templates/tl-classic/execute/execSetResults.tpl       ← モーダルインクルード追加
gui/templates/tl-classic/execute/inc_exec_show_tc_exec.tpl ← 履歴行に📋ボタン追加
gui/templates/tl-classic/attachments_simple.inc.tpl       ← 実行・ステップ入力に📋ボタン追加
lib/functions/exec.inc.php                                 ← base64→$_FILES注入処理
```

---

## 導入手順

### 1. ファイルの配置

```
<TestLinkルート>/
└── plugins/
    └── ClipboardUpload/
        ├── ClipboardUpload.php
        ├── pages/
        │   └── upload.php
        ├── templates/
        │   └── clipboard_modal.tpl
        └── README.md
```

### 2. モーダルテンプレートの配置

```bash
sudo cp /var/www/html/testlink/plugins/ClipboardUpload/templates/clipboard_modal.tpl \
        /var/www/html/testlink/gui/templates/tl-classic/execute/clipboard_modal.tpl
```

### 3. プラグインのインストール

1. TestLink に管理者アカウントでログイン
2. 上部メニュー → **「管理」** → **「プラグイン管理」**
3. **ClipboardUpload** を **「インストール」**

### 4. 添付ファイル機能の有効化確認

```php
// config.inc.php
$tlCfg->attachments->enabled = true;
$tlCfg->attachments->allowed_files = 'doc,xls,gif,png,jpg,xlsx,csv';  // png/jpg を含むこと
```

### 5. テンプレートの手動修正（下記「テンプレートの手動修正」を参照）

### 6. Smarty キャッシュのクリア

```bash
sudo rm -f /var/www/html/testlink/gui/templates_c/*.php
```

---

## テンプレートの手動修正

手動修正が必要なファイルは **4つ** あります。

---

### 修正①: モーダルUIのインクルード追加（必須）

**対象ファイル:** `gui/templates/tl-classic/execute/execSetResults.tpl`

`#plugin_display` の直後に以下を追加します。

```smarty
    {if $gui->plugins.EVENT_TESTRUN_DISPLAY}
      <div id="plugin_display">
        ...
      </div>
    {/if}

    {* ← ここに追加 *}
    {* ClipboardUpload Plugin: モーダルUI・JS を常時出力（テストケース選択状態に依存しない） *}
    {include file="execute/clipboard_modal.tpl"}
```

---

### 修正②: 実行・ステップ入力エリアへの📋ボタン追加（必須・パターン①）

**対象ファイル:** `gui/templates/tl-classic/attachments_simple.inc.tpl`

`<input type="file" .../>` の直後（`&nbsp;&nbsp;&nbsp;&nbsp;` の部分）を以下に差し替えます。

**修正前:**

```smarty
        <input type="file" name="uploadedFile[{$attach_id}][]" id="uploadedFile_{$attach_id}" multiple 
               size="{#UPLOAD_FILENAME_SIZE#}" />
        &nbsp;&nbsp;&nbsp;&nbsp;
  </div>
```

**修正後:**

```smarty
        <input type="file" name="uploadedFile[{$attach_id}][]" id="uploadedFile_{$attach_id}" multiple 
               size="{#UPLOAD_FILENAME_SIZE#}" />
        &nbsp;
        {* ClipboardUpload Plugin: 実行レベル（attach_id=0）はフォーム同梱ボタン *}
        {if $attach_id == 0}
          <button type="button"
                  onclick="clipUpload.openForExec()"
                  style="cursor:pointer;padding:2px 8px;font-size:12px;"
                  title="クリップボードから画像を貼り付けて実行結果と一緒に保存">
            &#128203;
          </button>
          <span id="clipupload_exec_status" style="font-size:11px;color:#555;"></span>
          <input type="hidden" name="clipupload_base64[0]" id="clipupload_base64_exec" value="">
          <input type="hidden" name="clipupload_filename[0]" id="clipupload_filename_exec" value="">
        {else}
          {* ステップレベル: attach_id = tcsteps.id *}
          <button type="button"
                  onclick="clipUpload.openForStep({$attach_id})"
                  style="cursor:pointer;padding:2px 8px;font-size:12px;"
                  title="クリップボードから画像を貼り付けてステップ結果と一緒に保存">
            &#128203;
          </button>
          <span id="clipupload_step_status_{$attach_id}" style="font-size:11px;color:#555;"></span>
          <input type="hidden" name="clipupload_base64[{$attach_id}]" id="clipupload_base64_step_{$attach_id}" value="">
          <input type="hidden" name="clipupload_filename[{$attach_id}]" id="clipupload_filename_step_{$attach_id}" value="">
        {/if}
  </div>
```

> **注意:** `attachments_simple.inc.tpl` は実行レベル・ステップレベル・テストケース編集画面など多くの箇所で使われます。`attach_id == 0` の条件分岐で実行結果入力時のみボタンが表示されるため、他の画面には影響しません。

---

### 修正③: 実行履歴行への📋ボタン追加（必須・パターン②）

**対象ファイル:** `gui/templates/tl-classic/execute/inc_exec_show_tc_exec.tpl`

`template_patch.diff` を参照してください（302〜306行目付近）。

**修正前:**

```smarty
      <td align="center"><a href="javascript:openFileUploadWindow({$tc_old_exec.execution_id},'executions')">
        <img src="{$tlImages.upload}" title="{$labels.alt_attachment_mgmt}"
             alt="{$labels.alt_attachment_mgmt}"
             style="border:none" /></a>
      </td>
```

**修正後:**

```smarty
      <td align="center">
        <a href="javascript:openFileUploadWindow({$tc_old_exec.execution_id},'executions')">
          <img src="{$tlImages.upload}" title="{$labels.alt_attachment_mgmt}"
               alt="{$labels.alt_attachment_mgmt}"
               style="border:none" />
        </a>
        &nbsp;
        <a href="javascript:clipUpload.openModal()"
           onclick="document.getElementById('clipupload_container').dataset.execId='{$tc_old_exec.execution_id}';return false;"
           title="クリップボードから画像を貼り付け">
          📋
        </a>
      </td>
```

---

### 修正④: PHP バックエンドへの base64 注入処理追加（必須・パターン①）

**対象ファイル:** `lib/functions/exec.inc.php`

`write_execution()` 内の「// Attachment @exec level」ブロックを以下に差し替えます。

**修正前:**

```php
      $uploadOp = new stdClass();
      $uploadOp->tcLevel = null;
      $uploadOp->stepLevel = null;
      if( isset($_FILES['uploadedFile']['name'][0]) &&
          !is_null($_FILES['uploadedFile']['name'][0]) &&
          $_FILES['uploadedFile']['name'][0][0] != '') {
        $uploadOp->tcLevel = addAttachmentsToExec($execution_id,$docRepo);
      }
```

**修正後（実行レベルの base64 注入を追加）:**

```php
      $uploadOp = new stdClass();
      $uploadOp->tcLevel = null;
      $uploadOp->stepLevel = null;

      // クリップボードから貼り付けた画像（base64 → 一時ファイル）を $_FILES に注入する
      if( isset($_POST['clipupload_base64'][0]) && $_POST['clipupload_base64'][0] != '' ) {
        $base64str  = $_POST['clipupload_base64'][0];
        $origName   = isset($_POST['clipupload_filename'][0]) && $_POST['clipupload_filename'][0] != ''
                      ? basename($_POST['clipupload_filename'][0])
                      : 'scr_' . date('YmdHis') . '.png';
        if( strpos($base64str, ',') !== false ) {
          list($meta, $b64data) = explode(',', $base64str, 2);
        } else {
          $b64data = $base64str;
          $meta    = 'data:image/png;base64';
        }
        $mimeType = 'image/png';
        if( preg_match('/data:([^;]+);/', $meta, $m) ) { $mimeType = $m[1]; }
        $decoded = base64_decode($b64data);
        if( $decoded !== false && strlen($decoded) > 0 ) {
          $tmpPath = tempnam(sys_get_temp_dir(), 'tl_clip_');
          file_put_contents($tmpPath, $decoded);
          if( !isset($_FILES['uploadedFile']) ) {
            $_FILES['uploadedFile'] = array(
              'name' => array(), 'type' => array(),
              'tmp_name' => array(), 'error' => array(), 'size' => array()
            );
          }
          $_FILES['uploadedFile']['name'][0]     = $origName;
          $_FILES['uploadedFile']['type'][0]     = $mimeType;
          $_FILES['uploadedFile']['tmp_name'][0] = $tmpPath;
          $_FILES['uploadedFile']['error'][0]    = UPLOAD_ERR_OK;
          $_FILES['uploadedFile']['size'][0]     = strlen($decoded);
        }
      }

      if( isset($_FILES['uploadedFile']['name'][0]) &&
          !is_null($_FILES['uploadedFile']['name'][0]) &&
          $_FILES['uploadedFile']['name'][0][0] != '') {
        $uploadOp->tcLevel = addAttachmentsToExec($execution_id,$docRepo);
      }
```

ステップレベルの base64 注入は、ステップ処理ループ内の `$execution_tcsteps_id = $db->insert_id($target);` の直後に以下を追加します（詳細は実装済みの `lib/functions/exec.inc.php` を参照）。

---

## 動作フロー

### パターン①：実行・ステップ入力時（フォーム同梱方式）

```
[1] テストケースを選択して実行結果画面を開く

[2] 実行レベルの📋ボタン → clipUpload.openForExec()
    ステップレベルの📋ボタン → clipUpload.openForStep(stepId)

[3] モーダルで Ctrl+V → プレビュー確認

[4] 「選択（フォーム保存時に添付）」ボタン
    → _embedInForm() で base64 を hidden input にセット
    → 「scr_YYYYMMDDHHMMSS.png （保存時に添付）」と表示

[5] ステータスボタン（合格/不合格等）で保存
    → multipart/form-data POST
      - 実行レベル: clipupload_base64[0], clipupload_filename[0]
      - ステップレベル: clipupload_base64[{tcsteps.id}], clipupload_filename[{tcsteps.id}]

[6] exec.inc.php の write_execution() が処理
    実行レベル:
      $_POST['clipupload_base64'][0] → base64decode → tempnam → $_FILES[0] に注入
      → addAttachmentsToExec(execution_id) で保存

    ステップレベル（各ステップの execution_tcsteps INSERT 後）:
      $_POST['clipupload_base64'][$step_id] → base64decode → tempnam
      → $_FILES[$step_id][0] に注入
      → insertAttachment(execution_tcsteps_id) で保存
```

### パターン②：実行履歴行への直接アップロード（fetch API方式）

```
[1] 履歴行の📋ボタン → data-exec-id に execution_id をセット
    → clipUpload.openModal() でモーダルを開く

[2] Ctrl+V → 「アップロード」ボタン
    → fetch POST: plugin.php?page=ClipboardUpload/upload
    → pages/upload.php: 認証 → 検証 → insertAttachment → JSON 返却

[3] 成功後1.2秒でモーダルが自動的に閉じる
```

---

## 仕様・制限事項

| 項目 | 内容 |
|------|------|
| 対応画像形式 | PNG / JPEG / GIF |
| ファイルサイズ上限 | `$tlCfg->repository_max_filesize`（デフォルト: 1MB） |
| 対応ブラウザ | Chrome / Edge / Firefox / Safari（モダンブラウザ全般） |
| HTTPS要件 | 不要（`paste` イベント方式） |
| ファイル名自動生成 | `scr_YYYYMMDDHHMMSS.png`（最大19文字、デフォルト正規表現に適合） |
| 権限チェック | TestLink セッション認証 + `attachments.enabled` |
| パターン①の添付先 | 実行レベル: `executions` / ステップレベル: `execution_tcsteps` |
| パターン②の添付先 | `executions`（fetch API 経由） |
| 📋ボタンの表示条件 | パターン①: 常時表示 / パターン②: 実行履歴が1件以上ある場合のみ |

---

## トラブルシューティング

### プラグイン管理画面に ClipboardUpload が表示されない

- `plugins/ClipboardUpload/ClipboardUpload.php` が存在し、クラス名が `ClipboardUploadPlugin` であることを確認する
- `config.inc.php` で `$tlCfg->gui->plugins = true` が設定されているか確認する

### 📋ボタンが表示されない（実行・ステップ入力エリア）

- `attachments_simple.inc.tpl` の修正が正しく適用されているか確認する
- Smarty キャッシュをクリアする（`sudo rm -f .../gui/templates_c/*.php`）
- `$tlCfg->attachments->enabled = true` であるか確認する

### 📋ボタンが表示されない（実行履歴行）

- `inc_exec_show_tc_exec.tpl` の修正が適用されているか確認する
- テストケースを一度も実行していない場合は履歴行が存在しないためボタンも出ない（仕様）

### 実行結果保存後に画像が添付されない（パターン①）

- `exec.inc.php` の修正が適用されているか確認する（`clipupload_base64` の処理があるか）
- ファイルサイズが上限（デフォルト1MB）を超えていないか確認する
- `allowed_files` に `png` / `jpg` が含まれているか確認する

### 「許可されていないファイル形式」エラー（パターン②）

- `config.inc.php` の `$tlCfg->attachments->allowed_files` に `png` と `jpg` が含まれているか確認する

### ファイル名が自動リネームされる

- デフォルト正規表現 `/^[a-zA-Z0-9_-]{1,20}\.[a-zA-Z0-9]{1,10}$/` に合わない場合は
  `scr_YYYYMMDDHHMMSS.png`（19文字）に自動変換される

### ペーストエリアで Ctrl+V が反応しない

- エリアをクリックしてフォーカスを当ててから Ctrl+V を押す
- スクリーンショット後に別ウィンドウに切り替えるとクリップボードが変わる場合がある
