<?php
/**
 * ClipboardUpload Plugin for TestLink
 *
 * テスト実行画面にクリップボードから画像を貼り付けてアップロードする機能を追加する。
 *
 * 設計方針:
 *   - モーダルUI・JavaScriptは plugins/ClipboardUpload/templates/clipboard_modal.tpl に分離
 *   - execSetResults.tpl から直接インクルードする（EVENT_TESTRUN_DISPLAY 非依存）
 *   - これにより「テストケース選択前でもUIが存在する」状態を保証する
 *   - バックエンドのアップロード処理は pages/upload.php が担う
 */

require_once(TL_ABS_PATH . '/lib/functions/tlPlugin.class.php');

class ClipboardUploadPlugin extends TestlinkPlugin
{
  function register()
  {
    $this->name        = 'ClipboardUpload';
    $this->description = 'テスト実行画面にクリップボードからの画像アップロード機能を追加する';
    $this->version     = '1.0';
    $this->author      = '';
    $this->contact     = '';
    $this->url         = '';
  }

  function hooks()
  {
    // EVENT_TESTRUN_DISPLAY は使用しない。
    // モーダルUIは execSetResults.tpl から直接 clipboard_modal.tpl をインクルードする。
    return array();
  }

  /**
   * プラグインのテンプレートディレクトリへのパスを返す
   */
  public static function templatePath()
  {
    return TL_PLUGIN_PATH . 'ClipboardUpload' . DIRECTORY_SEPARATOR . 'templates' . DIRECTORY_SEPARATOR;
  }
}
