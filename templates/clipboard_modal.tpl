{*
 * ClipboardUpload Plugin - クリップボード貼り付けモーダルUI
 * execSetResults.tpl からインクルードして使用する。
 * このテンプレートは EVENT_TESTRUN_DISPLAY に依存せず常時出力される。
 *}

<!-- ClipboardUpload Plugin -->
<div id="clipupload_container" style="display:none;" data-exec-id=""></div>

<div id="clipupload_modal"
     style="display:none; position:fixed; top:0; left:0; width:100%; height:100%;
            background:rgba(0,0,0,0.45); z-index:9000; justify-content:center; align-items:center;">
  <div style="background:#fff; border-radius:6px; padding:24px; width:520px; max-width:95%;
              box-shadow:0 4px 20px rgba(0,0,0,0.3); position:relative;">

    <h3 style="margin:0 0 12px; font-size:15px;">クリップボードから画像を貼り付け</h3>

    <div id="clipupload_paste_area"
         tabindex="0"
         style="border:2px dashed #6c9dc6; border-radius:4px; padding:32px 16px;
                text-align:center; color:#555; font-size:13px; cursor:pointer;
                background:#f0f6fc; min-height:100px; outline:none;">
      <div id="clipupload_hint">
        ここをクリックしてから <strong>Ctrl+V</strong>（Mac: <strong>&#8984;+V</strong>）で貼り付けてください
      </div>
      <div id="clipupload_preview_wrap" style="display:none; margin-top:8px;">
        <img id="clipupload_preview" src="" alt="preview"
             style="max-width:100%; max-height:200px; border:1px solid #ccc; border-radius:3px;" />
        <div id="clipupload_preview_name" style="font-size:11px; color:#888; margin-top:4px;"></div>
      </div>
    </div>

    <div style="margin-top:10px;">
      <label style="font-size:12px; display:block; margin-bottom:3px;">ファイル名（省略時は自動生成）:</label>
      <input type="text" id="clipupload_filename" placeholder="例: scr_20261022143022.png"
             style="width:100%; box-sizing:border-box; padding:5px 7px; font-size:13px;
                    border:1px solid #ccc; border-radius:3px;" />
    </div>

    <div id="clipupload_execid_row" style="margin-top:8px; display:none;">
      <label style="font-size:12px; display:block; margin-bottom:3px;">
        Execution ID <span style="color:#888; font-size:11px;">（テンプレート修正済みの場合は不要）</span>
      </label>
      <input type="number" id="clipupload_exec_id" placeholder="例: 42"
             style="width:100%; box-sizing:border-box; padding:5px 7px; font-size:13px;
                    border:1px solid #ccc; border-radius:3px;" />
    </div>

    <div style="margin-top:14px; text-align:right;">
      <button type="button" id="clipupload_upload_btn"
              onclick="clipUpload.doUpload()"
              disabled
              style="padding:6px 18px; font-size:13px; cursor:pointer;
                     background:#4a90d9; color:#fff; border:none; border-radius:3px;">
        アップロード
      </button>
      &nbsp;
      <button type="button" onclick="clipUpload.closeModal()"
              style="padding:6px 14px; font-size:13px; cursor:pointer;">
        キャンセル
      </button>
    </div>

    <div id="clipupload_modal_status"
         style="margin-top:10px; font-size:12px; min-height:16px; text-align:center;"></div>
  </div>
</div>

<script>
(function() {
  var UPLOAD_URL = '{$basehref}plugin.php?page=ClipboardUpload/upload';

  var clipUpload = window.clipUpload = {
    blob: null,

    openModal: function(execId) {
      var container = document.getElementById('clipupload_container');
      // 引数で渡された場合はセット、なければ data-exec-id を使う
      if (execId) {
        container.dataset.execId = execId;
      }
      var currentExecId = container.dataset.execId;

      // execId が不明な場合は手入力欄を表示
      var execIdRow = document.getElementById('clipupload_execid_row');
      if (!currentExecId) {
        execIdRow.style.display = 'block';
        document.getElementById('clipupload_exec_id').value = '';
      } else {
        execIdRow.style.display = 'none';
        document.getElementById('clipupload_exec_id').value = currentExecId;
      }

      document.getElementById('clipupload_modal').style.display = 'flex';
      document.getElementById('clipupload_modal_status').textContent = '';
      document.getElementById('clipupload_upload_btn').disabled = true;
      document.getElementById('clipupload_preview_wrap').style.display = 'none';
      document.getElementById('clipupload_hint').style.display = 'block';
      document.getElementById('clipupload_filename').value = '';
      clipUpload.blob = null;

      setTimeout(function() {
        document.getElementById('clipupload_paste_area').focus();
      }, 100);
    },

    closeModal: function() {
      document.getElementById('clipupload_modal').style.display = 'none';
    },

    onPaste: function(e) {
      var items = (e.clipboardData || e.originalEvent.clipboardData).items;
      var imageItem = null;
      for (var i = 0; i < items.length; i++) {
        if (items[i].type.indexOf('image') !== -1) {
          imageItem = items[i];
          break;
        }
      }
      if (!imageItem) {
        document.getElementById('clipupload_modal_status').innerHTML =
          '<span style="color:#c00;">画像が見つかりません。画像をコピーしてから貼り付けてください。</span>';
        return;
      }
      e.preventDefault();
      clipUpload.blob = imageItem.getAsFile();

      var reader = new FileReader();
      reader.onload = function(ev) {
        var img = document.getElementById('clipupload_preview');
        img.src = ev.target.result;
        document.getElementById('clipupload_preview_wrap').style.display = 'block';
        document.getElementById('clipupload_hint').style.display = 'none';
        document.getElementById('clipupload_modal_status').textContent = '';
      };
      reader.readAsDataURL(clipUpload.blob);

      var fnInput = document.getElementById('clipupload_filename');
      if (!fnInput.value) {
        var now = new Date();
        var ts = now.getFullYear()
               + ('0'+(now.getMonth()+1)).slice(-2)
               + ('0'+now.getDate()).slice(-2)
               + ('0'+now.getHours()).slice(-2)
               + ('0'+now.getMinutes()).slice(-2)
               + ('0'+now.getSeconds()).slice(-2);
        var ext = (clipUpload.blob.type === 'image/png') ? 'png'
                : (clipUpload.blob.type === 'image/jpeg') ? 'jpg' : 'png';
        // "scr_" + 14桁 + "." + 拡張子 = 19〜20文字（デフォルト正規表現の20文字上限に収まる）
        fnInput.value = 'scr_' + ts + '.' + ext;
      }
      document.getElementById('clipupload_upload_btn').disabled = false;
    },

    doUpload: function() {
      if (!clipUpload.blob) {
        document.getElementById('clipupload_modal_status').innerHTML =
          '<span style="color:#c00;">先に画像を貼り付けてください。</span>';
        return;
      }

      var execId = document.getElementById('clipupload_exec_id').value;
      if (!execId) {
        var container = document.getElementById('clipupload_container');
        execId = container.dataset.execId;
      }
      if (!execId) {
        document.getElementById('clipupload_modal_status').innerHTML =
          '<span style="color:#c00;">Execution ID を入力してください。</span>';
        return;
      }

      var filename = document.getElementById('clipupload_filename').value.trim();
      if (!filename) { filename = 'scr_upload.png'; }

      var statusEl  = document.getElementById('clipupload_modal_status');
      var uploadBtn = document.getElementById('clipupload_upload_btn');
      statusEl.textContent = 'アップロード中...';
      uploadBtn.disabled = true;

      var formData = new FormData();
      formData.append('execution_id', execId);
      formData.append('filename', filename);
      formData.append('image', clipUpload.blob, filename);

      fetch(UPLOAD_URL, { method: 'POST', body: formData })
        .then(function(res) { return res.json(); })
        .then(function(data) {
          if (data.status === 'ok') {
            statusEl.innerHTML = '<span style="color:green;">&#10004; アップロード完了: ' +
              data.filename + '</span>';
            uploadBtn.disabled = false;
            clipUpload.blob = null;
            setTimeout(function() { clipUpload.closeModal(); }, 1200);
          } else {
            statusEl.innerHTML = '<span style="color:#c00;">エラー: ' +
              (data.message || '不明なエラー') + '</span>';
            uploadBtn.disabled = false;
          }
        })
        .catch(function(err) {
          statusEl.innerHTML = '<span style="color:#c00;">通信エラー: ' + err.message + '</span>';
          uploadBtn.disabled = false;
        });
    }
  };

  document.addEventListener('DOMContentLoaded', function() {
    var pasteArea = document.getElementById('clipupload_paste_area');
    if (pasteArea) {
      pasteArea.addEventListener('paste', clipUpload.onPaste);
      pasteArea.addEventListener('click', function() { pasteArea.focus(); });
    }
    var modal = document.getElementById('clipupload_modal');
    if (modal) {
      modal.addEventListener('click', function(e) {
        if (e.target === modal) { clipUpload.closeModal(); }
      });
    }
  });
})();
</script>
