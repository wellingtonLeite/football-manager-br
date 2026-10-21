package br.com.fmbr.football_manager_br

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Seletor de arquivo do backup feito aqui mesmo (sem plugin externo):
/// abre o seletor do Android e devolve o texto do arquivo escolhido.
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fmbr/backup").setMethodCallHandler { call, result ->
            if (call.method != "pickText") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            pending?.success(null)
            pending = result
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            try {
                @Suppress("DEPRECATION")
                startActivityForResult(intent, PICK_BACKUP)
            } catch (e: Exception) {
                pending = null
                result.error("picker", e.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_BACKUP) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val text = contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
            result.success(text)
        } catch (e: Exception) {
            result.error("read", e.message, null)
        }
    }

    companion object {
        private const val PICK_BACKUP = 4242
    }
}
